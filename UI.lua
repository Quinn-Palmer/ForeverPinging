-- UI.lua: main window, options panel, secure Ping! button, themes.
--
-- Combat rules this file follows:
--   * The Ping! button's attributes are only set via ns.RunOutOfCombat.
--   * The main frame is the secure button's parent, so it is never shown,
--     hidden, moved, resized, rescaled or re-skinned in combat (Core queues
--     ApplyAppearance and ApplyShown).
--   * Inputs are disabled while in combat; Ping! keeps working.

local _, ns = ...
local L = ns.L

local UI = {}
ns.UI = UI

local WIDTH = 290
local QUEST_BTN = 22
local PAD = 10
local ROW_H = 22
local GEAR = 18
local WHITE = "Interface\\Buttons\\WHITE8X8"

-- Row offsets from the top, normal and compact (compact drops the title row).
local LAYOUT = {
    -- height leaves ~6px between the ping type dropdown and the bottom row.
    normal  = { row1 = -32, row2 = -60, height = 118 },
    compact = { row1 = -PAD, row2 = -PAD - 28, height = 96 },
}

local main, title, closeBtn, nameBox, questBtn, useTargetBtn, pingTypeDD, attackDD, pingBtn
local optionsToggle, settingsBtn, statusText
local optionsPanel, markerDD
local checkboxes = {}   -- key -> { button, label }
local themedLabels = {} -- font strings coloured with theme.text
local locked = false
local theme             -- resolved theme currently applied

-- Ping cooldown state (UI.ApplyCooldown)
local cooldownHandler   -- secure handler that owns the OnClick wrap
local secureCooldown = false   -- true = the wrap can read GetTime, works in combat
local lastFallbackPing  -- GetTime() of the last click let through by the fallback

-- Runs in the restricted environment before every OnClick of Ping!, in or out
-- of combat. Returning false drops the click, so the macro never runs.
-- lastPing lives in the handler's private snippet environment.
local COOLDOWN_SNIPPET = [[
    if down then return end   -- useOnKeyDown=false: only the release acts
    local cd = owner:GetAttribute("cooldown") or 0
    if cd <= 0 or not GetTime then return end
    local now = GetTime()
    if lastPing and now - lastPing < cd then return false end
    lastPing = now
]]

local function SetTooltip(frame, titleText, body)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(titleText)
        if body then
            GameTooltip:AddLine(body, 1, 1, 1, true)
        end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", GameTooltip_Hide)
end

-- Fills the name box (Use Target, quest mob menu). Out of combat only.
local function SetName(name)
    if InCombatLockdown() then
        ns.Print(L.TARGET_COMBAT)
        return
    end
    ns.db.name = name
    nameBox:SetText(name)
    nameBox:SetCursorPosition(0)
    nameBox:ClearFocus()
    ns.OnSettingsChanged()
end

-- Quest mob menu: unfinished kill objectives, current zone by default so it
-- stays short. "All zones" is a checkbox inside the menu itself.
local function BuildQuestMenu(_, root)
    root:CreateTitle(L.QUEST_MOBS)
    local mobs, hidden = ns.GetQuestMobs(ns.db.questMobsAllZones)
    if not mobs then
        root:CreateTitle(hidden)   -- reason
        return
    end

    if #mobs == 0 then
        root:CreateTitle(ns.db.questMobsAllZones and L.QUEST_NONE or L.QUEST_NONE_HERE)
    end
    for _, mob in ipairs(mobs) do
        local label = mob.name
        if mob.numRequired and mob.numRequired > 0 then
            label = ("%s |cff999999%d/%d|r"):format(mob.name, mob.numFulfilled or 0, mob.numRequired)
        end
        local item = root:CreateButton(label, function() SetName(mob.name) end)
        if item.SetTooltip then
            item:SetTooltip(function(tooltip)
                tooltip:SetText(mob.name)
                for _, questTitle in ipairs(mob.quests) do
                    tooltip:AddLine(questTitle, 1, 1, 1)
                end
            end)
        end
    end
    if hidden > 0 then
        root:CreateTitle(L.QUEST_MORE_ELSEWHERE:format(hidden))
    end

    root:CreateDivider()
    root:CreateCheckbox(L.QUEST_ALL_ZONES,
        function() return ns.db.questMobsAllZones end,
        function() ns.db.questMobsAllZones = not ns.db.questMobsAllZones end)

    -- Safety net if "All zones" is on with a full quest log.
    if root.SetScrollMode then root:SetScrollMode(300) end
