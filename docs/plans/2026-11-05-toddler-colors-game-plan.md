# Toddler Colors Game Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (separate session) or superpowers:subagent-driven-development (this session) to implement this plan task by task. `AGENTS.md` overrides those skills where they differ: work on `main`, no worktree, and every commit step below waits for the owner's approval.

> **As built:** the tree is the record now. Reviews changed the code after this plan was written: the walk spies on what is drawn and on `Screenshoter`, text fit is measured from what is painted (`question_width`, `answer_width` and `answer_face` are gone), `Shapes.render` calls `setAllocated(1)`, two-finger taps count as presses, and a "Hold to exit" bar replaced the corner hold, which shrank the tiles to 600×338.

**Goal:** A KOReader plugin with three modes (Colors, Shapes, Both): a 7-tile question screen, an answer screen that names what was tapped, and a 3-second corner hold back to the start screen.

**Architecture:** `game.lua` holds the rules and draws nothing. `shapes.lua` turns a shape and colour into an SVG and renders it. `screen.lua` is one full-screen widget that consumes every gesture and paints each state. `main.lua` adds the menu entry and wraps the launch in `pcall`.

**Tech stack:** Lua on KOReader's LuaJIT, KOReader's widget API, Busted from the emulator's `spec/rocks/`, luacheck.

**Reads first:** `AGENTS.md`, `docs/plans/2026-11-05-toddler-colors-game-design.md`. The approved screens are the "Toddler Colors Game mocks" canvas: https://claude.ai/artifact/GzUshXDpa7b2Nrb6sepnBX

---

## Verified facts

All citations are at the pinned build `e1fe1ac`, relative to `~/Projects/kodev/koreader/` unless they start with `kopanda/` (`~/Projects/elatedpanda/kopanda/`).

**SVG render, probed on 2026-11-05 through a Busted spec on the emulator's LuaJIT:**
- `RenderImage:renderSVGImageDataWithCRengine` (`frontend/ui/renderimage.lua:104`) keeps colour exactly: `#1E6FD9` fill came back as r=30 g=111 b=217. The SVG path wins; the scanline fallback is not built.
- It needs `width` and `height` attributes on `<svg>`. Without them, a request for 290 returned 200×200 and a request for 1150 returned 1100×1100. With them, 290, 1150 and 1200 all came back at that exact size.
- The result is `TYPE_BBRGB32` flattened onto opaque white (corner pixel r=255 g=255 b=255 a=255). So a shape needs a white background, and a plain `blitFrom` is enough. Every shape in the design sits on white.

**Gestures:**
- `UIManager:sendEvent` gives a gesture to the topmost non-toast widget first and stops when `handleEvent` returns true (`frontend/ui/uimanager.lua:962-992`).
- `hold` and `hold_release` both carry `time = tev.timev` (`frontend/device/gesturedetector.lua:1262-1296`, `:1343-1354`). A hold that drifts into `hold_pan` still emits `hold_release` (`:14`).
- `hold` fires 500 ms after touch down (`:63`, `:102`). The exit gap runs from `hold` to `hold_release`, so 3.0 s of gap is about 3.5 s of finger.
- Overriding `onGesture` replaces `InputContainer:onGesture` (`frontend/ui/widget/container/inputcontainer.lua:266`), which is what `ges_events` matching runs from. The override catches every gesture name without listing any.

**Screen:**
- The Colorsoft class sets no `hasGSensor` (`frontend/device/kindle/device.lua:1208-1220`) and the default is `no` (`frontend/device/generic/device.lua:126`). KOReader never auto-rotates there, so "portrait locked" only means setting portrait at launch and restoring on exit. Whether the Colorsoft SE maps to this class is an **assumption**; Task 12's device check covers it.
- `SetRotationMode` is handled by `FileManager:onSetRotationMode` (`frontend/apps/filemanager/filemanager.lua:71`) and `ReaderView:onSetRotationMode` (`frontend/apps/reader/modules/readerview.lua:895`).
- `Font:getFace` scales through `Screen:scaleBySize` (`frontend/ui/font.lua:276`), which is `ceil(px × 1264 / 600)` here (`base/ffi/framebuffer.lua:414-426`). Face size 34 is 72 px, 57 is 121 px, 71 is 150 px, 21 is 45 px.
- `cfont` is `NotoSans-Regular.ttf` and `tfont` is `NotoSans-Bold.ttf` (`frontend/ui/font.lua:42`, `:45`).
- `paintRect` draws luminance only (`base/ffi/blitbuffer.lua:1704`); colour goes through `paintRectRGB32` (`:1827`). `Blitbuffer.colorFromString` parses `#RRGGBB` (`:2653`).

**Text fit at the design's sizes, from font advance widths (kerning not counted), against 1224 px available:**
- Longest question: "Which one is the **orange diamond**?", 1202 px at 72 px.
- Longest Colors answer: "That's orange!", 1071 px at 150 px.
- Longest Shapes answer: "That's a diamond!", 1074 px at 121 px.
- Longest Both second line: "orange diamond!", 1033 px at 121 px.

**Plugin:**
- `sorting_hint = "tools"` appends the item to the Tools tab (`frontend/ui/menusorter.lua:179-182`).
- The plugin name is the folder name minus `.koplugin` (`frontend/pluginloader.lua:210`, `:249`), and `getPluginInstance(name)` reads `loaded_plugins`, filled at `:482` (`:573-575`).
- `require("random")` seeds `math.random` on load (`frontend/random.lua:8`, `:11`).
- A tap in the top eighth of the screen opens the file manager's menu (`frontend/apps/filemanager/filemanagermenu.lua:78-84`, `defaults.lua:59`). Task 9 uses this as the positive control.

**Owner decisions on 2026-11-05 (recorded in the design doc):**
- A slow press counts as a tap when the finger lifts.
- A tap outside every tile on the question screen does nothing.
- One-line 72 px question, 600×364 tiles, seventh tile centred.

**Assumptions the tasks verify first:**
- `UIManager:forceRePaint` (`frontend/ui/uimanager.lua:1404`) paints a dirty widget synchronously, so the walk can sample pixels right after a gesture. Task 5 verifies it.
- The first `UIManager:nextTick` after startup runs with the file manager already built and the plugin instantiated. Task 5 verifies it.
- `SetRotationMode` broadcast from the file manager works on the emulator with `EMULATE_READER_FORCE_PORTRAIT=1`. Task 10 verifies it.

