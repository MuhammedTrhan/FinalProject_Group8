extends Control
## Minecraft-style hotbar along the bottom of the HUD.
##
## Selection: number keys 1-8, the mouse wheel, or clicking a slot. Whatever
## sits in the picked slot is the item she is "holding" - see
## Inventory.get_held_item(). The Tab panel stays the full inventory; this is
## only the quick-select strip.
##
## The slots are built in code so the scene needs no editing when HOTBAR_SIZE
## changes, and so the count always matches Inventory.

const SLOT_SIZE := Vector2(52, 52)
const SELECTED_BORDER := Color(0.95, 0.82, 0.42)
const IDLE_BORDER := Color(0.35, 0.31, 0.26)
## A switched-on tool is bordered in its own colour - the UV cone is the only
## other sign it is running, and that is off-screen whenever she looks away.
const ACTIVE_BORDER := Color(0.7, 0.35, 1.0)

@onready var slot_row: HBoxContainer = $SlotRow
@onready var name_label: Label = $NameLabel

# One PanelContainer per slot, in hotbar order.
var _slots: Array[PanelContainer] = []
# The icon inside each slot, same order - kept so refreshing doesn't re-walk
# the node tree every time an item moves.
var _icons: Array[TextureRect] = []


func _ready() -> void:
	_build_slots()

	Inventory.items_changed.connect(_refresh)
	Inventory.selection_changed.connect(_on_selection_changed)
	# Toggling a tool changes neither the item list nor the selection, so the
	# switched-on border needs its own trigger.
	GameEvents.item_use_requested.connect(_on_item_use_requested)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	# Hidden at night and once the run is over, and the hotbar shouldn't eat
	# keys it isn't showing a response to.
	if not is_visible_in_tree():
		return

	# Read as raw keys rather than input actions: eight near-identical actions
	# in project.godot would be noise, and these are not meant to be rebound.
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		var slot := key.physical_keycode - KEY_1
		if slot >= 0 and slot < Inventory.HOTBAR_SIZE:
			Inventory.select_slot(slot)
			get_viewport().set_input_as_handled()
		return

	var click := event as InputEventMouseButton
	if click != null and click.pressed:
		if click.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			Inventory.cycle_selection(1)
		elif click.button_index == MOUSE_BUTTON_WHEEL_UP:
			Inventory.cycle_selection(-1)


func _build_slots() -> void:
	for i in Inventory.HOTBAR_SIZE:
		var slot := PanelContainer.new()
		slot.custom_minimum_size = SLOT_SIZE
		slot.add_theme_stylebox_override("panel", _make_slot_style(false))
		# Bound per slot so a click selects the one that was actually clicked.
		slot.gui_input.connect(_on_slot_gui_input.bind(i))
		slot_row.add_child(slot)

		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)

		_slots.append(slot)
		_icons.append(icon)


func _make_slot_style(selected: bool, active: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.04, 0.04, 0.85)
	if active:
		style.border_color = ACTIVE_BORDER
	else:
		style.border_color = SELECTED_BORDER if selected else IDLE_BORDER
	style.set_border_width_all(3 if selected or active else 2)
	style.set_corner_radius_all(4)
	return style


## Clicking a slot picks it up; clicking the slot she is already holding uses
## what is in it. That second click is the only way to swing a one-shot tool
## like the crowbar from the hotbar - merely holding it does nothing.
func _on_slot_gui_input(event: InputEvent, index: int) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return

	if index == Inventory.get_selected_index():
		Inventory.use_item(Inventory.get_held_item())
	else:
		Inventory.select_slot(index)


func _on_selection_changed(_index: int, _item: ItemData) -> void:
	_refresh()


func _on_item_use_requested(_item: ItemData, _is_active: bool) -> void:
	_refresh()


func _refresh() -> void:
	var items := Inventory.get_items()
	var selected := Inventory.get_selected_index()
	var active := Inventory.get_active_tool()

	for i in _slots.size():
		var item: ItemData = items[i] if i < items.size() else null
		_icons[i].texture = item.icon if item else null
		_slots[i].add_theme_stylebox_override(
			"panel", _make_slot_style(i == selected, item != null and item == active))

	# Only the held item is named - eight captions at once would be unreadable,
	# and the point of the caption is to confirm what she just picked.
	var held := Inventory.get_held_item()
	if held == null:
		name_label.text = ""
	elif held == active:
		name_label.text = "%s (on)" % held.display_name
	else:
		name_label.text = held.display_name
