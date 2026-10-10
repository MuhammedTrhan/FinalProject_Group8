extends CanvasLayer
## Toggle-able inventory panel (Tab): the backpack as a grid with the hotbar row
## underneath. Reads Inventory directly - see docs/CONTRACT.md.
##
## Drag an item onto another slot to move or swap it. Release it away from the
## panel to drop it on the floor beside the player. A ring of DROP_SAFE_MARGIN
## around the panel does not count as "away", so a drag that slips off the edge
## just drops back into its slot instead of throwing the item away.
## Hovering a slot and pressing Q drops that slot's item too.

const INVENTORY_SLOT_SCENE := preload("res://Scenes/UI/inventory_slot.tscn")
## Pixels around the panel where releasing an item does nothing.
const DROP_SAFE_MARGIN := 24.0

@onready var drop_catcher: Control = $Root
@onready var panel: PanelContainer = $Root/CenterContainer/PanelContainer
@onready var grid: GridContainer = $Root/CenterContainer/PanelContainer/MarginContainer/VBox/Grid
@onready var hotbar_row: HBoxContainer = $Root/CenterContainer/PanelContainer/MarginContainer/VBox/HotbarRow

# Every slot, indexed the same as Inventory's.
var _slots: Array[InventorySlot] = []


func _ready() -> void:
	visible = false
	_build_slots()

	# Anything released on the dimmed area outside the panel lands here. The
	# panel swallows drops that fall on it, so this only ever sees the outside.
	drop_catcher.set_drag_forwarding(Callable(), _can_drop_outside, _drop_outside)

	Inventory.items_changed.connect(_refresh)
	Inventory.selection_changed.connect(func(_index: int, _item: ItemData) -> void: _refresh())
	# Switching a tool on changes neither of the above, but it changes the border.
	GameEvents.item_use_requested.connect(func(_item: ItemData, _is_active: bool) -> void: _refresh())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		if visible:
			_close()
		elif GameManager.is_run_interactive():
			# Refused while anything else owns the pause - the dossier, the keypad,
			# the pause menu, the game-over screen - so this can't unpause theirs.
			_open()
	elif visible and event.is_action_pressed("drop_item"):
		var slot := _slot_under_mouse()
		if slot != null:
			Inventory.drop_slot(slot.slot_index)
		get_viewport().set_input_as_handled()


## Freezes the house while she is in her bag.
func _open() -> void:
	visible = true
	get_tree().paused = true


func _close() -> void:
	# A drag still in flight when the panel closes would otherwise be left stuck
	# to the cursor.
	get_viewport().gui_cancel_drag()
	visible = false
	get_tree().paused = false


# The backpack fills the grid in slot order, the hotbar sits underneath in its
# own row - both in Inventory's own order, so slot_index is all a slot needs.
func _build_slots() -> void:
	grid.columns = Inventory.BACKPACK_COLUMNS
	_slots.resize(Inventory.TOTAL_SLOTS)

	for index in Inventory.TOTAL_SLOTS:
		var slot: InventorySlot = INVENTORY_SLOT_SCENE.instantiate()
		slot.slot_index = index
		var parent: Control = hotbar_row if index < Inventory.HOTBAR_SIZE else grid
		parent.add_child(slot)
		_slots[index] = slot


func _refresh() -> void:
	for slot in _slots:
		slot.refresh()


func _slot_under_mouse() -> InventorySlot:
	for slot in _slots:
		if Rect2(Vector2.ZERO, slot.size).has_point(slot.get_local_mouse_position()):
			return slot
	return null


# Root is full-screen at the origin, so its local position is a screen position
# and compares directly with the panel's global rect.
func _can_drop_outside(at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary and data.get("from") is int):
		return false

	return not panel.get_global_rect().grow(DROP_SAFE_MARGIN).has_point(at_position)


func _drop_outside(_at_position: Vector2, data: Variant) -> void:
	Inventory.drop_slot(data["from"])