## Rules for every task

- TDD: write the test, run it, see it fail for the expected reason, implement, run again.
- The gate for every task is `bin/check --unit`. Tasks 5 to 11 also run `bin/check spec/emulator/walk_spec.lua`.
- Commit steps: present the summary and message, ask "Ready to commit and push?", then `git add <the listed files>`. Never `git add -A`, never AI attribution.
- Colour values and layout numbers below come from the approved mocks. The owner judges them on the emulator, so they need no test of their own.

---

### Task 1: The gate

About 20 minutes.

**Files:**
- Create: `bin/check`, `spec/helper.lua`, `.luacheckrc`, `.env.example`

**Step 1: Write `bin/check`**

```bash
#!/usr/bin/env bash
# The gate: luacheck, then Busted specs on the emulator's LuaJIT under a fresh KO_HOME.
#
#   bin/check              lint, unit specs, emulator specs; stops at the first failing stage
#   bin/check --unit       lint and unit specs; stops before spec/emulator/
#   bin/check <spec>...    exactly those spec files in one Busted process, no lint
#
# Exit 0 on success, 1 when a stage fails, 2 when the script refuses to run.
set -euo pipefail

TODDLER_COLORS_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
emulator_default="$HOME/Projects/kodev/koreader/koreader-emulator-arm64-apple-darwin23.5.0-debug/koreader"
TODDLER_COLORS_EMULATOR="${TODDLER_COLORS_EMULATOR:-$emulator_default}"
export TODDLER_COLORS_ROOT TODDLER_COLORS_EMULATOR

refuse() {
    printf '%s\n' "$@" >&2
    exit 2
}

command -v luacheck >/dev/null 2>&1 || refuse "bin/check: luacheck is not on PATH" "    brew install luacheck"
[[ -x "$TODDLER_COLORS_EMULATOR/luajit" ]] || refuse "bin/check: no luajit at $TODDLER_COLORS_EMULATOR/luajit" \
    "    set TODDLER_COLORS_EMULATOR to the emulator's koreader directory"

KO_HOME="$(mktemp -d)"
export KO_HOME
trap 'rm -rf "$KO_HOME"' EXIT

run_lint() {
    echo "== lint"
    (cd "$TODDLER_COLORS_ROOT" && luacheck --quiet --no-color .)
}

# Drops the lines KOReader's ffi/loadlib.lua logs whenever a process loads a library.
drop_chatter() {
    grep -vE '^(has monolibtic\? |lib_(search_path|basic_format|version_format): |ffi\.(findlib|load): |package\.loadlib: )'
}

run_busted() {
    local lua_path="?.lua;common/?.lua;frontend/?.lua;spec/front/unit/?.lua"
    lua_path="$lua_path;spec/rocks/share/lua/5.1/?.lua;spec/rocks/share/lua/5.1/?/init.lua"
    lua_path="$lua_path;$TODDLER_COLORS_ROOT/spec/?.lua;$TODDLER_COLORS_ROOT/toddler-colors-game.koplugin/?.lua"
    cd "$TODDLER_COLORS_EMULATOR"
    LUA_PATH="$lua_path" LUA_CPATH='?.so;common/?.so;spec/rocks/lib/lua/5.1/?.so' \
        ./luajit -e 'require "busted.runner" {standalone = false}' /dev/null \
        --output=gtest --sort-files --helper="$TODDLER_COLORS_ROOT/spec/helper.lua" --loaders=lua --lazy \
        -- "$@" 2>&1 | drop_chatter
}

run_layer() {
    local layer="$1" specs=()
    echo "== $layer"
    while IFS= read -r spec; do
        specs+=("$spec")
    done < <(find "$TODDLER_COLORS_ROOT/spec/$layer" -name '*_spec.lua' -type f 2>/dev/null | sort)
    if [[ ${#specs[@]} -eq 0 ]]; then
        echo "no specs under spec/$layer"
        return 0
    fi
    (run_busted "${specs[@]}")
}

if [[ $# -eq 0 ]]; then
    run_lint || exit 1
    run_layer unit || exit 1
    run_layer emulator || exit 1
elif [[ $# -eq 1 && "$1" == "--unit" ]]; then
    run_lint || exit 1
    run_layer unit || exit 1
else
    specs=()
    for spec in "$@"; do
        [[ -f "$spec" ]] || refuse "bin/check: no such spec file: $spec"
        case "$spec" in
            /*) specs+=("$spec") ;;
            *) specs+=("$PWD/$spec") ;;
        esac
    done
    (run_busted "${specs[@]}") || exit 1
fi
```

Run `chmod +x bin/check`.

**Step 2: Write the three support files**

`spec/helper.lua`: copy `kopanda/spec/helper.lua` (26 lines), changing only the first comment line to name this repo.

`.luacheckrc`:

```lua
std = "luajit"
self = false
unused_args = false
max_line_length = 120

globals = {
    "G_reader_settings",
    "G_defaults",
}

files["spec/**"].std = "+busted"
```

`.env.example`:

```bash
# The KOReader emulator's koreader directory: holds ./luajit, frontend/ and the Busted rocks under
# spec/rocks/. bin/check runs every spec from inside it.
TODDLER_COLORS_EMULATOR=$HOME/Projects/kodev/koreader/koreader-emulator-arm64-apple-darwin23.5.0-debug/koreader
```

**Step 3: Verify**

Run: `bin/check --unit`
Expected: `== lint`, then `== unit`, then `no specs under spec/unit`; exit 0.

Run: `TODDLER_COLORS_EMULATOR=/nope bin/check --unit; echo "exit $?"`
Expected: the refusal, then `exit 2`.

**Step 4: Commit (ask first)**

Files: `bin/check`, `spec/helper.lua`, `.luacheckrc`, `.env.example`. Message: `Add the check gate`.

---

### Task 2: Shapes

About 20 minutes.

**Files:**
- Create: `toddler-colors-game.koplugin/shapes.lua`
- Test: `spec/unit/shapes_spec.lua`
- Modify: `docs/plans/2026-11-05-toddler-colors-game-design.md`

**Step 1: Write the failing test**

```lua
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

    it("outlines a coloured shape in black", function()
        assert.truthy(Shapes.svg("circle", "blue", 290):find('stroke="#000000"', 1, true))
        assert.is_nil(Shapes.svg("circle", nil, 290):find("stroke", 1, true))
    end)
end)
```

