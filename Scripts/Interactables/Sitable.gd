class_name Sitable
extends Interactable


@onready var stand_up_point = $StandUpMarker
@onready var sit_down_point = $SitDownMarker

var is_occupied: bool = false
var occupant: Node2D = null


func _ready() -> void:
	if is_occupied:
		prompt_text = "Stand Up"
	else:
		prompt_text = "Sit Down"


# Primary (Interact/Space): sit down, or stand up if the actor is the one
# currently seated here.
func _do_interact(actor: Node2D) -> Interactions.InteractionType:
	if is_occupied and occupant == actor:
		stand_up(actor)
		return Interactions.InteractionType.STANDUP

	if is_occupied:
		return Interactions.InteractionType.NONE

	sit_down(actor)
	return Interactions.InteractionType.SITDOWN


func sit_down(actor: Node2D) -> void:
	is_occupied = true
	occupant = actor

	# The chair dynamically ignores collision with whoever sat in it.
	actor.add_collision_exception_with(self)

	_orient_actor(actor, sit_down_point.global_position)

	prompt_text = "Stand Up"


func stand_up(actor: Node2D) -> void:
	if is_instance_valid(occupant):
		occupant.remove_collision_exception_with(self)

	is_occupied = false
	occupant = null

	_orient_actor(actor, stand_up_point.global_position)

	prompt_text = "Sit Down"


# Player should face away from the chair for both sitting and standing up,
# so the look direction is the same formula either way.
func _orient_actor(actor: Node2D, snap_pos: Vector2) -> void:
	if actor.has_method("orient_for_furniture"):
		actor.orient_for_furniture(snap_pos, sit_down_point.global_position, stand_up_point.global_position)
	else:
		actor.global_position = snap_pos
