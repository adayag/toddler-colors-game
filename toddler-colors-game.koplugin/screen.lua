-- The game's one full-screen widget: start, question and answer states over KOReader. It overrides
-- InputContainer:onGesture (frontend/ui/widget/container/inputcontainer.lua:266) so every gesture stops here, and
-- paints with paintRectRGB32 (base/ffi/blitbuffer.lua:1827) because paintRect draws luminance only (:1704).
local InputContainer = require("ui/widget/container/inputcontainer")

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

return GameScreen
