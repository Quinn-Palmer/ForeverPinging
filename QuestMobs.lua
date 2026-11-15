-- QuestMobs.lua: pure helpers that turn quest objectives into mob names.
-- No WoW API calls here; Core.lua reads the quest log and passes plain tables in.

local _, ns = ...

local QuestMobs = {}
ns.QuestMobs = QuestMobs

local function Trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- "Kobold Vermin slain: 3/8"  (classic style)
-- "3/8 Kobold Vermin slain"   (modern style)
-- Returns the mob name, or nil if nothing usable is left.
function QuestMobs.ParseMobName(text)
    if type(text) ~= "string" then return nil end
    local t = Trim(text:gsub("[\r\n]+", " "))
    t = t:gsub("%s*:?%s*%d+%s*/%s*%d+%s*$", "")   -- trailing count
    t = t:gsub("^%d+%s*/%s*%d+%s*", "")           -- leading count
    t = Trim(t)
    t = t:gsub("%s+[Ss]lain$", ""):gsub("%s+[Kk]illed$", "")
    t = Trim((t:gsub(":$", "")))
    if t == "" then return nil end
    return t
end

-- quests: list of { title = string, onMap = bool, objectives = { {text, type, finished, numFulfilled, numRequired}, ... } }
-- allZones: include quests that aren't on the current map.
-- Returns:
--   mobs   list of { name, numFulfilled, numRequired, quests = {title, ...} }, in quest log order,
--          one entry per mob name (same mob in two quests is merged)
--   hidden number of extra mobs left out because their quest isn't in this zone
function QuestMobs.Collect(quests, allZones)
    local mobs, byName = {}, {}
    local hiddenNames = {}
    for _, q in ipairs(quests or {}) do
        for _, obj in ipairs(q.objectives or {}) do
            if obj.type == "monster" and not obj.finished then
                local name = QuestMobs.ParseMobName(obj.text)
                if name then
                    if allZones or q.onMap then
                        local mob = byName[name]
                        if not mob then
                            mob = { name = name, numFulfilled = obj.numFulfilled,
                                    numRequired = obj.numRequired, quests = {} }
                            byName[name] = mob
                            mobs[#mobs + 1] = mob
                        end
                        mob.quests[#mob.quests + 1] = q.title
                    else
                        hiddenNames[name] = true
                    end
                end
            end
        end
    end
    local hidden = 0
    for name in pairs(hiddenNames) do
        if not byName[name] then hidden = hidden + 1 end
    end
    return mobs, hidden
end
