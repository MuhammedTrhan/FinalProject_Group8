extends StaticBody2D

@export var destination_stairs: StaticBody2D
@export var leads_upstairs: bool = true

@onready var climbing_spawn = $ClimbingSpawnP
@onready var descending_spawn = $DescendingSpawnP
@onready var climb_trigger = $ClimbTriggerArea
@onready var descend_trigger = $DescendTriggerArea

@onready var upper_end = $UpperEnd
@onready var lower_end = $LowerEnd


var tween_start_pos: Vector2
var tween_target_pos: Vector2

func _ready() -> void:
	if not destination_stairs:
		print("Destination stairs not set for %s" % self.name)

	if leads_upstairs:
		# Set the climb trigger to monitor and the descend trigger to not monitor
		climb_trigger.monitoring = true
		descend_trigger.monitoring = false

		# Connect the body_entered signal of the climb trigger to the on_teleport_trigger function
		climb_trigger.body_entered.connect(on_teleport_trigger)

		# Set the tween start and target positions based on the upper and lower ends of the stairs
		tween_start_pos = lower_end.global_position
		tween_target_pos = upper_end.global_position

	else:
		climb_trigger.monitoring = false
		descend_trigger.monitoring = true

		descend_trigger.body_entered.connect(on_teleport_trigger)

		tween_start_pos = upper_end.global_position
		tween_target_pos = lower_end.global_position


func on_teleport_trigger(body: Node) -> void:
	if destination_stairs and (body.is_in_group("player") or body.is_in_group("enemy")):
		var dest_stair_start_point: Vector2
		var target_spawn_pos: Vector2

		if leads_upstairs:
			# If the player is climbing upstairs, set the target spawn position to the climbing spawn point of the destination stairs
			target_spawn_pos = destination_stairs.climbing_spawn.global_position
			# Set the destination stair start point to the upper end of the destination stairs
			dest_stair_start_point = destination_stairs.upper_end.global_position
		else:
			target_spawn_pos = destination_stairs.descending_spawn.global_position
			dest_stair_start_point = destination_stairs.lower_end.global_position

		teleport(body, target_spawn_pos, dest_stair_start_point)


func teleport(body: Node2D, spawn_position: Vector2, stairs_end: Vector2) -> void:
	if not body.is_in_group("player") and not body.is_in_group("enemy"):
		return

	# Snap the body to the tween start position before starting the teleportation
	body.global_position = tween_start_pos

	if body.has_method("start_teleport"):
		body.start_teleport(spawn_position, tween_target_pos, stairs_end)
	else:
		body.global_position = spawn_position
