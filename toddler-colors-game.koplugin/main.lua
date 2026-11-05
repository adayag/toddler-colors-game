-- Adds Tools > Toddler Colors Game (frontend/ui/menusorter.lua:179-182) and opens the game. Every module is required
-- here because KOReader puts the plugin root first on package.path only while it loads this file
-- (frontend/pluginloader.lua:242, :269-270). Requiring random seeds math.random (frontend/random.lua:8, :11).
require("random")
require("game")
require("shapes")
local GameScreen = require("screen")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local logger = require("logger")
local _ = require("gettext")

local ToddlerColorsGame = WidgetContainer:extend{
    name = "toddler-colors-game",
    is_doc_only = false,
}

function ToddlerColorsGame:init()
    self.ui.menu:registerToMainMenu(self)
end

function ToddlerColorsGame:addToMainMenu(menu_items)
    menu_items.toddler_colors_game = {
        text = _("Toddler Colors Game"),
        sorting_hint = "tools",
        callback = function()
            self:start()
        end,
    }
end

function ToddlerColorsGame:start(random)
    local ok, err = pcall(GameScreen.open, random or math.random)
    if not ok then
        logger.warn("toddler-colors-game: could not open:", err)
    end
end

return ToddlerColorsGame
