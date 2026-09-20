extends CanvasLayer
## How long is left of the day, or of the night.
##
## Its own layer rather than part of the HUD, because the HUD hides at night
## and the night is exactly when a countdown matters most - she is shut in her
## room waiting for it to end.

## Below this the clock turns red, to sell the last stretch of the day.
const URGENT_SECONDS := 10.0
const NORMAL_COLOUR := Color(0.87, 0.82, 0.68)
const URGENT_COLOUR := Color(0.9, 0.35, 0.28)

@onready var phase_label: Label = $Root/Box/Header/Phase
@onready var time_label: Label = $Root/Box/Time


func _process(_delta: float) -> void:
	# The dossier and the keypad are registered before this layer, so they draw
	# underneath it - the clock would sit on top of them.
	if not GameManager.is_run_interactive() or DayOneTerminal.visible or ExitKeypad.visible:
		visible = false
		return

	var left := GameManager.get_phase_time_left()
	# -1 is Night 1, which ends when she reads the computer rather than on a
	# clock. ESCORT is the enemy walking her home; she can't act, so a
	# countdown there would only read as another deadline.
	if left < 0.0 or GameManager.current_phase == GameManager.Phase.ESCORT:
		visible = false
		return

	visible = true
	phase_label.text = "%s %d" % [
		"DAY" if GameManager.is_day() else "NIGHT", GameManager.current_day]
	time_label.text = _format(left)
	time_label.add_theme_color_override(
		"font_color", URGENT_COLOUR if left <= URGENT_SECONDS else NORMAL_COLOUR)


func _format(seconds: float) -> String:
	var whole := int(ceil(seconds)) # 0:01 should last a second, not flash past
	@warning_ignore("integer_division")
	return "%d:%02d" % [whole / 60, whole % 60]
