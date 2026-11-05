-- Runs one headless KOReader on a scratch KO_HOME with the plugin copied in and the walk userpatch applied, and
-- returns what the walk wrote to spec/.artifacts/. settings.reader.lua's color_rendering skips the first-run colour
-- notice (reader.lua:195-202). Leaving extra_plugin_paths out makes KOReader add <KO_HOME>/plugins/ itself
-- (frontend/pluginloader.lua:193-199).
local lfs = require("libs/libkoreader-lfs")

local M = {}

local TIMEOUT_S = 90

local function quote(s)
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function shell(command)
    assert(os.execute(command) == 0, "driver: failed: " .. command)
end

local function write_file(path, text)
    local file = assert(io.open(path, "w"))
    file:write(text)
    file:close()
end

local function read_file(path)
    local file = io.open(path, "r")
    if not file then
        return nil
    end
    local text = file:read("*a")
    file:close()
    return text
end

-- Returns the exit status of the emulator run without bin/check's LUA_PATH and LUA_CPATH, so it finds the plugin the
-- way a device does, and killed after TIMEOUT_S with SIGKILL behind SIGTERM, which a hang ignores
-- (base/ffi/SDL3.lua:719-723).
local function run_emulator(emulator, env, library, log)
    local script = table.concat({
        "cd " .. quote(emulator) .. " || exit 127",
        "env -u EMULATE_BB_TYPE -u LUA_PATH -u LUA_CPATH " .. env .. " ./luajit reader.lua " .. quote(library)
            .. " > " .. quote(log) .. " 2>&1 &",
        "pid=$!",
        "(sleep " .. TIMEOUT_S .. "; kill $pid 2>/dev/null; sleep 5; kill -9 $pid 2>/dev/null) >/dev/null 2>&1 &",
        "killer=$!",
        "wait $pid",
        "s=$?",
        "kill -STOP $killer 2>/dev/null; pkill -P $killer 2>/dev/null; kill -9 $killer 2>/dev/null",
        "echo",
        "echo $s",
    }, "\n")
    local pipe = assert(io.popen("sh -c " .. quote(script)))
    local output = pipe:read("*a")
    pipe:close()
    return tonumber(output:match("(%d+)\n$"))
end

function M.walk()
    local root = assert(os.getenv("TODDLER_COLORS_ROOT"), "driver: TODDLER_COLORS_ROOT unset")
    local emulator = assert(os.getenv("TODDLER_COLORS_EMULATOR"), "driver: TODDLER_COLORS_EMULATOR unset")
    local plugin = root .. "/toddler-colors-game.koplugin"
    if lfs.attributes(emulator .. "/plugins/toddler-colors-game.koplugin", "mode") then
        error("driver: the emulator's plugins/ holds the plugin; KOReader would load it twice")
    end

    local scratch = assert(os.getenv("KO_HOME")) .. "/walk"
    local artifacts = root .. "/spec/.artifacts"
    shell("rm -rf " .. quote(scratch) .. " " .. quote(artifacts))
    for _, dir in ipairs({ scratch, scratch .. "/settings", scratch .. "/patches", scratch .. "/plugins",
            scratch .. "/library", artifacts }) do
        shell("mkdir -p " .. quote(dir))
    end
    -- coverbrowser is off so its database prompt doesn't appear, and the emulator's third-party plugins are off so
    -- the file manager is stock.
    write_file(scratch .. "/settings.reader.lua",
        'return { ["color_rendering"] = true, ["plugins_disabled"] = { ["coverbrowser"] = true, '
            .. '["simpleui"] = true, ["bookshelf"] = true, ["solariconpack"] = true } }\n')
    shell("cp -R " .. quote(plugin) .. " " .. quote(scratch .. "/plugins/"))
    shell("cp " .. quote(root .. "/spec/emulator/patches/2-walk.lua") .. " " .. quote(scratch .. "/patches/"))

    local log = artifacts .. "/walk.log"
    local env = table.concat({
        "KO_HOME=" .. quote(scratch),
        "XDG_DOCUMENTS_DIR=" .. quote(scratch),
        "SDL_VIDEO_DRIVER=offscreen",
        "EMULATE_READER_W=1264",
        "EMULATE_READER_H=1680",
        "EMULATE_READER_DPI=300",
        "EMULATE_READER_FORCE_PORTRAIT=1",
        "TODDLER_WALK_DIR=" .. quote(artifacts),
    }, " ")
    local status = run_emulator(emulator, env, scratch .. "/library", log)
    local text = read_file(artifacts .. "/results.json")
    if not text then
        error("driver: no results.json, exit status " .. tostring(status) .. ", log at " .. log)
    end
    local results = require("rapidjson").decode(text)
    assert(results.error == nil, results.error)
    assert(status == 0, "driver: KOReader exited with status " .. tostring(status) .. ", log at " .. log)
    return results
end

return M
