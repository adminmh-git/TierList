-- TierList: your own S/A/B/C tier lists per gear slot, for any build and any character.
-- Core: saved data, lists, item facts, equipped/owned state, upgrade logic, events, slash commands.
local ADDON, TL = ...
_G.TierList = TL
TL.VERSION = "0.9.0"
BINDING_HEADER_TIERLIST = "TierList"
BINDING_NAME_TIERLIST_TOGGLE = "Open / close TierList"

-- ---------------------------------------------------------------------------
-- Constants
-- ---------------------------------------------------------------------------
TL.TIERS = { "S", "A", "B", "C" }
TL.TIER_RANK = { S = 1, A = 2, B = 3, C = 4 }
TL.TIER_RGB = {
    S = { 1.00, 0.50, 0.00 },
    A = { 0.64, 0.21, 0.93 },
    B = { 0.00, 0.44, 0.87 },
    C = { 0.12, 0.75, 0.00 },
}
TL.TIER_HEX = { S = "ffff8000", A = "ffa335ee", B = "ff0070dd", C = "ff1eff00" }
TL.UNRANKED = 99

TL.SLOTS = {
    { key = "HEAD", label = "Head", inv = { 1 } },
    { key = "NECK", label = "Neck", inv = { 2 } },
    { key = "SHOULDER", label = "Shoulder", inv = { 3 } },
    { key = "BACK", label = "Back", inv = { 15 } },
    { key = "CHEST", label = "Chest", inv = { 5 } },
    { key = "WRIST", label = "Wrist", inv = { 9 } },
    { key = "HANDS", label = "Hands", inv = { 10 } },
    { key = "WAIST", label = "Waist", inv = { 6 } },
    { key = "LEGS", label = "Legs", inv = { 7 } },
    { key = "FEET", label = "Feet", inv = { 8 } },
    { key = "FINGER", label = "Rings", inv = { 11, 12 } },
    { key = "TRINKET", label = "Trinkets", inv = { 13, 14 } },
    { key = "MAINHAND", label = "Main Hand", inv = { 16 } },
    { key = "OFFHAND", label = "Off Hand", inv = { 17 } },
    { key = "RANGED", label = "Ranged / Relic", inv = { 18 } },
    { key = "OTHER", label = "Other", inv = {} },
}
TL.SLOT_BY_KEY = {}
for i, s in ipairs(TL.SLOTS) do
    s.index = i
    TL.SLOT_BY_KEY[s.key] = s
end

local EQUIPLOC_SLOT = {
    INVTYPE_HEAD = "HEAD", INVTYPE_NECK = "NECK", INVTYPE_SHOULDER = "SHOULDER", INVTYPE_CLOAK = "BACK",
    INVTYPE_CHEST = "CHEST", INVTYPE_ROBE = "CHEST", INVTYPE_WRIST = "WRIST", INVTYPE_HAND = "HANDS",
    INVTYPE_WAIST = "WAIST", INVTYPE_LEGS = "LEGS", INVTYPE_FEET = "FEET", INVTYPE_FINGER = "FINGER",
    INVTYPE_TRINKET = "TRINKET", INVTYPE_2HWEAPON = "MAINHAND", INVTYPE_WEAPON = "MAINHAND",
    INVTYPE_WEAPONMAINHAND = "MAINHAND", INVTYPE_WEAPONOFFHAND = "OFFHAND", INVTYPE_SHIELD = "OFFHAND",
    INVTYPE_HOLDABLE = "OFFHAND", INVTYPE_RANGED = "RANGED", INVTYPE_RANGEDRIGHT = "RANGED",
    INVTYPE_THROWN = "RANGED", INVTYPE_RELIC = "RANGED",
}
TL.EQUIPLOC_SLOT = EQUIPLOC_SLOT

local KIND_LABEL = {
    B = "Boss drop", T = "Trash drop", R = "Rare drop", W = "World drop", Q = "Quest", P = "Crafted",
    V = "Vendor", O = "Container", C = "Container", F = "Fishing", U = "Unknown source",
}

local CLASS_NAMES = {
    WARRIOR = "Warrior", PALADIN = "Paladin", HUNTER = "Hunter", ROGUE = "Rogue", PRIEST = "Priest",
    SHAMAN = "Shaman", MAGE = "Mage", WARLOCK = "Warlock", DRUID = "Druid",
}
TL.CLASS_NAMES = CLASS_NAMES
TL.CLASS_ORDER = { "DRUID", "HUNTER", "MAGE", "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR" }

local DEFAULT_SETTINGS = {
    alerts = true,        -- banner on loot rolls / loot window
    sound = true,         -- sound with an upgrade banner
    chat = true,          -- chat line with alerts and loot
    tooltip = true,       -- TierList lines in item tooltips
    tooltipOthers = true, -- also show other characters' lists in tooltips
    popup = true,         -- "drops here" pop-up when entering a dungeon or raid
}

-- Fill from GearQuest: which sources and qualities count, how many places per slot.
local DEFAULT_FILL = {
    places = 10,
    cats = { dungeon = true, raid = true, crafted = true, quest = true, vendor = true, world = true, pvp = false, other = false },
    quality = { [2] = true, [3] = true, [4] = true },
    replace = true,
}

-- ---------------------------------------------------------------------------
-- Small helpers
-- ---------------------------------------------------------------------------
-- Newer clients can return hidden ("secret") values. Treat them as missing.
function TL.Plain(v)
    if issecretvalue and issecretvalue(v) then
        return nil
    end
    return v
end
local Plain = TL.Plain

