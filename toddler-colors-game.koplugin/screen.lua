-- The game's one full-screen widget: start, question and answer states over KOReader. It overrides
-- InputContainer:onGesture (frontend/ui/widget/container/inputcontainer.lua:266) so every gesture stops here, and
-- paints with paintRectRGB32 (base/ffi/blitbuffer.lua:1827) because paintRect draws luminance only (:1704).
local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Font = require("ui/font")
local Geom = require("ui/geometry")
local InputContainer = require("ui/widget/container/inputcontainer")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local logger = require("logger")
local Screen = Device.screen

local MARGIN = 20
local GAP = 24
local HEADER_H = 132
local BUTTON_W = 1100
local BUTTON_H = 340
local BUTTON_GAP = 40
local EDGE = 60
local EXIT_W = 200
local EXIT_H = 88

local GameScreen = InputContainer:extend{
    name = "toddler_colors_game",
    covers_fullscreen = true,
}

function GameScreen.tile_rects(w, h)
    local tile_w = math.floor((w - 2 * MARGIN - GAP) / 2)
    local tile_h = math.floor((h - HEADER_H - MARGIN - 3 * GAP) / 4)
    local rects = {}
    for i = 1, 6 do
        local column, row = (i - 1) % 2, math.floor((i - 1) / 2)
        rects[i] = {
            x = MARGIN + column * (tile_w + GAP),
            y = HEADER_H + row * (tile_h + GAP),
            w = tile_w,
            h = tile_h,
        }
    end
    rects[7] = { x = math.floor((w - tile_w) / 2), y = HEADER_H + 3 * (tile_h + GAP), w = tile_w, h = tile_h }
    return rects
end

function GameScreen.start_rects(w, h)
    local x = math.floor((w - BUTTON_W) / 2)
    local stack_h = 3 * BUTTON_H + 2 * BUTTON_GAP
    local free_h = h - 2 * EDGE - EXIT_H - BUTTON_GAP
    local top = EDGE + math.floor((free_h - stack_h) / 2)
    local buttons = {}
    for i, button in ipairs({ { "colors", "Colors" }, { "shapes", "Shapes" }, { "both", "Both" } }) do
        buttons[i] = {
            mode = button[1],
            label = button[2],
            x = x,
            y = top + (i - 1) * (BUTTON_H + BUTTON_GAP),
            w = BUTTON_W,
            h = BUTTON_H,
        }
    end
    buttons[4] = {
        exit = true,
        label = "Exit",
        x = x + BUTTON_W - EXIT_W,
        y = h - EDGE - EXIT_H,
        w = EXIT_W,
        h = EXIT_H,
    }
    return buttons
end

function GameScreen.hit(rects, x, y)
    for index, rect in ipairs(rects) do
        if x >= rect.x and x < rect.x + rect.w and y >= rect.y and y < rect.y + rect.h then
            return index
        end
    end
end

local WHITE = "#FFFFFF"
local BLACK = "#000000"
local BUTTON_BORDER = 6
local EXIT_BORDER = 4
local BUTTON_FACE = 57
local EXIT_FACE = 21

local function fill(bb, rect, hex)
    bb:paintRectRGB32(rect.x, rect.y, rect.w, rect.h, Blitbuffer.colorFromString(hex))
end

local function framed(bb, rect, border, hex)
    fill(bb, rect, BLACK)
    fill(bb, { x = rect.x + border, y = rect.y + border, w = rect.w - 2 * border, h = rect.h - 2 * border }, hex)
end

local function text(string_, font, size, color)
    return TextWidget:new{ text = string_, face = Font:getFace(font, size), fgcolor = color or Blitbuffer.COLOR_BLACK }
end

-- Paints one line centred horizontally between left and left + width.
local function paint_line(bb, widget, left, width, y)
    widget:paintTo(bb, left + math.floor((width - widget:getWidth()) / 2), y)
    widget:free()
end

function GameScreen.open(random)
    local widget = GameScreen:new{ random = random }
    UIManager:show(widget, "full")
    return widget
end

function GameScreen:init()
    local size = Screen:getSize()
    self.dimen = Geom:new{ x = 0, y = 0, w = size.w, h = size.h }
    self.rects = GameScreen.tile_rects(size.w, size.h)
    self.buttons = GameScreen.start_rects(size.w, size.h)
    self.state = "start"
end

function GameScreen:paint_start(bb)
    for _, button in ipairs(self.buttons) do
        framed(bb, button, button.exit and EXIT_BORDER or BUTTON_BORDER, WHITE)
        local font, face = "tfont", BUTTON_FACE
        if button.exit then
            font, face = "cfont", EXIT_FACE
        end
        local label = text(button.label, font, face)
        local y = button.y + math.floor((button.h - label:getSize().h) / 2)
        paint_line(bb, label, button.x, button.w, y)
    end
end

function GameScreen:paint(bb)
    fill(bb, self.dimen, WHITE)
    if self.state == "start" then
        self:paint_start(bb)
    end
end

-- Runs a handler; on an error the game closes on the next tick, so KOReader's file browser is usable again.
function GameScreen:guarded(handler, ...)
    local ok, err = pcall(handler, self, ...)
    if not ok then
        logger.warn("toddler-colors-game:", err)
        UIManager:nextTick(function()
            self:shutdown()
        end)
    end
end

function GameScreen:paintTo(bb, x, y)
    self:guarded(self.paint, bb)
end

function GameScreen:shutdown()
    if self.closed then
        return
    end
    self.closed = true
    UIManager:close(self, "full")
end

return GameScreen
