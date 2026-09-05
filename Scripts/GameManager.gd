extends Node
## Day/night cycle + active personality. Only talks to the team via GameEvents.

enum Phase { DAY, NIGHT }

# 4 passcode digits: 0=UV floor, 1=floorboard, 2=diary, 3=terminal.
const PASSCODE_LENGTH := 4

@export var day_duration_sec: float = 7.0   #REAL VALUES LATER = 90-60
@export var night_duration_sec: float = 5.0
@export var allow_repeat_personality := false

const PERSONALITIES: Array[PersonalityProfile.Personality] = [
	PersonalityProfile.Personality.FORGETFUL,
	PersonalityProfile.Personality.PARANOID,
	PersonalityProfile.Personality.OVERWHELMED,
]

var current_day := 1
var current_phase: Phase = Phase.DAY
var active_personality: PersonalityProfile.Personality = PersonalityProfile.Personality.FORGETFUL
var run_seed: int = 0

# -1 = digit not found yet. Filled in by Dev3's clue_revealed.
var passcode_digits: Array[int] = [-1, -1, -1, -1]

const DAY_TRANSITION_SCENE := preload("res://Scenes/day_transition.tscn")

var _phase_timer: Timer
var _locked_down := false

## Fires once the last passcode digit is found. Local signal, not part of GameEvents.
signal passcode_completed


func _ready() -> void:
	_phase_timer = Timer.new()
	_phase_timer.one_shot = true
	add_child(_phase_timer)
	_phase_timer.timeout.connect(_on_phase_timer_timeout)

	GameEvents.player_caught.connect(_on_player_caught)
	GameEvents.clue_revealed.connect(_on_clue_revealed)

	add_child(DAY_TRANSITION_SCENE.instantiate())

	start_new_run()


func start_new_run() -> void:
	_locked_down = false
	current_day = 1
	run_seed = randi()
	passcode_digits = [-1, -1, -1, -1]

	ProceduralGenerator.generate(run_seed)
	GameEvents.run_started.emit(run_seed)

	_start_day()


func _start_day() -> void:
	current_phase = Phase.DAY
	active_personality = _pick_personality()

	GameEvents.day_started.emit(current_day, active_personality)
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
	_locked_down = true
	_phase_timer.stop()


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
	choices.erase(active_personality)
	return choices[randi() % choices.size()]


func _unhandled_input(event: InputEvent) -> void:
	if _locked_down or current_phase != Phase.DAY:
		return

	if event.is_action_pressed("debug_cycle_personality"):
		var idx := PERSONALITIES.find(active_personality)
		active_personality = PERSONALITIES[(idx + 1) % PERSONALITIES.size()]
		GameEvents.day_started.emit(current_day, active_personality)
