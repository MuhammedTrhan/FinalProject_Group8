extends PanelContainer
## One draggable/droppable row in the inventory panel.

var item: ItemData:
	set(value):
		item = value
		label.text = item.display_name if item else ""

@onready var label: Label = $Label


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
