class_name Furniture
extends Interactable


@export var is_active := false

@onready var active_sprite: Sprite2D = $ActiveSprite
@onready var inactive_sprite: Sprite2D = $InactiveSprite


func _ready() -> void:
	if is_active: activate()
	else: deactivate()


# Primary (Interact/Space): toggle.
func _do_interact(_actor: Node2D) -> Interactions.InteractionType:
	if is_active:
		deactivate()
	else:
		activate()
	return Interactions.InteractionType.NONE


func activate() -> void:
	is_active = true

	active_sprite.show()
	inactive_sprite.hide()


func deactivate() -> void:
	is_active = false

	active_sprite.hide()
	inactive_sprite.show()
