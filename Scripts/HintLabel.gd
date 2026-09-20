extends CanvasLayer
## Tells a stuck player what the run is waiting on.
##
## Not part of the HUD: that hides at night, and the opening night - find the
## computer, no clock running - is where a player is most likely to sit stuck.

## Wandering the house doesn't reset this; only actual progress does.
const IDLE_DELAY := 15.0
const SHOW_TIME := 9.0
const FADE_TIME := 0.6

@onready var label: Label = $Root/Hint

var _idle := 0.0
var _visible_for := 0.0
var _fading := false
var _shown := ""


func _ready() -> void:
	visible = false
	label.modulate.a = 0.0

	GameEvents.run_started.connect(func(_s: int) -> void: _reset())
	GameEvents.day_started.connect(func(_d: int, _p: int) -> void: _reset())
	GameEvents.night_started.connect(func(_d: int) -> void: _reset())
	GameEvents.clue_revealed.connect(func(_i: int, _v: int, _f: String) -> void: _reset())
	GameEvents.noise_source_silenced.connect(func(_s: Node, _r: int) -> void: _reset())
	GameEvents.item_pickup_requested.connect(func(_i: ItemData) -> void: _reset())
	GameEvents.item_use_requested.connect(func(_i: ItemData, _a: bool) -> void: _reset())
	GameEvents.enemy_dropped_item.connect(func(_i: ItemData, _p: Vector2) -> void: _reset())
	GameEvents.computer_interact_requested.connect(_reset)


func _process(delta: float) -> void:
	# Both are registered before this layer, so they draw underneath it.
	if not GameManager.is_run_interactive() or DayOneTerminal.visible or ExitKeypad.visible:
		_hide()
		return

	if visible:
		_visible_for += delta
		if _visible_for >= SHOW_TIME:
			_fade_out()
		return

	_idle += delta
	if _idle >= IDLE_DELAY:
		_show(_current_hint())


## Ordered nearest-goal first, so she is told the next step and not the last
## one. A tool she already used is skipped by checking its digit rather than
## whether she still carries it - the crowbar stays in the bag afterwards.
func _current_hint() -> String:
	if GameManager.is_passcode_complete():
		return "The code is complete. Find the front door."

	if GameManager.is_waiting_for_terminal():
		return "There is a computer in this room. Read it before you sleep."

	if _has_all_scraps():
		return "Those torn pages look like they belong together. Open your bag (Tab)."

	if _has_item(&"crowbar") and _digit_missing(1):
		return "One of the floorboards doesn't sit flush. Stand on it and use the crowbar."

	if _has_item(&"uv_flashlight") and _digit_missing(0):
		return "Some writing only shows under UV light. Hold the flashlight and look around."

	if _carries_any_scrap() and _digit_missing(2):
		return "He throws the pieces away. Check the bins he visits."

	# Nothing in hand yet, so the next step is whatever today's antagonist
	# wants. The night has no step of its own - she is shut in and waiting.
	if not GameManager.is_day():
		return ""

	match GameManager.current_personality:
		PersonalityProfile.Personality.FORGETFUL:
			# He sees in every direction (360 fov), so getting spotted is likely -
			# but he only searches for 1.5s, against the Paranoid's 5s.
			return "He looks every way at once, so stay close but hide the moment he comes at you - he forgets quickly."
		PersonalityProfile.Personality.PARANOID:
			return "Stay inside his circle while he walks, and see where he goes."
		PersonalityProfile.Personality.OVERWHELMED:
			return "The noise is getting to him. Turn off what is making it."

	return ""


## By id rather than by resource, so this doesn't have to preload every item
## the puzzles happen to use.
func _has_item(id: StringName) -> bool:
	for item in Inventory.get_items():
		if item != null and item.id == id:
			return true
	return false


func _digit_missing(index: int) -> bool:
	return GameManager.passcode_digits[index] < 0


func _has_all_scraps() -> bool:
	for scrap in Inventory.DIARY_SCRAPS:
		if not Inventory.has_item(scrap):
			return false
	return true


func _carries_any_scrap() -> bool:
	for scrap in Inventory.DIARY_SCRAPS:
		if Inventory.has_item(scrap):
			return true
	return false


func _show(text: String) -> void:
	if text == "":
		_hide()
		return
	if text == _shown and visible:
		return

	_shown = text
	label.text = text
	visible = true
	_visible_for = 0.0
	_fading = false
	create_tween().tween_property(label, "modulate:a", 1.0, FADE_TIME)


func _fade_out() -> void:
	if _fading: # _process keeps running through the fade
		return

	_fading = true
	var tween := create_tween()
	tween.tween_property(label, "modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(_hide)


func _hide() -> void:
	if not visible:
		return

	_shown = ""
	visible = false
	label.modulate.a = 0.0
	_visible_for = 0.0
	_fading = false
	_idle = 0.0 # a hint that has been shown has to earn its place again


func _reset() -> void:
	_idle = 0.0
	_hide()
