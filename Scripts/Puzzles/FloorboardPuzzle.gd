class_name FloorboardPuzzle
extends Node2D
## The loose floorboard - pry it up with the crowbar (used from the Inventory)
## to reveal digit_index 1 of the exit passcode.

const DIGIT_INDEX := 1
const DIRT_SOURCE_ID := 5 # Balcony garden.png (TileSet_5erdv sources/5)

@export var required_item: ItemData
@export var use_radius: float = 32.0
@export var dirt_atlas_coords: Vector2i = Vector2i(4, 2)
@export_multiline var flavour_text: String = ""
## This floor's NavigationRegion2D/Ground TileMapLayer - the tile this node
## sits on gets swapped from wood to dirt on reveal.
@export var ground_layer_path: NodePath

@onready var scribble: Sprite2D = $ClueScribble
@onready var tile_shade: Polygon2D = $TileShade

var _revealed := false


func _ready() -> void:
	add_to_group(&"crowbar_targets")
	scribble.visible = false
	tile_shade.visible = false


## Called by ToolUser when the crowbar is used within use_radius of this node.
func try_pry(item: ItemData) -> void:
	if _revealed or item != required_item:
		return

	_revealed = true
	_swap_tile_to_dirt()
	scribble.visible = true
	tile_shade.visible = true
	GameEvents.clue_revealed.emit(DIGIT_INDEX, ProceduralGenerator.get_digit(DIGIT_INDEX), flavour_text)


func _swap_tile_to_dirt() -> void:
	var ground := get_node(ground_layer_path) as TileMapLayer
	var cell := ground.local_to_map(ground.to_local(global_position))
	ground.set_cell(cell, DIRT_SOURCE_ID, dirt_atlas_coords)
	# Snap to the tile's actual center rather than trusting this node's exact
	# placement, so the darkened patch always lines up with the grid cell.
	tile_shade.global_position = ground.to_global(ground.map_to_local(cell))
