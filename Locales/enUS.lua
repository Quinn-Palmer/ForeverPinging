local _, ns = ...

-- Missing keys fall back to the key itself so a typo shows up on screen
-- instead of erroring.
local L = setmetatable({}, { __index = function(_, key) return key end })
ns.L = L

L.TITLE = "Forever Pinging"
L.NAME = "Name"
L.USE_TARGET = "Use Target"
L.USE_TARGET_TOOLTIP = "Use Current Target"
L.USE_TARGET_TOOLTIP_BODY = "Fill the name box with your current target's name."
L.QUEST_MOBS = "Quest mobs"
L.QUEST_MOBS_TOOLTIP_BODY = "Pick a mob from your unfinished kill objectives to fill the name box."
L.QUEST_ALL_ZONES = "Show all zones"
L.QUEST_NONE_HERE = "No kill objectives in this zone"
L.QUEST_NONE = "No unfinished kill objectives"
L.QUEST_MORE_ELSEWHERE = "+%d in other zones"
L.QUEST_API_MISSING = "Quest log API not available"
L.PING = "Ping!"
L.PING_TOOLTIP_BODY = "Targets the name, pings it (unless the ping type is No ping), then casts your chosen attack (if any)."
L.OPTIONS_COLLAPSED = "Options +"
L.OPTIONS_EXPANDED = "Options -"

-- Attack (cast after the ping)
L.ATTACK = "Attack"
L.ATTACK_TOOLTIP_BODY = "Optional spell to cast at the target right after the ping. Saved per class. Only instant abilities make sense here: a cast-time spell would start casting at the target."
L.ATTACK_NONE = "No attack"
L.ATTACK_SELECTED = "Attack: %s"
L.ATTACK_NOT_LEARNED = "Not learned yet"
L.ATTACK_CUSTOM = "Custom spell..."
L.ATTACK_CUSTOM_SET = "Custom: %s"
L.ATTACK_CUSTOM_PROMPT = "Spell to cast after the ping (exact spell name, as in your spellbook). Leave empty for none."

-- Ping types
L.PING_default = "Default"
L.PING_attack = "Attack"
L.PING_assist = "Assist"
L.PING_warning = "Warning"
L.PING_onmyway = "On My Way"
L.PING_none = "No ping (target only)"

-- Options
L.OPT_exactMatch = "Exact name match"
L.OPT_skipDead = "Skip dead"
L.OPT_enemiesOnly = "Enemies only"
L.OPT_friendliesOnly = "Friendlies only"
L.OPT_clearIfNotFound = "Clear target if not found"
L.OPT_clearIfNotFound_TIP = "Clears your target before searching, so a failed search leaves no target and nothing is pinged. Still being verified in-game."
L.OPT_returnToPrevious = "Return to previous target"
L.RAID_MARKER = "Raid marker"

-- Raid markers (index = /tm number)
L.MARKER_0 = "None"
L.MARKER_1 = "Star"
L.MARKER_2 = "Circle"
L.MARKER_3 = "Diamond"
L.MARKER_4 = "Triangle"
L.MARKER_5 = "Moon"
L.MARKER_6 = "Square"
L.MARKER_7 = "Cross"
L.MARKER_8 = "Skull"

-- Status / chat
L.LOCKED_IN_COMBAT = "Locked in combat"
L.TOO_LONG = "Macro is %d chars (max %d)"
L.TOO_LONG_CHAT = "Warning: the macro is %d characters, over the %d limit. Turn off some options or shorten the name."
L.QUEUED = "In combat: change saved, will apply when combat ends."
L.QUEUE_APPLIED = "Combat ended: queued changes applied."
L.NO_TARGET = "You have no target."
L.TARGET_SECRET = "Your target's name isn't readable right now (restricted value)."
L.TARGET_COMBAT = "Can't change the name in combat."
L.RESET_DONE = "Position and settings reset."
L.DEBUG_HEADER = "Current macrotext (%d chars):"
L.DEBUG_EMPTY = "Macro is empty (no name set)."
L.HELP = "Commands: /fp (toggle window), /fp macro (action bar macro), /fp reset (reset position and settings), /fp debug (print current macro)"

-- Keybinding / action bar macro
L.BINDING_PING = "Ping! (target and ping)"
L.MACRO_READY = "Macro \"%s\" is on your cursor. Drop it on an action bar and keybind that slot. You can also bind Ping! directly under Keybindings > AddOns."
L.MACRO_COMBAT = "Can't create macros in combat. Try again after combat."
L.MACRO_FULL = "Your macro slots are full. Free one up, or bind Ping! under Keybindings > AddOns instead."
L.MACRO_FAILED = "Couldn't create the macro."