**Step 2: Run it**

Run: `bin/check spec/unit/shapes_spec.lua`
Expected: FAIL, `module 'shapes' not found`.

**Step 3: Implement**

```lua
-- The seven shapes as SVG templates and the seven colours. Renders through
-- RenderImage:renderSVGImageDataWithCRengine (frontend/ui/renderimage.lua:104), which ignores the requested size
-- unless the SVG states it, and returns an opaque buffer on white.
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
    return string.format('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 100 100">%s</svg>',
        size, size, TEMPLATES[shape]:format(paint))
end

function Shapes.render(shape, color, size)
    local svg = Shapes.svg(shape, color, size)
    return assert(RenderImage:renderSVGImageDataWithCRengine(svg, #svg, size, size))
end

return Shapes
```

**Step 4: Run it**

Run: `bin/check spec/unit/shapes_spec.lua`
Expected: PASS, 4 tests.

**Step 5: Record the winning path in the design doc**

In the "Why SVG" paragraph, replace the **Fallback** sentences and the "The colour test runs first" sentence with:

```markdown
**Colour test result:** the render keeps colour exactly, so the scanline fallback was not built. It needs `width` and `height` on the `<svg>`, and it returns an opaque buffer on white, so a shape always sits on a white background.
```

Run: `bin/check --unit`. Expected: lint clean, 4 tests pass.

**Step 6: Commit (ask first)**

Files: `toddler-colors-game.koplugin/shapes.lua`, `spec/unit/shapes_spec.lua`, the design doc. Message: `Add SVG shapes with colour render test`.

---

### Task 3: Game rules

About 20 minutes.

**Files:**
- Create: `toddler-colors-game.koplugin/game.lua`
- Test: `spec/unit/game_spec.lua`

**Step 1: Write the failing test**

```lua
describe("game", function()
    local Game = require("game")

    -- A fixed sequence, so a failure replays the same way.
    local function sequence()
        local state = 7
        return function(n)
            state = (state * 1103515245 + 12345) % 2147483648
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

    it("shuffles the tiles between rounds", function()
        local game = Game.new("colors", sequence())
        local first, second = game:round().tiles, game:round().tiles
        local differs = false
        for i = 1, 7 do
            differs = differs or first[i].color ~= second[i].color
        end
        assert.is_true(differs)
    end)

    it("words the question in three parts so the name can be bold", function()
        assert.same({ "Which one is ", "blue", "?" }, { Game.question({ color = "blue" }) })
        assert.same({ "Which one is the ", "star", "?" }, { Game.question({ shape = "star" }) })
        assert.same({ "Which one is the ", "blue circle", "?" }, { Game.question({ color = "blue", shape = "circle" }) })
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
```

**Step 2: Run it**

Run: `bin/check spec/unit/game_spec.lua`
Expected: FAIL, `module 'game' not found`.

**Step 3: Implement**

```lua
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
```

**Step 4: Run it**

Run: `bin/check spec/unit/game_spec.lua`
Expected: PASS.

Run: `bin/check --unit`. Expected: lint clean, all unit specs pass.

**Step 5: Commit (ask first)**

Files: `toddler-colors-game.koplugin/game.lua`, `spec/unit/game_spec.lua`. Message: `Add the game rules`.

---

### Task 4: Layout

About 15 minutes.

**Files:**
- Create: `toddler-colors-game.koplugin/screen.lua`
- Test: `spec/unit/layout_spec.lua`

**Step 1: Write the failing test**

```lua
describe("layout", function()
    require("commonrequire")
    local GameScreen = require("screen")

    local rects = GameScreen.tile_rects(1264, 1680)

    it("fits 600×364 tiles in two columns", function()
        assert.same({ x = 20, y = 132, w = 600, h = 364 }, rects[1])
        assert.same({ x = 644, y = 132, w = 600, h = 364 }, rects[2])
        assert.same({ x = 20, y = 908, w = 600, h = 364 }, rects[5])
    end)

    it("centres the seventh tile on the last row and ends on the bottom margin", function()
        assert.same({ x = 332, y = 1296, w = 600, h = 364 }, rects[7])
        assert.equals(1660, rects[7].y + rects[7].h)
    end)

    it("finds the tile under a point", function()
        assert.equals(1, GameScreen.hit(rects, 20, 132))
        assert.equals(7, GameScreen.hit(rects, 931, 1659))
    end)

    it("finds nothing in a gap, the header or beside the seventh tile", function()
        assert.is_nil(GameScreen.hit(rects, 632, 300))
        assert.is_nil(GameScreen.hit(rects, 300, 508))
        assert.is_nil(GameScreen.hit(rects, 100, 60))
        assert.is_nil(GameScreen.hit(rects, 100, 1500))
    end)

    it("stacks the three mode buttons above a small exit", function()
        local buttons = GameScreen.start_rects(1264, 1680)
        assert.same({ "colors", "shapes", "both" }, { buttons[1].mode, buttons[2].mode, buttons[3].mode })
        assert.equals(226, buttons[1].y)
        assert.equals(986, buttons[3].y)
        assert.is_true(buttons[4].exit)
        assert.equals(1620, buttons[4].y + buttons[4].h)
    end)
end)
```

**Step 2: Run it**

Run: `bin/check spec/unit/layout_spec.lua`
Expected: FAIL, `module 'screen' not found`.

**Step 3: Implement**

```lua
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
```

**Step 4: Run it**

Run: `bin/check spec/unit/layout_spec.lua`
Expected: PASS, 5 tests.

Run: `bin/check --unit`. Expected: lint clean, all pass.

**Step 5: Commit (ask first)**

Files: `toddler-colors-game.koplugin/screen.lua`, `spec/unit/layout_spec.lua`. Message: `Add the screen layout`.

---

### Task 5: Boot the plugin in the emulator

About 40 minutes. Builds the emulator walk the later tasks extend: one KOReader run that plays through the game from a userpatch, writes `results.json` and PNGs to `spec/.artifacts/`, and quits.

**Files:**
- Create: `toddler-colors-game.koplugin/_meta.lua`, `toddler-colors-game.koplugin/main.lua`, `spec/emulator/driver.lua`, `spec/emulator/patches/2-walk.lua`
- Test: `spec/emulator/walk_spec.lua`
- Modify: `toddler-colors-game.koplugin/screen.lua`

