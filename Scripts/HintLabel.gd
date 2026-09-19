extends CanvasLayer
## Nudges the player when she has gone a while without doing anything that
## moves the run forward, and says what the house is currently waiting on.
##
## Deliberately not part of the HUD: that hides at night, and the opening
## night - find the computer, with no clock running - is exactly where a
## player is most likely to sit stuck.

## How long she has to go without progress before the hint appears. Note that
## wandering the house looking for something doesn't reset this - only actually
## getting somewhere does - so a player who is searching will still see it.
const IDLE_DELAY := 20.0
## How long it stays up before fading out again. It then needs another full
## IDLE_DELAY of nothing happening to come back, so it nags rather than nails
## itself to the screen.
const SHOW_TIME := 9.0
const FADE_TIME := 0.6

@onready var label: Label = $Root/Hint

var _idle := 0.0
# How long the hint on screen has been up, counted only while it is showing.
var _visible_for := 0.0
# True from the moment the fade-out starts until it lands, so the fade isn't
# restarted every frame while it plays.
var _fading := false
# What the label is currently showing, so a hint that stays true across frames
# isn't re-faded every frame.
var _shown := ""


func _ready() -> void:
	visible = false
	label.modulate.a = 0.0

	# Anything that moves the run forward counts as progress and buys her
	# another IDLE_DELAY of silence. The arities differ, hence the lambdas.
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
	# The dossier and the keypad are checked separately: both are registered
	# earlier than this layer, so they draw underneath it and a hint left up
	# would sit on top of them.
	if not GameManager.is_run_interactive() or DayOneTerminal.visible or ExitKeypad.visible:
		_hide()
		return

	# While one is up, the only thing being counted is how long it has been up.
	if visible:
		_visible_for += delta
		if _visible_for >= SHOW_TIME:
			_fade_out()
		return

	_idle += delta
	if _idle >= IDLE_DELAY:
		_show(_current_hint())


## First match wins - the list runs from "you are one step from the exit" back
## to "you have nothing yet", so she is always told the nearest thing to do.
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

	# Nothing in hand yet: what she does today depends on who woke up.
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


## Its time is up. Fades rather than blinking out, and only once - _process
## keeps running through the fade.
func _fade_out() -> void:
	if _fading:
		return

	_fading = true
	var tween := create_tween()
	tween.tween_property(label, "modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(_hide)


## Instant, for everything that isn't the timer running out: the dossier
## opening over it, the run ending, progress being made.
func _hide() -> void:
	if not visible:
		return

	_shown = ""
	visible = false
	label.modulate.a = 0.0
	_visible_for = 0.0
	_fading = false
	# Earns its place again from scratch, so a dismissed hint doesn't reappear
	# a frame later.
	_idle = 0.0


func _reset() -> void:
	_idle = 0.0
	_hide()
