class_name Door
extends Interactable


@export var is_locked := false
## Deliberately its own field, not the base Interactable.required_item: that
## one gates BOTH interact() and secondary_interact(), but a key should only
## gate lock/unlock (secondary) - opening/closing an already-unlocked door
## must never require holding anything.
@export var required_key_item: ItemData

@onready var hitbox = $Hitbox
@onready var closed_door: Sprite2D = $DoorClosed
@onready var opened_door: Sprite2D = $DoorOpen
@onready var lock_icon: Sprite2D = $LockIcon
## The two valid "outside the doorway" points, one per side. Whoever is still
## standing in the hitbox when it closes gets snapped to whichever is nearer.
@onready var exit_marker_a: Marker2D = $ExitMarkerA
@onready var exit_marker_b: Marker2D = $ExitMarkerB

var is_open := false


func _ready() -> void:
	if not is_open:
		closed_door.show()
		opened_door.hide()
	else:
		opened_door.show()
		closed_door.hide()

	if is_locked:
		lock_icon.show()
	else:
		lock_icon.hide()

	_update_prompts()


# Primary (Interact/Space): open/close.
func _do_interact(_actor: Node2D) -> Interactions.InteractionType:
	if is_locked:
		GameEvents.message_requested.emit("I need to unlock this door first.")
		return Interactions.InteractionType.NONE

	if is_open:
		close_door()
		return Interactions.InteractionType.CLOSE
	else:
		open_door()
		return Interactions.InteractionType.OPEN


## Secondary (action/E): lock/unlock.
func _do_secondary(_actor: Node2D) -> Interactions.InteractionType:
	if not _has_required_key():
		GameEvents.message_requested.emit("I don't have the right key.")
		return Interactions.InteractionType.NONE

	var result := Interactions.InteractionType.NONE
	if not is_open:
		toogle_lock()
		result = Interactions.InteractionType.LOCK if is_locked else Interactions.InteractionType.UNLOCK
	else:
		if not is_locked:
			GameEvents.message_requested.emit("I need to close this door to lock it.")
		else:
			GameEvents.message_requested.emit("I need to close this door to unlock it.")

	# Safety net: if the door is somehow both open and locked, force it closed.
	if is_locked and is_open:
		close_door()

	return result


func open_door() -> void:
	is_open = true
	hitbox.set_deferred("disabled", true)
	closed_door.hide()
	opened_door.show()
	_update_prompts()


func close_door() -> void:
	_evacuate_hitbox()

	is_open = false
	hitbox.set_deferred("disabled", false)
	closed_door.show()
	opened_door.hide()
	_update_prompts()


# Snap the body to nearest exit marker if it's still in the hitbox
# when the door closes.
func _evacuate_hitbox() -> void:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = hitbox.shape
	query.transform = hitbox.global_transform
	query.collision_mask = Layers.PLAYER | Layers.ENEMY

	var space_state := get_world_2d().direct_space_state
	for result in space_state.intersect_shape(query, 4):
		var body: Node2D = result.get("collider")
		if body == null:
			continue

		var to_a := body.global_position.distance_squared_to(exit_marker_a.global_position)
		var to_b := body.global_position.distance_squared_to(exit_marker_b.global_position)
		body.global_position = exit_marker_a.global_position if to_a <= to_b else exit_marker_b.global_position


func toogle_lock() -> void:
	is_locked = not is_locked
	if is_locked:
		lock_icon.show()
	else:
		lock_icon.hide()
	_update_prompts()


func _has_required_key() -> bool:
	return required_key_item == null or Inventory.has_item(required_key_item)


func _update_prompts() -> void:
	if is_open:
		prompt_text = "Close the door"
		secondary_prompt_text = ""
	elif is_locked:
		prompt_text = ""
		secondary_prompt_text = "Unlock the door"
	else:
		prompt_text = "Open the door"
		secondary_prompt_text = "Lock the door"
