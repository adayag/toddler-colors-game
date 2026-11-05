# Toddler Colors Game — Design

Date: 2026-11-05. Status: approved, built and passing on the emulator; the check on the real Kindle is still to come.

## Purpose

A game on the owner's Kindle Colorsoft for their 18-month-old son, to learn colours and shapes. The Kindle has no audio in KOReader, so the parent reads the question aloud; the screen carries the text and the pictures.

## What he sees

**Start screen (for the parent).** Three big buttons, **Colors**, **Shapes**, **Both**, and a small **Exit** that returns to KOReader.

**Question screen.** A one-line question at the top (72 px) and 7 big tiles below in a 2-column grid (600×364 px each), with the seventh tile centred on the last row.

| Mode | Tiles | Question | Answer screen |
|---|---|---|---|
| Colors | 7 solid colours: red, orange, yellow, green, blue, purple, pink | "Which one is **blue**?" | Whole screen in the tapped colour, "That's green!" |
| Shapes | 7 black shapes: circle, square, triangle, star, heart, diamond, moon | "Which one is the **star**?" | The tapped shape filling the screen, "That's a heart!" |
| Both | 7 tiles, each a different shape in a different colour | "Which one is the **blue circle**?" | "That's a green star!" |

Shapes mode draws in black so colour doesn't compete with shape.

**Answer screen.** Any tile tap names what he tapped. There is no right or wrong: at 18 months the goal is naming things together, and a "wrong" signal would only frustrate. Any tap on the answer screen asks a new question with the tiles shuffled; the same target is never asked twice in a row.

**Tap rules.** A slow press counts as a tap when the finger lifts, because a toddler's press often outlasts KOReader's 0.5 s hold threshold. A tap outside every tile on the question screen does nothing. A tap beside a resting finger counts too: KOReader reports it as a two-finger tap, and the game presses at the midpoint of the two contacts.

**Exit.** Holding the top-left corner for 3 seconds returns to the start screen. No other gesture leaves the game.

### Why these choices

- *7 tiles, not 2–4:* the owner's call. At 1264×1680 a 2×4 grid still gives toddler-sized targets.
- *One-line 72 px question, not 120 px:* 120 px text and 380 px rows don't fit in 1680 px. The parent reads the question aloud, so the height goes to the tiles. The longest question ("Which one is the orange diamond?") measures about 1202 px at 72 px against 1224 px available, from the advance widths in `koreader/resources/fonts/noto/NotoSans-Regular.ttf` and `NotoSans-Bold.ttf`, kerning not counted.
- *Seventh tile centred, not wide:* a wide tile would be the biggest target, and which colour or shape gets it would change with every shuffle.
- *Any tap names it (exploring), then a new question:* every tile tap moves the game forward, so he never gets stuck on a question he can't answer yet.
- *3-second corner hold:* hard for a toddler to trigger by accident, quick for a parent. Two-finger long press was rejected (a palm can trigger it); power-button-only was rejected (relaunching every time).

## How it's built

A standalone KOReader plugin, `toddler-colors-game.koplugin/`, separate from KoPanda (owner's request).

1. `main.lua` adds **Tools › Toddler Colors Game** to KOReader's menu.
2. `game.lua` holds the rules: mode, target choice (never the previous one), tile shuffle, the Both-mode pairing (no colour or shape repeats in a grid). Pure Lua, no drawing.
3. `shapes.lua` renders each shape from an SVG template with the fill colour written into the text, through `RenderImage:renderSVGImageDataWithCRengine` (`frontend/ui/renderimage.lua:104`).
4. `screen.lua` is one full-screen widget over KOReader with three states: start, question, answer.

**Why SVG.** It renders anti-aliased (smooth curves on heart, moon and star), allows friendlier artwork (rounded star, outlines), and new artwork later is a new template string, not new drawing code. **Colour test result:** the render keeps colour exactly, so the scanline fallback was not built. It needs `width` and `height` on the `<svg>`, and it returns an opaque buffer on white, so a shape always sits on a white background.

**Toddler-proofing.** The widget consumes every gesture so none reach KOReader (no swipe-down menu, no corner actions). The exit hold is measured from the `hold` and `hold_release` timestamps, so no background timer runs. Portrait is locked while the game runs.

**E-ink.** One full refresh per screen change so the previous colour doesn't ghost. No animation.

## Testing

1. **SVG colour test first**, in the emulator (~15 min): render one coloured SVG and check the pixels are colour.
2. **Unit specs for `game.lua`** (busted from the emulator): no target twice in a row, 7 distinct tiles, Both mode has no repeated colour or shape.
3. **Emulator captures** at 1264×1680 of start, question and answer in each mode. The owner reviews the PNGs before anything goes on the Kindle.
4. **On the Kindle:** pink vs red and blue vs purple are distinguishable; the 3-second corner hold exits and nothing else does; one round with him.

## Delivery

Copy the plugin folder into `koreader/plugins/` with OpenMTP, in one session from the stock home screen. Updates will be rare, so no release pipeline. A GitHub-release update check (like KoPanda's, about 2 more hours) is only worth it if more modes keep coming.

## Out of scope

Sound, scoring, progress tracking, more than three modes, KoPanda integration.
