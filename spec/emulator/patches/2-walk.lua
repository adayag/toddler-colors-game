-- KOReader userpatch (late priority, frontend/userpatch.lua:13) copied into a scratch profile by
-- spec/emulator/driver.lua. Plays through the game by sending gestures to UIManager, the way the input loop does,
-- wrapping TextWidget:paintTo (frontend/ui/widget/textwidget.lua:338), UIManager:_refresh
-- (frontend/ui/uimanager.lua:1200) and UIManager:scheduleIn (:413) to see what each screen drew and queued, and
-- counting the file manager's Screenshoter gestures to catch a leak. Writes what it saw, and any error in
-- results.error, to results.json, shoots one PNG per screen, then quits.
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

local function all_true(list)
    for _, value in ipairs(list) do
        if not value then
            return false
        end
    end
    return #list == 7
end

-- What the plugin drew since the last clear_drawn; nil leaves the spy inert.
local drawn

local function clear_drawn()
    drawn = { text = {}, shapes = {}, refreshes = {} }
end

local function note(kind, value)
    if drawn then
        table.insert(drawn[kind], value)
    end
end

local function shape_key(color, shape)
    return tostring(color) .. " " .. shape
end

local function spy_on_drawing()
    local TextWidget = require("ui/widget/textwidget")
    local Shapes = require("shapes")
    local paint_text, render = TextWidget.paintTo, Shapes.render
    local refresh, schedule_in = UIManager._refresh, UIManager.scheduleIn
    TextWidget.paintTo = function(widget, bb, x, y)
        note("text", widget.text)
        if drawn then
            drawn.left = math.min(drawn.left or x, x)
            drawn.right = math.max(drawn.right or 0, x + widget:getWidth())
        end
        return paint_text(widget, bb, x, y)
    end
    Shapes.render = function(shape, color, size)
        note("shapes", shape_key(color, shape))
        return render(shape, color, size)
    end
    UIManager._refresh = function(manager, mode, ...)
        note("refreshes", mode)
        return refresh(manager, mode, ...)
    end
    UIManager.scheduleIn = function(manager, ...)
        note("refreshes", "scheduled")
        return schedule_in(manager, ...)
    end
end

-- From the start screen: picks a mode, shoots the question, taps tile 2, shoots the answer, taps once more, and
-- leaves the game on a fresh question. Returns what each screen showed.
local function play(game, index, mode)
    local Game = require("game")
    local Shapes = require("shapes")
    local seen = {}
    clear_drawn()
    tap(game.buttons[index])
    shoot(mode .. "-question")
    seen.question_refreshes = table.concat(drawn.refreshes, ",")
    seen.question_words = table.concat(drawn.text)
    seen.question_expected = table.concat({ Game.question(game.round.target) })
    seen.tile_shapes = table.concat(drawn.shapes, ",")
    local tile_shapes = {}
    for _, tile in ipairs(game.round.tiles) do
        if tile.shape then
            table.insert(tile_shapes, shape_key(tile.color, tile.shape))
        end
    end
    seen.tile_shapes_expected = table.concat(tile_shapes, ",")
    seen.question_state = game.state
    seen.question_text = holds({ x = 0, y = 28, w = Screen:getWidth(), h = 80 }, "#000000")
    local tiles = {}
    for i, rect in ipairs(game.rects) do
        local tile = game.round.tiles[i]
        tiles[i] = holds(rect, tile.color and Shapes.hex(tile.color) or "#000000")
    end
    seen.tiles_painted = all_true(tiles)
    seen.previous_target = game.round.target.color or game.round.target.shape

    local tapped = game.round.tiles[2]
    clear_drawn()
    tap(game.rects[2])
    shoot(mode .. "-answer")
    seen.answer_refreshes = table.concat(drawn.refreshes, ",")
    seen.answer_words = table.concat(drawn.text, " ")
    seen.answer_expected = table.concat(Game.answer(tapped), " ")
    seen.answer_shape = table.concat(drawn.shapes, ",")
    seen.answer_shape_expected = tapped.shape and shape_key(tapped.color, tapped.shape) or ""
    seen.answer_state = game.state
    local whole = { x = 0, y = 0, w = Screen:getWidth(), h = Screen:getHeight() }
    seen.answer_painted = holds(whole, tapped.color and Shapes.hex(tapped.color) or "#000000")
    seen.answer_fills = mode == "colors" and pixel(10, 10) == Shapes.hex(tapped.color)
    if mode == "colors" then
        local ink = Shapes.is_dark(tapped.color) and "#FFFFFF" or "#000000"
        seen.answer_text = holds({ x = 0, y = 755, w = Screen:getWidth(), h = 170 }, ink)
    else
        seen.answer_text = holds({ x = 0, y = 1420, w = Screen:getWidth(), h = 150 }, "#000000")
    end

    clear_drawn()
    tap(whole)
    seen.next_refreshes = table.concat(drawn.refreshes, ",")
    drawn = nil
    seen.next_state = game.state
    seen.next_target = game.round.target.color or game.round.target.shape
    return seen
