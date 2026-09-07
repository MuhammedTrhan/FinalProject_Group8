class_name Interactable
extends StaticBody2D
## Shared base for every object the player can act on (doors, sittable and
## hideable, toggleable, pickup items).
##
## Its own InterractionArea is a passive marker
## (monitoring = false, monitorable = true, layer = Layers.INTERACTABLE)
## and the PLAYER's InterractArea is the active sensor that finds candidates
## and calls interact()/secondary_interact() on the nearest one. See
## PlayerMovement.gd.
##
## interact() returns the InteractionType synchronously.
## Because the actor calls this directly (passing itself
## as `actor`), a subclass can just read/write `actor` inline

# For outside observers only (future puzzle/enemy-awareness hooks).
# Not how the actor gets its animation.
signal interacted(actor: Node2D)

# Shown above the player's head while this is the nearest candidate.
@export var prompt_text: String = "Interact"
# Shown for the secondary ("action") verb, if this object has one. Leave
# empty if it doesn't - Player only shows a prompt for a non-empty string.
@export var secondary_prompt_text: String = ""
# If set, interact() refuses (and shows refusal_text) unless Inventory.has_item(required_item).
@export var required_item: ItemData = null
@export var refusal_text: String = "I can't use that."
# Breaks ties when more than one candidate is equidistant from the player.
@export var priority: int = 0

# Every subclass's scene has a child Area2D named exactly this - it's the
# passive marker Player's InterractArea sensor detects (see class doc above).
@onready var interaction_area: Area2D = $InterractionArea
# ...and this is its collision shape, also a fixed name by convention. Used
# by get_distance_to() below - NOT for detection, InterractionArea already
# handles that.
@onready var interaction_box: CollisionShape2D = $InterractionArea/InterractionBox

# This is how Player's sensor finds this object at all.
@warning_ignore("unused_private_class_variable")
@onready var _interactable_meta_set: bool = _set_interactable_meta()


func _set_interactable_meta() -> bool:
	interaction_area.set_meta(&"interactable", self)
	return true


## Distance from `point` to the NEAREST POINT of this object's interaction
## shape (0 if `point` is already inside it) - deliberately not distance to
## this node's origin. Origins can sit far from where the player actually
## needs to stand; comparing origins made a nearer object lose to a farther
## one whenever the farther one's origin happened to be closer than its own shape.
## Player uses this for nearest-candidate selection instead of raw global_position distance.
func get_distance_to(point: Vector2) -> float:
	var shape := interaction_box.shape if interaction_box else null
	if shape == null:
		return global_position.distance_to(point)

	var local_point: Vector2 = interaction_box.global_transform.affine_inverse() * point

	if shape is CircleShape2D:
		return maxf(0.0, local_point.length() - shape.radius)

	if shape is CapsuleShape2D:
		# Capsule's long axis is always local Y in Godot, regardless of
		# whatever rotation this particular instance's node carries - that
		# rotation is already baked into global_transform above.
		var half_segment: float = maxf(0.0, shape.height * 0.5 - shape.radius)
		var closest_on_axis := Vector2(0.0, clampf(local_point.y, -half_segment, half_segment))
		return maxf(0.0, local_point.distance_to(closest_on_axis) - shape.radius)

	if shape is RectangleShape2D:
		var half_size: Vector2 = shape.size * 0.5
		var closest := Vector2(
			clampf(local_point.x, -half_size.x, half_size.x),
			clampf(local_point.y, -half_size.y, half_size.y)
		)
		return local_point.distance_to(closest)

	# Unhandled shape type (e.g. a polygon) - fall back to origin distance
	# rather than guessing at its geometry.
	return global_position.distance_to(point)


func interact(actor: Node2D) -> Interactions.InteractionType:
	if not _has_required_item():
		GameEvents.message_requested.emit(refusal_text)
		return Interactions.InteractionType.NONE

	var result := _do_interact(actor)
	if result != Interactions.InteractionType.NONE:
		interacted.emit(actor)
	return result


func secondary_interact(actor: Node2D) -> Interactions.InteractionType:
	if not _has_required_item():
		GameEvents.message_requested.emit(refusal_text)
		return Interactions.InteractionType.NONE

	var result := _do_secondary(actor)
	if result != Interactions.InteractionType.NONE:
		interacted.emit(actor)
	return result


func _has_required_item() -> bool:
	return required_item == null or Inventory.has_item(required_item)


# Override in subclasses. Return NONE if nothing happened (e.g. refused).
func _do_interact(_actor: Node2D) -> Interactions.InteractionType:
	return Interactions.InteractionType.NONE


# Override in subclasses that have a secondary verb. Most don't.
func _do_secondary(_actor: Node2D) -> Interactions.InteractionType:
	return Interactions.InteractionType.NONE
