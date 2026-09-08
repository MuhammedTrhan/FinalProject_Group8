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
