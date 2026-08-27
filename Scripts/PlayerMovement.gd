extends CharacterBody2D

const MAX_SPEED = 150.0
# How fast the player speeds up (pixels per second squared)
const ACCELERATION = 800.0
# How fast the player slides to a stop when letting go
const FRICTION = 600.0

@export var keys: Array[PackedScene] = []

@onready var anim_handler = $PlayerAnimationHandler


func _physics_process(delta: float) -> void:
	handle_movement(delta)

	anim_handler.update_animations(velocity)


func handle_movement(_delta: float) -> void:
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
