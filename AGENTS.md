# Toddler Colors Game

A KOReader plugin for the owner's Kindle Colorsoft: a colours-and-shapes game for their 18-month-old son. A question sits at the top ("Which one is blue?") over 7 big tiles; any tap names what was tapped, and the next tap asks a new question. There are three modes (Colors, Shapes, Both) and no sound, so the parent reads the question aloud. The repo is the owner's own; the plugin is unsupported for anyone else.

- **Stack:** Lua on KOReader's LuaJIT, KOReader's widget API (`toddler-colors-game.koplugin/`). No dependencies, no storage.
- **Deployed:** copied by hand into the Kindle's `koreader/plugins/` with OpenMTP. No releases, no update check.
- **Status:** design approved 2026-11-05, not yet implemented. Read `docs/plans/2026-11-05-toddler-colors-game-design.md` for the decisions and why each won. `bin/check` arrives with the first implementation task.

## Principles

- **No wrong answers.** Every tap moves the game forward. Don't add scoring, "try again", or anything that marks a tap wrong.
- **Toddler-proof.** The game's full-screen widget consumes every gesture (tap, hold, swipe, pan, pinch) so none reach KOReader underneath. The only way out is holding the top-left corner for 3 seconds; the start screen's Exit button then closes the game. Portrait is locked while it runs.
- **No settings.** The mode is picked on the start screen each time. A settings key enters only when the owner has wanted to change that thing on the real device.
- **E-ink rules.** The screen redraws only on input. No background timers, no animations. Each screen change is one full refresh so the previous colour doesn't ghost.
- **A failure never strands the device.** Every entry point from KOReader is wrapped in `pcall`; on an error the game closes and KOReader's file browser is usable again.

## Emulator, devices and references

- The KOReader emulator lives at `~/Projects/kodev/` (build `e1fe1ac`, 2026-10-08). Never vendor KOReader here. Rebuild is `./kodev build` in `~/Projects/kodev/koreader/` (~7 min). KOReader is pinned to that build; upgrading it is a deliberate chore that reruns the emulator specs.
- Headless capture: `~/Projects/kodev/capture.sh <out.png> [library] [delay]`, 1264×1680 in ~10 s. Screen env vars, `KO_HOME` profiles, the Retina window quirk and the fonts path are in `~/Projects/kodev/HANDOFF.md` §3. Don't rediscover them.
- A plugin folder present in both the emulator's `plugins/` and `<KO_HOME>/plugins/` loads twice. Tests copy the plugin into a scratch profile, so the emulator's own `plugins/` must not hold `toddler-colors-game.koplugin`.
- Primary device: Kindle Colorsoft SE, 1264×1680 @ 300 DPI; the colour layer is 150 PPI. KOReader 2026.07.1 via KPM. USB is MTP-only and single-session: the Kindle shows only from the stock home screen (exit KOReader first) and drops off after every session, so copy the whole plugin folder in one OpenMTP session.
- KoPanda (`~/Projects/elatedpanda/kopanda`) is the working reference for a KOReader plugin with unit and emulator specs (`bin/check`, `spec/helper.lua`, `spec/plugin_harness.lua`). Read it for patterns; copy pieces in rather than requiring across repos. KOReader is AGPL-3.0.

## Commands

- `bin/check`: the full gate. luacheck, then every `spec/unit/*_spec.lua`, then every `spec/emulator/*_spec.lua`, on the emulator's LuaJIT and Busted under a fresh `KO_HOME`; stops at the first failing stage.
- `bin/check --unit`: luacheck and the unit specs, stopping before `spec/emulator/` (the gate for every task).
- `bin/check <spec>...`: exactly those spec files in one Busted process, no luacheck.

`bin/check` needs `luacheck` on `PATH` (`brew install luacheck`) and the emulator at `TODDLER_COLORS_EMULATOR` (see `.env.example`); it refuses with exit 2 otherwise. There is no system `busted`: the rocks ship inside the emulator's `spec/rocks/`.

## Conventions and gotchas

- Lua: KOReader's style (4-space indent, `local` everything, modules return a table).
- Require every module in `main.lua` at load time. KOReader prepends the plugin root to `package.path` only while it loads `main.lua` (`frontend/pluginloader.lua:242`, `:269-270`), so a later `require("game")` can resolve to another plugin's same-named file.
- `game.lua` holds the rules (mode, target never the previous one, tile shuffle, Both-mode pairing with no repeated colour or shape) and never draws. Randomness is passed in, so specs fix the sequence.
- Shapes are SVG templates rendered from a string with the fill colour written in (`RenderImage:renderSVGImageDataWithCRengine`, `frontend/ui/renderimage.lua:104`). The first task checks in the emulator that this render keeps colour; if it doesn't, shapes are scanline spans drawn with `paintRectRGB32`, and the design doc records which path won.
- `paintRect` draws luminance only (`base/ffi/blitbuffer.lua:1704`); colour goes through `paintRectRGB32` (`:1827`).
- The exit hold is the gap between the `hold` and `hold_release` timestamps, never a timer.
- Out of scope, don't re-suggest: sound, scoring or progress tracking, more modes, settings, KoPanda integration, a release pipeline.

