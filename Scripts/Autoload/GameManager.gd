extends Node
## Owns the day/night cycle and which personality is awake. Talks to the rest
## of the game only through GameEvents.

## ESCORT is the gap between the day ending and night beginning: she can't act,
## but the enemy still has to walk her home and that has to be visible.
enum Phase {DAY, ESCORT, NIGHT}

const PLAYER_SCENE = preload("res://Scenes/player.tscn")
const ENEMY_SCENE = preload("res://Scenes/Enemy/enemy.tscn")

# 3 passcode digits: 0=UV floor, 1=floorboard, 2=diary.
const PASSCODE_LENGTH := 3

## Whose reward unlocks each digit - Overwhelmed gives the UV flashlight,
## Forgetful the crowbar, Paranoid the diary scraps. A clue retires this
## personality rather than whoever is awake, because the scraps are combined
## in the inventory and she can do that on any later day.
const DIGIT_OWNERS: Array[PersonalityProfile.Personality] = [
	PersonalityProfile.Personality.OVERWHELMED,
	PersonalityProfile.Personality.FORGETFUL,
	PersonalityProfile.Personality.PARANOID,
]

@export var day_duration_sec: float = 90
@export var night_duration_sec: float = 15
## Matches EscortController.ESCORT_DURATION - change one, change both.
@export var escort_duration_sec: float = 5.0
@export var allow_repeat_personality := false

const PERSONALITIES: Array[PersonalityProfile.Personality] = [
	PersonalityProfile.Personality.FORGETFUL,
	PersonalityProfile.Personality.PARANOID,
	PersonalityProfile.Personality.OVERWHELMED,
]

# Two chances per personality; the run then fails on the day after those,
# which never actually plays.
var max_days: int = PERSONALITIES.size() * 2 + 1

# A run opens on Night 1 and alternates Night N -> Day N -> Night N+1.
var current_day := 1
var current_phase: Phase = Phase.NIGHT
var current_personality: PersonalityProfile.Personality = PersonalityProfile.Personality.FORGETFUL
var run_seed: int = 0

# -1 = digit not found yet. Filled in by clue_revealed.
var passcode_digits: Array[int] = [-1, -1, -1]

const DAY_TRANSITION_SCENE := preload("res://Scenes/day_transition.tscn")
const LOCKDOWN_SCREEN_SCENE := preload("res://Scenes/UI/lockdown_screen.tscn")
const INVENTORY_UI_SCENE := preload("res://Scenes/UI/inventory_ui.tscn")

var _phase_timer: Timer
var _locked_down := false
# True between start_new_run() and returning to the title screen.
var _run_active := false
# The opening night has no clock - it ends once she reads the day-one terminal.
var _waiting_for_terminal := false
# Personalities whose clue was found. They never come back; the ones whose day
# she failed stay in the pool for another turn.
var _retired_personalities: Array[PersonalityProfile.Personality] = []
# Last life count read off EscortController. -1 = not read yet, which must not
# count as a catch. See _process().
var _lives_seen := -1

# These overlays live under this autoload so they survive scene changes, which
# also means they have to be reset by hand.
var _day_transition: CanvasLayer
var _lockdown_screen: CanvasLayer
var _inventory_ui: CanvasLayer

## Fires once the last passcode digit is found. Local signal, not GameEvents.
signal passcode_completed


func _ready() -> void:
	_phase_timer = Timer.new()
	_phase_timer.one_shot = true
	add_child(_phase_timer)
	_phase_timer.timeout.connect(_on_phase_timer_timeout)

	GameEvents.player_caught.connect(_on_player_caught)
	GameEvents.clue_revealed.connect(_on_clue_revealed)
	GameEvents.night_start_requested.connect(_on_night_start_requested)
	GameEvents.computer_interact_requested.connect(_on_computer_interact_requested)
	DayOneTerminal.dossier_closed.connect(_on_dossier_closed)

	_day_transition = DAY_TRANSITION_SCENE.instantiate()
	_lockdown_screen = LOCKDOWN_SCREEN_SCENE.instantiate()
	_inventory_ui = INVENTORY_UI_SCENE.instantiate()
	add_child(_day_transition)
	add_child(_lockdown_screen)
	add_child(_inventory_ui)
	# The main menu's Play button starts the run - starting it here would have
	# the day/night timer ticking at the title screen.