local reported = {}
-- Runs fn safely. The first error of each kind is printed once, the rest stay quiet.
function TL.Safe(key, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok and not reported[key] then
        reported[key] = true
        TL.Print("|cffff5555error in " .. tostring(key) .. ":|r " .. tostring(err))
    end
    return ok
end

function TL.Print(msg)
    local frame = DEFAULT_CHAT_FRAME or ChatFrame1
    if frame then
        frame:AddMessage("|cff33ff99TierList|r: " .. tostring(msg))
    end
end

function TL.Trim(s)
    return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

function TL.TierText(tier)
    if not tier then
        return "|cff888888-|r"
    end
    return "|c" .. (TL.TIER_HEX[tier] or "ffffffff") .. tier .. "|r"
end

function TL.ItemIDFromLink(link)
    if type(link) ~= "string" then
        return nil
    end
    return tonumber(link:match("item:(%d+)"))
end

local function GetInfoInstant(id)
    local fn = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if not fn then
        return nil
    end
    local ok, itemID, itemType, itemSubType, equipLoc, icon, classID, subClassID = pcall(fn, id)
    if not ok then
        return nil
    end
    return itemID, itemType, itemSubType, equipLoc, icon, classID, subClassID
end

local function GetInfo(id)
    local fn = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if not fn then
        return nil
    end
    local ok, name, link, quality, ilvl, reqLevel, _, _, _, equipLoc, icon = pcall(fn, id)
    if not ok then
        return nil
    end
    return name, link, quality, ilvl, reqLevel, equipLoc, icon
end

-- Name, quality, icon, equip location, required level, item level, sub type (Plate, Cloth, ...).
function TL:ItemBasics(id)
    local db = self.ItemDB and self.ItemDB[id]
    local _, _, subType, equipLoc, icon = GetInfoInstant(id)
    local name, quality, ilvl, reqLevel
    if db then
        name, quality, reqLevel, ilvl = db[1], db[2], db[3], db[4]
    end
    if not name or not quality then
        local n, _, q, il, rl, el, ic = GetInfo(id)
        name = name or n
        quality = quality or q
        ilvl = ilvl or il
        reqLevel = reqLevel or rl
        equipLoc = equipLoc or el
        icon = icon or ic
    end
    return name, quality, icon, equipLoc, reqLevel, ilvl, subType
end

function TL:QualityHex(q)
    local c = ITEM_QUALITY_COLORS and q and ITEM_QUALITY_COLORS[q]
    if c and c.hex then
        return c.hex
    end
    if c and c.r then
        return string.format("|cff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255)
    end
    return "|cffffffff"
end

function TL:ItemLink(id)
    local _, link = GetInfo(id)
    if link then
        return link
    end
    local name, q = self:ItemBasics(id)
    return self:QualityHex(q) .. "|Hitem:" .. id .. "::::::::::::|h[" .. (name or ("item " .. id)) .. "]|h|r"
end

function TL:ColoredName(id)
    local name, q = self:ItemBasics(id)
    return self:QualityHex(q) .. (name or ("item " .. id)) .. "|r"
end

local slotCache = {}
function TL:DefaultSlotKey(id)
    local cached = slotCache[id]
    if cached then
        return cached
    end
    local _, _, _, equipLoc = GetInfoInstant(id)
    if not equipLoc or equipLoc == "" then
        local _, _, _, _, _, el = GetInfo(id)
        equipLoc = el
    end
    local key = EQUIPLOC_SLOT[equipLoc or ""]
    if key then
        slotCache[id] = key
    end
    return key or "OTHER"
end

function TL:EquipLoc(id)
    local _, _, _, equipLoc = GetInfoInstant(id)
    return equipLoc
end

function TL:SlotKeyFor(id, entry)
    if entry and entry.slot and TL.SLOT_BY_KEY[entry.slot] then
        return entry.slot
    end
    return self:DefaultSlotKey(id)
end

-- 2 = binds when equipped (tradeable, so the Auction House), 1 = binds when picked up, nil = not known
-- yet (item not cached).
function TL:BindType(id)
    local fn = (C_Item and C_Item.GetItemInfo) or GetItemInfo
    if not fn or not id then
        return nil
    end
    local r = { pcall(fn, id) }
    if not r[1] then
        return nil
    end
    return tonumber(Plain(r[15]))
end

function TL:IsBoE(id)
    return self:BindType(id) == 2
end

function TL.MoneyText(copper)
    copper = math.floor(tonumber(copper) or 0)
    local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    local parts = {}
    if g > 0 then parts[#parts + 1] = g .. "g" end
    if s > 0 then parts[#parts + 1] = s .. "s" end
    if c > 0 or #parts == 0 then parts[#parts + 1] = c .. "c" end
    return table.concat(parts, " ")
end

-- What a vendor wants for the item ("75 Tarnished Undermine Real", "1g 20s + 3 Marks"), recorded when a
-- vendor window was open (any character of the account), or nil.
function TL:VendorCost(id)
    local v = self.db and self.db.vendorCost and self.db.vendorCost[id]
    if v then
        return v.text, v.vendor
    end
end

-- Auction House price from Auctionator (its public API), or nil.
function TL:AHPrice(id)
    local api = Auctionator and Auctionator.API and Auctionator.API.v1
    if not (api and api.GetAuctionPriceByItemID) then
        return nil
    end
    local ok, price = pcall(api.GetAuctionPriceByItemID, "TierList", id)
    price = ok and tonumber(Plain(price)) or nil
    return price and price > 0 and price or nil
end

-- One short line about where an item comes from (+ vendor cost when known, + "BoE, AH" when tradeable).
function TL:SourceShort(id)
    local s = self:SourceBase(id)
    if self:IsBoE(id) then
        s = s .. " (BoE, AH)"
    end
    return s
end

function TL:SourceBase(id)
    local d = self.ItemDB and self.ItemDB[id]
    if not d then
        return "Source unknown"
    end
    local kind, zone, who, rate, detail = d[5], d[6], d[7], d[8], d[9]
    local cost = self:VendorCost(id)
    if d[10] then
        return "PvP: " .. (cost or "Honor / marks")
    end
    local rateText = rate and string.format(" (%s%%)", (rate == math.floor(rate)) and tostring(rate) or string.format("%.1f", rate)) or ""
    if kind == "B" or kind == "R" or kind == "T" then
        local prefix = (detail and detail:find("pattern", 1, true)) and "Pattern from " or ""
        local s = prefix .. (who or KIND_LABEL[kind]) .. rateText
        if zone then
            s = s .. " - " .. zone
        end
        return s
    elseif kind == "Q" then
        return "Quest: " .. (who or "?") .. (zone and (" - " .. zone) or "")
    elseif kind == "P" then
        local skill = detail and detail:match("skill (%d+)")
        return "Crafted: " .. (who or "profession") .. (skill and (" " .. skill) or "")
    elseif kind == "V" then
        return "Vendor: " .. (who or "?") .. (zone and (" - " .. zone) or "") .. (cost and (": " .. cost) or "")
    elseif kind == "W" then
        local lo, hi
        if detail then
            lo, hi = detail:match("level (%d+)%-(%d+)")
        end
        return "World drop" .. ((lo and hi) and (" (lvl " .. lo .. "-" .. hi .. ")") or "")
    elseif kind == "O" or kind == "C" then
        return "Container" .. (who and (": " .. who) or "") .. (zone and (" - " .. zone) or "")
    elseif kind == "F" then
        return "Fishing"
    end
    return KIND_LABEL[kind] or "Source unknown"
end

function TL:SourceDetail(id)
    local d = self.ItemDB and self.ItemDB[id]
    return d and d[9]
end

function TL:SourceZone(id)
    local d = self.ItemDB and self.ItemDB[id]
    if d and (d[5] == "B" or d[5] == "T") then
        return d[6]
    end
end

-- ---------------------------------------------------------------------------
-- Saved data
-- ---------------------------------------------------------------------------
function TL:InitDB()
    TierListDB = TierListDB or {}
    local db = TierListDB
    db.version = db.version or 1
    db.lists = db.lists or {}
    db.nextId = db.nextId or 1
    db.active = db.active or {}
    db.chars = db.chars or {}
    db.collapsed = db.collapsed or {}
    db.window = db.window or {}
    db.settings = db.settings or {}
    for k, v in pairs(DEFAULT_SETTINGS) do
        if db.settings[k] == nil then
            db.settings[k] = v
        end
    end
    local fill = db.settings.fill or {}
    db.settings.fill = fill
    for k, v in pairs(DEFAULT_FILL) do
        if fill[k] == nil then
            if type(v) == "table" then
                fill[k] = {}
                for kk, vv in pairs(v) do
                    fill[k][kk] = vv
                end
            else
                fill[k] = v
            end
        elseif type(v) == "table" then
            for kk, vv in pairs(v) do
                if fill[k][kk] == nil then
                    fill[k][kk] = vv
                end
            end
        end
    end
    self.db = db
end

function TL:CharKey()
    return self.charKey
end

function TL:CharLabel(key)
    local c = self.db.chars[key]
    if c and c.name then
        return c.name
    end
    return (tostring(key):gsub("%-$", ""))
end

function TL:RegisterChar()
    local name = Plain(UnitName("player")) or "?"
    local realm = Plain(GetRealmName and GetRealmName()) or ""
    -- The GUID stays the same even if the realm name (blank on some Forever builds) changes.
    local guid = UnitGUID and Plain(UnitGUID("player"))
    self.charKey = (type(guid) == "string" and guid ~= "") and guid or (name .. "-" .. realm)
    local _, classFile = UnitClass("player")
    self.playerClass = Plain(classFile)
    self.playerFaction = UnitFactionGroup and Plain((UnitFactionGroup("player"))) or nil
    self.db.chars[self.charKey] = { name = name, realm = realm, class = self.playerClass, faction = self.playerFaction, seen = time() }
end

-- ---------------------------------------------------------------------------
-- Lists
-- ---------------------------------------------------------------------------
function TL:GetList(id)
    return id and self.db.lists[id]
end

function TL:SortedLists()
    local out = {}
    for _, l in pairs(self.db.lists) do
        out[#out + 1] = l
    end
    table.sort(out, function(a, b)
        return (a.name or ""):lower() < (b.name or ""):lower()
    end)
    return out
end

function TL:CreateList(name, class, build)
    local id = self.db.nextId
    self.db.nextId = id + 1
    local list = {
        id = id, name = name ~= "" and name or ("List " .. id), class = class, build = build or "",
        chars = {}, items = {}, created = time(), modified = time(),
    }
    self.db.lists[id] = list
    return list
end

function TL:DeleteList(id)
    local list = self.db.lists[id]
    if not list then
        return
    end
    self.db.lists[id] = nil
    for key, lid in pairs(self.db.active) do
        if lid == id then
            self.db.active[key] = nil
        end
    end
    self:EnsureActive()
    self:Changed()
end

function TL:GetActiveList()
    return self:GetList(self.db.active[self.charKey])
end

function TL:SetActiveList(id)
    local list = self:GetList(id)
    if not list then
        return
    end
    self.db.active[self.charKey] = id
    list.chars[self.charKey] = true
    self:Changed()
end

-- Lists that belong to this character, the active one first.
function TL:ListsForChar(key)
    key = key or self.charKey
    local out, active = {}, self.db.active[key]
    if active and self.db.lists[active] then
        out[1] = self.db.lists[active]
    end
    for _, l in ipairs(self:SortedLists()) do
        if l.id ~= active and l.chars[key] then
            out[#out + 1] = l
        end
    end
    return out
end

-- Picks an active list for a character that has none: one assigned to it, else an unassigned one of its class.
function TL:EnsureActive()
    if self.db.active[self.charKey] and self.db.lists[self.db.active[self.charKey]] then
        return
    end
    self.db.active[self.charKey] = nil
    for _, l in ipairs(self:SortedLists()) do
        if l.chars[self.charKey] then
            self.db.active[self.charKey] = l.id
            return
        end
    end
    for _, l in ipairs(self:SortedLists()) do
        if l.class == self.playerClass and next(l.chars) == nil then
            self:SetActiveList(l.id)
            return
        end
    end
end

function TL:ApplySeeds()
    if not self.Seeds then
        return
    end
    local function create(seed)
        local list = self:CreateList(seed.name, seed.class, seed.build)
        list.note = seed.source
        list.seedId = seed.id
        list.spec = seed.spec
        list.specSeeded = true
        for _, tier in ipairs(self.TIERS) do
            for _, id in ipairs(seed.tiers[tier] or {}) do
                self:AddItem(list, id, tier)
                local e = list.items[id]
                if e and seed.notes and seed.notes[id] then
                    e.note = seed.notes[id]
                end
            end
        end
        return list
    end
    -- seeds without an id: the 0.1.0 set, created once together
    if not self.db.seeded then
        for _, seed in ipairs(self.Seeds) do
            if not seed.id then
                create(seed)
            end
        end
        self.db.seeded = 1
    end
    -- seeds with an id (added later, e.g. Grayston's list in 0.6.0): created once each
    self.db.seedsDone = self.db.seedsDone or {}
    for _, seed in ipairs(self.Seeds) do
        if seed.id and not self.db.seedsDone[seed.id] then
            self.db.seedsDone[seed.id] = { list = create(seed).id, v = seed.version }
            TL.Print("new list \"" .. seed.name .. "\" (" .. (seed.build or "") .. ").")
        end
        -- once per character of the seed's class: make it the active list if that character still
        -- uses an older seed list (or none); switching back later is respected
        local done = seed.id and self.db.seedsDone[seed.id]
        local list = done and self:GetList(done.list)
        if list and (seed.activate or seed.assign) and seed.class == self.playerClass then
            done.chars = done.chars or {}
            if not done.chars[self.charKey] then
                done.chars[self.charKey] = true
                local cur = self:GetActiveList()
                if seed.assign and not seed.activate then
                    -- counts for this character (tooltips, alerts, dungeon pop-up), the active list stays
                    list.chars[self.charKey] = true
                    TL.Print("\"" .. list.name .. "\" now counts for this character too (" ..
                        TL.Spec.Label(list.spec) .. "; Edit removes it).")
                elseif not cur or (cur.note and cur.note ~= list.note and not cur.seedId and cur.note:find("wowsims", 1, true)) then
                    list.chars[self.charKey] = true
                    self.db.active[self.charKey] = list.id
                    TL.Print("active list is now \"" .. list.name .. "\"" .. (cur and (" (was \"" .. cur.name .. "\", still there)") or "") .. ".")
                end
            end
        end
    end
    -- Items added to a seed later (seed.version, seed.added[version] = { ids }) go into the list made
    -- from an older version once; items the player removed before are not touched.
    for _, seed in ipairs(self.Seeds) do
        local done = seed.id and self.db.seedsDone[seed.id]
        local list = done and seed.version and self:GetList(done.list)
        if list and (done.v or 1) < seed.version then
            local n = 0
            for v = (done.v or 1) + 1, seed.version do
                for _, id in ipairs(seed.added and seed.added[v] or {}) do
                    if not list.items[id] then
                        local tier = "C"
                        for _, t in ipairs(self.TIERS) do
                            for _, sid in ipairs(seed.tiers[t] or {}) do
                                if sid == id then
                                    tier = t
                                end
                            end
                        end
                        self:AddItem(list, id, tier)
                        if list.items[id] and seed.notes and seed.notes[id] then
                            list.items[id].note = seed.notes[id]
                        end
                        n = n + 1
                    end
                end
            end
            done.v = seed.version
            if n > 0 then
                TL.Print(string.format("added %d items to \"%s\" (update of the list).", n, list.name))
            end
        end
    end
    -- Seed lists get their seed's spec once (0.7.0, also lists made by older versions); a spec the
    -- player picked with Edit stays.
    for _, seed in ipairs(self.Seeds) do
        if seed.spec then
            local done = seed.id and self.db.seedsDone[seed.id]
            for _, list in pairs(self.db.lists) do
                if not list.specSeeded and ((done and list.id == done.list) or (not seed.id and list.note == seed.source)) then
                    list.specSeeded = true
                    if list.spec == nil then
                        list.spec = seed.spec
                    end
                end
            end
        end
    end
    -- Seed lists get GearQuest's other picks once (added in 0.2.0, also for lists seeded by 0.1.0).
    -- Runs on a character of the list's class, so the faction-specific picks fit.
    for _, seed in ipairs(self.Seeds) do
        if seed.fill and seed.class == self.playerClass then
            for _, list in pairs(self.db.lists) do
                if list.note == seed.source and not list.seedFilled then
                    list.seedFilled = true
                    local n = self:FillFromPicks(list, seed.fill)
                    if n > 0 then
                        TL.Print(string.format("added %d GearQuest picks (%s) to \"%s\". /tl unfill removes them.",
                            n, seed.fill, list.name))
                    end
                end
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Items in a list
-- ---------------------------------------------------------------------------
local function NextOrder(self, list, slotKey, tier)
    local max = 0
    for id, e in pairs(list.items) do
        if e.tier == tier and self:SlotKeyFor(id, e) == slotKey and (e.order or 0) > max then
            max = e.order or 0
        end
    end
    return max + 1
end

-- Adds an item (or changes its tier). Returns "added", "changed" or "same".
function TL:AddItem(list, id, tier, slotOverride)
    tier = TL.TIER_RANK[tier or ""] and tier or "S"
    local e, listed = self:Entry(list, id)
    if e then
        id = listed -- a variant of this item is already listed: change that one
    end
    if e and e.tier == tier and (not slotOverride or e.slot == slotOverride) then
        return "same"
    end
    if e then
        e.slot = slotOverride or e.slot
        local slotKey = self:SlotKeyFor(id, e)
        e.tier = tier
        e.src = nil -- your choice now, no longer a GearQuest fill
        e.order = NextOrder(self, list, slotKey, tier)
        list.modified = time()
        return "changed"
    end
    e = { tier = tier, added = time() }
    if slotOverride and TL.SLOT_BY_KEY[slotOverride] then
        e.slot = slotOverride
    end
    e.order = NextOrder(self, list, self:SlotKeyFor(id, e), tier)
    list.items[id] = e
    list.modified = time()
    return "added"
end

function TL:RemoveItem(list, id)
    local e = list.items[id]
    if not e then
        return
    end
    self.undo = { listId = list.id, id = id, entry = e }
    list.items[id] = nil
    list.modified = time()
end

function TL:Undo()
    local u = self.undo
    local list = u and self:GetList(u.listId)
    if not list then
        TL.Print("nothing to undo.")
        return
    end
    if u.bulk then
        local n = 0
        for id, e in pairs(u.bulk) do
            list.items[id] = e
            n = n + 1
        end
        TL.Print("restored " .. n .. " items to " .. list.name .. ".")
    else
        list.items[u.id] = u.entry
        TL.Print("restored " .. self:ColoredName(u.id) .. " to " .. list.name .. ".")
    end
    self.undo = nil
    self:Changed()
end

-- ---------------------------------------------------------------------------
-- GearQuest picks (Data\Picks.lua): GearQuest Forever's ranked items per class,
-- spec and slot at level 60. "Fill" adds them below what a list already has.
-- ---------------------------------------------------------------------------
-- Where an item comes from, for the fill filters (order = order in the Fill dialog).
TL.SOURCE_CATS = {
    { key = "dungeon", label = "Dungeons" },
    { key = "raid", label = "Raids" },
    { key = "crafted", label = "Crafted" },
    { key = "quest", label = "Quests" },
    { key = "vendor", label = "Vendors" },
    { key = "world", label = "World drops, rares" },
    { key = "pvp", label = "PvP (Honor)" },
    { key = "other", label = "Unknown source" },
}
TL.FILL_QUALITIES = {
    { q = 2, label = "Green" },
    { q = 3, label = "Blue" },
    { q = 4, label = "Epic" },
}

function TL:SourceCategory(id)
    local d = self.ItemDB and self.ItemDB[id]
    if not d then
        return "other"
    end
    if d[10] then
        return "pvp"
    end
    local kind, zone = d[5], d[6]
    if kind == "B" or kind == "T" then
        local k = zone and self.InstanceKind and self.InstanceKind[zone]
        if k == "raid" or k == "dungeon" then
            return k
        end
        return zone and "world" or "other" -- world bosses, open-world drops
    elseif kind == "P" then
        return "crafted"
    elseif kind == "Q" then
        return "quest"
    elseif kind == "V" then
        return d[7] and "vendor" or "other" -- no known seller (e.g. the ilvl-98 "Inquisition" pieces)
    elseif kind == "W" or kind == "R" or kind == "O" or kind == "C" or kind == "F" then
        return "world"
    end
    return "other"
end

function TL:FillSettings()
    return self.db.settings.fill
end

-- Does an item pass the fill filters? opts = { cats = {...}, quality = {...} }
function TL:PassesFill(id, opts)
    if not opts.cats[self:SourceCategory(id)] then
        return false
    end
    local d = self.ItemDB and self.ItemDB[id]
    local q = d and d[2]
    if not q then
        local _, iq = self:ItemBasics(id)
        q = iq
    end
    if q then
        q = math.max(2, math.min(4, q)) -- white counts as green, legendary as epic
        return opts.quality[q] and true or false
    end
    return true
end

function TL:PickSpecs(class)
    local c = self.Picks and class and self.Picks[class]
    return c and c.specs or {}
end

function TL:PicksFor(class, spec, slotKey, faction)
    local c = self.Picks and class and self.Picks[class]
    local s = c and spec and c[spec]
    if not s then
        return nil
    end
    local own = faction and s[faction]
    return (own and own[slotKey]) or s[slotKey]
end

-- The faction a list is for: its characters' faction, else the player's.
function TL:ListFaction(list)
    for key in pairs(list.chars or {}) do
        local c = self.db.chars[key]
        if c and c.faction then
            return c.faction
        end
    end
    return self.playerFaction
end

-- Tier from the place among the items that pass the filters: first 30 % A, next 30 % B, rest C.
local function FillTier(place, limit)
    if place <= math.ceil(limit * 0.3) then
        return "A"
    elseif place <= math.ceil(limit * 0.6) then
        return "B"
    end
    return "C"
end

-- Adds GearQuest's picks for `spec` to the list, best first, only items that pass the filters.
-- opts (all optional, defaults from /tl Fill settings): places, cats, quality, replace.
-- Items already listed keep their tier. A slot without an S item gets the first pick as S.
-- A list whose best main hand is two-handed only gets two-handers and no off hands.
-- replace = remove earlier GearQuest picks of this list first.
-- Returns the number of added items (+ removed count), or nil + message.
function TL:FillFromPicks(list, spec, opts)
    if type(opts) == "number" then
        opts = { places = opts }
    end
    opts = opts or {}
    local class = list.class or self.playerClass
    if not (self.Picks and self.Picks[class] and self.Picks[class][spec]) then
        return nil, "no GearQuest picks for " .. tostring(class) .. " / " .. tostring(spec) .. "."
    end
    local f = self:FillSettings()
    local filter = { cats = opts.cats or f.cats, quality = opts.quality or f.quality }
    local places = math.max(1, math.min(40, tonumber(opts.places) or f.places or 10))
    local removed = 0
    if opts.replace then
        for id, e in pairs(list.items) do
            if e.src == "gq" then
                list.items[id] = nil
                removed = removed + 1
            end
        end
    end
    local faction = self:ListFaction(list)
    local mh = self:SlotItems(list, "MAINHAND")[1]
    local twoHand = mh and self:EquipLoc(mh.id) == "INVTYPE_2HWEAPON"
    local added = 0
    for _, slot in ipairs(TL.SLOTS) do
        local picks = self:PicksFor(class, spec, slot.key, faction)
        if picks and not (twoHand and slot.key == "OFFHAND") then
            local limit = (#slot.inv > 1) and math.floor(places * 1.4 + 0.5) or places
            local hasS = false
            for _, row in ipairs(self:SlotItems(list, slot.key)) do
                if row.e.tier == "S" then
                    hasS = true
                end
            end
            local place = 0
            for i = 1, #picks, 2 do
                local id, score = picks[i], picks[i + 1]
                if not (twoHand and slot.key == "MAINHAND" and self:EquipLoc(id) ~= "INVTYPE_2HWEAPON")
                    and self:PassesFill(id, filter) then
                    place = place + 1
                    if place > limit then
                        break
                    end
                    if not self:Entry(list, id) then
                        local tier = FillTier(place, limit)
                        if not hasS then
                            tier, hasS = "S", true
                        end
                        local over = (self:DefaultSlotKey(id) ~= slot.key) and slot.key or nil
                        if self:AddItem(list, id, tier, over) == "added" then
                            local e = list.items[id]
                            e.src, e.score = "gq", score
                            added = added + 1
                        end
                    end
                end
            end
        end
    end
    list.fill = { spec = spec, faction = faction, at = time() }
    list.modified = time()
    self:Changed()
    return added, removed
end

-- Removes the items a fill added (not ones you re-tiered or moved since). /tl undo brings them back.
function TL:RemoveFilled(list)
    local removed, n = {}, 0
    for id, e in pairs(list.items) do
        if e.src == "gq" then
            removed[id] = e
            n = n + 1
        end
    end
    for id in pairs(removed) do
        list.items[id] = nil
    end
    if n > 0 then
        self.undo = { listId = list.id, bulk = removed }
        list.modified = time()
        self:Changed()
    end
    return n
end

-- "shock" -> "shockadin"; exact name first, then prefix.
function TL:MatchSpec(specs, word)
    if not word or word == "" then
        return nil
    end
    word = word:lower()
    for _, s in ipairs(specs) do
        if s == word then
            return s
        end
    end
    for _, s in ipairs(specs) do
        if s:sub(1, #word) == word then
            return s
        end
    end
end

function TL:CountFilled(list)
    local n = 0
    for _, e in pairs(list.items) do
        if e.src == "gq" then
            n = n + 1
        end
    end
    return n
end

function TL:SetItemSlot(list, id, slotKey)
    local e = list.items[id]
    if not e then
        return
    end
    e.slot = (slotKey ~= self:DefaultSlotKey(id)) and slotKey or nil
    e.order = NextOrder(self, list, self:SlotKeyFor(id, e), e.tier)
    list.modified = time()
end

-- Items of one slot, best first.
function TL:SlotItems(list, slotKey)
    local out = {}
    for id, e in pairs(list.items) do
        if self:SlotKeyFor(id, e) == slotKey then
            out[#out + 1] = { id = id, e = e }
        end
    end
    table.sort(out, function(a, b)
        local ra, rb = TL.TIER_RANK[a.e.tier] or 9, TL.TIER_RANK[b.e.tier] or 9
        if ra ~= rb then
            return ra < rb
        end
        if (a.e.order or 0) ~= (b.e.order or 0) then
            return (a.e.order or 0) < (b.e.order or 0)
        end
        return a.id < b.id
    end)
    return out
end

-- Position of an item inside its slot (1 = best), and the slot key.
function TL:PlaceInSlot(list, id)
    local e, listed = self:Entry(list, id)
    if not e then
        return nil
    end
    id = listed
    local slotKey = self:SlotKeyFor(id, e)
    for i, row in ipairs(self:SlotItems(list, slotKey)) do
        if row.id == id then
            return i, slotKey
        end
    end
end

-- Moves an item one step up (-1) or down (+1) inside its slot. Crossing a tier border changes its tier.
function TL:MoveItem(list, id, delta)
    local e = list.items[id]
    if not e then
        return
    end
    local rows = self:SlotItems(list, self:SlotKeyFor(id, e))
    local pos
    for i, r in ipairs(rows) do
        if r.id == id then
            pos = i
        end
    end
    local other = pos and rows[pos + delta]
    if not other then
        return
    end
    if other.e.tier ~= e.tier then
        e.tier = other.e.tier
    end
    e.src = nil
    -- renumber the tier so the swap is exact
    table.remove(rows, pos)
    table.insert(rows, pos + delta, { id = id, e = e })
    local counter = {}
    for _, r in ipairs(rows) do
        counter[r.e.tier] = (counter[r.e.tier] or 0) + 1
        r.e.order = counter[r.e.tier]
    end
    list.modified = time()
end

function TL:CountItems(list)
    local n = 0
    for _ in pairs(list.items) do
        n = n + 1
    end
    return n
end

-- ---------------------------------------------------------------------------
-- What the character has
-- ---------------------------------------------------------------------------
function TL:RefreshEquipped()
    local eq = {}
    for slot = 1, 19 do
        local id = Plain(GetInventoryItemID("player", slot))
        if id then
            eq[slot] = id
        end
    end
    self.equipped = eq
end

function TL:IsEquipped(id)
    local v = self:Variants(id)
    for _, eid in pairs(self.equipped or {}) do
        if eid == id then
            return true
        end
        if v then
            for _, vid in ipairs(v) do
                if eid == vid then
                    return true
                end
            end
        end
    end
    return false
end

local function CountOne(id)
    local fn = (C_Item and C_Item.GetItemCount) or GetItemCount
    if not fn then
        return 0
    end
    local ok, n = pcall(fn, id, true)
    n = ok and Plain(n) or 0
    return tonumber(n) or 0
end

function TL:OwnedCount(id)
    local n = CountOne(id)
    for _, vid in ipairs(self:Variants(id) or {}) do
        n = n + CountOne(vid)
    end
    return n
end

-- "equipped", "owned" or nil
function TL:ItemState(id)
    if self:IsEquipped(id) then
        return "equipped"
    end
    if self:OwnedCount(id) > 0 then
        return "owned"
    end
end

-- Rank of an item in a list as a sortable number (lower = better), unranked = 99.
function TL:RankValue(list, id)
    local e = self:Entry(list, id)
    if not e then
        return TL.UNRANKED
    end
    return (TL.TIER_RANK[e.tier] or 9) + (e.order or 0) / 1000
end

-- What is worn in the slot this item would go into: the weakest piece for two-slot groups.
-- Returns rankValue, equippedItemId
function TL:WornInSlot(list, slotKey)
    local slot = TL.SLOT_BY_KEY[slotKey]
    if not slot or #slot.inv == 0 then
        return nil
    end
    local worstRank, worstId = -1, nil
    for _, inv in ipairs(slot.inv) do
        local eid = self.equipped and self.equipped[inv]
        local r = eid and self:RankValue(list, eid) or TL.UNRANKED + 1
        if r > worstRank then
            worstRank, worstId = r, eid
        end
    end
    return worstRank, worstId
end

-- Is this item an upgrade over what is worn, judged by the list? Returns isUpgrade, wornId, wornRank.
function TL:UpgradeInfo(list, id)
    local e = self:Entry(list, id)
    if not e then
        return nil
    end
    local slotKey = self:SlotKeyFor(id, e)
    local wornRank, wornId = self:WornInSlot(list, slotKey)
    if not wornRank then
        return nil
    end
    if self:IsEquipped(id) then
        return false, id, self:RankValue(list, id)
    end
    return self:RankValue(list, id) < wornRank, wornId, wornRank
end

-- ---------------------------------------------------------------------------
-- Name lookups (search and import)
-- ---------------------------------------------------------------------------
function TL:NameIndex()
    if self.nameIndex then
        return self.nameIndex
    end
    local idx, byName = {}, {}
    for id, d in pairs(self.ItemDB or {}) do
        local lower = d[1]:lower()
        idx[#idx + 1] = { id = id, lower = lower }
        local list = byName[lower]
        if not list then
            list = {}
            byName[lower] = list
        end
        list[#list + 1] = id
    end
    -- for duplicate names prefer the highest item level, then the newer (Forever) id
    for _, ids in pairs(byName) do
        table.sort(ids, function(a, b)
            local la, lb = self.ItemDB[a][4] or 0, self.ItemDB[b][4] or 0
            if la ~= lb then
                return la > lb
            end
            return a > b
        end)
    end
    self.nameIndex, self.byName = idx, byName
    return idx
end

function TL:IdsByName(name)
    self:NameIndex()
    return self.byName[TL.Trim(name):lower()]
end

function TL.Slugify(name)
    local s = name:lower():gsub("'", ""):gsub("[^%w]+", "_"):gsub("_+", "_"):gsub("^_", ""):gsub("_$", "")
    return s
end

-- wowsims gear names: snake_case item names, duplicates carry _ilvlNN or _tagN.
function TL:IdBySlug(slug)
    if not self.bySlug then
        local t = {}
        for id, d in pairs(self.ItemDB or {}) do
            local s = TL.Slugify(d[1])
            t[s] = t[s] or {}
            table.insert(t[s], id)
        end
        for _, ids in pairs(t) do
            table.sort(ids, function(a, b)
                local la, lb = self.ItemDB[a][4] or 0, self.ItemDB[b][4] or 0
                if la ~= lb then
                    return la > lb
                end
                return a > b
            end)
        end
        self.bySlug = t
    end
    local ilvl = tonumber(slug:match("_ilvl(%d+)$"))
    local base = slug:gsub("_ilvl%d+$", ""):gsub("_tag%d+$", "")
    local ids = self.bySlug[base]
    if not ids then
        return nil
    end
    if ilvl then
        for _, id in ipairs(ids) do
            if self.ItemDB[id][4] == ilvl then
                return id
            end
        end
    end
    return ids[1]
end

-- Same name + same item level = the same item for us (faction copies such as
-- Soulforge Spaulders 22093 and 226969). Returns the other ids or nil.
local variantCache = {}
function TL:Variants(id)
    local c = variantCache[id]
    if c ~= nil then
        return c or nil
    end
    local d = self.ItemDB and self.ItemDB[id]
    local out = false
    if d then
        self:NameIndex()
        local ids = self.byName[d[1]:lower()]
        if ids and #ids > 1 then
            local t = {}
            for _, vid in ipairs(ids) do
                if vid ~= id and self.ItemDB[vid][4] == d[4] then
                    t[#t + 1] = vid
                end
            end
            if #t > 0 then
                out = t
            end
        end
    end
    variantCache[id] = out
    return out or nil
end

-- The list entry for an item or one of its variants. Returns entry, listedId.
function TL:Entry(list, id)
    if not list or not id then
        return nil
    end
    local e = list.items[id]
    if e then
        return e, id
    end
    local v = self:Variants(id)
    if v then
        for _, vid in ipairs(v) do
            if list.items[vid] then
                return list.items[vid], vid
            end
        end
    end
end

-- Search the whole item database. Returns up to `limit` ids.
function TL:SearchAll(query, limit)
    query = TL.Trim(query):lower()
    local out = {}
    if query == "" then
        return out
    end
    local asId = tonumber(query)
    if asId then
        out[1] = asId
    end
    local prefix, other = {}, {}
    for _, row in ipairs(self:NameIndex()) do
        if row.id ~= asId then
            local s = row.lower:find(query, 1, true)
            if s == 1 then
                prefix[#prefix + 1] = row.id
            elseif s then
                other[#other + 1] = row.id
            end
        end
    end
    local function byLevel(a, b)
        local la, lb = self.ItemDB[a][4] or 0, self.ItemDB[b][4] or 0
        if la ~= lb then
            return la > lb
        end
        return a < b
    end
    table.sort(prefix, byLevel)
    table.sort(other, byLevel)
    for _, id in ipairs(prefix) do
        if #out >= limit then
            break
        end
        out[#out + 1] = id
    end
    for _, id in ipairs(other) do
        if #out >= limit then
            break
        end
        out[#out + 1] = id
    end
    return out
end

-- ---------------------------------------------------------------------------
-- Change notification (UI refresh)
-- ---------------------------------------------------------------------------
local refreshQueued = false
function TL:Changed()
    if refreshQueued then
        return
    end
    refreshQueued = true
    C_Timer.After(0.05, function()
        refreshQueued = false
        if TL.UI and TL.UI.Refresh then
            TL.Safe("ui", TL.UI.Refresh, TL.UI)
        end
    end)
end

-- ---------------------------------------------------------------------------
-- Adding from text (slash command, add box)
-- ---------------------------------------------------------------------------
-- Turns "link / id / name" into item ids. Returns ids, or nil + message.
function TL:ResolveItems(text)
    text = TL.Trim(text)
    if text == "" then
        return nil, "type an item link, ID or name."
    end
    local ids = {}
    for id in text:gmatch("item:(%d+)") do
        ids[#ids + 1] = tonumber(id)
    end
    if #ids > 0 then
        return ids
    end
    for id in text:gmatch("[Ii]tem[=/](%d+)") do
        ids[#ids + 1] = tonumber(id)
    end
    if #ids > 0 then
        return ids
    end
    if text:match("^[%d%s,;]+$") then
        for id in text:gmatch("%d+") do
            ids[#ids + 1] = tonumber(id)
        end
        return ids
    end
    local byName = self:IdsByName(text)
    if byName then
        return { byName[1] }
    end
    return nil, "no item called \"" .. text .. "\" found. Try the search box with \"All items\"."
end

function TL:AddFromText(text, tier)
    local list = self:GetActiveList()
    if not list then
        TL.Print("no list yet. Open /tl and create one.")
        return false
    end
    local ids, err = self:ResolveItems(text)
    if not ids then
        TL.Print(err)
        return false
    end
    for _, id in ipairs(ids) do
        local res = self:AddItem(list, id, tier)
        if res == "added" then
            TL.Print("added " .. self:ColoredName(id) .. " as " .. TL.TierText(tier) .. " to " .. list.name .. ".")
        elseif res == "changed" then
            TL.Print(self:ColoredName(id) .. " is now " .. TL.TierText(tier) .. " in " .. list.name .. ".")
        else
            TL.Print(self:ColoredName(id) .. " is already " .. TL.TierText(tier) .. ".")
        end
    end
    self:Changed()
    return true
end

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------
local events = CreateFrame("Frame")
TL.events = events
local handlers = {}
TL.handlers = handlers

function TL:On(event, fn)
    handlers[event] = handlers[event] or {}
    table.insert(handlers[event], fn)
    pcall(events.RegisterEvent, events, event)
end

events:SetScript("OnEvent", function(_, event, ...)
    local list = handlers[event]
    if not list then
        return
    end
    for _, fn in ipairs(list) do
        TL.Safe(event, fn, ...)
    end
end)

TL:On("ADDON_LOADED", function(name)
    if name ~= ADDON then
        return
    end
    TL:InitDB()
end)

TL:On("PLAYER_LOGIN", function()
    if not TL.db then
        TL:InitDB()
    end
    TL:RegisterChar()
    TL:ApplySeeds()
    TL:EnsureActive()
    TL:RefreshEquipped()
    if TL.Tooltip and TL.Tooltip.Hook then
        TL.Safe("tooltip-hook", TL.Tooltip.Hook)
    end
    if TL.UI and TL.UI.HookLinks then
        TL.Safe("link-hook", TL.UI.HookLinks)
    end
end)

-- ---------------------------------------------------------------------------
-- Vendor costs: read from an open vendor window (gold, currencies, tokens, honor), kept account wide
-- ---------------------------------------------------------------------------
local function MerchantItem(i)
    if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
        local ok, info = pcall(C_MerchantFrame.GetItemInfo, i)
        if ok and type(info) == "table" then
            return tonumber(Plain(info.price)), Plain(info.hasExtendedCost)
        end
    end
    if GetMerchantItemInfo then
        local ok, _, _, price, _, _, _, _, ext = pcall(GetMerchantItemInfo, i)
        if ok then
            return tonumber(Plain(price)), Plain(ext)
        end
    end
end

function TL:ScanMerchant()
    if not (self.db and GetMerchantNumItems and GetMerchantItemLink) then
        return 0
    end
    local ok, n = pcall(GetMerchantNumItems)
    n = ok and tonumber(Plain(n)) or 0
    local vendor = Plain(UnitName("npc"))
    self.db.vendorCost = self.db.vendorCost or {}
    local saved = 0
    for i = 1, n do
        local okL, link = pcall(GetMerchantItemLink, i)
        local id = okL and TL.ItemIDFromLink(Plain(link))
        if id and self.ItemDB and self.ItemDB[id] then
            local price, ext = MerchantItem(i)
            local parts = {}
            if ext and GetMerchantItemCostInfo and GetMerchantItemCostItem then
                local okC, nc = pcall(GetMerchantItemCostInfo, i)
                for c = 1, (okC and tonumber(Plain(nc)) or 0) do
                    local okI, _, value, clink, cname = pcall(GetMerchantItemCostItem, i, c)
                    if okI then
                        value, clink, cname = tonumber(Plain(value)), Plain(clink), Plain(cname)
                        local name = (type(cname) == "string" and cname ~= "" and cname)
                            or (type(clink) == "string" and clink:match("%[(.-)%]"))
                        if value and value > 0 and name then
                            parts[#parts + 1] = value .. " " .. name
                        end
                    end
                end
            end
            if price and price > 0 then
                table.insert(parts, 1, TL.MoneyText(price))
            end
            if #parts > 0 then
                self.db.vendorCost[id] = { text = table.concat(parts, " + "), vendor = vendor, seen = time() }
                saved = saved + 1
            end
        end
    end
    return saved
end

TL:On("MERCHANT_SHOW", function()
    TL:ScanMerchant()
end)
TL:On("MERCHANT_UPDATE", function()
    TL:ScanMerchant()
end)

TL:On("PLAYER_EQUIPMENT_CHANGED", function()
    TL:RefreshEquipped()
    TL:Changed()
end)

TL:On("BAG_UPDATE_DELAYED", function()
    if TL.UI and TL.UI.frame and TL.UI.frame:IsShown() then
        TL:Changed()
    end
end)

TL:On("GET_ITEM_INFO_RECEIVED", function()
    if TL.UI and TL.UI.frame and TL.UI.frame:IsShown() then
        TL:Changed()
    end
end)

-- ---------------------------------------------------------------------------
-- Slash commands
-- ---------------------------------------------------------------------------
local SETTING_CMDS = {
    alerts = { "alerts", "loot alerts" },
    sound = { "sound", "alert sound" },
    chat = { "chat", "chat messages" },
    tooltip = { "tooltip", "tooltip lines" },
    others = { "tooltipOthers", "other characters' lists in tooltips" },
    popup = { "popup", "dungeon pop-up" },
}

local function Help()
    TL.Print("commands:")
    local lines = {
        "/tl - open or close the window",
        "/tl add <link, ID or name> [S|A|B|C] - add to the active list",
        "/tl import, /tl export - share lists, import wowsims / text",
        "/tl lists - show your lists, /tl use <name> - switch list",
        "/tl undo - bring back the last removed item(s)",
        "/tl fill <spec> [count] - add GearQuest's level-60 picks per slot, /tl unfill - remove them",
        "/tl spec - your talent tree and which lists are main spec / offspec; /tl spec <name> | auto",
        "/tl test - show a test alert",
        "/tl minimap - show or hide the minimap button",
        "/tl version - your version and whether a newer one is out",
        "/tl alerts | sound | chat | tooltip | others | popup - switch options on/off",
    }
    for _, l in ipairs(lines) do
        TL.Print("  " .. l)
    end
end

function TierList_Toggle()
    if TL.UI then
        TL.UI:Toggle()
    end
end

function TierList_OnAddonCompartmentClick()
    TierList_Toggle()
end

SLASH_TIERLIST1 = "/tl"
SLASH_TIERLIST2 = "/tierlist"
SlashCmdList["TIERLIST"] = function(msg)
    msg = TL.Trim(msg)
    local cmd, rest = msg:match("^(%S+)%s*(.-)$")
    cmd = (cmd or ""):lower()
    if cmd == "" then
        TierList_Toggle()
    elseif cmd == "add" then
        local tier = "S"
        local body, t = rest:match("^(.-)%s+([SsAaBbCc])$")
        if body and t then
            rest, tier = body, t:upper()
        end
        TL:AddFromText(rest, tier)
    elseif cmd == "import" then
        TL.UI:ShowImport()
    elseif cmd == "export" then
        TL.UI:ShowExport()
    elseif cmd == "lists" or cmd == "list" then
        local active = TL:GetActiveList()
        for _, l in ipairs(TL:SortedLists()) do
            local chars = {}
            for key in pairs(l.chars) do
                chars[#chars + 1] = TL:CharLabel(key)
            end
            TL.Print((l == active and "> " or "  ") .. l.name .. " (" .. TL:CountItems(l) .. " items" ..
                (#chars > 0 and (", " .. table.concat(chars, ", ")) or "") .. ")")
        end
    elseif cmd == "use" then
        local want = rest:lower()
        for _, l in ipairs(TL:SortedLists()) do
            if l.name:lower() == want then
                TL:SetActiveList(l.id)
                TL.Print("active list: " .. l.name)
                return
            end
        end
        TL.Print("no list called \"" .. rest .. "\".")
    elseif cmd == "undo" then
        TL:Undo()
    elseif cmd == "fill" then
        local list = TL:GetActiveList()
        if not list then
            TL.Print("no list yet. Open /tl and create one.")
            return
        end
        local word, count = rest:match("^(%S*)%s*(%d*)$")
        local specs = TL:PickSpecs(list.class or TL.playerClass)
        local spec = TL:MatchSpec(specs, word ~= "" and word or (list.fill and list.fill.spec))
        if not spec then
            TL.Print(#specs > 0 and ("which spec? /tl fill " .. table.concat(specs, " | ")) or
                "no GearQuest picks for this list's class (set it with Edit).")
            return
        end
        local n, removed = TL:FillFromPicks(list, spec, { places = tonumber(count), replace = TL:FillSettings().replace })
        if n then
            TL.Print(string.format("added %d GearQuest picks (%s) to %s%s.", n, spec, list.name,
                (removed or 0) > 0 and (", replaced " .. removed .. " earlier ones") or ""))
        else
            TL.Print(removed)
        end
    elseif cmd == "unfill" then
        local list = TL:GetActiveList()
        if list then
            local n = TL:RemoveFilled(list)
            TL.Print(n > 0 and string.format("removed %d GearQuest picks from %s. /tl undo brings them back.", n, list.name)
                or "this list has no GearQuest picks (items you re-tiered or moved count as yours).")
        end
    elseif cmd == "spec" then
        local word = rest:lower()
        TL.db.specOverride = TL.db.specOverride or {}
        if word == "auto" then
            TL.db.specOverride[TL.charKey] = nil
        elseif word ~= "" then
            local opts = TL.Spec.Options(TL.playerClass)
            local hit = TL:MatchSpec(opts, TL.Spec.ALIASES[word] or word)
            if not hit then
                TL.Print("unknown spec. Use one of: " .. table.concat(opts, ", ") .. ", or auto.")
                return
            end
            TL.db.specOverride[TL.charKey] = hit
        end
        TL.Spec.Recheck(true)
        TL.Print(TL.Spec.Describe())
    elseif cmd == "test" then
        if TL.Alerts then
            TL.Alerts:Test()
        end
    elseif cmd == "minimap" then
        if TL.MinimapButton then
            TL.MinimapButton:Toggle()
        end
    elseif cmd == "version" then
        TL.Print(TL.Version and TL.Version.Describe() or ("version " .. TL.VERSION))
    elseif SETTING_CMDS[cmd] then
        local key, label = SETTING_CMDS[cmd][1], SETTING_CMDS[cmd][2]
        TL.db.settings[key] = not TL.db.settings[key]
        TL.Print(label .. ": " .. (TL.db.settings[key] and "|cff00ff00on|r" or "|cffff5555off|r"))
    else
        Help()
    end
end
