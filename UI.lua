-- UI.lua: main window, options panel, secure Ping! button.
--
-- Combat rules this file follows:
--   * The Ping! button's attributes are only set via ns.RunOutOfCombat.
--   * The main frame is the secure button's parent, so it is never shown,
--     hidden or moved in combat (Core queues those).
--   * Inputs are disabled while in combat; Ping! keeps working.

local _, ns = ...
local L = ns.L

local UI = {}
ns.UI = UI

local WIDTH = 270
local MAIN_HEIGHT = 112
local PAD = 10
local ROW_H = 22

local BACKDROP = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

local main, nameBox, useTargetBtn, pingTypeDD, pingBtn, optionsToggle, statusText
local optionsPanel, markerDD
local checkboxes = {}   -- key -> { button, label }
local locked = false

local OPTION_KEYS = {
    "exactMatch", "skipDead", "enemiesOnly", "friendliesOnly",
    "clearIfNotFound", "returnToPrevious",
}

local function SetTooltip(frame, title, body)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title)
        if body then
            GameTooltip:AddLine(body, 1, 1, 1, true)
        end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", GameTooltip_Hide)
end

local function CreatePanel(name, parent)
    local f = CreateFrame("Frame", name, parent, "BackdropTemplate")
    f:SetBackdrop(BACKDROP)
    f:SetBackdropColor(0, 0, 0, 0.85)
    f:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    return f
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
    main = CreatePanel("ForeverPingingFrame", UIParent)
    main:SetSize(WIDTH, MAIN_HEIGHT)
    main:SetFrameStrata("MEDIUM")
    main:SetClampedToScreen(true)
    main:SetMovable(true)
    main:EnableMouse(true)
    main:RegisterForDrag("LeftButton")
    if main.SetDontSavePosition then main:SetDontSavePosition(true) end
    main:SetScript("OnDragStart", function(self)
        if InCombatLockdown() then return end
        self:StartMoving()
    end)
    main:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition()
    end)
    main:Hide()

    local title = main:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOPLEFT", PAD, -PAD)
    title:SetText(L.TITLE)

    local close = CreateFrame("Button", nil, main, "UIPanelCloseButton")
    close:SetSize(24, 24)
    close:SetPoint("TOPRIGHT", -2, -2)
    close:SetScript("OnClick", function() ns.SetShown(false) end)

    -- Row 1: name box + Use Target
    nameBox = CreateFrame("EditBox", nil, main, "InputBoxTemplate")
    nameBox:SetSize(WIDTH - PAD * 2 - 100 - 6, ROW_H)
    nameBox:SetPoint("TOPLEFT", PAD + 6, -32)   -- InputBoxTemplate's left art sits outside the box
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
    useTargetBtn:SetPoint("TOPRIGHT", -PAD, -32)
    useTargetBtn:SetText(L.USE_TARGET)
    useTargetBtn:SetScript("OnClick", function()
        local name, reason = ns.GetTargetName()
        if not name then
            ns.Print(reason)
            return
        end
        ns.db.name = name
        nameBox:SetText(name)
        nameBox:ClearFocus()
        ns.OnSettingsChanged()
    end)
    SetTooltip(useTargetBtn, L.USE_TARGET_TOOLTIP, L.USE_TARGET_TOOLTIP_BODY)

    -- Row 2: ping type + Ping!
    pingTypeDD = CreateFrame("DropdownButton", nil, main, "WowStyle1DropdownTemplate")
    pingTypeDD:SetWidth(WIDTH - PAD * 2 - 100 - 6)
    pingTypeDD:SetPoint("TOPLEFT", PAD, -60)
    pingTypeDD:SetupMenu(function(_, root)
        for _, pt in ipairs(ns.Macro.PING_TYPES) do
            root:CreateRadio(L["PING_" .. pt.key],
                function() return ns.db.pingType == pt.key end,
                function()
                    ns.db.pingType = pt.key
                    ns.OnSettingsChanged()
                end)
        end
    end)

    -- The secure button. Its click runs the macrotext; addon code never
    -- targets or pings directly.
    pingBtn = CreateFrame("Button", "ForeverPingingPingButton", main,
        "SecureActionButtonTemplate, UIPanelButtonTemplate")
    pingBtn:SetSize(100, ROW_H + 2)
    pingBtn:SetPoint("TOPRIGHT", -PAD, -59)
    pingBtn:SetText(L.PING)
    -- Both edges, so the click fires whichever way ActionButtonUseKeyDown is set.
    pingBtn:RegisterForClicks("AnyUp", "AnyDown")
    pingBtn:SetAttribute("type", "macro")
    pingBtn:SetAttribute("macrotext", "")
    pingBtn:Disable()
    SetTooltip(pingBtn, L.PING, L.PING_TOOLTIP_BODY)

    -- Row 3: options toggle + status
    optionsToggle = CreateFrame("Button", nil, main, "UIPanelButtonTemplate")
    optionsToggle:SetSize(90, 20)
    optionsToggle:SetPoint("BOTTOMLEFT", PAD, PAD)
    optionsToggle:SetScript("OnClick", function()
        ns.db.optionsExpanded = not ns.db.optionsExpanded
        UI.UpdateOptionsShown()
    end)

    statusText = main:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    statusText:SetPoint("LEFT", optionsToggle, "RIGHT", 8, 0)
    statusText:SetPoint("RIGHT", main, "RIGHT", -PAD, 0)
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
    cb:SetScript("OnClick", function(self)
        local opts = ns.db.options
        opts[key] = self:GetChecked() and true or false
        if opts[key] then
            if key == "enemiesOnly" then
                opts.friendliesOnly = false
                checkboxes.friendliesOnly.button:SetChecked(false)
            elseif key == "friendliesOnly" then
                opts.enemiesOnly = false
                checkboxes.enemiesOnly.button:SetChecked(false)
            end
        end
        ns.OnSettingsChanged()
    end)
    local tip = rawget(L, "OPT_" .. key .. "_TIP")
    if tip then SetTooltip(cb, L["OPT_" .. key], tip) end
    checkboxes[key] = { button = cb, label = label }
