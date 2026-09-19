extends CanvasLayer
## Tells a stuck player what the run is waiting on.
##
## Not part of the HUD: that hides at night, and the opening night - find the
## computer, no clock running - is where a player is most likely to sit stuck.

## Wandering the house doesn't reset this; only actual progress does.
const IDLE_DELAY := 20.0
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


## Ordered nearest-goal first, so she is told the next step and not the last one.
func _current_hint() -> String:
	if GameManager.is_passcode_complete():
		return "The code is complete. Find the front door."

	if GameManager.is_waiting_for_terminal():
		return "There is a computer in this room. Read it before you sleep."

	if _has_all_scraps():
		return "Those torn pages look like they belong together. Open your bag (Tab)."

	if Inventory.has_item(Inventory.SCRAP_A) or Inventory.has_item(Inventory.SCRAP_B) \
			or Inventory.has_item(Inventory.SCRAP_C):
		return "He throws the pieces away. Check the bins he visits."

	if not GameManager.is_day():
		return "The night passes on its own. Wait for morning."

	match GameManager.current_personality:
		PersonalityProfile.Personality.FORGETFUL:
			return "He forgets quickly. Stay near him and he may warm up to you."
		PersonalityProfile.Personality.PARANOID:
			return "Stay inside his circle while he walks, and see where he goes."
		PersonalityProfile.Personality.OVERWHELMED:
			return "The noise is getting to him. Turn off what is making it."

	return ""


func _has_all_scraps() -> bool:
	for scrap in Inventory.DIARY_SCRAPS:
		if not Inventory.has_item(scrap):
			return false
	return true


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
