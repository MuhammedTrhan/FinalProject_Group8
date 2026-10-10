extends Node
## Item storage. Dev2/Dev3 call add_item/has_item/remove_item directly
## (see docs/CONTRACT.md); also auto-adds items via GameEvents.item_pickup_requested.

## Fires whenever any slot changes. Local signal, not part of GameEvents -
## the hotbar and the inventory screen listen to this.
signal items_changed

## Fires when the held item changes - either she picked a different hotbar slot,
## or the item in the one she had picked changed. Local signal; the hotbar
## and anything that cares about what she is holding listen to this.
signal selection_changed(index: int, item: ItemData)

## Slot layout: indices 0..HOTBAR_SIZE-1 are the hotbar (directly selectable),
## everything after that is the backpack, shown in the Tab screen as a grid of
## BACKPACK_COLUMNS x BACKPACK_ROWS. Raise the counts when more items turn up.
const HOTBAR_SIZE := 7
const BACKPACK_COLUMNS := 7
const BACKPACK_ROWS := 4
const TOTAL_SLOTS := HOTBAR_SIZE + BACKPACK_COLUMNS * BACKPACK_ROWS

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

# One entry per slot, null where empty. Slots never shift when an item leaves,
# so a gap stays a gap.
var _slots: Array[ItemData] = []

# Which hotbar slot she has picked. Stays put when a slot empties, so using
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


func _init() -> void:
	_slots.resize(TOTAL_SLOTS)


func _ready() -> void:
	GameEvents.item_pickup_requested.connect(add_item)
	# Locked in her room she can't use tools, and a UV cone left burning
	# through the fade would still be lit when the next day opens.
	GameEvents.night_started.connect(func(_day: int) -> void: _set_active_tool(null))


## Puts the item in the first empty slot, hotbar first. Returns false, and
## leaves the item with the caller, if every slot is taken.
func add_item(item: ItemData) -> bool:
	var slot := _slots.find(null)
	if slot == -1:
		return false

	_slots[slot] = item
	_slots_changed()

	# Deferred so the merge lands after whoever added the item has finished: a
	# WorldItem emits its pickup flavour text right after this returns, and that
	# would otherwise overwrite the "pieced back together" message.
	if is_diary_scrap(item):
		try_combine_diary_scraps.call_deferred()
	return true


func has_item(item: ItemData) -> bool:
	return item != null and _slots.has(item)


func has_free_slot() -> bool:
	return _slots.has(null)


# Returns false if the item wasn't in the inventory.
func remove_item(item: ItemData) -> bool:
	var idx := _slots.find(item) if item != null else -1
	if idx == -1:
		return false

	_slots[idx] = null
	_slots_changed()
	return true


## The carried items, in slot order, without the empty slots.
func get_items() -> Array[ItemData]:
	var items: Array[ItemData] = []
	for item in _slots:
		if item != null:
			items.append(item)
	return items


## The item in one slot (hotbar or backpack), or null if it is empty or the
## index is out of range.
func get_slot_item(index: int) -> ItemData:
	if index < 0 or index >= TOTAL_SLOTS:
		return null
	return _slots[index]


## Moves the item in `from` to `to`, swapping if `to` is occupied. Nothing
## happens for a bad index, the same slot twice, or an empty `from`.
func move_slot(from: int, to: int) -> void:
	if from == to or get_slot_item(from) == null or to < 0 or to >= TOTAL_SLOTS:
		return

	var moved := _slots[from]
	_slots[from] = _slots[to]
	_slots[to] = moved
	_slots_changed()


## Takes the item out of a slot and sets it down on the floor next to the
## player, where it can be picked up again. Returns false, and does nothing, if
## the slot is empty or there is no player to drop it beside.
func drop_slot(index: int) -> bool:
	var item := get_slot_item(index)
	var player := get_tree().get_first_node_in_group(&"player")
	if item == null or player == null:
		return false

	_slots[index] = null
	_slots_changed()
	# Loaded at call time and the player left untyped: WorldItem and Player both
	# name this autoload, so naming them back here would make the scripts depend
	# on each other at compile time.
	var world_item: GDScript = load("res://Scripts/Interactables/WorldItem.gd")
	world_item.spawn(item, player.get_parent(), player.get_drop_position())
	return true


# Called by GameManager at the start of a run - items must not carry over.
func clear() -> void:
	_slots.fill(null)
	_selected_index = 0
	_slots_changed()


## The item in the picked hotbar slot, or null if that slot is empty. This is
## what "she is holding the flashlight" means - merely owning it is not enough.
func get_held_item() -> ItemData:
	return get_slot_item(_selected_index)


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


## The player asked to use an item - she pressed E with it in the picked hotbar
## slot. One-shot tools (the crowbar) fire once; toggleable ones
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


func _slots_changed() -> void:
	# A switched-on tool that is no longer carried can't stay on.
	if _active_tool != null and not has_item(_active_tool):
		_set_active_tool(null)

	items_changed.emit()
	_notify_selection()


func _notify_selection() -> void:
	# A toggleable tool never comes on by itself - only use_item() switches it
	# on - but it goes off when she puts it away or loses it. Gated on the held
	# item having actually changed: picking something up off the floor must not
	# flick a light she deliberately switched on.
	var held := get_held_item()
	if held != _last_held:
		_last_held = held
		if _active_tool != held:
			_set_active_tool(null)

	selection_changed.emit(_selected_index, held)


func is_diary_scrap(item: ItemData) -> bool:
	return item in DIARY_SCRAPS


# Combines the 3 diary scraps into DIARY_PAGE if all are present, and reveals
# digit_index 2 of the exit passcode (see docs/CONTRACT.md §3.2). Runs by itself
# whenever a scrap is picked up - see add_item().
func try_combine_diary_scraps() -> bool:
	for scrap in DIARY_SCRAPS:
		if not has_item(scrap):
			return false

	for scrap in DIARY_SCRAPS:
		remove_item(scrap)
	add_item(DIARY_PAGE)

	GameEvents.clue_revealed.emit(2, ProceduralGenerator.get_digit(2), "You put the diary back together.")
	return true
