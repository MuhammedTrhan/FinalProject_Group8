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
##
## Every signal below is emitted and connected to from other scripts. GDScript's
## UNUSED_SIGNAL warning can't see those cross-file relationships, so it flags
## every signal here as "declared but never used".
## @warning_ignore("unused_signal") silences that.


# ---------------------------------------------------------------------------
# Game flow  (Dev1 emits, everyone consumes)
# ---------------------------------------------------------------------------

## Fired once at the start of a run, after the passcode has been generated.
@warning_ignore("unused_signal")
signal run_started(run_seed: int)

## The antagonist wakes up as `personality` (a PersonalityProfile.Personality).
## Dev2's enemy listens to this to swap its active profile.
@warning_ignore("unused_signal")
signal day_started(day: int, personality: int)

## The player is locked in their room; day mechanics stop being evaluated.
@warning_ignore("unused_signal")
signal night_started(day: int)

## NOT YET EMITTED - requested of Dev1 09.09.2026, see docs/CONTRACT.md §2.2.
## Fires the instant the day's timer would otherwise have fired
## night_started right away - GameManager should then wait a further fixed
## ~5s (matching Dev2's EscortController.ESCORT_DURATION) before actually
## proceeding into the fadeout, giving Dev2 a window to walk the player back
## to her room BEFORE night begins. Until this exists, EscortController
## falls back to starting that same walk on today's night_started instead
## (later than ideal, but not broken).
@warning_ignore("unused_signal")
signal day_ended(day: int)

## NOT YET EMITTED - see day_ended above. Fires once that ~5s wait elapses,
## right as the day/night fadeout itself begins; night_started (unchanged)
## still fires once the fadeout completes. Dev2's escort keeps walking
## through both windows - day_ended..night_ended and night_ended..night_started -
## only actually finishing (snap + lock) on night_started.
@warning_ignore("unused_signal")
signal night_ended(day: int)


# ---------------------------------------------------------------------------
# Antagonist  (Dev2 emits, Dev1 consumes)
# ---------------------------------------------------------------------------

## The player has been caught. Dev1 shows the lockdown / game-over screen.
## `reason` is one of: &"seen", &"too_close", &"noise", &"timeout", &"touched"
@warning_ignore("unused_signal")
signal player_caught(reason: StringName)

## The antagonist has been satisfied and dropped his reward item into the world.
@warning_ignore("unused_signal")
signal enemy_dropped_item(item: ItemData, world_position: Vector2)

## Diagnostic only - the debug overlay and (optionally) audio listen to this.
@warning_ignore("unused_signal")
signal enemy_state_changed(state: StringName)

## A non-final catch's own escort-back-to-her-room window just finished (the
## self-timed ~5s equivalent of day_ended..night_ended, since a catch has no
## day_ended to react to). GameManager should react as if night_ended had
## just fired - skip straight into starting the fadeout - since Dev2 already
## ran the equivalent window itself before asking. `reason` is currently
## always &"caught".
@warning_ignore("unused_signal")
signal night_start_requested(reason: StringName)


# ---------------------------------------------------------------------------
# World and puzzles  (Dev3 emits, Dev1 consumes)
# ---------------------------------------------------------------------------

## A puzzle has revealed one digit of the exit passcode (3 digits total).
## `digit_index` is fixed per puzzle: 0 = UV floor clue, 1 = loose floorboard,
## 2 = torn diary. See docs/CONTRACT.md §3.2.
@warning_ignore("unused_signal")
signal clue_revealed(digit_index: int, digit_value: int, flavour: String)

## A WorldItem was picked up. Dev1's Inventory adds it.
@warning_ignore("unused_signal")
signal item_pickup_requested(item: ItemData)

## Player opens the computer to check for info. Dev1's ComputerUI opens.
@warning_ignore("unused_signal")
signal computer_interact_requested()

## One of the Overwhelmed's noise sources was switched off.
## `remaining` is how many are still making noise; 0 means the house is quiet.
@warning_ignore("unused_signal")
signal noise_source_silenced(source: Node, remaining: int)

## The player entered or left a hiding spot. Dev2's Perception checks this
## first, as a belt-and-braces companion to the player's collision layer going
## to 0 while hidden. `hideable` is the Hideable node itself while hidden
## (null when revealed, and always null from debug_toggle_hidden's fake
## toggle) - lets the enemy walk straight to that spot's exit marker if it
## catches the player hiding in plain sight.
@warning_ignore("unused_signal")
signal player_hidden_changed(hidden: bool, hideable: Hideable)


# ---------------------------------------------------------------------------
# Presentation  (anyone emits)
# ---------------------------------------------------------------------------

## Text to show above the player's head. Empty string hides the label.
@warning_ignore("unused_signal")
signal interaction_prompt_changed(primary: String, secondary: String)

## A transient message above the player's head ("I don't have the right key.").
@warning_ignore("unused_signal")
signal message_requested(text: String)

@warning_ignore("unused_signal")
signal sfx_requested(sfx_id: StringName, world_position: Vector2)