end

-- Opens the menu beside the window's right edge instead of at the cursor, so it
-- doesn't cover the name box / Use Target. Falls back to a cursor context menu if
-- the Menu internals differ in this client.
local function OpenQuestMenu(owner)
    local ok = pcall(function()
        local desc = MenuUtil.CreateRootMenuDescription(MenuVariants.GetDefaultContextMenuMixin())
        Menu.PopulateDescription(BuildQuestMenu, owner, desc)
        Menu.GetManager():OpenMenu(owner, desc, CreateAnchor("TOPLEFT", main, "TOPRIGHT", 2, 0))
    end)
    if not ok then
        MenuUtil.CreateContextMenu(owner, BuildQuestMenu)
    end
end

-- Custom attack: any spell name the player types (for spells not in the list).
StaticPopupDialogs.FOREVERPINGING_CUSTOM_ATTACK = {
    text = L.ATTACK_CUSTOM_PROMPT,
    button1 = ACCEPT,
    button2 = CANCEL,
    hasEditBox = true,
    maxLetters = 64,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    OnShow = function(self)
        local eb = self.GetEditBox and self:GetEditBox() or self.editBox
        local choice = ns.GetAttackChoice()
        eb:SetText(type(choice) == "string" and choice or "")
        eb:HighlightText()
        eb:SetFocus()
    end,
    OnAccept = function(self)
        local eb = self.GetEditBox and self:GetEditBox() or self.editBox
        ns.SetAttack(eb:GetText())
    end,
    EditBoxOnEnterPressed = function(self)
        ns.SetAttack(self:GetText())
        self:GetParent():Hide()
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
}

-- Attack menu: none, this class's instant attacks (unlearned ones greyed but
-- still selectable), then a custom spell name.
local function BuildAttackMenu(_, root)
    root:CreateRadio(L.ATTACK_NONE,
        function() return ns.GetAttackChoice() == nil end,
        function() ns.SetAttack(nil) end)

    for _, entry in ipairs(ns.Abilities.ForClass(ns.playerClass)) do
        local name = ns.GetAbilityName(entry)
        local known = ns.IsSpellKnown(entry.id)
        local label = known and name or ("|cff808080%s|r"):format(name)
        local radio = root:CreateRadio(label,
            function() return ns.GetAttackChoice() == entry.id end,
            function() ns.SetAttack(entry.id) end)
        if radio.SetTooltip and (entry.note or not known) then
            radio:SetTooltip(function(tooltip)
                tooltip:SetText(name)
                if entry.note then tooltip:AddLine(entry.note, 1, 1, 1, true) end
                if not known then tooltip:AddLine(L.ATTACK_NOT_LEARNED, 1, 0.3, 0.3, true) end
            end)
        end
    end

    root:CreateDivider()
    local choice = ns.GetAttackChoice()
    local customLabel = type(choice) == "string" and L.ATTACK_CUSTOM_SET:format(choice) or L.ATTACK_CUSTOM
    root:CreateRadio(customLabel,
        function() return type(ns.GetAttackChoice()) == "string" end,
        function() StaticPopup_Show("FOREVERPINGING_CUSTOM_ATTACK") end)

    if root.SetScrollMode then root:SetScrollMode(400) end
end

