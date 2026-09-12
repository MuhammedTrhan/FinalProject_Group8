class_name PersonalityAreaVisual
extends Node2D
## Always-visible (not debug-only) rendering of the active personality's
## detection areas: the inner area - Perception's own cone - filled with
## fill_color, and the outer follow area (PersonalityProfile.follow_area_radius)
## as an unfilled ring. Reads live Perception/PersonalityProfile values already
## driving gameplay.

@export var fill_color: Color = Color(1, 1, 0, 0.25)
@export var ring_color: Color = Color(1, 1, 1, 0.6)
@export var ring_width: float = 2.0

const SEGMENTS := 48

var _enemy: Enemy


func _ready() -> void:
	_enemy = get_parent()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not _enemy or not _enemy.profile:
		return

	_draw_outer_ring()

	# A vision area that can't currently trigger anything would be a
	# misleading indicator - Enemy._check_perception_transitions() only ever
	# runs outside State.SPECIAL, so Overwhelmed's cone is inert for as long
	# as he's frozen rocking/panicking. Once he calms down and resumes
	# Patrol, Perception is live again and his cone should reappear.
	if _enemy.state != Enemy.State.SPECIAL:
		_draw_inner_area()


func _draw_outer_ring() -> void:
	var radius := _enemy.profile.follow_area_radius
	if radius <= 0.0:
		return
	draw_arc(Vector2.ZERO, radius, 0, TAU, SEGMENTS, ring_color, ring_width)


func _draw_inner_area() -> void:
	var perception := _enemy.perception
	if perception.view_distance <= 0.0:
		return

	var facing_angle := perception.facing_dir.angle()
	var half_fov := deg_to_rad(perception.fov_degrees * 0.5)

	var points := PackedVector2Array()
	points.append(Vector2.ZERO)
	for i in SEGMENTS + 1:
		var t := float(i) / float(SEGMENTS)
		var angle := facing_angle - half_fov + t * (half_fov * 2.0)
		points.append(Vector2.RIGHT.rotated(angle) * perception.view_distance)

	draw_colored_polygon(points, fill_color)
