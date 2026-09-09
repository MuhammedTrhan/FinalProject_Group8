class_name EscortController
extends Node
## 3-lives catch funnel: the first two catches in a run freeze both actors for
## a brief "escorted back to her room" beat and end the day right away.
##
## Also runs the same escort beat when the day times out naturally, and owns
## the snap-back-to-spawn (+ room door lock/unlock) that follows every escort.

## Set by Enemy, first thing in _ready() - before anything else touches it.
var enemy: Enemy

const MAX_LIVES := 3
const ESCORT_DURATION := 4.0            # tunable, 3-5s
const ESCORT_APPROACH_DISTANCE := 40.0  # "hop next to player" lands this close - not touching
## Matches DayTransition's fade length - a stopgap until day/night_started
## fire at fade-end instead of fade-start when the signal is written.
const SPAWN_SNAP_FADE_DELAY := 0.5

var _lives_remaining: int = MAX_LIVES
var _run_over: bool = false
var _escorting: bool = false
var _escort_timer: float = 0.0
## True while the escort in progress was triggered by a catch (day_end_requested
## fires at the end); false for a natural day-timeout escort (day already ended).
var _escort_triggered_by_catch: bool = false


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
## its normal state-machine dispatch.
func process(delta: float) -> void:
	enemy.velocity = Vector2.ZERO
	_escort_timer += delta
	if _escort_timer >= ESCORT_DURATION:
		_end_escort()


func _start_escort(triggered_by_catch: bool) -> void:
	_escorting = true
	_escort_triggered_by_catch = triggered_by_catch
	_escort_timer = 0.0
	enemy.velocity = Vector2.ZERO

	var player := enemy.perception.get_player()
	if player and enemy.global_position.distance_to(player.global_position) > ESCORT_APPROACH_DISTANCE:
		enemy.global_position = player.global_position \
			+ (enemy.global_position - player.global_position).normalized() * ESCORT_APPROACH_DISTANCE

	if player and is_instance_valid(player) and player.has_method("stop_player_movement"):
		player.stop_player_movement()


func _end_escort() -> void:
	# Emit BEFORE clearing _escorting: if this synchronously causes GameManager
	# to fire night_started, the re-entrant _on_night_started must still see
	# _escorting == true so it doesn't start a redundant second escort.
	if _escort_triggered_by_catch:
		GameEvents.day_end_requested.emit(&"caught")
	_escorting = false

	var player := enemy.perception.get_player()
	if player and is_instance_valid(player) and player.has_method("resume_player_movement"):
		player.resume_player_movement()

	_schedule_snap(true)  # every escort, catch or natural, ends the night this way


func _on_night_started(_day: int) -> void:
	if not _escorting:
		_start_escort(false)  # natural day-timeout, no catch involved


func _on_day_started(_day: int, _personality: int) -> void:
	_schedule_snap(false)  # day always unlocks the room - unconditional safety net


func _schedule_snap(is_night: bool) -> void:
	get_tree().create_timer(SPAWN_SNAP_FADE_DELAY).timeout.connect(func(): _snap_to_spawn(is_night))


## Repositions the enemy (to the room door guard point, locking/unlocking the
## door) and the player (to PlayerSpawnPoint), once the screen is already black.
func _snap_to_spawn(is_night: bool) -> void:
	var door := get_tree().get_first_node_in_group(&"player_room_door")
	var guard_point := enemy.get_parent().get_node_or_null("DoorGuardPoint")

	if door and guard_point:
		enemy.global_position = guard_point.global_position
		if is_night:
			if door.is_open:
				door.close_door()
			if not door.is_locked:
				door.toogle_lock()
		else:
			if door.is_locked:
				door.toogle_lock()
	# Fallback: if the door or guard point is missing, just snap to the EnemySpawnPoint instead.
	else:
		var enemy_spawn := enemy.get_parent().get_node_or_null("EnemySpawnPoint")
		if enemy_spawn:
			enemy.global_position = enemy_spawn.global_position  # fallback: no door involved

	enemy.velocity = Vector2.ZERO
	enemy.reset_patrol_for_current_position()

	var player := enemy.perception.get_player()
	var player_spawn := enemy.get_parent().get_node_or_null("PlayerSpawnPoint")
	if player and player_spawn and player.has_method("snap_to_spawn"):
		player.snap_to_spawn(player_spawn.global_position)
