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
	if event.is_action_pressed("toggle_inventory"):
		visible = not visible


func _refresh() -> void:
	for child in item_list.get_children():
		child.queue_free()

	for item in Inventory.get_items():
		var slot: PanelContainer = INVENTORY_SLOT_SCENE.instantiate()
		item_list.add_child(slot)
		slot.item = item
