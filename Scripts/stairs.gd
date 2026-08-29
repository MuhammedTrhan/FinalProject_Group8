extends StaticBody2D

@export var destination_stairs: StaticBody2D
@export var leads_upstairs: bool = true

@onready var climbing_spawn = $ClimbingSpawnP
@onready var descending_spawn = $DescendingSpawnP
@onready var climb_trigger = $ClimbTriggerArea
@onready var descend_trigger = $DescendTriggerArea

@onready var upper_end = $UpperEnd
@onready var lower_end = $LowerEnd

var tween_start_position: Vector2
var tween_target_position: Vector2

func _ready() -> void:
	if not destination_stairs:
		print("Destination stairs not set for %s" % self.name)

	if leads_upstairs:
		climb_trigger.monitoring = true
		descend_trigger.monitoring = false

		tween_start_position = lower_end.global_position
		tween_target_position = upper_end.global_position
	else:
		climb_trigger.monitoring = false
		descend_trigger.monitoring = true

		tween_start_position = upper_end.global_position
		tween_target_position = lower_end.global_position

func _on_climb_trigger_area_body_entered(body: Node2D) -> void:
	if destination_stairs and (body.is_in_group("player") or body.is_in_group("enemy")):
		teleport(body, destination_stairs.climbing_spawn)

func _on_descend_trigger_area_body_entered(body: Node2D) -> void:
	if destination_stairs and (body.is_in_group("player") or body.is_in_group("enemy")):
		teleport(body, destination_stairs.descending_spawn)

func teleport(body: Node2D, target_spawn: Marker2D) -> void:
	if not body.is_in_group("player") and not body.is_in_group("enemy"):
		return

	var spawn_position = target_spawn.global_position

	# Snap the body to the tween start position before starting the teleportation
	body.global_position = tween_start_position

	if body.has_method("start_teleport"):
		body.start_teleport(spawn_position, tween_target_position)
	else:
		body.global_position = spawn_position
