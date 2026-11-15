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
    questMobsAllZones = false,   -- quest mob menu: false = current zone only
    -- Attack cast after the ping, per class (SavedVariables are account-wide):
    -- classFile -> spell ID from Abilities.lua, or a custom spell name string.
    attackByClass = {},
    shown = true,
    macroIcon = "Ability_Hunter_MarkedForDeath",   -- one of ns.MACRO_ICONS
    appearance = {
        theme = "tooltip",   -- key from Themes.LIST
        scale = 1,           -- window scale, SCALE_MIN..SCALE_MAX
        opacity = 1,         -- multiplier on the theme's background alpha, 0..1
        locked = false,      -- true = window can't be dragged
        compact = false,     -- true = no title row, tighter layout
    },
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
    for class, choice in pairs(db.attackByClass) do
        local t = type(choice)
        if t == "string" then
            choice = ns.Macro.CleanName(choice)
            db.attackByClass[class] = choice ~= "" and choice or nil
        elseif t ~= "number" then
            db.attackByClass[class] = nil
        end
    end

    if not ns.IsValidMacroIcon(db.macroIcon) then db.macroIcon = ns.MACRO_ICONS[1] end

    local a = db.appearance
    if not ns.Themes.IsValid(a.theme) then a.theme = ns.Themes.DEFAULT end
    a.scale = math.min(ns.SCALE_MAX, math.max(ns.SCALE_MIN, tonumber(a.scale) or 1))
    a.opacity = math.min(1, math.max(0, tonumber(a.opacity) or 1))
    a.locked = a.locked and true or false
    a.compact = a.compact and true or false
end

ns.SCALE_MIN, ns.SCALE_MAX, ns.SCALE_STEP = 0.7, 1.5, 0.05
ns.OPACITY_STEP = 0.05

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
-- Attack (spell cast after the ping), stored per class
---------------------------------------------------------------------------
-- Set on ADDON_LOADED. "UNKNOWN" keeps the table key valid if UnitClass fails.
ns.playerClass = "UNKNOWN"

function ns.GetAttackChoice()
    return ns.db.attackByClass[ns.playerClass]
end

-- The attack choice as one string, so the Settings page can hold it:
-- "" = none, "spell:<id>" = list entry, "custom:<name>" = typed spell name.
function ns.EncodeAttack(choice)
    if type(choice) == "number" then
        return "spell:" .. choice
    elseif type(choice) == "string" then
        return "custom:" .. choice
    end
    return ""
end

function ns.DecodeAttack(value)
    if type(value) ~= "string" then return nil end
    local id = value:match("^spell:(%d+)$")
    if id then return tonumber(id) end
    local name = value:match("^custom:(.+)$")
    if name then
        name = ns.Macro.CleanName(name)
        return name ~= "" and name or nil
    end
    return nil
end

-- choice: spell ID from Abilities.lua, custom name string, or nil for none.
function ns.SetAttack(choice)
    if type(choice) == "string" then
        choice = ns.Macro.CleanName(choice)
        if choice == "" then choice = nil end
    end
    ns.Set("attack", ns.EncodeAttack(choice))
end

-- Localized spell name for an ID, or nil if the client doesn't know it.
function ns.GetSpellName(id)
    if C_Spell and C_Spell.GetSpellName then
        return C_Spell.GetSpellName(id)
    elseif GetSpellInfo then
        return (GetSpellInfo(id))
    end
end

function ns.IsSpellKnown(id)
    if IsPlayerSpell then
        return IsPlayerSpell(id) and true or false
    elseif C_SpellBook and C_SpellBook.IsSpellKnown then
        return C_SpellBook.IsSpellKnown(id) and true or false
    end
    return true
end

-- Display name for a list entry (localized when possible).
function ns.GetAbilityName(entry)
    return ns.GetSpellName(entry.id) or entry.name
end

-- The name the macro casts, or nil when no attack is chosen.
function ns.GetAttackName()
    local choice = ns.GetAttackChoice()
    if type(choice) == "string" then
        return choice
    elseif type(choice) == "number" then
        local entry = ns.Abilities.Find(ns.playerClass, choice)
        local name = ns.GetSpellName(choice) or (entry and entry.name)
        if name and entry and entry.toggle then
            name = "!" .. name
        end
        return name
    end
    return nil
end

---------------------------------------------------------------------------
-- Macro
---------------------------------------------------------------------------
local wasTooLong = false

function ns.Rebuild()
    local text = ns.Macro.Build(ns.db, ns.GetAttackName())
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
-- Settings fields: every setting the window and the game's Settings page
-- both edit. Both sides write through ns.Set, so each sees the other's
-- changes. Options.lua registers a Settings proxy for each field.
--   get()      current value
--   set(v)     writes the saved value (nothing else)
--   changed(v) side effects after a write
--   queues     true = the effect waits for combat to end (warn the player)
---------------------------------------------------------------------------
local function MacroChanged()
    ns.UI.RefreshValues()
    ns.OnSettingsChanged()
