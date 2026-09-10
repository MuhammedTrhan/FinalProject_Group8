extends Node
## Day/night cycle + active personality. Only talks to the team via GameEvents.
## Public API for Dev2/Dev3 (see docs/CONTRACT.md): current_personality, is_day().

## ESCORT is the gap between the day's play ending and night beginning: the
## day is over and she can't act, but the enemy still has to walk her home,
## and that has to be visible. See docs/CONTRACT.md §2.2.
enum Phase { DAY, ESCORT, NIGHT }

# 3 passcode digits, per docs/CONTRACT.md: 0=UV floor, 1=floorboard, 2=diary.
const PASSCODE_LENGTH := 3

@export var day_duration_sec: float = 90
@export var night_duration_sec: float = 20
## The walk-her-home window between day and night. Matches Dev2's
## EscortController.ESCORT_DURATION - if you change one, change both.
@export var escort_duration_sec: float = 5.0
@export var allow_repeat_personality := false

const PERSONALITIES: Array[PersonalityProfile.Personality] = [
	PersonalityProfile.Personality.FORGETFUL,
	PersonalityProfile.Personality.PARANOID,
	PersonalityProfile.Personality.OVERWHELMED,
]

# Every personality gets two chances at being solved; the run then ends in
# failure on the day after those, which never actually plays.
var max_days: int = PERSONALITIES.size() * 2 + 1

# A run opens on Night 1 and alternates Night N -> Day N -> Night N+1, so a
# night always precedes the day of the same number.
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
# The opening night runs without a clock - it ends only once the player has
# read the day-one terminal.
var _waiting_for_terminal := false
# Personalities whose clue the player already found. They never come back;
# the ones whose day she failed stay in the pool for another turn.
var _retired_personalities: Array[PersonalityProfile.Personality] = []

# These overlays live under this autoload, so they survive scene changes and
# have to be reset by hand - otherwise e.g. the game-over screen stays drawn
# on top of the main menu.
var _day_transition: CanvasLayer
var _lockdown_screen: CanvasLayer
var _inventory_ui: CanvasLayer

## Fires once the last passcode digit is found. Local signal, not part of GameEvents.
signal passcode_completed


func _ready() -> void:
	_phase_timer = Timer.new()
	_phase_timer.one_shot = true
	add_child(_phase_timer)
	_phase_timer.timeout.connect(_on_phase_timer_timeout)

	GameEvents.player_caught.connect(_on_player_caught)
	GameEvents.clue_revealed.connect(_on_clue_revealed)
	GameEvents.night_start_requested.connect(_on_night_start_requested)
	# TODO: swap to the GameEvents signal for this once the team adds one.
	DayOneTerminal.dossier_closed.connect(_on_dossier_closed)

	_day_transition = DAY_TRANSITION_SCENE.instantiate()
	_lockdown_screen = LOCKDOWN_SCREEN_SCENE.instantiate()
	_inventory_ui = INVENTORY_UI_SCENE.instantiate()
	add_child(_day_transition)
	add_child(_lockdown_screen)
	add_child(_inventory_ui)
	# start_new_run() is NOT called here - the main menu's Play button starts it,
	# otherwise the day/night timer would already be ticking at the title screen.


## Loads the level, then starts Night 1. The level has to exist BEFORE the
## first signals fire - otherwise the enemy, the escort controller and the
## doors are all still unloaded and miss them.
func start_new_run() -> void:
	_locked_down = false
	current_day = 1
	run_seed = randi()
	passcode_digits = [-1, -1, -1]
	_retired_personalities.clear()

	get_tree().paused = false
	Inventory.clear()
	_reset_overlays()

	get_tree().change_scene_to_file("res://Scenes/main_level.tscn")
	await get_tree().process_frame

	ProceduralGenerator.generate(run_seed)
	GameEvents.run_started.emit(run_seed)

	# The run opens on Night 1, shut in her own room, where she's meant to read
	# the computer before the first day. That terminal ends this night early -
	# but until the computer object exists the ordinary night clock still runs,
	# so the run can't soft-lock here.
	_waiting_for_terminal = true
	_day_transition.play_night_card(current_day, func() -> void:
		_snap_player_to_spawn()
		_lock_player_room_door()
		_start_night()
	)


# The Player node sits wherever it was convenient to author, but a run always
# begins in her own room - same snap Dev2's escort uses to put her back there.
func _snap_player_to_spawn() -> void:
	_snap_player_to("PlayerSpawnPoint", true)


