class_name PhysicsQueryUtils
extends RefCounted
## Shared spatial "is this point free of walls/furniture" check, for
## furniture whose single authored spawn/exit point (e.g. Sitable's
## stand_up_point) might end up overlapping a wall or another piece of
## furniture placed too close to it - a level-layout issue, not a dynamic
## occupant one. Doors dodge this by having two hand-placed exit markers to
## choose from (Door.gd's _evacuate_hitbox()); a single marker has no second
## point to fall back to, so find_clear_point() searches nearby instead.


## True if no body on `mask` overlaps a small circle at `point` (world space).
static func is_point_clear(node: Node2D, point: Vector2, mask: int = Layers.WALLS, radius: float = 6.0) -> bool:
	var shape := CircleShape2D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, point)
	query.collision_mask = mask
	return node.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


## Returns `point` itself if clear, otherwise the nearest clear spot found by
## sampling rings of 8 candidates around it at increasing radius, up to
## `max_search_radius`. Falls back to `point` unchanged if nothing clear was
## found in range (better to place the actor exactly where authored than
## somewhere arbitrarily far off).
static func find_clear_point(node: Node2D, point: Vector2, mask: int = Layers.WALLS, radius: float = 6.0, step: float = 6.0, max_search_radius: float = 64.0) -> Vector2:
	if is_point_clear(node, point, mask, radius):
		return point

	var search_radius := step
	while search_radius <= max_search_radius:
		for i in 8:
			var candidate := point + Vector2.RIGHT.rotated(TAU * float(i) / 8.0) * search_radius
			if is_point_clear(node, candidate, mask, radius):
				return candidate
		search_radius += step

	return point