**Step 1: Write the driver**

`spec/emulator/driver.lua`, adapted from `kopanda/spec/emulator/driver.lua:201-265`:

```lua
-- Runs one headless KOReader on a scratch KO_HOME with the plugin copied in and the walk userpatch applied, and
-- returns what the walk wrote to spec/.artifacts/. settings.reader.lua's color_rendering skips the first-run colour
-- notice (reader.lua:195-203). Leaving extra_plugin_paths out makes KOReader add <KO_HOME>/plugins/ itself
-- (frontend/pluginloader.lua:193-199). coverbrowser is off so its database prompt doesn't appear.
local lfs = require("libs/libkoreader-lfs")

local M = {}

local TIMEOUT_S = 90

local function quote(s)
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function shell(command)
    assert(os.execute(command) == 0, "driver: failed: " .. command)
end

local function write_file(path, text)
    local file = assert(io.open(path, "w"))
    file:write(text)
    file:close()
end

local function read_file(path)
    local file = io.open(path, "r")
    if not file then
        return nil
    end
    local text = file:read("*a")
    file:close()
    return text
end

-- Runs the emulator in the background and kills it after TIMEOUT_S: SIGTERM alone can't stop a hung emulator, so
-- SIGKILL follows 5 s later (base/ffi/SDL3.lua:719-723). Returns the exit status.
local function run_emulator(emulator, env, library, log)
    local script = table.concat({
        "cd " .. quote(emulator) .. " || exit 127",
        "env -u EMULATE_BB_TYPE " .. env .. " ./luajit reader.lua " .. quote(library) .. " > " .. quote(log) .. " 2>&1 &",
        "pid=$!",
        "(sleep " .. TIMEOUT_S .. "; kill $pid 2>/dev/null; sleep 5; kill -9 $pid 2>/dev/null) >/dev/null 2>&1 &",
        "killer=$!",
        "wait $pid",
        "s=$?",
        "kill -STOP $killer 2>/dev/null; pkill -P $killer 2>/dev/null; kill -9 $killer 2>/dev/null",
        "echo",
        "echo $s",
    }, "\n")
    local pipe = assert(io.popen("sh -c " .. quote(script)))
    local output = pipe:read("*a")
    pipe:close()
    return tonumber(output:match("(%d+)\n$"))
end

function M.walk()
    local root = assert(os.getenv("TODDLER_COLORS_ROOT"), "driver: TODDLER_COLORS_ROOT unset")
    local emulator = assert(os.getenv("TODDLER_COLORS_EMULATOR"), "driver: TODDLER_COLORS_EMULATOR unset")
    local plugin = root .. "/toddler-colors-game.koplugin"
    if lfs.attributes(emulator .. "/plugins/toddler-colors-game.koplugin", "mode") then
        error("driver: the emulator's plugins/ holds the plugin; KOReader would load it twice")
    end

    local scratch = assert(os.getenv("KO_HOME")) .. "/walk"
    local artifacts = root .. "/spec/.artifacts"
    shell("rm -rf " .. quote(scratch) .. " " .. quote(artifacts))
    for _, dir in ipairs({ scratch, scratch .. "/settings", scratch .. "/patches", scratch .. "/plugins",
            scratch .. "/library", artifacts }) do
        shell("mkdir -p " .. quote(dir))
    end
    write_file(scratch .. "/settings.reader.lua",
        'return { ["color_rendering"] = true, ["plugins_disabled"] = { ["coverbrowser"] = true } }\n')
    shell("cp -R " .. quote(plugin) .. " " .. quote(scratch .. "/plugins/"))
    shell("cp " .. quote(root .. "/spec/emulator/patches/2-walk.lua") .. " " .. quote(scratch .. "/patches/"))

    local log = artifacts .. "/walk.log"
    local env = table.concat({
        "KO_HOME=" .. quote(scratch),
        "XDG_DOCUMENTS_DIR=" .. quote(scratch),
        "SDL_VIDEO_DRIVER=offscreen",
        "EMULATE_READER_W=1264",
        "EMULATE_READER_H=1680",
        "EMULATE_READER_DPI=300",
        "EMULATE_READER_FORCE_PORTRAIT=1",
        "TODDLER_WALK_DIR=" .. quote(artifacts),
    }, " ")
    local status = run_emulator(emulator, env, scratch .. "/library", log)
    local text = read_file(artifacts .. "/results.json")
    if not text then
        error("driver: no results.json, exit status " .. tostring(status) .. ", log at " .. log)
    end
    local results = require("rapidjson").decode(text)
    assert(results.error == nil, results.error)
    return results
end

return M
```

**Step 2: Write the walk patch**

`spec/emulator/patches/2-walk.lua`:

```lua
-- KOReader userpatch (late priority, frontend/userpatch.lua:13) copied into a scratch profile by
-- spec/emulator/driver.lua. Plays through the game by sending gestures to UIManager, the way the input loop does,
-- and writes what it saw to results.json plus one PNG per screen, then quits. Any error lands in results.error.
local dir = os.getenv("TODDLER_WALK_DIR")
if not dir then
    return
end

local Event = require("ui/event")
local Geom = require("ui/geometry")
local UIManager = require("ui/uimanager")
local Screen = require("device").screen
local time = require("ui/time")

local results = {}

local function finish(message)
    results.error = message
    local file = assert(io.open(dir .. "/results.json", "w"))
    file:write(require("rapidjson").encode(results))
    file:close()
    UIManager:quit()
end

local function first()
    return 1
end

local function open_game()
    require("pluginloader"):getPluginInstance("toddler-colors-game"):start(first)
    return UIManager:getNthTopWidget(1)
end

local function gesture(ges, x, y, at, extra)
    local fields = extra or {}
    fields.ges = ges
    fields.pos = Geom:new{ x = x, y = y, w = 0, h = 0 }
    fields.time = at or time.now()
    UIManager:sendEvent(Event:new("Gesture", fields))
end

local function tap(rect)
    gesture("tap", rect.x + math.floor(rect.w / 2), rect.y + math.floor(rect.h / 2))
    UIManager:forceRePaint()
end

local function shoot(name)
    UIManager:forceRePaint()
    assert(Screen:shot(dir .. "/" .. name .. ".png"))
end

local function pixel(x, y)
    local c = Screen.bb:getPixel(x, y):getColorRGB32()
    return string.format("#%02X%02X%02X", c.r, c.g, c.b)
end

-- Whether a colour appears anywhere inside rect, stepping past the tile border.
local function holds(rect, hex)
    for y = rect.y + 8, rect.y + rect.h - 8, 8 do
        for x = rect.x + 8, rect.x + rect.w - 8, 8 do
            if pixel(x, y) == hex then
                return true
            end
        end
    end
    return false
end

local function walk()
    local size = Screen:getSize()
    local buttons = require("screen").start_rects(size.w, size.h)
    local game = open_game()
    shoot("start")
    results.start = { state = game.state, button = pixel(buttons[1].x + 2, buttons[1].y + 2), background = pixel(5, 5) }
    finish()
end

UIManager:nextTick(function()
    local ok, err = xpcall(walk, debug.traceback)
    if not ok then
        finish(tostring(err))
    end
end)
```

