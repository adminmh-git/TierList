-- Which talent tree the character is in, and whether a list counts as main spec or offspec.
--
-- A list has a spec: nil / "any" = always main spec (the old behaviour), "off" = always offspec,
-- or a tree / build key ("protection", "shockadin", ...): main spec while the character's
-- talents are in that tree, offspec otherwise. Offspec hits never say NEED.
--
-- WoW Forever has switched the old talent calls off and spends talents through C_ClassTalents /
-- C_Traits (as Wishwell and ForeverDungeonJournal note), so that is read too. Everything that is
-- missing or hidden makes the detection return nil, and then every list counts as main spec.
local _, TL = ...
local Spec = {}
TL.Spec = Spec

-- talent tab -> tree key, in the game's tab order (GearQuest's spec ids)
Spec.TREES = {
    WARRIOR = { "arms", "fury", "protection" },
    PALADIN = { "holy", "protection", "retribution" },
    HUNTER = { "beast_mastery", "marksmanship", "survival" },
    ROGUE = { "assassination", "combat", "subtlety" },
    PRIEST = { "discipline", "holy", "shadow" },
    SHAMAN = { "elemental", "enhancement", "restoration" },
    MAGE = { "arcane", "fire", "frost" },
    WARLOCK = { "affliction", "demonology", "destruction" },
    DRUID = { "balance", "feral", "restoration" },
}

-- words for /tl spec
Spec.ALIASES = { tank = "protection", deff = "protection", def = "protection", heal = "holy", ret = "retribution" }

-- builds that live in another tree
Spec.TREE_OF = {
    shockadin = "holy", bear = "feral", enhancement_tank = "enhancement",
    battlemage_frost = "frost", battlemage_fire = "fire", battlemage_arcane = "arcane",
}

local LABELS = {
    shockadin = "Shockadin", bear = "Bear Tank", feral = "Feral", enhancement_tank = "Enhancement Tank",
    beast_mastery = "Beast Mastery", battlemage_frost = "Battle Mage (Frost)",
    battlemage_fire = "Battle Mage (Fire)", battlemage_arcane = "Battle Mage (Arcane)",
}

function Spec.Label(key)
    if not key or key == "any" then
        return "Any spec"
    elseif key == "off" then
        return "Always offspec"
    end
    return LABELS[key] or (key:gsub("_", " "):gsub("(%a)(%w*)", function(a, b) return a:upper() .. b end))
end

function Spec.TreeOf(key)
    return key and (Spec.TREE_OF[key] or key)
end

