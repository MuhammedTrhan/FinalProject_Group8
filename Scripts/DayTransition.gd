extends CanvasLayer
## Full-screen "Day X" / "Night X" card. Driven by GameManager rather than
## reacting to GameEvents: the phase signals are emitted from this card's
## on_black callback, so the teleport and personality swap they trigger happen
## while the screen is covered and stay invisible.

@export var begin_text: String = "BEGIN: Night 1"
@export var fade_duration: float = 0.5
@export var hold_duration: float = 1.0
# How dark the screen stays during the night, after the card fades out. 0 = clear.
@export_range(0.0, 1.0) var night_ambient_alpha: float = 0.55

@onready var fade: ColorRect = $Root/Fade # black rect; alpha = how faded the screen is
@onready var label: Label = $Root/PhaseLabel

var _current_tween: Tween


func _ready() -> void:
	fade.color.a = 0.0
	label.modulate.a = 0.0


## Clears the card and the night dimming - otherwise a run that ended at
## night leaves the screen darkened over the main menu.
func reset() -> void:
	if _current_tween:
		_current_tween.kill()

	fade.color.a = 0.0
	label.modulate.a = 0.0


## A caption over the live game, no blackout - tells her the day is over and
## that's why she can't move while the enemy walks her home. The next card
## picks up from here, cross-fading straight into its own text.
func show_notice(text: String) -> void:
	if _current_tween:
		_current_tween.kill()

	label.text = text.to_upper()

	_current_tween = create_tween()
	_current_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_current_tween.tween_property(label, "modulate:a", 1.0, fade_duration)


func play_day_card(day: int, on_black: Callable) -> void:
	_play("Day %d" % day, 0.0, on_black) # daytime is fully clear


func play_night_card(day: int, on_black: Callable) -> void:
	_play("Night %d" % day, night_ambient_alpha, on_black) # night stays dim


func play_begin_card() -> void:
	# Similar to _play, but there is no fadeout, only a hold and a fadein.
	if _current_tween:
		_current_tween.kill()
	
	label.text = begin_text

	fade.color.a = 1.0
	label.modulate.a = 1.0
	
	_current_tween = create_tween()
	_current_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	_current_tween.tween_interval(hold_duration)
	# Settles at the same dim as every other night, not fully clear.
	_current_tween.tween_property(fade, "color:a", night_ambient_alpha, fade_duration)
	_current_tween.parallel().tween_property(label, "modulate:a", 0.0, fade_duration)


# end_alpha is how dark the screen stays once the card fades out. `on_black`
# runs at the one moment the screen is fully covered.
func _play(text: String, end_alpha: float, on_black: Callable) -> void:
	if _current_tween: # stop a still-playing transition so they don't overlap
		_current_tween.kill()
	
	label.text = text.to_upper()
	label.modulate.a = 0.0

	_current_tween = create_tween()
	_current_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	_current_tween.tween_property(fade, "color:a", 1.0, fade_duration)
	_current_tween.parallel().tween_property(label, "modulate:a", 1.0, fade_duration)
	_current_tween.tween_callback(on_black)
	_current_tween.tween_interval(hold_duration)
	_current_tween.tween_property(fade, "color:a", end_alpha, fade_duration)
	_current_tween.parallel().tween_property(label, "modulate:a", 0.0, fade_duration)