**Step 3: Write the failing spec**

`spec/emulator/walk_spec.lua`:

```lua
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
    end)
end)
```

**Step 4: Run it**

Run: `bin/check spec/emulator/walk_spec.lua`
Expected: FAIL. The plugin folder has no `main.lua`, so `getPluginInstance` returns nil and `results.error` names the nil index.

If it instead fails with no `results.json`, read `spec/.artifacts/walk.log`: that is the driver or the first-tick assumption, and it must be fixed before going on.

**Step 5: Implement the plugin and the start state**

`toddler-colors-game.koplugin/_meta.lua`:

```lua
local _ = require("gettext")
return {
    fullname = _("Toddler Colors Game"),
    description = _([[A colours and shapes game for a toddler.]]),
}
```

`toddler-colors-game.koplugin/main.lua`:

```lua
-- Adds Tools > Toddler Colors Game (frontend/ui/menusorter.lua:179-182) and opens the game. Every module is required
-- here because KOReader keeps the plugin root on package.path only while it loads this file
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
```

In `screen.lua`, replace the requires at the top with:

```lua
local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Font = require("ui/font")
local Geom = require("ui/geometry")
local InputContainer = require("ui/widget/container/inputcontainer")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local logger = require("logger")
local Screen = Device.screen
```

Add these above `return GameScreen`:

```lua
local WHITE = "#FFFFFF"
local BLACK = "#000000"
local BUTTON_BORDER = 6
local EXIT_BORDER = 4
local BUTTON_FACE = 57
local EXIT_FACE = 21

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

function GameScreen:paint(bb)
    fill(bb, self.dimen, WHITE)
    if self.state == "start" then
        self:paint_start(bb)
    end
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
```

**Step 6: Run it**

Run: `bin/check spec/emulator/walk_spec.lua`
Expected: PASS, 1 test. Open `spec/.artifacts/start.png` and compare it with the mock's Start screen.

If the `forceRePaint` assumption fails (the buttons read `#FFFFFF`), find what paints synchronously, record it in `Verified facts`, and stop to tell the lead.

Run: `bin/check --unit`. Expected: lint clean, all pass.

**Step 7: Commit (ask first)**

Files: `_meta.lua`, `main.lua`, `screen.lua`, `spec/emulator/driver.lua`, `spec/emulator/patches/2-walk.lua`, `spec/emulator/walk_spec.lua`. Message: `Open the start screen from a plugin menu entry`.

---

### Task 6: Question and answer screens

About 45 minutes.

**Files:**
- Modify: `toddler-colors-game.koplugin/screen.lua`, `spec/emulator/patches/2-walk.lua`, `spec/emulator/walk_spec.lua`

**Step 1: Extend the walk**

In `2-walk.lua`, add above `walk`:

```lua
local function all_true(list)
    for _, value in ipairs(list) do
        if not value then
            return false
        end
    end
    return #list == 7
end

-- From the start screen: picks a mode, shoots the question, taps tile 2, shoots the answer, taps once more, and
-- leaves the game on a fresh question. Returns what each screen showed.
local function play(game, index, mode)
    local Shapes = require("shapes")
    local seen = {}
    tap(game.buttons[index])
    shoot(mode .. "-question")
    seen.question_state = game.state
    local tiles = {}
    for i, rect in ipairs(game.rects) do
        local tile = game.round.tiles[i]
        tiles[i] = holds(rect, tile.color and Shapes.hex(tile.color) or "#000000")
    end
    seen.tiles_painted = all_true(tiles)
    seen.previous_target = game.round.target.color or game.round.target.shape

    local tapped = game.round.tiles[2]
    tap(game.rects[2])
    shoot(mode .. "-answer")
    seen.answer_state = game.state
    local whole = { x = 0, y = 0, w = size_w(), h = size_h() }
    seen.answer_painted = holds(whole, tapped.color and Shapes.hex(tapped.color) or "#000000")
    seen.answer_fills = mode == "colors" and pixel(10, 10) == Shapes.hex(tapped.color)

    tap(whole)
    seen.next_state = game.state
    seen.next_target = game.round.target.color or game.round.target.shape
    return seen
end
```

Add above `all_true`:

```lua
local function size_w()
    return Screen:getWidth()
end

local function size_h()
    return Screen:getHeight()
end
```

In `walk`, between the `results.start` line and `finish()`:

```lua
    results.colors = play(game, 1, "colors")
    game.state = "start"
    results.shapes = play(game, 2, "shapes")
    game.state = "start"
    results.both = play(game, 3, "both")
    game.state = "start"
```

Task 8 replaces those `game.state` lines with a real exit hold.

**Step 2: Add the failing spec**

In `walk_spec.lua`, inside the `describe`:

```lua
    for _, mode in ipairs({ "colors", "shapes", "both" }) do
        describe(mode .. " mode", function()
            it("paints all 7 tiles in their colour or shape", function()
                assert.equals("question", results[mode].question_state)
                assert.is_true(results[mode].tiles_painted)
            end)

            it("names the tapped tile whatever the target was", function()
                assert.equals("answer", results[mode].answer_state)
                assert.is_true(results[mode].answer_painted)
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

    it("fits every question and answer inside the margins", function()
        assert.is_true(results.widest_question <= 1224)
        assert.is_true(results.widest_answer <= 1224)
    end)
```

In `walk`, before `finish()`:

