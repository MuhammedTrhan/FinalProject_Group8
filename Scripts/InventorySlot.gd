extends PanelContainer
## One row in the inventory panel. Click it to use it, if it is a usable tool.

var item: ItemData:
	set(value):
		item = value
		label.text = item.display_name if item else ""

@onready var label: Label = $Label


## Clicking a usable item uses it - Inventory.use_item() decides whether that
## means "fire once" (crowbar) or "toggle" (UV flashlight) and emits
## GameEvents.item_use_requested for Dev3.
##
## Fires on release rather than press.
func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return

	Inventory.use_item(item)
