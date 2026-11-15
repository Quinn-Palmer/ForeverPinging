-- Themes.lua: window look definitions. Pure data + a resolver, no WoW API
-- calls, so it can be loaded and tested outside the client.
--
-- A resolved theme has:
--   backdrop      BackdropTemplate table for the window and options panel
--   bg, border    {r, g, b, a}; bg alpha is multiplied by the opacity setting
--   title         {r, g, b} window title
--   text          {r, g, b} labels (checkboxes, "Raid marker", "Attack")
--   textDisabled  {r, g, b} labels while locked in combat
--   input         {r, g, b} name box text
--   flatButtons   true = replace the Blizzard red button art with flat boxes
--   button        { bg, border, hover, text } flat button colours (flatButtons only)
--   accent        {r, g, b, a} border of the Ping! button (flatButtons only)

local _, ns = ...
ns = ns or {}

local Themes = {}
ns.Themes = Themes

local WHITE = "Interface\\Buttons\\WHITE8X8"

Themes.DEFAULT = "tooltip"

-- Dropdown order. Labels live in the locale as THEME_<key>.
Themes.LIST = { "tooltip", "blizzard", "dark", "classcolor", "parchment" }

-- Used by "classcolor" when the player's class colour isn't available.
Themes.FALLBACK_CLASS_COLOR = { 0.6, 0.6, 0.6 }

local FLAT_BACKDROP = {
    bgFile = WHITE, edgeFile = WHITE, tile = false, edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

local DEFS = {
    -- The original look: tooltip background and border.
    tooltip = {
        backdrop = {
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        },
        bg = { 0, 0, 0, 0.85 },
        border = { 0.6, 0.6, 0.6, 1 },
        title = { 1, 0.82, 0 },
        text = { 1, 1, 1 },
        textDisabled = { 0.5, 0.5, 0.5 },
        input = { 1, 1, 1 },
        flatButtons = false,
    },

    -- Default game dialog: dark marble with the gold-trimmed border.
    blizzard = {
        backdrop = {
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 24,
            insets = { left = 6, right = 6, top = 6, bottom = 6 },
        },
        bg = { 1, 1, 1, 1 },
        border = { 1, 1, 1, 1 },
        title = { 1, 0.82, 0 },
        text = { 1, 1, 1 },
        textDisabled = { 0.5, 0.5, 0.5 },
        input = { 1, 1, 1 },
        flatButtons = false,
    },

    -- Flat dark panel, 1px border, flat buttons.
    dark = {
        backdrop = FLAT_BACKDROP,
        bg = { 0.06, 0.06, 0.07, 0.92 },
        border = { 0.22, 0.22, 0.25, 1 },
        title = { 0.92, 0.92, 0.92 },
        text = { 0.85, 0.85, 0.85 },
        textDisabled = { 0.45, 0.45, 0.45 },
        input = { 1, 1, 1 },
        flatButtons = true,
        button = {
            bg = { 0.13, 0.13, 0.15, 1 },
            border = { 0.28, 0.28, 0.32, 1 },
            hover = { 1, 1, 1, 0.08 },
        },
        accent = { 0.2, 0.65, 1, 1 },
    },

    -- Dark Minimal with class-coloured border, title and Ping! accent.
    -- Fields set to "class" are filled in by Themes.Resolve.
    classcolor = {
        base = "dark",
        border = "class",
        title = "class",
        accent = "class",
    },

    -- Quest-log paper with dark brown text.
    parchment = {
        backdrop = {
            bgFile = "Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = false, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        },
        bg = { 1, 1, 1, 1 },
        border = { 0.55, 0.4, 0.22, 1 },
        title = { 0.3, 0.16, 0.04 },
        text = { 0.22, 0.13, 0.05 },
        textDisabled = { 0.5, 0.42, 0.33 },
        input = { 0.2, 0.12, 0.04 },
        flatButtons = false,
    },
}

local function Copy(v)
    if type(v) ~= "table" then return v end
    local out = {}
    for k, x in pairs(v) do out[k] = Copy(x) end
    return out
end

function Themes.IsValid(key)
    return type(key) == "string" and DEFS[key] ~= nil
end

-- Returns a fresh table (safe to modify) for the theme key. Unknown keys
-- fall back to the default theme. classColor = {r, g, b} or nil.
function Themes.Resolve(key, classColor)
    if not Themes.IsValid(key) then key = Themes.DEFAULT end
    local def = DEFS[key]

    local theme = def.base and Copy(DEFS[def.base]) or {}
    for k, v in pairs(def) do
        if k ~= "base" then theme[k] = Copy(v) end
    end

    local cc = classColor or Themes.FALLBACK_CLASS_COLOR
    for k, v in pairs(theme) do
        if v == "class" then
            theme[k] = { cc[1], cc[2], cc[3], 1 }
        end
    end
    theme.key = key
    return theme
end
