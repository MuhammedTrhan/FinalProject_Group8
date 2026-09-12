class_name ForgetfulModule
extends PersonalityModule
## Gives up investigating quickly. leave_door_open_chance (on the active
## PersonalityProfile) is read directly by Enemy's door-handling code, not
## here - this module only owns the "how long does he look around" number.
##
## Also owns the "stalk" mechanic: an outer follow-area fill/drain
## accumulator (profile.follow_area_radius/follow_fill_time/follow_drain_time)
## that drops the crowbar once fully filled. His chase trigger itself is
## unchanged - it's still Enemy._check_perception_transitions() reacting to
## Perception's own cone, just with profile.fov_degrees set to 360 so that
## cone is effectively a circle.

const LOOK_AROUND_TIME := 1.5

var _follow_progress: float = 0.0
## True once the crowbar has been dropped this day - stalking is over,
## resets naturally next day since _apply_personality() recreates this module.
var _rewarded := false


func on_lost_target() -> void:
	if enemy:
		enemy.investigate_look_around_time = LOOK_AROUND_TIME


func _physics_process(delta: float) -> void:
	if _rewarded or enemy == null or enemy.profile == null:
		return
	# Don't accumulate/drain while the day-end escort or a floor-crossing
	# tween has the player and enemy artificially close together.
	if enemy.escort_controller.is_escorting() or enemy.is_teleporting:
		return

	if enemy.state == Enemy.State.CHASE or enemy.state == Enemy.State.INVESTIGATE:
		# Getting spotted/chased means this stalking attempt failed - start over.
		_follow_progress = 0.0
		return

	var player := enemy.perception.get_player()
	var inside: bool = player != null and is_instance_valid(player) \
		and enemy.global_position.distance_to(player.global_position) <= enemy.profile.follow_area_radius

	if inside:
		_follow_progress = minf(_follow_progress + delta / enemy.profile.follow_fill_time, 1.0)
		if _follow_progress >= 1.0:
			_rewarded = true
			_follow_progress = 0.0
			enemy.drop_reward()
	else:
		_follow_progress = maxf(_follow_progress - delta / enemy.profile.follow_drain_time, 0.0)


## The shared chase bar tracks danger - how close to a Chase starting - not
## the stalk/reward meter. That's Perception's own dwell timer against the
## inner circle (fov_degrees=360), which already hard-resets to 0 the instant
## she's not continuously watched - the same "drains when not being watched"
## behaviour Paranoid/post-calm-Overwhelmed report through this same hook.
func get_chase_progress() -> float:
	return enemy.perception.get_dwell_progress() if enemy else 0.0


## The separate, Forgetful-only radial bar - see PersonalityModule.
## get_follow_progress().
func get_follow_progress() -> float:
	return _follow_progress
