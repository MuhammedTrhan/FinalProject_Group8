class_name EscortController
extends Node
## 3-lives catch funnel: the first two catches in a run walk the player back
## toward her room (herded just ahead of the enemy) and end the day right
## away; only the 3rd catch is the real, permanent game-over.
##
## Also runs the same walk-home beat before the day ends naturally, so it
## fully plays out BEFORE night begins rather than overlapping the day/night
## fade: day -> escort -> night. Two phases, both spent actually walking
## (never frozen in place):
## - WALKING_HOME: a catch self-times this (nothing external tells it when
##   to stop) and ends by asking Dev1 to start the night right away via
##   night_start_requested. A natural escort starts on GameEvents.day_ended
##   and ends on GameEvents.night_ended (Dev1's own timing, not a number
##   Dev2 has to match) - falling back to the same self-timed cap if
##   night_ended isn't wired yet.
## - LOCKING_IN: both cases keep walking here too (this is meant to overlap
##   Dev1's actual fadeout) until GameEvents.night_started fires, which is
##   when the escort actually finishes - guaranteed snap to the lockdown
##   positions, door locked, player gets control back. A short fallback
##   timer also finishes it if night_started doesn't arrive, which is what
##   keeps catches working today, since nothing consumes night_start_requested
##   yet.
##
## Kept as its own node (a back-reference to the owning Enemy, set once from
## outside) rather than growing Enemy.gd or PlayerMovement.gd further.

## Set by Enemy, first thing in _ready() - before anything else touches it.
var enemy: Enemy

const MAX_LIVES := 3
## WALKING_HOME's length: a catch always self-times this (no external signal
## exists for it); a natural escort only falls back to it if night_ended
## isn't wired yet. Matches the ~5s lead time requested of Dev1 for day_ended.
const ESCORT_DURATION := 5.0
## LOCKING_IN's fallback cap, in case night_started never arrives (keeps
## catches working today, since Dev1 doesn't consume night_start_requested
## yet). Deliberately well above the real fadeout's actual length (~0.5s
## elsewhere in this codebase) so that once night_start_requested IS wired,
## the real night_started signal always wins the race and this almost never
## actually fires - it's a last-resort recovery, not a stand-in for the fade.
const LOCK_IN_FALLBACK_DELAY := 2.0
const ESCORT_APPROACH_DISTANCE := 40.0  # "hop next to player" lands this close - not touching
## How far ahead of the enemy the player is herded while walking home.
const ESCORT_LEAD_DISTANCE := 18.0

enum _Phase { WALKING_HOME, LOCKING_IN }

var _lives_remaining: int = MAX_LIVES
var _run_over: bool = false
var _escorting: bool = false
var _phase: _Phase = _Phase.WALKING_HOME
var _phase_timer: float = 0.0
## True while the escort in progress was triggered by a catch (self-timed,
## ends WALKING_HOME by requesting night_start_requested); false for a
## natural, day_ended/night_ended-driven escort.
var _escort_triggered_by_catch: bool = false
var _escort_target: Vector2
## Guards against the night_started fallback-start re-starting a second
## natural escort after one already ran (via day_ended or a catch) this
## day/night cycle. Reset each new day.
var _did_escort_this_cycle: bool = false


func _ready() -> void:
	GameEvents.run_started.connect(_on_run_started)
	GameEvents.day_ended.connect(_on_day_ended)
	GameEvents.night_ended.connect(_on_night_ended)
	GameEvents.night_started.connect(_on_night_started)
	GameEvents.day_started.connect(_on_day_started)


func _on_run_started(_run_seed: int) -> void:
	_lives_remaining = MAX_LIVES
	_run_over = false
	_escorting = false
	_did_escort_this_cycle = false


## Every site that used to call GameEvents.player_caught.emit(reason) directly
## now funnels through here. Only the 3rd catch of a run is the real,
## permanent game-over - the first two trigger a walk-home beat and end the
## day early instead.
func register_catch(reason: StringName) -> void:
	if _run_over or _escorting or enemy.is_teleporting:
		return

	_lives_remaining -= 1
	if _lives_remaining <= 0:
		_run_over = true
		GameEvents.player_caught.emit(reason)  # unchanged meaning: final, permanent game-over
		return

	_start_escort(true)


func is_escorting() -> bool:
	return _escorting


## Called by Enemy every physics frame while _escorting is true, instead of
## its normal state-machine dispatch. Both phases keep walking toward the
## room the whole time - only the phase transitions differ in what they check.
func process(delta: float) -> void:
	_walk_step(delta)
	_phase_timer += delta

	match _phase:
		_Phase.WALKING_HOME:
			# Catches always self-time (no external end signal exists for
			# them); naturals only fall back to the same timer if
			# night_ended isn't wired yet - real night_ended cuts this
			# short via _on_night_ended() instead.
			if _phase_timer >= ESCORT_DURATION:
				_enter_locking_in()
		_Phase.LOCKING_IN:
			if _phase_timer >= LOCK_IN_FALLBACK_DELAY:
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
	_did_escort_this_cycle = true
	_escort_triggered_by_catch = triggered_by_catch
	_phase = _Phase.WALKING_HOME
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


## WALKING_HOME -> LOCKING_IN. A catch additionally asks Dev1 to start the
## night right away here - this IS "when the 5s ends" for a catch.
func _enter_locking_in() -> void:
	if _escort_triggered_by_catch:
		GameEvents.night_start_requested.emit(&"caught")
	_phase = _Phase.LOCKING_IN
	_phase_timer = 0.0


## Ends the escort (both phases done) - guarantees both actors actually end
## up at the room door (enemy at the guard point, player at her spawn)
## regardless of how far the walk actually got, locks the door, and gives
## the player control back.
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


## Natural-timeout start trigger (primary, once Dev1 wires it).
func _on_day_ended(_day: int) -> void:
	if not _escorting and not _did_escort_this_cycle:
		_start_escort(false)


## Natural-timeout end-of-WALKING_HOME trigger (primary, once Dev1 wires it) -
## only acts while an in-progress natural escort is actually still walking home.
func _on_night_ended(_day: int) -> void:
	if _escorting and not _escort_triggered_by_catch and _phase == _Phase.WALKING_HOME:
		_enter_locking_in()


## Two roles: (1) the real end-of-LOCKING_IN trigger for any in-progress
## escort, catch or natural. (2) fallback start for a natural escort, only
## used for as long as day_ended isn't wired yet - guarded by
## _did_escort_this_cycle so it can't double-start once day_ended IS wired
## and already handled this cycle.
func _on_night_started(_day: int) -> void:
	if _escorting:
		if _phase == _Phase.LOCKING_IN:
			_finish_escort()
		return
	if not _did_escort_this_cycle:
		_start_escort(false)


## Safety net: always unlock the room door on a new day, even if nothing else
## touches it (also fires on F1's personality-cycle day_started, harmlessly).
func _on_day_started(_day: int, _personality: int) -> void:
	_did_escort_this_cycle = false
	var door := get_tree().get_first_node_in_group(&"player_room_door")
	if door and door.is_locked:
		door.toogle_lock()