## Loads the level, then starts Night 1. The level has to exist before the
## first signals fire, or the enemy, the escort controller and the doors are
## all still unloaded and miss them.
func start_new_run() -> void:
	_locked_down = false
	_run_active = true
	current_day = 1
	run_seed = randi()
	passcode_digits = [-1, -1, -1]
	_retired_personalities.clear()
	_lives_seen = -1

	get_tree().paused = false
	Inventory.clear()
	_reset_overlays()

	get_tree().change_scene_to_file("res://Scenes/main_level.tscn")
	await get_tree().scene_changed

	ProceduralGenerator.generate(run_seed)
	GameEvents.run_started.emit(run_seed)

	# Night 1 has no clock: it ends once she reads the computer, which is how
	# she learns who she is dealing with before the first day starts.
	_waiting_for_terminal = true
	_day_transition.play_begin_card()

	spawn_player()
	spawn_enemy()
	_start_night()


func spawn_player() -> void:
	if PLAYER_SCENE == null:
		push_warning("PLAYER_SCENE is null - can't spawn player")
		return

	var player_instance = PLAYER_SCENE.instantiate()
	var marker: Node2D = get_tree().current_scene.get_node_or_null("PlayerSpawnPoint")
	var spawn_position: Vector2 = Vector2.ZERO

	if marker != null:
		spawn_position = marker.global_position

	player_instance.global_position = spawn_position
	get_tree().current_scene.add_child(player_instance)


func spawn_enemy() -> void:
	if ENEMY_SCENE == null:
		push_warning("ENEMY_SCENE is null - can't spawn enemy")
		return

	var enemy_instance = ENEMY_SCENE.instantiate()
	var marker: Node2D = get_tree().current_scene.get_node_or_null("EnemySpawnPoint")
	var spawn_position: Vector2 = Vector2.ZERO

	if marker != null:
		spawn_position = marker.global_position

	enemy_instance.global_position = spawn_position
	get_tree().current_scene.add_child(enemy_instance)


## Called by the game-over and win screens. The overlays outlive the scene
## change, so without clearing them they stay drawn on top of the menu.
func return_to_main_menu() -> void:
	_run_active = false
	get_tree().paused = false
	_reset_overlays()
	get_tree().change_scene_to_file("res://Scenes/UI/main_menu.tscn")


func _reset_overlays() -> void:
	_lockdown_screen.visible = false
	_inventory_ui.visible = false
	Hud.visible = false # day_started brings it back
	_day_transition.reset()
	WinScreen.visible = false
	ExitKeypad.visible = false
	DayOneTerminal.visible = false


## Watches for a catch she survived. EscortController only emits player_caught
## on the final one, so the first two are noticed by its life count dropping.
func _process(_delta: float) -> void:
	if not _run_active or _locked_down:
		return

	var enemy := get_tree().get_first_node_in_group(&"enemy")
	if enemy == null:
		return

	var escort = enemy.get("escort_controller")
	if escort == null:
		return

	var remaining = escort.get("_lives_remaining")
	if remaining == null or remaining == _lives_seen:
		return

	var was := _lives_seen
	_lives_seen = remaining

	# Said before the enemy snaps to her and walks her home, or that grab has
	# no explanation. The final catch needs nothing - the game-over screen
	# covers the house and gives the reason itself.
	if was > remaining and remaining > 0:
		_day_transition.show_notice(_catch_notice(escort))


## The same wording the game-over screen uses, so a catch reads the same
## whether it was her last one or not.
func _catch_notice(escort: Node) -> String:
	var reason = escort.get("last_catch_reason")
	if reason == null or reason == &"":
		return "You Have Been Caught"

	return _lockdown_screen.REASON_TEXT.get(reason, "You Have Been Caught")


func is_day() -> bool:
	return current_phase == Phase.DAY


## False whenever something else already owns the pause - the game-over screen,
## the win screen, the terminal - since resuming would hand the house back
## mid-death or mid-read.
func can_pause() -> bool:
	return is_run_interactive()


## Whether the player is actually in control right now.
func is_run_interactive() -> bool:
	return _run_active and not _locked_down and not get_tree().paused


func is_waiting_for_terminal() -> bool:
	return _waiting_for_terminal


## Seconds left in the current phase, or -1 when nothing is on the clock - the
## opening night runs until she reads the computer rather than on a timer.
func get_phase_time_left() -> float:
	return -1.0 if _phase_timer.is_stopped() else _phase_timer.time_left


func _start_day() -> void:
	if current_day >= max_days: # she's out of days - this one never starts
		_fail_run(&"timeout")
		return

	current_phase = Phase.DAY
	current_personality = _pick_personality()

	GameEvents.day_started.emit(current_day, current_personality)
	_phase_timer.start(day_duration_sec)


func _start_night() -> void:
	current_phase = Phase.NIGHT
	GameEvents.night_started.emit(current_day)

	if not _waiting_for_terminal:
		_phase_timer.start(night_duration_sec)


