class_name InventorySlot
extends PanelContainer
## One square slot in the Tab inventory. Shows whatever Inventory holds at
## slot_index; drag it onto another slot to move or swap the items. Dropping on
## the floor is handled by InventoryUI, which owns the area around the panel.
##
## Clicking a hotbar slot picks it (the same as the number keys). Using an item
## is never done from here.

const SLOT_SIZE := Vector2(52, 52)
const SELECTED_BORDER := Color(0.95, 0.82, 0.42)
const IDLE_BORDER := Color(0.35, 0.31, 0.26)
const ACTIVE_BORDER := Color(0.7, 0.35, 1.0)
const NUMBER_COLOUR := Color(0.9, 0.84, 0.7)
## How much the icon of the slot being dragged fades, so it reads as picked up.
const DRAGGED_ALPHA := 0.35

## Which Inventory slot this shows. Set before the slot enters the tree.
var slot_index := -1

var _icon: TextureRect


func _ready() -> void:
	custom_minimum_size = SLOT_SIZE

	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)

	# Only the hotbar slots have a key - same corner as on the HUD hotbar.
	if _is_hotbar_slot():
		var number := Label.new()
		number.text = str(slot_index + 1)
		number.mouse_filter = Control.MOUSE_FILTER_IGNORE
		number.size_flags_horizontal = Control.SIZE_SHRINK_END
		number.size_flags_vertical = Control.SIZE_SHRINK_END
		number.add_theme_font_size_override("font_size", 13)
		number.add_theme_color_override("font_outline_color", Color.BLACK)
		number.add_theme_color_override("font_color", NUMBER_COLOUR)
		number.add_theme_constant_override("outline_size", 4)
		add_child(number)

	refresh()


## Redraws the icon, tooltip and border from Inventory.
func refresh() -> void:
	var item := Inventory.get_slot_item(slot_index)
	_icon.texture = item.icon if item else null
	tooltip_text = "%s\n%s" % [item.display_name, item.description] if item else ""

	var selected := _is_hotbar_slot() and slot_index == Inventory.get_selected_index()
	var active := item != null and item == Inventory.get_active_tool()
	add_theme_stylebox_override("panel", _make_style(selected, active))


func _is_hotbar_slot() -> bool:
	return slot_index >= 0 and slot_index < Inventory.HOTBAR_SIZE


func _make_style(selected: bool, active: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.04, 0.04, 0.85)
	if active:
		style.border_color = ACTIVE_BORDER
	else:
		style.border_color = SELECTED_BORDER if selected else IDLE_BORDER
	style.set_border_width_all(3 if selected or active else 2)
	style.set_corner_radius_all(4)
	return style


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return

	if _is_hotbar_slot():
		Inventory.select_slot(slot_index)


func _get_drag_data(_at_position: Vector2) -> Variant:
	var item := Inventory.get_slot_item(slot_index)
	if item == null:
		return null

	# The preview is centred on the cursor: a bare Control holds the icon so it
	# can be offset, since the drag preview is pinned to the cursor by its origin.
	var preview := TextureRect.new()
	preview.texture = item.icon
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.size = SLOT_SIZE
	preview.position = -SLOT_SIZE / 2.0
	preview.modulate.a = 0.85

	var holder := Control.new()
	holder.add_child(preview)
	set_drag_preview(holder)

	return {"from": slot_index}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("from") is int


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	Inventory.move_slot(data["from"], slot_index)


# A drag starting or ending anywhere is announced to every control, which is
# how the slot being dragged knows to fade its icon - and to restore it however
# the drag ended, including one that was dropped nowhere.
func _notification(what: int) -> void:
	if _icon == null:
		return

	if what == NOTIFICATION_DRAG_BEGIN:
		var data: Variant = get_viewport().gui_get_drag_data()
		if data is Dictionary and data.get("from") == slot_index:
			_icon.modulate.a = DRAGGED_ALPHA
	elif what == NOTIFICATION_DRAG_END:
		_icon.modulate.a = 1.0
