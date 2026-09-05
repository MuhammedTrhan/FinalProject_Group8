class_name ItemData
extends Resource
## A single inventory item, authored as a .tres file under res://Resources/Items/.

## Items are compared by identity (pointer), not by id, because every reference
## in the project comes from the same preloaded resource. The `id` field exists
## for save data, debug output and content lookups.

## OWNERSHIP: this is shared. Dev1 owns the Inventory logic that stores
## these; Dev2/Dev3 own the world objects that grant and require them.
## Changing a field here affects all three - announce it.

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D

## Groups keys together in the inventory UI. Purely cosmetic.
@export var is_key: bool = false

## Shown to the player the moment the item is picked up. Leave empty for none.
@export var pickup_flavour: String = ""


func _to_string() -> String:
	return "ItemData(%s)" % (String(id) if id != &"" else "<unnamed>")
