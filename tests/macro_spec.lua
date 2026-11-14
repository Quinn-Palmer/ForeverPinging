-- Unit tests for Macro.lua. Run with: python tests/run_tests.py
-- `Macro` is injected by the runner.

local cases = {}
local function test(name, fn) cases[#cases + 1] = { name = name, fn = fn } end

local function eq(actual, expected)
    if actual ~= expected then
        error(("\nexpected:\n%s\nactual:\n%s"):format(tostring(expected), tostring(actual)), 2)
    end
end

local function settings(over)
    local s = {
        name = "Night Watch Guard",
        pingType = "default",
        options = {
            exactMatch = true, skipDead = false, enemiesOnly = false,
            friendliesOnly = false, clearIfNotFound = false,
            returnToPrevious = false, raidMarker = 0,
        },
    }
    for k, v in pairs(over or {}) do
        if k == "options" then
            for ok, ov in pairs(v) do s.options[ok] = ov end
        else
            s[k] = v
        end
    end
    return s
end

test("base macro matches the spec", function()
    eq(Macro.Build(settings()), "/targetexact Night Watch Guard\n/ping [@target,exists]")
end)

test("defaults (exact + skip dead)", function()
    eq(Macro.Build(settings({ options = { skipDead = true } })),
        "/targetexact Night Watch Guard\n/cleartarget [dead]\n/ping [@target,exists]")
end)

test("exact match off uses /target", function()
    eq(Macro.Build(settings({ options = { exactMatch = false } })),
        "/target Night Watch Guard\n/ping [@target,exists]")
end)

test("empty or whitespace name gives empty macro", function()
    eq(Macro.Build(settings({ name = "" })), "")
    eq(Macro.Build(settings({ name = "   " })), "")
    eq(Macro.Build({}), "")
    eq(Macro.Build(nil), "")
end)

test("name is trimmed and line breaks can't inject lines", function()
    eq(Macro.Build(settings({ name = "  Hogger  " })), "/targetexact Hogger\n/ping [@target,exists]")
    eq(Macro.Build(settings({ name = "Hogger\n/dance" })), "/targetexact Hogger /dance\n/ping [@target,exists]")
end)

test("ping types use numeric aliases", function()
    local expected = { attack = "1", assist = "4", warning = "2", onmyway = "3" }
    for key, arg in pairs(expected) do
        eq(Macro.Build(settings({ pingType = key })),
            "/targetexact Night Watch Guard\n/ping [@target,exists] " .. arg)
    end
end)

test("unknown ping type falls back to contextual", function()
    eq(Macro.Build(settings({ pingType = "bogus" })),
        "/targetexact Night Watch Guard\n/ping [@target,exists]")
end)

test("enemies only / friendlies only", function()
    eq(Macro.Build(settings({ options = { enemiesOnly = true } })),
        "/targetexact Night Watch Guard\n/cleartarget [help]\n/ping [@target,exists]")
    eq(Macro.Build(settings({ options = { friendliesOnly = true } })),
        "/targetexact Night Watch Guard\n/cleartarget [harm]\n/ping [@target,exists]")
end)

test("enemies only wins if both are somehow set", function()
    eq(Macro.Build(settings({ options = { enemiesOnly = true, friendliesOnly = true } })),
        "/targetexact Night Watch Guard\n/cleartarget [help]\n/ping [@target,exists]")
end)

test("skip dead + enemies only share one /cleartarget line", function()
    eq(Macro.Build(settings({ options = { skipDead = true, enemiesOnly = true } })),
        "/targetexact Night Watch Guard\n/cleartarget [dead][help]\n/ping [@target,exists]")
end)

test("clear target if not found clears first", function()
    eq(Macro.Build(settings({ options = { clearIfNotFound = true } })),
        "/cleartarget\n/targetexact Night Watch Guard\n/ping [@target,exists]")
end)

test("return to previous target appended after ping", function()
    eq(Macro.Build(settings({ options = { returnToPrevious = true } })),
        "/targetexact Night Watch Guard\n/ping [@target,exists]\n/targetlasttarget")
end)

test("raid marker goes before the ping", function()
    eq(Macro.Build(settings({ options = { raidMarker = 8 } })),
        "/targetexact Night Watch Guard\n/tm [@target,exists] 8\n/ping [@target,exists]")
end)

test("invalid raid markers are ignored", function()
    for _, m in ipairs({ 0, -1, 9, 2.5, "x" }) do
        eq(Macro.Build(settings({ options = { raidMarker = m } })),
            "/targetexact Night Watch Guard\n/ping [@target,exists]")
    end
end)

test("everything on stays under 255 chars with a normal name", function()
    local text = Macro.Build(settings({
        pingType = "attack",
        options = { skipDead = true, enemiesOnly = true, clearIfNotFound = true,
            returnToPrevious = true, raidMarker = 8 },
    }))
    eq(text, "/cleartarget\n/targetexact Night Watch Guard\n/cleartarget [dead][help]\n"
        .. "/tm [@target,exists] 8\n/ping [@target,exists] 1\n/targetlasttarget")
    eq(Macro.IsTooLong(text), false)
end)

test("IsTooLong boundary", function()
    eq(Macro.IsTooLong(string.rep("a", 255)), false)
    eq(Macro.IsTooLong(string.rep("a", 256)), true)
end)

test("IsValidPingType", function()
    eq(Macro.IsValidPingType("default"), true)
    eq(Macro.IsValidPingType("attack"), true)
    eq(Macro.IsValidPingType("nope"), false)
    eq(Macro.IsValidPingType(nil), false)
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
