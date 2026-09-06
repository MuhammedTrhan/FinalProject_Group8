extends Node
## Item storage. Dev2/Dev3 call add_item/has_item/remove_item directly
## (see docs/CONTRACT.md); also auto-adds items via GameEvents.item_pickup_requested.

## Fires whenever the item list changes. Local signal, not part of GameEvents -
## the future Inventory UI screen listens to this.
signal items_changed

# Placeholder ItemData until Dev3 authors the real ones at the same paths
# (see docs/CONTRACT.md §3.2) - combining logic doesn't change either way.
const SCRAP_A := preload("res://Resources/Items/scrap_a.tres")
const SCRAP_B := preload("res://Resources/Items/scrap_b.tres")
const SCRAP_C := preload("res://Resources/Items/scrap_c.tres")
const DIARY_PAGE := preload("res://Resources/Items/diary_page.tres")
const DIARY_SCRAPS := [SCRAP_A, SCRAP_B, SCRAP_C]

var _items: Array[ItemData] = []


func _ready() -> void:
	GameEvents.item_pickup_requested.connect(add_item)


func add_item(item: ItemData) -> void:
	_items.append(item)
	items_changed.emit()


func has_item(item: ItemData) -> bool:
	return _items.has(item)


# Returns false if the item wasn't in the inventory.
func remove_item(item: ItemData) -> bool:
	var idx := _items.find(item)
	if idx == -1:
		return false

	_items.remove_at(idx)
	items_changed.emit()
	return true


func get_items() -> Array[ItemData]:
	return _items.duplicate()


func is_diary_scrap(item: ItemData) -> bool:
	return item in DIARY_SCRAPS


# Combines the 3 diary scraps into DIARY_PAGE if all are present.
# NOTE: revealing the passcode digit for the diary (clue_revealed, digit_index
# 2) is Dev3's job per docs/CONTRACT.md - not wired here yet, pending their hookup.
func try_combine_diary_scraps() -> bool:
	for scrap in DIARY_SCRAPS:
		if not has_item(scrap):
			return false

	for scrap in DIARY_SCRAPS:
		remove_item(scrap)
	add_item(DIARY_PAGE)
	return true