## Testing

- TDD, no exceptions: write the failing test first, run it, implement, run again. Every behaviour change ships with a test. A change to a colour value or a layout number alone needs no new test; the owner judges those by eye on the emulator.
- Two layers: Busted unit specs on KOReader's LuaJIT under a fresh `KO_HOME` for the pure parts (`game.lua`, the SVG templating); emulator capture specs at 1264×1680 for what only a running KOReader shows: that each screen renders in each mode, that gestures don't leak to KOReader, and that the corner hold exits.
- Test the edges where behaviour changes (a hold of 2.9 s and 3.0 s), not every value in a range.
- No real waits: a duration in a test is passed in at test size; production values stay.
- No goldens: no capture is compared against a committed image. A capture spec may sample a pixel (a tile's colour) or compare two captures from the same run. The owner reviews the PNGs before anything goes on the Kindle.

<!-- shared-workflow-start -->
## Working with agents

### Before changing anything
- For a feature, ask clarifying questions, then present a plan and get approval before writing code; a bug fix or tweak proceeds straight to the failing test. Never assume requirements or make architectural decisions without explicit consent.
- Offer 2–3 approaches with trade-offs when a real decision is needed. Break large tasks into small, reviewable steps.
- Ask one question at a time; related questions that decide the same plan may be batched. Do the homework first: read the relevant code and docs, check how similar things are done here, then ask the one thing only the user can decide.

### While working
- Make the minimal change that accomplishes the task. Don't refactor unrelated code; mention issues you notice outside scope instead of fixing them.
- Stop and ask when something unexpected comes up: an edge case the plan didn't cover, a conflicting pattern, a missing dependency, a security concern, or any ambiguity. Don't decide silently to keep moving.
- No TODO comments — do it or ask. No commented-out example code.

### Code
- YAGNI, especially before adding a dependency or an abstraction. Prefer the simple solution; simple doesn't equal clever.
- Comments say what the code can't. A module opens with one to three sentences: what it is, and which KOReader internals it reads or patches, each with its `file:line`. A function gets a comment only when its name and signature don't say what it does: one sentence, what and why, never how. Never cite design docs in code: the spec is the record of why, the commit message is the record of what lost, the code is the record of what is. No comment restates the line under it.
- Write idiomatic code for the language at hand; don't invent patterns or conventions the ecosystem doesn't use.
- Tests must prove correctness — no tests that merely mirror the implementation.
- Don't use deprecated or undocumented APIs.
- A file passing 500 lines is a signal to plan decomposition; at 1000, do it.

### Subagents
- Run agents that write, review or fix plugin code on Opus; smaller tasks (read-only surveys, doc edits, mechanical changes) on Sonnet. An agent never spawns subagents of its own; the lead does all spawning. Run subagents in parallel whenever the dependency order allows. Brief an agent with the full task text, the verified facts and a short checklist, and tell it to read `bin/check` output through a filter that drops KOReader's library-loading chatter, so its transcript stays small.
- One agent, one job, one transcript. A fix round is a fresh agent briefed with the review's findings, the task plan and the diff, never a resume of the builder; a re-check is a fresh agent briefed with the review report and the fix diff, never a resume of the reviewer.
- One reviewer per task, covering spec compliance and code quality in one brief. A change under about 150 changed lines is built, tested and self-reviewed by one agent, with no separate reviewer.
- An owner-directed visual adjustment (a colour or a spacing the owner asked for) is the lead's to make, not a subagent's: it runs the affected capture specs, looks at the screens on the emulator, then runs `bin/check`.
- A reviewer's report ends with a numbered fix list the lead can paste into the fixer's brief: file:line, what's wrong, the fix, the test that proves it. The fixer writes each test first and reports it failing before the fix.

### Before committing
- Self-review every change against the plan: unintended side effects, missing tests, missing docs.
- Present a summary of the changes and a proposed commit message, then ask: "Ready to commit and push?" Never commit without approval.
- `git add <specific files>`, never `git add -A`.
- Work on `main`. Never force-push. Never include AI attribution (Claude, Anthropic, Co-Authored-By) in commits.
<!-- shared-workflow-end -->

## Project additions

- Specs and plans: every concrete claim about code outside this repo (a KOReader file, function, key, default or format) cites the `file:line` it was read from, at the pinned emulator build. An uncheckable claim is marked as an assumption, and the task that depends on it verifies it first.
