class_name Door
extends StaticBody2D

enum DoorInteraction {
	OPEN,
	CLOSE,
	LOCK,
	UNLOCK
}

signal door_interacted(interaction: DoorInteraction)

@export var is_locked := false
@export var required_key: PackedScene

@onready var info_label = $DoorInfoLabel
@onready var hitbox = $Hitbox
@onready var closed_door: Sprite2D = $DoorClosed
@onready var opened_door: Sprite2D = $DoorOpen
@onready var lock_icon: Sprite2D = $LockIcon

var player_in_area := false
var is_open := false
var interacting_bodies: Dictionary = {} # Holds bodies: {"player": body_ref, "enemy": body_ref}
var error_message_label: Label


func _ready() -> void:
	info_label.hide()
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


func _unhandled_input(event: InputEvent) -> void:
	if not player_in_area or not "player" in interacting_bodies:
		return
	
	var player_body = interacting_bodies["player"]
	if not is_instance_valid(player_body):
		return

	if event.is_action_pressed("action"):
		if has_required_key():
			if not is_open:
				toogle_lock()
			else:
				if not is_locked:
					show_error_message("I need to close this door to lock it.")
				else:
					show_error_message("I need to close this door to unlock it.")

			# If the door is still open somehow, close it when locking it.
			if is_locked and is_open:
				close_door()
			
			update_info_label()
		
		else:
			show_error_message("I don't have the right key.")

	elif event.is_action_pressed("Interact") and not is_locked:
		if is_open:
			close_door()
		else:
			open_door()

	elif event.is_action_pressed("Interact") and is_locked:
		show_error_message("I need to unlock this door first.")


func open_door() -> void:
	is_open = true
	hitbox.set_deferred("disabled", true)
	closed_door.hide()
	opened_door.show()

	if player_in_area:
		update_info_label()
	
	door_interacted.emit(DoorInteraction.OPEN)


func close_door() -> void:
	is_open = false
	hitbox.set_deferred("disabled", false)

	closed_door.show()
	opened_door.hide()

	if player_in_area:
		update_info_label()
		info_label.show()
	
	door_interacted.emit(DoorInteraction.CLOSE)
	

func toogle_lock() -> void:
	is_locked = not is_locked
	if is_locked:
		lock_icon.show()
		door_interacted.emit(DoorInteraction.LOCK)
	else:
		lock_icon.hide()
		door_interacted.emit(DoorInteraction.UNLOCK)

	if player_in_area:
		update_info_label()


func has_required_key() -> bool:
	if not "player" in interacting_bodies:
		return false
	var player_body = interacting_bodies["player"]
	return required_key == null or (player_body.has_method("has_key") and player_body.has_key(required_key))


func update_info_label() -> void:
	if is_open:
		info_label.text = "Press 'Space' to close the door"
	elif is_locked:
		info_label.text = "Press 'E' to unlock the door."
	else:
		info_label.text = "Press 'Space' to open the door\n Press 'E' to lock the door."


func show_error_message(message: String) -> void:
	if not "player" in interacting_bodies:
		return
	
	var player_body = interacting_bodies["player"]
	if not is_instance_valid(player_body):
		return

	if is_instance_valid(error_message_label):
		error_message_label.queue_free()

	error_message_label = Label.new()
	error_message_label.text = message
	error_message_label.position = Vector2(-90, -64)
	error_message_label.z_index = 10
	error_message_label.add_theme_color_override("font_color", Color.WHITE)
	error_message_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	error_message_label.add_theme_constant_override("shadow_offset_x", 2)
	error_message_label.add_theme_constant_override("shadow_offset_y", 2)
	player_body.add_child(error_message_label)

	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(error_message_label):
		error_message_label.queue_free()
		error_message_label = null

	
func _on_interraction_area_body_entered(body: Node2D) -> void:
	var body_key: String
	
	if body.is_in_group("player"):
		body_key = "player"
		player_in_area = true
		update_info_label()
		info_label.show()
	else:
		body_key = "enemy"
	
	interacting_bodies[body_key] = body

	# Connect the door_interacted signal to the interacting body if it has the on_door_interacted method
	if body.has_method("on_door_interacted"):
		door_interacted.connect(body.on_door_interacted)


func _on_interraction_area_body_exited(body: Node2D) -> void:
	var body_key: String
	
	if body.is_in_group("player"):
		body_key = "player"
		player_in_area = false
		info_label.hide()
	else:
		body_key = "enemy"
	
	if body_key in interacting_bodies and interacting_bodies[body_key] == body:
		interacting_bodies.erase(body_key)
		
		if body.has_method("on_door_interacted"):
			if door_interacted.is_connected(body.on_door_interacted):
				door_interacted.disconnect(body.on_door_interacted)
