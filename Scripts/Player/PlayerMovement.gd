class_name Player
extends CharacterBody2D


const MAX_SPEED = 150.0
# How fast the player speeds up (pixels per second squared)
const ACCELERATION = 800.0
# How fast the player slides to a stop when letting go
const FRICTION = 600.0

@onready var anim_handler = $PlayerAnimationHandler
@onready var fade_rect = $TransitionLayer/FadeRect
@onready var camera = $Camera2D
@onready var sprite = $Sprite2D
@onready var interract_area: Area2D = $InterractArea
@onready var prompt_label: Label = $PromptLabel
@onready var message_label: Label = $MessageLabel
@onready var message_timer: Timer = $MessageTimer

var is_teleporting: bool = false
var accept_input: bool = true
var teleport_tween: Tween

# Interactable candidates currently overlapping InterractArea.
var _candidates: Array[Interactable] = []
var _last_primary_prompt: String = ""
var _last_secondary_prompt: String = ""


func _ready() -> void:
	interract_area.area_entered.connect(_on_interract_area_entered)
	interract_area.area_exited.connect(_on_interract_area_exited)

	GameEvents.interaction_prompt_changed.connect(_on_interaction_prompt_changed)
	GameEvents.message_requested.connect(_on_message_requested)
	message_timer.timeout.connect(message_label.hide)

	prompt_label.hide()
	message_label.hide()


func _physics_process(delta: float) -> void:
	handle_movement(delta)

	anim_handler.update_animations(velocity)


func _process(_delta: float) -> void:
	_update_interaction_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("Interact"):
		_try_interact(false)
	elif event.is_action_pressed("action"):
		_try_interact(true)


func _try_interact(secondary: bool) -> void:
	var candidate := _get_nearest_candidate()
	if candidate == null:
		return

	get_viewport().set_input_as_handled()

	var result := candidate.secondary_interact(self) if secondary else candidate.interact(self)
	if result != Interactions.InteractionType.NONE:
		handle_interactions()
		anim_handler.handle_interaction_anim(result)


func _on_interract_area_entered(area: Area2D) -> void:
	var interactable = area.get_meta(&"interactable", null)
	if interactable != null and not _candidates.has(interactable):
		_candidates.append(interactable)


func _on_interract_area_exited(area: Area2D) -> void:
	var interactable = area.get_meta(&"interactable", null)
	if interactable != null and _candidates.has(interactable):
		_candidates.erase(interactable)


# Nearest candidate wins - by distance to its interaction shape, not its
# origin (see Interactable.get_distance_to()). `priority` breaks ties.
func _get_nearest_candidate() -> Interactable:
	var nearest: Interactable = null
	var nearest_dist := INF

	for candidate in _candidates:
		if not is_instance_valid(candidate):
			continue

		var dist := candidate.get_distance_to(global_position)
		if nearest == null or dist < nearest_dist or (dist == nearest_dist and candidate.priority > nearest.priority):
			nearest = candidate
			nearest_dist = dist

	return nearest


func _update_interaction_prompt() -> void:
	var candidate := _get_nearest_candidate()
	var primary := candidate.prompt_text if candidate else ""
	var secondary := candidate.secondary_prompt_text if candidate else ""

	if primary != _last_primary_prompt or secondary != _last_secondary_prompt:
		_last_primary_prompt = primary
		_last_secondary_prompt = secondary
		GameEvents.interaction_prompt_changed.emit(primary, secondary)


func _on_interaction_prompt_changed(primary: String, secondary: String) -> void:
	var lines: Array[String] = []
	if primary != "":
		lines.append("[Space] %s" % primary)
	if secondary != "":
		lines.append("[E] %s" % secondary)

	if lines.is_empty():
		prompt_label.hide()
	else:
		prompt_label.text = "\n".join(lines)
		prompt_label.show()


func _on_message_requested(text: String) -> void:
	message_label.text = text
	message_label.show()
	message_timer.start()


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


func start_teleport(target_position: Vector2, tween_target_pos: Vector2, stairs_end: Vector2 = Vector2.ZERO, duration: float = 0.5) -> void:
	if teleport_tween:
		teleport_tween.kill() # Stop any existing teleport tween
		
	# Set the player as teleporting
	is_teleporting = true
	velocity = Vector2.ZERO

	# Make sure the player is looking at the target position of the tween before starting the tween
	var look_dir: String = find_look_direction(tween_target_pos, global_position)
	anim_handler.set_facing_direction(look_dir)

	teleport_tween = create_tween()
	# PHASE 1: Tween the player into the stairs AND fade the screen to black simultaneously
	teleport_tween.set_parallel(true)
	teleport_tween.tween_property(self, "global_position", tween_target_pos, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	teleport_tween.tween_property(fade_rect, "modulate:a", 1.0, duration)

	# PHASE 2: Once black, turn off parallel mode and trigger the teleport
	teleport_tween.set_parallel(false)
	teleport_tween.tween_callback(func(): end_teleport(target_position, duration, stairs_end))


func end_teleport(target_position: Vector2, fade_duration: float, stairs_end: Vector2 = Vector2.ZERO) -> void:
	# Teleport the player to the target spawn position
	global_position = target_position
	# Force the camera to instantly snap to the new floor without panning
	camera.reset_smoothing()
	# Reset the velocity of the player to zero to prevent it from moving after teleportation
	velocity = Vector2.ZERO

	# Give control back to the player
	is_teleporting = false

	# Calculate the facing direction after the teleport. It should face away from the stairs.
	var look_dir: String = find_look_direction(global_position, stairs_end)
	anim_handler.set_facing_direction(look_dir)
		
	# PHASE 3: Create a new tween to fade the screen back to transparent
	var fade_in_tween = create_tween()
	fade_in_tween.tween_property(fade_rect, "modulate:a", 0.0, fade_duration)

# Called by EscortController after a day/night transition, once the screen
# should already be covered by the fade. No local fade of its own.
func snap_to_spawn(spawn_position: Vector2) -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	camera.reset_smoothing()


# Called by Sitable to snap the player to a seat/stand-up marker and face
# them away from the chair. The look direction is `facing_to - facing_from`
# regardless of whether this is a sit or a stand - same formula both ways.
func orient_for_furniture(snap_pos: Vector2, facing_from: Vector2, facing_to: Vector2) -> void:
	global_position = snap_pos
	anim_handler.set_facing_direction(find_look_direction(facing_to, facing_from))


# Called by Hideable when the player hides inside/under (or is revealed
# from) a piece of furniture. Unlike sitting, there is no animation for
# this - the player simply disappears, and is frozen in place
# (collision_layer = 0) so the enemy's TouchArea and any raycast pass through them.
func set_hidden(is_hidden: bool, snap_pos: Vector2, hideable: Hideable = null) -> void:
	global_position = snap_pos

	if is_hidden:
		collision_layer = 0
		sprite.hide()
		accept_input = false
	else:
		collision_layer = Layers.PLAYER
		sprite.show()
		accept_input = true

	GameEvents.player_hidden_changed.emit(is_hidden, hideable)


# Stop player movement during interactions and resume it after the interaction animation is finished
func handle_interactions() -> void:
	if not anim_handler.interact_anim_finish.is_connected(_on_interact_anim_finish):
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


func find_look_direction(target_position: Vector2, start_position: Vector2) -> String:
	var direction_vector = (target_position - start_position).normalized()
	if abs(direction_vector.x) >= abs(direction_vector.y):
		if direction_vector.x > 0:
			return "right"
		else:
			return "left"
	else:
		if direction_vector.y > 0:
			return "down"
		else:
			return "up"
