class_name Computer
extends Furniture

func activate() -> void:
	super()

	GameEvents.computer_interact_requested.emit()
