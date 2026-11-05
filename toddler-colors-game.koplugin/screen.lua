-- The game's one full-screen widget: start, question and answer states over KOReader. It overrides
-- InputContainer:onGesture (frontend/ui/widget/container/inputcontainer.lua:266) so every gesture stops here, and
-- paints with paintRectRGB32 (base/ffi/blitbuffer.lua:1827) because paintRect draws luminance only (:1704).
local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Font = require("ui/font")
local Game = require("game")
local Geom = require("ui/geometry")
local InputContainer = require("ui/widget/container/inputcontainer")
local Shapes = require("shapes")
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
local TOP = 8
local TILE_BORDER = 4
local TILE_SHAPE = 290
local QUESTION_FACE = 34
local ANSWER_FACE = 57
local COLOR_ANSWER_FACE = 71
local COLOR_ANSWER_LINE = 170
local ANSWER_LINE = 132
local ANSWER_SHAPE = { 1200, 1150 }
local ANSWER_SHAPE_GAP = { 80, 40 }

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

local function question_parts(target)
    local prefix, target_name, suffix = Game.question(target)
    return { text(prefix, "cfont", QUESTION_FACE), text(target_name, "tfont", QUESTION_FACE),
        text(suffix, "cfont", QUESTION_FACE) }
end

local function parts_width(parts)
    local width = 0
    for _, part in ipairs(parts) do
        width = width + part:getWidth()
    end
    return width
end

local function answer_face(tile)
    return tile.shape and ANSWER_FACE or COLOR_ANSWER_FACE
end

function GameScreen.question_width(target)
    local parts = question_parts(target)
    local width = parts_width(parts)
    for _, part in ipairs(parts) do
        part:free()
    end
    return width
end

function GameScreen.answer_width(tile)
    local width = 0
    for _, line in ipairs(Game.answer(tile)) do
        local widget = text(line, "tfont", answer_face(tile))
        width = math.max(width, widget:getWidth())
        widget:free()
    end
    return width
end

local function paint_shape(bb, shape, color, size, x, y)
    local image = Shapes.render(shape, color, size)
    bb:blitFrom(image, x, y, 0, 0, size, size)
    image:free()
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

function GameScreen:paint_question(bb)
    local parts = question_parts(self.round.target)
    local x = math.floor((self.dimen.w - parts_width(parts)) / 2)
    for _, part in ipairs(parts) do
        part:paintTo(bb, x, TOP)
        x = x + part:getWidth()
        part:free()
    end
    for index, rect in ipairs(self.rects) do
        local tile = self.round.tiles[index]
        framed(bb, rect, TILE_BORDER, tile.shape and WHITE or Shapes.hex(tile.color))
        if tile.shape then
            paint_shape(bb, tile.shape, tile.color, TILE_SHAPE, rect.x + math.floor((rect.w - TILE_SHAPE) / 2),
                rect.y + math.floor((rect.h - TILE_SHAPE) / 2))
        end
    end
end

function GameScreen:paint_color_answer(bb, tile)
    fill(bb, self.dimen, Shapes.hex(tile.color))
    local color = Shapes.is_dark(tile.color) and Blitbuffer.COLOR_WHITE or Blitbuffer.COLOR_BLACK
    local y = math.floor((self.dimen.h - COLOR_ANSWER_LINE) / 2)
    paint_line(bb, text(Game.answer(tile)[1], "tfont", COLOR_ANSWER_FACE, color), 0, self.dimen.w, y)
end

function GameScreen:paint_shape_answer(bb, tile)
    local lines = Game.answer(tile)
    local size, gap = ANSWER_SHAPE[#lines], ANSWER_SHAPE_GAP[#lines]
    local y = math.floor((self.dimen.h - size - gap - #lines * ANSWER_LINE) / 2)
    paint_shape(bb, tile.shape, tile.color, size, math.floor((self.dimen.w - size) / 2), y)
    y = y + size + gap
    for _, line in ipairs(lines) do
        paint_line(bb, text(line, "tfont", ANSWER_FACE), 0, self.dimen.w, y)
        y = y + ANSWER_LINE
    end
end

function GameScreen:paint_answer(bb)
    if self.tapped.shape then
        self:paint_shape_answer(bb, self.tapped)
    else
        self:paint_color_answer(bb, self.tapped)
    end
end

function GameScreen:paint(bb)
    fill(bb, self.dimen, WHITE)
    if self.state == "start" then
        self:paint_start(bb)
    elseif self.state == "question" then
        self:paint_question(bb)
    else
        self:paint_answer(bb)
    end
end

function GameScreen:go(state)
    self.state = state
    UIManager:setDirty(self, "full")
end

function GameScreen:ask()
    self.round = self.game:round()
    self:go("question")
end

function GameScreen:press(pos)
    if self.state == "start" then
        local button = self.buttons[GameScreen.hit(self.buttons, pos.x, pos.y) or 0]
        if button and button.exit then
            self:shutdown()
        elseif button then
            self.game = Game.new(button.mode, self.random)
            self:ask()
        end
    elseif self.state == "question" then
        local index = GameScreen.hit(self.rects, pos.x, pos.y)
        if index then
            self.tapped = self.round.tiles[index]
            self:go("answer")
        end
    else
        self:ask()
    end
end

function GameScreen:handle(ev)
    if ev.ges == "tap" then
        self:press(ev.pos)
    elseif ev.ges == "hold" then
        self.hold = ev
    elseif ev.ges == "hold_release" and self.hold then
        self.hold = nil
        self:press(ev.pos)
    end
end

function GameScreen:onGesture(ev)
    self:guarded(self.handle, ev)
    return true
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
