class_name UVFlashlight
extends Node2D
## The UV flashlight's cone - toggled by GameEvents.item_use_requested
## (is_active), drawn in front of the player, and used to reveal any
## UVClue it currently covers.

const SEGMENTS := 24

# Temporary stand-in for Dev1's Inventory UI - U, debug builds only. See
# docs/CONTRACT.md's debug key table and ToolUser.gd's debug_use_crowbar.
const UV_FLASHLIGHT_ITEM := preload("res://Resources/Items/uv_flashlight.tres")

@export var range: float = 96.0
@export var half_fov_degrees: float = 35.0
@export var fill_color: Color = Color(0.6, 0.2, 0.9, 0.35)

@onready var player: Player = get_parent()

var _debug_active := false


func _ready() -> void:
	GameEvents.item_use_requested.connect(_on_item_use_requested)
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return

	if event.is_action_pressed("debug_toggle_uv"):
		_debug_active = not _debug_active
		GameEvents.item_use_requested.emit(UV_FLASHLIGHT_ITEM, _debug_active)


func _on_item_use_requested(item: ItemData, is_active: bool) -> void:
	if item.id != &"uv_flashlight":
		return

	visible = is_active
	if not is_active:
		# _physics_process() below stops calling set_lit() the instant it is
		# not visible, so without this, whatever was lit right when the
		# light turned off would just stay showing forever.
		for clue in get_tree().get_nodes_in_group(&"uv_clues"):
			clue.set_lit(false)


func _physics_process(_delta: float) -> void:
	if not visible:
		return

	rotation = _facing_to_angle(player.anim_handler.last_direction)
	queue_redraw()

	var facing := Vector2.RIGHT.rotated(rotation)
	for clue in get_tree().get_nodes_in_group(&"uv_clues"):
		clue.set_lit(_is_in_cone(clue.global_position, facing))


func _is_in_cone(point: Vector2, facing: Vector2) -> bool:
	var to_point := point - global_position
	if to_point.length() > range:
		return false
	if absf(rad_to_deg(facing.angle_to(to_point))) > half_fov_degrees:
		return false

	# Confirming raycast, same as Perception.gd - a wall between the
	# flashlight and the mark blocks it.
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, point, Layers.WALLS)
	return space_state.intersect_ray(query).is_empty()


func _draw() -> void:
	var half_fov := deg_to_rad(half_fov_degrees)
	var points := PackedVector2Array()
	points.append(Vector2.ZERO)
	for i in SEGMENTS + 1:
		var t := float(i) / float(SEGMENTS)
		var angle := -half_fov + t * (half_fov * 2.0)
		points.append(Vector2.RIGHT.rotated(angle) * range)
	draw_colored_polygon(points, fill_color)


func _facing_to_angle(direction: String) -> float:
	match direction:
		"up": return -PI / 2.0
		"down": return PI / 2.0
		"left": return PI
		_: return 0.0   # "right" / fallback
