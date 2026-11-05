# Toddler Colors Game — Design

Date: 2026-11-05. Status: approved, not yet implemented.

## Purpose

A game on the owner's Kindle Colorsoft for their 18-month-old son, to learn colours and shapes. The Kindle has no audio in KOReader, so the parent reads the question aloud; the screen carries the text and the pictures.

## What he sees

**Start screen (for the parent).** Three big buttons, **Colors**, **Shapes**, **Both**, and a small **Exit** that returns to KOReader.

**Question screen.** A question at the top in large text (about 120 px) and 7 big tiles below in a 2-column grid (about 600×380 px each).

| Mode | Tiles | Question | Answer screen |
|---|---|---|---|
| Colors | 7 solid colours: red, orange, yellow, green, blue, purple, pink | "Which one is **blue**?" | Whole screen in the tapped colour, "That's green!" |
| Shapes | 7 black shapes: circle, square, triangle, star, heart, diamond, moon | "Which one is the **star**?" | The tapped shape filling the screen, "That's a heart!" |
| Both | 7 tiles, each a different shape in a different colour | "Which one is the **blue circle**?" | "That's a green star!" |

Shapes mode draws in black so colour doesn't compete with shape.

**Answer screen.** Any tile tap names what he tapped. There is no right or wrong: at 18 months the goal is naming things together, and a "wrong" signal would only frustrate. Any tap on the answer screen asks a new question with the tiles shuffled; the same target is never asked twice in a row.

**Exit.** Holding the top-left corner for 3 seconds returns to the start screen. No other gesture leaves the game.

### Why these choices

- *7 tiles, not 2–4:* the owner's call. At 1264×1680 a 2×4 grid still gives toddler-sized targets.
- *Any tap names it (exploring), then a new question:* every tap moves the game forward, so he never gets stuck on a question he can't answer yet.
- *3-second corner hold:* hard for a toddler to trigger by accident, quick for a parent. Two-finger long press was rejected (a palm can trigger it); power-button-only was rejected (relaunching every time).

## How it's built

A standalone KOReader plugin, `toddler-colors-game.koplugin/`, separate from KoPanda (owner's request).

1. `main.lua` adds **Tools › Toddler Colors Game** to KOReader's menu.
2. `game.lua` holds the rules: mode, target choice (never the previous one), tile shuffle, the Both-mode pairing (no colour or shape repeats in a grid). Pure Lua, no drawing.
3. `shapes.lua` renders each shape from an SVG template with the fill colour written into the text, through `RenderImage:renderSVGImageDataWithCRengine` (`frontend/ui/renderimage.lua:104`).
4. `screen.lua` is one full-screen widget over KOReader with three states: start, question, answer.

**Why SVG.** It renders anti-aliased (smooth curves on heart, moon and star), allows friendlier artwork (rounded star, outlines), and new artwork later is new files, not new drawing code. **Fallback:** if the emulator shows that render dropping colour, shapes are drawn as scanline spans with `paintRectRGB32`. On the Colorsoft the colour layer is 150 PPI, which hides most aliasing, so the fallback looks close. The colour test runs first because it decides which path is built.

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
