# IntroDB Integration Design Specification for ModernZ

- **Date:** 2026-10-07
- **Target:** `modernz.lua`, `modernz.conf`
- **Branch:** `feature/introdb-integration`
- **Status:** Approved Draft

---

## 1. Overview & Goals

This specification details the architecture, data flow, visual design, and implementation plan for integrating **IntroDB** (https://introdb.app) into the **ModernZ** mpv user script.

### Key Objectives
1. **Seekbar Segment Highlighting**: Display colored, semi-transparent range indicators on the seekbar for segments identified by IntroDB (`intro`, `recap`, `outro`, `post_credits`), respecting chapter nibbles and rounded corner styling.
2. **Floating Skip Capsule Button**: Render a stream-styled pill button (e.g. `[ ⏭ Skip Intro ]`) during segment playback, auto-displaying for 7 seconds upon entering a segment (or upon user interaction/seeking), and immediately seeking past the segment when clicked.
3. **Strict UI Non-Interference**: Fully preserve ModernZ's existing OSC controls, geometry, responsive layouts (`default`, `compact`, `mini`, `seekbar`), and performance.
4. **Resilient Metadata Pipeline**: Support instant IPC property ingestion from external scrobblers (such as `Media-Player-Scrobbler-for-Simkl`) as primary, with a robust fallback ladder (path regex, `.nfo` parsing, `guessit`, public search APIs).

---

## 2. Metadata Pipeline & IPC Interface

IntroDB API requires:
- `imdb_id`: string (pattern `^tt\d{7,8}`)
- For TV series: `season` (integer >= 1) and `episode` (integer >= 1)
- For movies: `is_movie = true`

### 2.1 Property Hierarchy (IPC & Inter-Script Protocol)

To allow interoperability across user scripts (such as `Media-Player-Scrobbler-for-Simkl`), ModernZ observes the following standardized properties in mpv:

| Property Name | Type | Description | Example |
| :--- | :--- | :--- | :--- |
| `user-data/metadata/imdb_id` | string | IMDb title ID | `"tt0903747"` |
| `user-data/metadata/season` | integer/string | TV Season number | `1` |
| `user-data/metadata/episode` | integer/string | TV Episode number | `2` |
| `user-data/metadata/is_movie` | boolean/string | Movie flag | `false` |

*ModernZ also accepts fallback property aliases:* `user-data/imdb_id`, `user-data/season`, `user-data/episode`, and embedded file tags (e.g. `metadata/by-key/IMDB`).

### 2.2 Identification Sequence (Fallback Ladder)

When a media file starts (`file-loaded`):
1. **Primary**: Check if `user-data/metadata/imdb_id` (or alias) is already populated by an external scrobbler. If present, query IntroDB immediately.
2. **Secondary (Local Patterns)**:
   - Search the active media path and directory name for `(tt\d{7,8})`.
   - Parse season and episode via regex: `[sS](%d+)[eE](%d+)`, `(%d+)x(%d+)`, etc.
   - If not found in filename, check if a sibling `.nfo` file exists in the directory and parse `<imdbid>(tt\d+)</imdbid>` or `imdb%.com/title/(tt%d+)`.
3. **Tertiary (GuessIt + Public Search API)**:
   - If enabled by `introdb_guessit_fallback = yes`:
     - Asynchronously execute `guessit "<filename>" -j`.
     - Parse JSON output: extract `title`, `season`, `episode`, `year`, `type`.
     - Asynchronously query Cinemeta API (`https://v3-cinemeta.strem.io/catalog/{series|movie}/top/search={title}.json`) or IMDb Suggestion API (`https://v3.sg.media-imdb.com/suggestion/x/{initial}/{title}.json`) to obtain the `imdb_id`.
     - Feed the resolved metadata into the IntroDB query handler.

---

## 3. IntroDB API Integration & Cache Management

### 3.1 Network Endpoint
- **Base URL**: `https://api.introdb.app/segments`
- **Query Parameters**:
  - Series: `?imdb_id={imdb_id}&season={season}&episode={episode}`
  - Movies: `?imdb_id={imdb_id}&is_movie=true`
- **Execution**: Subprocess execution via `curl -s -f --max-time 3 "<URL>"` using `mp.command_native_async({name = "subprocess", ...})`.

### 3.2 Response Processing & State Model
IntroDB response schema:
```json
{
  "imdb_id": "tt0903747",
  "media_type": "tv",
  "is_movie": false,
  "season": 1,
  "episode": 2,
  "intro": { "start_sec": 77, "end_sec": 94 },
  "recap": { "start_sec": 95, "end_sec": 259 },
  "outro": { "start_sec": 2791, "end_sec": 2843 },
  "post_credits": null
}
```

State structure in `state.introdb`:
```lua
state.introdb = {
    imdb_id = nil,
    season = nil,
    episode = nil,
    segments = {},           -- Array of { type = "intro"|"recap"|"outro"|"post_credits", start_sec = N, end_sec = N }
    active_segment = nil,   -- Reference to the segment currently active at playback-time
    button_shown_time = 0,  -- mp.get_time() when button was last displayed
    button_visible = false, -- Whether capsule button is currently visible
    button_alpha = 255,     -- ASS alpha for smooth fade-in/out
}
```

### 3.3 Lifecycle & File Switch Cleanup
- On `start-file`: Reset `state.introdb` completely to prevent cross-file contamination.
- On `end-file` / `shutdown`: Cancel pending curl subprocesses if any.

---

## 4. Seekbar Highlighting & ASS Rendering

### 4.1 Layer Integration
In `modernz.lua`'s element rendering loop:
1. `seekbarbg`
2. `draw_seekbar_nibbles(element, elem_ass)`
3. `draw_introdb_ranges(element, elem_ass)` **(New)**
4. `draw_seekbar_ranges(element, elem_ass, handle_x, handle_radius)` (cache bar)
5. `draw_seekbar_progress(element, elem_ass)`
6. `draw_ab_loop_range(element, elem_ass)`
7. `draw_seekbar_handle(element, elem_ass, handle_x, handle_radius, anim_override, is_active)`

### 4.2 Drawing Implementation (`draw_introdb_ranges`)
- For each segment in `state.introdb.segments`:
  - Calculate `pstart = get_slider_ele_pos_for(element, (seg.start_sec / state.duration) * 100)`
  - Calculate `pend = get_slider_ele_pos_for(element, (seg.end_sec / state.duration) * 100)`
  - If `slider_lo.nibbles_style == "gap"`, split segment geometry across gap cuts.
  - Draw rounded or flat rectangles matching seekbar track dimensions using the designated color and alpha.

### 4.3 Tooltip Enhancement
In `get_seekbar_tooltip_text(pos)`:
- Determine if the hovered second falls within any IntroDB segment.
- If so, append segment label, e.g. `01:25 • Intro`.

---

## 5. Floating Skip Capsule Button

### 5.1 Appearance & Layout
- **Shape**: Rounded pill / capsule using ASS vector commands (`\round_rect_cw`).
- **Styling**:
  - Background: Dark translucent box with customizable opacity (`user_opts.osc_color` / Catppuccin style).
  - Border: Subtle highlight border (`#FFFFFF` with low alpha).
  - Content: Icon (fast forward / skip glyph) + Label (`Skip Intro`, `Skip Recap`, etc.).
- **Position**:
  - Bottom-Right: `x2 = osc_geo.w - 30`, `y2 = osc_geo.h - osc_margin - 15`.
  - When OSC is active, float just above the OSC frame without overlapping seekbar or controls.
  - When OSC hides, remain anchored to the bottom-right.

### 5.2 7-Second Smart Display Behavior
1. **Trigger**:
   - Playback enters `segment.start_sec <= playback_time < segment.end_sec`.
   - Set `active_segment = seg`, `button_shown_time = mp.get_time()`, `button_visible = true`.
2. **Auto-Dismiss**:
   - If `user_opts.introdb_button_duration > 0` (default 7 seconds):
   - Once `mp.get_time() - button_shown_time >= 7`, trigger smooth fade-out.
3. **Re-activation on User Action**:
   - If user moves mouse or seeks back into the active segment, reset `button_shown_time = mp.get_time()` and show the button again for 7 seconds.
4. **Click Handler**:
   - Left click: `mp.commandv("seek", segment.end_sec, "absolute+exact")`.
   - Immediately clears `active_segment`, fades out button.
5. **Hotkey Support**:
   - Provide script-binding `modernz/introdb-skip` for custom keybind mapping (e.g. `TAB`).

---

## 6. Configuration Parameters (`modernz.conf`)

New options added to `modernz.conf`:

```ini
# IntroDB Integration
introdb_enable=yes
introdb_api_url=https://api.introdb.app
introdb_auto_skip=no
introdb_button_duration=7
introdb_button_position=bottom_right

# Seekbar Highlights
introdb_show_highlights=yes
introdb_range_alpha=150
introdb_intro_color=#5C7CFA
introdb_recap_color=#20C997
introdb_outro_color=#FD7E14
introdb_post_credits_color=#BE4BDB

# Fallback Options
introdb_guessit_fallback=yes
```

---

## 7. Localization (`language` table)

| Key | Default (English) | Chinese (`zh`) |
| :--- | :--- | :--- |
| `skip_intro` | Skip Intro | 跳过片头 |
| `skip_recap` | Skip Recap | 跳过前情提要 |
| `skip_outro` | Skip Outro | 跳过片尾 |
| `skip_post_credits` | Skip Credits | 跳过彩蛋 |
| `skipped_segment` | Skipped %s | 已跳过 %s |

---

## 8. Verification & Test Plan

1. **IPC Ingestion Test**:
   - Verify setting `user-data/metadata/imdb_id = "tt0903747"`, `season = 2`, `episode = 1` immediately fetches IntroDB data and logs segment coordinates.
2. **Fallback Ladder Test**:
   - Test with a video file named `Breaking.Bad.S02E01.mkv` (without IPC input); verify `guessit` executes, resolves IMDb ID via Cinemeta/IMDb API, and loads IntroDB segments.
3. **Seekbar Highlighting Test**:
   - Verify colored segments render accurately on the seekbar in all 4 layouts (`default`, `compact`, `mini`, `seekbar`).
   - Verify hover tooltip shows segment name.
4. **Capsule Button Test**:
   - Verify capsule button fades in upon entering segment.
   - Verify button fades out after 7 seconds if unclicked.
   - Verify clicking skips to `end_sec` precisely and closes button.
   - Verify `modernz/introdb-skip` key binding works as expected.
5. **Layout Non-Regression**:
   - Verify all existing ModernZ buttons, volume bar, chapter marks, time codes, and animations remain visually and functionally unaffected.
