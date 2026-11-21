-- Macro.lua: pure macrotext builder.
-- Input: a settings table shaped like ForeverPingingDB. Output: a macrotext string.
-- No WoW API calls in here, so it can be loaded and tested outside the client.

local _, ns = ...
ns = ns or {}

local Macro = {}
ns.Macro = Macro

Macro.MAX_LENGTH = 255

-- Ping types, in dropdown order. `arg` is the numeric /ping alias
-- (1 attack, 2 warning, 3 on my way, 4 assist). Numbers are used instead of
-- words because the word forms resolve through localized globals and only
-- match on English clients. nil = contextual (no type argument).
-- noPing = leave out the /ping line (target, mark and attack only).
Macro.PING_TYPES = {
    { key = "default", arg = nil },
    { key = "attack", arg = "1" },
    { key = "assist", arg = "4" },
    { key = "warning", arg = "2" },
    { key = "onmyway", arg = "3" },
    { key = "none", noPing = true },
}

local PING_ARG, NO_PING = {}, {}
for _, pt in ipairs(Macro.PING_TYPES) do
    PING_ARG[pt.key] = pt.arg or false
    NO_PING[pt.key] = pt.noPing or nil
end

-- Raid markers: 0 = none, 1..8 = star..skull (the /tm index).
Macro.MARKER_COUNT = 8

-- Trims the name and strips line breaks so it can't inject extra macro lines.
function Macro.CleanName(name)
    if type(name) ~= "string" then
        return ""
    end
    name = name:gsub("[\r\n]+", " ")
    name = name:match("^%s*(.-)%s*$")
    return name
end

function Macro.IsValidPingType(key)
    return PING_ARG[key] ~= nil
end

-- Returns the macrotext, or "" when there is no name to target.
-- attackName (optional) is the already-resolved, localized spell to cast at the
-- target after pinging; Core works it out from the per-class choice. A leading
-- "!" (auto-repeat abilities) is kept so a second press doesn't toggle it off.
function Macro.Build(settings, attackName)
    settings = settings or {}
    local name = Macro.CleanName(settings.name)
    if name == "" then
        return ""
    end

    local o = settings.options or {}
    local lines = {}
    local function add(line) lines[#lines + 1] = line end

    local attack = Macro.CleanName(attackName)
    local hasAttack = attack ~= "" and attack ~= "!"

    -- Targeting by name keeps the old target when nothing matches; clearing
    -- first means a failed search leaves no target, so nothing gets pinged.
    -- Forced on when there's an attack, or a miss would cast it at whatever
    -- you had targeted before (macro conditions can't check the unit's name).
    if o.clearIfNotFound or hasAttack then
        add("/cleartarget")
    end

    add((o.exactMatch and "/targetexact " or "/target ") .. name)

    -- Multiple [..] groups are OR'd, so one line covers every filter.
    local conds = {}
    if o.skipDead then conds[#conds + 1] = "[dead]" end
    if o.enemiesOnly then
        conds[#conds + 1] = "[help]"
    elseif o.friendliesOnly then
        conds[#conds + 1] = "[harm]"
    end
    if #conds > 0 then
        add("/cleartarget " .. table.concat(conds))
    end

    local marker = tonumber(o.raidMarker) or 0
    if marker >= 1 and marker <= Macro.MARKER_COUNT and marker % 1 == 0 then
        add("/tm [@target,exists] " .. marker)
    end

    if not NO_PING[settings.pingType] then
        local ping = "/ping [@target,exists]"
        local arg = PING_ARG[settings.pingType]
        if arg then
            ping = ping .. " " .. arg
        end
        add(ping)
    end

    -- [harm,nodead] keeps the cast off friendlies, corpses and yourself.
    if hasAttack then
        add("/cast [@target,harm,nodead] " .. attack)
    end

    if o.returnToPrevious then
        add("/targetlasttarget")
    end

    return table.concat(lines, "\n")
end

function Macro.IsTooLong(text)
    return #text > Macro.MAX_LENGTH
end

return Macro
