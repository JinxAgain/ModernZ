# IntroDB Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Integrate IntroDB crowdsourced segment skipping and seekbar highlighting into ModernZ mpv user script with a floating 7-second auto-fading skip capsule button, multi-source metadata resolution, and zero impact on existing UI layouts.

**Architecture:** Extend `modernz.lua` with an IntroDB state engine; observe `user-data/metadata/imdb_id` (and fallbacks like regex, .nfo, guessit + Cinemeta/IMDb API); asynchronously query `https://api.introdb.app/segments`; render colored ranges on seekbar respecting gap nibbles; render a floating ASS pill button during active segments; support auto-skip and hotkey skipping.

**Tech Stack:** Lua 5.1 / mpv Lua API, ASS vector drawing, curl, guessit, Cinemeta / IMDb Suggestion APIs.

**Spec:** `docs/superpowers/specs/2026-10-07-introdb-integration-design.md`

## Global Constraints

- Lua scripts and code comments must be written in English.
- Must preserve all existing ModernZ layouts (`default`, `compact`, `mini`, `seekbar`) without shifting existing buttons or controls.
- Asynchronous operations (curl, guessit) must never block mpv's main event thread.
- Switching files or closing mpv must reset IntroDB state cleanly with no stale segment leakage across videos.
- Follow Git conventional commit style; do not commit automatically.

## Review Focus

1. **Network failure / offline mode**: Curl error or timeout must not throw Lua runtime exceptions or freeze playback; state degrades silently to no segments.
2. **Missing or malformed metadata**: Videos without recognizable IMDb IDs (home videos, unusual titles) must gracefully abort without crashing.
3. **Seekbar gap style compatibility**: When `nibbles_style = "gap"`, segment highlights must cut cleanly around chapter gaps without drawing glitches.
4. **Window resizing / resolution changes**: Floating capsule button and seekbar highlights must scale correctly without clipping offscreen.
5. **Rapid file switching / seeking**: Seeking across multiple segments or quickly switching playlist items must cancel or supersede previous pending requests.

---

### Task 1: Add User Options and Localization Strings

**Files:**
- Modify: `modernz.conf:440-448`
- Modify: `modernz.lua:200-310`, `modernz.lua:392-430`
- Test: `tests/test_options.lua`

**Interfaces:**
- Produces: `user_opts.introdb_enable`, `user_opts.introdb_api_url`, `user_opts.introdb_auto_skip`, `user_opts.introdb_button_duration`, `user_opts.introdb_show_highlights`, `user_opts.introdb_range_alpha`, `user_opts.introdb_intro_color`, `user_opts.introdb_recap_color`, `user_opts.introdb_outro_color`, `user_opts.introdb_post_credits_color`, `user_opts.introdb_guessit_fallback`.
- Produces: `locale.skip_intro`, `locale.skip_recap`, `locale.skip_outro`, `locale.skip_post_credits`, `locale.skipped_segment`.

- [ ] **Step 1: Write verification test for options and localization**

Create `tests/test_options.lua` testing that `user_opts` contains all IntroDB configuration keys with correct defaults and that `language["default"]` and `language["zh"]` (if present) contain required string keys.

- [ ] **Step 2: Run test to verify it fails**

Run: `mpv --load-scripts=no --script=tests/test_options.lua --idle=once`
Expected: FAIL indicating missing configuration keys.

- [ ] **Step 3: Implement options in `modernz.lua` and `modernz.conf`**

Add IntroDB options block into `user_opts` table in `modernz.lua` and append documented comments to `modernz.conf`. Add localization keys to `language["default"]`.

- [ ] **Step 4: Run test to verify it passes**

Run: `mpv --load-scripts=no --script=tests/test_options.lua --idle=once`
Expected: PASS with 0 exit code.

- [ ] **Step 5: Git commit message preparation**

Commit message: `feat(introdb): add configuration options and localization strings`

---

### Task 2: Implement IntroDB State Model and API Client

**Files:**
- Modify: `modernz.lua`
- Test: `tests/test_api_client.lua`

**Interfaces:**
- Consumes: `user_opts.introdb_api_url`, `exec(args, callback)`
- Produces: `fetch_introdb_segments(imdb_id, season, episode, is_movie, callback)`
- Produces: `state.introdb` state machine (`imdb_id`, `season`, `episode`, `segments`, `active_segment`, `button_shown_time`, `button_visible`, `button_alpha`)
- Produces: `reset_introdb_state()`

- [ ] **Step 1: Write test for API response parsing and state lifecycle**

