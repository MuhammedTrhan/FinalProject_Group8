class_name EnemyDebugOverlay
extends Node2D
## F11-toggled diagnostic draw (debug_toggle_overlay).
## state name + view-distance ring.

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
	draw_string(
		ThemeDB.fallback_font, Vector2(-60, -60), "%s | %s" % [personality_name, state_name],
		HORIZONTAL_ALIGNMENT_CENTER, 200, 14, Color.YELLOW
	)
	draw_arc(Vector2.ZERO, _enemy.profile.view_distance, 0, TAU, 48, Color(1, 1, 0, 0.4), 1.0)
