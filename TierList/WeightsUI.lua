-- Stat weights tab (0.9.9): the stat weights and stat priorities of every class and spec, side by side per
-- source. Data\Weights.lua is built by build_weights.py from GearQuest Forever (numbers for every spec, what
-- Fill ranks by), Grayston's sheet (Shockadin EP) and ConquestCapped's stat priority pages (an order, no
-- numbers). Two tabs below the main window switch between the lists and this view.
local _, TL = ...
local UI = TL.UI
local Skin = TL.Skin
local GREY = "|cff9d9d9d"
local WHITE8 = "Interface\\Buttons\\WHITE8X8"

UI.view = "lists"

local PAD, TOP = 14, 30
local CLASS_W, SPEC_H, ROW_H = 66, 22, 16
local CARD_TOP = 92 -- below the class and spec rows

-- ---------------------------------------------------------------------------
-- Tabs below the window: a flat plate, accent line on the selected one (EllesmereUI's house tab look,
-- drawn by TierList itself so it does not depend on Blizzard's tab templates)
-- ---------------------------------------------------------------------------
local function Tab(parent, text, w)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(w, 24)
    b:SetBackdrop({ bgFile = WHITE8, edgeFile = WHITE8, edgeSize = 1 })
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.text:SetPoint("CENTER", 0, 1)
    b.text:SetText(text)
    Skin.Apply("Font", b.text)
    b.line = b:CreateTexture(nil, "OVERLAY")
    b.line:SetTexture(WHITE8)
    b.line:SetPoint("BOTTOMLEFT", 1, 1)
    b.line:SetPoint("BOTTOMRIGHT", -1, 1)
    b.line:SetHeight(2)
    Skin.Apply("Highlight", b, 0.12)
    function b:SetSelected(on)
        local p = Skin.PANEL
        self:SetBackdropColor(p[1], p[2], p[3], p[4])
        self:SetBackdropBorderColor(0, 0, 0, 1)
        local r, g, bl = Skin.Accent()
        self.line:SetVertexColor(r, g, bl, 1)
        self.line:SetShown(on)
        local c = on and 1 or 0.65
        self.text:SetTextColor(c, c, c)
        self.selected = on
    end
    return b
end

function UI:CreateTabs()
    local f = self.frame
    self.tabs = {}
    local prev
    for _, t in ipairs({ { "lists", "Lists" }, { "weights", "Stat weights" } }) do
        local b = Tab(f, t[2], 112)
        if prev then
            b:SetPoint("LEFT", prev, "RIGHT", 4, 0)
        else
            b:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 12, 2)
        end
        b:SetScript("OnClick", function() UI:SetView(t[1]) end)
        self.tabs[t[1]] = b
        prev = b
    end
    UI.Tip(self.tabs.weights, "Stat weights",
        "What each class and spec values on gear: the guides' stat priorities and GearQuest's weights, side by side.")
    Skin.OnLooksChanged(function() UI:UpdateTabs() end)
    self:UpdateTabs()
end

function UI:UpdateTabs()
    for view, b in pairs(self.tabs or {}) do
        b:SetSelected(view == self.view)
    end
end

function UI:SetView(view)
    self.view = view
    if self.listView then
        self.listView:SetShown(view == "lists")
    end
    if view == "weights" then
        self:CreateWeights()
        self.weightsView:Show()
        self:PickWeightDefaults()
        self:RefreshWeights()
    elseif self.weightsView then
        self.weightsView:Hide()
    end
    self:UpdateTabs()
    if view == "lists" then
        self:Refresh()
    end
end

-- ---------------------------------------------------------------------------
-- Data helpers
-- ---------------------------------------------------------------------------
local function SpecEntry(class, spec)
    for _, e in ipairs(TL.Weights and TL.Weights[class] or {}) do
        if e.spec == spec then
            return e
        end
    end
end

local function Num(v)
    local s = string.format("%.2f", v):gsub("0+$", ""):gsub("%.$", "")
    return s
end

local function StatLabel(key)
    return TL.WeightLabels and TL.WeightLabels[key] or key
end

-- "ConquestCapped by Kir", "Grayston", "GearQuest Forever 1.4.3"
local function SourceTitle(set)
    if set.source == "GearQuest" then
        return set.by or set.source
    end
    return set.source .. ((set.by and set.by ~= set.source) and (GREY .. " by " .. set.by .. "|r") or "")
end

