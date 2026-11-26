-- Version check between players. TierList users in the same group or guild tell each other which
-- version they run, and an older copy says once that a newer one is out and where to get it.
-- An addon cannot update itself (no downloads, no file writes) - updating is WowUp-CF's job.
local _, TL = ...
local Version = {}
TL.Version = Version

Version.PREFIX = "TierList"
Version.URL = "https://github.com/adminmh-git/TierList"
Version.THROTTLE = 30 -- seconds between two broadcasts on the same channel

local told = {}      -- newer versions already announced this session
local replied = {}   -- senders with an older version we answered this session
Version.lastSend = {} -- channel -> GetTime() of the last broadcast

function Version.Parse(v)
    local out = {}
    for n in tostring(v or ""):gsub("^[vV]", ""):gmatch("%d+") do
        out[#out + 1] = tonumber(n)
    end
    return out
end

-- 1 if a is newer than b, -1 if older, 0 if the same
function Version.Compare(a, b)
    local x, y = Version.Parse(a), Version.Parse(b)
    for i = 1, math.max(#x, #y) do
        local p, q = x[i] or 0, y[i] or 0
        if p ~= q then
            return p > q and 1 or -1
        end
    end
    return 0
end

local function Send(channel, target)
    if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then
        return false
    end
    -- may be refused (e.g. addon messages blocked in some instances) - never an error for the player
    return pcall(C_ChatInfo.SendAddonMessage, Version.PREFIX, "V:" .. TL.VERSION, channel, target)
end

local function Broadcast(channel)
    local now = GetTime()
    local last = Version.lastSend[channel]
    if last and now - last < Version.THROTTLE then
        return
    end
    Version.lastSend[channel] = now
    Send(channel)
end

function Version.AnnounceGroup()
    if IsInGroup and LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
        Broadcast("INSTANCE_CHAT")
    elseif IsInRaid and IsInRaid() then
        Broadcast("RAID")
    elseif IsInGroup and IsInGroup() then
        Broadcast("PARTY")
    end
end

-- true when sent (guild info can still be missing right after login)
function Version.AnnounceGuild()
    if IsInGuild and IsInGuild() then
        Broadcast("GUILD")
        return true
    end
    return false
end

function Version.Notify(newer)
    if TL.db and Version.Compare(newer, TL.db.newestSeen) > 0 then
        TL.db.newestSeen = newer
    end
    if told[newer] then
        return
    end
    told[newer] = true
    TL.Print(string.format("version |cff00ff00%s|r is out (you have %s). Update it in WowUp-CF, or download it from %s",
        newer, TL.VERSION, Version.URL .. "/releases/latest"))
end

local function IsMe(sender)
    local short = Ambiguate and Ambiguate(sender, "none") or sender:match("^[^-]+")
    return short == UnitName("player")
end

function Version.OnMessage(prefix, msg, channel, sender)
    if prefix ~= Version.PREFIX then
        return
    end
    if issecretvalue and (issecretvalue(msg) or issecretvalue(sender)) then
        return
    end
    local v = type(msg) == "string" and msg:match("^V:(%d+[%.%d]*)$")
    if not v or type(sender) ~= "string" or IsMe(sender) then
        return
    end
    local c = Version.Compare(v, TL.VERSION)
    if c > 0 then
        Version.Notify(v)
    elseif c < 0 and channel ~= "WHISPER" and not replied[sender] then
        -- they broadcast an older version: tell just them which one is current
        replied[sender] = true
        Send("WHISPER", sender)
    end
end

-- for /tl version
function Version.Describe()
    local newest = TL.db and TL.db.newestSeen
    local tail = (newest and Version.Compare(newest, TL.VERSION) > 0)
        and (" - |cff00ff00" .. newest .. "|r is out, update in WowUp-CF or at " .. Version.URL .. "/releases/latest")
        or " - no newer version seen in your group or guild"
    return "version " .. TL.VERSION .. tail .. "."
end

if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
    pcall(C_ChatInfo.RegisterAddonMessagePrefix, Version.PREFIX)
end

TL:On("CHAT_MSG_ADDON", Version.OnMessage)

TL:On("PLAYER_LOGIN", function()
    if not TL.db then
        return
    end
    if TL.db.newestSeen and Version.Compare(TL.db.newestSeen, TL.VERSION) <= 0 then
        TL.db.newestSeen = nil -- updated in the meantime
    elseif TL.db.newestSeen then
        local newer = TL.db.newestSeen
        C_Timer.After(10, function() TL.Safe("version", Version.Notify, newer) end)
    end
end)

local guildDone
TL:On("PLAYER_ENTERING_WORLD", function()
    C_Timer.After(15, function()
        TL.Safe("version", function()
            if not guildDone then
                guildDone = Version.AnnounceGuild()
            end
            Version.AnnounceGroup()
        end)
    end)
end)

local rosterPending
TL:On("GROUP_ROSTER_UPDATE", function()
    if rosterPending then
        return
    end
    rosterPending = true
    C_Timer.After(5, function()
        rosterPending = false
        TL.Safe("version", Version.AnnounceGroup)
    end)
end)
