class_name ForgetfulModule
extends PersonalityModule
## Gives up investigating quickly. leaves_doors_open (on the active
## PersonalityProfile) is read directly by Enemy's door-handling code, not
## here - this module only owns the "how long does he look around" number.

const LOOK_AROUND_TIME := 1.5


func on_lost_target() -> void:
	if enemy:
		enemy.investigate_look_around_time = LOOK_AROUND_TIME