end

local function CreateOptions()
    optionsPanel = CreatePanel("ForeverPingingOptions", main)
    optionsPanel:SetPoint("TOPLEFT", main, "BOTTOMLEFT", 0, 2)
    optionsPanel:SetPoint("TOPRIGHT", main, "BOTTOMRIGHT", 0, 2)

    local y = -PAD + 2
    for _, key in ipairs(OPTION_KEYS) do
        CreateCheckbox(optionsPanel, key, y)
        y = y - 24
    end

    local markerLabel = optionsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    markerLabel:SetPoint("TOPLEFT", PAD + 2, y - 8)
    markerLabel:SetText(L.RAID_MARKER)

    markerDD = CreateFrame("DropdownButton", nil, optionsPanel, "WowStyle1DropdownTemplate")
    markerDD:SetWidth(130)
    markerDD:SetPoint("TOPRIGHT", -PAD, y - 2)
    markerDD:SetupMenu(function(_, root)
        for i = 0, ns.Macro.MARKER_COUNT do
            root:CreateRadio(L["MARKER_" .. i],
                function() return ns.db.options.raidMarker == i end,
                function()
                    ns.db.options.raidMarker = i
                    ns.OnSettingsChanged()
                end)
        end
    end)

    optionsPanel:SetHeight(-(y - 2) + 28 + PAD)
    optionsPanel:Hide()
end

function UI.Create()
    if main then return end
    CreateMain()
    CreateOptions()
end

---------------------------------------------------------------------------
-- State -> widgets
---------------------------------------------------------------------------
function UI.UpdateOptionsShown()
    optionsPanel:SetShown(ns.db.optionsExpanded)
    optionsToggle:SetText(ns.db.optionsExpanded and L.OPTIONS_EXPANDED or L.OPTIONS_COLLAPSED)
end

-- Pushes saved settings into every widget (load, reset).
function UI.Refresh()
    nameBox:SetText(ns.db.name or "")
    nameBox:SetCursorPosition(0)
    for key, cb in pairs(checkboxes) do
        cb.button:SetChecked(ns.db.options[key] and true or false)
    end
    pingTypeDD:GenerateMenu()
    markerDD:GenerateMenu()
    UI.UpdateOptionsShown()
end

function UI.ApplyShown()
    main:SetShown(ns.db.shown)
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
    nameBox:SetTextColor(enabled and 1 or 0.5, enabled and 1 or 0.5, enabled and 1 or 0.5)
    useTargetBtn:SetEnabled(enabled)
    pingTypeDD:SetEnabled(enabled)
    markerDD:SetEnabled(enabled)
    for _, cb in pairs(checkboxes) do
        cb.button:SetEnabled(enabled)
        cb.label:SetFontObject(enabled and "GameFontHighlightSmall" or "GameFontDisableSmall")
    end
    UI.UpdateStatus()
end
