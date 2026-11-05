describe("the game on the emulator", function()
    require("commonrequire")
    local results

    setup(function()
        results = require("emulator.driver").walk()
    end)

    it("opens on the start screen with its black-outlined buttons on white", function()
        assert.equals("start", results.start.state)
        assert.equals("#000000", results.start.button)
        assert.equals("#FFFFFF", results.start.background)
        assert.is_true(results.start.exit_label)
    end)

    it("opens from Tools in the file manager's main menu", function()
        assert.equals("start", results.menu.state)
    end)
end)
