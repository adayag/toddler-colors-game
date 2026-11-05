describe("shapes", function()
    require("commonrequire")
    local Shapes = require("shapes")

    -- A point inside each shape on the 100×100 viewBox.
    local INSIDE = {
        circle = { 50, 50 }, square = { 50, 50 }, triangle = { 50, 60 }, star = { 50, 50 },
        heart = { 50, 40 }, diamond = { 50, 50 }, moon = { 20, 50 },
    }

    local function pixel(bb, x, y)
        local c = bb:getPixel(x, y):getColorRGB32()
        return string.format("#%02X%02X%02X", c.r, c.g, c.b)
    end

    it("writes the requested size into the SVG, which the render otherwise ignores", function()
        local bb = Shapes.render("circle", "blue", 290)
        assert.equals(290, bb:getWidth())
        assert.equals(290, bb:getHeight())
        bb:free()
    end)

    it("keeps each colour through the render", function()
        for _, color in ipairs({ "red", "orange", "yellow", "green", "blue", "purple", "pink" }) do
            local bb = Shapes.render("square", color, 290)
            assert.equals(Shapes.hex(color), pixel(bb, 145, 145))
            bb:free()
        end
    end)

    it("draws each shape, in black when no colour is given, on white", function()
        for shape, point in pairs(INSIDE) do
            local bb = Shapes.render(shape, nil, 290)
            assert.equals("#000000", pixel(bb, point[1] * 2.9, point[2] * 2.9))
            assert.equals("#FFFFFF", pixel(bb, 1, 1))
            bb:free()
        end
    end)

    it("owns its pixels, so free() releases them", function()
        local bb = Shapes.render("circle", "blue", 290)
        assert.equals(1, bb:getAllocated())
        bb:free()
    end)

    it("outlines a coloured shape in black", function()
        assert.truthy(Shapes.svg("circle", "blue", 290):find('stroke="#000000"', 1, true))
        assert.is_nil(Shapes.svg("circle", nil, 290):find("stroke", 1, true))
    end)
end)
