# Integration Contract — Developer 1 ↔ Developer 2/3

**Project "Split"** · INF2556 Game Development · Submission 18.09.2026

This document defines the boundary between Developer 1 (Core Systems, UI &
Game State) and Developers 2/3 (Antagonist AI, Player, Environment & Puzzles).

Everything crosses that boundary through **`Scripts/Autoload/GameEvents.gd`** —
a signal-only autoload with no state and no logic. Neither side ever references
the other's scripts or scenes directly.

---

## 1. The rule

> You may **emit** only the signals in your own section of `GameEvents.gd`.
> You may **connect** to any signal in the file.
> If you need a new signal, add it to `GameEvents.gd` in its own commit and
> announce it. Never add a signal to another developer's script.

---

## 2. What Developer 1 must provide

### 2.1 Autoloads

| Autoload | Registered as | Notes |
|---|---|---|
| `GameManager` | `res://Scripts/Autoload/GameManager.gd` | Day/night cycle, personality order, passcode |
| `Inventory` | `res://Scripts/Autoload/Inventory.gd` | Item storage and combining |

`GameEvents` is already registered in `project.godot` (Dev2/Dev3 depend on it
from day one). Its ownership transfers to Developer 1.

### 2.2 Signals Developer 1 emits

```gdscript
signal run_started(run_seed: int)
signal day_started(day: int, personality: int)   # personality = PersonalityProfile.Personality
signal night_started(day: int)
```

`day_started` is what switches the antagonist's active personality. Until it
exists, Dev2 cycles personalities manually with **F1**.

### 2.3 API Developer 2/3 call directly

```gdscript
Inventory.add_item(item: ItemData) -> void
Inventory.has_item(item: ItemData) -> bool
Inventory.remove_item(item: ItemData) -> bool

GameManager.current_personality -> int      # PersonalityProfile.Personality
GameManager.is_day() -> bool
```

### 2.4 Screens

- Main menu
- Day-one computer terminal (personality dossiers — see §4)
- Day transition screen
- Lockdown / game-over screen (triggered by `player_caught`)
- Win screen (passcode accepted)
- Inventory UI
- Passcode entry (keypad) on the exit door

---

## 3. What Developer 2/3 provide

### 3.1 Signals emitted

```gdscript
# Puzzles (Dev3)
signal clue_revealed(digit_index: int, digit_value: int, flavour: String)
signal item_pickup_requested(item: ItemData)
signal noise_source_silenced(source: Node, remaining: int)
signal player_hidden_changed(hidden: bool)

# Antagonist (Dev2)
signal player_caught(reason: StringName)
signal enemy_dropped_item(item: ItemData, world_position: Vector2)
signal enemy_state_changed(state: StringName)

# Presentation (either)
signal interaction_prompt_changed(primary: String, secondary: String)
signal message_requested(text: String)
signal sfx_requested(sfx_id: StringName, world_position: Vector2)
```

### 3.2 Passcode digit ownership

The passcode is **4 digits**. `GameManager` generates the values; each digit is
revealed by a fixed source:

| `digit_index` | Revealed by | Owner |
|---|---|---|
| 0 | UV floor clue (needs the UV Flashlight) | Dev3 |
| 1 | Loose floorboard (needs the Crowbar) | Dev3 |
| 2 | Torn diary (3 scraps combined) | Dev3 |
| 3 | Day-one computer terminal | Dev1 |

Only the **values** are randomised per run; the digit-to-source mapping is fixed.

### 3.3 Shared data schemas (authored by Dev2/3, consumed by Dev1)

- `Scripts/Items/ItemData.gd` — one inventory item
- `Scripts/Enemy/PersonalityProfile.gd` — one antagonist personality
- `Scripts/Layers.gd` — named physics-layer constants

Items live in `res://Resources/Items/`:
`crowbar`, `uv_flashlight`, `scrap_a`, `scrap_b`, `scrap_c`, `diary_page`,
`common_key`, `rare_key`, `precious_key`.

---

## 4. The day-one terminal reads `PersonalityProfile`

Rather than duplicating the personality descriptions in the UI, the terminal
screen loads the same `.tres` files the AI uses and reads three fields:

```gdscript
profile.display_name    # "The Paranoid"
profile.dossier_text    # the in-fiction diary entry
profile.portrait        # Texture2D
```

In-fiction, these entries were written by the child personality in his diary.
Dev2 writes the text and supplies the portraits; Dev1 builds the screen. Neither
side edits the other's files.

The player identifies which personality is active on a given day purely
through **clothing/face (the LPC spritesheet swap)** and **audio/emote cues**
(`PersonalityProfile.ambient_loop`, `emote_icon`) — deliberately no glow, tint,
or other easy-mode visual shortcut.

---

## 5. Project-wide settings already decided (do not change without announcing)

Set in `project.godot` on 05.09.2026:

- `run/main_scene` = `Scenes/main_level.tscn` — **temporary**. Change it to
  Developer 1's game shell scene once that exists.
- `window/stretch/mode = "viewport"` at 1152×648 (aspect `keep`, both equal to
  Godot's own engine defaults so they don't appear literally in the file).
  This guarantees every player sees exactly the same amount of the level,
  which the antagonist's detection ranges are tuned against.
  **`stretch/mode` changes how Control nodes anchor — build all UI against
  this setting, not the default.**
- `textures/canvas_textures/default_texture_filter = 0` (Nearest) for crisp
  16×16 pixel art.
- Physics layers: 1 Player · 2 Walls · 3 Interactable · 4 Enemy ·
  5 StairsTransition · 6 HidingSpot · 7 NoiseSource. Use `Layers.gd`, never
  literal integers.
- `*.tres` and `*.import` were **removed from Git LFS**. Everyone must run
  `git lfs pull` or re-clone once after 05.09.2026.

---

## 6. Debug keys (debug builds only)

Available to everyone for testing without a full day cycle:

| Key | Action |
|---|---|
| F1 | Cycle the active personality |
| F2 | Freeze / unfreeze the AI |
| F3 | Warp the antagonist to the player |
| F4 | Force the current personality's objective to succeed |
| F9 | Force the current personality's objective to fail |
| F10 | Toggle "player is hidden" |
| F11 | Toggle the AI debug overlay |

F5–F8 are deliberately unused so they do not collide with the Godot editor's
Run / Stop shortcuts.
