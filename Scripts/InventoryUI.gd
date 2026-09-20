extends CanvasLayer
## Toggle-able inventory panel (Tab). Reads Inventory directly - see docs/CONTRACT.md.
## Drag one diary scrap onto another to combine them (see InventorySlot.gd).

const INVENTORY_SLOT_SCENE := preload("res://Scenes/UI/inventory_slot.tscn")

@onready var item_list: VBoxContainer = $Root/CenterContainer/PanelContainer/MarginContainer/VBox/ItemList


func _ready() -> void:
	visible = false
	Inventory.items_changed.connect(_refresh)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("toggle_inventory"):
		return

	if visible:
		_close()
	elif GameManager.is_run_interactive():
		# Refused while anything else owns the pause - the dossier, the keypad,
		# the pause menu, the game-over screen - so this can't unpause theirs.
		_open()


## Freezes the house while she is in her bag. Combining the diary pieces is a
## drag-and-drop that takes both hands, and with the captor still walking she
## could be caught by a menu.
func _open() -> void:
	visible = true
	get_tree().paused = true


func _close() -> void:
	visible = false
	get_tree().paused = false


func _refresh() -> void:
	for child in item_list.get_children():
		child.queue_free()

	for item in Inventory.get_items():
		var slot: PanelContainer = INVENTORY_SLOT_SCENE.instantiate()
		item_list.add_child(slot)
		slot.item = item
