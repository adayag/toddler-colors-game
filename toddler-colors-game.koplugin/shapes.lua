-- The seven shapes as SVG templates and the seven colours. Renders through
-- RenderImage:renderSVGImageDataWithCRengine (frontend/ui/renderimage.lua:104), which ignores the requested size
-- unless the SVG states it, and returns an opaque buffer on white. It hands over a malloc'ed buffer it doesn't mark as
-- owned (frontend/ui/renderimage.lua:111), so free() would release nothing (base/ffi/blitbuffer.lua:1472) until
-- setAllocated (:699).
local RenderImage = require("ui/renderimage")

local Shapes = {}

local PALETTE = {
    red = "#D7263D",
    orange = "#F28C28",
    yellow = "#FFD60A",
    green = "#2E9E4F",
    blue = "#1E6FD9",
    purple = "#7B2FBE",
    pink = "#FF7AB8",
}

-- Colours that take white text on the answer screen.
local DARK = { red = true, blue = true, purple = true }

local TEMPLATES = {
    circle = '<circle cx="50" cy="50" r="46" %s/>',
    square = '<rect x="8" y="8" width="84" height="84" %s/>',
    triangle = '<polygon points="50,7 95,90 5,90" %s/>',
    star = '<polygon points="50,4 61.8,36 96,37 69,58.6 78.5,91.5 50,72.5 21.5,91.5 31,58.6 4,37 38.2,36" %s/>',
    heart = '<path d="M50 90 C20 66 5 48 5 30 C5 16 16 7 28 7 C38 7 46 13 50 22'
        .. ' C54 13 62 7 72 7 C84 7 95 16 95 30 C95 48 80 66 50 90 Z" %s/>',
    diamond = '<polygon points="50,3 93,50 50,97 7,50" %s/>',
    moon = '<path d="M66 6 A46 46 0 1 0 66 94 A52 52 0 0 1 66 6 Z" %s/>',
}

function Shapes.hex(color)
    return PALETTE[color]
end

function Shapes.is_dark(color)
    return DARK[color] == true
end

function Shapes.svg(shape, color, size)
    local paint = 'fill="#000000"'
    if color then
        -- A big shape scales its outline with it, so it takes half the stroke.
        local stroke = size > 600 and 1 or 2
        paint = string.format('fill="%s" stroke="#000000" stroke-width="%d" stroke-linejoin="round"',
            PALETTE[color], stroke)
    end
    return string.format('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d"'
        .. ' viewBox="0 0 100 100">%s</svg>',
        size, size, TEMPLATES[shape]:format(paint))
end

function Shapes.render(shape, color, size)
    local svg = Shapes.svg(shape, color, size)
    local image = assert(RenderImage:renderSVGImageDataWithCRengine(svg, #svg, size, size))
    image:setAllocated(1)
    return image
end

return Shapes