---------------------------------------------------------------------------
-- Theme helpers
---------------------------------------------------------------------------
local function ClassColor()
    local c
    if C_ClassColor and C_ClassColor.GetClassColor then
        c = C_ClassColor.GetClassColor(ns.playerClass)
    end
    if not c and RAID_CLASS_COLORS then
        c = RAID_CLASS_COLORS[ns.playerClass]
    end
    if c and c.r then return { c.r, c.g, c.b } end
end

local function StylePanel(f, opacity)
    f:SetBackdrop(theme.backdrop)
    local bg, border = theme.bg, theme.border
    f:SetBackdropColor(bg[1], bg[2], bg[3], (bg[4] or 1) * opacity)
    f:SetBackdropBorderColor(border[1], border[2], border[3], border[4] or 1)
end

-- Flat themes hide the template's red button art and draw a box instead.
-- The box textures sit in the BACKGROUND layer (under the label); the hover
-- texture is in the HIGHLIGHT layer, so the client shows it on mouseover.
local function SkinButton(btn, accent)
    local flat = theme.flatButtons
    for _, key in ipairs({ "Left", "Middle", "Right" }) do
        if btn[key] then btn[key]:SetShown(not flat) end
    end
    local hl = btn:GetHighlightTexture()
    if hl then hl:SetAlpha(flat and 0 or 1) end

    if flat and not btn.fpSkin then
        local s = {}
        s.border = btn:CreateTexture(nil, "BACKGROUND", nil, -8)
        s.border:SetAllPoints()
        s.fill = btn:CreateTexture(nil, "BACKGROUND", nil, -7)
        s.fill:SetPoint("TOPLEFT", 1, -1)
        s.fill:SetPoint("BOTTOMRIGHT", -1, 1)
        s.hover = btn:CreateTexture(nil, "HIGHLIGHT")
        s.hover:SetPoint("TOPLEFT", 1, -1)
        s.hover:SetPoint("BOTTOMRIGHT", -1, 1)
        for _, t in pairs(s) do t:SetTexture(WHITE) end
        btn.fpSkin = s
    end
    if btn.fpSkin then
        for _, t in pairs(btn.fpSkin) do t:SetShown(flat) end
    end

    if flat then
        local b = theme.button
        local edge = (accent and theme.accent) or b.border
        btn.fpSkin.border:SetVertexColor(edge[1], edge[2], edge[3], edge[4] or 1)
        btn.fpSkin.fill:SetVertexColor(b.bg[1], b.bg[2], b.bg[3], b.bg[4] or 1)
        btn.fpSkin.hover:SetVertexColor(b.hover[1], b.hover[2], b.hover[3], b.hover[4] or 1)
        btn:SetNormalFontObject(GameFontHighlight)
    else
        btn:SetNormalFontObject(GameFontNormal)
    end
    btn:SetHighlightFontObject(GameFontHighlight)
    btn:SetDisabledFontObject(GameFontDisable)
end

local function ColorText()
    if not theme then return end
    local c = locked and theme.textDisabled or theme.text
    for _, fs in ipairs(themedLabels) do
        fs:SetTextColor(c[1], c[2], c[3])
    end
    local i = locked and theme.textDisabled or theme.input
    nameBox:SetTextColor(i[1], i[2], i[3])
end

local function ApplyLayout(compact)
    local l = compact and LAYOUT.compact or LAYOUT.normal
    main:SetHeight(l.height)
    title:SetShown(not compact)
    closeBtn:SetShown(not compact)

    nameBox:ClearAllPoints()
    nameBox:SetPoint("TOPLEFT", PAD + 6, l.row1)   -- InputBoxTemplate's left art sits outside the box
    useTargetBtn:ClearAllPoints()
    useTargetBtn:SetPoint("TOPRIGHT", -PAD, l.row1)
    pingTypeDD:ClearAllPoints()
    pingTypeDD:SetPoint("TOPLEFT", PAD, l.row2)
    pingBtn:ClearAllPoints()
    pingBtn:SetPoint("TOPRIGHT", -PAD, l.row2 + 1)
