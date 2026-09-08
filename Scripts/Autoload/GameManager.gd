extends Node
## Day/night cycle + active personality. Only talks to the team via GameEvents.
## Public API for Dev2/Dev3 (see docs/CONTRACT.md): current_personality, is_day().

enum Phase { DAY, NIGHT }

# 3 passcode digits, per docs/CONTRACT.md: 0=UV floor, 1=floorboard, 2=diary.
const PASSCODE_LENGTH := 3

@export var day_duration_sec: float = 90   #REAL VALUES LATER = 90-60
@export var night_duration_sec: float = 60
@export var allow_repeat_personality := false

const PERSONALITIES: Array[PersonalityProfile.Personality] = [
	PersonalityProfile.Personality.FORGETFUL,
	PersonalityProfile.Personality.PARANOID,
	PersonalityProfile.Personality.OVERWHELMED,
]

var current_day := 1
var current_phase: Phase = Phase.DAY
var current_personality: PersonalityProfile.Personality = PersonalityProfile.Personality.FORGETFUL
var run_seed: int = 0

# -1 = digit not found yet. Filled in by Dev3's clue_revealed.
var passcode_digits: Array[int] = [-1, -1, -1]

const DAY_TRANSITION_SCENE := preload("res://Scenes/day_transition.tscn")
const LOCKDOWN_SCREEN_SCENE := preload("res://Scenes/UI/lockdown_screen.tscn")
const INVENTORY_UI_SCENE := preload("res://Scenes/UI/inventory_ui.tscn")

var _phase_timer: Timer
var _locked_down := false

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

	_day_transition = DAY_TRANSITION_SCENE.instantiate()
	_lockdown_screen = LOCKDOWN_SCREEN_SCENE.instantiate()
	_inventory_ui = INVENTORY_UI_SCENE.instantiate()
	add_child(_day_transition)
	add_child(_lockdown_screen)
	add_child(_inventory_ui)
	# start_new_run() is NOT called here - the main menu's Play button starts it,
	# otherwise the day/night timer would already be ticking at the title screen.


func start_new_run() -> void:
	_locked_down = false
	current_day = 1
	run_seed = randi()
	passcode_digits = [-1, -1, -1]

	get_tree().paused = false
	Inventory.clear()
	_reset_overlays()

	ProceduralGenerator.generate(run_seed)
	GameEvents.run_started.emit(run_seed)

	_start_day()


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
	current_phase = Phase.DAY
	current_personality = _pick_personality()

	GameEvents.day_started.emit(current_day, current_personality)
	_phase_timer.start(day_duration_sec)


func _start_night() -> void:
	current_phase = Phase.NIGHT
	GameEvents.night_started.emit(current_day)

	_phase_timer.start(night_duration_sec)


func _on_phase_timer_timeout() -> void:
	if current_phase == Phase.DAY:
		_start_night()
	else:
		current_day += 1
		_start_day()


func _on_player_caught(_reason: StringName) -> void:
	if _locked_down: # the enemy can emit this repeatedly while touching the player
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

	if is_passcode_complete():
		passcode_completed.emit()


func is_passcode_complete() -> bool:
	return not passcode_digits.has(-1)


func _pick_personality() -> PersonalityProfile.Personality:
	if allow_repeat_personality or PERSONALITIES.size() == 1:
		return PERSONALITIES[randi() % PERSONALITIES.size()]

	var choices := PERSONALITIES.duplicate()
	choices.erase(current_personality)
	return choices[randi() % choices.size()]


func _unhandled_input(event: InputEvent) -> void:
	if _locked_down or current_phase != Phase.DAY:
		return

	if event.is_action_pressed("debug_cycle_personality"):
		var idx := PERSONALITIES.find(current_personality)
		current_personality = PERSONALITIES[(idx + 1) % PERSONALITIES.size()]
		GameEvents.day_started.emit(current_day, current_personality)