Create `tests/test_api_client.lua` feeding mock JSON responses (`intro`, `recap`, `outro`, `post_credits`) into the parsing function and testing that `reset_introdb_state()` wipes all segments.

- [ ] **Step 2: Run test to verify it fails**

Run: `mpv --load-scripts=no --script=tests/test_api_client.lua --idle=once`
Expected: FAIL with undefined `fetch_introdb_segments`.

- [ ] **Step 3: Implement `fetch_introdb_segments` and state lifecycle in `modernz.lua`**

1. Define `state.introdb` initialization.
2. Implement `reset_introdb_state()`. Hook it to `start-file` event to clear cached segments on file switch.
3. Implement `fetch_introdb_segments(imdb_id, season, episode, is_movie)` constructing `curl -s -f --max-time 3 "<URL>"` via `exec()`.
4. Parse JSON result safely via `utils.parse_json()`, extract non-null segments into a sorted list: `{ type = "intro", start_sec = N, end_sec = N, label = "Intro" }`.

- [ ] **Step 4: Run test to verify it passes**

Run: `mpv --load-scripts=no --script=tests/test_api_client.lua --idle=once`
Expected: PASS.

- [ ] **Step 5: Git commit message preparation**

Commit message: `feat(introdb): implement api client and lifecycle state management`

---

### Task 3: Implement Metadata Resolution and Fallback Ladder

**Files:**
- Modify: `modernz.lua`
- Test: `tests/test_metadata_resolver.lua`

**Interfaces:**
- Consumes: mpv properties `user-data/metadata/imdb_id`, `user-data/metadata/season`, `user-data/metadata/episode`, `user-data/metadata/is_movie` (plus aliases `user-data/imdb_id`, `metadata/by-key/IMDB`).
- Produces: `resolve_media_metadata(callback)`
- Produces: Fallback ladder: IPC property $\to$ filename regex & NFO $\to$ guessit $\to$ Cinemeta/IMDb suggestion.

- [ ] **Step 1: Write test for metadata resolution pipeline**

Create `tests/test_metadata_resolver.lua` checking:
- Path containing `tt0903747` and `S01E02` extracts IMDb ID `tt0903747`, season 1, episode 2.
- User-data property observation triggers metadata resolution.
- Guessit JSON parsing extracts title, season, episode.

- [ ] **Step 2: Run test to verify it fails**

Run: `mpv --load-scripts=no --script=tests/test_metadata_resolver.lua --idle=once`
Expected: FAIL.

- [ ] **Step 3: Implement metadata resolver in `modernz.lua`**

1. Register `mp.observe_property("user-data/metadata/imdb_id", "string", on_imdb_id_changed)`.
2. Implement filename and directory path regex parser for `tt\d{7,8}` and `[sS](%d+)[eE](%d+)`.
3. Implement local `.nfo` inspection if present in the same directory.
4. Implement `guessit` subprocess execution and Cinemeta search fallback when `introdb_guessit_fallback` is enabled.
5. Trigger `fetch_introdb_segments()` once metadata is resolved.

- [ ] **Step 4: Run test to verify it passes**

Run: `mpv --load-scripts=no --script=tests/test_metadata_resolver.lua --idle=once`
Expected: PASS.

- [ ] **Step 5: Git commit message preparation**

Commit message: `feat(introdb): implement multi-source metadata resolution ladder`

---

### Task 4: Implement Seekbar Segment Highlights and Tooltip Integration

**Files:**
- Modify: `modernz.lua:1640-1655` (seekbar rendering loop), `modernz.lua:3600-3660` (tooltip)
- Test: `tests/test_seekbar_highlights.lua`

**Interfaces:**
- Consumes: `state.introdb.segments`, `user_opts.introdb_show_highlights`, segment colors.
- Produces: `draw_introdb_ranges(element, elem_ass)`
- Modifies: `get_seekbar_tooltip_text(pos)` to append segment label if hovering a segment.

- [ ] **Step 1: Write test for seekbar coordinate calculation and tooltip generation**

Create `tests/test_seekbar_highlights.lua` checking:
- Coordinates for start/end percentages map correctly to pixel positions.
- Tooltip returns `"[time] • [Label]"` when within segment boundaries.

- [ ] **Step 2: Run test to verify it fails**

Run: `mpv --load-scripts=no --script=tests/test_seekbar_highlights.lua --idle=once`
Expected: FAIL.

- [ ] **Step 3: Implement `draw_introdb_ranges` and tooltip enhancement**

