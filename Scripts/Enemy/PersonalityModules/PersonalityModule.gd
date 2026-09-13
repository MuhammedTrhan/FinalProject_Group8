class_name PersonalityModule
extends Node
## Personality-specific mechanics that don't belong in the shared state
## machine (Enemy.gd). One of these is instantiated and added as a child of
## Enemy whenever the active personality changes.

## Set by Enemy right after instantiating this module.
var enemy: Enemy


## Called when Enemy enters State.SPECIAL.
func on_enter_special() -> void:
	pass


## Called every physics frame while Enemy is in State.SPECIAL. Only Overwhelmed uses this.
func process_special(_delta: float) -> void:
	pass


## Called right before Enemy drops from CHASE into INVESTIGATE.
func on_lost_target() -> void:
	pass


## Called whenever GameEvents.noise_source_silenced fires. Only Overwhelmed cares about this.
func on_noise_source_silenced(_remaining: int) -> void:
	pass


## 0.0-1.0 progress toward this personality's own punishing outcome (the
## shared chase bar Dev1 shows in the UI) - how close the player currently
## is to getting caught/chased. Drained back down whenever she isn't
## actively being watched, not a slow-building meter.
func get_chase_progress() -> float:
	return 0.0


## 0.0-1.0 progress toward this personality's own rewarding outcome (a
## second, separate radial bar Dev1 only shows while this personality is
## active) - e.g. Forgetful's "stay close and he warms up to you" outer
## follow-area meter. Unrelated to get_chase_progress() above - a
## personality without one of these just stays at the default 0.0.
func get_follow_progress() -> float:
	return 0.0


## Name of a fixed, non-directional Animation to play instead of the usual
## idle/walk state while in State.SPECIAL (see EnemyAnimationHandler.
## play_special_pose()). Empty string (the default) means "no override, just
## play idle/walk as normal".
func special_pose_animation() -> StringName:
	return &""


## Fill color for the outer follow-area ring in PersonalityAreaVisual.
## Color.TRANSPARENT (the default) means "just draw the plain unfilled
## outline" (Forgetful's ring). A personality wanting a dynamic fill
## (Paranoid's green-while-deciding/red-while-giving-up) returns a real
## color here each frame.
func get_outer_area_fill_color() -> Color:
	return Color.TRANSPARENT


## Whether Enemy._check_perception_transitions() should still run (and
## PersonalityAreaVisual should still show the cone) while in State.SPECIAL.
## false (the default) - Overwhelmed's rocking/panicking is inert to
## perception by design. Paranoid's deposit walk is a fully alert, moving
## use of SPECIAL and overrides this to true.
func reacts_to_perception_during_special() -> bool:
	return false