```lua
    local GameScreen = require("screen")
    local Game = require("game")
    results.widest_question, results.widest_answer = 0, 0
    local function measure(tile)
        results.widest_question = math.max(results.widest_question, GameScreen.question_width(tile))
        results.widest_answer = math.max(results.widest_answer, GameScreen.answer_width(tile))
    end
    for _, color in ipairs(Game.COLORS) do
        measure({ color = color })
        for _, shape in ipairs(Game.SHAPES) do
            measure({ color = color, shape = shape })
        end
    end
    for _, shape in ipairs(Game.SHAPES) do
        measure({ shape = shape })
    end
```

**Step 3: Run it**

Run: `bin/check spec/emulator/walk_spec.lua`
Expected: FAIL. `tap` reaches `InputContainer:onGesture`, so `game.round` is nil and `results.error` names it.

**Step 4: Implement**

In `screen.lua`, add `local Game = require("game")` and `local Shapes = require("shapes")` to the requires. Add the constants:

```lua
local TOP = 28
local TILE_BORDER = 4
local TILE_SHAPE = 290
local QUESTION_FACE = 34
local ANSWER_FACE = 57
local COLOR_ANSWER_FACE = 71
local COLOR_ANSWER_LINE = 170
local ANSWER_LINE = 132
local ANSWER_SHAPE = { 1200, 1150 }
local ANSWER_SHAPE_GAP = { 80, 40 }
```

Add above `GameScreen.open`:

```lua
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
```

Add below `paint_start`:

```lua
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
    end
end

function GameScreen:onGesture(ev)
    self:guarded(self.handle, ev)
    return true
end
```

In `paint`, replace the `if` block with:

```lua
    if self.state == "start" then
        self:paint_start(bb)
    elseif self.state == "question" then
        self:paint_question(bb)
    else
        self:paint_answer(bb)
    end
```

**Step 5: Run it**

Run: `bin/check spec/emulator/walk_spec.lua`
Expected: PASS. Open the six PNGs in `spec/.artifacts/` and compare them with the mocks.

Run: `bin/check --unit`. Expected: lint clean, all pass.

**Step 6: Commit (ask first)**

Files: `screen.lua`, `spec/emulator/patches/2-walk.lua`, `spec/emulator/walk_spec.lua`. Message: `Add the question and answer screens`.

---

### Task 7: Slow presses and missed taps

About 15 minutes.

**Files:**
- Modify: `toddler-colors-game.koplugin/screen.lua`, `spec/emulator/patches/2-walk.lua`, `spec/emulator/walk_spec.lua`

**Step 1: Write the failing test**

In `2-walk.lua`, in `walk`, right after `results.start = ...`:

```lua
    tap(game.buttons[1])
    local t0 = time.now()
    results.taps = {}
    gesture("tap", 632, 300)
    UIManager:forceRePaint()
    results.taps.gap = game.state
    gesture("tap", 100, 1500)
    UIManager:forceRePaint()
    results.taps.beside_seventh = game.state
    gesture("tap", 300, 60)
    UIManager:forceRePaint()
    results.taps.header = game.state
    gesture("hold", 300, 300, t0)
    gesture("hold_release", 300, 300, t0 + time.s(1))
    UIManager:forceRePaint()
    results.taps.slow_press = game.state
    gesture("hold", 300, 300, t0)
    gesture("hold_release", 300, 300, t0 + time.s(1))
    UIManager:forceRePaint()
    results.taps.slow_press_on_answer = game.state
    game.state = "start"
```

In `walk_spec.lua`:

```lua
    it("does nothing for a tap outside every tile", function()
        assert.equals("question", results.taps.gap)
        assert.equals("question", results.taps.beside_seventh)
        assert.equals("question", results.taps.header)
    end)

    it("counts a slow press as a tap when the finger lifts", function()
        assert.equals("answer", results.taps.slow_press)
        assert.equals("question", results.taps.slow_press_on_answer)
    end)
```

**Step 2: Run it**

Run: `bin/check spec/emulator/walk_spec.lua`
Expected: FAIL, `results.taps.slow_press` is `question`.

**Step 3: Implement**

Replace `GameScreen:handle`:

```lua
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
```

**Step 4: Run it**

Run: `bin/check spec/emulator/walk_spec.lua`. Expected: PASS.

Run: `bin/check --unit`. Expected: lint clean, all pass.

**Step 5: Commit (ask first)**

Files: `screen.lua`, `spec/emulator/patches/2-walk.lua`, `spec/emulator/walk_spec.lua`. Message: `Count a slow press as a tap`.

---

### Task 8: Corner hold exit

About 20 minutes.

**Files:**
- Modify: `toddler-colors-game.koplugin/screen.lua`, `spec/emulator/patches/2-walk.lua`, `spec/emulator/walk_spec.lua`

**Step 1: Write the failing test**

In `2-walk.lua`, add above `walk`:

```lua
-- Holds a point from at to at + gap, in the same units as the gesture timestamps.
local function hold(x, y, at, gap)
    gesture("hold", x, y, at)
    gesture("hold_release", x, y, at + gap)
    UIManager:forceRePaint()
end
```

In `walk`, replace each of the `game.state = "start"` lines (the one at the end of the Task 7 block and the three after `play`) with:

```lua
    hold(50, 50, time.now(), time.s(3))
```

Add before the `widest_question` block:

```lua
    results.exit = {}
    tap(game.buttons[1])
    local t1 = time.now()
    hold(50, 50, t1, time.s(2.9))
    results.exit.at_2_9 = game.state
    hold(50, 50, t1, time.s(3))
    results.exit.at_3_0 = game.state
    tap(game.buttons[1])
    hold(700, 50, t1, time.s(3))
    results.exit.outside_corner = game.state
    gesture("hold_release", 50, 50, t1 + time.s(3))
    UIManager:forceRePaint()
    results.exit.release_without_hold = game.state
    hold(50, 50, t1, time.s(3))
    hold(50, 50, t1, time.s(3))
    results.exit.on_start = game.state
```

In `walk_spec.lua`:

```lua
    describe("the corner hold", function()
        it("does not exit at 2.9 s", function()
            assert.equals("question", results.exit.at_2_9)
        end)

        it("returns to the start screen at 3.0 s", function()
            assert.equals("start", results.exit.at_3_0)
        end)

        it("does not exit from elsewhere on the screen", function()
            assert.equals("question", results.exit.outside_corner)
        end)

        it("ignores a release with no hold before it", function()
            assert.equals("question", results.exit.release_without_hold)
        end)

        it("does nothing on the start screen", function()
            assert.equals("start", results.exit.on_start)
        end)
    end)
```

