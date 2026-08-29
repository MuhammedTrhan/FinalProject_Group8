extends Area2D

@export var destination_stairs: Area2D
# Check this to 'true' in the Inspector if these stairs lead to a higher floor
@export var leads_upstairs: bool = true

@onready var climbing_spawn = $ClimbingSpawnP
@onready var descending_spawn = $DescendingSpawnP

func _ready() -> void:
    body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
    if body.is_in_group("player") or body.is_in_group("enemy"):
        if destination_stairs:
            if leads_upstairs:
                # If the character walks upstairs, they spawn at the destination's top point
                body.global_position = destination_stairs.climbing_spawn.global_position
            else:
                # If the character walks downstairs, they spawn at the destination's bottom point
                body.global_position = destination_stairs.descending_spawn.global_position