end

-- Paints a forced answer in a colour and reports which ink appears in the text band.
local function ink_on(game, color)
    game.tapped = { color = color }
    game:go("answer")
    UIManager:forceRePaint()
    local band = { x = 0, y = 755, w = Screen:getWidth(), h = 170 }
    return { white = holds(band, "#FFFFFF"), black = holds(band, "#000000") }
end

-- Holds a point from at to at + gap, in the same units as the gesture timestamps.
local function hold(x, y, at, gap)
    gesture("hold", x, y, at)
    gesture("hold_release", x, y, at + gap)
    UIManager:forceRePaint()
end

local LEAK_GESTURES = {
    "tap", "double_tap", "two_finger_tap", "touch", "swipe", "two_finger_swipe", "multiswipe", "pan", "pan_release",
    "two_finger_pan", "hold", "hold_pan", "hold_release", "two_finger_hold", "two_finger_hold_release", "pinch",
    "spread", "inward_pan", "outward_pan", "rotate",
}

local function stack_size()
    local count = 0
    for _ in UIManager:topdown_widgets_iter() do
        count = count + 1
    end
    return count
end

local function send_all(x, y)
    for _, ges in ipairs(LEAK_GESTURES) do
        gesture(ges, x, y, nil, {
            direction = "south", multiswipe_directions = "south", distance = 300, span = 300, angle = 90,
        })
    end
end

local screenshots = 0

-- Swaps the handlers the Screenshoter's gestures fire, which hold onScreenshot by value
-- (frontend/ui/widget/screenshoter.lua:139-140), for a counter, so no file or dialog appears.
local function spy_on_screenshot()
    local function count()
        screenshots = screenshots + 1
        return true
    end
    local module = require("apps/filemanager/filemanager").instance.screenshot
    module.onSwipeDiagonal, module.onTapDiagonal = count, count
end

local screenshot_stamp = 0

-- Sends a full-diagonal swipe and two-finger tap and returns how many reached the Screenshoter, stamped ahead of every
-- earlier send because any gesture of a type, however short, spends its one match a second
-- (frontend/ui/gesturerange.lua:42-52), which would hide a leak.
local function screenshot_gestures()
    local before = screenshots
    local diagonal = math.floor(math.sqrt(Screen:getWidth() ^ 2 + Screen:getHeight() ^ 2))
    screenshot_stamp = screenshot_stamp + time.s(2)
    local at = time.now() + screenshot_stamp
    -- Diagonal and below the menu zone, so the file chooser and the menu leave it alone
    -- (frontend/ui/widget/menu.lua:1535, frontend/apps/filemanager/filemanagermenu.lua:99-122). The tap lands off every
    -- button and tile, since the game counts a two-finger tap as a press.
    gesture("swipe", 10, 1670, at, {
        direction = "northeast", multiswipe_directions = "northeast", distance = diagonal,
    })
    gesture("two_finger_tap", 632, 590, at, { span = diagonal })
    return screenshots - before
