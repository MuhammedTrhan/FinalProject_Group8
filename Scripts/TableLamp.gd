class_name TableLamp
extends Furniture

@onready var light_node: PointLight2D = $PointLight2D

func activate() -> void:
	light_node.enabled = true
	super()

func deactivate() -> void:
	light_node.enabled = false
	super()
