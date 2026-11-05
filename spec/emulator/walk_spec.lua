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

    for _, mode in ipairs({ "colors", "shapes", "both" }) do
        describe(mode .. " mode", function()
            it("paints the question and all 7 tiles in their colour or shape", function()
                assert.equals("question", results[mode].question_state)
                assert.is_true(results[mode].question_text)
                assert.is_true(results[mode].tiles_painted)
            end)

            it("names the tapped tile whatever the target was", function()
                assert.equals("answer", results[mode].answer_state)
                assert.is_true(results[mode].answer_painted)
                assert.is_true(results[mode].answer_text)
            end)

            it("asks about the target and draws each tile's own shape", function()
                assert.is_string(results[mode].question_expected)
                assert.equals(results[mode].question_expected, results[mode].question_words)
                assert.is_string(results[mode].tile_shapes_expected)
                assert.equals(results[mode].tile_shapes_expected, results[mode].tile_shapes)
            end)

            it("draws and names the tapped tile on the answer", function()
                assert.is_string(results[mode].answer_expected)
                assert.equals(results[mode].answer_expected, results[mode].answer_words)
                assert.is_string(results[mode].answer_shape_expected)
                assert.equals(results[mode].answer_shape_expected, results[mode].answer_shape)
            end)

            it("does one full refresh per screen change", function()
                assert.equals("full", results[mode].question_refreshes)
                assert.equals("full", results[mode].answer_refreshes)
                assert.equals("full", results[mode].next_refreshes)
            end)

            it("asks a new question on the next tap", function()
                assert.equals("question", results[mode].next_state)
                assert.are_not.equal(results[mode].previous_target, results[mode].next_target)
            end)
        end)
    end

    it("fills the whole answer screen with the tapped colour in colors mode", function()
        assert.is_true(results.colors.answer_fills)
    end)

    it("writes white on red, blue and purple answers and black on the rest", function()
        for _, color in ipairs({ "red", "blue", "purple" }) do
            assert.is_true(results.ink[color].white)
            assert.is_false(results.ink[color].black)
        end
        for _, color in ipairs({ "orange", "yellow", "green", "pink" }) do
            assert.is_true(results.ink[color].black)
            assert.is_false(results.ink[color].white)
        end
    end)

    it("does nothing for a tap outside every tile", function()
        assert.equals("question", results.taps.gap)
        assert.equals("question", results.taps.beside_seventh)
        assert.equals("question", results.taps.header)
    end)

    it("counts a slow press as a tap when the finger lifts", function()
        assert.equals("answer", results.taps.slow_press)
        assert.equals("question", results.taps.slow_press_on_answer)
    end)

    describe("the corner hold", function()
        it("does not exit at 2.9 s", function()
            assert.equals("question", results.exit.at_2_9)
        end)

        it("returns to the start screen at 3.0 s", function()
            assert.equals("start", results.exit.at_3_0)
        end)

        it("does not exit from elsewhere on the screen", function()
            assert.equals("question", results.exit.outside_corner)
            assert.equals("question", results.exit.below_corner)
        end)

        it("ignores a release with no hold before it", function()
            assert.equals("question", results.exit.release_without_hold)
        end)

        it("exits when a held finger drifts out of the corner", function()
            assert.equals("start", results.exit.drifted)
        end)

        it("does nothing on the start screen", function()
            assert.equals("start", results.exit.on_start)
            assert.equals("", results.exit.on_start_refreshes)
        end)
    end)

    describe("gestures", function()
        it("open KOReader's menu when the game isn't showing", function()
            assert.is_true(results.leak.control_opened_menu)
        end)

        it("stay in the game on the start screen", function()
            assert.is_true(results.leak.start_kept)
        end)

        it("stay in the game on the question screen", function()
            assert.is_true(results.leak.game_kept)
        end)

        it("reach the screenshot gesture when the game isn't showing, so the next test can fail", function()
            assert.is_true(results.leak.screenshot_control)
        end)

        it("never reach KOReader's screenshot gesture from the game", function()
            assert.is_false(results.leak.screenshot_on_start)
            assert.is_false(results.leak.screenshot_on_question)
        end)
    end)

    it("fits every question and answer inside the margins", function()
        assert.is_true(results.widest_question <= 1224)
        assert.is_true(results.widest_answer <= 1224)
    end)

    it("closes from the start screen's Exit button", function()
        assert.is_true(results.exit_button.closed)
    end)

    it("runs in portrait and puts the old rotation back", function()
        assert.equals(0, results.rotation.during)
        assert.equals(1264, results.rotation.width)
        assert.equals(1, results.rotation.after)
    end)
end)
