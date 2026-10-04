@tool
extends Node2D

@export var disable_in_editor: bool = true

func _ready() -> void:
	if Engine.is_editor_hint():
		visible = not disable_in_editor
	else:
		visible = true
