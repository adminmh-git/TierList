-- Look of TierList's own frames.
--  * With EllesmereUI (its "Blizzard Skins+" module hands out a skinner; third-party skinning on for
--    TierList, the default) the frames go to EllesmereUI's skinning API (EllesmereUI\SKINNING_API.md)
--    and follow the user's EUI theme, accent colour and font, live.
--  * Without it: a small built-in flat style (dark panels, 1px borders, flat buttons and inputs).
-- UI code calls Skin.Apply("<Kind>", frame, ...) once per frame; kinds: Shell, Panel, Button, EditBox,
-- ScrollBar, CloseButton, Checkbox, Font, Icon, Highlight.
local ADDON, TL = ...
local Skin = { queue = {}, looks = {} }
TL.Skin = Skin

local WHITE = "Interface\\Buttons\\WHITE8X8"
Skin.DEFAULT_ACCENT = { 0.20, 0.85, 0.60 } -- TierList green, used without EllesmereUI
Skin.PANEL = { 0.06, 0.06, 0.07, 0.96 }

local FLAT, EUI = {}, {}

-- ---------------------------------------------------------------------------
-- Dispatch
-- ---------------------------------------------------------------------------
local reported = {}
local function Try(impl, kind, obj, ...)
    local fn = impl[kind]
    if not fn then
        return true
    end
    local ok, err = pcall(fn, obj, ...)
    if not ok and not reported[kind] then
        reported[kind] = true
        TL.Print("look (" .. kind .. ") failed: " .. tostring(err))
    end
    return ok
end

-- True while EllesmereUI is installed but has not handed over its skinner yet (before PLAYER_LOGIN).
Skin.waiting = (EllesmereUI and EllesmereUI.RegisterSkin) and true or false

