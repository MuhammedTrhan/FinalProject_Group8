class_name TrashCan
extends ContainerFurniture
## A bin has no open/closed state: every interact just looks inside, so it
## skips Furniture's activate/deactivate toggle (which other containers like
## closets keep).


func _do_interact(_actor: Node2D) -> Interactions.InteractionType:
	_look_inside()
	return Interactions.InteractionType.NONE
