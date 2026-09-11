class_name EscortController
extends Node
## Manages the 3-lives catch funnel and the full night routine. The first
## two catches herd the player to her room and end the day early; the 3rd
## catch triggers a permanent game-over.
##
## Also handles the natural walk-home beat before night falls. Escorting
## blocks the Enemy's normal state machine entirely throughout the night
## using this sequence:
## WALKING_HOME -> LOCKING_IN -> WALKING_TO_GUARD -> WAITING_AT_SPAWN -> UNLOCKING -> WAKE
##
## - WALKING_HOME: Self-timed for catches, or uses day_ended/night_ended
##   signals for natural escorts.
## - LOCKING_IN: Overlaps the day/night fade until night_started fires.
## - WALKING_TO_GUARD: Both are snapped to her spawn, she's frozen, and the
##   enemy walksto the door guard point.
## - WAITING_AT_SPAWN: The door is locked, she regains control, and
##   the enemywaits at EnemySpawnPoint until day_started signals true morning.
## - UNLOCKING: Enemy walks to the door and unlocks it (has a
##   fallback timeout to prevent permanent soft-locks).
## - WALKING_TO_WAKE: Enemy walks to the active personality's wake marker,
##   then returns control to its normal state machine.
##
## Abstracted into its own node to keep Enemy.gd and PlayerMovement.gd clean.

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
const ESCORT_APPROACH_DISTANCE := 40.0 # "hop next to player" lands this close - not touching
## How far ahead of the enemy the player is herded while walking home.
const ESCORT_LEAD_DISTANCE := 18.0
## "Close enough" for the night routine's UNLOCKING/WALKING_TO_WAKE legs.
const NIGHT_ROUTINE_ARRIVAL_DISTANCE := 12.0
## Generous safety nets for the night routine's back half - these aren't
## time-critical like the pre-night beats, they just must never soft-lock
## the door shut or leave the enemy stuck forever if pathing fails.
const UNLOCK_FALLBACK_DURATION := 15.0
const WAKE_WALK_FALLBACK_DURATION := 20.0
## Same "generous, not time-critical" role as the two above, for the
## WALKING_TO_GUARD leg.
const LOCK_WALK_FALLBACK_DURATION := 5.0

enum _Phase {WALKING_HOME, LOCKING_IN, WALKING_TO_GUARD, WAITING_AT_SPAWN, UNLOCKING, WALKING_TO_WAKE}

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
## True while a door open/close/lock/unlock animation is being awaited, so
## process() doesn't re-enter to a state (or keep walking) while one is playing.
var _door_anim_in_progress: bool = false


func _ready() -> void:
	GameEvents.run_started.connect(_on_run_started)
	GameEvents.day_ended.connect(_on_day_ended)
	GameEvents.night_ended.connect(_on_night_ended)
	GameEvents.night_started.connect(_on_night_started)
	GameEvents.day_started.connect(_on_day_started)
	GameEvents.clue_revealed.connect(_on_clue_revealed)


## Called once by Enemy._ready(), first thing - the run always opens on
## Night 1 with both already at their spawns and the door not yet locked,
## so there's no WALKING_HOME leg to run. Seeds the state as if that leg had
## just finished, so night_started's normal handling below plays out
## unchanged for the opening night too - and disables her input immediately,
## since there's no preceding walk-home to have done that already.
func begin_opening_night() -> void:
	_escorting = true
	_did_escort_this_cycle = true
	_phase = _Phase.LOCKING_IN
	_phase_timer = 0.0

	var player := enemy.perception.get_player()
	if player and is_instance_valid(player) and player.has_method("start_escort"):
		player.start_escort()


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
		GameEvents.player_caught.emit(reason) # unchanged meaning: final, permanent game-over
		return

	_start_escort(true)


func is_escorting() -> bool:
	return _escorting


## Called by Enemy every physics frame while _escorting is true, instead of
## its normal state-machine dispatch. WALKING_HOME/LOCKING_IN also puppet the
## player; the night-routine phases after that only move the enemy.
func process(delta: float) -> void:
	_phase_timer += delta

	match _phase:
		_Phase.WALKING_HOME:
			_walk_step_with_player(delta)
			# Catches always self-time (no external end signal exists for
			# them); naturals only fall back to the same timer if
			# night_ended isn't wired yet - real night_ended cuts this
			# short via _on_night_ended() instead.
			if _phase_timer >= ESCORT_DURATION:
				_enter_locking_in()
		_Phase.LOCKING_IN:
			_walk_step_with_player(delta)
			if _phase_timer >= LOCK_IN_FALLBACK_DELAY:
				_enter_walking_to_guard()
		_Phase.WALKING_TO_GUARD:
			if _door_anim_in_progress:
				return
			_enemy_walk_step(delta)
			if _has_arrived_at(_escort_target) or _phase_timer >= LOCK_WALK_FALLBACK_DURATION:
				_enter_waiting_at_spawn()
		_Phase.WAITING_AT_SPAWN:
			_enemy_walk_step(delta)
			# Ends only on day_started (_on_day_started) - see class doc.
		_Phase.UNLOCKING:
			if _door_anim_in_progress:
				return
			_enemy_walk_step(delta)
			if _has_arrived_at(_escort_target) or _phase_timer >= UNLOCK_FALLBACK_DURATION:
				_finish_unlocking()
		_Phase.WALKING_TO_WAKE:
			_enemy_walk_step(delta)
			if _has_arrived_at(_escort_target) or _phase_timer >= WAKE_WALK_FALLBACK_DURATION:
				_end_night_routine()


