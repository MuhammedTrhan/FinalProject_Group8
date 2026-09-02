extends CharacterBody2D

const MAX_SPEED = 150.0
# How fast the player speeds up (pixels per second squared)
const ACCELERATION = 800.0
# How fast the player slides to a stop when letting go
const FRICTION = 600.0

@export var keys: Array[PackedScene] = []

@onready var anim_handler = $PlayerAnimationHandler
@onready var fade_rect = $TransitionLayer/FadeRect
@onready var camera = $Camera2D

var is_teleporting: bool = false
var accept_input: bool = true
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
	var direction: Vector2

	if accept_input:
		direction = Input.get_vector("left", "right", "up", "down")
	else:
		direction = Vector2.ZERO

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


func start_teleport(target_position: Vector2, tween_target_pos: Vector2, face_dir: Vector2 = Vector2.DOWN, duration: float = 0.5) -> void:
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
	# PHASE 1: Tween the player into the stairs AND fade the screen to black simultaneously
	teleport_tween.set_parallel(true)
	teleport_tween.tween_property(self, "global_position", tween_target_pos, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	teleport_tween.tween_property(fade_rect, "modulate:a", 1.0, duration)

	# PHASE 2: Once black, turn off parallel mode and trigger the teleport
	teleport_tween.set_parallel(false)
	teleport_tween.tween_callback(func(): end_teleport(target_position, duration, face_dir))


func end_teleport(target_position: Vector2, fade_duration: float, face_dir: Vector2 = Vector2.DOWN) -> void:
	# Teleport the player to the target spawn position
	global_position = target_position
	# Force the camera to instantly snap to the new floor without panning
	camera.reset_smoothing()
	# Reset the velocity of the player to zero to prevent it from moving after teleportation
	velocity = Vector2.ZERO

	# Give control back to the player
	is_teleporting = false

	# Calculate the facing direction after the teleport. It should face away from the stairs.
	if abs(face_dir.x) >= abs(face_dir.y):
		if face_dir.x > 0:
			anim_handler.set_facing_direction("right")
		else:
			anim_handler.set_facing_direction("left")
	else:
		if face_dir.y > 0:
			anim_handler.set_facing_direction("down")
		else:
			anim_handler.set_facing_direction("up")
		
	# PHASE 3: Create a new tween to fade the screen back to transparent
	var fade_in_tween = create_tween()
	fade_in_tween.tween_property(fade_rect, "modulate:a", 0.0, fade_duration)

func on_door_interacted(interaction: int) -> void:
	# Pass the interaction to the animation handler to play the appropriate animation
	anim_handler.handle_door_interaction(interaction)
	handle_interactions()


# Stop player movement during interactions and resume it after the interaction animation is finished
func handle_interactions() -> void:
	anim_handler.interact_anim_finish.connect(_on_interact_anim_finish)
	stop_player_movement()

func _on_interact_anim_finish() -> void:
	# Resume player movement after the interaction animation is finished
	resume_player_movement()

	if anim_handler.interact_anim_finish.is_connected(_on_interact_anim_finish):
		anim_handler.interact_anim_finish.disconnect(_on_interact_anim_finish)

func stop_player_movement() -> void:
	# Stop accepting input and set velocity to zero
	velocity = Vector2.ZERO
	accept_input = false

func resume_player_movement() -> void:
	# Resume accepting input
	accept_input = true