# She's shut in her room every night, so each day starts by putting her back
# out in the house. Optional: without a DayStartPoint marker she simply walks
# out of her room herself once the door unlocks.
func _snap_player_to_day_start() -> void:
	_snap_player_to("DayStartPoint", false)


func _snap_player_to(marker_name: String, required: bool) -> void:
	var marker: Node2D = get_tree().current_scene.get_node_or_null(marker_name)
	var player := get_tree().get_first_node_in_group(&"player")

	if marker == null or player == null or not player.has_method("snap_to_spawn"):
		if required:
			push_warning("No %s or player - she won't start in her room." % marker_name)
		return

	player.snap_to_spawn(marker.global_position)


# Dev2's EscortController already unlocks this again on day_started, so the
# run start only needs to do the locking half.
func _lock_player_room_door() -> void:
	var door := get_tree().get_first_node_in_group(&"player_room_door")
	if door == null:
		push_warning("No node in the player_room_door group - she won't start locked in.")
		return

	if door.is_open:
		door.close_door()
	if not door.is_locked:
		door.toogle_lock()


## Called by the game-over and win screens. Clears the run's overlays first -
## they outlive the scene change, so without this they stay on top of the menu.
func return_to_main_menu() -> void:
	get_tree().paused = false
	_reset_overlays()
	get_tree().change_scene_to_file("res://Scenes/UI/main_menu.tscn")


func _reset_overlays() -> void:
	_lockdown_screen.visible = false
	_inventory_ui.visible = false
	_day_transition.reset()
	WinScreen.visible = false
	ExitKeypad.visible = false
	DayOneTerminal.visible = false


func is_day() -> bool:
	return current_phase == Phase.DAY


func _start_day() -> void:
	if current_day >= max_days: # she's out of days - this one never starts
		_fail_run(&"timeout")
		return

	current_phase = Phase.DAY
	current_personality = _pick_personality()

	_snap_player_to_day_start()
	GameEvents.day_started.emit(current_day, current_personality)
	_phase_timer.start(day_duration_sec)


func _start_night() -> void:
	current_phase = Phase.NIGHT
	GameEvents.night_started.emit(current_day)
	_phase_timer.start(night_duration_sec)


## The day's play is over, but night doesn't begin yet - Dev2's enemy gets a
## fixed window to walk her home first, and that walk has to stay visible.
func _end_day() -> void:
	current_phase = Phase.ESCORT
	_day_transition.show_notice("Day Ended")
	GameEvents.day_ended.emit(current_day)
	_phase_timer.start(escort_duration_sec)


## Fades to black, and only once the screen is covered does night actually
## begin - so her teleport and the enemy's personality swap aren't seen.
func _begin_night() -> void:
	current_day += 1
	_day_transition.play_night_card(current_day, _start_night)


func _end_night() -> void:
	GameEvents.night_ended.emit(current_day)
	_day_transition.play_day_card(current_day, _start_day)


## Dev2 asks for night to start immediately after a non-final catch: it has
## already run its own walk-home window, so the escort wait is skipped.
func _on_night_start_requested(_reason: StringName) -> void:
	if _locked_down or current_phase == Phase.NIGHT:
		return

	_phase_timer.stop()
	_begin_night()


# The opening night ends only once the player has actually read the dossier.
func _on_dossier_closed() -> void:
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


## Ends the run without a catch - currently only the day cap. Deliberately
## does NOT emit player_caught: that one is Dev2's to emit (docs/CONTRACT.md)
## and means an actual catch, so the screen is shown directly instead.
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
	# Freezes the enemy and the player underneath the game-over screen. The
	# screen itself runs with process_mode = ALWAYS so its button still works.
	get_tree().paused = true


# digit_index/digit_value come from Dev3's puzzle; flavour text isn't needed here.
func _on_clue_revealed(digit_index: int, digit_value: int, _flavour: String) -> void:
	if digit_index < 0 or digit_index >= PASSCODE_LENGTH:
		push_warning("clue_revealed sent an out-of-range digit_index: %d" % digit_index)
		return

	passcode_digits[digit_index] = digit_value

	# Whoever she was up against when she found this clue is done for the run.
	if not _retired_personalities.has(current_personality):
		_retired_personalities.append(current_personality)

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
