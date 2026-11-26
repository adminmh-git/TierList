-- TierList window: one row per gear slot, items sorted S > A > B > C, plus search, import/export
-- and list management. No character model, just a list.
local _, TL = ...
local UI = {}
TL.UI = UI

local WIDTH, HEIGHT = 660, 600
local ROW_H, HEAD_H, HINT_H = 34, 24, 26
local GREY, GREEN, YELLOW = "|cff9d9d9d", "|cff40ff40", "|cffffd100"
local Skin = TL.Skin

UI.addTier = "S"
UI.scope = "list"
UI.query = ""
UI.rows = {}

-- ---------------------------------------------------------------------------
-- Widget helpers
-- ---------------------------------------------------------------------------
local function SetTex(tex, ...)
    for i = 1, select("#", ...) do
        local path = select(i, ...)
        local ok, res = pcall(tex.SetTexture, tex, path)
        if ok and res ~= false then
            return
        end
    end
end

local function Btn(parent, text, w, h)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, h or 22)
    b:SetText(text)
    Skin.Apply("Button", b)
    return b
end

local function Input(parent, w)
    local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    eb:SetSize(w, 20)
    eb:SetAutoFocus(false)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    eb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    Skin.Apply("EditBox", eb)
    return eb
end

local function Check(parent, text)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(22, 22)
    Skin.Apply("Checkbox", cb)
    cb.label = cb.Text or cb.text
    if not cb.label then
        cb.label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        cb.label:SetPoint("LEFT", cb, "RIGHT", 2, 0)
        Skin.Apply("Font", cb.label)
    end
    cb.label:SetText(text or "")
    return cb
end

local function Placeholder(eb, text)
    local ph = eb:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    ph:SetPoint("LEFT", eb, "LEFT", 2, 0)
    ph:SetPoint("RIGHT", eb, "RIGHT", -4, 0)
    ph:SetJustifyH("LEFT")
    ph:SetText(text)
    Skin.Apply("Font", ph)
    local function update()
        if eb:GetText() == "" and not eb:HasFocus() then
            ph:Show()
        else
            ph:Hide()
        end
    end
    eb:HookScript("OnTextChanged", update)
    eb:HookScript("OnEditFocusGained", update)
    eb:HookScript("OnEditFocusLost", update)
    update()
    eb.placeholder = ph
end

local function Label(parent, text, font)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
    fs:SetText(text or "")
    fs:SetJustifyH("LEFT")
    Skin.Apply("Font", fs)
    return fs
end

local function TierButton(parent, size)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(size, size)
    b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.text:SetPoint("CENTER", 0, 0)
    Skin.Apply("Font", b.text)
    Skin.Apply("Highlight", b, 0.15)
    function b:SetTier(t, dim, selected)
        local c = TL.TIER_RGB[t or ""] or { 0.35, 0.35, 0.35 }
        self:SetBackdropColor(c[1], c[2], c[3], dim and 0.25 or 0.9)
        if selected then
            self:SetBackdropBorderColor(1, 1, 1, 1)
        else
            self:SetBackdropBorderColor(0, 0, 0, 0.9)
        end
        self.text:SetText(t or "-")
        self.text:SetTextColor(1, 1, 1, dim and 0.6 or 1)
    end
    return b
end

local function IconButton(parent, size, ...)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    local t = b:CreateTexture(nil, "ARTWORK")
    t:SetAllPoints()
    SetTex(t, ...)
    b.tex = t
    Skin.Apply("Highlight", b, 0.12)
    return b
end

local function Tip(frame, title, text)
    frame:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(title, 1, 1, 1)
        if text then
            GameTooltip:AddLine(text, nil, nil, nil, true)
        end
        GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

local function MultiLineBox(parent, w, h)
    local holder = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    holder:SetSize(w, h)
    Skin.Apply("Panel", holder, { inset = true })
    local sf = CreateFrame("ScrollFrame", nil, holder, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 6, -6)
    sf:SetPoint("BOTTOMRIGHT", -26, 6)
    Skin.Apply("ScrollBar", sf.ScrollBar)
    local eb = CreateFrame("EditBox", nil, sf)
    eb:SetMultiLine(true)
    eb:SetAutoFocus(false)
    eb:SetFontObject(GameFontHighlightSmall)
    eb:SetWidth(w - 36)
    eb:SetHeight(h - 12)
    eb:SetMaxLetters(0)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    eb:SetScript("OnTextChanged", function() sf:UpdateScrollChildRect() end)
    eb:SetScript("OnCursorChanged", function(_, _, y, _, ch)
        local top = -y
        local scroll = sf:GetVerticalScroll()
        local height = sf:GetHeight()
        if top < scroll then
            sf:SetVerticalScroll(top)
        elseif top + ch > scroll + height then
            sf:SetVerticalScroll(math.max(0, top + ch - height))
        end
    end)
    sf:SetScrollChild(eb)
    holder:EnableMouse(true)
    holder:SetScript("OnMouseDown", function() eb:SetFocus() end)
    holder.edit = eb
    holder.scroll = sf
    return holder
end

