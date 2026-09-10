class_name ContainerFurniture
extends Furniture
## Trash cans now; drawers/closets later. Opening a container that currently
## holds something spawns one random item from what it holds as a WorldItem next
## to it, draining the container in random order across repeated opens.
##
## required_item/refusal_text are inherited from Interactable UNCHANGED -
## e.g. a locked closet: required_item = a key ItemData, refusal_text =
## "I can't open this without a key." Interactable.interact() already gates
## and messages that case before activate() is ever reached.
## not_found_text: shown when a container is opened and has nothing inside.
##
## Contents come from two places: hand-assigned in the editor (closets)
## via initial_items, and deposited at runtime via add_item() (Paranoid's trash can)

@export var initial_items: Array[ItemData] = []
@export var not_found_text: String = "Nothing fancy here."

var _items: Array[ItemData] = []


func _ready() -> void:
	_items = initial_items.duplicate()
	super._ready()


func activate() -> void:
	super()
	if _items.is_empty():
		GameEvents.message_requested.emit(not_found_text)
	else:
		_spawn_random_item()


func _spawn_random_item() -> void:
	var given: ItemData = _items.pop_at(randi() % _items.size())
	WorldItem.spawn(given, get_parent(), global_position)


## Hook for Paranoid's deposit behavior.
func add_item(new_item: ItemData) -> void:
	_items.append(new_item)
