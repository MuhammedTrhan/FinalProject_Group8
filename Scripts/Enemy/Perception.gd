class_name Perception
extends Node2D
## Vision-cone + last-known-position tracking for the enemy. Code-based
## (distance + cardinal-snapped angle + one confirming raycast) rather than
##
## Deliberately has no Area2D of its own: hiding integrates for free because
## the hidden player's collision_layer is 0 (the raycast below physically
## misses them), and GameEvents.player_hidden_changed is checked first as a
## belt-and-braces companion in case that trick ever breaks.
##
## Not self-driving (no _physics_process) - Enemy calls update() once per
## physics frame so the state machine stays in full control of timing.

@export var view_distance: float = 180.0
@export var fov_degrees: float = 90.0
@export var detect_dwell: float = 1.0

## Set by Enemy every frame before calling update() - a cardinal Vector2
## (UP/DOWN/LEFT/RIGHT), matching EnemyAnimationHandler.get_facing_vector().
## Fairness rule: the cone follows what the LPC sprite is actually facing on
## screen, not a raw continuous nav heading.
var facing_dir: Vector2 = Vector2.DOWN

var last_known_position: Vector2

var _dwell_timer: float = 0.0
var _player_hidden: bool = false
var _player: Node2D
## Cached result of the last update() call. player_hidden_changed can fire
## mid-frame with the player's collision_layer already at 0 (a raycast would
## miss them by then) - Enemy uses this to distinguish between "was I actually
## watching them the instant they hid" from "they were already out of sight".
var _was_visible: bool = false


func _ready() -> void:
	_player = get_tree().get_first_node_in_group(&"player")
	GameEvents.player_hidden_changed.connect(_on_player_hidden_changed)


func _on_player_hidden_changed(is_hidden: bool) -> void:
	_player_hidden = is_hidden


## Call once per physics frame. Returns true the instant the player has been
## continuously visible for detect_dwell seconds.
func update(delta: float) -> bool:
	_was_visible = is_player_visible()
	if _was_visible:
		_dwell_timer += delta
		last_known_position = _player.global_position
	else:
		_dwell_timer = 0.0
	return _dwell_timer >= detect_dwell


func was_visible_last_frame() -> bool:
	return _was_visible


func is_player_visible() -> bool:
	if _player_hidden or _player == null or not is_instance_valid(_player):
		return false

	var to_player := _player.global_position - global_position
	var distance := to_player.length()
	if distance > view_distance:
		return false

	var angle_to_player := absf(rad_to_deg(facing_dir.angle_to(to_player)))
	if angle_to_player > fov_degrees * 0.5:
		return false

	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		global_position, _player.global_position, Layers.PLAYER | Layers.WALLS
	)
	var result := space_state.intersect_ray(query)
	# Nothing hit (shouldn't happen, the player is on the mask) or the player
	# itself was the first thing hit -> clear line of sight.
	return result.is_empty() or result.get("collider") == _player


func get_player() -> Node2D:
	return _player
