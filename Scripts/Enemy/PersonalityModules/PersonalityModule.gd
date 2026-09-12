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


## 0.0-1.0 progress toward this personality's own punishing outcome (a chase
## bar Dev1 shows in the UI).
func get_chase_progress() -> float:
	return 0.0


## Name of a fixed, non-directional Animation to play instead of the usual
## idle/walk state while in State.SPECIAL (see EnemyAnimationHandler.
## play_special_pose()). Empty string (the default) means "no override, just
## play idle/walk as normal".
func special_pose_animation() -> StringName:
	return &""