func _walk_step_with_player(delta: float) -> void:
	var direction := enemy.escort_step_toward(_escort_target, delta, enemy.profile.move_speed)

	var player := enemy.perception.get_player()
	if player and is_instance_valid(player) and player.has_method("escort_step"):
		var lead_position := enemy.global_position
		if direction != Vector2.ZERO:
			lead_position += direction * ESCORT_LEAD_DISTANCE
		player.escort_step(lead_position, direction * enemy.profile.move_speed)


## Used by the night-routine phases (after the player already has control
## back) - the enemy walks alone, nobody to herd.
func _enemy_walk_step(delta: float) -> void:
	enemy.escort_step_toward(_escort_target, delta, enemy.profile.move_speed)


func _has_arrived_at(target: Vector2) -> bool:
	return FloorZones.get_floor(enemy.global_position) == FloorZones.get_floor(target) \
		and enemy.global_position.distance_to(target) <= NIGHT_ROUTINE_ARRIVAL_DISTANCE


func _start_escort(triggered_internally: bool) -> void:
	_escorting = true
	_did_escort_this_cycle = true
	_escort_triggered_by_catch = triggered_internally
	_phase = _Phase.WALKING_HOME
	_phase_timer = 0.0
	enemy.velocity = Vector2.ZERO

	var player := enemy.perception.get_player()
	if player and enemy.global_position.distance_to(player.global_position) > ESCORT_APPROACH_DISTANCE:
		enemy.global_position = player.global_position \
			+ (enemy.global_position - player.global_position).normalized() * ESCORT_APPROACH_DISTANCE

	_escort_target = _resolve_door_guard_target()

	if player and is_instance_valid(player) and player.has_method("start_escort"):
		player.start_escort()


## The door guard point (WALKING_TO_GUARD/UNLOCKING walk here) - falls back
## to the enemy's spawn point if the marker's missing so this is always
## safe to call.
func _resolve_door_guard_target() -> Vector2:
	var guard_point := enemy.get_parent().get_node_or_null("DoorGuardPoint")
	if _phase == _Phase.WALKING_HOME:
		var player_spawn := enemy.get_parent().get_node_or_null("PlayerSpawnPoint")
		if player_spawn:
			return player_spawn.global_position
		# Fallback: if the player spawn is missing, use the guard point if it exists.
		elif guard_point:
			return guard_point.global_position
	else:
		if guard_point:
			return guard_point.global_position

	var enemy_spawn := enemy.get_parent().get_node_or_null("EnemySpawnPoint")
	return enemy_spawn.global_position if enemy_spawn else enemy.global_position # last-resort: don't crash, just stop in place


## WALKING_HOME -> LOCKING_IN. A catch additionally asks Dev1 to start the
## night right away here - this IS "when the 5s ends" for a catch.
func _enter_locking_in() -> void:
	if _escort_triggered_by_catch:
		GameEvents.night_start_requested.emit(&"caught")
	_phase = _Phase.LOCKING_IN
	_phase_timer = 0.0


## LOCKING_IN -> WALKING_TO_GUARD. This is where the escort's actual
## "arrival at home" happens regardless of how far the timed walk really
## got: guaranteed snap of both to her spawn, player frozen (idempotent -
## also covers Night 1, which has no preceding WALKING_HOME leg to have
## frozen her already), then the enemy walks to the guard point.
func _enter_walking_to_guard() -> void:
	var player_spawn: Node2D = enemy.get_parent().get_node_or_null("PlayerSpawnPoint")
	var spawn_pos: Vector2 = player_spawn.global_position if player_spawn else enemy.global_position
	enemy.global_position = spawn_pos
	enemy.velocity = Vector2.ZERO

	var player := enemy.perception.get_player()
	if player and is_instance_valid(player):
		if player.has_method("snap_to_spawn"):
			player.snap_to_spawn(spawn_pos)
		if player.has_method("start_escort"):
			player.start_escort()

	_phase = _Phase.WALKING_TO_GUARD
	_phase_timer = 0.0
	_escort_target = _resolve_door_guard_target() # DoorGuardPoint, since _phase != WALKING_HOME


