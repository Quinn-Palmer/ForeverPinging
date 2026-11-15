-- Unit tests for QuestMobs.lua. Run with: python tests/run_tests.py
-- `QuestMobs` is injected by the runner.

local cases = {}
local function test(name, fn) cases[#cases + 1] = { name = name, fn = fn } end

local function eq(actual, expected)
    if actual ~= expected then
        error(("\nexpected: %s\nactual:   %s"):format(tostring(expected), tostring(actual)), 2)
    end
end

local P = QuestMobs.ParseMobName

test("classic style 'X slain: n/m'", function()
    eq(P("Kobold Vermin slain: 3/8"), "Kobold Vermin")
    eq(P("Defias Thug slain: 0/12"), "Defias Thug")
end)

test("modern style 'n/m X slain'", function()
    eq(P("3/8 Kobold Vermin slain"), "Kobold Vermin")
end)

test("no 'slain' word", function()
    eq(P("Young Wolf: 2/10"), "Young Wolf")
    eq(P("Hogger killed: 0/1"), "Hogger")
end)

test("plain text with no count is kept", function()
    eq(P("Hogger"), "Hogger")
end)

test("junk gives nil", function()
    eq(P(""), nil)
    eq(P("  3/8  "), nil)
    eq(P(nil), nil)
    eq(P(42), nil)
end)

local function obj(text, over)
    local o = { text = text, type = "monster", finished = false, numFulfilled = 0, numRequired = 8 }
    for k, v in pairs(over or {}) do o[k] = v end
    return o
end

test("only unfinished monster objectives are listed", function()
    local mobs = QuestMobs.Collect({
        { title = "Kobold Camp", onMap = true, objectives = {
            obj("Kobold Vermin slain: 3/8"),
            obj("Kobold Worker slain: 8/8", { finished = true }),
            obj("Gold Dust: 0/5", { type = "item" }),
        } },
    }, false)
    eq(#mobs, 1)
    eq(mobs[1].name, "Kobold Vermin")
    eq(mobs[1].quests[1], "Kobold Camp")
end)

test("current zone only hides other-zone quests and counts them", function()
    local quests = {
        { title = "Here", onMap = true, objectives = { obj("Young Wolf slain: 0/10") } },
        { title = "Far", onMap = false, objectives = { obj("Murloc slain: 0/5"), obj("Gnoll slain: 0/5") } },
    }
    local mobs, hidden = QuestMobs.Collect(quests, false)
    eq(#mobs, 1)
    eq(mobs[1].name, "Young Wolf")
    eq(hidden, 2)

    mobs, hidden = QuestMobs.Collect(quests, true)
    eq(#mobs, 3)
    eq(hidden, 0)
end)

test("same mob in two quests is listed once", function()
    local mobs = QuestMobs.Collect({
        { title = "A", onMap = true, objectives = { obj("Defias Thug slain: 1/12") } },
        { title = "B", onMap = true, objectives = { obj("Defias Thug slain: 0/5") } },
    }, false)
    eq(#mobs, 1)
    eq(#mobs[1].quests, 2)
    eq(mobs[1].quests[2], "B")
end)

test("hidden count skips names already shown", function()
    local _, hidden = QuestMobs.Collect({
        { title = "Here", onMap = true, objectives = { obj("Defias Thug slain: 0/5") } },
        { title = "Far", onMap = false, objectives = { obj("Defias Thug slain: 0/5") } },
    }, false)
    eq(hidden, 0)
end)

test("empty input", function()
    local mobs, hidden = QuestMobs.Collect(nil, false)
    eq(#mobs, 0)
    eq(hidden, 0)
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
