-- TierList enchants (0.9.3): the best enchant per slot of a ready-made list, taken from the guide the list
-- comes from (Data\Enchants.lua). The window shows it at the slot header; hovering shows the enchant,
-- a click searches the Auction House for it (Auctionator if installed, else Blizzard's search box).
local _, TL = ...
local Enchant = {}
TL.Enchant = Enchant

local GREY = "|cff9d9d9d"
Enchant.COLOR = "|cff5fd7c8"
Enchant.CHEAP_COLOR = "|cffc8b878" -- the cheaper option: muted gold, next to a coin

-- slot -> { {name, effect, hand=, alt=}, ... } for a list, or nil (own lists have none)
function Enchant.ForList(list)
    local all = TL.SeedEnchants
    if not list or not all then
        return nil
    end
    return (list.seedId and all[list.seedId]) or (not list.seedId and list.note and all[list.note]) or nil
end

function Enchant.ForSlot(list, slotKey)
    local e = Enchant.ForList(list)
    return e and e[slotKey]
end

-- "1H" / "2H" for the best weapon on the list's main hand (nil without one)
local function BestWeaponHand(list)
    local best = TL:SlotItems(list, "MAINHAND")[1]
    if not best then
        return nil
    end
    return TL:EquipLoc(best.id) == "INVTYPE_2HWEAPON" and "2H" or "1H"
end

-- The enchant to show for the slot: the guide's first pick; for weapons the first one that suits the
-- list's best weapon (one-hander or two-hander) when the guide has both.
function Enchant.Best(list, slotKey)
    local entries = Enchant.ForSlot(list, slotKey)
    if not entries or not entries[1] then
        return nil
    end
    local hand
    for _, e in ipairs(entries) do
        if e.hand then
            hand = hand or BestWeaponHand(list) or "1H"
            break
        end
    end
    if hand then
        for _, e in ipairs(entries) do
            if not e.alt and (e.hand == nil or e.hand == hand) then
                return e
            end
        end
    end
    return entries[1]
end

-- The cheaper option for the slot (0.9.4), for the same kind of weapon as the best pick: the guide's own,
-- else TierList's pick of the same stat one step smaller (own = true, 0.9.5); nil when there is none.
-- Shown next to the best enchant with a coin and "cheaper:".
function Enchant.Cheap(list, slotKey)
    local best = Enchant.Best(list, slotKey)
    if not best then
        return nil
    end
    for _, e in ipairs(Enchant.ForSlot(list, slotKey)) do
        if e.cheap and e ~= best and e.hand == best.hand then
            return e
        end
    end
    return nil
end

-- short form for the header: "Enchant Bracer - Greater Spellpower" -> "Greater Spellpower",
-- "Enchant 2H Weapon - Spellblasting" -> "Spellblasting (2H)"; items keep their name
function Enchant.Short(name)
    local two = name:match("^Enchant 2H Weapon %- (.+)$")
    if two then
        return two .. " (2H)"
    end
    return name:match("^Enchant [^-]+ %- (.+)$") or name
end

-- Item link for chat (once the item is cached), else the plain name.
function Enchant.Link(name)
    local info = TL.EnchantDB and TL.EnchantDB[name]
    local fn = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if info and info.item and fn then
        local ok, _, link = pcall(fn, info.item)
        if ok and type(link) == "string" then
            return link
        end
    end
    return name
end

-- Tooltip for the enchant shown at the header: `entry` is the best pick (default) or the cheaper one.
function Enchant.Tooltip(tt, list, slotKey, entry)
    local best = Enchant.Best(list, slotKey)
    entry = entry or best
    if not entry then
        return
    end
    local name = entry[1]
    local info = TL.EnchantDB and TL.EnchantDB[name] or {}
    if info.item then
        tt:SetHyperlink("item:" .. info.item)
    elseif info.spell and tt.SetSpellByID then
        tt:SetSpellByID(info.spell)
    else
        tt:SetText(name, 1, 1, 1)
    end
    local slot = TL.SLOT_BY_KEY[slotKey]
    tt:AddLine(" ")
    tt:AddLine("|cff33ff99TierList|r " .. (entry.cheap and "cheaper" or "best") .. " " ..
        (slot and slot.label:lower() or "") .. " enchant: " .. Enchant.COLOR .. name .. "|r", 1, 1, 1, true)
    if entry[2] then
        tt:AddLine("  " .. entry[2], 0.85, 0.85, 0.85, true)
    end
    if entry.own then
        tt:AddLine("  Picked by TierList: the guide names no cheaper enchant, so this is the same kind of stat, one step smaller.",
            0.6, 0.6, 0.6, true)
    end
    for _, e in ipairs(Enchant.ForSlot(list, slotKey)) do
        if e == best and e ~= entry then
            tt:AddLine("Best: " .. e[1] .. (e[2] and (GREY .. " - " .. e[2] .. "|r") or ""), 0.85, 0.85, 0.85, true)
        elseif e ~= entry then
            local kind = e.hand == "2H" and "two-hander" or e.hand == "1H" and "one-hander" or nil
            local tag = e.cheap and (e.own and "Cheaper (TierList's pick)" or "Cheaper") or e.alt and "Or"
                or (kind and (kind:gsub("^%l", string.upper))) or "Also"
            if kind and (e.cheap or e.alt) then
                tag = tag .. " (" .. kind .. ")"
            end
            tt:AddLine(tag .. ": " .. e[1] .. (e[2] and (GREY .. " - " .. e[2] .. "|r") or ""), 0.85, 0.85, 0.85, true)
        end
    end
    local src = Enchant.ForList(list)
    if src and src.source then
        tt:AddLine("From: " .. src.source, 0.6, 0.6, 0.6, true)
    end
    tt:AddLine("Click: search the Auction House" .. (info.kind == "E" and " (finds the formula)" or "") ..
        ". Shift-click: link in chat.", 0.6, 0.6, 0.6, true)
end

-- ---------------------------------------------------------------------------
-- Auction House search
-- ---------------------------------------------------------------------------
local function AHOpen()
    return (AuctionHouseFrame and AuctionHouseFrame:IsShown()) or (AuctionFrame and AuctionFrame:IsShown()) or false
end

local function RunSearch(terms)
    local api = Auctionator and Auctionator.API and Auctionator.API.v1
    if api and api.MultiSearch and pcall(api.MultiSearch, "TierList", terms) then
        return true
    end
    local term = terms[1]
    local bar = AuctionHouseFrame and AuctionHouseFrame:IsShown() and AuctionHouseFrame.SearchBar
    if bar and bar.SearchBox then
        bar.SearchBox:SetText(term)
        if bar.StartSearch then
            bar:StartSearch()
        elseif bar.SearchButton then
            bar.SearchButton:Click()
        end
        return true
    end
    if AuctionFrame and AuctionFrame:IsShown() and BrowseName then
        if AuctionFrameTab1 and AuctionFrameTab1.Click then
            AuctionFrameTab1:Click()
        end
        BrowseName:SetText(term)
        if AuctionFrameBrowse_Search then
            AuctionFrameBrowse_Search()
        end
        return true
    end
    return false
end

-- Search the Auction House for an enchant (its item, the Libram behind an Arcanum, or the formula).
-- With the Auction House closed the search waits until it opens.
function Enchant.Search(name)
    local info = TL.EnchantDB and TL.EnchantDB[name]
    local terms = (info and info.ah) or { name }
    if AHOpen() then
        Enchant.pending = nil
        if not RunSearch(terms) then
            TL.Print("could not search the Auction House for " .. name .. ".")
        end
        return
    end
    Enchant.pending = terms
    TL.Print("open the Auction House, then TierList searches for " .. table.concat(terms, " / ") .. ".")
end

-- Ask the client for the enchant items once, so their tooltips (and our lines below them) are complete
-- on the first hover; an uncached item tooltip is rebuilt when the data arrives.
function Enchant.Preload()
    local load = C_Item and C_Item.RequestLoadItemDataByID
    if not load or not TL.EnchantDB then
        return 0
    end
    local n = 0
    for _, info in pairs(TL.EnchantDB) do
        if info.item then
            pcall(load, info.item)
            n = n + 1
        end
    end
    return n
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("AUCTION_HOUSE_SHOW")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        C_Timer.After(5, function() TL.Safe("enchant preload", Enchant.Preload) end)
        return
    end
    local terms = Enchant.pending
    if terms then
        Enchant.pending = nil
        -- Auctionator builds its tabs on the same event: give it a moment
        C_Timer.After(0.5, function()
            TL.Safe("ah search", RunSearch, terms)
        end)
    end
end)