## The day's play is over, but night doesn't begin yet - the enemy gets a
## fixed window to walk her home first, and that walk has to stay visible.
func _end_day() -> void:
	current_phase = Phase.ESCORT
	_day_transition.show_notice("Day Ended")
	GameEvents.day_ended.emit(current_day)
	_phase_timer.start(escort_duration_sec)


## Night begins only once the screen is covered, so her teleport and the
## enemy's personality swap aren't seen.
func _begin_night() -> void:
	current_day += 1
	_day_transition.play_night_card(current_day, _start_night)


func _end_night() -> void:
	GameEvents.night_ended.emit(current_day)
	_day_transition.play_day_card(current_day, _start_day)


## EscortController asks for night after a non-final catch: it has already run
## its own walk-home window, so the escort wait is skipped.
func _on_night_start_requested(_reason: StringName) -> void:
	if _locked_down or current_phase == Phase.NIGHT:
		return

	_phase_timer.stop()
	_begin_night()


## Reading the computer freezes the house around her - the terminal runs with
## process_mode = ALWAYS so its Close button still works.
func _on_computer_interact_requested() -> void:
	get_tree().paused = true
	# The HUD is a later autoload than the terminal, so it draws on top of it.
	Hud.visible = false
	DayOneTerminal.open()


func _on_dossier_closed() -> void:
	get_tree().paused = false
	# Night 1 has no HUD to restore; day_started brings it back below.
	Hud.visible = is_day() and not _locked_down

	# Only Night 1 is gated on the computer; reading it again on a later day
	# just closes the screen and hands the house back.
	if not _waiting_for_terminal:
		return

	_waiting_for_terminal = false
	_phase_timer.stop()
	_end_night()


func _on_phase_timer_timeout() -> void:
	match current_phase:
		Phase.DAY:
			_end_day()
		Phase.ESCORT:
			_begin_night()
		Phase.NIGHT:
			_end_night()


func _on_player_caught(_reason: StringName) -> void:
	_freeze_run() # LockdownScreen shows itself off this same signal


## The exit code was accepted. Freezes the run exactly as a catch does -
## otherwise the day timer keeps running behind the win screen and can still
## end the day, starting the escort and night routine underneath it.
func complete_run() -> void:
	_freeze_run()


## Ends the run without a catch - currently only the day cap. Deliberately does
## NOT emit player_caught: that signal belongs to the enemy and means a real
## catch, so the screen is shown directly instead.
func _fail_run(reason: StringName) -> void:
	if _locked_down:
		return

	_freeze_run()
	_lockdown_screen.show_game_over(reason)


func _freeze_run() -> void:
	if _locked_down: # the enemy can emit player_caught repeatedly while touching
		return

	_locked_down = true
	_phase_timer.stop()
	# The game-over screen runs with process_mode = ALWAYS so its button
	# still works under this.
	get_tree().paused = true


func _on_clue_revealed(digit_index: int, digit_value: int, _flavour: String) -> void:
	if digit_index < 0 or digit_index >= PASSCODE_LENGTH:
		push_warning("clue_revealed sent an out-of-range digit_index: %d" % digit_index)
		return

	passcode_digits[digit_index] = digit_value

	# A clue ends the day early: the escort snaps the enemy next to her a
	# beat later, and that teleport has no explanation without this.
	_day_transition.show_notice("Clue Found")

	# Whoever's reward unlocked this clue is done for the run - see DIGIT_OWNERS.
	var digit_owner := DIGIT_OWNERS[digit_index]
	if not _retired_personalities.has(digit_owner):
		_retired_personalities.append(digit_owner)

	if is_passcode_complete():
		passcode_completed.emit()


func is_passcode_complete() -> bool:
	return not passcode_digits.has(-1)


## Draws from the personalities whose clue is still unfound, so a solved one
## never returns while a failed day's personality gets another turn.
func _pick_personality() -> PersonalityProfile.Personality:
	var pool := PERSONALITIES.duplicate()
	for retired in _retired_personalities:
		pool.erase(retired)

	if pool.is_empty(): # every clue found already - nothing left to gate
		pool = PERSONALITIES.duplicate()

	if not allow_repeat_personality and pool.size() > 1:
		pool.erase(current_personality)

	return pool[randi() % pool.size()]


func _unhandled_input(event: InputEvent) -> void:
	if _locked_down or current_phase != Phase.DAY:
		return

	if event.is_action_pressed("debug_cycle_personality"):
		var idx := PERSONALITIES.find(current_personality)
		current_personality = PERSONALITIES[(idx + 1) % PERSONALITIES.size()]
		GameEvents.day_started.emit(current_day, current_personality)
