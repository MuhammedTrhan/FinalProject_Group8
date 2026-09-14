class_name ToolUser
extends Node
## Reacts to GameEvents.item_use_requested. Lives as a child of player.tscn
## so it can trigger the player's interaction-lock/animation pipeline and
## read her position. Each item gets its own small handler here, keyed on
## item.id

const CROWBAR_ID := &"crowbar"

# Temporary stand-in for Dev1's Inventory UI, which will eventually emit
# item_use_requested itself when a usable item is clicked. F12, debug builds
# only - see docs/CONTRACT.md's debug key table.
const CROWBAR_ITEM := preload("res://Resources/Items/crowbar.tres")

@onready var player: Player = get_parent()


func _ready() -> void:
	GameEvents.item_use_requested.connect(_on_item_use_requested)


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return

	if event.is_action_pressed("debug_use_crowbar"):
		GameEvents.item_use_requested.emit(CROWBAR_ITEM, false)


func _on_item_use_requested(item: ItemData, _is_active: bool) -> void:
	match item.id:
		CROWBAR_ID:
			_use_crowbar(item)


func _use_crowbar(item: ItemData) -> void:
	if player.is_busy():
		return

	var target: FloorboardPuzzle = _find_nearest_crowbar_target()
	if target != null:
		target.try_pry(item)

	# The swing plays regardless of whether anything was actually pried open -
	# it's feedback that the tool was used, not that it succeeded.
	player.play_tool_animation(Interactions.InteractionType.TOOL_USE)


func _find_nearest_crowbar_target() -> FloorboardPuzzle:
	var nearest: FloorboardPuzzle = null
	var nearest_dist := INF

	for node in get_tree().get_nodes_in_group(&"crowbar_targets"):
		var dist := player.global_position.distance_to(node.global_position)
		if dist <= node.use_radius and dist < nearest_dist:
			nearest = node
			nearest_dist = dist

	return nearest