1. Implement `draw_introdb_ranges(element, elem_ass)`:
   - Check `user_opts.introdb_enable` and `user_opts.introdb_show_highlights` and `state.introdb.segments`.
   - For each segment, determine color from `user_opts.introdb_<type>_color`.
   - Calculate `pstart` and `pend` in slider coordinate space.
   - If `slider_lo.nibbles_style == "gap"`, split segment cleanly across chapter gap cuts.
   - Append ASS drawing commands to `elem_ass`.
2. Insert `draw_introdb_ranges(element, elem_ass)` right after `draw_seekbar_nibbles` in `render_elements()`.
3. In tooltip generator, check if hovered timestamp falls in any segment and append segment label.

- [ ] **Step 4: Run test to verify it passes**

Run: `mpv --load-scripts=no --script=tests/test_seekbar_highlights.lua --idle=once`
Expected: PASS.

- [ ] **Step 5: Git commit message preparation**

Commit message: `feat(introdb): add seekbar segment highlights and tooltip labels`

---

### Task 5: Implement Floating Skip Capsule Button & Hotkey

**Files:**
- Modify: `modernz.lua`
- Test: `tests/test_skip_button.lua`

**Interfaces:**
- Consumes: `playback-time`, `state.introdb.segments`, `user_opts.introdb_button_duration`.
- Produces: `active_segment` detection on tick.
- Produces: `draw_skip_capsule_button(master_ass)` (ASS vector capsule button at bottom-right).
- Produces: Mouse click event handling (seek to `segment.end_sec`).
- Produces: `script-binding modernz/introdb-skip`.
- Produces: `introdb_auto_skip` execution.

- [ ] **Step 1: Write test for active segment detection and 7-second auto-timer**

Create `tests/test_skip_button.lua` checking:
- When `playback-time` is inside segment, `active_segment` is detected.
- `button_visible` becomes true; after 7 seconds elapsed without interaction, visibility timer expires.
- Mouse interaction / seek into segment resets timer.
- Skip action seeks to `end_sec`.

- [ ] **Step 2: Run test to verify it fails**

Run: `mpv --load-scripts=no --script=tests/test_skip_button.lua --idle=once`
Expected: FAIL.

- [ ] **Step 3: Implement active segment detection, capsule button, and skip handler**

1. On `playback-time` update:
   - Check if current time falls in a segment.
   - If entering a new segment:
     - If `user_opts.introdb_auto_skip` matches segment type: seek immediately to `end_sec`, show OSD message `Skipped [Type]`.
     - Otherwise: set `button_shown_time = mp.get_time()`, `button_visible = true`.
   - If inside segment and `mp.get_time() - button_shown_time < user_opts.introdb_button_duration`: keep visible; otherwise fade out.
2. Implement ASS vector drawing for the pill button in bottom-right (above OSC).
3. Handle mouse click on capsule hitbox to perform `mp.commandv("seek", segment.end_sec, "absolute+exact")`.
4. Register script-binding: `mp.add_key_binding(nil, "introdb-skip", skip_current_segment)`.

- [ ] **Step 4: Run test to verify it passes**

Run: `mpv --load-scripts=no --script=tests/test_skip_button.lua --idle=once`
Expected: PASS.

- [ ] **Step 5: Git commit message preparation**

Commit message: `feat(introdb): implement floating skip capsule button and hotkey binding`

---

### Task 6: Full Integration and Regression Verification

**Files:**
- Test: `tests/test_integration.lua`

**Interfaces:**
- Validates the entire flow: metadata ingestion $\to$ IntroDB fetch $\to$ seekbar render $\to$ capsule button display $\to$ skip execution $\to$ cleanup on file change.
- Validates that ModernZ existing layouts (`default`, `compact`, `mini`, `seekbar`) remain unaltered.

- [ ] **Step 1: Write comprehensive integration test**

Create `tests/test_integration.lua` running a full mpv playback cycle simulating file load, user-data injection, segment fetching, seekbar rendering, and capsule skip trigger.

- [ ] **Step 2: Run integration test suite**

Run: `mpv --load-scripts=no --script=tests/test_integration.lua --idle=once`
Expected: All test assertions PASS with exit code 0.

- [ ] **Step 3: Clean up temporary test artifacts**

Remove any temporary test output files while preserving test suites in `tests/`.

- [ ] **Step 4: Final verification and summary**

Verify `git status` shows clean modifications aligned with the specification.

- [ ] **Step 5: Git commit message preparation**

Commit message: `test(introdb): add end-to-end integration test suite`
