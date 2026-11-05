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

    it("plays from Tools on KOReader's own random numbers", function()
        assert.equals("question", results.menu.played)
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

            it("paints the bar last on the question and the answer", function()
                assert.equals("Hold to exit", results[mode].question_bar)
                assert.is_true(results[mode].question_bar_painted)
                assert.equals("Hold to exit", results[mode].answer_bar)
                assert.is_true(results[mode].answer_bar_painted)
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

    it("shows the bar's white strip on top of every colour answer", function()
        for _, color in ipairs({ "red", "orange", "yellow", "green", "blue", "purple", "pink" }) do
            assert.is_true(results.ink[color].bar)
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

    it("counts a tap beside a resting finger", function()
        assert.equals("answer", results.taps.two_finger_tap)
        assert.equals("question", results.taps.two_finger_hold_release)
    end)

    describe("the hold to exit bar", function()
        it("is not on the start screen", function()
            assert.is_false(results.start.bar_painted)
            assert.equals("Colors,Shapes,Both,Exit", results.bar.start_words)
        end)

        it("does nothing for a tap or a slow press on a question", function()
            assert.equals("question", results.bar.tap_on_question)
            assert.equals("question", results.bar.press_on_question)
        end)

        it("does nothing for any tap or slow press on an answer", function()
            assert.equals("answer", results.bar.tap_on_answer)
            assert.equals("answer", results.bar.press_on_answer)
            assert.equals("answer", results.bar.two_finger_tap)
            assert.equals("answer", results.bar.two_finger_release)
            assert.equals("answer", results.bar.lift_on_bar)
        end)

        it("leaves the answer's next tap live right above it", function()
            assert.equals("question", results.bar.tap_above_bar)
        end)

        it("schedules the exit 2.5 s after hold, which comes 0.5 s after touch down", function()
            assert.equals(2.5, results.bar.delay)
        end)

        it("goes to the start screen only when the timer fires, with one full refresh", function()
            assert.equals("answer", results.bar.before_firing)
            assert.equals("start", results.bar.fired)
            assert.equals("full", results.bar.fired_refreshes)
            assert.equals("start", results.left_answer)
        end)

        it("ignores the late release after the timer fired, even over Exit", function()
            assert.equals("start", results.bar.late_release)
            assert.equals("", results.bar.late_refreshes)
        end)

        it("stays put and cancels when released early", function()
            assert.is_false(results.bar.release_keeps)
            assert.equals("question", results.bar.after_release)
        end)

        it("cancels when the finger drifts off, and the lift presses nothing", function()
            assert.is_false(results.bar.drift_keeps)
            assert.equals("question", results.bar.after_drift)
        end)

        it("stays armed while the finger moves along the bar", function()
            assert.is_true(results.bar.pan_on_bar_keeps)
        end)

        it("cancels on every gesture but the holding finger's own drag", function()
            assert.same({ "tap", "double_tap", "two_finger_tap", "touch", "swipe", "two_finger_swipe", "multiswipe",
                "pan", "pan_release", "two_finger_pan", "hold", "hold_release", "two_finger_hold",
                "two_finger_hold_release", "pinch", "spread", "inward_pan", "outward_pan", "rotate" },
                results.bar.cancelled_by)
        end)

        it("never leaves two timers queued", function()
            assert.is_false(results.bar.first_hold_keeps)
        end)

        it("cancels on Suspend", function()
            assert.is_false(results.bar.suspend_keeps)
        end)

        it("cancels when the game closes", function()
            assert.is_false(results.bar.close_keeps)
        end)

        it("arms nothing for a hold elsewhere, and the lift is a slow press", function()
            assert.equals(0, results.bar.elsewhere_timers)
            assert.equals("answer", results.bar.elsewhere)
        end)

        it("is not live on the start screen", function()
            assert.equals(0, results.bar.on_start_timers)
            assert.equals("start", results.bar.on_start)
            assert.equals("", results.bar.on_start_refreshes)
        end)

        it("ignores a release with no hold before it", function()
            assert.equals("question", results.bar.release_without_hold)
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
        assert.is_true(results.text_left >= 20)
        assert.is_true(results.text_right <= 1244)
    end)

    it("keeps every question and answer above the bar", function()
        assert.is_true(results.text_bottom <= 1580)
    end)

    it("closes from the start screen's Exit button", function()
        assert.is_true(results.exit_button.closed)
    end)

    it("does a full refresh when it opens and when it closes", function()
        assert.equals("full", results.open_refreshes)
        assert.equals("full", results.exit_button.refreshes)
    end)

    it("runs in portrait and puts the old rotation back", function()
        assert.equals(0, results.rotation.during)
        assert.equals(1264, results.rotation.width)
        assert.equals(1, results.rotation.after)
    end)

    describe("on an error", function()
        it("closes when a paint fails", function()
            assert.is_true(results.failure.paint_closed)
        end)

        it("closes when a gesture handler fails", function()
            assert.is_true(results.failure.gesture_closed)
        end)

        it("closes when the exit timer fails", function()
            assert.is_false(results.failure.timer_raised)
            assert.is_true(results.failure.timer_closed)
        end)

        it("leaves KOReader's file browser on top", function()
            assert.is_true(results.failure.file_browser_on_top)
        end)

        it("stays in KOReader's file browser when opening fails", function()
            assert.is_true(results.failure.open_kept_file_browser)
        end)
    end)
end)
