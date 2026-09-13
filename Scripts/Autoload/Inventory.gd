extends Node
## Item storage. Dev2/Dev3 call add_item/has_item/remove_item directly
## (see docs/CONTRACT.md); also auto-adds items via GameEvents.item_pickup_requested.

## Fires whenever the item list changes. Local signal, not part of GameEvents -
## the future Inventory UI screen listens to this.
signal items_changed

## Fires when the held item changes - either she picked a different hotbar slot,
## or the list shifted under the one she had picked. Local signal; the hotbar
## and anything that cares about what she is holding listen to this.
signal selection_changed(index: int, item: ItemData)

## How many slots the hotbar shows. Items past this are still carried, just not
## directly selectable - nothing in the design needs more than 8.
const HOTBAR_SIZE := 8

# Placeholder ItemData until Dev3 authors the real ones at the same paths
# (see docs/CONTRACT.md §3.2) - combining logic doesn't change either way.
const SCRAP_A := preload("res://Resources/Items/scrap_a.tres")
const SCRAP_B := preload("res://Resources/Items/scrap_b.tres")
const SCRAP_C := preload("res://Resources/Items/scrap_c.tres")
const DIARY_PAGE := preload("res://Resources/Items/diary_page.tres")
const DIARY_SCRAPS := [SCRAP_A, SCRAP_B, SCRAP_C]

var _items: Array[ItemData] = []

# Which hotbar slot she has picked. Stays put when the list changes, so using
# up a slot's item leaves her holding nothing rather than silently sliding the
# next item into her hand.
var _selected_index := 0


func _ready() -> void:
	GameEvents.item_pickup_requested.connect(add_item)


func add_item(item: ItemData) -> void:
	_items.append(item)
	items_changed.emit()
	_notify_selection()


func has_item(item: ItemData) -> bool:
	return _items.has(item)


# Returns false if the item wasn't in the inventory.
func remove_item(item: ItemData) -> bool:
	var idx := _items.find(item)
	if idx == -1:
		return false

	_items.remove_at(idx)
	items_changed.emit()
	_notify_selection()
	return true


func get_items() -> Array[ItemData]:
	return _items.duplicate()


# Called by GameManager at the start of a run - items must not carry over.
func clear() -> void:
	_items.clear()
	_selected_index = 0
	items_changed.emit()
	_notify_selection()


## The item in the picked hotbar slot, or null if that slot is empty. This is
## what "she is holding the flashlight" means - merely owning it is not enough.
func get_held_item() -> ItemData:
	if _selected_index < 0 or _selected_index >= _items.size():
		return null
	return _items[_selected_index]


func get_selected_index() -> int:
	return _selected_index


func select_slot(index: int) -> void:
	if index < 0 or index >= HOTBAR_SIZE or index == _selected_index:
		return

	_selected_index = index
	_notify_selection()


## Mouse-wheel stepping. Wraps around the whole hotbar rather than stopping at
## the last carried item, so the wheel always moves.
func cycle_selection(step: int) -> void:
	select_slot(wrapi(_selected_index + step, 0, HOTBAR_SIZE))


func _notify_selection() -> void:
	selection_changed.emit(_selected_index, get_held_item())


func is_diary_scrap(item: ItemData) -> bool:
	return item in DIARY_SCRAPS


# Combines the 3 diary scraps into DIARY_PAGE if all are present, and reveals
# digit_index 2 of the exit passcode (see docs/CONTRACT.md §3.2).
func try_combine_diary_scraps() -> bool:
	for scrap in DIARY_SCRAPS:
		if not has_item(scrap):
			return false

	for scrap in DIARY_SCRAPS:
		remove_item(scrap)
	add_item(DIARY_PAGE)

	GameEvents.clue_revealed.emit(2, ProceduralGenerator.get_digit(2), "You piece the diary pages together.")
	return true
