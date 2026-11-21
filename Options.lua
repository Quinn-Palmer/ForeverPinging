-- Options.lua: the page under Options > AddOns > Forever Pinging.
--
-- Every control is a Settings proxy over a field in Core's ns.FIELDS, so the
-- page and the window both read and write ForeverPingingDB through ns.Set.
-- A change on either side shows up on the other straight away.

local _, ns = ...
local L = ns.L

local Options = {}
ns.Options = Options

local settings = {}   -- field key -> Setting
local category

function Options.GetSetting(key)
    return settings[key]
end

-- Opens the Settings page, or explains why it can't.
function ns.OpenSettings()
    if category and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(category:GetID())
    else
        ns.Print(L.SETTINGS_MISSING)
    end
end

-- Re-reads every control from saved settings (after /fp reset).
function Options.RefreshAll()
    for _, setting in pairs(settings) do
        if setting.NotifyUpdate then
            pcall(setting.NotifyUpdate, setting)
        end
    end
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function VarType(default)
    local t = type(default)
    if t == "boolean" then return Settings.VarType.Boolean end
    if t == "number" then return Settings.VarType.Number end
    return Settings.VarType.String
end

local function Register(key, label, default)
    local field = ns.FIELDS[key]
    local setting = Settings.RegisterProxySetting(category,
        "FOREVERPINGING_" .. key:upper(), VarType(default), label, default,
        field.get,
        function(value) ns.ApplyField(key, value) end)
    settings[key] = setting
    return setting
end

-- Settings.CreateCheckbox was CreateCheckBox before 11.0.
local CreateCheckbox = Settings.CreateCheckbox or Settings.CreateCheckBox

local function Checkbox(key, label, default, tooltip)
    CreateCheckbox(category, Register(key, label, default), tooltip)
end

-- build(add) calls add(value, label) for each choice.
local function Dropdown(key, label, default, tooltip, build)
    local function GetOptions()
        local container = Settings.CreateControlTextContainer()
        build(function(value, text) container:Add(value, text) end)
        return container:GetData()
    end
    Settings.CreateDropdown(category, Register(key, label, default), GetOptions, tooltip)
end

local function Percent(value)
    return ("%d%%"):format(math.floor(value * 100 + 0.5))
end

local function Seconds(value)
    if value <= 0 then return L.SET_COOLDOWN_OFF end
    return (("%.2f"):format(value):gsub("0+$", ""):gsub("%.$", "")) .. "s"
end

-- format defaults to Percent.
local function Slider(key, label, default, min, max, step, tooltip, format)
    local options = Settings.CreateSliderOptions(min, max, step)
    if MinimalSliderWithSteppersMixin and options.SetLabelFormatter then
        options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, format or Percent)
    end
    Settings.CreateSlider(category, Register(key, label, default), options, tooltip)
end

local function Header(layout, text)
    if layout and CreateSettingsListSectionHeaderInitializer then
        layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
    end
end

local function Button(layout, label, buttonText, onClick, tooltip)
    if layout and CreateSettingsButtonInitializer then
        layout:AddInitializer(CreateSettingsButtonInitializer(label, buttonText, onClick, tooltip, true))
    end
end

---------------------------------------------------------------------------
-- Page
---------------------------------------------------------------------------
local function Build(layout)
    local D = ns.DEFAULTS

    Header(layout, L.SECTION_WINDOW)
    Checkbox("shown", L.SET_SHOWN, D.shown, L.SET_SHOWN_TIP)
    Dropdown("theme", L.SET_THEME, D.appearance.theme, L.SET_THEME_TIP, function(add)
        for _, key in ipairs(ns.Themes.LIST) do
            add(key, L["THEME_" .. key])
        end
    end)
    Slider("scale", L.SET_SCALE, D.appearance.scale, ns.SCALE_MIN, ns.SCALE_MAX, ns.SCALE_STEP, L.SET_SCALE_TIP)
    Slider("opacity", L.SET_OPACITY, D.appearance.opacity, 0, 1, ns.OPACITY_STEP, L.SET_OPACITY_TIP)
    Checkbox("locked", L.SET_LOCKED, D.appearance.locked, L.SET_LOCKED_TIP)
    Checkbox("compact", L.SET_COMPACT, D.appearance.compact, L.SET_COMPACT_TIP)
    Button(layout, L.SET_RESET_POS, L.SET_RESET_POS_BUTTON, function()
        if not ns.RunOutOfCombat("position", function() ns.UI.ResetPosition() end) then
            ns.Print(L.QUEUED)
        end
    end, L.SET_RESET_POS_TIP)

    Header(layout, L.SECTION_PING)
    Dropdown("pingType", L.SET_PING_TYPE, D.pingType, nil, function(add)
        for _, pt in ipairs(ns.Macro.PING_TYPES) do
            add(pt.key, L["PING_" .. pt.key])
        end
    end)
    Slider("pingCooldown", L.SET_COOLDOWN, D.pingCooldown, 0, ns.COOLDOWN_MAX, ns.COOLDOWN_STEP,
        L.SET_COOLDOWN_TIP, Seconds)
    Dropdown("attack", L.ATTACK, "", L.SET_ATTACK_TIP, function(add)
        add("", L.ATTACK_NONE)
        for _, entry in ipairs(ns.Abilities.ForClass(ns.playerClass)) do
            local name = ns.GetAbilityName(entry)
            if not ns.IsSpellKnown(entry.id) then
                name = ("|cff808080%s|r"):format(name)
            end
            add(ns.EncodeAttack(entry.id), name)
        end
        -- A custom spell is typed in the window; show it here when one is set.
        local choice = ns.GetAttackChoice()
        if type(choice) == "string" then
            add(ns.EncodeAttack(choice), L.ATTACK_CUSTOM_SET:format(choice))
        end
    end)
    Dropdown("raidMarker", L.RAID_MARKER, D.options.raidMarker, nil, function(add)
        for i = 0, ns.Macro.MARKER_COUNT do
            add(i, L["MARKER_" .. i])
        end
    end)

    Header(layout, L.SECTION_TARGETING)
    for _, key in ipairs(ns.OPTION_KEYS) do
        Checkbox(key, L["OPT_" .. key], D.options[key], rawget(L, "OPT_" .. key .. "_TIP"))
    end

    Header(layout, L.SECTION_KEYBIND)
    Dropdown("macroIcon", L.SET_MACRO_ICON, D.macroIcon, L.SET_MACRO_ICON_TIP, function(add)
        for _, name in ipairs(ns.MACRO_ICONS) do
            add(name, ("|TInterface\\Icons\\%s:16:16|t %s"):format(name, L["ICON_" .. name]))
        end
    end)
    Button(layout, L.SET_MACRO, L.SET_MACRO_BUTTON, function() ns.CreateActionMacro() end, L.SET_MACRO_TIP)
end

-- Called once from ADDON_LOADED, after ns.db is ready.
function Options.Register()
    if category then return end
    if not (Settings and Settings.RegisterVerticalLayoutCategory and Settings.RegisterProxySetting) then
        return   -- no Settings API: the window and slash commands still work
    end

    local layout
    category, layout = Settings.RegisterVerticalLayoutCategory(L.TITLE)
    local ok, err = pcall(Build, layout)
    if not ok then
        -- Don't break the addon over the options page; show the error once.
        ns.Print(L.SETTINGS_FAILED)
        geterrorhandler()(err)
    end
    Settings.RegisterAddOnCategory(category)
end