## WALKING_TO_GUARD -> WAITING_AT_SPAWN, once the enemy has actually arrived
## at the guard point. Locks the door, then hands control back to the player
## nothing after this point touches the player again,
## only the enemy's own night routine.
func _enter_waiting_at_spawn() -> void:
	if _door_anim_in_progress:
		return
	_door_anim_in_progress = true
	enemy.velocity = Vector2.ZERO

	await _lock_room_door()

	var player := enemy.perception.get_player()
	if player and is_instance_valid(player) and player.has_method("end_escort"):
		player.end_escort() # released only after the door is actually locked

	_door_anim_in_progress = false
	_phase = _Phase.WAITING_AT_SPAWN
	_phase_timer = 0.0
	var enemy_spawn := enemy.get_parent().get_node_or_null("EnemySpawnPoint")
	_escort_target = enemy_spawn.global_position if enemy_spawn else enemy.global_position


## WAITING_AT_SPAWN -> UNLOCKING, triggered by day_started (see _on_day_started).
func _enter_unlocking() -> void:
	_phase = _Phase.UNLOCKING
	_phase_timer = 0.0
	_escort_target = _resolve_door_guard_target()


## UNLOCKING -> WALKING_TO_WAKE (or straight to the end if there's no wake
## marker for the active personality yet). Unlocks the door with its
## animation, freezing the enemy at the guard point for it.
func _finish_unlocking() -> void:
	if _door_anim_in_progress:
		return
	_door_anim_in_progress = true

	var door := get_tree().get_first_node_in_group(&"player_room_door")
	await enemy.unlock_room_door(door)

	_door_anim_in_progress = false

	var wake_point := _resolve_wake_point()
	if wake_point == null:
		_end_night_routine()
		return

	_phase = _Phase.WALKING_TO_WAKE
	_phase_timer = 0.0
	_escort_target = wake_point.global_position


## Exact child name of the level root, e.g. "WakePoint_FORGETFUL" -
## Returns null gracefully if the profile or the marker aren't set up yet.
func _resolve_wake_point() -> Node:
	if enemy.profile == null:
		return null
	var personality_name: String = str(PersonalityProfile.Personality.keys()[enemy.profile.personality])
	return enemy.get_parent().get_node_or_null("WakePoint_%s" % personality_name)


## The actual end of the whole night routine - hands control back to Enemy's
## normal state machine (Patrol etc.), re-reading patrol points for wherever
## the enemy actually ended up.
func _end_night_routine() -> void:
	_escorting = false
	enemy.velocity = Vector2.ZERO
	enemy.reset_patrol_for_current_position()


func _lock_room_door() -> void:
	var door := get_tree().get_first_node_in_group(&"player_room_door")
	if door == null:
		return
	await enemy.close_and_lock_room_door(door)


## Natural-timeout start trigger (primary, once Dev1 wires it).
func _on_day_ended(_day: int) -> void:
	if not _escorting and not _did_escort_this_cycle:
		_start_escort(false)


## Natural-timeout end-of-WALKING_HOME trigger (primary, once Dev1 wires it) -
## only acts while an in-progress natural escort is actually still walking home.
func _on_night_ended(_day: int) -> void:
	if _escorting and not _escort_triggered_by_catch and _phase == _Phase.WALKING_HOME:
		_enter_locking_in()


## Three roles: (1) the real end-of-LOCKING_IN trigger for any in-progress
## escort, catch or natural - moves it into WAITING_AT_SPAWN. (2) fallback
## start for a natural escort, only used for as long as day_ended isn't
## wired yet - guarded by _did_escort_this_cycle so it can't double-start
## once day_ended IS wired and already handled this cycle. (3) while neither
## of those apply (e.g. mid-night-routine already), does nothing.
func _on_night_started(_day: int) -> void:
	if _escorting:
		if _phase == _Phase.LOCKING_IN:
			_enter_walking_to_guard()
		return
	if not _did_escort_this_cycle:
		_start_escort(false)


## Finding a clue ends the day early, same as a non-lethal catch - snaps
## near the player and walks her home - but doesn't cost a life.
func _on_clue_revealed(_digit_index: int, _digit_value: int, _flavour: String) -> void:
	if _run_over or _escorting or enemy.is_teleporting:
		return
	_start_escort(true)


## day_started alone drives WAITING_AT_SPAWN ->
## UNLOCKING for the real night routine. Anything else that fires
## day_started (F1's personality-cycle debug press, or any state that isn't
## a completed night routine) just unlocks the door directly as a safety net.
func _on_day_started(_day: int, _personality: int) -> void:
	_did_escort_this_cycle = false

	if _escorting and _phase == _Phase.WAITING_AT_SPAWN:
		_enter_unlocking()
		return

	var door := get_tree().get_first_node_in_group(&"player_room_door")
	if door and door.is_locked:
		door.toogle_lock()
