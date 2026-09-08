class_name WorldItem
extends Interactable
## A pickup lying in the world - crowbar, UV flashlight, a diary scrap, a key,
## anything backed by an ItemData. Either placed by hand in a level (set
## `item` in the editor) or spawned at runtime via WorldItem.spawn()
## (e.g. when the antagonist drops a reward).


@export var item: ItemData

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	if item != null:
		_apply_item()


func _apply_item() -> void:
	if item.icon != null:
		sprite.texture = item.icon
	prompt_text = "Take %s" % item.display_name


func _do_interact(_actor: Node2D) -> Interactions.InteractionType:
	GameEvents.item_pickup_requested.emit(item)
	if item.pickup_flavour != "":
		GameEvents.message_requested.emit(item.pickup_flavour)

	queue_free()
	return Interactions.InteractionType.PICKUP


static func spawn(spawn_item: ItemData, parent: Node, spawn_pos: Vector2) -> WorldItem:
	var instance: WorldItem = preload("res://Scenes/world_item.tscn").instantiate()
	instance.item = spawn_item
	instance.global_position = spawn_pos
	parent.add_child(instance)
	return instance
