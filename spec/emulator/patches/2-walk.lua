-- KOReader userpatch (late priority, frontend/userpatch.lua:13) copied into a scratch profile by
-- spec/emulator/driver.lua. Plays through the game by sending gestures to UIManager, the way the input loop does,
-- and writes what it saw to results.json plus one PNG per screen, then quits. Any error lands in results.error.
local dir = os.getenv("TODDLER_WALK_DIR")
if not dir then
    return
end

local Event = require("ui/event")
local Geom = require("ui/geometry")
local UIManager = require("ui/uimanager")
local Screen = require("device").screen
local time = require("ui/time")

local results = {}

local function finish(message)
    results.error = message
    local file = assert(io.open(dir .. "/results.json", "w"))
    file:write(require("rapidjson").encode(results))
    file:close()
    UIManager:quit()
end

local function first()
    return 1
end

local function open_game()
    require("pluginloader"):getPluginInstance("toddler-colors-game"):start(first)
    return UIManager:getNthTopWidget(1)
end

local function gesture(ges, x, y, at, extra)
    local fields = extra or {}
    fields.ges = ges
    fields.pos = Geom:new{ x = x, y = y, w = 0, h = 0 }
    fields.time = at or time.now()
    UIManager:sendEvent(Event:new("Gesture", fields))
end

-- luacheck: ignore tap
local function tap(rect)
    gesture("tap", rect.x + math.floor(rect.w / 2), rect.y + math.floor(rect.h / 2))
    UIManager:forceRePaint()
end

local function shoot(name)
    UIManager:forceRePaint()
    assert(Screen:shot(dir .. "/" .. name .. ".png"))
end

local function pixel(x, y)
    local c = Screen.bb:getPixel(x, y):getColorRGB32()
    return string.format("#%02X%02X%02X", c.r, c.g, c.b)
end

-- Whether a colour appears anywhere inside rect, stepping past the tile border.
local function holds(rect, hex)
    for y = rect.y + 8, rect.y + rect.h - 8, 8 do
        for x = rect.x + 8, rect.x + rect.w - 8, 8 do
            if pixel(x, y) == hex then
                return true
            end
        end
    end
    return false
end

-- The Tools entry a person actually taps, read from the sorted menu KOReader builds
-- (frontend/apps/filemanager/filemanagermenu.lua:862).
local function tools_entry()
    local menu = require("apps/filemanager/filemanager").instance.menu
    menu:setUpdateItemTable()
    for _, tab in ipairs(menu.tab_item_table) do
        if tab.id == "tools" then
            for _, item in ipairs(tab) do
                if item.id == "toddler_colors_game" then
                    return item
                end
            end
        end
    end
end

local function walk()
    local size = Screen:getSize()
    local buttons = require("screen").start_rects(size.w, size.h)
    local entry = assert(tools_entry(), "no Toddler Colors Game entry in Tools")
    entry.callback()
    local game = UIManager:getNthTopWidget(1)
    results.menu = { state = game.state }
    game:shutdown()
    Screen.bb:paintRect(0, 0, 10, 10, require("ffi/blitbuffer").COLOR_BLACK)
    game = open_game()
    shoot("start")
    results.start = {
        state = game.state,
        button = pixel(buttons[1].x + 2, buttons[1].y + 2),
        background = pixel(5, 5),
        exit_label = holds(buttons[4], "#000000"),
    }
    finish()
end

UIManager:nextTick(function()
    local ok, err = xpcall(walk, debug.traceback)
    if not ok then
        finish(tostring(err))
    end
end)
