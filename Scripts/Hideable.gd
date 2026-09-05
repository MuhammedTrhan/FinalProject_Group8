extends StaticBody2D
## A piece of furniture the player can hide inside/under (bed, table with a
## floor-length cloth, ...). Mirrors Sitable.gd's structure so that when the
## Faz 1 Interactable refactor lands, folding this in alongside
## Door/Furniture/Sitable is the same mechanical change - nothing here is
## throwaway.

signal hide_triggered(isHidden: bool, hidePosition: Vector2, standPosition: Vector2)

@onready var info_label = $InfoLabel
@onready var hide_point = $HideMarker
@onready var stand_point = $StandMarker

var player_inside: bool = false
var is_occupied: bool = false
# Holds bodies: {"player": body_ref, "enemy": body_ref}
var interacting_bodies: Dictionary = {}
var occupant: Node2D = null


func _ready() -> void:
	if not player_inside:
		info_label.hide()
	else:
		info_label.show()


func _on_interraction_area_body_entered(body: Node2D) -> void:
	var body_key: String

	if body.is_in_group("player"):
		body_key = "player"
		player_inside = true

		if not is_occupied:
			info_label.show()
	else:
		body_key = "enemy"

	interacting_bodies[body_key] = body

	# Guarded: revealing the player restores collision_layer, which makes
	# this Area2D re-detect them as "entering" again (see the comment in
	# _on_interraction_area_body_exited) even though the connection was
	# never dropped - connecting twice would otherwise throw
	# "Signal is already connected".
	if body.has_method("on_hide_triggered") and not hide_triggered.is_connected(body.on_hide_triggered):
		hide_triggered.connect(body.on_hide_triggered)
		
	print("Hideable: body entered: ", body_key, " player_inside=", player_inside, " interacting_bodies=", interacting_bodies)


func _on_interraction_area_body_exited(body: Node2D) -> void:
	var body_key: String

	if body.is_in_group("player"):
		body_key = "player"
		# if the player is still inside, they are probably hiding
		# and will be revealed soon. Do not set the player_inside flag yet,
		# it will be set after reveal_player() emits hide_triggered(false, ...).
		# If we set player_inside = false here, the player will trap under forever.
		if not is_occupied:
			player_inside = false
			info_label.hide()
	else:
		body_key = "enemy"

	# Keep the reference if they are hidden, otherwise they can't be revealed
	if body_key in interacting_bodies and interacting_bodies[body_key] == body and not is_occupied:
		interacting_bodies.erase(body_key)

	# Do not disconnect while occupied. hide_player() sets
	# collision_layer = 0 on the player, which removes them from this
	# Area2D's layer/mask match and fires body_exited on the next
	# physics tick. If we disconnected here, reveal_player()'s 
	# hide_triggered.emit(false, ...) would never reach the player.
	if not is_occupied and body.has_method("on_hide_triggered") and hide_triggered.is_connected(body.on_hide_triggered):
		hide_triggered.disconnect(body.on_hide_triggered)
		print("Hideable: disconnected hide_triggered from ", body.name, " because not occupied")
		
	print("Hideable: body exited: ", body_key, " player_inside=", player_inside, " interacting_bodies=", interacting_bodies)


func _unhandled_input(event: InputEvent) -> void:
	if not player_inside or not "player" in interacting_bodies:
		return

	var player_body = interacting_bodies["player"]
	if not is_instance_valid(player_body):
		return

	# IF HIDDEN: 'Interact' (Space) or a movement key reveals
	if is_occupied and occupant == player_body:
		if event.is_action_pressed("Interact") or _is_movement_key(event):
			reveal_player()

	# IF NOT HIDDEN: 'Interact' (Space) hides
	elif player_inside and not is_occupied:
		if event.is_action_pressed("Interact"):
			hide_player(player_body)
		
		
	print("Hideable: unhandled_input: player_inside=", player_inside, " is_occupied=", is_occupied, " occupant=", occupant)


func hide_player(character: Node2D) -> void:
	is_occupied = true
	occupant = character
	info_label.hide()

	# The hiding spot's own collision would otherwise block the player from
	# standing at hide_point if that marker sits inside/behind the sprite.
	occupant.add_collision_exception_with(self)

	hide_triggered.emit(true, hide_point.global_position, stand_point.global_position)


func reveal_player() -> void:
	if is_instance_valid(occupant):
		occupant.remove_collision_exception_with(self)

	is_occupied = false
	occupant = null

	hide_triggered.emit(false, hide_point.global_position, stand_point.global_position)

	if player_inside:
		info_label.show()


func _is_movement_key(event: InputEvent) -> bool:
	return event.is_action_pressed("up") or event.is_action_pressed("down") or event.is_action_pressed("left") or event.is_action_pressed("right")
