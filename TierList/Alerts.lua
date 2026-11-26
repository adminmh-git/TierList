-- TierList alerts: a banner when a list item comes up for a roll or lies in the loot window,
-- chat lines for loot, and a "drops here" pop-up when entering a dungeon or raid.
local _, TL = ...
local Alerts = {}
TL.Alerts = Alerts

local Plain = TL.Plain
local GREY, GREEN = "|cff9d9d9d", "|cff40ff40"

-- ---------------------------------------------------------------------------
-- Matching an item against this character's lists
-- ---------------------------------------------------------------------------
-- Returns the best hit: { list, entry, upgrade, wornId, isActive, offspec }
-- Order: main-spec upgrade, offspec upgrade, main spec, offspec; the active list wins a tie.
function Alerts.Match(id)
    if not id or not TL.db then
        return nil
    end
    local best, bestScore = nil, 0
    for i, list in ipairs(TL:ListsForChar()) do
        local e = TL:Entry(list, id)
        if e then
            local up, wornId = TL:UpgradeInfo(list, id)
            local off = TL:IsOffspec(list)
            local score = (up and 2 or 0) + (off and 1 or 2)
            if score > bestScore then
                best = { list = list, entry = e, upgrade = up, wornId = wornId, isActive = (i == 1), offspec = off }
                bestScore = score
            end
            if bestScore == 4 then
                break
            end
        end
    end
    return best
end

-- " (offspec)" after a list name, or ""
local OFF = "|cff59a6ff"
local function OffTag(hit)
    return hit.offspec and (OFF .. " (offspec)|r") or ""
end
Alerts.OffTag = OffTag

-- ---------------------------------------------------------------------------
-- Banner
-- ---------------------------------------------------------------------------
local banner
local function CreateBanner()
    local f = CreateFrame("Button", "TierListAlertBanner", UIParent, "BackdropTemplate")
    f:SetSize(460, 74)
    f:SetPoint("TOP", UIParent, "TOP", 0, -150)
    f:SetFrameStrata("HIGH")
    TL.Skin.Apply("Panel", f)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint()
        TL.db.window.banner = { p, rp, x, y }
    end)
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(46, 46)
    f.icon:SetPoint("LEFT", 14, 0)
    TL.Skin.Apply("Icon", f.icon, f)
    -- coloured strip on the left: tier colour, orange for NEED
    f.stripe = f:CreateTexture(nil, "OVERLAY")
    f.stripe:SetWidth(3)
    f.stripe:SetPoint("TOPLEFT", 1, -1)
    f.stripe:SetPoint("BOTTOMLEFT", 1, 1)
    f.tier = f:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    f.tier:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 12, 2)
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("LEFT", f.tier, "RIGHT", 8, 0)
    f.title:SetPoint("RIGHT", f, "RIGHT", -12, 0)
    f.title:SetJustifyH("LEFT")
    f.line = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.line:SetPoint("TOPLEFT", f.tier, "BOTTOMLEFT", 0, -4)
    f.line:SetPoint("RIGHT", f, "RIGHT", -12, 0)
    f.line:SetJustifyH("LEFT")
    f.sub = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.sub:SetPoint("TOPLEFT", f.line, "BOTTOMLEFT", 0, -3)
    f.sub:SetPoint("RIGHT", f, "RIGHT", -12, 0)
    f.sub:SetJustifyH("LEFT")
    for _, fs in ipairs({ f.tier, f.title, f.line, f.sub }) do
        TL.Skin.Apply("Font", fs)
    end
    f:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    f:SetScript("OnClick", function(self, button)
        self:Hide()
        if button == "LeftButton" and TL.UI then
            TL.UI:Show()
        end
    end)
    f:SetScript("OnEnter", function(self)
        if self.itemId then
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetHyperlink("item:" .. self.itemId)
            GameTooltip:Show()
        end
        self.hold = true
    end)
    f:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
        self.hold = false
    end)
    f:SetScript("OnUpdate", function(self, elapsed)
        if self.hold then
            self:SetAlpha(1)
            return
        end
        self.left = (self.left or 0) - elapsed
        if self.left <= 0 then
            self:Hide()
        elseif self.left < 1 then
            self:SetAlpha(self.left)
        end
    end)
    f:Hide()
    return f