end

---------------------------------------------------------------------------
-- Position
---------------------------------------------------------------------------
local function SavePosition()
    local point, _, relPoint, x, y = main:GetPoint(1)
    if point then
        ns.db.position = { point, relPoint, x, y }
    end
end

function UI.ResetPosition()
    ns.db.position = nil
    main:ClearAllPoints()
    main:SetPoint("CENTER", UIParent, "CENTER", 0, 150)
end

function UI.RestorePosition()
    local pos = ns.db.position
    main:ClearAllPoints()
    if type(pos) == "table" and pos[1] then
        main:SetPoint(pos[1], UIParent, pos[2] or pos[1], tonumber(pos[3]) or 0, tonumber(pos[4]) or 0)
    else
        main:SetPoint("CENTER", UIParent, "CENTER", 0, 150)
    end
end

---------------------------------------------------------------------------
-- Build
---------------------------------------------------------------------------
local function CreateMain()
    main = CreateFrame("Frame", "ForeverPingingFrame", UIParent, "BackdropTemplate")
    main:SetSize(WIDTH, LAYOUT.normal.height)
    main:SetFrameStrata("MEDIUM")
    main:SetClampedToScreen(true)
    main:SetMovable(true)
    main:EnableMouse(true)
    main:RegisterForDrag("LeftButton")
    if main.SetDontSavePosition then main:SetDontSavePosition(true) end
    main:SetScript("OnDragStart", function(self)
        if InCombatLockdown() or ns.db.appearance.locked then return end
        self:StartMoving()
    end)
    main:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition()
    end)
    main:Hide()

    title = main:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOPLEFT", PAD, -PAD)
    title:SetText(L.TITLE)

    closeBtn = CreateFrame("Button", nil, main, "UIPanelCloseButton")
    closeBtn:SetSize(24, 24)
    closeBtn:SetPoint("TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function() ns.SetShown(false) end)

    -- Row 1: name box + quest mobs + Use Target (points set by ApplyLayout)
    nameBox = CreateFrame("EditBox", nil, main, "InputBoxTemplate")
    nameBox:SetSize(WIDTH - PAD * 2 - 100 - 6 - QUEST_BTN - 4, ROW_H)
    nameBox:SetAutoFocus(false)
    nameBox:SetMaxLetters(48)
    nameBox:SetScript("OnTextChanged", function(self, userInput)
        if not userInput then return end
        ns.db.name = self:GetText()
        ns.OnSettingsChanged()
    end)
    nameBox:SetScript("OnEnterPressed", EditBox_ClearFocus)
    nameBox:SetScript("OnEscapePressed", EditBox_ClearFocus)
    SetTooltip(nameBox, L.NAME)

    useTargetBtn = CreateFrame("Button", nil, main, "UIPanelButtonTemplate")
    useTargetBtn:SetSize(100, ROW_H)
    useTargetBtn:SetText(L.USE_TARGET)
    useTargetBtn:SetScript("OnClick", function()
        local name, reason = ns.GetTargetName()
        if not name then
            ns.Print(reason)
            return
        end
        SetName(name)
    end)
    SetTooltip(useTargetBtn, L.USE_TARGET_TOOLTIP, L.USE_TARGET_TOOLTIP_BODY)

    -- Quest mob picker, between the name box and Use Target.
    questBtn = CreateFrame("Button", nil, main)
    questBtn:SetSize(QUEST_BTN, QUEST_BTN)
    questBtn:SetPoint("RIGHT", useTargetBtn, "LEFT", -4, 0)
    questBtn:SetNormalTexture("Interface\\GossipFrame\\AvailableQuestIcon")
    questBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    questBtn:SetScript("OnClick", function(self)
        if InCombatLockdown() then return end
        OpenQuestMenu(self)
    end)
    SetTooltip(questBtn, L.QUEST_MOBS, L.QUEST_MOBS_TOOLTIP_BODY)

    -- Row 2: ping type + Ping!
    pingTypeDD = CreateFrame("DropdownButton", nil, main, "WowStyle1DropdownTemplate")
    pingTypeDD:SetWidth(WIDTH - PAD * 2 - 100 - 6)
    pingTypeDD:SetupMenu(function(_, root)
        for _, pt in ipairs(ns.Macro.PING_TYPES) do
            root:CreateRadio(L["PING_" .. pt.key],
                function() return ns.db.pingType == pt.key end,
                function() ns.Set("pingType", pt.key) end)
        end
    end)

    -- The secure button. Its click runs the macrotext; addon code never
    -- targets or pings directly.
    pingBtn = CreateFrame("Button", "ForeverPingingPingButton", main,
        "SecureActionButtonTemplate, UIPanelButtonTemplate")
    pingBtn:SetSize(100, ROW_H + 2)
    pingBtn:SetText(L.PING)
    -- Both edges are registered, but useOnKeyDown=false makes the template act
    -- only on release. That way a mouse click, a keybind (Bindings.xml CLICK
    -- binding) and "/click ForeverPingingPingButton" (which sends an up-click)
    -- each fire exactly once, whatever ActionButtonUseKeyDown is set to.
    pingBtn:RegisterForClicks("AnyUp", "AnyDown")
    pingBtn:SetAttribute("useOnKeyDown", false)
    pingBtn:SetAttribute("type", "macro")
    pingBtn:SetAttribute("macrotext", "")
    pingBtn:Disable()
    SetTooltip(pingBtn, L.PING, L.PING_TOOLTIP_BODY)
    -- Fallback cooldown, only used when the secure one can't run (see
    -- UI.ApplyCooldown). Blocks a click by clearing "type" for that one click.
    pingBtn:SetScript("PreClick", function(self, _, down)
        if secureCooldown or down or InCombatLockdown() then return end
        local cd = ns.db.pingCooldown
        local now = GetTime()
        if cd > 0 and lastFallbackPing and now - lastFallbackPing < cd then
            self:SetAttribute("type", nil)
        else
            lastFallbackPing = now
        end
    end)
    pingBtn:SetScript("PostClick", function(self)
        if not InCombatLockdown() and self:GetAttribute("type") ~= "macro" then
            self:SetAttribute("type", "macro")
        end
    end)

    -- Bottom row: options toggle, status, settings gear
    optionsToggle = CreateFrame("Button", nil, main, "UIPanelButtonTemplate")
    optionsToggle:SetSize(90, 20)
    optionsToggle:SetPoint("BOTTOMLEFT", PAD, PAD)
    optionsToggle:SetScript("OnClick", function()
        ns.db.optionsExpanded = not ns.db.optionsExpanded
        UI.UpdateOptionsShown()
    end)

    settingsBtn = CreateFrame("Button", nil, main)
    settingsBtn:SetSize(GEAR, GEAR)
    settingsBtn:SetPoint("BOTTOMRIGHT", -PAD, PAD + 1)
    settingsBtn:SetNormalTexture("Interface\\WorldMap\\Gear_64Grey")
    settingsBtn:SetHighlightTexture("Interface\\WorldMap\\Gear_64Grey", "ADD")
    settingsBtn:SetScript("OnClick", function() ns.OpenSettings() end)
    SetTooltip(settingsBtn, L.SETTINGS_BUTTON, L.SETTINGS_BUTTON_TIP)

    statusText = main:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    statusText:SetPoint("LEFT", optionsToggle, "RIGHT", 8, 0)
    statusText:SetPoint("RIGHT", settingsBtn, "LEFT", -4, 0)
    statusText:SetJustifyH("LEFT")
    statusText:SetWordWrap(false)
