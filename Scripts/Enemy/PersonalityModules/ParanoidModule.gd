class_name ParanoidModule
extends PersonalityModule
## Searches thoroughly for a long time after losing the player - the
## opposite of ForgetfulModule.
##
## Also owns the "deposit" mechanic: a wide, short-fuse outer follow-area
## accumulator that, once fully filled, sends him walking to a random
## trash_can (group "diary_bin") to deposit one of profile.reward_items -
## reusing State.SPECIAL as the movement/animation hand-off vehicle,
## exactly like Overwhelmed's rocking does. The accumulator keeps running
## for the whole walk, not just the initial decision: stepping outside
## the area at any point drains it from wherever it sits,
## and draining fully gives up the attempt.
##
## Unlike Overwhelmed's rocking, this personality stays fully alert during
## SPECIAL, so his chase trigger keeps working even mid-walk.

const LOOK_AROUND_TIME := 5.0
const ARRIVAL_DISTANCE := 15.0
## No natural per-arrival moment exists during a long walk to a distant bin
## (unlike ordinary Patrol's per-point arrivals) - re-roll turn_around_chance
## on a timer instead, so it can still happen (possibly more than once)
## during a longer walk.
const TURN_CHECK_INTERVAL := 3.0
## Long enough for detect_dwell (0.5s on paranoid.tres) to have a real
## chance to complete against a stalking player before he turns back.
const LOOK_BEHIND_DURATION := 1.0

const DECISION_FILL_COLOR := Color(0, 1, 0, 0.35)
const DECISION_DRAIN_COLOR := Color(1, 0, 0, 0.35)

var _decision_progress: float = 0.0
var _is_filling: bool = false
var _is_depositing: bool = false
var _target_bin: ContainerFurniture = null

enum _TurnPhase {WARNING, LOOK_BEHIND}
var _turn_check_timer: float = 0.0
var _turn_phase: _TurnPhase = _TurnPhase.WARNING
var _turn_phase_timer: float = 0.0
var _is_turning: bool = false
## Guards the await in _perform_deposit() - process_special() and
## _physics_process() both run every physics frame, so without this either
## could re-enter/interleave with an in-flight _perform_deposit() before its
## animation await resumes.
var _finishing_deposit: bool = false


func on_lost_target() -> void:
	if enemy:
		enemy.investigate_look_around_time = LOOK_AROUND_TIME


func get_chase_progress() -> float:
	return enemy.perception.get_dwell_progress() if enemy else 0.0


## The world-space ring's progress.
func get_follow_progress() -> float:
	return _decision_progress


func get_outer_area_fill_color() -> Color:
	if _decision_progress <= 0.0 or _decision_progress >= 1.0:
		return Color.TRANSPARENT # baseline, or a decision already made - nothing to show either way
	return DECISION_FILL_COLOR if _is_filling else DECISION_DRAIN_COLOR


func reacts_to_perception_during_special() -> bool:
	return true


func _physics_process(delta: float) -> void:
	if _finishing_deposit or enemy == null or enemy.profile == null:
		return
	if enemy.escort_controller.is_escorting() or enemy.is_teleporting:
		return
	if enemy.state == Enemy.State.CHASE or enemy.state == Enemy.State.INVESTIGATE:
		# A real Chase/Investigate always wins - cancel any in-progress deposit.
		if _is_depositing:
			_abandon_deposit()
		_decision_progress = 0.0
		return

	var player := enemy.perception.get_player()
	_is_filling = player != null and is_instance_valid(player) \
		and enemy.global_position.distance_to(player.global_position) <= enemy.profile.follow_area_radius

	if _is_filling:
		_decision_progress = minf(_decision_progress + delta / enemy.profile.follow_fill_time, 1.0)
		if _decision_progress >= 1.0 and not _is_depositing \
				and enemy.paranoid_deposited_count < enemy.profile.reward_items.size():
			_start_deposit_walk()
	else:
		_decision_progress = maxf(_decision_progress - delta / enemy.profile.follow_drain_time, 0.0)
		if _decision_progress <= 0.0 and _is_depositing:
			_abandon_deposit()


func _start_deposit_walk() -> void:
	var bin := _pick_trash_bin()
	if bin == null:
		return
	_target_bin = bin
	_is_depositing = true
	_turn_check_timer = 0.0
	enemy.enter_special()


func _abandon_deposit() -> void:
	_is_depositing = false
	_target_bin = null
	_decision_progress = 0.0
	enemy.enter_patrol()


func _pick_trash_bin() -> ContainerFurniture:
	var candidates: Array[ContainerFurniture] = []
	for n in enemy.get_tree().get_nodes_in_group(&"diary_bin"):
		if n is ContainerFurniture and n != enemy.paranoid_last_used_bin:
			candidates.append(n)

	if candidates.is_empty():
		# Only the last-used bin exists (or none tagged at all) - allow a
		# repeat rather than never depositing again.
		for n in enemy.get_tree().get_nodes_in_group(&"diary_bin"):
			if n is ContainerFurniture:
				candidates.append(n)

	if candidates.is_empty():
		push_warning("ParanoidModule: no nodes in group 'diary_bin' - cannot start a deposit walk.")
		return null

	return candidates[randi() % candidates.size()]


func process_special(delta: float) -> void:
	if _finishing_deposit:
		return
	if not _is_depositing or _target_bin == null or not is_instance_valid(_target_bin):
		enemy.enter_patrol()
		return

	if _is_turning:
		_turn_phase_timer -= delta
		if _turn_phase_timer <= 0.0:
			match _turn_phase:
				_TurnPhase.WARNING:
					_turn_phase = _TurnPhase.LOOK_BEHIND
					_turn_phase_timer = LOOK_BEHIND_DURATION
					enemy.is_turn_warning = false
					# Turn now - held for the whole look-behind phase, giving
					# him a real chance to catch the player stalking.
					enemy.anim_handler.set_facing_direction(_opposite_direction(enemy.anim_handler.last_direction))
				_TurnPhase.LOOK_BEHIND:
					_is_turning = false
		return # frozen for both beats - no movement, facing held throughout

	_turn_check_timer += delta
	if _turn_check_timer >= TURN_CHECK_INTERVAL:
		_turn_check_timer = 0.0
		if randf() < enemy.profile.turn_around_chance:
			_is_turning = true
			_turn_phase = _TurnPhase.WARNING
			_turn_phase_timer = enemy.profile.turn_around_warning_time
			enemy.is_turn_warning = true
			return

	enemy.escort_step_toward(_target_bin.global_position, delta, enemy.profile.move_speed)

	if enemy.global_position.distance_to(_target_bin.global_position) <= ARRIVAL_DISTANCE:
		_perform_deposit()


func _perform_deposit() -> void:
	_finishing_deposit = true
	enemy.velocity = Vector2.ZERO
	enemy.anim_handler.handle_interaction_anim(Interactions.InteractionType.OPEN)
	await enemy.anim_handler.interact_anim_finish

	if is_instance_valid(_target_bin) and enemy.paranoid_deposited_count < enemy.profile.reward_items.size():
		_target_bin.add_item(enemy.profile.reward_items[enemy.paranoid_deposited_count])
		enemy.paranoid_deposited_count += 1
		enemy.paranoid_last_used_bin = _target_bin

	_target_bin = null
	_is_depositing = false
	_decision_progress = 0.0
	_finishing_deposit = false
	enemy.enter_patrol()


func _opposite_direction(direction: String) -> String:
	match direction:
		"up": return "down"
		"down": return "up"
		"left": return "right"
		_: return "left"