**Step 2: Run it**

Run: `bin/check spec/emulator/walk_spec.lua`
Expected: FAIL. The hold at 3.0 s stays on `question`, so `tap(game.buttons[...])` lands on a question screen and the mode specs break too.

**Step 3: Implement**

Add `local time = require("ui/time")` to the requires, and these constants:

```lua
local EXIT_HOLD_S = 3
local CORNER = 200
```

Replace the `hold_release` branch of `GameScreen:handle`:

```lua
    elseif ev.ges == "hold_release" and self.hold then
        local hold = self.hold
        self.hold = nil
        if self:is_exit(hold, ev) then
            self:go("start")
        else
            self:press(ev.pos)
        end
    end
```

Add above `handle`:

```lua
function GameScreen:is_exit(hold, release)
    return self.state ~= "start" and hold.pos.x < CORNER and hold.pos.y < CORNER
        and release.time - hold.time >= time.s(EXIT_HOLD_S)
end
```

**Step 4: Run it**

Run: `bin/check spec/emulator/walk_spec.lua`. Expected: PASS.

Run: `bin/check --unit`. Expected: lint clean, all pass.

**Step 5: Commit (ask first)**

Files: `screen.lua`, `spec/emulator/patches/2-walk.lua`, `spec/emulator/walk_spec.lua`. Message: `Exit to the start screen on a 3-second corner hold`.

---

### Task 9: No gesture reaches KOReader

About 20 minutes. `onGesture` already returns true, so this test should pass once written. The positive control is what proves the test can fail: run it with the `return true` removed.

**Files:**
- Modify: `spec/emulator/patches/2-walk.lua`, `spec/emulator/walk_spec.lua`

**Step 1: Write the test**

In `2-walk.lua`, add above `walk`:

```lua
local LEAK_GESTURES = {
    "tap", "double_tap", "two_finger_tap", "touch", "swipe", "two_finger_swipe", "multiswipe", "pan", "pan_release",
    "two_finger_pan", "hold", "hold_pan", "hold_release", "two_finger_hold", "two_finger_hold_release", "pinch",
    "spread", "inward_pan", "outward_pan", "rotate",
}

local function stack_size()
    local count = 0
    for _ in UIManager:topdown_widgets_iter() do
        count = count + 1
    end
    return count
end

local function send_all(x, y)
    for _, ges in ipairs(LEAK_GESTURES) do
        gesture(ges, x, y, nil, {
            direction = "south", multiswipe_directions = "south", distance = 300, span = 300, angle = 90,
        })
    end
end
```

At the start of `walk`, before `open_game()`:

```lua
    local before = stack_size()
    gesture("tap", 632, 20)
    results.leak = { control_opened_menu = stack_size() > before }
    UIManager:close(UIManager:getNthTopWidget(1))
```

Before the `widest_question` block, with the game on the start screen:

```lua
    local depth = stack_size()
    send_all(632, 20)
    send_all(10, 1670)
    results.leak.start_kept = stack_size() == depth and UIManager:getNthTopWidget(1) == game
    tap(game.buttons[1])
    send_all(632, 20)
    send_all(10, 1670)
    results.leak.game_kept = stack_size() == depth and UIManager:getNthTopWidget(1) == game
    hold(50, 50, time.now(), time.s(3))
```

`send_all` includes `hold` and `hold_release` with a current timestamp, so the gap is far under 3 s and it can't exit. Its `tap` can change the state, which is fine: this test only reads the stack.

In `walk_spec.lua`:

```lua
    describe("gestures", function()
        it("open KOReader's menu when the game isn't showing, so this test can fail", function()
            assert.is_true(results.leak.control_opened_menu)
        end)

        it("stay in the game on the start screen", function()
            assert.is_true(results.leak.start_kept)
        end)

        it("stay in the game on the question screen", function()
            assert.is_true(results.leak.game_kept)
        end)
    end)
```

**Step 2: Prove the test can fail**

Temporarily change `GameScreen:onGesture` to end with `return false`.

Run: `bin/check spec/emulator/walk_spec.lua`
Expected: FAIL on `start_kept` or `game_kept`. If it passes, the positive control isn't reaching KOReader's menu: stop and report.

Restore `return true`.

**Step 3: Run it**

Run: `bin/check spec/emulator/walk_spec.lua`. Expected: PASS.

Run: `bin/check --unit`. Expected: lint clean, all pass.

**Step 4: Commit (ask first)**

Files: `spec/emulator/patches/2-walk.lua`, `spec/emulator/walk_spec.lua`. Message: `Test that no gesture leaks to KOReader`.

---

### Task 10: Portrait while running

About 20 minutes.

**Files:**
- Modify: `toddler-colors-game.koplugin/screen.lua`, `spec/emulator/patches/2-walk.lua`, `spec/emulator/walk_spec.lua`

**Step 1: Write the failing test**

In `2-walk.lua`, in `walk`, before `finish()`, with the game on the start screen:

```lua
    tap(game.buttons[4])
    results.exit_button = { closed = not UIManager:isWidgetShown(game) }

    UIManager:broadcastEvent(Event:new("SetRotationMode", Screen.DEVICE_ROTATED_CLOCKWISE))
    local landscape = open_game()
    UIManager:forceRePaint()
    results.rotation = { during = Screen:getRotationMode(), width = Screen:getWidth() }
    gesture("tap", landscape.buttons[4].x + 10, landscape.buttons[4].y + 10)
    UIManager:forceRePaint()
    results.rotation.after = Screen:getRotationMode()
    UIManager:broadcastEvent(Event:new("SetRotationMode", Screen.DEVICE_ROTATED_UPRIGHT))
```

In `walk_spec.lua`:

```lua
    it("closes from the start screen's Exit button", function()
        assert.is_true(results.exit_button.closed)
    end)

    it("runs in portrait and puts the old rotation back", function()
        assert.equals(0, results.rotation.during)
        assert.equals(1264, results.rotation.width)
        assert.equals(1, results.rotation.after)
    end)
```

`DEVICE_ROTATED_UPRIGHT` is 0 and `DEVICE_ROTATED_CLOCKWISE` is 1 (`base/ffi/framebuffer.lua:78-79`).