end

function Alerts.ShowBanner(id, hit, context)
    if not TL.db.settings.alerts then
        return
    end
    banner = banner or CreateBanner()
    local pos = TL.db.window.banner
    if pos then
        banner:ClearAllPoints()
        banner:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    end
    local _, _, icon = TL:ItemBasics(id)
    local slotKey = TL:SlotKeyFor(id, hit.entry)
    local slot = TL.SLOT_BY_KEY[slotKey]
    local place = TL:PlaceInSlot(hit.list, id)
    banner.itemId = id
    banner.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    banner.tier:SetText(TL.TierText(hit.entry.tier))
    local need = hit.upgrade and not hit.offspec
    local c = (need and { 1, 0.5, 0 }) or (hit.offspec and { 0.35, 0.65, 1 }) or TL.TIER_RGB[hit.entry.tier] or { 0.6, 0.6, 0.6 }
    banner.stripe:SetColorTexture(c[1], c[2], c[3], 1)
    if need then
        banner.title:SetText("|cffff8000NEED!|r  " .. context)
    elseif hit.offspec then
        banner.title:SetText(OFF .. "Offspec - Greed|r  " .. context)
    else
        banner.title:SetText("|cffffd100On your list|r  " .. context)
    end
    banner.line:SetText(TL:ColoredName(id) .. GREY .. "  " .. (slot and slot.label or "") .. " #" .. (place or "?") .. "|r")
    local worn = hit.wornId and TL:Entry(hit.list, hit.wornId)
    local wornText
    if TL:IsEquipped(id) then
        wornText = "already equipped"
    elseif hit.upgrade then
        wornText = GREEN .. "upgrade|r over " .. (hit.wornId and (TL:ColoredName(hit.wornId) .. " " .. (worn and TL.TierText(worn.tier) or GREY .. "unranked|r")) or "an empty slot")
    else
        wornText = "not an upgrade, you wear " .. (hit.wornId and (TL:ColoredName(hit.wornId) .. " " .. (worn and TL.TierText(worn.tier) or "")) or "?")
    end
    banner.sub:SetText(hit.list.name .. OffTag(hit) .. GREY .. " - |r" .. wornText)
    banner.left = 9
    banner:SetAlpha(1)
    banner:Show()
    if need and TL.db.settings.sound then
        local kit = SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959
        pcall(PlaySound, kit, "Master")
    end
end

local function ChatLine(msg)
    if TL.db.settings.chat then
        TL.Print(msg)
    end
end

local recent = {}
local function Throttled(key, seconds)
    local now = GetTime()
    if recent[key] and now - recent[key] < seconds then
        return true
    end
    recent[key] = now
    return false
end

-- ---------------------------------------------------------------------------
-- Loot roll (group loot)
-- ---------------------------------------------------------------------------
TL:On("START_LOOT_ROLL", function(rollID)
    if not GetLootRollItemLink then
        return
    end
    local ok, link = pcall(GetLootRollItemLink, rollID)
    local id = ok and TL.ItemIDFromLink(Plain(link))
    local hit = Alerts.Match(id)
    if not hit then
        return
    end
    Alerts.ShowBanner(id, hit, "roll")
    local lead = (hit.upgrade and not hit.offspec and "|cffff8000NEED|r on ") or
        (hit.offspec and (OFF .. "GREED|r (offspec) on ")) or "on your list: "
    ChatLine(lead .. TL:ItemLink(id) .. " - " .. TL.TierText(hit.entry.tier) .. " in " .. hit.list.name ..
        (hit.upgrade and "" or " (not an upgrade)"))
end)