end

local function CreateCheckbox(parent, key, y)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    cb:SetPoint("TOPLEFT", PAD - 2, y)
    local label = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    label:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    label:SetText(L["OPT_" .. key])
    themedLabels[#themedLabels + 1] = label
    cb:SetScript("OnClick", function(self)
        ns.Set(key, self:GetChecked() and true or false)
    end)
    local tip = rawget(L, "OPT_" .. key .. "_TIP")
    if tip then SetTooltip(cb, L["OPT_" .. key], tip) end
    checkboxes[key] = { button = cb, label = label }
end

local function CreateOptions()
    optionsPanel = CreateFrame("Frame", "ForeverPingingOptions", main, "BackdropTemplate")
    optionsPanel:SetPoint("TOPLEFT", main, "BOTTOMLEFT", 0, 2)
    optionsPanel:SetPoint("TOPRIGHT", main, "BOTTOMRIGHT", 0, 2)

    local y = -PAD + 2
    for _, key in ipairs(ns.OPTION_KEYS) do
        CreateCheckbox(optionsPanel, key, y)
        y = y - 24
    end

    local markerLabel = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    markerLabel:SetPoint("TOPLEFT", PAD + 2, y - 8)
    markerLabel:SetText(L.RAID_MARKER)
    themedLabels[#themedLabels + 1] = markerLabel

    markerDD = CreateFrame("DropdownButton", nil, optionsPanel, "WowStyle1DropdownTemplate")
    markerDD:SetWidth(130)
    markerDD:SetPoint("TOPRIGHT", -PAD, y - 2)
    markerDD:SetupMenu(function(_, root)
        for i = 0, ns.Macro.MARKER_COUNT do
            root:CreateRadio(L["MARKER_" .. i],
                function() return ns.db.options.raidMarker == i end,
                function() ns.Set("raidMarker", i) end)
        end
    end)

    -- Attack cast after the ping (the "Attack" label replaces a text prefix).
    y = y - 30
    local attackLabel = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    attackLabel:SetPoint("TOPLEFT", PAD + 2, y - 8)
    attackLabel:SetText(L.ATTACK)
    themedLabels[#themedLabels + 1] = attackLabel

    attackDD = CreateFrame("DropdownButton", nil, optionsPanel, "WowStyle1DropdownTemplate")
    attackDD:SetWidth(180)
    attackDD:SetPoint("TOPRIGHT", -PAD, y - 2)
    attackDD:SetupMenu(BuildAttackMenu)
    if attackDD.SetSelectionTranslator then
        attackDD:SetSelectionTranslator(function(selection)
            local choice = ns.GetAttackChoice()
            if choice == nil then return L.ATTACK_NONE end
            if type(choice) == "string" then return choice end
            return selection.text
        end)
    end
    SetTooltip(attackDD, L.ATTACK, L.ATTACK_TOOLTIP_BODY)

    optionsPanel:SetHeight(-(y - 2) + 28 + PAD)
    optionsPanel:Hide()
end

function UI.Create()
    if main then return end
    theme = ns.Themes.Resolve(ns.db.appearance.theme, ClassColor())
    CreateMain()
    CreateOptions()
    ApplyLayout(false)
    -- Background straight away, even if ApplyAppearance is queued behind
    -- combat (a /reload mid-fight).
    StylePanel(main, ns.db.appearance.opacity)
    StylePanel(optionsPanel, ns.db.appearance.opacity)
end

---------------------------------------------------------------------------
-- State -> widgets
---------------------------------------------------------------------------
-- Out of combat only (Core calls it through ns.RunOutOfCombat): it rescales,
-- resizes and re-skins the secure button's parent.
function UI.ApplyAppearance()
    local a = ns.db.appearance
    theme = ns.Themes.Resolve(a.theme, ClassColor())

    StylePanel(main, a.opacity)
    StylePanel(optionsPanel, a.opacity)
    title:SetTextColor(theme.title[1], theme.title[2], theme.title[3])
    SkinButton(useTargetBtn)
    SkinButton(optionsToggle)
    SkinButton(pingBtn, true)
    ColorText()

    main:SetScale(a.scale)
    ApplyLayout(a.compact)
end

function UI.UpdateOptionsShown()
    optionsPanel:SetShown(ns.db.optionsExpanded)
    optionsToggle:SetText(ns.db.optionsExpanded and L.OPTIONS_EXPANDED or L.OPTIONS_COLLAPSED)
end

-- Re-reads checkboxes and dropdowns from saved settings (after any change,
-- including ones made on the game's Settings page).
function UI.RefreshValues()
    if not main then return end
    for key, cb in pairs(checkboxes) do
        cb.button:SetChecked(ns.db.options[key] and true or false)
    end
    pingTypeDD:GenerateMenu()
    attackDD:GenerateMenu()
    markerDD:GenerateMenu()
end

-- Pushes saved settings into every widget (load, reset).
function UI.Refresh()
    nameBox:SetText(ns.db.name or "")
    nameBox:SetCursorPosition(0)
    UI.RefreshValues()
    UI.UpdateOptionsShown()
end

-- Re-reads the attack choice into the dropdown text (after the custom popup).
function UI.RefreshAttack()
    if attackDD then attackDD:GenerateMenu() end
end

function UI.ApplyShown()
    main:SetShown(ns.db.shown)
end

-- Out of combat only (called through ns.RunOutOfCombat): wrapping a secure
-- button and setting the handler's attribute are both blocked in combat.
function UI.ApplyCooldown(seconds)
    if not cooldownHandler then
        cooldownHandler = CreateFrame("Frame", nil, nil, "SecureHandlerBaseTemplate")
        -- Not sure GetTime is exposed to secure snippets on this client; ask.
        cooldownHandler:Execute([[ self:SetAttribute("hasGetTime", GetTime ~= nil) ]])
        secureCooldown = cooldownHandler:GetAttribute("hasGetTime") and true or false
        SecureHandlerWrapScript(pingBtn, "OnClick", cooldownHandler, COOLDOWN_SNIPPET)
    end
    cooldownHandler:SetAttribute("cooldown", seconds)
end

-- For /fp debug: "off", "secure" (works in combat) or "fallback" (out of
-- combat only), or nil before ApplyCooldown has run.
function UI.CooldownMode()
    if not cooldownHandler then return nil end
    if (ns.db.pingCooldown or 0) <= 0 then return "off" end
    return secureCooldown and "secure" or "fallback"
end

-- Out of combat only (called through ns.RunOutOfCombat).
function UI.ApplyMacro(text)
    pingBtn:SetAttribute("macrotext", text)
    pingBtn:SetEnabled(text ~= "")
end

function UI.UpdateStatus()
    if not statusText then return end
    local text = ns.macrotext or ""
    if locked then
        statusText:SetText(L.LOCKED_IN_COMBAT)
        statusText:SetTextColor(1, 0.3, 0.3)
    elseif ns.Macro.IsTooLong(text) then
        statusText:SetText(L.TOO_LONG:format(#text, ns.Macro.MAX_LENGTH))
        statusText:SetTextColor(1, 0.6, 0)
    else
        statusText:SetText("")
    end
end

function UI.SetCombatLocked(isLocked)
    if not main then return end
    locked = isLocked
    local enabled = not isLocked
    if isLocked then nameBox:ClearFocus() end
    nameBox:SetEnabled(enabled)
    useTargetBtn:SetEnabled(enabled)
    questBtn:SetEnabled(enabled)
    questBtn:SetAlpha(enabled and 1 or 0.4)
    pingTypeDD:SetEnabled(enabled)
    attackDD:SetEnabled(enabled)
    if isLocked then StaticPopup_Hide("FOREVERPINGING_CUSTOM_ATTACK") end
    markerDD:SetEnabled(enabled)
    for _, cb in pairs(checkboxes) do
        cb.button:SetEnabled(enabled)
    end
    ColorText()
    UI.UpdateStatus()
end