**Step 2: Run it**

Run: `bin/check spec/emulator/walk_spec.lua`
Expected: FAIL, `results.rotation.during` is 1.

If the broadcast itself doesn't rotate the emulator (`Screen:getRotationMode()` stays 0 right after it), the assumption is wrong. Stop and report it.

**Step 3: Implement**

Add `local Event = require("ui/event")` to the requires. Add above `GameScreen.open`:

```lua
local function rotate_to(mode)
    if Screen:getRotationMode() ~= mode then
        UIManager:broadcastEvent(Event:new("SetRotationMode", mode))
    end
end
```

Replace `GameScreen.open`:

```lua
function GameScreen.open(random)
    local rotation = Screen:getRotationMode()
    rotate_to(Screen.DEVICE_ROTATED_UPRIGHT)
    local widget = GameScreen:new{ random = random, rotation = rotation }
    UIManager:show(widget, "full")
    return widget
end
```

In `GameScreen:shutdown`, after `UIManager:close(self, "full")`:

```lua
    rotate_to(self.rotation)
```

**Step 4: Run it**

Run: `bin/check spec/emulator/walk_spec.lua`. Expected: PASS.

Run: `bin/check --unit`. Expected: lint clean, all pass.

**Step 5: Commit (ask first)**

Files: `screen.lua`, `spec/emulator/patches/2-walk.lua`, `spec/emulator/walk_spec.lua`. Message: `Run in portrait and restore the rotation on exit`.

---

### Task 11: A failure never strands the device

About 20 minutes. `guarded` already exists from Task 5, so these tests should pass once written. Remove the `nextTick` shutdown to see them fail.

**Files:**
- Modify: `spec/emulator/patches/2-walk.lua`, `spec/emulator/walk_spec.lua`

**Step 1: Write the test**

In `2-walk.lua`, in `walk`, replace the final `finish()` with:

```lua
    local Shapes = require("shapes")
    local render = Shapes.render
    local painting = open_game()
    Shapes.render = function()
        error("walk: render failed")
    end
    tap(painting.buttons[2])
    Shapes.render = render
    UIManager:nextTick(function()
        results.failure = { paint_closed = not UIManager:isWidgetShown(painting) }
        local round = Game.round
        local tapping = open_game()
        Game.round = function()
            error("walk: round failed")
        end
        tap(tapping.buttons[1])
        Game.round = round
        UIManager:nextTick(function()
            results.failure.gesture_closed = not UIManager:isWidgetShown(tapping)
            results.failure.file_browser_on_top =
                UIManager:getNthTopWidget(1) == require("apps/filemanager/filemanager").instance
            finish()
        end)
    end)
```

In `walk_spec.lua`:

```lua
    describe("on an error", function()
        it("closes when a paint fails", function()
            assert.is_true(results.failure.paint_closed)
        end)

        it("closes when a gesture handler fails", function()
            assert.is_true(results.failure.gesture_closed)
        end)

        it("leaves KOReader's file browser on top", function()
            assert.is_true(results.failure.file_browser_on_top)
        end)
    end)
```

**Step 2: Prove the test can fail**

Temporarily remove the `UIManager:nextTick` block from `GameScreen:guarded`, leaving only the `logger.warn`.

Run: `bin/check spec/emulator/walk_spec.lua`
Expected: FAIL on all three.

Restore the block.

**Step 3: Run it**

Run: `bin/check spec/emulator/walk_spec.lua`. Expected: PASS.

Run: `bin/check --unit`. Expected: lint clean, all pass.

**Step 4: Commit (ask first)**

Files: `spec/emulator/patches/2-walk.lua`, `spec/emulator/walk_spec.lua`. Message: `Test that a failure closes the game`.

---

### Task 12: Full gate, owner review, device check

About 30 minutes of agent time, then the owner's time on the Kindle.

**Step 1: Run the full gate**

Run: `bin/check`
Expected: lint, unit and emulator all pass.

**Step 2: Self-review**

- Check every Task against the design doc's "What he sees" table and `AGENTS.md`'s Principles.
- Confirm no file passes 500 lines. `screen.lua` should be about 330.
- Confirm the module comments carry no design-doc citations and that their `file:line` citations are accurate.

**Step 3: Owner review of the PNGs**

Present the 7 PNGs in `spec/.artifacts/` with their absolute paths: `start`, then `-question` and `-answer` for `colors`, `shapes` and `both`. Any colour or spacing change the owner asks for is the lead's to make, per `AGENTS.md`.

**Step 4: Owner's device check**

The owner copies the whole `toddler-colors-game.koplugin/` folder into `koreader/plugins/` in one OpenMTP session from the stock home screen, then checks:

1. The menu shows Tools › Toddler Colors Game, and opening it from both the file browser and a book works.
2. Pink vs red and blue vs purple are easy to tell apart.
3. The screen has no ghosting between screens, and one-refresh flashing is acceptable.
4. Holding the "Hold to exit" bar for 3 s returns to the start screen with the finger still down, a tap on it does nothing, and Exit closes the game.
5. A resting palm on the bar goes to the start screen, taps still register with a hand resting, and the exit works with your normal grip, because a thumb resting anywhere on the glass cancels it.
6. The screen stays in portrait when the Kindle is turned, which confirms the SE has no G-sensor rotation.
7. With a palm resting on the screen, taps still register, and a press that smears across a tile isn't a dead tap. A smear past about 5.5 mm is a swipe, which the game ignores (`frontend/device/gesturedetector.lua:119`).
8. A short press of the power button, then wake, returns to the same screen. A long press shows nothing from the Kindle OS over the game, and neither does a swipe down from the top edge.
9. Night mode is off: `paintRectRGB32` honours inversion, so blue would show orange.
10. A double stab doesn't skip the answer screen during a full refresh.
11. `ls koreader/plugins/*/{game,screen,shapes}.lua` finds no other plugin with those module names; a same-named module loaded earlier wins `require`.
12. One round with him.

Any failure there is a new bug, handled as a failing test first where the emulator can show it.

**Step 5: Update the docs (ask first)**

In `AGENTS.md`, change "**Status:** design approved 2026-11-05, not yet implemented." to say the plugin is implemented, and remove "`bin/check` arrives with the first implementation task."

Message: `Mark the plugin implemented`.
