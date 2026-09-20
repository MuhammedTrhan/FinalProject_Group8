class_name VisionConeUtils
extends RefCounted
## Shared wall-occlusion helpers for vision/light cones (the enemy's
## Perception cone, its outer follow/decision ring, and the player's UV
## flashlight).


## Raycasts from `node`'s origin to `local_point` (given in `node`'s own local
## space, as _draw() points are) and returns the point clipped to the nearest
## wall hit, or `local_point` unchanged if nothing is in the way.
static func clip_point_to_walls(node: Node2D, local_point: Vector2, mask: int = Layers.WALLS) -> Vector2:
	var global_point := node.to_global(local_point)
	var space_state := node.get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(node.global_position, global_point, mask)
	var result := space_state.intersect_ray(query)
	if result.is_empty():
		return local_point
	return node.to_local(result.position)


## Same raycast as above, but only reports whether `local_point` is reachable
## in a straight line from `node`'s origin without crossing a wall.
static func is_point_visible(node: Node2D, local_point: Vector2, mask: int = Layers.WALLS) -> bool:
	var global_point := node.to_global(local_point)
	var space_state := node.get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(node.global_position, global_point, mask)
	return space_state.intersect_ray(query).is_empty()


## Like is_point_visible(), but for gameplay checks that already have two
## global-space positions on hand (e.g. a personality module's follow-area
## check).
static func has_clear_line_of_sight(from: Node2D, to_global_position: Vector2, mask: int = Layers.WALLS) -> bool:
	var space_state := from.get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(from.global_position, to_global_position, mask)
	return space_state.intersect_ray(query).is_empty()


## Strips consecutive near-duplicate points (within epsilon) from a point
## list about to be handed to draw_colored_polygon().
static func dedupe_consecutive(points: PackedVector2Array, epsilon: float = 0.5, closed: bool = false) -> PackedVector2Array:
	var result := PackedVector2Array()
	for p in points:
		if result.is_empty() or result[result.size() - 1].distance_to(p) > epsilon:
			result.append(p)
	if closed and result.size() > 1 and result[0].distance_to(result[result.size() - 1]) <= epsilon:
		result.remove_at(result.size() - 1)
	return result