end

local function AppearanceChanged()
    ns.RunOutOfCombat("appearance", function() ns.UI.ApplyAppearance() end)
end

local function AppearanceField(key)
    return {
        get = function() return ns.db.appearance[key] end,
        set = function(v) ns.db.appearance[key] = v end,
        changed = AppearanceChanged,
        queues = true,
    }
end

ns.FIELDS = {
    shown = {
        get = function() return ns.db.shown end,
        set = function(v) ns.db.shown = v and true or false end,
        changed = function() ns.RunOutOfCombat("shown", function() ns.UI.ApplyShown() end) end,
        queues = true,
    },
    pingType = {
        get = function() return ns.db.pingType end,
        set = function(v)
            if ns.Macro.IsValidPingType(v) then ns.db.pingType = v end
        end,
        changed = MacroChanged,
        queues = true,
    },
    raidMarker = {
        get = function() return ns.db.options.raidMarker end,
        set = function(v)
            v = math.floor(tonumber(v) or 0)
            if v < 0 or v > ns.Macro.MARKER_COUNT then v = 0 end
            ns.db.options.raidMarker = v
        end,
        changed = MacroChanged,
        queues = true,
    },
    attack = {
        get = function() return ns.EncodeAttack(ns.GetAttackChoice()) end,
        set = function(v) ns.db.attackByClass[ns.playerClass] = ns.DecodeAttack(v) end,
        changed = function()
            ns.UI.RefreshAttack()
            ns.OnSettingsChanged()
        end,
        queues = true,
    },
    macroIcon = {
        get = function() return ns.db.macroIcon end,
        set = function(v)
            if ns.IsValidMacroIcon(v) then ns.db.macroIcon = v end
        end,
        changed = function() ns.RunOutOfCombat("macroIcon", ns.UpdateMacroIcon) end,
        queues = true,
    },
    theme = AppearanceField("theme"),
    scale = AppearanceField("scale"),
    opacity = AppearanceField("opacity"),
    compact = AppearanceField("compact"),
    -- Lock only affects dragging, so it takes effect immediately.
    locked = {
        get = function() return ns.db.appearance.locked end,
        set = function(v) ns.db.appearance.locked = v and true or false end,
        changed = function() end,
    },
}

-- Boolean targeting options. Enemies only / Friendlies only switch each other off.
ns.OPTION_KEYS = {
    "exactMatch", "skipDead", "enemiesOnly", "friendliesOnly",
    "clearIfNotFound", "returnToPrevious",
}
local EXCLUSIVE = { enemiesOnly = "friendliesOnly", friendliesOnly = "enemiesOnly" }

for _, key in ipairs(ns.OPTION_KEYS) do
    ns.FIELDS[key] = {
        get = function() return ns.db.options[key] end,
        set = function(v) ns.db.options[key] = v and true or false end,
        changed = function(v)
            if v and EXCLUSIVE[key] then
                ns.Set(EXCLUSIVE[key], false)
            end
            MacroChanged()
        end,
        queues = true,
    }
end

local warnedThisCombat = false

-- Writes the value and runs its side effects. Called directly, or by the
-- Settings proxy's setter (Options.lua).
function ns.ApplyField(key, value)
    local field = ns.FIELDS[key]
    if not field or field.get() == value then return end
    field.set(value)
    field.changed(field.get())
    if field.queues and InCombatLockdown() and not warnedThisCombat then
        warnedThisCombat = true
        Print(L.QUEUED)
    end
end

function ns.Get(key)
    return ns.FIELDS[key].get()
end