-- The choices for a list of this class: its three trees plus GearQuest's builds.
function Spec.Options(class)
    local out, seen = {}, {}
    local function add(k)
        if k and not seen[k] then
            seen[k] = true
            out[#out + 1] = k
        end
    end
    for _, k in ipairs(Spec.TREES[class] or {}) do
        add(k)
    end
    for _, k in ipairs(TL:PickSpecs(class)) do
        add(k)
    end
    return out
end

-- ---------------------------------------------------------------------------
-- Reading the talents
-- ---------------------------------------------------------------------------
local function Plain(v)
    if issecretvalue and issecretvalue(v) then
        return nil
    end
    return v
end

local function Call(fn, ...)
    if type(fn) ~= "function" then
        return nil
    end
    local ok, a, b, c, d, e = pcall(fn, ...)
    if ok then
        return Plain(a), Plain(b), Plain(c), Plain(d), Plain(e)
    end
    return nil
end

-- 1. the old calls (other clients)
local function FromTalentInfo()
    if type(GetNumTalents) ~= "function" or type(GetTalentInfo) ~= "function" then
        return nil
    end
    local points, found = { 0, 0, 0 }, false
    for tab = 1, 3 do
        for i = 1, tonumber(Call(GetNumTalents, tab)) or 0 do
            local name, _, _, _, rank = Call(GetTalentInfo, tab, i)
            if type(name) == "string" then
                found = true
                points[tab] = points[tab] + (tonumber(rank) or 0)
            end
        end
    end
    return found and points or nil, "talents"
end

-- 2. C_ClassTalents / C_Traits (WoW Forever). Three tree ids: one per classic tree. One tree id:
-- the three classic trees side by side, split at the two widest gaps between node columns.
local function NodeRank(info)
    if type(info) ~= "table" then
        return 0
    end
    local r = tonumber(Plain(info.currentRank) or Plain(info.ranksPurchased) or Plain(info.activeRank)) or 0
    return r > 0 and r or 0
end

local function Bands(nodes)
    local xs, seen = {}, {}
    for _, n in ipairs(nodes) do
        local x = math.floor(n.x + 0.5)
        if not seen[x] then
            seen[x] = true
            xs[#xs + 1] = x
        end
    end
    table.sort(xs)
    if #xs < 3 then
        return nil
    end
    local gaps = {}
    for i = 1, #xs - 1 do
        gaps[#gaps + 1] = { at = i, gap = xs[i + 1] - xs[i] }
    end
    table.sort(gaps, function(a, b)
        if a.gap ~= b.gap then
            return a.gap > b.gap
        end
        return a.at < b.at
    end)
    if not gaps[2] or gaps[2].gap <= 0 then
        return nil
    end
    local c1, c2 = math.min(gaps[1].at, gaps[2].at), math.max(gaps[1].at, gaps[2].at)
    local points = { 0, 0, 0 }
    for _, n in ipairs(nodes) do
        local x = math.floor(n.x + 0.5)
        local band = (x <= xs[c1] and 1) or (x <= xs[c2] and 2) or 3
        points[band] = points[band] + n.rank
    end
    return points
end

local function FromTraits()
    if not (C_ClassTalents and C_Traits) then
        return nil
    end
    local configID = Call(C_ClassTalents.GetActiveConfigID)
    if not configID then
        return nil
    end
    local config = Call(C_Traits.GetConfigInfo, configID)
    local trees = type(config) == "table" and Plain(config.treeIDs) or nil
    if type(trees) ~= "table" or #trees == 0 then
        return nil
    end
    if #trees >= 3 then
        local points = { 0, 0, 0 }
        for tab = 1, 3 do
            for _, nodeID in ipairs(Call(C_Traits.GetTreeNodes, trees[tab]) or {}) do
                points[tab] = points[tab] + NodeRank(Call(C_Traits.GetNodeInfo, configID, nodeID))
            end
        end
        return points, "traits"
    end
    local nodes = {}
    for _, treeID in ipairs(trees) do
        for _, nodeID in ipairs(Call(C_Traits.GetTreeNodes, treeID) or {}) do
            local info = Call(C_Traits.GetNodeInfo, configID, nodeID)
            local x = type(info) == "table" and tonumber(Plain(info.posX))
            if x then
                nodes[#nodes + 1] = { x = x, rank = NodeRank(info) }
            end
        end
    end
    local points = #nodes > 0 and Bands(nodes) or nil
    return points, "traits"
end

-- 3. GetTalentTabInfo: pointsSpent is 3rd on old clients, 5th from Wrath on
local function FromTabInfo()
    if type(GetTalentTabInfo) ~= "function" then
        return nil
    end
    local points, found = { 0, 0, 0 }, false
    for tab = 1, 3 do
        local a, _, c, _, e = Call(GetTalentTabInfo, tab)
        local spent = tonumber(type(a) == "number" and e or c)
        if spent then
            found = true
            points[tab] = spent
        end
    end
    return found and points or nil, "tab info"
end

-- Points per tree { p1, p2, p3 } and where they came from, or nil.
function Spec.Points()
    for _, read in ipairs({ FromTalentInfo, FromTraits, FromTabInfo }) do
        local ok, points, source = pcall(read)
        if ok and points and (points[1] + points[2] + points[3]) > 0 then
            return points, source
        end
    end
    return nil
end

-- The tree the character is in now ("protection", "holy", ...), or nil when unknown.
-- /tl spec <name> sets it by hand for this character; /tl spec auto goes back to the talents.
local cache, failedAt
function Spec.Current()
    local key = TL.charKey
    local manual = key and TL.db and TL.db.specOverride and TL.db.specOverride[key]
    if manual then
        return Spec.TreeOf(manual), "set by hand"
    end
    -- nothing readable yet (e.g. right after login): try again after a few seconds
    if cache == false and failedAt and GetTime() - failedAt > 5 then
        cache = nil
    end
    if cache == nil then
        cache = false
        failedAt = GetTime()
        local points, source = Spec.Points()
        local trees = Spec.TREES[TL.playerClass or ""]
        if points and trees then
            local best = 1
            for tab = 2, 3 do
                if points[tab] > points[best] then
                    best = tab
                end
            end
            cache = { tree = trees[best], source = source, points = points }
        end
    end
    if cache then
        return cache.tree, cache.source, cache.points
    end
    return nil
end

function Spec.Invalidate()
    cache = nil
end

-- ---------------------------------------------------------------------------
-- Main spec / offspec per list
-- ---------------------------------------------------------------------------
-- "main" or "off". A list for a spec counts as main spec only while the talents are in its tree;
-- with the tree unknown it counts as main spec, so nothing is hidden.
function TL:ListRole(list)
    local s = list and list.spec
    if s == "off" then
        return "off"
    end
    if not s or s == "any" then
        return "main"
    end
    local cur = Spec.Current()
    if not cur then
        return "main"
    end
    return Spec.TreeOf(s) == cur and "main" or "off"
end

function TL:IsOffspec(list)
    return self:ListRole(list) == "off"
end

-- One chat line: the current tree and which of this character's lists are main / off.
function Spec.Describe()
    local cur, source, points = Spec.Current()
    local main, off = {}, {}
    for _, l in ipairs(TL:ListsForChar()) do
        if TL:IsOffspec(l) then
            off[#off + 1] = l.name
        else
            main[#main + 1] = l.name
        end
    end
    local head = cur and ("spec " .. Spec.Label(cur) .. " (" .. (source or "?") ..
        (points and (", " .. table.concat(points, "/")) or "") .. ")") or "spec unknown (all lists count as main spec)"
    return head .. ". Main spec: " .. (#main > 0 and table.concat(main, ", ") or "-") ..
        ". Offspec: " .. (#off > 0 and table.concat(off, ", ") or "-") .. "."
end

-- Talent changes: read again a moment later, say so once when the tree changed.
local function Recheck(quiet)
    Spec.Invalidate()
    if not TL.db or not TL.charKey then
        return
    end
    local cur = Spec.Current()
    TL.db.lastSpec = TL.db.lastSpec or {}
    local before = TL.db.lastSpec[TL.charKey]
    TL.db.lastSpec[TL.charKey] = cur or before
    if cur and before and cur ~= before and not quiet then
        TL.Print(Spec.Describe())
    end
    TL:Changed()
end
Spec.Recheck = Recheck

local pending
local function Later()
    if pending then
        return
    end
    pending = true
    C_Timer.After(1, function()
        pending = false
        TL.Safe("spec", Recheck)
    end)
end

for _, ev in ipairs({ "PLAYER_TALENT_UPDATE", "CHARACTER_POINTS_CHANGED", "TRAIT_CONFIG_UPDATED",
    "ACTIVE_TALENT_GROUP_CHANGED", "PLAYER_SPECIALIZATION_CHANGED", "ACTIVE_PLAYER_SPECIALIZATION_CHANGED" }) do
    TL:On(ev, Later)
end
TL:On("PLAYER_LOGIN", function()
    -- talents are not always readable right at login
    C_Timer.After(2, function() TL.Safe("spec", Recheck, true) end)
end)
