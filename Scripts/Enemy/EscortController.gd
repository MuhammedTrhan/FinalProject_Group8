class_name EscortController
extends Node
## 3-lives catch funnel: the first two catches in a run walk the player back
## toward her room (herded just ahead of the enemy) and end the day right away;
## only the 3rd catch is the real, permanent game-over.
##
## Also runs the same walk-home beat when the day times out naturally with no
## catch at all. Once it ends (arrival or timeout) both actors are snapped to
## their lockdown positions, and the room door is locked. Kept as its own node
## (a back-reference to the owning Enemy, set once from outside).

## Set by Enemy, first thing in _ready() - before anything else touches it.
var enemy: Enemy

const MAX_LIVES := 3
## WALKING phase cap. Ends earlier if they arrive at the target first.
const ESCORT_DURATION := 4.0
## FADING phase length - matches DayTransition's fade length. A stopgap
## until day/night_started fire at fade-end instead of fade-start; remove
## this (and just snap on that signal) once Dev1 makes that change.
const SPAWN_SNAP_FADE_DELAY := 0.5
const ESCORT_APPROACH_DISTANCE := 40.0  # "hop next to player" lands this close - not touching
const ESCORT_ARRIVAL_DISTANCE := 12.0
## How far ahead of the enemy the player is herded while walking home.
const ESCORT_LEAD_DISTANCE := 18.0

enum _Phase { WALKING, FADING }

var _lives_remaining: int = MAX_LIVES
var _run_over: bool = false
var _escorting: bool = false
var _phase: _Phase = _Phase.WALKING
var _phase_timer: float = 0.0
## True while the escort in progress was triggered by a catch (day_end_requested
## fires at the end of WALKING); false for a natural day-timeout escort (day
## already ended, nothing to request).
var _escort_triggered_by_catch: bool = false
var _escort_target: Vector2


func _ready() -> void:
	GameEvents.run_started.connect(_on_run_started)
	GameEvents.night_started.connect(_on_night_started)
	GameEvents.day_started.connect(_on_day_started)


func _on_run_started(_run_seed: int) -> void:
	_lives_remaining = MAX_LIVES
	_run_over = false
	_escorting = false


## Only the 3rd catch of a run is the game-over.
## The first two trigger an escort and end the day early.
func register_catch(reason: StringName) -> void:
	if _run_over or _escorting or enemy.is_teleporting:
		return

	_lives_remaining -= 1
	if _lives_remaining <= 0:
		_run_over = true
		GameEvents.player_caught.emit(reason)  # final, permanent game-over
		return

	_start_escort(true)


func is_escorting() -> bool:
	return _escorting


## Called by Enemy every physics frame while _escorting is true, instead of
## its normal state-machine dispatch. Both phases keep walking toward the
## room the whole time - only the phase transitions differ in what they check.
func process(delta: float) -> void:
	_phase_timer += delta
	_walk_step(delta)

	match _phase:
		_Phase.WALKING:
			var arrived := FloorZones.get_floor(enemy.global_position) == FloorZones.get_floor(_escort_target) \
				and enemy.global_position.distance_to(_escort_target) <= ESCORT_ARRIVAL_DISTANCE
			if arrived or _phase_timer >= ESCORT_DURATION:
				if _escort_triggered_by_catch:
					GameEvents.day_end_requested.emit(&"caught")
				_phase = _Phase.FADING
				_phase_timer = 0.0
		_Phase.FADING:
			if _phase_timer >= SPAWN_SNAP_FADE_DELAY:
				_finish_escort()


func _walk_step(delta: float) -> void:
	var direction := enemy.escort_step_toward(_escort_target, delta, enemy.profile.move_speed)

	var player := enemy.perception.get_player()
	if player and is_instance_valid(player) and player.has_method("escort_step"):
		var lead_position := enemy.global_position
		if direction != Vector2.ZERO:
			lead_position += direction * ESCORT_LEAD_DISTANCE
		player.escort_step(lead_position, direction * enemy.profile.move_speed)


func _start_escort(triggered_by_catch: bool) -> void:
	_escorting = true
	_escort_triggered_by_catch = triggered_by_catch
	_phase = _Phase.WALKING
	_phase_timer = 0.0
	enemy.velocity = Vector2.ZERO

	var player := enemy.perception.get_player()
	if player and enemy.global_position.distance_to(player.global_position) > ESCORT_APPROACH_DISTANCE:
		enemy.global_position = player.global_position \
			+ (enemy.global_position - player.global_position).normalized() * ESCORT_APPROACH_DISTANCE

	_escort_target = _resolve_escort_target()

	if player and is_instance_valid(player) and player.has_method("start_escort"):
		player.start_escort()


func _resolve_escort_target() -> Vector2:
	var guard_point := enemy.get_parent().get_node_or_null("DoorGuardPoint")
	if guard_point:
		return guard_point.global_position

	# Safety net: if the door marker is missing, just walk to the enemy's spawn point instead.
	var enemy_spawn := enemy.get_parent().get_node_or_null("EnemySpawnPoint")
	return enemy_spawn.global_position if enemy_spawn else enemy.global_position  # last-resort: don't crash, just stop in place


## Ends the whole escort (WALKING + FADING both done) - guarantees both
## actors actually end up at the room door (enemy at the guard point, player
## at her spawn), locks the door, and gives the player control back.
func _finish_escort() -> void:
	_escorting = false

	var guard_point := enemy.get_parent().get_node_or_null("DoorGuardPoint")
	if guard_point:
		enemy.global_position = guard_point.global_position
	else:
		var enemy_spawn := enemy.get_parent().get_node_or_null("EnemySpawnPoint")
		if enemy_spawn:
			enemy.global_position = enemy_spawn.global_position  # fallback: no door involved

	enemy.velocity = Vector2.ZERO
	enemy.reset_patrol_for_current_position()
	_lock_room_door()

	var player := enemy.perception.get_player()
	var player_spawn := enemy.get_parent().get_node_or_null("PlayerSpawnPoint")
	if player and is_instance_valid(player):
		if player_spawn and player.has_method("snap_to_spawn"):
			player.snap_to_spawn(player_spawn.global_position)
		if player.has_method("end_escort"):
			player.end_escort()


func _lock_room_door() -> void:
	var door := get_tree().get_first_node_in_group(&"player_room_door")
	if door == null:
		return
	if door.is_open:
		door.close_door()
	if not door.is_locked:
		door.toogle_lock()


func _on_night_started(_day: int) -> void:
	if not _escorting:
		_start_escort(false)  # natural day-timeout, no catch involved


## Safety net: always unlock the room door on a new day, even if nothing else
## touches it (also fires on F1's personality-cycle day_started, harmlessly).
func _on_day_started(_day: int, _personality: int) -> void:
	var door := get_tree().get_first_node_in_group(&"player_room_door")
	if door and door.is_locked:
		door.toogle_lock()
