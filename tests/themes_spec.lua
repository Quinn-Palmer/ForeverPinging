-- Unit tests for Themes.lua. Run with: python tests/run_tests.py
-- `Themes` is injected by the runner.

local cases = {}
local function test(name, fn) cases[#cases + 1] = { name = name, fn = fn } end

local function check(cond, msg)
    if not cond then error(msg or "check failed", 2) end
end

local function isColor(c, minLen)
    if type(c) ~= "table" or #c < (minLen or 3) then return false end
    for i = 1, #c do
        if type(c[i]) ~= "number" or c[i] < 0 or c[i] > 1 then return false end
    end
    return true
end

test("default is in the list and valid", function()
    check(Themes.IsValid(Themes.DEFAULT), "default valid")
    local found = false
    for _, key in ipairs(Themes.LIST) do
        if key == Themes.DEFAULT then found = true end
    end
    check(found, "default listed")
end)

test("every listed theme resolves with all fields", function()
    for _, key in ipairs(Themes.LIST) do
        check(Themes.IsValid(key), key .. " valid")
        local t = Themes.Resolve(key, { 0.1, 0.2, 0.3 })
        check(t.key == key, key .. " key")
        check(type(t.backdrop) == "table" and t.backdrop.bgFile and t.backdrop.edgeFile, key .. " backdrop")
        check(type(t.backdrop.insets) == "table", key .. " insets")
        for _, f in ipairs({ "bg", "border" }) do
            check(isColor(t[f], 4), key .. " " .. f)
        end
        for _, f in ipairs({ "title", "text", "textDisabled", "input" }) do
            check(isColor(t[f]), key .. " " .. f)
        end
        check(type(t.flatButtons) == "boolean", key .. " flatButtons")
        if t.flatButtons then
            check(type(t.button) == "table", key .. " button")
            for _, f in ipairs({ "bg", "border", "hover" }) do
                check(isColor(t.button[f], 4), key .. " button." .. f)
            end
            check(isColor(t.accent, 4), key .. " accent")
        end
    end
end)

test("unknown or missing key falls back to default", function()
    check(Themes.Resolve("nope").key == Themes.DEFAULT, "unknown")
    check(Themes.Resolve(nil).key == Themes.DEFAULT, "nil")
    check(Themes.Resolve(42).key == Themes.DEFAULT, "number")
    check(not Themes.IsValid("nope"), "IsValid unknown")
    check(not Themes.IsValid(nil), "IsValid nil")
end)

test("class color fills border, title and accent", function()
    local t = Themes.Resolve("classcolor", { 0.96, 0.55, 0.73 })
    check(t.border[1] == 0.96 and t.border[2] == 0.55 and t.border[3] == 0.73 and t.border[4] == 1, "border")
    check(t.title[1] == 0.96, "title")
    check(t.accent[3] == 0.73, "accent")
    -- Inherits the rest from dark.
    local dark = Themes.Resolve("dark")
    check(t.flatButtons == true, "flat")
    check(t.bg[1] == dark.bg[1] and t.bg[4] == dark.bg[4], "bg from dark")
end)

test("class color without a colour uses the fallback", function()
    local t = Themes.Resolve("classcolor", nil)
    local fb = Themes.FALLBACK_CLASS_COLOR
    check(t.border[1] == fb[1] and t.border[2] == fb[2] and t.border[3] == fb[3], "fallback")
end)

test("resolved tables are copies", function()
    local a = Themes.Resolve("dark")
    a.bg[1] = 0.99
    a.backdrop.insets.left = 99
    local b = Themes.Resolve("dark")
    check(b.bg[1] ~= 0.99, "bg not shared")
    check(b.backdrop.insets.left ~= 99, "backdrop not shared")
    local c = Themes.Resolve("classcolor")
    check(c.backdrop.insets.left ~= 99, "base not mutated")
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
