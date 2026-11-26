-- TierList tooltip lines: tier + place in slot for every list the item is on, upgrade hint, source.
local _, TL = ...
local Tooltip = {}
TL.Tooltip = Tooltip

local GREY = "|cff9d9d9d"
local GREEN = "|cff40ff40"
local YELLOW = "|cffffd100"

-- the list name in its class colour, tagged when it is an offspec list for this character
local function ListLabel(list)
    return TL:ListName(list) .. (TL:IsOffspec(list) and " |cff59a6ff(offspec)|r" or "")
end

-- Lines to add for an item id: { {left, right}, ... }
function Tooltip.Lines(id)
    local db = TL.db
    if not db or not db.settings.tooltip then
        return nil
    end
    -- only the lists this character uses (ticked); lists of other characters stay out (0.9.2)
    local lines = {}
    local inAnyList = false
    local mine = TL:ListsForChar()
    for i, list in ipairs(mine) do
        local e = TL:Entry(list, id)
        if e then
            inAnyList = true
            local place, slotKey = TL:PlaceInSlot(list, id)
            local slot = TL.SLOT_BY_KEY[slotKey]
            lines[#lines + 1] = {
                "|cff33ff99TierList|r " .. ListLabel(list),
                TL.TierText(e.tier) .. " " .. YELLOW .. (slot and slot.label or "") .. " #" .. (place or "?") .. "|r",
            }
            if i == 1 and e.note then
                lines[#lines + 1] = { "|cff7fbfff  " .. e.note .. "|r", wrap = true }
            end
            if i == 1 then
                local up, wornId, wornRank = TL:UpgradeInfo(list, id)
                if TL:IsEquipped(id) then
                    lines[#lines + 1] = { GREY .. "  equipped|r" }
                elseif up then
                    local worn = wornId and TL:Entry(list, wornId)
                    lines[#lines + 1] = { GREEN .. "  upgrade|r" .. GREY .. " (you wear " ..
                        (worn and TL.TierText(worn.tier) or "unranked") .. GREY .. ")|r" }
                elseif up == false then
                    local worn = wornId and TL:Entry(list, wornId)
                    lines[#lines + 1] = { GREY .. "  not an upgrade (you wear " ..
                        (worn and TL.TierText(worn.tier) or "?") .. GREY .. ")|r" }
                end
            end
        end
    end
    if inAnyList then
        lines[#lines + 1] = { GREY .. "  " .. TL:SourceShort(id) .. "|r" }
        local d = TL.ItemDB and TL.ItemDB[id]
        local detail = d and d[9]
        local chain = type(detail) == "string" and detail:match("(Quest chain.-%.)$")
        if chain then
            lines[#lines + 1] = { GREY .. "  " .. chain .. "|r", wrap = true }
        end
        local cost, vendor = TL:VendorCost(id)
        if cost and d and d[5] ~= "V" and not d[10] then
            lines[#lines + 1] = { GREY .. "  Buy: " .. cost .. (vendor and (" (" .. vendor .. ")") or "") .. "|r" }
        end
        local ah = TL:IsBoE(id) and TL:AHPrice(id)
        if ah then
            lines[#lines + 1] = { GREY .. "  Auction House: " .. TL.MoneyText(ah) .. " (Auctionator)|r" }
        end
    end
    return #lines > 0 and lines or nil
end

local function Add(tooltip, id, show)
    if not id or not tooltip or not tooltip.AddLine then
        return
    end
    -- the same tooltip can be processed twice for one item; add our lines once
    if tooltip.tierListShown == id then
        return
    end
    local lines = Tooltip.Lines(id)
    if not lines then
        return
    end
    tooltip.tierListShown = id
    for _, l in ipairs(lines) do
        if l[2] then
            tooltip:AddDoubleLine(l[1], l[2])
        else
            tooltip:AddLine(l[1], nil, nil, nil, l.wrap)
        end
    end
    if show and tooltip.Show then
        tooltip:Show()
    end
end

local function HookClear(tip)
    if tip and tip.HookScript and not tip.tierListClearHooked then
        tip.tierListClearHooked = true
        tip:HookScript("OnTooltipCleared", function(self)
            self.tierListShown = nil
        end)
    end
end

function Tooltip.Hook()
    if Tooltip.hooked then
        return
    end
    Tooltip.hooked = true
    for _, tip in ipairs({ GameTooltip, ItemRefTooltip, ShoppingTooltip1, ShoppingTooltip2 }) do
        HookClear(tip)
    end
    local hasProcessor = TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
        and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item
    if hasProcessor then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
            TL.Safe("tooltip", function()
                local id = data and TL.Plain(data.id)
                if not id and tooltip.GetItem then
                    local _, link = tooltip:GetItem()
                    id = TL.ItemIDFromLink(TL.Plain(link))
                end
                HookClear(tooltip)
                Add(tooltip, id, false)
            end)
        end)
        return
    end
    for _, tip in ipairs({ GameTooltip, ItemRefTooltip, ShoppingTooltip1, ShoppingTooltip2 }) do
        if tip and tip.HookScript then
            tip:HookScript("OnTooltipSetItem", function(self)
                TL.Safe("tooltip", function()
                    local _, link = self:GetItem()
                    Add(self, TL.ItemIDFromLink(TL.Plain(link)), true)
                end)
            end)
        end
    end
end
