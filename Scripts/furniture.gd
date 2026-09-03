extends StaticBody2D
class_name Furniture


@export var is_active := false

@onready var info_label = $InfoLabel
@onready var active_sprite: Sprite2D = $ActiveSprite
@onready var inactive_sprite: Sprite2D = $InactiveSprite

# Holds bodies: {"player": body_ref, "enemy": body_ref}
var bodies_nearby: Dictionary = {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	info_label.hide()

	if is_active: activate()
	else: deactivate()
	
func _unhandled_input(event: InputEvent) -> void:
	if not "player" in bodies_nearby:
		return
	
	var player_body = bodies_nearby["player"]
	if not is_instance_valid(player_body):
		return
	
	if event.is_action_pressed("action"):
		if is_active:
			deactivate()
		else:
			activate()

func _on_interraction_area_body_entered(body: Node2D) -> void:
	var body_key: String
	
	if body.is_in_group("player"):
		body_key = "player"
		info_label.show()
	else:
		body_key = "enemy"
	
	bodies_nearby[body_key] = body


func _on_interraction_area_body_exited(body: Node2D) -> void:
	var body_key: String

	if body.is_in_group("player"):
		body_key = "player"
		info_label.hide()
	else:
		body_key = "enemy"
	
	if body_key in bodies_nearby and bodies_nearby[body_key] == body:
		bodies_nearby.erase(body_key)


func activate() -> void:
	is_active = true

	active_sprite.show()
	inactive_sprite.hide()

func deactivate() -> void:
	is_active = false

	active_sprite.hide()
	inactive_sprite.show()
