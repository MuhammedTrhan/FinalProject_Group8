class_name Computer
extends Furniture
## Interacting always opens the terminal; closing it is the terminal UI's job
## (DayOneTerminal's Close button), so there is no on/off toggle here.


func _ready() -> void:
	super()
	prompt_text = "Open the computer"
	secondary_prompt_text = ""


# Bypass Furniture's activate/deactivate toggle.
func _do_interact(_actor: Node2D) -> Interactions.InteractionType:
	GameEvents.computer_interact_requested.emit()
	return Interactions.InteractionType.NONE