-- ---------------------------------------------------------------------------
-- Loot window (solo, chests, master loot)
-- ---------------------------------------------------------------------------
TL:On("LOOT_OPENED", function()
    if not GetNumLootItems or not GetLootSlotLink then
        return
    end
    local n = Plain(GetNumLootItems()) or 0
    for slot = 1, n do
        local ok, link = pcall(GetLootSlotLink, slot)
        local id = ok and TL.ItemIDFromLink(Plain(link))
        local hit = Alerts.Match(id)
        if hit and not Throttled("loot" .. id, 20) then
            Alerts.ShowBanner(id, hit, "in loot")
            ChatLine("in the loot: " .. TL:ItemLink(id) .. " - " .. TL.TierText(hit.entry.tier) .. " in " .. hit.list.name .. OffTag(hit))
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Loot messages: you got it / someone else got it
-- ---------------------------------------------------------------------------
local function Prefix(fmt)
    return fmt and fmt:match("^(.-)%%s") or nil
end

TL:On("CHAT_MSG_LOOT", function(msg)
    msg = Plain(msg)
    if type(msg) ~= "string" then
        return
    end
    local id = TL.ItemIDFromLink(msg)
    local hit = Alerts.Match(id)
    if not hit then
        return
    end
    local mine = false
    for _, fmt in ipairs({ LOOT_ITEM_SELF, LOOT_ITEM_SELF_MULTIPLE, LOOT_ITEM_PUSHED_SELF,
        LOOT_ITEM_PUSHED_SELF_MULTIPLE, LOOT_ITEM_CREATED_SELF, LOOT_ITEM_CREATED_SELF_MULTIPLE }) do
        local p = Prefix(fmt)
        if p and p ~= "" and msg:sub(1, #p) == p then
            mine = true
            break
        end
    end
    if mine then
        if not Throttled("got" .. id, 5) then
            ChatLine(GREEN .. "got it!|r " .. TL:ItemLink(id) .. " - " .. TL.TierText(hit.entry.tier) .. " in " .. hit.list.name)
        end
        TL:Changed()
    else
        local who = msg:match("^(%S+)")
        if who and not Throttled("other" .. id, 5) then
            ChatLine(GREY .. who .. " got|r " .. TL:ItemLink(id) .. GREY .. " (your " .. "|r" ..
                TL.TierText(hit.entry.tier) .. GREY .. " in " .. hit.list.name .. ")|r")
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Dungeon / raid pop-up
-- ---------------------------------------------------------------------------
local popup
local function CreatePopup()
    local f = CreateFrame("Frame", "TierListInstancePopup", UIParent, "BackdropTemplate")
    f:SetSize(380, 60)
    f:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -220, -200)
    f:SetFrameStrata("HIGH")
    TL.Skin.Apply("Panel", f)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint()
        TL.db.window.popup = { p, rp, x, y }
    end)
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOPLEFT", 12, -10)
    f.title:SetPoint("RIGHT", -30, 0)
    f.title:SetJustifyH("LEFT")
    TL.Skin.Apply("Font", f.title)
    f.close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    f.close:SetPoint("TOPRIGHT", 2, 2)
    TL.Skin.Apply("CloseButton", f.close)
    f.lines = {}
    f:SetScript("OnUpdate", function(self, elapsed)
        if self:IsMouseOver() then
            self.left = math.max(self.left or 0, 3)
            self:SetAlpha(1)
            return
        end
        self.left = (self.left or 0) - elapsed
        if self.left <= 0 then
            self:Hide()
        elseif self.left < 1.5 then
            self:SetAlpha(self.left / 1.5)
        end
    end)
    f:Hide()
    return f
end

local function PopupLine(f, i)
    local b = f.lines[i]
    if b then
        return b
    end
    b = CreateFrame("Button", nil, f)
    b:SetHeight(18)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.text:SetAllPoints()
    b.text:SetJustifyH("LEFT")
    TL.Skin.Apply("Font", b.text)
    TL.Skin.Apply("Highlight", b, 0.06)
    b:SetScript("OnEnter", function(self)
        if self.itemId then
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:SetHyperlink("item:" .. self.itemId)
            GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.lines[i] = b
    return b
end

function Alerts.ShowInstancePopup(instanceName, hits)
    popup = popup or CreatePopup()
    local pos = TL.db.window.popup
    if pos then
        popup:ClearAllPoints()
        popup:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    end
    popup.title:SetText("|cff33ff99TierList|r - " .. #hits .. " of your items drop in " .. instanceName)
    local shown = math.min(#hits, 12)
    for i = 1, shown do
        local h = hits[i]
        local b = PopupLine(popup, i)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", popup, "TOPLEFT", 14, -28 - (i - 1) * 18)
        b:SetPoint("RIGHT", popup, "RIGHT", -12, 0)
        b.itemId = h.id
        local d = TL.ItemDB[h.id]
        local who = d and d[7]
        local rate = d and d[8]
        local state = TL:ItemState(h.id) == "owned" and (GREEN .. " (have it)|r") or ""
        local off = h.offspec and (OFF .. "  offspec: " .. h.list.name .. "|r") or ""
        b.text:SetText(TL.TierText(h.entry.tier) .. " " .. TL:ColoredName(h.id) .. state .. GREY .. "  " ..
            (who or "") .. (rate and string.format(" %.0f%%", rate) or "") .. "|r" .. off)
        b:Show()
    end
    for i = shown + 1, #popup.lines do
        popup.lines[i]:Hide()
    end
    popup:SetHeight(40 + shown * 18)
    popup.left = 25
    popup:SetAlpha(1)
    popup:Show()
end

local lastInstance
local function CheckInstance()
    if not TL.db or not TL.db.settings.popup then
        return
    end
    local inInstance = Plain(IsInInstance())
    if not inInstance then
        lastInstance = nil
        return
    end
    local name = Plain((GetInstanceInfo()))
    if not name or name == lastInstance then
        return
    end
    lastInstance = name
    local canon = (TL.InstanceAlias and TL.InstanceAlias[name:lower()]) or name
    -- one row per item; a main-spec list beats an offspec one, then the first (active) list
    local hits, seen = {}, {}
    for _, list in ipairs(TL:ListsForChar()) do
        local off = TL:IsOffspec(list)
        for id, e in pairs(list.items) do
            local h = seen[id]
            if (not h or (h.offspec and not off)) and TL:SourceZone(id) == canon and not TL:IsEquipped(id) then
                if not h then
                    h = { id = id }
                    seen[id] = h
                    hits[#hits + 1] = h
                end
                h.entry, h.list, h.offspec = e, list, off
            end
        end
    end
    if #hits == 0 then
        return
    end
    -- main spec first, then by tier
    table.sort(hits, function(a, b)
        if a.offspec ~= b.offspec then
            return not a.offspec
        end
        local ra, rb = TL.TIER_RANK[a.entry.tier] or 9, TL.TIER_RANK[b.entry.tier] or 9
        if ra ~= rb then
            return ra < rb
        end
        return a.id < b.id
    end)
    Alerts.ShowInstancePopup(canon, hits)
end

TL:On("PLAYER_ENTERING_WORLD", function()
    C_Timer.After(2, function() TL.Safe("instance", CheckInstance) end)
end)
TL:On("ZONE_CHANGED_NEW_AREA", function()
    C_Timer.After(1, function() TL.Safe("instance", CheckInstance) end)
end)

-- ---------------------------------------------------------------------------
-- Test
-- ---------------------------------------------------------------------------
function Alerts:Test()
    local list = TL:GetActiveList()
    if not list then
        TL.Print("no active list.")
        return
    end
    local pick
    for _, slot in ipairs(TL.SLOTS) do
        for _, row in ipairs(TL:SlotItems(list, slot.key)) do
            if not TL:IsEquipped(row.id) then
                pick = row
                break
            end
        end
        if pick then
            break
        end
    end
    if not pick then
        TL.Print("every item on " .. list.name .. " is already equipped.")
        return
    end
    local up, wornId = TL:UpgradeInfo(list, pick.id)
    Alerts.ShowBanner(pick.id, { list = list, entry = pick.e, upgrade = up, wornId = wornId, isActive = true }, "(test)")
end
