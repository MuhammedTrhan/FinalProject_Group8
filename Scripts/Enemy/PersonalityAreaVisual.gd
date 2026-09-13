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
	# Enemy's own root scale (see enemy.tscn) would otherwise shrink
	# everything drawn here below its true world-space size - compensate so
	# radii drawn in local space match the actual world-space trigger
	# distances (PersonalityModule/ParanoidModule logic reads global_position
	# distances directly, unaffected by this node's parent's scale).
	if _enemy and _enemy.scale.x != 0.0 and _enemy.scale.y != 0.0:
		scale = Vector2.ONE / _enemy.scale


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not _enemy or not _enemy.profile:
		return

	# Nothing to show at night/during the escort walk/mid-stairs-crossing -
	# the enemy isn't running its normal perception-driven behaviour then.
	if not GameManager.is_day() or _enemy.escort_controller.is_escorting() or _enemy.is_teleporting:
		return

	_draw_outer_ring()

	# A vision area that can't currently trigger anything would be a
	# misleading indicator - Enemy._check_perception_transitions() only runs
	# outside State.SPECIAL, UNLESS the active module opts back in (Paranoid's
	# deposit walk is fully alert; Overwhelmed's rocking/panicking is not).
	if _enemy.state != Enemy.State.SPECIAL or (_enemy.active_module and _enemy.active_module.reacts_to_perception_during_special()):
		_draw_inner_area()


func _draw_outer_ring() -> void:
	var radius := _enemy.profile.follow_area_radius
	if radius <= 0.0:
		return

	var override_color := _enemy.active_module.get_outer_area_fill_color() if _enemy.active_module else Color.TRANSPARENT
	if override_color.a > 0.0:
		# Fills from the center outward (radius scales with progress) rather
		# than fading in place, at a constant color/opacity.
		var progress := _enemy.active_module.get_follow_progress() if _enemy.active_module else 0.0
		_draw_filled_circle(radius * progress, override_color)
	else:
		draw_arc(Vector2.ZERO, radius, 0, TAU, SEGMENTS, ring_color, ring_width)


func _draw_inner_area() -> void:
	var perception := _enemy.perception
	if perception.view_distance <= 0.0:
		return

	# A fov_degrees of (essentially) 360 is Forgetful's inner circle. Drawing
	# it as a cone would mean the sector's start and end rays land on nearly
	# - but, due to float rounding, not always exactly - the same point,
	# which the renderer's polygon triangulator intermittently rejects
	# ("Invalid polygon data, triangulation failed"). A plain closed N-gon
	# has no such seam, so use it whenever there's no real cone to show.
	if perception.fov_degrees >= 359.99:
		_draw_filled_circle(perception.view_distance, fill_color)
	else:
		_draw_filled_cone(perception)


func _draw_filled_circle(radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in SEGMENTS:
		var angle := TAU * float(i) / float(SEGMENTS)
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	draw_colored_polygon(points, color)


func _draw_filled_cone(perception: Perception) -> void:
	var facing_angle := perception.facing_dir.angle()
	var half_fov := deg_to_rad(perception.fov_degrees * 0.5)

	var points := PackedVector2Array()
	points.append(Vector2.ZERO)
	for i in SEGMENTS + 1:
		var t := float(i) / float(SEGMENTS)
		var angle := facing_angle - half_fov + t * (half_fov * 2.0)
		points.append(Vector2.RIGHT.rotated(angle) * perception.view_distance)

	draw_colored_polygon(points, fill_color)
