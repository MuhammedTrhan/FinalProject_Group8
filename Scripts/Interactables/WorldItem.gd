class_name WorldItem
extends Interactable
## A pickup lying in the world - crowbar, UV flashlight, a diary scrap, a key,
## anything backed by an ItemData. Either placed by hand in a level (set
## `item` in the editor) or spawned at runtime via WorldItem.spawn()
## (e.g. when the antagonist drops a reward).


@export var item: ItemData
## Where the icon starts, relative to its resting spot, for the one-time
## "landing" tween played after a runtime spawn() (see _play_drop_animation).
@export var drop_offset: Vector2 = Vector2(0, -20)

@onready var sprite: Sprite2D = $Sprite2D
@onready var anim_player: AnimationPlayer = $AnimationPlayer

## Set by spawn() only - distinguishes a runtime drop from a WorldItem
## hand-placed in a level, so pre-placed pickups don't play a falling animation.
var _play_drop_animation: bool = false


func _ready() -> void:
	if item != null:
		_apply_item()
	if _play_drop_animation:
		_play_drop_tween()


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


## Stops the idle autoplay, animates the icon, then hands control to the idle.
func _play_drop_tween() -> void:
	anim_player.stop()
	sprite.position = drop_offset

	var tween := create_tween()
	tween.tween_property(sprite, "position", Vector2.ZERO, 0.35) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func(): anim_player.play(&"idle"))


## Nudges desired_pos away from walls/furniture (Layers.WALLS covers both -
## see Layers.gd) with a small ring search, so a dropped reward never lands
## somewhere the player can't reach. Falls back to desired_pos itself if
## nothing clearer turns up nearby.
func _find_clear_position(desired_pos: Vector2) -> Vector2:
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsPointQueryParameters2D.new()
	query.collision_mask = Layers.WALLS
	query.position = desired_pos

	if space_state.intersect_point(query, 1).is_empty():
		return desired_pos

	for radius: float in [16.0, 32.0, 48.0, 64.0, 80.0, 96.0]:
		for angle_deg in range(0, 360, 45):
			var candidate: Vector2 = desired_pos + Vector2.RIGHT.rotated(deg_to_rad(angle_deg)) * radius
			query.position = candidate
			if space_state.intersect_point(query, 1).is_empty():
				return candidate

	return desired_pos


static func spawn(spawn_item: ItemData, parent: Node, spawn_pos: Vector2) -> WorldItem:
	var instance: WorldItem = preload("res://Scenes/world_item.tscn").instantiate()
	instance.item = spawn_item
	instance._play_drop_animation = true
	parent.add_child(instance)
	instance.global_position = instance._find_clear_position(spawn_pos)
	return instance
