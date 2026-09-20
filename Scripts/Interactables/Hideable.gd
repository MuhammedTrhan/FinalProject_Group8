class_name Hideable
extends Interactable
## A piece of furniture the player can hide inside/under (bed,
## table with a floor-length cloth, ...).


@onready var hide_point = $HideMarker
@onready var stand_point = $StandMarker

var is_occupied: bool = false
var occupant: Node2D = null


func _ready() -> void:
	if is_occupied:
		prompt_text = "Reveal"
	else:
		prompt_text = "Hide"


# Primary (Interact/Space): hide, or reveal if the actor is the one
# currently hidden here. (Re-triggering Interact while hidden reaches this
# the normal way - the actor's sensor keeps overlapping this InterractionArea
# even with collision_layer = 0, since that only affects being detected as a
# body, not this object's own detection of the actor.)
func _do_interact(actor: Node2D) -> Interactions.InteractionType:
	if is_occupied and occupant == actor:
		reveal_player(actor)
	elif not is_occupied:
		hide_player(actor)
	return Interactions.InteractionType.NONE


# A hidden actor can also exit with movement keys, not just Interact - but
# only while they'd normally be able to move themselves right now.
func _unhandled_input(event: InputEvent) -> void:
	if not is_occupied or not is_instance_valid(occupant) or not _is_movement_key(event):
		return
	if _occupant_is_input_locked():
		return
	reveal_player(occupant)


## True while `occupant` shouldn't be allowed to self-reveal via a raw
## movement key - specifically while EscortController is puppeting its
## position (is_being_escorted) or mid stairs-teleport (is_teleporting).
func _occupant_is_input_locked() -> bool:
	return ("is_being_escorted" in occupant and occupant.is_being_escorted) \
		or ("is_teleporting" in occupant and occupant.is_teleporting)


func hide_player(actor: Node2D) -> void:
	is_occupied = true
	occupant = actor

	# The hiding spot's own collision would otherwise block the player from
	# standing at hide_point if that marker sits inside/behind the sprite.
	actor.add_collision_exception_with(self)

	if actor.has_method("set_interaction_lock"):
		actor.set_interaction_lock(self)

	if actor.has_method("set_hidden"):
		actor.set_hidden(true, hide_point.global_position, self)

	prompt_text = "Reveal"


func reveal_player(actor: Node2D) -> void:
	if is_instance_valid(occupant):
		occupant.remove_collision_exception_with(self)

	is_occupied = false
	occupant = null

	if actor.has_method("clear_interaction_lock"):
		actor.clear_interaction_lock(self)

	if actor.has_method("set_hidden"):
		# stand_point itself might overlap a wall/furniture placed too close
		# to it - nudge to the nearest clear spot instead if so.
		var spawn_pos := PhysicsQueryUtils.find_clear_point(self, stand_point.global_position)
		actor.set_hidden(false, spawn_pos, self)

	prompt_text = "Hide"

func _is_movement_key(event: InputEvent) -> bool:
	return event.is_action_pressed("up") or event.is_action_pressed("down") or event.is_action_pressed("left") or event.is_action_pressed("right")
