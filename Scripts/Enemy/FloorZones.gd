class_name FloorZones
extends RefCounted
## Maps a world position to a floor index (0/1/2). Used by Enemy to decide
## whether a target is on its own floor or requires a stairs crossing.

## Hand-defined rather than derived from the NavigationRegion2D's outlines.
const FLOOR_RECTS: Array[Rect2] = [
	Rect2(-1750, -50, 800, 1100),   # 0: left wing (around Stairs4)
	Rect2(-100, -150, 1025, 1550),   # 1: middle/ground floor (hub - Stairs & Stairs2)
	Rect2(1600, -200, 1000, 1475),    # 2: right wing (around Stairs3)
]


static func get_floor(world_pos: Vector2) -> int:
	for i in FLOOR_RECTS.size():
		if FLOOR_RECTS[i].has_point(world_pos):
			return i
	return 1  # fall back to the hub if not found - never return -1
