extends CanvasLayer
## Full-screen "Day X" / "Night X" card. Reacts to GameEvents on its own.

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

	GameEvents.day_started.connect(_on_day_started)
	GameEvents.night_started.connect(_on_night_started)


func _on_day_started(day: int, _personality: int) -> void:
	_show_text("Day %d" % day, 0.0) # day is fully clear once the card is gone


func _on_night_started(day: int) -> void:
	_show_text("Night %d" % day, night_ambient_alpha) # night stays dim after the card


# end_alpha is how dark the screen stays once the card fades out.
func _show_text(text: String, end_alpha: float) -> void:
	label.text = text.to_upper()

	if _current_tween: # stop a still-playing transition so they don't overlap
		_current_tween.kill()

	_current_tween = create_tween()
	_current_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	_current_tween.tween_property(fade, "color:a", 1.0, fade_duration)
	_current_tween.parallel().tween_property(label, "modulate:a", 1.0, fade_duration)
	_current_tween.tween_interval(hold_duration)
	_current_tween.tween_property(fade, "color:a", end_alpha, fade_duration)
	_current_tween.parallel().tween_property(label, "modulate:a", 0.0, fade_duration)
