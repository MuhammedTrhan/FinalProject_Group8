class_name ParanoidModule
extends PersonalityModule
## Searches thoroughly for a long time after losing the player - the
## opposite of ForgetfulModule. Never enters SPECIAL; Paranoid's personality
## is already fully expressed by the profile's turn_around_chance/
## detect_dwell/fov_degrees numbers.

const LOOK_AROUND_TIME := 5.0


func on_lost_target() -> void:
	if enemy:
		enemy.investigate_look_around_time = LOOK_AROUND_TIME
