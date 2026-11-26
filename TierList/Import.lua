-- TierList import/export.
-- Understands: TierList share strings, wowsims JSON exports, Sixty Upgrades set exports (JSON),
-- wowsims .siml gear sets,
-- and free text (item links, Wowhead URLs, item IDs or item names, with optional S/A/B/C markers).
local _, TL = ...
local Import = {}
TL.Import = Import

local Trim = function(s) return TL.Trim(s) end

local VALID_TIER = { S = true, A = true, B = true, C = true }

-- ---------------------------------------------------------------------------
-- Share string: TL1;name=..;class=..;build=..;S=1,2;A=3;B=;C=
-- ---------------------------------------------------------------------------
local function clean(v)
    return (tostring(v or ""):gsub("[;=|\n\r]", " "))
end

function Import.ShareString(list)
    local parts = { "TL1", "name=" .. clean(list.name), "class=" .. clean(list.class or ""), "build=" .. clean(list.build or "") }
    for _, tier in ipairs(TL.TIERS) do
        local ids = {}
        for _, slot in ipairs(TL.SLOTS) do
            for _, row in ipairs(TL:SlotItems(list, slot.key)) do
                if row.e.tier == tier then
                    local token = tostring(row.id)
                    if row.e.slot then
                        token = token .. "@" .. row.e.slot
                    end
                    ids[#ids + 1] = token
                end
            end
        end
        parts[#parts + 1] = tier .. "=" .. table.concat(ids, ",")
    end
    return table.concat(parts, ";")
end

function Import.PlainText(list)
    local out = { "# " .. list.name .. (list.build ~= "" and (" - " .. list.build) or "") }
    for _, slot in ipairs(TL.SLOTS) do
        local rows = TL:SlotItems(list, slot.key)
        if #rows > 0 then
            out[#out + 1] = ""
            out[#out + 1] = "# " .. slot.label
            for _, row in ipairs(rows) do
                local name = TL:ItemBasics(row.id)
                out[#out + 1] = row.e.tier .. ": " .. (name or "?") .. " (" .. row.id .. ")"
            end
        end
    end
    return table.concat(out, "\n")
end

local function ParseShare(text)
    local body = text:match("TL1;[^\n\r]*")
    if not body then
        return nil
    end
    local res = { format = "TierList share string", items = {}, unknown = {}, meta = {} }
    for part in body:gmatch("[^;]+") do
        local k, v = part:match("^%s*([^=]+)=(.*)$")
        if k then
            k = Trim(k)
            if k == "name" or k == "class" or k == "build" then
                res.meta[k] = Trim(v)
            elseif VALID_TIER[k] then
                for token in v:gmatch("[^,]+") do
                    local id, slot = token:match("^%s*(%d+)@?(%u*)%s*$")
                    if id then
                        res.items[#res.items + 1] = { id = tonumber(id), tier = k, slot = slot ~= "" and slot or nil }
                    end
                end
            end
        end
    end
    if res.meta.class == "" then
        res.meta.class = nil
    end
    return res
end

-- ---------------------------------------------------------------------------
-- JSON exports
--   wowsims:        {"player":{"equipment":{"items":[{"id":123,...},{},...]}}} or {"items":[...]}
--   Sixty Upgrades: "Export Set" -> {"name":..,"character":{"gameClass":..},"items":[{"name":..,"id":..,
--                   "enchant":{..},"slot":"HEAD"},..],"wishlist":[{"name":..,"id":..,"type":"ITEM"},..]}
--                   Set items get the chosen tier, wishlist items the tier below it.
-- ---------------------------------------------------------------------------
local TIER_BELOW = { S = "A", A = "B", B = "C", C = "C" }

local function ArrayAt(text, key, from)
    local _, bracket = text:find('"' .. key .. '"%s*:%s*%[', from or 1)
    return bracket
end

-- Calls fn(objectText) for every top-level {...} of the JSON array whose "[" is at `bracket`.
local function EachObject(text, bracket, fn)
    local depth, objStart = 0, nil
    local i, n = bracket + 1, #text
    while i <= n do
        local c = text:sub(i, i)
        if c == "{" then
            depth = depth + 1
            if depth == 1 then
                objStart = i
            end
        elseif c == "}" then
            depth = depth - 1
            if depth == 0 and objStart then
                fn(text:sub(objStart, i))
                objStart = nil
            end
        elseif c == "]" and depth == 0 then
            break
        elseif c == '"' then
            -- skip strings so braces inside names do not count
            local j = i + 1
            while j <= n do
                local cj = text:sub(j, j)
                if cj == "\\" then
                    j = j + 1
                elseif cj == '"' then
                    break
                end
                j = j + 1
            end
            i = j
        end
        i = i + 1
    end
end

-- The object's own "id" (the first one; nested enchant/gem objects come later).
local function ObjectId(obj)
    local id = tonumber(obj:match('^{%s*"id"%s*:%s*(%d+)') or obj:match('[{,]%s*"id"%s*:%s*(%d+)'))
    return (id and id > 0) and id or nil
end

local function ParseJson(text, tier)
    local sixty = text:find('"exportOptions"%s*:') or text:find('"wishlist"%s*:%s*%[')
        or text:find('"slot"%s*:%s*"[%u_]+%d?"')
    local start = text:find('"equipment"%s*:%s*{%s*"items"%s*:%s*%[')
    local items = ArrayAt(text, "items", start)
    local wish = sixty and ArrayAt(text, "wishlist")
    if not items and not wish then
        return nil
    end
    local res = { format = sixty and "Sixty Upgrades set" or "wowsims JSON", items = {}, unknown = {} }
    if items then
        EachObject(text, items, function(obj)
            local id = ObjectId(obj)
            if id then
                res.items[#res.items + 1] = { id = id, tier = tier }
            end
        end)
    end
    if wish then
        local wishTier, count = TIER_BELOW[tier] or "A", 0
        EachObject(text, wish, function(obj)
            local kind = (obj:match('"type"%s*:%s*"([^"]*)"') or "ITEM"):upper()
            if kind:find("ENCHANT") or kind:find("GEM") or kind:find("RUNE") or kind:find("GLYPH") then
                return -- those ids are not items
            end
            local id = ObjectId(obj)
            if id then
                res.items[#res.items + 1] = { id = id, tier = wishTier }
                count = count + 1
            end
        end)
        if count > 0 then
            res.format = res.format .. ", wishlist as " .. wishTier
        end
    end
    if sixty then
        local class = text:match('"gameClass"%s*:%s*"(%a+)"')
        res.meta = { name = text:match('^%s*{%s*"name"%s*:%s*"([^"]*)"'), class = class and class:upper() or nil }
    end
    return res
end

-- ---------------------------------------------------------------------------
-- wowsims .siml gear set: "head   stalwart_helm + arcanum_of_focus"
-- ---------------------------------------------------------------------------
local SIML_SLOTS = {
    head = "HEAD", neck = "NECK", shoulder = "SHOULDER", shoulders = "SHOULDER", back = "BACK", chest = "CHEST",
    wrist = "WRIST", hands = "HANDS", waist = "WAIST", legs = "LEGS", feet = "FEET",
    finger1 = "FINGER", finger2 = "FINGER", trinket1 = "TRINKET", trinket2 = "TRINKET",
    main_hand = "MAINHAND", mainhand = "MAINHAND", off_hand = "OFFHAND", offhand = "OFFHAND", ranged = "RANGED",
}

local function ParseSiml(text, tier)
    local res = { format = "wowsims gear set", items = {}, unknown = {} }
    -- siml lines are lower-case snake_case: "head   stalwart_helm + arcanum_of_focus"
    local strict = 0
    for line in text:gmatch("[^\r\n]+") do
        local slot = line:match("^%s*([%l_]+%d?)%s+[%l%d_]+%s*$") or line:match("^%s*([%l_]+%d?)%s+[%l%d_]+%s+%+")
        if slot and SIML_SLOTS[slot] then
            strict = strict + 1
        end
    end
    if strict < 2 and not text:match("^%s*siml%s+%d") then
        return nil
    end
    local found = false
    for line in text:gmatch("[^\r\n]+") do
        local slot, slug = line:match("^%s*([%a_]+%d?)%s+([%w_]+)")
        if slot and SIML_SLOTS[slot:lower()] then
            found = true
            local id = TL:IdBySlug(slug:lower())
            if id then
                local slotKey = SIML_SLOTS[slot:lower()]
                local override = (slotKey ~= TL:DefaultSlotKey(id)) and slotKey or nil
                res.items[#res.items + 1] = { id = id, tier = tier, slot = override }
            else
                res.unknown[#res.unknown + 1] = Trim(line)
            end
        end
    end
    return found and res or nil
end

-- ---------------------------------------------------------------------------
-- Free text
-- ---------------------------------------------------------------------------
local SLOT_WORDS = {
    head = true, helm = true, helmet = true, neck = true, necklace = true, amulet = true, shoulder = true,
    shoulders = true, back = true, cloak = true, cape = true, chest = true, wrist = true, wrists = true,
    bracers = true, hands = true, hand = true, gloves = true, waist = true, belt = true, legs = true,
    pants = true, feet = true, boots = true, ring = true, rings = true, finger = true, ["ring 1"] = true,
    ["ring 2"] = true, trinket = true, trinkets = true, ["trinket 1"] = true, ["trinket 2"] = true,
    weapon = true, ["main hand"] = true, mainhand = true, ["main-hand"] = true, ["off hand"] = true,
    offhand = true, ["off-hand"] = true, ["two-hand"] = true, ["two hand"] = true, ["2h"] = true,
    ["1h"] = true, shield = true, ranged = true, relic = true, libram = true, totem = true, idol = true,
    wand = true, bow = true, gun = true, crossbow = true, thrown = true,
}

-- Reads an S/A/B/C marker at the start of a line. Returns tier, restOfLine.
local function TierMarker(line)
    local t, rest = line:match("^%s*%[([SsAaBbCc])%]%s*(.*)$")
    if t then return t:upper(), rest end
    t, rest = line:match("^%s*([SsAaBbCc])[%s%-]?[Tt][Ii][Ee][Rr]%s*[:%-=]?%s*(.*)$")
    if t then return t:upper(), rest end
    t, rest = line:match("^%s*[Tt][Ii][Ee][Rr]%s*([SsAaBbCc])%s*[:%-=]?%s*(.*)$")
    if t then return t:upper(), rest end
    t, rest = line:match("^%s*([SsAaBbCc])%s*[:=%)]%s*(.*)$")
    if t then return t:upper(), rest end
    t, rest = line:match("^%s*([SsAaBbCc])%s+%-%s+(.*)$")
    if t then return t:upper(), rest end
    t = line:match("^%s*([SsAaBbCc])%s*$")
    if t then return t:upper(), "" end
    return nil, line
end

local function MatchName(text)
    text = Trim(text)
    if text == "" then
        return nil
    end
    local ids = TL:IdsByName(text)
    if ids then
        return ids[1]
    end
    -- drop a leading slot label ("Head: ...", "Trinket 1 - ...")
    local label, rest = text:match("^([%a][%a%s%-]-%d?)%s*[:%-]%s+(.+)$")
    if label and SLOT_WORDS[Trim(label):lower()] then
        ids = TL:IdsByName(rest)
        if ids then
            return ids[1]
        end
        text = rest
    end
    -- try the pieces between separators
    local pieces = {}
    local normalized = text:gsub("\226\128\147", "|"):gsub("\226\128\148", "|"):gsub("%s+%-%s+", "|")
        :gsub("[%(%)%[%]\t,;:]", "|")
    for piece in normalized:gmatch("[^|]+") do
        pieces[#pieces + 1] = Trim(piece)
    end
    for _, piece in ipairs(pieces) do
        if piece ~= "" then
            ids = TL:IdsByName(piece)
            if ids then
                return ids[1]
            end
        end
    end
    return nil
end

local function ParseText(text, tier)
    local res = { format = "text", items = {}, unknown = {} }
    local current = tier
    for raw in text:gmatch("[^\r\n]+") do
        local line = raw
        if not line:match("^%s*#") and not line:match("^%s*//") and Trim(line) ~= "" then
            local t, rest = TierMarker(line)
            if t then
                current = t
                line = rest
            end
            local found = false
            for id in line:gmatch("|Hitem:(%d+)") do
                res.items[#res.items + 1] = { id = tonumber(id), tier = current }
                found = true
            end
            if not found then
                for id in line:gmatch("[Ii][Tt][Ee][Mm][=/:](%d+)") do
                    res.items[#res.items + 1] = { id = tonumber(id), tier = current }
                    found = true
                end
            end
            if not found then
                local paren = line:match("%(%s*(%d+)%s*%)")
                if paren then
                    res.items[#res.items + 1] = { id = tonumber(paren), tier = current }
                    found = true
                end
            end
            if not found then
                local stripped = Trim(line:gsub("^%s*[%-%*%+#>]+%s*", ""):gsub("^%s*%d+[%.%)]%s+", ""))
                if stripped == "" then
                    found = true -- just a tier header
                elseif stripped:match("^[%d%s,;]+$") then
                    for id in stripped:gmatch("%d+") do
                        res.items[#res.items + 1] = { id = tonumber(id), tier = current }
                    end
                    found = true
                else
                    local id = MatchName(stripped)
                    if id then
                        res.items[#res.items + 1] = { id = id, tier = current }
                        found = true
                    end
                end
            end
            if not found then
                res.unknown[#res.unknown + 1] = Trim(raw)
            end
        end
    end
    return res
end

-- ---------------------------------------------------------------------------
-- Entry point
-- ---------------------------------------------------------------------------
-- Returns { format, items = { {id, tier, slot}, ... }, unknown = { lines }, meta = {name, class, build} }
function Import.Parse(text, defaultTier)
    defaultTier = VALID_TIER[defaultTier or ""] and defaultTier or "S"
    text = tostring(text or "")
    local res = ParseShare(text)
        or ParseJson(text, defaultTier)
        or ParseSiml(text, defaultTier)
        or ParseText(text, defaultTier)
    -- drop duplicates, keep the first mention
    local seen, items = {}, {}
    for _, it in ipairs(res.items) do
        if it.id and not seen[it.id] then
            seen[it.id] = true
            items[#items + 1] = it
        end
    end
    res.items = items
    return res
end

-- Puts parsed items into a list. replace = clear the list first.
function Import.Apply(res, list, replace)
    if replace then
        list.items = {}
    end
    local counts = { added = 0, changed = 0, same = 0 }
    for _, it in ipairs(res.items) do
        local r = TL:AddItem(list, it.id, it.tier, it.slot)
        counts[r] = (counts[r] or 0) + 1
    end
    TL:Changed()
    return counts
end
