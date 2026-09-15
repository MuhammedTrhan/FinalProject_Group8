extends Node
## Item storage. Dev2/Dev3 call add_item/has_item/remove_item directly
## (see docs/CONTRACT.md); also auto-adds items via GameEvents.item_pickup_requested.

## Fires whenever the item list changes. Local signal, not part of GameEvents -
## the future Inventory UI screen listens to this.
signal items_changed

## Fires when the held item changes - either she picked a different hotbar slot,
## or the list shifted under the one she had picked. Local signal; the hotbar
## and anything that cares about what she is holding listen to this.
signal selection_changed(index: int, item: ItemData)

## How many slots the hotbar shows. Items past this are still carried, just not
## directly selectable - nothing in the design needs more than 8.
const HOTBAR_SIZE := 8

## Usable items that switch on and off rather than firing once, so their
## item_use_requested carries a meaningful is_active. Everything else is a
## one-shot tool (the crowbar) and always reports false, per Dev3's request.
##
## This really belongs on ItemData as an `is_toggleable` flag next to
## `is_usable`, but that resource is shared with Dev2/Dev3 - until they agree
## to the field, the one item it applies to is listed here.
const TOGGLEABLE_ITEM_IDS: Array[StringName] = [&"uv_flashlight"]

# Placeholder ItemData until Dev3 authors the real ones at the same paths
# (see docs/CONTRACT.md §3.2) - combining logic doesn't change either way.
const SCRAP_A := preload("res://Resources/Items/scrap_a.tres")
const SCRAP_B := preload("res://Resources/Items/scrap_b.tres")
const SCRAP_C := preload("res://Resources/Items/scrap_c.tres")
const DIARY_PAGE := preload("res://Resources/Items/diary_page.tres")
const DIARY_SCRAPS := [SCRAP_A, SCRAP_B, SCRAP_C]

var _items: Array[ItemData] = []

# Which hotbar slot she has picked. Stays put when the list changes, so using
# up a slot's item leaves her holding nothing rather than silently sliding the
# next item into her hand.
var _selected_index := 0

# The toggleable tool that is currently switched on, or null. Kept here rather
# than in the UI so there is exactly one answer to "is the UV light on", no
# matter which screen was used to switch it.
var _active_tool: ItemData = null

# What she was holding last time the selection was recomputed, so picking up
# an unrelated item can be told apart from actually changing hands.
var _last_held: ItemData = null


func _ready() -> void:
	GameEvents.item_pickup_requested.connect(add_item)
	# Locked in her room she can't use tools, and a UV cone left burning
	# through the fade would still be lit when the next day opens.
	GameEvents.night_started.connect(func(_day: int) -> void: _set_active_tool(null))


func add_item(item: ItemData) -> void:
	_items.append(item)
	items_changed.emit()
	_notify_selection()


func has_item(item: ItemData) -> bool:
	return _items.has(item)


# Returns false if the item wasn't in the inventory.
func remove_item(item: ItemData) -> bool:
	var idx := _items.find(item)
	if idx == -1:
		return false

	_items.remove_at(idx)
	items_changed.emit()
	_notify_selection()
	return true


func get_items() -> Array[ItemData]:
	return _items.duplicate()


# Called by GameManager at the start of a run - items must not carry over.
func clear() -> void:
	_items.clear()
	_selected_index = 0
	items_changed.emit()
	_notify_selection()


## The item in the picked hotbar slot, or null if that slot is empty. This is
## what "she is holding the flashlight" means - merely owning it is not enough.
func get_held_item() -> ItemData:
	if _selected_index < 0 or _selected_index >= _items.size():
		return null
	return _items[_selected_index]


func get_selected_index() -> int:
	return _selected_index


func select_slot(index: int) -> void:
	if index < 0 or index >= HOTBAR_SIZE or index == _selected_index:
		return

	_selected_index = index
	_notify_selection()


## Mouse-wheel stepping. Wraps around the whole hotbar rather than stopping at
## the last carried item, so the wheel always moves.
func cycle_selection(step: int) -> void:
	select_slot(wrapi(_selected_index + step, 0, HOTBAR_SIZE))


## The player asked to use an item - she clicked it in the inventory panel or
## on its hotbar slot. One-shot tools (the crowbar) fire once; toggleable ones
## (the UV flashlight) flip on and off. Anything not marked is_usable is inert.
##
## This is the only place item_use_requested originates. Dev3's ToolUser and
## UVFlashlight both listen to it (see GameEvents.gd's Inventory section).
func use_item(item: ItemData) -> void:
	if item == null or not item.is_usable:
		return

	if not is_toggleable(item):
		GameEvents.item_use_requested.emit(item, false)
		return

	_set_active_tool(null if _active_tool == item else item)


func is_toggleable(item: ItemData) -> bool:
	return item != null and item.id in TOGGLEABLE_ITEM_IDS


func get_active_tool() -> ItemData:
	return _active_tool


## Emits both halves of the switch, so a listener never has to infer that the
## old tool went off because a new one came on.
func _set_active_tool(tool: ItemData) -> void:
	if tool == _active_tool:
		return

	if _active_tool != null:
		GameEvents.item_use_requested.emit(_active_tool, false)

	_active_tool = tool

	if _active_tool != null:
		GameEvents.item_use_requested.emit(_active_tool, true)


func _notify_selection() -> void:
	# A toggleable tool comes on when she takes it in hand and goes off when
	# she puts it away or loses it. Gated on the held item having actually
	# changed: picking something up off the floor must not flick a light she
	# deliberately clicked off back on.
	var held := get_held_item()
	if held != _last_held:
		_last_held = held
		if is_toggleable(held) and held.is_usable:
			_set_active_tool(held)
		elif _active_tool != held:
			_set_active_tool(null)

	selection_changed.emit(_selected_index, held)


func is_diary_scrap(item: ItemData) -> bool:
	return item in DIARY_SCRAPS


# Combines the 3 diary scraps into DIARY_PAGE if all are present, and reveals
# digit_index 2 of the exit passcode (see docs/CONTRACT.md §3.2).
func try_combine_diary_scraps() -> bool:
	for scrap in DIARY_SCRAPS:
		if not has_item(scrap):
			return false

	for scrap in DIARY_SCRAPS:
		remove_item(scrap)
	add_item(DIARY_PAGE)

	GameEvents.clue_revealed.emit(2, ProceduralGenerator.get_digit(2), "You piece the diary pages together.")
	return true