-- The one way to change a setting. Going through the Settings proxy (when
-- the Settings page is registered) also refreshes that page's controls.
function ns.Set(key, value)
    local setting = ns.Options and ns.Options.GetSetting(key)
    if setting then
        local ok, err = pcall(setting.SetValue, setting, value)
        if not ok then geterrorhandler()(err) end
        if ns.FIELDS[key].get() == value then return end
    end
    ns.ApplyField(key, value)
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
-- Quest mobs: reads the quest log into plain tables for ns.QuestMobs.Collect.
-- Returns mobs, hiddenCount, or nil + reason.
---------------------------------------------------------------------------
function ns.GetQuestMobs(allZones)
    local QL = C_QuestLog
    if not (QL and QL.GetNumQuestLogEntries and QL.GetInfo and QL.GetQuestObjectives) then
        return nil, L.QUEST_API_MISSING
    end

    local quests = {}
    for i = 1, QL.GetNumQuestLogEntries() do
        local info = QL.GetInfo(i)
        if info and not info.isHeader and not info.isHidden and info.questID
            and not IsSecret(info.questID) then
            local objectives = {}
            for _, o in ipairs(QL.GetQuestObjectives(info.questID) or {}) do
                if not IsSecret(o.text) and not IsSecret(o.type) and not IsSecret(o.finished) then
                    objectives[#objectives + 1] = o
                end
            end
            local onMap = true
            if QL.IsOnMap then
                local v = QL.IsOnMap(info.questID)
                onMap = not IsSecret(v) and v and true or false
            end
            quests[#quests + 1] = {
                title = (not IsSecret(info.title) and info.title) or "?",
                onMap = onMap,
                objectives = objectives,
            }
        end
    end
    return ns.QuestMobs.Collect(quests, allZones)
end

---------------------------------------------------------------------------
-- Window toggle / reset
---------------------------------------------------------------------------
function ns.SetShown(shown)
    ns.Set("shown", shown and true or false)
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
        ns.UI.ApplyAppearance()
        ns.UI.ResetPosition()
        ns.UI.ApplyShown()
        ns.Rebuild()
        if ns.Options then ns.Options.RefreshAll() end
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
-- Macro icons are a file ID or a bare icon name ("INV_Misc_QuestionMark"),
-- never a full "Interface\\Icons\\..." path: the macro API rejects paths.
-- Choices for the "Macro icon" setting (names under Interface\Icons).
ns.MACRO_ICONS = {
    "Ability_Hunter_MarkedForDeath",   -- red crosshair
    "Ability_Hunter_SniperShot",       -- Hunter's Mark
    "Ability_Marksmanship",            -- bow on target
    "Ability_Hunter_EagleEye",         -- eye
    "INV_Misc_Spyglass_03",            -- spyglass
}
local QUESTION_MARK_ICON = 134400   -- INV_Misc_QuestionMark

function ns.IsValidMacroIcon(name)
    for _, n in ipairs(ns.MACRO_ICONS) do
        if n == name then return true end
    end
    return false
end

-- Icon candidates for the chosen icon, best first.
local function MacroIcons()
    local name = ns.db and ns.db.macroIcon or ns.MACRO_ICONS[1]
    local icons = {}
    if GetFileIDFromPath then
        local id = GetFileIDFromPath("Interface\\Icons\\" .. name)
        if type(id) == "number" and id > 0 then icons[#icons + 1] = id end
    end
    icons[#icons + 1] = name
    icons[#icons + 1] = QUESTION_MARK_ICON
    return icons
end

-- Tries each icon until the client accepts one. Returns the macro index or nil.
local function CreateMacroWithIcon(perChar)
    for _, icon in ipairs(MacroIcons()) do
        local ok, index = pcall(CreateMacro, ns.ACTION_MACRO_NAME, icon, ns.ACTION_MACRO_BODY, perChar)
        if ok and index and index > 0 then return index end
    end
end

local function RepairMacro(index)
    for _, icon in ipairs(MacroIcons()) do
        if pcall(EditMacro, index, ns.ACTION_MACRO_NAME, icon, ns.ACTION_MACRO_BODY) then
            return true
        end
    end
end

-- After the icon setting changes: update the macro if it already exists.
-- Out of combat only (macros can't be edited in combat).
function ns.UpdateMacroIcon()
    local index = GetMacroIndexByName(ns.ACTION_MACRO_NAME)
    if index and index > 0 then
        RepairMacro(index)
    end
end

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
        -- Also resets the icon, in case an earlier version left it broken.
        if not RepairMacro(index) then
            Print(L.MACRO_FAILED)
            return
        end
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
        index = CreateMacroWithIcon(perChar)
        if not index then
            Print(L.MACRO_FAILED)
            return
        end
    end

    -- From the Settings page's Create button: get the panel out of the way so
    -- the action bars can be reached while the macro is on the cursor.
    if SettingsPanel and SettingsPanel:IsShown() and HideUIPanel then
        HideUIPanel(SettingsPanel)
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
    elseif cmd == "options" or cmd == "config" or cmd == "settings" then
        ns.OpenSettings()
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
events:RegisterEvent("SPELLS_CHANGED")

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
        ns.playerClass = select(2, UnitClass("player")) or "UNKNOWN"

        ns.UI.Create()
        ns.UI.Refresh()
        ns.RunOutOfCombat("shown", function()
            ns.UI.ApplyAppearance()   -- scale first, so the saved position lands right
            ns.UI.RestorePosition()
            ns.UI.ApplyShown()
        end)
        ns.UI.SetCombatLocked(InCombatLockdown())
        ns.Rebuild()
        ns.Options.Register()

    elseif event == "PLAYER_REGEN_DISABLED" then
        ns.UI.SetCombatLocked(true)

    elseif event == "PLAYER_REGEN_ENABLED" then
        warnedThisCombat = false
        local ranQueued = FlushQueue()
        ns.UI.SetCombatLocked(false)
        if ranQueued then
            Print(L.QUEUE_APPLIED)
        end

    elseif event == "SPELLS_CHANGED" then
        -- Spell names can resolve late on first login; only rebuild if the
        -- cast line would actually change (this event fires often).
        if ns.db then
            local text = ns.Macro.Build(ns.db, ns.GetAttackName())
            if text ~= ns.macrotext then
                ns.Rebuild()
            end
        end
    end
end)
