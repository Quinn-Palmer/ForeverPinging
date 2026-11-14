-- Core.lua: init, saved variables, combat queue, events, slash commands.

local addonName, ns = ...
local L = ns.L

ns.DB_VERSION = 1

ns.DEFAULTS = {
    dbVersion = ns.DB_VERSION,
    name = "",
    pingType = "default",
    options = {
        exactMatch = true,
        skipDead = true,
        enemiesOnly = false,
        friendliesOnly = false,
        clearIfNotFound = false,
        returnToPrevious = false,
        raidMarker = 0,
    },
    optionsExpanded = false,
    shown = true,
    -- position = { point, relativePoint, x, y } (nil = default spot)
}

local function Print(msg)
    print("|cff33ccffForever Pinging:|r " .. tostring(msg))
end
ns.Print = Print

-- Fills in missing keys without touching values the user already has.
local function MergeDefaults(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            MergeDefaults(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

local function Migrate(db)
    -- No migrations yet; v1 is the first schema.
    db.dbVersion = ns.DB_VERSION
end

local function Sanitize(db)
    if not ns.Macro.IsValidPingType(db.pingType) then
        db.pingType = "default"
    end
    if type(db.name) ~= "string" then db.name = "" end
    -- Enemies only and Friendlies only are mutually exclusive.
    if db.options.enemiesOnly and db.options.friendliesOnly then
        db.options.friendliesOnly = false
    end
end

---------------------------------------------------------------------------
-- Combat queue: secure attributes, and showing/moving the frame that holds
-- the secure button, can't change during combat lockdown. Work is keyed so
-- repeated edits collapse into one run when combat ends.
---------------------------------------------------------------------------
local queue, queueOrder = {}, {}

function ns.RunOutOfCombat(key, fn)
    if not InCombatLockdown() then
        fn()
        return true
    end
    if not queue[key] then
        queueOrder[#queueOrder + 1] = key
    end
    queue[key] = fn
    return false
end

local function FlushQueue()
    if #queueOrder == 0 then return false end
    local order = queueOrder
    local fns = queue
    queue, queueOrder = {}, {}
    for _, key in ipairs(order) do
        fns[key]()
    end
    return true
end

---------------------------------------------------------------------------
-- Macro
---------------------------------------------------------------------------
local wasTooLong = false

function ns.Rebuild()
    local text = ns.Macro.Build(ns.db)
    ns.macrotext = text

    local tooLong = ns.Macro.IsTooLong(text)
    if tooLong and not wasTooLong then
        Print(L.TOO_LONG_CHAT:format(#text, ns.Macro.MAX_LENGTH))
    end
    wasTooLong = tooLong

    ns.UI.UpdateStatus()
    -- Read ns.macrotext at run time so a queued apply uses the latest text.
    ns.RunOutOfCombat("macro", function() ns.UI.ApplyMacro(ns.macrotext) end)
end

-- Called by the UI whenever name / ping type / options change.
function ns.OnSettingsChanged()
    ns.Rebuild()
end

---------------------------------------------------------------------------
-- Target name (guarded against Midnight secret values)
---------------------------------------------------------------------------
local function IsSecret(v)
    return issecretvalue ~= nil and issecretvalue(v)
end

-- Returns name, or nil + reason.
function ns.GetTargetName()
    if InCombatLockdown() then
        return nil, L.TARGET_COMBAT
    end
    local exists = UnitExists("target")
    if IsSecret(exists) then return nil, L.TARGET_SECRET end
    if not exists then return nil, L.NO_TARGET end

    local name = UnitName("target")
    if IsSecret(name) then return nil, L.TARGET_SECRET end
    if type(name) ~= "string" or name == "" then return nil, L.NO_TARGET end
    return name
end

---------------------------------------------------------------------------
-- Window toggle / reset
---------------------------------------------------------------------------
function ns.SetShown(shown)
    ns.db.shown = shown
    if not ns.RunOutOfCombat("shown", function() ns.UI.ApplyShown() end) then
        Print(L.QUEUED)
    end
end

function ns.ToggleWindow()
    ns.SetShown(not ns.db.shown)
end

function ns.Reset()
    local doReset = function()
        local db = ns.db
        for k in pairs(db) do db[k] = nil end
        MergeDefaults(db, ns.DEFAULTS)
        ns.UI.Refresh()
        ns.UI.ResetPosition()
        ns.UI.ApplyShown()
        ns.Rebuild()
        Print(L.RESET_DONE)
    end
    if not ns.RunOutOfCombat("reset", doReset) then
        Print(L.QUEUED)
    end
end

function ns.PrintDebug()
    local text = ns.macrotext or ""
    if text == "" then
        Print(L.DEBUG_EMPTY)
        return
    end
    Print(L.DEBUG_HEADER:format(#text))
    for line in text:gmatch("[^\n]+") do
        print("  " .. line)
    end
    if ns.Macro.IsTooLong(text) then
        Print(L.TOO_LONG:format(#text, ns.Macro.MAX_LENGTH))
    end
end

---------------------------------------------------------------------------
-- Keybinding / action bar
---------------------------------------------------------------------------
-- Labels for Bindings.xml. The client looks these up as globals by name,
-- so they're the one unavoidable exception to "no globals".
BINDING_HEADER_FOREVERPINGING = L.TITLE
_G["BINDING_NAME_CLICK ForeverPingingPingButton:LeftButton"] = L.BINDING_PING

ns.ACTION_MACRO_NAME = "FP Ping"      -- macro names max 16 chars
ns.ACTION_MACRO_BODY = "/click ForeverPingingPingButton"
local ACTION_MACRO_ICON = "Interface\\Icons\\Ability_Hunter_MarkedForDeath"

-- Creates (or repairs) an account-wide macro that clicks the Ping! button,
-- then puts it on the cursor so the player can drop it on an action bar.
-- The macro only forwards a click; the name/options still come from the window.
function ns.CreateActionMacro()
    if InCombatLockdown() then
        Print(L.MACRO_COMBAT)
        return
    end

    local index = GetMacroIndexByName(ns.ACTION_MACRO_NAME)
    if index and index > 0 then
        EditMacro(index, nil, nil, ns.ACTION_MACRO_BODY)
    else
        local numAccount, numChar = GetNumMacros()
        local perChar
        if numAccount < (MAX_ACCOUNT_MACROS or 120) then
            perChar = false
        elseif numChar < (MAX_CHARACTER_MACROS or 30) then
            perChar = true
        else
            Print(L.MACRO_FULL)
            return
        end
        index = CreateMacro(ns.ACTION_MACRO_NAME, ACTION_MACRO_ICON, ns.ACTION_MACRO_BODY, perChar)
        if not index or index == 0 then
            Print(L.MACRO_FAILED)
            return
        end
    end

    PickupMacro(index)
    Print(L.MACRO_READY:format(ns.ACTION_MACRO_NAME))
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
SLASH_FOREVERPINGING1 = "/fp"
SLASH_FOREVERPINGING2 = "/foreverpinging"
SlashCmdList.FOREVERPINGING = function(msg)
    local cmd = (msg or ""):lower():match("^%s*(%S*)")
    if cmd == "" then
        ns.ToggleWindow()
    elseif cmd == "reset" then
        ns.Reset()
    elseif cmd == "debug" then
        ns.PrintDebug()
    elseif cmd == "macro" then
        ns.CreateActionMacro()
    else
        Print(L.HELP)
    end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")

events:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= addonName then return end
        events:UnregisterEvent("ADDON_LOADED")

        ForeverPingingDB = ForeverPingingDB or {}
        local db = ForeverPingingDB
        if (tonumber(db.dbVersion) or 0) < ns.DB_VERSION then
            Migrate(db)
        end
        MergeDefaults(db, ns.DEFAULTS)
        Sanitize(db)
        ns.db = db

        ns.UI.Create()
        ns.UI.Refresh()
        ns.RunOutOfCombat("shown", function()
            ns.UI.RestorePosition()
            ns.UI.ApplyShown()
        end)
        ns.UI.SetCombatLocked(InCombatLockdown())
        ns.Rebuild()

    elseif event == "PLAYER_REGEN_DISABLED" then
        ns.UI.SetCombatLocked(true)

    elseif event == "PLAYER_REGEN_ENABLED" then
        local ranQueued = FlushQueue()
        ns.UI.SetCombatLocked(false)
        if ranQueued then
            Print(L.QUEUE_APPLIED)
        end
    end
end)