function Skin.Apply(kind, obj, ...)
    if not obj then
        return
    end
    if Skin.S then
        if not Try(EUI, kind, obj, ...) then
            Try(FLAT, kind, obj, ...)
        end
    elseif Skin.waiting then
        Skin.queue[#Skin.queue + 1] = { kind, obj, select("#", ...), ... }
    else
        Try(FLAT, kind, obj, ...)
    end
end

local function Flush()
    local q = Skin.queue
    Skin.queue = {}
    for _, e in ipairs(q) do
        Skin.Apply(e[1], e[2], unpack(e, 4, 3 + e[3]))
    end
end

function Skin.IsEUI()
    return Skin.S ~= nil
end

function Skin.Accent()
    local S = Skin.S
    if S and S.GetAccentColor then
        local ok, r, g, b = pcall(S.GetAccentColor)
        if ok and r then
            return r, g, b
        end
    end
    local c = Skin.DEFAULT_ACCENT
    return c[1], c[2], c[3]
end

function Skin.AccentHex()
    local r, g, b = Skin.Accent()
    return string.format("|cff%02x%02x%02x", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

-- fn() runs when EllesmereUI's accent/theme changes (and once when its skinner arrives).
function Skin.OnLooksChanged(fn)
    Skin.looks[#Skin.looks + 1] = fn
end

function Skin.LooksChanged()
    for _, fn in ipairs(Skin.looks) do
        pcall(fn)
    end
end

if EllesmereUI and EllesmereUI.RegisterSkin then
    EllesmereUI.RegisterSkin(ADDON, function(S)
        Skin.S = S
        Skin.waiting = false
        if S.OnLooksChanged then
            S.OnLooksChanged(Skin.LooksChanged)
        end
        Flush()
        Skin.LooksChanged()
    end)
end

-- EllesmereUI hands its skinner out at PLAYER_LOGIN. If none came (skinning switched off for
-- TierList, or the Blizzard Skins+ module disabled), use the flat style.
TL:On("PLAYER_LOGIN", function()
    C_Timer.After(2, function()
        if not Skin.S and Skin.waiting then
            Skin.waiting = false
            Flush()
        end
    end)
end)

-- ---------------------------------------------------------------------------
-- EllesmereUI
-- ---------------------------------------------------------------------------
function EUI.Shell(f, opts)
    local S = Skin.S
    S.Shell(f, opts)
    if f.CloseButton then
        S.CloseButton(f.CloseButton)
    end
    if f.Inset and S.Inset then
        S.Inset(f.Inset)
    end
    if f.TitleText then
        S.Font(f.TitleText)
    end
end

function EUI.Panel(f, opts)
    if f.SetBackdrop then
        f:SetBackdrop(nil) -- EUI paints its own panel
    end
    Skin.S.Panel(f, opts)
end

function EUI.Button(b)
    local S = Skin.S
    S.Button(b)
    if S.StateButtonLabel then
        S.StateButtonLabel(b)
    end
    local fs = b.GetFontString and b:GetFontString()
    if fs then
        S.Font(fs)
    end
end

function EUI.EditBox(eb)
    Skin.S.EditBox(eb)
end

function EUI.ScrollBar(sb)
    Skin.S.ScrollBar(sb)
end

function EUI.CloseButton(b)
    Skin.S.CloseButton(b)
end

function EUI.Checkbox(cb)
    Skin.S.Checkbox(cb)
    local fs = cb.Text or cb.text
    if fs then
        Skin.S.Font(fs)
    end
end

function EUI.Font(fs)
    Skin.S.Font(fs)
end

function EUI.Icon(tex, parent)
    Skin.S.SquareIcon(tex, parent)
end

EUI.Highlight = function(frame, alpha) FLAT.Highlight(frame, alpha) end

-- ---------------------------------------------------------------------------
-- Built-in flat style
-- ---------------------------------------------------------------------------
local function FadeArt(frame)
    if not frame or not frame.GetRegions then
        return
    end
    for _, r in ipairs({ frame:GetRegions() }) do
        if r.IsObjectType and r:IsObjectType("Texture") then
            r:SetAlpha(0)
        end
    end
end
Skin.FadeArt = FadeArt

-- Background + 1px edges made of textures (any frame, no BackdropTemplate needed).
-- out = { left, right, top, bottom }: how far the box reaches outside the frame.
local function Box(frame, bg, edge, out, layer)
    out = out or { 0, 0, 0, 0 }
    local l, r, t, b = out[1], out[2], out[3], out[4]
    layer = layer or "BACKGROUND"
    local tex = frame:CreateTexture(nil, layer, nil, -7)
    tex:SetColorTexture(bg[1], bg[2], bg[3], bg[4])
    tex:SetPoint("TOPLEFT", -l, t)
    tex:SetPoint("BOTTOMRIGHT", r, -b)
    if edge then
        local function line(p1, x1, y1, p2, x2, y2, w, h)
            local e = frame:CreateTexture(nil, layer, nil, -6)
            e:SetColorTexture(edge[1], edge[2], edge[3], edge[4])
            e:SetPoint(p1, x1, y1)
            e:SetPoint(p2, x2, y2)
            if w then e:SetWidth(w) end
            if h then e:SetHeight(h) end
        end
        line("TOPLEFT", -l, t, "TOPRIGHT", r, t, nil, 1)
        line("BOTTOMLEFT", -l, -b, "BOTTOMRIGHT", r, -b, nil, 1)
        line("TOPLEFT", -l, t, "BOTTOMLEFT", -l, -b, 1, nil)
        line("TOPRIGHT", r, t, "BOTTOMRIGHT", r, -b, 1, nil)
    end
    return tex
end

function FLAT.Highlight(frame, alpha)
    if not frame.SetHighlightTexture then
        return
    end
    frame:SetHighlightTexture(WHITE, "ADD")
    local h = frame:GetHighlightTexture()
    if h then
        h:SetAlpha(1)
        h:SetColorTexture(1, 1, 1, alpha or 0.07)
        h:SetBlendMode("ADD")
    end
end

function FLAT.Shell(f)
    FadeArt(f)
    FadeArt(f.NineSlice)
    if f.Inset then
        FadeArt(f.Inset)
        FadeArt(f.Inset.NineSlice)
    end
    local p = Skin.PANEL
    Box(f, p, { 0, 0, 0, 1 })
    local strip = f:CreateTexture(nil, "BORDER", nil, -2)
    strip:SetColorTexture(0.11, 0.11, 0.13, 1)
    strip:SetPoint("TOPLEFT", 1, -1)
    strip:SetPoint("TOPRIGHT", -1, -1)
    strip:SetHeight(23)
    local line = f:CreateTexture(nil, "BORDER", nil, -1)
    local r, g, b = Skin.Accent()
    line:SetColorTexture(r, g, b, 0.7)
    line:SetPoint("TOPLEFT", strip, "BOTTOMLEFT", 0, 0)
    line:SetPoint("TOPRIGHT", strip, "BOTTOMRIGHT", 0, 0)
    line:SetHeight(1)
    if f.TitleText then
        f.TitleText:SetTextColor(1, 1, 1)
    end
    if f.CloseButton then
        FLAT.CloseButton(f.CloseButton)
    end
end

function FLAT.Panel(f, opts)
    local p = Skin.PANEL
    local bg = (opts and opts.inset) and { 0.02, 0.02, 0.03, 0.85 } or p
    if f.SetBackdrop then
        f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
        f:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
        f:SetBackdropBorderColor(0, 0, 0, 1)
    else
        Box(f, bg, { 0, 0, 0, 1 })
    end
end

function FLAT.Button(b)
    FadeArt(b)
    Box(b, { 0.15, 0.15, 0.17, 1 }, { 0, 0, 0, 1 })
    FLAT.Highlight(b, 0.08)
    if b.SetNormalFontObject then
        b:SetNormalFontObject(GameFontHighlightSmall)
        b:SetHighlightFontObject(GameFontHighlightSmall)
        b:SetDisabledFontObject(GameFontDisableSmall)
    end
end

function FLAT.EditBox(eb)
    for _, k in ipairs({ "Left", "Middle", "Mid", "Right" }) do
        if eb[k] then
            eb[k]:SetAlpha(0)
        end
    end
    Box(eb, { 0.02, 0.02, 0.03, 0.9 }, { 0.24, 0.24, 0.27, 1 }, { 6, 2, 1, 1 })
end

function FLAT.ScrollBar(sb)
    FadeArt(sb)
    FadeArt(sb.ScrollUpButton)
    FadeArt(sb.ScrollDownButton)
    local thumb = sb.ThumbTexture or (sb.GetThumbTexture and sb:GetThumbTexture())
    if thumb then
        thumb:SetAlpha(1)
        thumb:SetColorTexture(1, 1, 1, 0.28)
        thumb:SetWidth(5)
    end
end

function FLAT.CloseButton(b)
    FadeArt(b)
    local x = b:CreateTexture(nil, "ARTWORK")
    x:SetTexture("Interface\\Buttons\\UI-StopButton")
    x:SetSize(12, 12)
    x:SetPoint("CENTER")
    x:SetVertexColor(0.85, 0.85, 0.85, 1)
    FLAT.Highlight(b, 0.1)
end

function FLAT.Icon(tex, parent)
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    if parent then
        local border = parent:CreateTexture(nil, "BACKGROUND", nil, 7)
        border:SetColorTexture(0, 0, 0, 1)
        border:SetPoint("TOPLEFT", tex, "TOPLEFT", -1, 1)
        border:SetPoint("BOTTOMRIGHT", tex, "BOTTOMRIGHT", 1, -1)
    end
end
