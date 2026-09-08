class_name ClueSource
extends Interactable
## A one-time environmental clue (UV floor mark, loose floorboard) that
## reveals one digit of the exit passcode. Per instance, set in the Inspector:
## digit_index (0=UV floor, 1=floorboard - see docs/CONTRACT.md), required_item
## (uv_flashlight / crowbar - inherited from Interactable), and flavour_text.

@export var digit_index: int = 0
@export_multiline var flavour_text: String = ""

var _revealed := false


func _do_interact(_actor: Node2D) -> Interactions.InteractionType:
	if _revealed:
		return Interactions.InteractionType.NONE

	_revealed = true
	prompt_text = ""
	GameEvents.clue_revealed.emit(digit_index, ProceduralGenerator.get_digit(digit_index), flavour_text)
	return Interactions.InteractionType.PICKUP
