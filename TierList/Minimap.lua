-- Minimap button: a LibDataBroker launcher shown by LibDBIcon (both embedded in Libs\).
-- Left-click opens/closes the window, right-click shows a quick menu, drag moves it around the minimap.
-- Broker displays (Titan Panel, ElvUI data texts, ...) pick up the same launcher.
local _, TL = ...
local Button = {}
TL.MinimapButton = Button

local NAME = "TierList"
local ICON = "Interface\\Icons\\INV_Misc_Note_05"
local GREY, YELLOW = "|cff9d9d9d", "|cffffd100"
local MAX_DROP_LINES = 8

local function Libs()
    local stub = _G.LibStub
    if not stub then
        return nil
    end
    return stub("LibDataBroker-1.1", true), stub("LibDBIcon-1.0", true)
end

-- Items of the active list that drop in the instance you are in (not equipped), best first.
function Button.DropsHere()
    local inInstance = TL.Plain(IsInInstance and IsInInstance())
    if not inInstance or not GetInstanceInfo then
        return nil
    end
    local name = TL.Plain((GetInstanceInfo()))
    local list = TL:GetActiveList()
    if not name or not list then
        return nil
    end
    local canon = (TL.InstanceAlias and TL.InstanceAlias[name:lower()]) or name
    local hits = {}
    for id, e in pairs(list.items) do
        if TL:SourceZone(id) == canon and not TL:IsEquipped(id) then
            hits[#hits + 1] = { id = id, e = e }
        end
    end
    table.sort(hits, function(a, b)
        local ra, rb = TL.TIER_RANK[a.e.tier] or 9, TL.TIER_RANK[b.e.tier] or 9
        if ra ~= rb then
            return ra < rb
        end
        return a.id < b.id
    end)
    return hits, canon
end

function Button.FillTooltip(tt)
    tt:AddLine("TierList " .. GREY .. TL.VERSION .. "|r")
    local list = TL:GetActiveList()
    if list then
        tt:AddLine("List: " .. TL:ListName(list, YELLOW) .. " " .. GREY .. "(" .. TL:CountItems(list) .. " items)|r", 1, 1, 1)
    else
        tt:AddLine("No list yet - open the window and make one.", 1, 1, 1)
    end
    local hits, zone = Button.DropsHere()
    if hits and #hits > 0 then
        tt:AddLine(" ")
        tt:AddLine("Drops in " .. zone .. ":")
        for i = 1, math.min(#hits, MAX_DROP_LINES) do
            local h = hits[i]
            local d = TL.ItemDB[h.id]
            tt:AddDoubleLine(TL.TierText(h.e.tier) .. " " .. TL:ColoredName(h.id), GREY .. ((d and d[7]) or "") .. "|r")
        end
        if #hits > MAX_DROP_LINES then
            tt:AddLine(GREY .. "... and " .. (#hits - MAX_DROP_LINES) .. " more|r")
        end
    end
    tt:AddLine(" ")
    tt:AddLine(GREY .. "Left-click:|r open / close", 1, 1, 1)
    tt:AddLine(GREY .. "Right-click:|r lists and options", 1, 1, 1)
    tt:AddLine(GREY .. "Drag:|r move around the minimap", 1, 1, 1)
end

function Button.OnClick(frame, button)
    if button == "RightButton" then
        if TL.UI and TL.UI.ShowQuickMenu then
            TL.UI:ShowQuickMenu(frame)
        end
    else
        TierList_Toggle()
    end
end

function Button:Setup()
    if self.registered then
        return
    end
    local ldb, icon = Libs()
    if not ldb or not icon then
        return
    end
    TL.db.minimap = TL.db.minimap or {}
    -- reuse the launcher if an earlier Setup got that far
    self.object = ldb:GetDataObjectByName(NAME) or ldb:NewDataObject(NAME, {
        type = "launcher",
        label = "TierList",
        icon = ICON,
        OnClick = function(frame, button)
            TL.Safe("minimap-click", Button.OnClick, frame, button)
        end,
        OnTooltipShow = function(tt)
            TL.Safe("minimap-tooltip", Button.FillTooltip, tt)
        end,
    })
    icon:Register(NAME, self.object, TL.db.minimap)
    self.registered = true
end

function Button:IsShown()
    return not (TL.db.minimap and TL.db.minimap.hide)
end

function Button:SetShown(show)
    TL.db.minimap = TL.db.minimap or {}
    TL.db.minimap.hide = not show
    local _, icon = Libs()
    if icon and self.registered then
        if show then
            icon:Show(NAME)
        else
            icon:Hide(NAME)
        end
    end
end

function Button:Toggle()
    self:SetShown(not self:IsShown())
    TL.Print("minimap button: " .. (self:IsShown() and "|cff00ff00on|r" or "|cffff5555off|r (/tl minimap brings it back)"))
end

TL:On("PLAYER_LOGIN", function()
    Button:Setup()
end)
