extends CharacterBody2D

const MAX_SPEED = 150.0
# How fast the player speeds up (pixels per second squared)
const ACCELERATION = 800.0
# How fast the player slides to a stop when letting go
const FRICTION = 600.0

@export var keys: Array[PackedScene] = []

@onready var anim_handler = $PlayerAnimationHandler

var is_teleporting := false
var teleport_tween: Tween


func _physics_process(delta: float) -> void:
	handle_movement(delta)

	anim_handler.update_animations(velocity)


func handle_movement(_delta: float) -> void:
	# Skip movement handling if the player is currently teleporting
	if is_teleporting:
		return
	
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_vector("left", "right", "up", "down")

	if direction != Vector2.ZERO:
		var target_velocity: Vector2 = direction * MAX_SPEED
		
		velocity = velocity.move_toward(target_velocity, ACCELERATION * _delta)

	else:
		# If no input, slow down the player smoothly
		# Instead of instantly stopping, smoothly slow down the player independent of framerate.
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * _delta)

	move_and_slide()


func has_key(key_scene: PackedScene) -> bool:
	return key_scene == null or keys.has(key_scene)


func add_key(key_scene: PackedScene) -> void:
	if key_scene != null and not keys.has(key_scene):
		keys.append(key_scene)


func start_teleport(target_position: Vector2, tween_target_pos: Vector2, duration: float = 0.5) -> void:
	if teleport_tween:
		teleport_tween.kill() # Stop any existing teleport tween
		
	# Set the player as teleporting
	is_teleporting = true
	velocity = Vector2.ZERO

	# Make sure the player is looking at the target position of the tween before starting the tween
	var dir := (tween_target_pos - global_position).normalized()
	if abs(dir.x) >= abs(dir.y):
		if dir.x > 0:
			anim_handler.set_facing_direction("right")
		else:
			anim_handler.set_facing_direction("left")
	else:
		if dir.y > 0:
			anim_handler.set_facing_direction("down")
		else:
			anim_handler.set_facing_direction("up")

	teleport_tween = create_tween()
	teleport_tween.set_trans(Tween.TRANS_SINE)
	teleport_tween.set_ease(Tween.EASE_IN_OUT)
	teleport_tween.tween_property(self, "global_position", tween_target_pos, duration)
	teleport_tween.finished.connect(func(): end_teleport(target_position))


func end_teleport(target_position: Vector2) -> void:
	is_teleporting = false
	velocity = Vector2.ZERO

	# Teleport the player to the target spawn position
	global_position = target_position

	# Update the last_direction of the player based on the direction to the target spawn
	var dir := (target_position - global_position).normalized()

	if abs(dir.x) >= abs(dir.y):
		if dir.x > 0:
			anim_handler.set_facing_direction("right")
		else:
			anim_handler.set_facing_direction("left")
	else:
		if dir.y > 0:
			anim_handler.set_facing_direction("down")
		else:
			anim_handler.set_facing_direction("up")

	# Reset the velocity of the player to zero to prevent it from moving after teleportation
	velocity = Vector2.ZERO