local function Dialog(name, w, h, title)
    local f = CreateFrame("Frame", name, UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(w, h)
    f:SetPoint("CENTER", 0, 40)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    local t = f.TitleText or f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    if not f.TitleText then
        t:SetPoint("TOP", 0, -5)
    end
    t:SetText(title)
    f.titleText = t
    Skin.Apply("Shell", f)
    if not f.TitleText then
        Skin.Apply("Font", t)
    end
    tinsert(UISpecialFrames, name)
    f:Hide()
    return f
end

-- ---------------------------------------------------------------------------
-- Small popup menu
-- ---------------------------------------------------------------------------
local menu
local function MenuButton(i)
    local b = menu.buttons[i]
    if b then
        return b
    end
    b = CreateFrame("Button", nil, menu)
    b:SetHeight(18)
    Skin.Apply("Highlight", b, 0.08)
    b.check = b:CreateTexture(nil, "ARTWORK")
    b.check:SetSize(14, 14)
    b.check:SetPoint("LEFT", 2, 0)
    SetTex(b.check, "Interface\\Buttons\\UI-CheckBox-Check")
    b.check:SetDesaturated(true) -- tinted with the accent colour in ShowMenu
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.text:SetPoint("LEFT", 18, 0)
    b.text:SetJustifyH("LEFT")
    Skin.Apply("Font", b.text)
    b:SetScript("OnClick", function(self)
        local entry = self.entry
        if not entry or entry.isTitle or entry.disabled then
            return
        end
        if not entry.keepOpen then
            menu:Hide()
        end
        if entry.func then
            TL.Safe("menu", entry.func)
        end
    end)
    menu.buttons[i] = b
    return b
end

function UI:ShowMenu(anchor, entries)
    if not menu then
        menu = CreateFrame("Frame", "TierListMenu", UIParent, "BackdropTemplate")
        menu:SetFrameStrata("FULLSCREEN_DIALOG")
        menu:SetClampedToScreen(true)
        Skin.Apply("Panel", menu)
        menu:EnableMouse(true)
        menu.buttons = {}
        menu:SetScript("OnEvent", function(self)
            if self:IsShown() and not self:IsMouseOver() then
                self:Hide()
            end
        end)
        menu:SetScript("OnHide", function(self)
            self.hiddenAt = GetTime()
        end)
        pcall(menu.RegisterEvent, menu, "GLOBAL_MOUSE_DOWN")
        tinsert(UISpecialFrames, "TierListMenu")
    end
    -- a click on the same button that just closed the menu should not reopen it
    if menu.anchor == anchor and menu.hiddenAt and GetTime() - menu.hiddenAt < 0.15 then
        return
    end
    menu.anchor = anchor
    local width = 120
    for i, entry in ipairs(entries) do
        local b = MenuButton(i)
        b.entry = entry
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", menu, "TOPLEFT", 6, -6 - (i - 1) * 18)
        b:SetPoint("RIGHT", menu, "RIGHT", -6, 0)
        b.text:SetText(entry.text or "")
        b.check:SetVertexColor(Skin.Accent())
        if entry.isTitle then
            b.text:SetTextColor(Skin.Accent())
            b:Disable()
        else
            if entry.disabled then
                b:Disable()
                b.text:SetTextColor(0.5, 0.5, 0.5)
            else
                b:Enable()
                b.text:SetTextColor(1, 1, 1)
            end
        end
        b.check:SetShown(entry.checked and true or false)
        b:Show()
        width = math.max(width, b.text:GetStringWidth() + 34)
    end
    for i = #entries + 1, #menu.buttons do
        menu.buttons[i]:Hide()
    end
    menu:SetSize(width, 12 + #entries * 18)
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
    menu:Show()
end

-- ---------------------------------------------------------------------------
-- Links: shift-click puts items into our boxes
-- ---------------------------------------------------------------------------
local function TakeLink(text)
    if type(text) ~= "string" then
        return
    end
    if UI.addBox and UI.addBox:HasFocus() then
        UI.addBox:Insert(text)
    elseif UI.importBox and UI.importBox.edit:HasFocus() then
        UI.importBox.edit:Insert(text .. "\n")
    elseif UI.search and UI.search:HasFocus() then
        local name = text:match("|h%[(.-)%]|h")
        if name then
            UI.search:SetText(name)
        end
    end
end

function UI.HookLinks()
    if UI.linksHooked then
        return
    end
    UI.linksHooked = true
    if ChatFrameUtil and ChatFrameUtil.InsertLink then
        hooksecurefunc(ChatFrameUtil, "InsertLink", function(text) TL.Safe("links", TakeLink, text) end)
    elseif ChatEdit_InsertLink then
        hooksecurefunc("ChatEdit_InsertLink", function(text) TL.Safe("links", TakeLink, text) end)
    end
end

local function InsertChatLink(link)
    if ChatFrameUtil and ChatFrameUtil.InsertLink then
        return ChatFrameUtil.InsertLink(link)
    elseif ChatEdit_InsertLink then
        return ChatEdit_InsertLink(link)
    end
end

-- Item on the cursor (dragged from bags or the character sheet)
local function CursorItem()
    local kind, id, link = GetCursorInfo()
    if kind == "item" then
        return tonumber(id) or TL.ItemIDFromLink(link)
    end
end

local function DropOnto(slotKey)
    local id = CursorItem()
    if not id then
        return
    end
    ClearCursor()
    local list = TL:GetActiveList()
    if not list then
        TL.Print("create a list first.")
        return
    end
    local override
    -- one-handers can be listed under Off Hand by dropping them on that slot
    if slotKey == "OFFHAND" and TL:EquipLoc(id) == "INVTYPE_WEAPON" then
        override = "OFFHAND"
    end
    local res = TL:AddItem(list, id, UI.addTier, override)
    TL.Print((res == "added" and "added " or "moved ") .. TL:ColoredName(id) .. " as " .. TL.TierText(UI.addTier) .. ".")
    TL:Changed()
end

-- ---------------------------------------------------------------------------
-- Main window
-- ---------------------------------------------------------------------------
function UI:Create()
    if self.frame then
        return self.frame
    end
    local f = CreateFrame("Frame", "TierListFrame", UIParent, "BasicFrameTemplateWithInset")
    self.frame = f
    f:SetSize(WIDTH, HEIGHT)
    local pos = TL.db.window.main
    if pos then
        f:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    else
        f:SetPoint("CENTER")
    end
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint()
        TL.db.window.main = { p, rp, x, y }
    end)
    f:SetScript("OnShow", function() UI:Refresh() end)
    tinsert(UISpecialFrames, "TierListFrame")
    Skin.Apply("Shell", f)
    local title = f.TitleText or f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    if not f.TitleText then
        title:SetPoint("TOP", 0, -5)
        Skin.Apply("Font", title)
    end
    title:SetText("TierList " .. GREY .. TL.VERSION .. "|r")

    -- row 1: list + actions
    local listBtn = Btn(f, "List", 180)
    listBtn:SetPoint("TOPLEFT", 14, -30)
    listBtn:SetScript("OnClick", function(self) UI:ShowListMenu(self) end)
    self.listBtn = listBtn
    local newBtn = Btn(f, "New", 58)
    newBtn:SetPoint("LEFT", listBtn, "RIGHT", 6, 0)
    newBtn:SetScript("OnClick", function() UI:ShowEdit(nil) end)
    Tip(newBtn, "New list", "Make a new tier list, for example for another build or another character.")
    local editBtn = Btn(f, "Edit", 58)
    editBtn:SetPoint("LEFT", newBtn, "RIGHT", 4, 0)
    editBtn:SetScript("OnClick", function()
        local list = TL:GetActiveList()
        if list then
            UI:ShowEdit(list)
        end
    end)
    Tip(editBtn, "Edit list", "Name, build, class and which characters use this list.")
    local importBtn = Btn(f, "Import", 70)
    importBtn:SetPoint("LEFT", editBtn, "RIGHT", 4, 0)
    importBtn:SetScript("OnClick", function() UI:ShowImport() end)
    Tip(importBtn, "Import", "Paste a TierList string, a wowsims or Sixty Upgrades export, Wowhead links, item IDs or item names.")
    local exportBtn = Btn(f, "Export", 70)
    exportBtn:SetPoint("LEFT", importBtn, "RIGHT", 4, 0)
    exportBtn:SetScript("OnClick", function() UI:ShowExport() end)
    Tip(exportBtn, "Export", "Copy this list as a string for friends or as plain text.")
    local fillBtn = Btn(f, "Fill", 52)
    fillBtn:SetPoint("LEFT", exportBtn, "RIGHT", 4, 0)
    fillBtn:SetScript("OnClick", function() UI:ShowFill() end)
    Tip(fillBtn, "Fill from GearQuest", "Add GearQuest Forever's ranked level-60 items for a spec to every slot (A/B/C below your own picks). Choose sources (dungeons, crafted, no PvP, ...) and quality.")
    local optBtn = Btn(f, "Options", 76)
    optBtn:SetPoint("LEFT", fillBtn, "RIGHT", 4, 0)
    optBtn:SetScript("OnClick", function(self) UI:ShowOptionsMenu(self) end)

    -- row 2: search + scope
    local search = CreateFrame("EditBox", nil, f, "SearchBoxTemplate")
    search:SetSize(250, 20)
    search:SetPoint("TOPLEFT", 20, -60)
    search:SetAutoFocus(false)
    Skin.Apply("EditBox", search)
    if search.Instructions then
        search.Instructions:SetText("Search name, ID, boss, zone")
    end
    search:HookScript("OnTextChanged", function(self)
        UI.query = self:GetText() or ""
        UI:Refresh()
    end)
    self.search = search
    local scopeList = Btn(f, "This list", 84)
    scopeList:SetPoint("LEFT", search, "RIGHT", 8, 0)
    scopeList:SetScript("OnClick", function()
        UI.scope = "list"
        UI:Refresh()
    end)
    Tip(scopeList, "Search this list", "Filter the items of the active list.")
    local scopeAll = Btn(f, "All items", 84)
    scopeAll:SetPoint("LEFT", scopeList, "RIGHT", 4, 0)
    scopeAll:SetScript("OnClick", function()
        UI.scope = "all"
        UI:Refresh()
        search:SetFocus()
    end)
    Tip(scopeAll, "Search all items", "Search every WoW Forever item TierList knows, then add it with + (uses the tier picked at the bottom).")
    self.scopeList, self.scopeAll = scopeList, scopeAll
    local info = Label(f, "", "GameFontDisableSmall")
    info:SetPoint("LEFT", scopeAll, "RIGHT", 10, 0)
    info:SetPoint("RIGHT", f, "RIGHT", -16, 0)
    info:SetJustifyH("RIGHT")
    self.info = info

    -- list area
    local sf = CreateFrame("ScrollFrame", "TierListScroll", f, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 12, -88)
    sf:SetPoint("BOTTOMRIGHT", -32, 48)
    Skin.Apply("ScrollBar", sf.ScrollBar or _G.TierListScrollScrollBar)
    local content = CreateFrame("Frame", nil, sf)
    content:SetSize(WIDTH - 44, 10)
    sf:SetScrollChild(content)
    self.scroll, self.content = sf, content
    content:EnableMouse(true)
    content:SetScript("OnReceiveDrag", function() DropOnto(nil) end)
    content:SetScript("OnMouseUp", function() DropOnto(nil) end)

    -- bottom: add bar
    local addBox = Input(f, 270)
    addBox:SetPoint("BOTTOMLEFT", 22, 16)
    Placeholder(addBox, "Item link, ID or name (Shift-click / drag an item)")
    addBox:SetScript("OnEnterPressed", function(self)
        if TL:AddFromText(self:GetText(), UI.addTier) then
            self:SetText("")
        end
    end)
    addBox:SetScript("OnReceiveDrag", function(self)
        local id = CursorItem()
        if id then
            ClearCursor()
            self:SetText(tostring(id))
            TL:AddFromText(tostring(id), UI.addTier)
            self:SetText("")
        end
    end)
    self.addBox = addBox
    local tierLabel = Label(f, "Tier", "GameFontNormalSmall")
    tierLabel:SetPoint("LEFT", addBox, "RIGHT", 10, 0)
    self.tierPick = {}
    local prev = tierLabel
    for _, t in ipairs(TL.TIERS) do
        local b = TierButton(f, 22)
        b:SetPoint("LEFT", prev, "RIGHT", 4, 0)
        b:SetScript("OnClick", function()
            UI.addTier = t
            UI:UpdateTierPick()
        end)
        Tip(b, "Add as " .. t, "New items go into this tier. Also used by + in the search and by drag and drop.")
        self.tierPick[t] = b
        prev = b
    end
    local addBtn = Btn(f, "Add", 56)
    addBtn:SetPoint("LEFT", prev, "RIGHT", 8, 0)
    addBtn:SetScript("OnClick", function()
        if TL:AddFromText(addBox:GetText(), UI.addTier) then
            addBox:SetText("")
        end
        addBox:ClearFocus()
    end)
    local hint = Label(f, GREY .. "Right-click a row for more|r", "GameFontDisableSmall")
    hint:SetPoint("LEFT", addBtn, "RIGHT", 10, 0)
    hint:SetPoint("RIGHT", f, "RIGHT", -16, 0)
    self:UpdateTierPick()
    f:Hide()
    return f
end

function UI:UpdateTierPick()
    for t, b in pairs(self.tierPick or {}) do
        b:SetTier(t, t ~= self.addTier, t == self.addTier)
    end
end

function UI:Show()
    self:Create():Show()
end

function UI:Toggle()
    local f = self:Create()
    if f:IsShown() then
        f:Hide()
    else
        f:Show()
    end
end

-- ---------------------------------------------------------------------------
-- Rows
-- ---------------------------------------------------------------------------
local function RowOnEnter(self)
    local d = self.data
    if not d or not d.id then
        return
    end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink("item:" .. d.id)
    local detail = TL:SourceDetail(d.id)
    if detail and detail ~= "" then
        GameTooltip:AddLine(detail, 0.75, 0.75, 0.75, true)
    end
    GameTooltip:Show()
end

local function RowOnClick(self, button)
    local d = self.data
    if not d then
        return
    end
    if d.type == "header" then
        if d.hint then
            return
        end
        if button == "LeftButton" and not CursorItem() then
            local key = d.listId .. ":" .. d.slot.key
            TL.db.collapsed[key] = not TL.db.collapsed[key] or nil
            UI:Refresh()
        else
            DropOnto(d.slot.key)
        end
        return
    end
    if not d.id then
        return
    end
    if CursorItem() then
        DropOnto(nil)
        return
    end
    if button == "RightButton" then
        UI:ShowItemMenu(self, d)
        return
    end
    local link = TL:ItemLink(d.id)
    if IsModifiedClick("CHATLINK") then
        InsertChatLink(link)
    elseif IsModifiedClick("DRESSUP") and DressUpItemLink then
        DressUpItemLink(link)
    end
end

local function CreateRow(content)
    local r = CreateFrame("Button", nil, content)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    Skin.Apply("Highlight", r, 0.05)
    r:SetScript("OnEnter", RowOnEnter)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r:SetScript("OnClick", RowOnClick)
    r:SetScript("OnReceiveDrag", function(self)
        DropOnto(self.data and self.data.type == "header" and self.data.slot.key or nil)
    end)

    -- header parts
    r.toggle = r:CreateTexture(nil, "ARTWORK")
    r.toggle:SetSize(14, 14)
    r.toggle:SetPoint("LEFT", 4, 0)
    r.headText = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    r.headText:SetPoint("LEFT", r.toggle, "RIGHT", 6, 0)
    r.headText:SetJustifyH("LEFT")
    r.wornText = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.wornText:SetPoint("RIGHT", -6, 0)
    r.wornText:SetPoint("LEFT", r.headText, "RIGHT", 10, 0)
    r.wornText:SetJustifyH("RIGHT")
    r.wornText:SetWordWrap(false)
    r.hintText = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.hintText:SetPoint("LEFT", 6, 0)
    r.hintText:SetPoint("RIGHT", -6, 0)
    r.hintText:SetJustifyH("LEFT")
    r.rule = r:CreateTexture(nil, "BACKGROUND")
    r.rule:SetHeight(1)
    r.rule:SetPoint("BOTTOMLEFT", 0, 0)
    r.rule:SetPoint("BOTTOMRIGHT", 0, 0)

    -- item parts
    r.place = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    r.place:SetPoint("LEFT", 2, 0)
    r.place:SetWidth(26)
    r.place:SetJustifyH("RIGHT")
    r.tierBtn = TierButton(r, 24)
    r.tierBtn:SetPoint("LEFT", 32, 0)
    r.tierBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    r.tierBtn:SetScript("OnClick", function(self, button)
        local d = self:GetParent().data
        UI:TierClick(d, button)
    end)
    r.tierBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Tier", 1, 1, 1)
        GameTooltip:AddLine("Left-click: lower tier (S > A > B > C > S)\nRight-click: higher tier", nil, nil, nil, true)
        GameTooltip:Show()
    end)
    r.tierBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- the icon sits in its own frame so a skin's icon border hides together with it on header rows
    r.iconFrame = CreateFrame("Frame", nil, r)
    r.iconFrame:SetSize(26, 26)
    r.iconFrame:SetPoint("LEFT", r.tierBtn, "RIGHT", 6, 0)
    r.icon = r.iconFrame:CreateTexture(nil, "ARTWORK")
    r.icon:SetAllPoints()
    Skin.Apply("Icon", r.icon, r.iconFrame)
    r.name = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 7, 1)
    r.name:SetPoint("RIGHT", r, "RIGHT", -150, 0)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)
    r.source = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    r.source:SetPoint("BOTTOMLEFT", r.icon, "BOTTOMRIGHT", 7, 0)
    r.source:SetPoint("RIGHT", r, "RIGHT", -64, 0)
    r.source:SetJustifyH("LEFT")
    r.source:SetWordWrap(false)
    r.state = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    r.state:SetPoint("TOPRIGHT", r, "TOPRIGHT", -64, -4)
    r.state:SetJustifyH("RIGHT")

    r.up = IconButton(r, 16, "Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Up", "Interface\\Buttons\\Arrow-Up-Up")
    r.up:SetPoint("RIGHT", -42, 0)
    r.up:SetScript("OnClick", function(self) UI:Move(self:GetParent().data, -1) end)
    r.down = IconButton(r, 16, "Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up", "Interface\\Buttons\\Arrow-Down-Up")
    r.down:SetPoint("RIGHT", -22, 0)
    r.down:SetScript("OnClick", function(self) UI:Move(self:GetParent().data, 1) end)
    r.del = IconButton(r, 16, "Interface\\Buttons\\UI-GroupLoot-Pass-Up", "Interface\\Buttons\\UI-StopButton")
    r.del:SetPoint("RIGHT", -2, 0)
    r.del:SetScript("OnClick", function(self) UI:Remove(self:GetParent().data) end)
    Tip(r.del, "Remove", "Removes the item from this list. /tl undo brings it back.")
    r.add = IconButton(r, 18, "Interface\\Buttons\\UI-PlusButton-Up")
    r.add:SetPoint("RIGHT", -2, 0)
    r.add:SetScript("OnClick", function(self) UI:AddFromSearch(self:GetParent().data) end)
    Tip(r.add, "Add to list", "Adds the item to the active list with the tier picked at the bottom.")
    for _, k in ipairs({ "headText", "wornText", "hintText", "place", "name", "source", "state" }) do
        Skin.Apply("Font", r[k])
    end
    return r
