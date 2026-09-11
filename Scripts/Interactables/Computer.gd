class_name Computer
extends Furniture

@onready var closed_computer: Sprite2D = $InactiveSprite
@onready var opened_computer: Sprite2D = $ActiveSprite

var is_open := false

func _ready() -> void:
	if not is_open:
		closed_computer.show()
		opened_computer.hide()
	else:
		opened_computer.show()
		closed_computer.hide()
	
	_update_prompts()

func activate() -> void:
	super()
	is_open = not is_open
	_update_prompts()

	GameEvents.computer_interact_requested.emit()

func deactivate() -> void:
	super()
	is_open = not is_open
	_update_prompts()


func _update_prompts() -> void:
	if is_open:
		prompt_text = "Close the computer"
		secondary_prompt_text = ""
	else:
		prompt_text = "Open the computer"
		secondary_prompt_text = ""
