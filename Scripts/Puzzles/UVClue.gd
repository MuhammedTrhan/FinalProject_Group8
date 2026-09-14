class_name UVClue
extends Node2D
## The invisible floor mark - only visible while the UV flashlight's cone is
## currently over it.

const DIGIT_INDEX := 0

@export_multiline var flavour_text: String = ""

@onready var scribble: Sprite2D = $ClueScribble

var _revealed := false


func _ready() -> void:
	add_to_group(&"uv_clues")
	scribble.visible = false
	_start_flicker()


## Called by UVFlashlight every active physics frame with whether its cone
## currently covers this node.
func set_lit(lit: bool) -> void:
	scribble.visible = lit
	if lit and not _revealed:
		_revealed = true
		GameEvents.clue_revealed.emit(DIGIT_INDEX, ProceduralGenerator.get_digit(DIGIT_INDEX), flavour_text)


# A slow, permanent shimmer while lit - "reflecting UV light". Runs
# continuously; harmless while scribble is hidden.
func _start_flicker() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property(scribble, "modulate:a", 0.55, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(scribble, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
