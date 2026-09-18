class_name EnemyDebugOverlay
extends Node2D
## F11-toggled diagnostic draw (debug_toggle_overlay).
## state name + current nav target + intended stairs.

var _enemy: Enemy


func _ready() -> void:
	_enemy = get_parent()


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	if not _enemy or not _enemy.profile:
		return

	var personality_name: String = PersonalityProfile.Personality.keys()[_enemy.profile.personality]
	var state_name: String = Enemy.State.keys()[_enemy.state]
	var target_pos: Vector2 = _enemy.nav_agent.target_position
	var stairs_name: String = String(_enemy._intended_stairs.name) if _enemy._intended_stairs and is_instance_valid(_enemy._intended_stairs) else "none"

	draw_string(
		ThemeDB.fallback_font, Vector2(-60, -60), "%s | %s" % [personality_name, state_name],
		HORIZONTAL_ALIGNMENT_CENTER, 200, 14, Color.YELLOW
	)
	draw_string(
		ThemeDB.fallback_font, Vector2(-60, -45), "target: (%.0f, %.0f)" % [target_pos.x, target_pos.y],
		HORIZONTAL_ALIGNMENT_CENTER, 200, 14, Color.YELLOW
	)
	draw_string(
		ThemeDB.fallback_font, Vector2(-60, -30), "stairs: %s" % stairs_name,
		HORIZONTAL_ALIGNMENT_CENTER, 200, 14, Color.YELLOW
	)
