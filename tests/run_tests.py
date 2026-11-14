"""Syntax-checks every addon Lua file and runs the Macro.lua unit tests.

Uses Lua 5.1 (same as WoW) via the `lupa` package:  pip install lupa
Run from the repo root:  python tests/run_tests.py
"""
import pathlib
import sys

from lupa import lua51

ROOT = pathlib.Path(__file__).resolve().parent.parent
TOC = ROOT / "ForeverPinging_Forever.toc"


def toc_lua_files():
    files = []
    for line in TOC.read_text(encoding="utf-8").splitlines():
        line = line.split("[", 1)[0].strip()
        if line and not line.startswith("#") and line.endswith(".lua"):
            files.append(ROOT / line.replace("\\", "/"))
    return files


def main():
    lua = lua51.LuaRuntime(unpack_returned_tuples=True)
    compile_chunk = lua.eval("function(src, name) local f, err = loadstring(src, name) return f ~= nil, err end")

    bad = 0
    files = toc_lua_files() + sorted((ROOT / "tests").glob("*.lua"))
    for path in files:
        ok, err = compile_chunk(path.read_text(encoding="utf-8"), "@" + path.name)
        print(("OK    " if ok else "ERROR ") + str(path.relative_to(ROOT)) + ("" if ok else f": {err}"))
        bad += 0 if ok else 1
    if bad:
        return 1

    # Load Macro.lua the way WoW does: chunk called with (addonName, ns).
    ns = lua.table()
    lua.execute("function __load(src, name, ...) return assert(loadstring(src, name))(...) end")
    lua.globals().__load((ROOT / "Macro.lua").read_text(encoding="utf-8"), "@Macro.lua", "ForeverPinging", ns)
    lua.globals().Macro = ns.Macro

    print()
    failed = lua.globals().__load((ROOT / "tests" / "macro_spec.lua").read_text(encoding="utf-8"), "@macro_spec.lua")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
