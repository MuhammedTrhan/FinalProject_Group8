class_name PersonalityProfile
extends Resource
## Everything that makes one of the antagonist's personalities different from
## the others, authored as a .tres under res://Resources/Personalities/.

## The behaviour state machine is SHARED across all personalities; only the
## numbers below change. Personality-specific mechanics live in a separate
## PersonalityModule node, not here.

## OWNERSHIP: Dev2 owns this file and the .tres files. Dev1's day-one terminal
## screen reads `display_name`, `dossier_text` and `portrait` from the same
## resources so the two sides never touch each other's scenes.

enum Personality {FORGETFUL, PARANOID, OVERWHELMED}


@export_group("Identity")
@export var personality: Personality = Personality.FORGETFUL
@export var display_name: String = ""
## Shown on the day-one computer terminal, written in-fiction by the child
## personality in his diary.
@export_multiline var dossier_text: String = ""
@export var portrait: Texture2D


@export_group("Spritesheets")
## Universal LPC Spritesheet Generator output. Same body, different face and clothes.

## These are swapped into the AnimationLibrary at runtime rather than assigned
## to Sprite2D directly, because every animation keyframes `Sprite2D:texture`
## and would immediately overwrite a direct assignment.
@export var idle_sheet: Texture2D
@export var walk_sheet: Texture2D
## Used by the slash, back_slash and lock animations - they share one sheet.
@export var slash_sheet: Texture2D
@export var sit_sheet: Texture2D


@export_group("Movement")
@export var move_speed: float = 90.0
@export var chase_speed: float = 130.0
## Chance per patrol leg that he stops and looks at nothing.
@export_range(0.0, 1.0) var pause_chance: float = 0.25
@export var pause_duration_range := Vector2(0.6, 1.8)
## Chance per patrol leg of an abrupt 180-degree turn. Reads as "paranoid".
@export_range(0.0, 1.0) var turn_around_chance: float = 0.0


@export_group("Perception")
@export var view_distance: float = 180.0
@export_range(0.0, 360.0) var fov_degrees: float = 90.0
## Seconds the player must stay visible before this personality reacts.
@export var detect_dwell: float = 1.0
## If false, spotting the player never escalates into a chase.
@export var can_chase: bool = true


@export_group("Follow Area")
## Outer "stay close and he'll warm up to you" area - separate from and
## larger than the Perception cone/circle above. 0.0 means this personality
## doesn't have one.
@export var follow_area_radius: float = 0.0
## Seconds of continuous "inside the follow area" to go from 0 to 1 progress.
@export var follow_fill_time: float = 6.0
## Seconds of continuous "outside the follow area" to drain 1 back to 0.
@export var follow_drain_time: float = 4.0


@export_group("Cues")
## Looping audio while this personality is active - the GDD's "auditory cue".
@export var ambient_loop: AudioStream
## Icon shown in a speech bubble above his head (e.g. a note or panic icon).
@export var emote_icon: Texture2D


@export_group("Behaviour")
## The Overwhelmed never patrols - he rocks in place from the moment the day
## starts, so his module drives the Special state immediately.
@export var starts_in_special: bool = false
## Chance, each time he opens a door, that he just doesn't bother closing it
## behind him again. 0.0 means "always closes up (and re-locks) behind
## itself" - only Forgetful has this above zero.
@export_range(0.0, 1.0) var leave_door_open_chance: float = 0.0
## If the player hides while still clearly in view (Perception.was_visible_
## last_frame() was true the instant player_hidden_changed(true) fires), this
## personality walks straight to the hiding spot and drags the player out. Only
## Forgetful just treats it as an ordinary lost-track (Investigate, then give up).
@export var catches_hidden_in_sight: bool = true


@export_group("Reward")
## The item WorldItem.spawn()s when this personality is satisfied - the
## crowbar (Forgetful, on a successful stalk), the UV flashlight
## (Overwhelmed, once the house is quiet). Left null for a personality that
## doesn't drop a single reward item.
@export var reward_item: ItemData
## Paranoid-specific: the torn diary pages he deposits into the three
## garbage cans while patrolling. Left empty for personalities that
## use reward_item instead. Depositing them is not yet implemented -
## it needs the garbage-can puzzle objects to exist first;
## this field just holds the data for when it is.
@export var reward_items: Array[ItemData] = []


## Returns the sheet an animation should use, keyed off the animation's name.
## Mapping is by name rather than by comparing the old texture, so it stays
## correct even if the base scene's textures are swapped later.
func get_sheet_for_animation(anim_name: String) -> Texture2D:
	if anim_name.begins_with("idle"):
		return idle_sheet
	if anim_name.begins_with("walk"):
		return walk_sheet
	if anim_name.begins_with("sit"):
		return sit_sheet
	# slash_*, back_slash_* and lock_* all share the slash sheet.
	return slash_sheet
