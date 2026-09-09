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
## The walk-home beat's cap. Ends earlier if they arrive at the target.
const ESCORT_DURATION := 4.0
## Matches DayTransition's fade length - a stopgap until day/night_started
## fire at fade-end instead of fade-start. Remove this once the Dev-1
## creates a signal for fade-end and we can hook into that instead.
const SPAWN_SNAP_FADE_DELAY := 0.5
const ESCORT_APPROACH_DISTANCE := 40.0  # "hop next to player" lands this close - not touching
const ESCORT_ARRIVAL_DISTANCE := 12.0
## How far ahead of the enemy the player is herded while walking home.
const ESCORT_LEAD_DISTANCE := 18.0

var _lives_remaining: int = MAX_LIVES
var _run_over: bool = false
var _escorting: bool = false
var _escort_timer: float = 0.0
## True while the escort in progress was triggered by a catch (day_end_requested
## fires at the end); false for a natural day-timeout escort (day already ended).
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
## its normal state-machine dispatch.
func process(delta: float) -> void:
	_escort_timer += delta

	var direction := enemy.escort_step_toward(_escort_target, enemy.profile.move_speed)

	var player := enemy.perception.get_player()
	if player and is_instance_valid(player) and player.has_method("escort_step"):
		var lead_position := enemy.global_position
		if direction != Vector2.ZERO:
			lead_position += direction * ESCORT_LEAD_DISTANCE
		player.escort_step(lead_position, direction * enemy.profile.move_speed)

	var arrived := FloorZones.get_floor(enemy.global_position) == FloorZones.get_floor(_escort_target) \
		and enemy.global_position.distance_to(_escort_target) <= ESCORT_ARRIVAL_DISTANCE
	if arrived or _escort_timer >= ESCORT_DURATION:
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

	_escort_target = _resolve_escort_target()

	if player and is_instance_valid(player) and player.has_method("start_escort"):
		player.start_escort()


func _resolve_escort_target() -> Vector2:
	var guard_point := enemy.get_parent().get_node_or_null("DoorGuardPoint")
	if guard_point:
		return guard_point.global_position
	
	# Safety net: if the door is missing, just walk to the enemy's spawn point instead.
	var enemy_spawn := enemy.get_parent().get_node_or_null("EnemySpawnPoint")
	return enemy_spawn.global_position if enemy_spawn else enemy.global_position  # last-resort: don't crash, just stop in place


## Ends the walk-home beat and gives the player control back right away. A
## real trip to the room usually won't have actually finished by now, so
## _schedule_snap() separately guarantees both actors end up in the right
## place a beat later, once the screen should already be black.
func _end_escort() -> void:
	# Emit BEFORE clearing _escorting: if this synchronously causes GameManager
	# to fire night_started, the re-entrant _on_night_started must still see
	# _escorting == true so it doesn't start a redundant second escort.
	if _escort_triggered_by_catch:
		GameEvents.day_end_requested.emit(&"caught")
	_escorting = false

	var player := enemy.perception.get_player()
	if player and is_instance_valid(player) and player.has_method("end_escort"):
		player.end_escort()

	_schedule_snap()


func _schedule_snap() -> void:
	get_tree().create_timer(SPAWN_SNAP_FADE_DELAY).timeout.connect(_snap_to_lockdown_positions)


## Guarantees both actors actually end up at the room door (enemy at the
## guard point, player at her spawn) and locks the door behind them.
func _snap_to_lockdown_positions() -> void:
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
	if player and player_spawn and player.has_method("snap_to_spawn"):
		player.snap_to_spawn(player_spawn.global_position)


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