end

-- Runs a step of the walk on the next tick, where nothing else would catch its error.
local function on_next_tick(step)
    UIManager:nextTick(function()
        local ok, err = xpcall(step, debug.traceback)
        if not ok then
            finish(tostring(err))
        end
    end)
end

-- Paints every question, over plain colour tiles so no SVGs render, and every answer, recording how far the text
-- reached.
local function measure_text(game)
    local Game = require("game")
    local plain, every = {}, {}
    for i, color in ipairs(Game.COLORS) do
        plain[i] = { color = color }
        table.insert(every, plain[i])
        for _, shape in ipairs(Game.SHAPES) do
            table.insert(every, { color = color, shape = shape })
        end
    end
    for _, shape in ipairs(Game.SHAPES) do
        table.insert(every, { shape = shape })
    end
    clear_drawn()
    for _, tile in ipairs(every) do
        game.round = { target = tile, tiles = plain }
        game:go("question")
        UIManager:forceRePaint()
        game.tapped = tile
        game:go("answer")
        UIManager:forceRePaint()
    end
    results.text_left, results.text_right = drawn.left, drawn.right
    drawn = nil
    game:go("start")
    UIManager:forceRePaint()
end

-- The walk from the lone release on, a tick later so that a close the release queued has happened.
local function after_lone_release(game, t1)
    results.exit.release_without_hold = UIManager:isWidgetShown(game) and game.state or "closed"
    gesture("hold", 50, 50, t1)
    gesture("hold_release", 400, 400, t1 + time.s(3))
    UIManager:forceRePaint()
    results.exit.drifted = game.state
    clear_drawn()
    hold(50, 50, t1, time.s(3))
    results.exit.on_start = game.state
    results.exit.on_start_refreshes = table.concat(drawn.refreshes, ",")
    drawn = nil

    local depth = stack_size()
    send_all(632, 20)
    send_all(10, 1670)
    results.leak.start_kept = stack_size() == depth and UIManager:getNthTopWidget(1) == game
    results.leak.screenshot_on_start = screenshot_gestures() > 0
    tap(game.buttons[1])
    send_all(632, 20)
    send_all(10, 1670)
    results.leak.game_kept = stack_size() == depth and UIManager:getNthTopWidget(1) == game
    results.leak.screenshot_on_question = screenshot_gestures() > 0
    hold(50, 50, time.now(), time.s(3))

    measure_text(game)

    clear_drawn()
    tap(game.buttons[4])
    results.exit_button = {
        closed = not UIManager:isWidgetShown(game),
        refreshes = table.concat(drawn.refreshes, ","),
    }
    drawn = nil

    UIManager:broadcastEvent(Event:new("SetRotationMode", Screen.DEVICE_ROTATED_CLOCKWISE))
    local landscape = open_game()
    UIManager:forceRePaint()
    results.rotation = { during = Screen:getRotationMode(), width = Screen:getWidth() }
    gesture("tap", landscape.buttons[4].x + 10, landscape.buttons[4].y + 10)
    UIManager:forceRePaint()
    results.rotation.after = Screen:getRotationMode()
    UIManager:broadcastEvent(Event:new("SetRotationMode", Screen.DEVICE_ROTATED_UPRIGHT))
    UIManager:forceRePaint()

    local Shapes = require("shapes")
    local render = Shapes.render
    clear_drawn()
    local painting = open_game()
    UIManager:forceRePaint()
    results.open_refreshes = table.concat(drawn.refreshes, ",")
    drawn = nil
    Shapes.render = function()
        error("walk: render failed")
    end
    tap(painting.buttons[2])
    Shapes.render = render
    on_next_tick(function()
        results.failure = { paint_closed = not UIManager:isWidgetShown(painting) }
        local Game = require("game")
        local round = Game.round
        local tapping = open_game()
        Game.round = function()
            error("walk: round failed")
        end
        tap(tapping.buttons[1])
        Game.round = round
        on_next_tick(function()
            local file_browser = require("apps/filemanager/filemanager").instance
            results.failure.gesture_closed = not UIManager:isWidgetShown(tapping)
            results.failure.file_browser_on_top = UIManager:getNthTopWidget(1) == file_browser
            local GameScreen = require("screen")
            local init = GameScreen.init
            GameScreen.init = function()
                error("walk: open failed")
            end
            results.failure.open_kept_file_browser = open_game() == file_browser
            GameScreen.init = init
            finish()
        end)
    end)
