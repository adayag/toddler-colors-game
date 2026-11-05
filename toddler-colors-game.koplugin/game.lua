-- The game's rules: which tiles, which target, what the text says. Pure Lua that never draws. Randomness is passed
-- in as a function of n returning 1..n, so specs fix the sequence.
local Game = {}
Game.__index = Game

Game.COLORS = { "red", "orange", "yellow", "green", "blue", "purple", "pink" }
Game.SHAPES = { "circle", "square", "triangle", "star", "heart", "diamond", "moon" }

local function shuffled(list, random)
    local copy = { unpack(list) }
    for i = #copy, 2, -1 do
        local j = random(i)
        copy[i], copy[j] = copy[j], copy[i]
    end
    return copy
end

local function name(tile)
    if tile.color and tile.shape then
        return tile.color .. " " .. tile.shape
    end
    return tile.color or tile.shape
end

function Game.new(mode, random)
    return setmetatable({ mode = mode, random = random }, Game)
end

function Game:deal()
    local colors = self.mode ~= "shapes" and shuffled(Game.COLORS, self.random)
    local shapes = self.mode ~= "colors" and shuffled(Game.SHAPES, self.random)
    local tiles = {}
    for i = 1, 7 do
        tiles[i] = { color = colors and colors[i] or nil, shape = shapes and shapes[i] or nil }
    end
    return tiles
end

function Game:round()
    local tiles = self:deal()
    local candidates = {}
    for _, tile in ipairs(tiles) do
        if name(tile) ~= self.previous then
            candidates[#candidates + 1] = tile
        end
    end
    local target = candidates[self.random(#candidates)]
    self.previous = name(target)
    return { tiles = tiles, target = target }
end

function Game.question(target)
    return target.shape and "Which one is the " or "Which one is ", name(target), "?"
end

function Game.answer(tile)
    if not tile.shape then
        return { "That's " .. tile.color .. "!" }
    end
    local word = name(tile)
    local article = word:match("^[aeiou]") and "an" or "a"
    if not tile.color then
        return { "That's " .. article .. " " .. word .. "!" }
    end
    return { "That's " .. article, word .. "!" }
end

return Game
