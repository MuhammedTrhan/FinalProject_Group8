extends PanelContainer
## One draggable/droppable row in the inventory panel. Drag it onto another to
## combine diary scraps; click it to use it, if it is a usable tool.

var item: ItemData:
	set(value):
		item = value
		label.text = item.display_name if item else ""

@onready var label: Label = $Label


## Clicking a usable item uses it - Inventory.use_item() decides whether that
## means "fire once" (crowbar) or "toggle" (UV flashlight) and emits
## GameEvents.item_use_requested for Dev3.
##
## Fires on release rather than press, and only when no drag is in flight, so
## dragging a scrap onto another scrap doesn't also count as a click.
func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return

	if get_viewport().gui_is_dragging():
		return

	Inventory.use_item(item)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if item == null:
		return null

	var preview := Label.new()
	preview.text = item.display_name
	set_drag_preview(preview)
	return item


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is ItemData and data != item


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not data is ItemData or not Inventory.is_diary_scrap(data) or not Inventory.is_diary_scrap(item):
		return

	if Inventory.try_combine_diary_scraps():
		GameEvents.message_requested.emit("You piece the diary pages together.")
	else:
		GameEvents.message_requested.emit("You need all 3 diary scraps.")
