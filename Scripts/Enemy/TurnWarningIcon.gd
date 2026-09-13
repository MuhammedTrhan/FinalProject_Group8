class_name TurnWarningIcon
extends Node2D
## Blinking "!" shown above the enemy's head for profile.turn_around_warning_time
## seconds before a turn-around actually happens - Enemy._process_patrol()'s
## own reversal, or a PersonalityModule's own equivalent (ParanoidModule's
## deposit-walk turns). Reads Enemy.is_turn_warning, set generically by
## either path, so this stays personality-agnostic.

const BLINK_COUNT := 3

@export var font_size: int = 28
@export var color: Color = Color(1, 0.9, 0.1, 1.0)
@export var offset := Vector2(0, -60)

var _enemy: Enemy
var _blink_timer: float = 0.0
var _visible_phase := false


func _ready() -> void:
	_enemy = get_parent()


func _process(delta: float) -> void:
	if not _enemy or not _enemy.is_turn_warning:
		_visible_phase = false
		_blink_timer = 0.0
		queue_redraw()
		return

	var warning_time: float = _enemy.profile.turn_around_warning_time if _enemy.profile else 0.6
	var half_period: float = warning_time / float(BLINK_COUNT * 2)
	_blink_timer += delta
	if _blink_timer >= half_period:
		_blink_timer -= half_period
		_visible_phase = not _visible_phase
	queue_redraw()


func _draw() -> void:
	if _visible_phase:
		draw_string(ThemeDB.fallback_font, offset, "!", HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, color)