end

local HEADER_PARTS = { "toggle", "headText", "wornText", "hintText", "rule" }
local ITEM_PARTS = { "place", "tierBtn", "iconFrame", "name", "source", "state", "up", "down", "del", "add" }

local function ShowParts(r, parts, show)
    for _, k in ipairs(parts) do
        r[k]:SetShown(show)
    end
end

local function WornText(list, slot)
    local parts = {}
    for _, inv in ipairs(slot.inv) do
        local id = TL.equipped and TL.equipped[inv]
        if id then
            local e = TL:Entry(list, id)
            parts[#parts + 1] = TL:ColoredName(id) .. " " .. (e and TL.TierText(e.tier) or GREY .. "(not listed)|r")
        end
    end
    if #parts == 0 then
        return ""
    end
    return GREY .. "worn:|r " .. table.concat(parts, GREY .. ", |r")
end

function UI:SetHeader(r, d)
    ShowParts(r, ITEM_PARTS, false)
    ShowParts(r, HEADER_PARTS, true)
    r:SetHeight(HEAD_H)
    if d.hint then
        r.toggle:Hide()
        r.rule:Hide()
        r.headText:Hide()
        r.wornText:Hide()
        r.hintText:SetText(d.text)
        return
    end
    r.hintText:Hide()
    local ar, ag, ab = Skin.Accent()
    r.headText:SetTextColor(ar, ag, ab)
    r.rule:SetColorTexture(ar, ag, ab, 0.35)
    SetTex(r.toggle, d.collapsed and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
    local count = d.count > 0 and (GREY .. " (" .. d.count .. ")|r") or (GREY .. "  - drop an item here|r")
    r.headText:SetText(d.slot.label .. count)
    r.wornText:SetText(WornText(d.list, d.slot))
end

function UI:SetItem(r, d)
    ShowParts(r, HEADER_PARTS, false)
    ShowParts(r, ITEM_PARTS, true)
    r:SetHeight(ROW_H)
    local id = d.id
    local name, quality, icon, _, reqLevel, ilvl, subType = TL:ItemBasics(id)
    r.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    r.name:SetText(TL:QualityHex(quality) .. (name or ("item " .. id)) .. "|r")
    local e = d.e
    if e then
        r.tierBtn:SetTier(e.tier, false, false)
    else
        r.tierBtn:SetTier(nil, true, false)
    end
    local state = TL:ItemState(id)
    local stateText = ""
    if state == "equipped" then
        stateText = GREEN .. "equipped|r"
    elseif state == "owned" then
        stateText = YELLOW .. "in bags/bank|r"
    elseif d.search and e then
        stateText = GREY .. "in list|r"
    end
    r.state:SetText(stateText)
    if d.search then
        r.place:SetText("")
        local slotKey = TL:DefaultSlotKey(id)
        local slot = TL.SLOT_BY_KEY[slotKey]
        local bits = { slot and slot.label or "" }
        if subType and subType ~= "" and subType ~= "Miscellaneous" then
            bits[#bits + 1] = subType
        end
        if ilvl then
            bits[#bits + 1] = "ilvl " .. ilvl
        end
        if reqLevel and reqLevel > 1 then
            bits[#bits + 1] = "req " .. reqLevel
        end
        r.source:SetText(table.concat(bits, " - ") .. GREY .. "  |  " .. TL:SourceShort(id) .. "|r")
        r.up:Hide()
        r.down:Hide()
        r.del:Hide()
        r.add:Show()
    else
        r.place:SetText("#" .. (d.place or "?"))
        r.source:SetText(TL:SourceShort(id))
        r.add:Hide()
        r.up:SetShown(not d.first)
        r.down:SetShown(not d.last)
    end
end

function UI:BuildRows()
    local rows = {}
    local list = TL:GetActiveList()
    local q = TL.Trim(self.query):lower()
    if self.scope == "all" then
        if q == "" then
            rows[1] = { type = "header", hint = true, text = "Type a name or item ID above to search every item TierList knows." }
            return rows
        end
        for _, id in ipairs(TL:SearchAll(q, 120)) do
            rows[#rows + 1] = { type = "item", id = id, e = list and TL:Entry(list, id), search = true }
        end
        if #rows == 0 then
            rows[1] = { type = "header", hint = true, text = "Nothing found. Item IDs always work: type the number." }
        end
        return rows
    end
    if not list then
        rows[1] = { type = "header", hint = true, text = "No list yet. Click New to make one, or Import to paste one." }
        return rows
    end
    for _, slot in ipairs(TL.SLOTS) do
        local items = TL:SlotItems(list, slot.key)
        local shown = {}
        for i, row in ipairs(items) do
            row.place = i
            if q == "" then
                shown[#shown + 1] = row
            else
                local name = (TL:ItemBasics(row.id) or ""):lower()
                local src = TL:SourceShort(row.id):lower()
                if name:find(q, 1, true) or src:find(q, 1, true) or tostring(row.id) == q
                    or slot.label:lower():find(q, 1, true) then
                    shown[#shown + 1] = row
                end
            end
        end
        local showHeader = (#shown > 0) or (q == "" and slot.key ~= "OTHER")
        if showHeader then
            local key = list.id .. ":" .. slot.key
            local collapsed = q == "" and TL.db.collapsed[key]
            rows[#rows + 1] = { type = "header", slot = slot, count = #items, collapsed = collapsed, list = list, listId = list.id }
            if not collapsed then
                for i, row in ipairs(shown) do
                    rows[#rows + 1] = {
                        type = "item", id = row.id, e = row.e, place = row.place, list = list,
                        first = (row.place == 1), last = (row.place == #items),
                    }
                end
            end
        end
    end
    if q ~= "" and #rows == 0 then
        rows[1] = { type = "header", hint = true, text = "Nothing in this list matches. Try \"All items\"." }
    end
    return rows
end

function UI:Refresh()
    local f = self.frame
    if not f or not f:IsShown() then
        return
    end
    local list = TL:GetActiveList()
    self.listBtn:SetText(list and ("List: " .. list.name) or "List: (none)")
    if self.scope == "all" then
        self.scopeAll:LockHighlight()
        self.scopeList:UnlockHighlight()
    else
        self.scopeList:LockHighlight()
        self.scopeAll:UnlockHighlight()
    end
    if list then
        local cls = list.class and TL.CLASS_NAMES[list.class] or "any class"
        self.info:SetText(TL:CountItems(list) .. " items - " .. cls .. (list.build ~= "" and (" - " .. list.build) or ""))
    else
        self.info:SetText("")
    end
    local data = self:BuildRows()
    local y = 0
    local width = self.content:GetWidth()
    for i, d in ipairs(data) do
        local r = self.rows[i]
        if not r then
            r = CreateRow(self.content)
            self.rows[i] = r
        end
        r.data = d
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, -y)
        r:SetWidth(width)
        if d.type == "header" then
            self:SetHeader(r, d)
            if d.hint then
                r:SetHeight(HINT_H)
            end
        else
            self:SetItem(r, d)
        end
        r:Show()
        y = y + r:GetHeight()
    end
    for i = #data + 1, #self.rows do
        self.rows[i]:Hide()
        self.rows[i].data = nil
    end
    self.content:SetHeight(math.max(y, 10))
end

-- ---------------------------------------------------------------------------
-- Row actions
-- ---------------------------------------------------------------------------
local NEXT_TIER = { S = "A", A = "B", B = "C", C = "S" }
local PREV_TIER = { S = "C", A = "S", B = "A", C = "B" }

function UI:TierClick(d, button)
    if not d or not d.id then
        return
    end
    local list = TL:GetActiveList()
    if not list then
        return
    end
    local e = list.items[d.id]
    if not e then
        TL:AddItem(list, d.id, self.addTier)
    else
        TL:AddItem(list, d.id, (button == "RightButton" and PREV_TIER or NEXT_TIER)[e.tier] or "S")
    end
    TL:Changed()
end

function UI:Move(d, delta)
    local list = TL:GetActiveList()
    if list and d and d.id then
        TL:MoveItem(list, d.id, delta)
        TL:Changed()
    end
end

function UI:Remove(d)
    local list = TL:GetActiveList()
    if list and d and d.id then
        TL:RemoveItem(list, d.id)
        TL.Print("removed " .. TL:ColoredName(d.id) .. " from " .. list.name .. ". |cffffd100/tl undo|r brings it back.")
        TL:Changed()
    end
end

function UI:AddFromSearch(d)
    local list = TL:GetActiveList()
    if not list then
        TL.Print("create a list first (New).")
        return
    end
    if d and d.id then
        TL:AddItem(list, d.id, self.addTier)
        TL.Print("added " .. TL:ColoredName(d.id) .. " as " .. TL.TierText(self.addTier) .. " to " .. list.name .. ".")
        TL:Changed()
    end
end

function UI:ShowItemMenu(anchor, d)
    local list = TL:GetActiveList()
    if not list then
        return
    end
    local id = d.id
    local e = list.items[id]
    local entries = { { text = TL:ColoredName(id), isTitle = true } }
    for _, t in ipairs(TL.TIERS) do
        entries[#entries + 1] = {
            text = (e and "Tier " or "Add as ") .. TL.TierText(t), checked = e and e.tier == t,
            func = function()
                TL:AddItem(list, id, t)
                TL:Changed()
            end,
        }
    end
    if e then
        entries[#entries + 1] = { text = "Move up", func = function() UI:Move(d, -1) end }
        entries[#entries + 1] = { text = "Move down", func = function() UI:Move(d, 1) end }
        local loc = TL:EquipLoc(id)
        if loc == "INVTYPE_WEAPON" then
            local cur = TL:SlotKeyFor(id, e)
            local other = cur == "OFFHAND" and "MAINHAND" or "OFFHAND"
            entries[#entries + 1] = {
                text = "Show under " .. TL.SLOT_BY_KEY[other].label,
                func = function()
                    TL:SetItemSlot(list, id, other)
                    TL:Changed()
                end,
            }
        end
        for _, other in ipairs(TL:SortedLists()) do
            if other.id ~= list.id then
                entries[#entries + 1] = {
                    text = "Copy to " .. other.name .. (other.items[id] and (" (is " .. TL.TierText(other.items[id].tier) .. ")") or ""),
                    func = function()
                        TL:AddItem(other, id, e.tier, e.slot)
                        TL.Print("copied " .. TL:ColoredName(id) .. " to " .. other.name .. " as " .. TL.TierText(e.tier) .. ".")
                    end,
                }
            end
        end
        entries[#entries + 1] = { text = "|cffff5555Remove|r", func = function() UI:Remove(d) end }
    end
    self:ShowMenu(anchor, entries)
end

function UI:ShowListMenu(anchor)
    local active = TL:GetActiveList()
    local entries = { { text = "Lists (" .. TL:CharLabel(TL.charKey) .. ")", isTitle = true } }
    for _, l in ipairs(TL:SortedLists()) do
        local chars = {}
        for key in pairs(l.chars) do
            chars[#chars + 1] = TL:CharLabel(key)
        end
        local extra = TL:CountItems(l) .. " items" .. (#chars > 0 and (", " .. table.concat(chars, ", ")) or "")
        entries[#entries + 1] = {
            text = l.name .. GREY .. "  (" .. extra .. ")|r" .. (l.chars[TL.charKey] and TL:IsOffspec(l) and "|cff59a6ff offspec|r" or ""),
            checked = (l == active),
            func = function()
                TL:SetActiveList(l.id)
            end,
        }
    end
    entries[#entries + 1] = { text = YELLOW .. "New list...|r", func = function() UI:ShowEdit(nil) end }
    self:ShowMenu(anchor, entries)
end

-- ---------------------------------------------------------------------------
-- Fill dialog: GearQuest's ranking for a spec, filtered by source and quality
-- ---------------------------------------------------------------------------
local QUALITY_HEX = { [2] = "|cff1eff00", [3] = "|cff0070dd", [4] = "|cffa335ee" }

local function SpecLabel(spec)
    return (spec:gsub("_", " "):gsub("(%a)([%w]*)", function(a, b) return a:upper() .. b end))
end

function UI:ShowFill()
    local list = TL:GetActiveList()
    if not list then
        TL.Print("no list yet. Make one with New.")
        return
    end
    local f = self.fill
    if not f then
        f = Dialog("TierListFillDialog", 430, 420, "Fill from GearQuest")
        self.fill = f
        local help = Label(f, "Adds GearQuest Forever's ranked level-" .. (TL.PicksLevel or 60) .. " items for a spec to every slot, " ..
            "below your own picks: the first 30 % of the places A, the next 30 % B, the rest C (a slot without an S item gets the first as S). " ..
            "Only items that pass the filters count.", "GameFontHighlightSmall")
        help:SetPoint("TOPLEFT", 16, -30)
        help:SetPoint("RIGHT", -16, 0)
        help:SetWordWrap(true)
        local specLabel = Label(f, "Spec")
        specLabel:SetPoint("TOPLEFT", 18, -86)
        f.specBtn = Btn(f, "", 170)
        f.specBtn:SetPoint("TOPLEFT", 120, -81)
        f.specBtn:SetScript("OnClick", function(btn)
            local l = TL:GetActiveList()
            local entries = { { text = "Spec", isTitle = true } }
            for _, spec in ipairs(TL:PickSpecs(l and l.class or TL.playerClass)) do
                entries[#entries + 1] = { text = SpecLabel(spec), checked = (f.spec == spec), func = function()
                    f.spec = spec
                    btn:SetText(SpecLabel(spec))
                end }
            end
            UI:ShowMenu(btn, entries)
        end)
        local srcLabel = Label(f, "Sources")
        srcLabel:SetPoint("TOPLEFT", 18, -116)
        f.catChecks = {}
        for i, c in ipairs(TL.SOURCE_CATS) do
            local cb = Check(f, c.label)
            local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
            cb:SetPoint("TOPLEFT", 16 + col * 200, -134 - row * 22)
            f.catChecks[c.key] = cb
        end
        local qLabel = Label(f, "Quality")
        qLabel:SetPoint("TOPLEFT", 18, -232)
        f.qChecks = {}
        for i, q in ipairs(TL.FILL_QUALITIES) do
            local cb = Check(f, QUALITY_HEX[q.q] .. q.label .. "|r")
            cb:SetPoint("TOPLEFT", 16 + (i - 1) * 110, -250)
            f.qChecks[q.q] = cb
        end
        local pLabel = Label(f, "Places per slot")
        pLabel:SetPoint("TOPLEFT", 18, -290)
        f.places = Input(f, 36)
        f.places:SetNumeric(true)
        f.places:SetMaxLetters(2)
        f.places:SetPoint("TOPLEFT", 140, -286)
        local pHint = Label(f, GREY .. "(rings and trinkets x1.4, max 40)|r", "GameFontHighlightSmall")
        pHint:SetPoint("LEFT", f.places, "RIGHT", 8, 0)
        f.replace = Check(f, "Replace this list's earlier GearQuest picks")
        f.replace:SetPoint("TOPLEFT", 16, -312)
        f.result = Label(f, "", "GameFontHighlightSmall")
        f.result:SetPoint("TOPLEFT", 18, -342)
        f.result:SetPoint("RIGHT", -16, 0)
        f.result:SetWordWrap(true)
        f.go = Btn(f, "Fill", 100)
        f.go:SetPoint("BOTTOMRIGHT", -14, 14)
        f.go:SetScript("OnClick", function() UI:DoFill() end)
        f.places:SetScript("OnEnterPressed", function(eb) eb:ClearFocus(); UI:DoFill() end)
        f.remove = Btn(f, "Remove picks", 130)
        f.remove:SetPoint("BOTTOMLEFT", 14, 14)
        f.remove:SetScript("OnClick", function()
            local l = TL:GetActiveList()
            if l then
                local n = TL:RemoveFilled(l)
                f.result:SetText(string.format("Removed %d GearQuest picks from %s. /tl undo brings them back.", n, l.name))
                UI:UpdateFill()
            end
        end)
        Tip(f.remove, "Remove GearQuest picks", "Removes every item a fill added to this list (items you re-tiered or moved count as yours and stay).")
    end
    local specs = TL:PickSpecs(list.class or TL.playerClass)
    local want = f.spec or (list.fill and list.fill.spec)
    f.spec = nil
    for _, spec in ipairs(specs) do
        if spec == want then
            f.spec = spec
        end
    end
    f.spec = f.spec or specs[1]
    f.specBtn:SetText(f.spec and SpecLabel(f.spec) or "no data for this class")
    local s = TL:FillSettings()
    for key, cb in pairs(f.catChecks) do
        cb:SetChecked(s.cats[key] and true or false)
    end
    for q, cb in pairs(f.qChecks) do
        cb:SetChecked(s.quality[q] and true or false)
    end
    f.places:SetText(tostring(s.places))
    f.replace:SetChecked(s.replace and true or false)
    f.result:SetText(#specs == 0 and "|cffff5555No GearQuest data for this list's class. Set the class with Edit.|r" or "")
    f.titleText:SetText("Fill from GearQuest: " .. list.name)
    self:UpdateFill()
    f:Show()
end

function UI:UpdateFill()
    local f = self.fill
    local list = TL:GetActiveList()
    if not f or not list then
        return
    end
    local n = TL:CountFilled(list)
    f.remove:SetText("Remove picks (" .. n .. ")")
    if n > 0 then f.remove:Enable() else f.remove:Disable() end
    if f.spec then f.go:Enable() else f.go:Disable() end
end

function UI:DoFill()
    local f = self.fill
    local list = TL:GetActiveList()
    if not f or not list or not f.spec then
        return
    end
    local s = TL:FillSettings()
    for key, cb in pairs(f.catChecks) do
        s.cats[key] = cb:GetChecked() and true or false
    end
    for q, cb in pairs(f.qChecks) do
        s.quality[q] = cb:GetChecked() and true or false
    end
    s.places = math.max(1, math.min(40, tonumber(f.places:GetText()) or s.places or 10))
    s.replace = f.replace:GetChecked() and true or false
    f.places:SetText(tostring(s.places))
    local n, removed = TL:FillFromPicks(list, f.spec, { places = s.places, replace = s.replace })
    if not n then
        f.result:SetText("|cffff5555" .. tostring(removed) .. "|r")
        return
    end
    f.result:SetText(GREEN .. "Added " .. n .. " items (" .. SpecLabel(f.spec) .. ") to " .. list.name ..
        ((removed or 0) > 0 and (", replaced " .. removed .. " earlier picks") or "") .. ".|r")
    self:UpdateFill()
end

function UI:ShowOptionsMenu(anchor)
    local s = TL.db.settings
    local function toggle(key)
        return function()
            s[key] = not s[key]
            UI:ShowOptionsMenu(anchor)
        end
    end
    self:ShowMenu(anchor, {
        { text = "Options", isTitle = true },
        { text = "Loot alerts (banner)", checked = s.alerts, func = toggle("alerts"), keepOpen = true },
        { text = "Sound on upgrades", checked = s.sound, func = toggle("sound"), keepOpen = true },
        { text = "Chat messages", checked = s.chat, func = toggle("chat"), keepOpen = true },
        { text = "Tooltip lines", checked = s.tooltip, func = toggle("tooltip"), keepOpen = true },
        { text = "Other characters' lists in tooltips", checked = s.tooltipOthers, func = toggle("tooltipOthers"), keepOpen = true },
        { text = "Dungeon pop-up", checked = s.popup, func = toggle("popup"), keepOpen = true },
        { text = "Minimap button", checked = TL.MinimapButton and TL.MinimapButton:IsShown(), keepOpen = true,
          func = function()
              TL.MinimapButton:Toggle()
              UI:ShowOptionsMenu(anchor)
          end },
        { text = "Show a test alert", func = function() TL.Alerts:Test() end },
    })
end

-- Right-click menu of the minimap button: switch list, main switches, hide the button.
function UI:ShowQuickMenu(anchor)
    local s = TL.db.settings
    local active = TL:GetActiveList()
    local entries = {
        { text = "TierList", isTitle = true },
        { text = "Open / close window", func = function() TierList_Toggle() end },
        { text = "Lists", isTitle = true },
    }
    for _, l in ipairs(TL:ListsForChar()) do
        entries[#entries + 1] = {
            text = l.name .. GREY .. "  (" .. TL:CountItems(l) .. ")|r" .. (TL:IsOffspec(l) and "|cff59a6ff offspec|r" or ""),
            checked = (l == active),
            func = function()
                TL:SetActiveList(l.id)
                TL.Print("active list: " .. l.name)
            end,
        }
    end
    entries[#entries + 1] = { text = "Options", isTitle = true }
    entries[#entries + 1] = {
        text = "Loot alerts (banner)", checked = s.alerts, keepOpen = true,
        func = function()
            s.alerts = not s.alerts
            UI:ShowQuickMenu(anchor)
        end,
    }
    entries[#entries + 1] = {
        text = "Sound on upgrades", checked = s.sound, keepOpen = true,
        func = function()
            s.sound = not s.sound
            UI:ShowQuickMenu(anchor)
        end,
    }
    entries[#entries + 1] = { text = GREY .. "Hide minimap button|r", func = function() TL.MinimapButton:Toggle() end }
    self:ShowMenu(anchor, entries)
end

-- ---------------------------------------------------------------------------
-- New / edit list dialog
-- ---------------------------------------------------------------------------
StaticPopupDialogs["TIERLIST_DELETE"] = {
    text = "Delete the list \"%s\"?",
    button1 = YES or "Yes",
    button2 = NO or "No",
    OnAccept = function(_, data)
        TL:DeleteList(data)
        if UI.edit then
            UI.edit:Hide()
        end
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    preferredIndex = 3,
}

function UI:ShowEdit(list)
    local f = self.edit
    if not f then
        f = Dialog("TierListEditDialog", 380, 440, "List")
        self.edit = f
        local y = -34
        local nameLabel = Label(f, "Name")
        nameLabel:SetPoint("TOPLEFT", 18, y)
        f.name = Input(f, 230)
        f.name:SetPoint("TOPLEFT", 120, y + 3)
        y = y - 30
        local buildLabel = Label(f, "Build / note")
        buildLabel:SetPoint("TOPLEFT", 18, y)
        f.build = Input(f, 230)
        f.build:SetPoint("TOPLEFT", 120, y + 3)
        y = y - 30
        local classLabel = Label(f, "Class")
        classLabel:SetPoint("TOPLEFT", 18, y)
        f.classBtn = Btn(f, "Any class", 140)
        f.classBtn:SetPoint("TOPLEFT", 114, y + 5)
        f.classBtn:SetScript("OnClick", function(self)
            local entries = { { text = "Any class", checked = f.class == nil, func = function()
                f.class = nil
                f.classBtn:SetText("Any class")
            end } }
            for _, c in ipairs(TL.CLASS_ORDER) do
                entries[#entries + 1] = { text = TL.CLASS_NAMES[c], checked = f.class == c, func = function()
                    f.class = c
                    f.classBtn:SetText(TL.CLASS_NAMES[c])
                end }
            end
            UI:ShowMenu(self, entries)
        end)
        y = y - 30
        -- main spec / offspec: a tree makes the list main spec only while you are specced into it
        local specLabel = Label(f, "Spec")
        specLabel:SetPoint("TOPLEFT", 18, y)
        f.specBtn = Btn(f, "Any spec", 160)
        f.specBtn:SetPoint("TOPLEFT", 114, y + 5)
        f.specBtn:SetScript("OnClick", function(self)
            local function pick(key)
                return function()
                    f.spec = key
                    UI:UpdateEditSpec()
                end
            end
            local entries = {
                { text = "Any spec (always main spec)", checked = f.spec == nil or f.spec == "any", func = pick(nil) },
                { text = "Always offspec (never NEED)", checked = f.spec == "off", func = pick("off") },
            }
            local class = f.class or TL.playerClass
            entries[#entries + 1] = { text = "Main spec while specced:", isTitle = true }
            for _, k in ipairs(TL.Spec.Options(class)) do
                entries[#entries + 1] = { text = TL.Spec.Label(k), checked = f.spec == k, func = pick(k) }
            end
            UI:ShowMenu(self, entries)
        end)
        f.specHint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        f.specHint:SetPoint("TOPLEFT", 18, y - 20)
        f.specHint:SetPoint("RIGHT", -14, 0)
        f.specHint:SetJustifyH("LEFT")
        Skin.Apply("Font", f.specHint)
        y = y - 52
        local charLabel = Label(f, "Used by these characters")
        charLabel:SetPoint("TOPLEFT", 18, y)
        f.charY = y - 18
        f.checks = {}
        f.save = Btn(f, "Save", 90)
        f.save:SetPoint("BOTTOMRIGHT", -14, 14)
        f.cancel = Btn(f, "Cancel", 90)
        f.cancel:SetPoint("RIGHT", f.save, "LEFT", -6, 0)
        f.cancel:SetScript("OnClick", function() f:Hide() end)
        f.delete = Btn(f, "Delete list", 100)
        f.delete:SetPoint("BOTTOMLEFT", 14, 14)
        f.delete:SetScript("OnClick", function()
            if f.list then
                StaticPopup_Show("TIERLIST_DELETE", f.list.name, nil, f.list.id)
            end
        end)
        f.save:SetScript("OnClick", function() UI:SaveEdit() end)
        f.name:SetScript("OnEnterPressed", function() UI:SaveEdit() end)
    end
    f.list = list
    f.titleText:SetText(list and ("Edit list: " .. list.name) or "New list")
    f.name:SetText(list and list.name or "")
    f.build:SetText(list and list.build or "")
    f.class = list and list.class or (not list and TL.playerClass) or nil
    f.classBtn:SetText(f.class and TL.CLASS_NAMES[f.class] or "Any class")
    f.spec = list and list.spec or nil
    self:UpdateEditSpec()
    f.delete:SetShown(list ~= nil)
    -- one checkbox per known character
    local keys = {}
    for key in pairs(TL.db.chars) do
        keys[#keys + 1] = key
    end
    table.sort(keys, function(a, b) return TL:CharLabel(a) < TL:CharLabel(b) end)
    for _, cb in ipairs(f.checks) do
        cb:Hide()
    end
    for i, key in ipairs(keys) do
        if i > 12 then
            break
        end
        local cb = f.checks[i]
        if not cb then
            cb = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
            cb:SetSize(22, 22)
            Skin.Apply("Checkbox", cb)
            local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
            cb:SetPoint("TOPLEFT", 18 + col * 170, f.charY - row * 22)
            cb.label = cb.Text or cb.text or cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            if not (cb.Text or cb.text) then
                cb.label:SetPoint("LEFT", cb, "RIGHT", 2, 0)
            end
            f.checks[i] = cb
        end
        cb.key = key
        local c = TL.db.chars[key]
        cb.label:SetText(TL:CharLabel(key) .. (c and c.class and (GREY .. " (" .. (TL.CLASS_NAMES[c.class] or c.class) .. ")|r") or ""))
        if list then
            cb:SetChecked(list.chars[key] and true or false)
        else
            cb:SetChecked(key == TL.charKey)
        end
        cb:Show()
    end
    f:Show()
    f.name:SetFocus()
end

-- Spec button text + a line saying what it means right now.
function UI:UpdateEditSpec()
    local f = self.edit
    local s = f.spec
    f.specBtn:SetText(TL.Spec.Label(s))
    local cur = TL.Spec.Current()
    local text
    if s == "off" then
        text = "Items show \"Offspec - Greed\", never NEED."
    elseif not s or s == "any" then
        text = "Always main spec (NEED on upgrades)."
    elseif not cur then
        text = "Your talent tree is not known yet: counts as main spec."
    elseif TL.Spec.TreeOf(s) == cur then
        text = "You are " .. TL.Spec.Label(cur) .. " now: main spec."
    else
        text = "You are " .. TL.Spec.Label(cur) .. " now: offspec (Greed)."
    end
    f.specHint:SetText(text)
end

function UI:SaveEdit()
    local f = self.edit
    local name = TL.Trim(f.name:GetText())
    if name == "" then
        TL.Print("the list needs a name.")
        return
    end
    local list = f.list
    if not list then
        list = TL:CreateList(name, f.class, TL.Trim(f.build:GetText()))
    end
    list.name = name
    list.build = TL.Trim(f.build:GetText())
    list.class = f.class
    list.spec = f.spec ~= "any" and f.spec or nil
    list.specSeeded = true
    list.modified = time()
    local wasActive = TL.db.active[TL.charKey] == list.id
    for _, cb in ipairs(f.checks) do
        if cb:IsShown() and cb.key then
            list.chars[cb.key] = cb:GetChecked() and true or nil
            if not cb:GetChecked() and TL.db.active[cb.key] == list.id then
                TL.db.active[cb.key] = nil
            end
        end
    end
    if not f.list and list.chars[TL.charKey] then
        TL:SetActiveList(list.id)
    elseif wasActive and not list.chars[TL.charKey] then
        TL:EnsureActive()
    elseif not TL:GetActiveList() and list.chars[TL.charKey] then
        TL:SetActiveList(list.id)
    end
    f:Hide()
    TL:Changed()
end

-- ---------------------------------------------------------------------------
-- Import dialog
-- ---------------------------------------------------------------------------
function UI:ShowImport()
    local f = self.import
    if not f then
        f = Dialog("TierListImportDialog", 560, 500, "Import")
        self.import = f
        local help = Label(f, "Paste a TierList string, a wowsims export (JSON or .siml), a Sixty Upgrades \"Export Set\" JSON (wishlist = one tier lower), Wowhead links, item IDs or " ..
            "item names, one per line. Lines may start with S:, A:, B: or C: (or a line \"A\" switches the tier for the lines below). " ..
            "Shift-click items into the box works too.", "GameFontHighlightSmall")
        help:SetPoint("TOPLEFT", 16, -30)
        help:SetPoint("RIGHT", -16, 0)
        help:SetWordWrap(true)
        f.box = MultiLineBox(f, 528, 220)
        f.box:SetPoint("TOPLEFT", 16, -78)
        self.importBox = f.box
        local y = -308
        local tl = Label(f, "Tier for unmarked lines", "GameFontNormalSmall")
        tl:SetPoint("TOPLEFT", 18, y)
        f.tier = "S"
        f.tierBtns = {}
        local prev = tl
        for _, t in ipairs(TL.TIERS) do
            local b = TierButton(f, 20)
            b:SetPoint("LEFT", prev, "RIGHT", 4, 0)
            b:SetScript("OnClick", function()
                f.tier = t
                for tt, bb in pairs(f.tierBtns) do
                    bb:SetTier(tt, tt ~= t, tt == t)
                end
            end)
            f.tierBtns[t] = b
            prev = b
        end
        for tt, bb in pairs(f.tierBtns) do
            bb:SetTier(tt, tt ~= f.tier, tt == f.tier)
        end
        y = y - 28
        f.intoActive = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
        f.intoActive:SetSize(22, 22)
        Skin.Apply("Checkbox", f.intoActive)
        f.intoActive:SetPoint("TOPLEFT", 14, y + 4)
        f.intoActiveText = f.intoActive.Text or f.intoActive.text or Label(f.intoActive, "", "GameFontHighlightSmall")
        if not (f.intoActive.Text or f.intoActive.text) then
            f.intoActiveText:SetPoint("LEFT", f.intoActive, "RIGHT", 2, 0)
        end
        f.asNew = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
        f.asNew:SetSize(22, 22)
        Skin.Apply("Checkbox", f.asNew)
        f.asNew:SetPoint("TOPLEFT", 14, y - 18)
        local asNewText = f.asNew.Text or f.asNew.text or Label(f.asNew, "", "GameFontHighlightSmall")
        if not (f.asNew.Text or f.asNew.text) then
            asNewText:SetPoint("LEFT", f.asNew, "RIGHT", 2, 0)
        end
        asNewText:SetText("as a new list named")
        f.newName = Input(f, 200)
        f.newName:SetPoint("LEFT", f.asNew, "RIGHT", 140, 0)
        f.intoActive:SetScript("OnClick", function() f.intoActive:SetChecked(true); f.asNew:SetChecked(false) end)
        f.asNew:SetScript("OnClick", function() f.asNew:SetChecked(true); f.intoActive:SetChecked(false) end)
        f.newName:HookScript("OnEditFocusGained", function() f.asNew:SetChecked(true); f.intoActive:SetChecked(false) end)
        f.replace = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
        f.replace:SetSize(22, 22)
        Skin.Apply("Checkbox", f.replace)
        f.replace:SetPoint("TOPLEFT", 14, y - 40)
        local replaceText = f.replace.Text or f.replace.text or Label(f.replace, "", "GameFontHighlightSmall")
        if not (f.replace.Text or f.replace.text) then
            replaceText:SetPoint("LEFT", f.replace, "RIGHT", 2, 0)
        end
        replaceText:SetText("empty that list first (replace instead of adding)")
        f.result = Label(f, "", "GameFontHighlightSmall")
        f.result:SetPoint("TOPLEFT", 18, y - 70)
        f.result:SetPoint("RIGHT", -16, 0)
        f.result:SetWordWrap(true)
        f.go = Btn(f, "Import", 100)
        f.go:SetPoint("BOTTOMRIGHT", -14, 14)
        f.go:SetScript("OnClick", function() UI:DoImport(false) end)
        f.preview = Btn(f, "Check", 90)
        f.preview:SetPoint("RIGHT", f.go, "LEFT", -6, 0)
        f.preview:SetScript("OnClick", function() UI:DoImport(true) end)
        Tip(f.preview, "Check", "Shows what would be imported without changing anything.")
        f.clear = Btn(f, "Clear", 80)
        f.clear:SetPoint("BOTTOMLEFT", 14, 14)
        f.clear:SetScript("OnClick", function()
            f.box.edit:SetText("")
            f.result:SetText("")
        end)
    end
    local list = TL:GetActiveList()
    f.intoActiveText:SetText("into the active list" .. (list and (" (" .. list.name .. ")") or " (none yet)"))
    f.intoActive:SetChecked(list ~= nil)
    f.asNew:SetChecked(list == nil)
    f.replace:SetChecked(false)
    f.result:SetText("")
    f:Show()
    f.box.edit:SetFocus()
end

function UI:DoImport(dryRun)
    local f = self.import
    local text = f.box.edit:GetText()
    if TL.Trim(text) == "" then
        f.result:SetText("|cffff5555Paste something first.|r")
        return
    end
    local res = TL.Import.Parse(text, f.tier)
    local counts = {}
    for _, it in ipairs(res.items) do
        counts[it.tier] = (counts[it.tier] or 0) + 1
    end
    local tierBits = {}
    for _, t in ipairs(TL.TIERS) do
        if counts[t] then
            tierBits[#tierBits + 1] = TL.TierText(t) .. " " .. counts[t]
        end
    end
    local msg = "Found " .. #res.items .. " items (" .. res.format .. ")" .. (#tierBits > 0 and (": " .. table.concat(tierBits, ", ")) or "") .. "."
    if #res.unknown > 0 then
        local shown = {}
        for i = 1, math.min(4, #res.unknown) do
            shown[i] = "\"" .. res.unknown[i]:sub(1, 50) .. "\""
        end
        msg = msg .. "\n|cffff9933Not recognised (" .. #res.unknown .. "):|r " .. table.concat(shown, ", ") .. (#res.unknown > 4 and " ..." or "")
    end
    if dryRun or #res.items == 0 then
        f.result:SetText(msg)
        if res.meta and res.meta.name and TL.Trim(f.newName:GetText()) == "" then
            f.newName:SetText(res.meta.name)
        end
        return
    end
    local list
    if f.asNew:GetChecked() or not TL:GetActiveList() then
        local name = TL.Trim(f.newName:GetText())
        if name == "" then
            name = (res.meta and res.meta.name) or "Imported"
        end
        list = TL:CreateList(name, res.meta and res.meta.class or TL.playerClass, res.meta and res.meta.build or "")
        TL:SetActiveList(list.id)
    else
        list = TL:GetActiveList()
    end
    local c = TL.Import.Apply(res, list, f.replace:GetChecked())
    f.result:SetText(msg .. "\n" .. GREEN .. "Imported into " .. list.name .. ": " .. (c.added or 0) .. " new, " ..
        (c.changed or 0) .. " changed tier, " .. (c.same or 0) .. " already there.|r")
    TL:Changed()
end

-- ---------------------------------------------------------------------------
-- Export dialog
-- ---------------------------------------------------------------------------
function UI:ShowExport()
    local list = TL:GetActiveList()
    if not list then
        TL.Print("no active list to export.")
        return
    end
    local f = self.export
    if not f then
        f = Dialog("TierListExportDialog", 560, 400, "Export")
        self.export = f
        f.help = Label(f, "", "GameFontHighlightSmall")
        f.help:SetPoint("TOPLEFT", 16, -30)
        f.help:SetPoint("RIGHT", -16, 0)
        f.help:SetWordWrap(true)
        f.box = MultiLineBox(f, 528, 280)
        f.box:SetPoint("TOPLEFT", 16, -62)
        f.shareBtn = Btn(f, "Share string", 110)
        f.shareBtn:SetPoint("BOTTOMLEFT", 14, 14)
        f.textBtn = Btn(f, "Plain text", 100)
        f.textBtn:SetPoint("LEFT", f.shareBtn, "RIGHT", 6, 0)
        f.close = Btn(f, "Close", 90)
        f.close:SetPoint("BOTTOMRIGHT", -14, 14)
        f.close:SetScript("OnClick", function() f:Hide() end)
        f.shareBtn:SetScript("OnClick", function() UI:FillExport("share") end)
        f.textBtn:SetScript("OnClick", function() UI:FillExport("text") end)
        f.box.edit:SetScript("OnEscapePressed", function() f:Hide() end)
    end
    f:Show()
    self:FillExport("share")
end

function UI:FillExport(mode)
    local f = self.export
    local list = TL:GetActiveList()
    if not f or not list then
        return
    end
    f.titleText:SetText("Export: " .. list.name)
    local text
    if mode == "text" then
        text = TL.Import.PlainText(list)
        f.help:SetText("Readable list with tiers and item IDs. It can be imported again as it is. Press Ctrl+C to copy.")
        f.textBtn:LockHighlight()
        f.shareBtn:UnlockHighlight()
    else
        text = TL.Import.ShareString(list)
        f.help:SetText("One line with the whole list. Press Ctrl+C to copy; friends paste it into /tl import.")
        f.shareBtn:LockHighlight()
        f.textBtn:UnlockHighlight()
    end
    f.box.edit:SetText(text)
    f.box.edit:SetFocus()
    f.box.edit:HighlightText()
end

-- EllesmereUI accent/theme changed: recolour headers.
Skin.OnLooksChanged(function()
    if UI.frame and UI.frame:IsShown() then
        UI:Refresh()
    end
end)
