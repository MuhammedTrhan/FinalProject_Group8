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

# This is how Player's sensor finds this object at all.
@warning_ignore("unused_private_class_variable")
@onready var _interactable_meta_set: bool = _set_interactable_meta()


func _set_interactable_meta() -> bool:
	interaction_area.set_meta(&"interactable", self)
	return true


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
