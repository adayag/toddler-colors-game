describe("game", function()
    local Game = require("game")

    -- A fixed sequence, so a failure replays the same way.
    local function sequence()
        local state = 7
        return function(n)
            state = (state * 75 + 74) % 65537
            return state % n + 1
        end
    end

    local function always_first()
        return 1
    end

    local function distinct(tiles, field)
        local seen, count = {}, 0
        for _, tile in ipairs(tiles) do
            if not seen[tile[field]] then
                seen[tile[field]] = true
                count = count + 1
            end
        end
        return count
    end

    local function same(a, b)
        return a.color == b.color and a.shape == b.shape
    end

    for _, mode in ipairs({ "colors", "shapes", "both" }) do
        describe(mode .. " mode", function()
            it("never asks the same target twice in a row", function()
                local game = Game.new(mode, sequence())
                local previous
                for _ = 1, 500 do
                    local round = game:round()
                    assert.is_false(previous ~= nil and same(previous, round.target))
                    previous = round.target
                end
            end)

            it("still changes target when the random source always returns 1", function()
                local game = Game.new(mode, always_first)
                assert.is_false(same(game:round().target, game:round().target))
            end)

            it("puts the target anywhere in the grid", function()
                local game = Game.new(mode, sequence())
                local positions = {}
                for _ = 1, 100 do
                    local round = game:round()
                    for i, tile in ipairs(round.tiles) do
                        if same(tile, round.target) then
                            positions[i] = true
                        end
                    end
                end
                for i = 1, 7 do
                    assert.is_true(positions[i])
                end
            end)

            it("deals 7 tiles that include the target", function()
                local game = Game.new(mode, sequence())
                for _ = 1, 100 do
                    local round = game:round()
                    assert.equals(7, #round.tiles)
                    local found = false
                    for _, tile in ipairs(round.tiles) do
                        found = found or same(tile, round.target)
                    end
                    assert.is_true(found)
                end
            end)
        end)
    end

    it("deals only colours in colors mode and only shapes in shapes mode", function()
        local colors = Game.new("colors", sequence()):round()
        assert.equals(7, distinct(colors.tiles, "color"))
        assert.is_nil(colors.target.shape)
        local shapes = Game.new("shapes", sequence()):round()
        assert.equals(7, distinct(shapes.tiles, "shape"))
        assert.is_nil(shapes.target.color)
    end)

    it("repeats no colour and no shape in a both-mode grid", function()
        local game = Game.new("both", sequence())
        for _ = 1, 100 do
            local tiles = game:round().tiles
            assert.equals(7, distinct(tiles, "color"))
            assert.equals(7, distinct(tiles, "shape"))
        end
    end)

    local function reorders(mode, field)
        local game = Game.new(mode, sequence())
        local first, second = game:round().tiles, game:round().tiles
        for i = 1, 7 do
            if first[i][field] ~= second[i][field] then
                return true
            end
        end
        return false
    end

    it("shuffles the tiles between rounds", function()
        assert.is_true(reorders("colors", "color"))
        assert.is_true(reorders("shapes", "shape"))
        assert.is_true(reorders("both", "color"))
        assert.is_true(reorders("both", "shape"))
    end)

    it("pairs colours and shapes afresh, not one fixed set of 7", function()
        local game = Game.new("both", sequence())
        local seen, count = {}, 0
        for _ = 1, 100 do
            local target = game:round().target
            local name = target.color .. " " .. target.shape
            if not seen[name] then
                seen[name] = true
                count = count + 1
            end
        end
        assert.is_true(count > 7)
    end)

    it("words the question in three parts so the name can be bold", function()
        assert.same({ "Which one is ", "blue", "?" }, { Game.question({ color = "blue" }) })
        assert.same({ "Which one is the ", "star", "?" }, { Game.question({ shape = "star" }) })
        assert.same({ "Which one is the ", "blue circle", "?" },
            { Game.question({ color = "blue", shape = "circle" }) })
    end)

    it("words the answer as one line, or two in both mode", function()
        assert.same({ "That's green!" }, Game.answer({ color = "green" }))
        assert.same({ "That's a heart!" }, Game.answer({ shape = "heart" }))
        assert.same({ "That's a", "green star!" }, Game.answer({ color = "green", shape = "star" }))
    end)

    it("uses an before a vowel", function()
        assert.same({ "That's an", "orange star!" }, Game.answer({ color = "orange", shape = "star" }))
    end)
end)
