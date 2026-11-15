-- Data checks for Abilities.lua. `Abilities` is injected by the runner.

local cases = {}
local function test(name, fn) cases[#cases + 1] = { name = name, fn = fn } end
local function check(cond, msg) if not cond then error(msg, 2) end end

local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }

test("every class has a list", function()
    for _, c in ipairs(CLASSES) do
        check(#Abilities.ForClass(c) > 0, c .. " has no abilities")
    end
end)

test("entries are well formed and unique per class", function()
    for class, list in pairs(Abilities.BY_CLASS) do
        local seenId, seenName = {}, {}
        for i, e in ipairs(list) do
            local where = ("%s[%d]"):format(class, i)
            check(type(e.id) == "number" and e.id > 0 and e.id % 1 == 0, where .. " bad id")
            check(type(e.name) == "string" and e.name ~= "", where .. " bad name")
            check(not e.name:find("[\r\n;]"), where .. " name has a macro-breaking character")
            check(e.note == nil or type(e.note) == "string", where .. " bad note")
            check(not seenId[e.id], where .. " duplicate id " .. e.id)
            check(not seenName[e.name], where .. " duplicate name " .. e.name)
            seenId[e.id], seenName[e.name] = true, true
        end
    end
end)

test("Find and unknown class", function()
    check(Abilities.Find("SHAMAN", 8050).name == "Flame Shock", "Flame Shock lookup")
    check(Abilities.Find("SHAMAN", 999999) == nil, "missing id")
    check(Abilities.Find("WARRIOR", 8050) == nil, "wrong class")
    check(#Abilities.ForClass("NOPE") == 0, "unknown class")
    check(#Abilities.ForClass(nil) == 0, "nil class")
end)

local failed = 0
for _, c in ipairs(cases) do
    local ok, err = pcall(c.fn)
    if ok then
        print("PASS  " .. c.name)
    else
        failed = failed + 1
        print("FAIL  " .. c.name .. ": " .. tostring(err))
    end
end
print(("%d passed, %d failed"):format(#cases - failed, failed))
return failed
