class_name RadialBar
extends Control
## A ring that fills clockwise from the top. Drawn rather than textured, so it
## needs no art - swap _draw() for a TextureProgressBar if art shows up later.

@export var thickness: float = 9.0
@export var track_color: Color = Color(0, 0, 0, 0.55)
@export var fill_color: Color = Color(0.83, 0.68, 0.35)

var _value: float = 0.0


## 0.0-1.0.
func set_value(value: float) -> void:
	var clamped := clampf(value, 0.0, 1.0)
	if is_equal_approx(clamped, _value):
		return

	_value = clamped
	queue_redraw()


func _draw() -> void:
	var radius := minf(size.x, size.y) * 0.5 - thickness * 0.5
	if radius <= 0.0:
		return

	var centre := size * 0.5
	draw_arc(centre, radius, 0.0, TAU, 48, track_color, thickness, true)

	if _value <= 0.0:
		return

	# Starts at 12 o'clock rather than 3, which is where a meter reads from.
	var start := -PI * 0.5
	draw_arc(centre, radius, start, start + TAU * _value, 48, fill_color, thickness, true)