-- which specs have a guide's own stat priority (for the empty card), "Balance, Feral, ..."
local function GuideSpecs()
    local by = {}
    local order = {}
    for _, class in ipairs(TL.CLASS_ORDER) do
        for _, e in ipairs(TL.Weights and TL.Weights[class] or {}) do
            for _, set in ipairs(e.sets) do
                if set.source ~= "GearQuest" then
                    if not by[set.source] then
                        by[set.source] = {}
                        order[#order + 1] = set.source
                    end
                    table.insert(by[set.source], TL.ClassText(class, TL.Spec.Label(e.spec)))
                end
            end
        end
    end
    local out = {}
    for _, src in ipairs(order) do
        out[#out + 1] = src .. ": " .. table.concat(by[src], ", ")
    end
    return table.concat(out, "\n")
end

-- the shown list's class and spec, else this character's class and talent tree, else the first entry
function UI:PickWeightDefaults()
    if self.weightClass and SpecEntry(self.weightClass, self.weightSpec) then
        return
    end
    local list = TL:GetActiveList()
    if list and list.class and SpecEntry(list.class, list.spec) then
        self.weightClass, self.weightSpec = list.class, list.spec
        return
    end
    local class = (list and list.class and TL.Weights[list.class]) and list.class or TL.playerClass
    if not (class and TL.Weights[class]) then
        class = TL.CLASS_ORDER[1]
    end
    self.weightClass = class
    local cur = TL.Spec and TL.Spec.Current()
    self.weightSpec = (cur and SpecEntry(class, cur)) and cur or TL.Weights[class][1].spec
end

function UI:SelectWeights(class, spec)
    self.weightClass = class
    if not SpecEntry(class, spec) then
        spec = TL.Weights[class] and TL.Weights[class][1] and TL.Weights[class][1].spec
    end
    self.weightSpec = spec
    self:RefreshWeights()
end

-- ---------------------------------------------------------------------------
-- Cards: one per source, rows of numbers (with a bar) or of the guide's order
-- ---------------------------------------------------------------------------
local function RowOnEnter(r)
    if not r.tip then
        return
    end
    GameTooltip:SetOwner(r, "ANCHOR_RIGHT")
    GameTooltip:AddLine(r.tipTitle or "", 1, 1, 1)
    GameTooltip:AddLine(r.tip, nil, nil, nil, true)
    GameTooltip:Show()
end

local function NewRow(card)
    local r = CreateFrame("Button", nil, card)
    r:SetHeight(ROW_H)
    r.bar = r:CreateTexture(nil, "BACKGROUND")
    r.bar:SetTexture(WHITE8)
    r.bar:SetPoint("TOPLEFT", 0, -2)
    r.bar:SetPoint("BOTTOMLEFT", 0, 2)
    r.num = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    r.num:SetPoint("LEFT", 4, 0)
    r.num:SetWidth(18)
    r.num:SetJustifyH("RIGHT")
    r.label = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.label:SetJustifyH("LEFT")
    r.label:SetWordWrap(false)
    r.value = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.value:SetPoint("RIGHT", -4, 0)
    r.value:SetJustifyH("RIGHT")
    for _, fs in ipairs({ r.num, r.label, r.value }) do
        Skin.Apply("Font", fs)
    end
    r:SetScript("OnEnter", RowOnEnter)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return r
end

local function NewCard(parent)
    local c = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    Skin.Apply("Panel", c, { inset = true })
    c.head = CreateFrame("Button", nil, c)
    c.head:SetPoint("TOPLEFT", 8, -6)
    c.head:SetPoint("TOPRIGHT", -8, -6)
    c.head:SetHeight(16)
    c.title = c.head:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    c.title:SetAllPoints()
    c.title:SetJustifyH("LEFT")
    c.title:SetWordWrap(false)
    c.sub = c:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    c.sub:SetPoint("TOPLEFT", c.head, "BOTTOMLEFT", 0, -2)
    c.sub:SetPoint("RIGHT", c, "RIGHT", -8, 0)
    c.sub:SetJustifyH("LEFT")
    c.sub:SetWordWrap(false)
    c.scale = c:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    c.scale:SetPoint("TOPLEFT", c.sub, "BOTTOMLEFT", 0, -2)
    c.scale:SetPoint("RIGHT", c, "RIGHT", -8, 0)
    c.scale:SetJustifyH("LEFT")
    c.scale:SetWordWrap(false)
    c.empty = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    c.empty:SetPoint("TOPLEFT", 10, -12)
    c.empty:SetPoint("RIGHT", c, "RIGHT", -10, 0)
    c.empty:SetJustifyH("LEFT")
    for _, fs in ipairs({ c.title, c.sub, c.scale, c.empty }) do
        Skin.Apply("Font", fs)
    end
    c.head:SetScript("OnEnter", function(self)
        local set = c.set
        if not set then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(SourceTitle(set), 1, 1, 1)
        if set.title then
            GameTooltip:AddLine(set.title, 0.85, 0.85, 0.85, true)
        end
        if set.date then
            GameTooltip:AddLine("Updated " .. set.date, 0.6, 0.6, 0.6)
        end
        if set.note then
            GameTooltip:AddLine(set.note, nil, nil, nil, true)
        end
        if set.url then
            GameTooltip:AddLine(set.url, 0.6, 0.6, 0.6, true)
        end
        GameTooltip:Show()
    end)
    c.head:SetScript("OnLeave", function() GameTooltip:Hide() end)
    c.rows = {}
    return c
end

-- rows to show for a set: { kind = "group"/"stat"/"order", ... }
local function SetRows(set)
    local out = {}
    if set.kind == "order" then
        for i, o in ipairs(set) do
            out[#out + 1] = { kind = "order", num = i, label = o[1], tip = o[2] }
        end
        return out
    end
    local point, pct = {}, {}
    for key, v in pairs(set.weights or {}) do
        local t = (TL.WeightPercent and TL.WeightPercent[key]) and pct or point
        t[#t + 1] = { key = key, value = v }
    end
    local function byValue(a, b)
        if a.value ~= b.value then
            return a.value > b.value
        end
        return StatLabel(a.key) < StatLabel(b.key)
    end
    for _, grp in ipairs({ { point, "per point" }, { pct, "per 1 %" } }) do
        local list = grp[1]
        if #list > 0 then
            table.sort(list, byValue)
            out[#out + 1] = { kind = "group", label = grp[2] }
            local max = list[1].value
            for _, s in ipairs(list) do
                local err = set.err and set.err[s.key]
                out[#out + 1] = { kind = "stat", key = s.key, label = StatLabel(s.key), value = s.value, err = err,
                                  frac = (max > 0) and (s.value / max) or 0 }
            end
        end
    end
    return out
end

local function FillCard(card, set, width, height)
    card.set = set
    for _, r in ipairs(card.rows) do
        r:Hide()
    end
    if not set then
        card.title:SetText(GREY .. "No guide stat priority for this spec|r")
        card.sub:SetText("")
        card.scale:SetText("")
        card.empty:SetText("TierList has guide stat priorities for:\n\n" .. GuideSpecs() ..
            "\n\nGearQuest's weights on the right cover every spec.")
        card.empty:Show()
        return
    end
    card.empty:Hide()
    card.title:SetText(Skin.AccentHex() .. SourceTitle(set) .. "|r")
    card.sub:SetText((set.title or "") .. (set.date and ("  -  " .. set.date) or ""))
    if set.kind == "order" then
        card.scale:SetText("The guide's order, most important first. Hover a stat for why.")
    elseif set.base then
        card.scale:SetText("Scale: 1 = " .. StatLabel(set.base) .. ". Higher is worth more.")
    else
        card.scale:SetText("Relative numbers on GearQuest's own scale. Higher is worth more.")
    end
    local rows = SetRows(set)
    local top = 58
    local rowH = math.min(ROW_H, math.floor((height - top - 8) / math.max(#rows, 1)))
    local r1, g1, b1 = Skin.Accent()
    for i, d in ipairs(rows) do
        local r = card.rows[i]
        if not r then
            r = NewRow(card)
            card.rows[i] = r
        end
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", card, "TOPLEFT", 6, -(top + (i - 1) * rowH))
        r:SetSize(width - 12, rowH)
        r.data = d
        r.tip, r.tipTitle = nil, nil
        r.bar:Hide()
        r.label:ClearAllPoints()
        if d.kind == "group" then
            r.num:SetText("")
            r.label:SetPoint("LEFT", 4, 0)
            r.label:SetPoint("RIGHT", -4, 0)
            r.label:SetText(GREY .. d.label .. "|r")
            r.value:SetText("")
        elseif d.kind == "order" then
            r.num:SetText(Skin.AccentHex() .. d.num .. "|r")
            r.label:SetPoint("LEFT", r.num, "RIGHT", 6, 0)
            r.label:SetPoint("RIGHT", -4, 0)
            r.label:SetText(d.label)
            r.value:SetText("")
            r.tip, r.tipTitle = d.tip, d.num .. ". " .. d.label
        else
            r.num:SetText("")
            r.label:SetPoint("LEFT", 8, 0)
            r.label:SetPoint("RIGHT", r.value, "LEFT", -6, 0)
            r.label:SetText(d.label)
            r.value:SetText(Num(d.value) .. (d.err and (GREY .. " +-" .. Num(d.err) .. "|r") or ""))
            r.bar:SetWidth(math.max(1, (width - 12) * d.frac))
            r.bar:SetVertexColor(r1, g1, b1, 0.22)
            r.bar:Show()
            if d.err then
                r.tip, r.tipTitle = "The guide reports an error of +-" .. Num(d.err) .. " for this weight.", d.label
            end
        end
        r:Show()
    end
end

-- ---------------------------------------------------------------------------
-- The view
-- ---------------------------------------------------------------------------
function UI:CreateWeights()
    if self.weightsView then
        return self.weightsView
    end
    local f = self.frame
    local v = CreateFrame("Frame", nil, f)
    v:SetAllPoints(f)
    self.weightsView = v
    self.classBtns = {}
    local prev
    for _, class in ipairs(TL.CLASS_ORDER) do
        local b = UI.Btn(v, TL.ClassText(class), CLASS_W, SPEC_H)
        if prev then
            b:SetPoint("LEFT", prev, "RIGHT", 4, 0)
        else
            b:SetPoint("TOPLEFT", PAD, -TOP)
        end
        b:SetScript("OnClick", function() UI:SelectWeights(class, UI.weightSpec) end)
        b.class = class
        self.classBtns[class] = b
        prev = b
    end
    self.specBtns = {}
    self.cards = { NewCard(v), NewCard(v) }
    v:Hide()
    return v
end

function UI:RefreshWeights()
    local v = self.weightsView
    if not v or not TL.Weights then
        return
    end
    local class, spec = self.weightClass, self.weightSpec
    for c, b in pairs(self.classBtns) do
        if c == class then
            b:LockHighlight()
        else
            b:UnlockHighlight()
        end
    end
    -- spec buttons for the class, as wide as fits
    local specs = TL.Weights[class] or {}
    local inner = (self.frame:GetWidth() or 660) - 2 * PAD
    local w = math.min(150, math.floor((inner - (#specs - 1) * 4) / math.max(#specs, 1)))
    for i, e in ipairs(specs) do
        local b = self.specBtns[i]
        if not b then
            b = UI.Btn(v, "", w, SPEC_H)
            local fs = b.GetFontString and b:GetFontString()
            if fs then
                fs:SetFontObject(GameFontNormalSmall)
                fs:SetWordWrap(false)
            end
            b:SetScript("OnClick", function(self) UI:SelectWeights(UI.weightClass, self.spec) end)
            self.specBtns[i] = b
        end
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", v, "TOPLEFT", PAD + (i - 1) * (w + 4), -(TOP + SPEC_H + 6))
        b:SetSize(w, SPEC_H)
        b.spec = e.spec
        local guide = false
        for _, set in ipairs(e.sets) do
            if set.source ~= "GearQuest" then
                guide = true
            end
        end
        -- a spec with a guide's own stat priority is marked with a star
        b:SetText(TL.Spec.Label(e.spec) .. (guide and " *" or ""))
        if e.spec == spec then
            b:LockHighlight()
        else
            b:UnlockHighlight()
        end
        b:Show()
    end
    for i = #specs + 1, #self.specBtns do
        self.specBtns[i]:Hide()
    end
    -- the cards: the guide left (or a note), GearQuest right
    local entry = SpecEntry(class, spec)
    local guide, gq
    for _, set in ipairs(entry and entry.sets or {}) do
        if set.source == "GearQuest" then
            gq = gq or set
        else
            guide = guide or set
        end
    end
    local cw = math.floor((inner - 8) / 2)
    local ch = (self.frame:GetHeight() or 600) - CARD_TOP - 16
    for i, set in ipairs({ guide or false, gq or false }) do
        local card = self.cards[i]
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", v, "TOPLEFT", PAD + (i - 1) * (cw + 8), -CARD_TOP)
        card:SetSize(cw, ch)
        FillCard(card, set or nil, cw, ch)
        card:Show()
    end
end

function UI:ShowWeights(class, spec)
    self:Show()
    if class then
        self.weightClass, self.weightSpec = class, spec
    end
    self:SetView("weights")
end
