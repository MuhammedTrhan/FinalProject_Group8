extends Node
## Global signal bus. Holds NO state and contains NO logic. Never connects to
## itself. This file is the contract sheet between the three developers.
##
## THE RULE:
##   You may EMIT only the signals in your own section.
##   You may CONNECT to any signal in this file.
##   If you need a new signal, add it here in its own commit and announce it.
##   Never add signals to another developer's script.
##
## Dev1 = game flow / inventory / UI
## Dev2 = antagonist AI
## Dev3 = player / world / puzzles


# ---------------------------------------------------------------------------
# Game flow  (Dev1 emits, everyone consumes)
# ---------------------------------------------------------------------------

## Fired once at the start of a run, after the passcode has been generated.
signal run_started(run_seed: int)

## The antagonist wakes up as `personality` (a PersonalityProfile.Personality).
## Dev2's enemy listens to this to swap its active profile.
signal day_started(day: int, personality: int)

## The player is locked in their room; day mechanics stop being evaluated.
signal night_started(day: int)


# ---------------------------------------------------------------------------
# Antagonist  (Dev2 emits, Dev1 consumes)
# ---------------------------------------------------------------------------

## The player has been caught. Dev1 shows the lockdown / game-over screen.
## `reason` is one of: &"seen", &"too_close", &"noise", &"timeout", &"touched"
signal player_caught(reason: StringName)

## The antagonist has been satisfied and dropped his reward item into the world.
signal enemy_dropped_item(item: ItemData, world_position: Vector2)

## Diagnostic only - the debug overlay and (optionally) audio listen to this.
signal enemy_state_changed(state: StringName)


# ---------------------------------------------------------------------------
# World and puzzles  (Dev3 emits, Dev1 consumes)
# ---------------------------------------------------------------------------

## A puzzle has revealed one digit of the exit passcode.
## `digit_index` is fixed per puzzle: 0 = UV floor clue, 1 = loose floorboard,
## 2 = torn diary, 3 = day-one terminal.
signal clue_revealed(digit_index: int, digit_value: int, flavour: String)

## A WorldItem was picked up. Dev1's Inventory adds it.
signal item_pickup_requested(item: ItemData)

## One of the Overwhelmed's noise sources was switched off.
## `remaining` is how many are still making noise; 0 means the house is quiet.
signal noise_source_silenced(source: Node, remaining: int)

## The player entered or left a hiding spot. Dev2's Perception checks this
## first, as a belt-and-braces companion to the player's collision layer going
## to 0 while hidden.
signal player_hidden_changed(hidden: bool)


# ---------------------------------------------------------------------------
# Presentation  (anyone emits)
# ---------------------------------------------------------------------------

## Text to show above the player's head. Empty string hides the label.
signal interaction_prompt_changed(primary: String, secondary: String)

## A transient message above the player's head ("I don't have the right key.").
signal message_requested(text: String)

signal sfx_requested(sfx_id: StringName, world_position: Vector2)
