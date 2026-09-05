extends Node
## Item storage. Dev2/Dev3 call add_item/has_item/remove_item directly
## (see docs/CONTRACT.md); also auto-adds items via GameEvents.item_pickup_requested.

## Fires whenever the item list changes. Local signal, not part of GameEvents -
## the future Inventory UI screen listens to this.
signal items_changed

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