end

local function walk()
    spy_on_screenshot()
    local before = stack_size()
    gesture("tap", 632, 20)
    results.leak = { control_opened_menu = stack_size() > before }
    require("apps/filemanager/filemanager").instance.menu:onCloseFileManagerMenu()
    results.leak.screenshot_control = screenshot_gestures() == 2
    local size = Screen:getSize()
    local buttons = require("screen").start_rects(size.w, size.h)
    local entry = assert(tools_entry(), "no Toddler Colors Game entry in Tools")
    entry.callback()
    local game = UIManager:getNthTopWidget(1)
    results.menu = { state = game.state }
    tap(game.buttons[1])
    results.menu.played = game.state
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
    tap(game.buttons[1])
    local t0 = time.now()
    results.taps = {}
    gesture("tap", 632, 300)
    UIManager:forceRePaint()
    results.taps.gap = game.state
    gesture("tap", 100, 1500)
    UIManager:forceRePaint()
    results.taps.beside_seventh = game.state
    gesture("tap", 300, 60)
    UIManager:forceRePaint()
    results.taps.header = game.state
    gesture("hold", 300, 300, t0)
    gesture("hold_release", 300, 300, t0 + time.s(1))
    UIManager:forceRePaint()
    results.taps.slow_press = game.state
    gesture("hold", 300, 300, t0)
    gesture("hold_release", 300, 300, t0 + time.s(1))
    UIManager:forceRePaint()
    results.taps.slow_press_on_answer = game.state
    gesture("two_finger_tap", 300, 300)
    UIManager:forceRePaint()
    results.taps.two_finger_tap = game.state
    gesture("two_finger_hold_release", 300, 300)
    UIManager:forceRePaint()
    results.taps.two_finger_hold_release = game.state
    hold(50, 50, time.now(), time.s(3))
    spy_on_drawing()
    results.colors = play(game, 1, "colors")
    results.ink = {}
    for _, color in ipairs(require("game").COLORS) do
        results.ink[color] = ink_on(game, color)
    end
    hold(50, 50, time.now(), time.s(3))
    results.shapes = play(game, 2, "shapes")
    hold(50, 50, time.now(), time.s(3))
    results.both = play(game, 3, "both")
    hold(50, 50, time.now(), time.s(3))

    results.exit = {}
    tap(game.buttons[1])
    local t1 = time.now()
    hold(50, 50, t1, time.s(2.9))
    results.exit.at_2_9 = game.state
    hold(50, 50, t1, time.s(3))
    results.exit.at_3_0 = game.state
    tap(game.buttons[1])
    hold(700, 50, t1, time.s(3))
    results.exit.outside_corner = game.state
    hold(50, game.rects[3].y - 1, t1, time.s(3))
    results.exit.below_corner = game.state
    hold(50, 50, t1, time.s(2.9))
    gesture("hold_release", 300, 300, t1 + time.s(3))
    UIManager:forceRePaint()
    on_next_tick(function()
        after_lone_release(game, t1)
    end)
end

on_next_tick(walk)
