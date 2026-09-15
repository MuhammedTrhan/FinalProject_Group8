extends CanvasLayer
## In-run readouts fed by Dev2's enemy (see docs/CONTRACT.md):
##   - chase bar: how close she is to being chased right now. Every day has
##     one, though each personality measures it differently.
##   - trust ring: Forgetful's own "stay close and he warms up to you" meter.
##   - noise counter: how many of Overwhelmed's noise sources are still on.
##
## Only shown during the day - night is when day mechanics stop being
## evaluated, so none of these mean anything then.

## Stands in for a digit she hasn't found yet, so the readout also tells her
## how many are left and which slot each belongs to.
const UNKNOWN_DIGIT := "*"
const FOUND_COLOUR := Color(0.98, 0.86, 0.5)
const UNKNOWN_COLOUR := Color(0.45, 0.41, 0.34)

## The personalities that have a follow meter, and what the ring is called for
## each. Doubles as the "does this personality show the ring at all" test, so
## there is one list to change when a fourth personality turns up.
const FOLLOW_BAR_CAPTIONS := {
	PersonalityProfile.Personality.FORGETFUL: "Trust",
	PersonalityProfile.Personality.PARANOID: "Gift",
}

@onready var chase_bar: ProgressBar = $Root/ChaseBar
@onready var follow_bar: RadialBar = $Root/FollowBar
@onready var follow_label: Label = $Root/FollowBar/FollowLabel
@onready var noise_counter: Label = $Root/NoiseCounter
@onready var digits_row: HBoxContainer = $Root/PasscodeReadout/Margin/VBox/Digits

# One Label per passcode slot, built to match however many digits there are.
var _digit_slots: Array[Label] = []

# Which readouts today's personality actually has. The noise furniture never
# switches itself back off, so "are any still on" can't stand in for this.
var _shows_follow := false
var _shows_noise := false


func _ready() -> void:
	visible = false

	GameEvents.day_started.connect(_on_day_started)
	GameEvents.night_started.connect(_on_night_started)
	GameEvents.day_ended.connect(_on_day_ended)
	GameEvents.chase_progress_changed.connect(_on_chase_progress_changed)
	GameEvents.follow_progress_changed.connect(_on_follow_progress_changed)
	GameEvents.noise_source_silenced.connect(_on_noise_source_silenced)
	GameEvents.enemy_dropped_item.connect(_on_enemy_dropped_item)
	GameEvents.clue_revealed.connect(_on_clue_revealed)
	GameEvents.run_started.connect(_on_run_started)
	# The run is over on a final catch - the game-over screen owns the screen
	# from here, and this draws above it.
	GameEvents.player_caught.connect(func(_reason: StringName) -> void: visible = false)

	_refresh_passcode_readout()


func _on_day_started(_day: int, personality: int) -> void:
	# Both of these personalities run a "stay in his area and he gives you
	# something" meter on the same get_follow_progress() hook, so they share
	# the ring - Paranoid's version is otherwise only drawn as a circle on the
	# floor, which is hard to read while she is moving.
	_shows_follow = personality in FOLLOW_BAR_CAPTIONS
	_shows_noise = personality == PersonalityProfile.Personality.OVERWHELMED

	# Cleared right away so yesterday's readings can't show for the frame
	# before the deferred poll below lands.
	chase_bar.value = 0.0
	follow_bar.set_value(0.0)
	follow_bar.visible = _shows_follow
	if _shows_follow:
		follow_label.text = FOLLOW_BAR_CAPTIONS[personality]
	noise_counter.visible = _shows_noise
	visible = true

	# Both deferred because this HUD is an autoload: it connected to
	# day_started before the level existed, so its handler runs before the
	# enemy's and the noise furniture's. Reading either right now would see
	# yesterday's personality module and furniture that hasn't switched on yet.
	_poll_enemy.call_deferred()
	_refresh_noise_counter.call_deferred()


func _on_night_started(_day: int) -> void:
	visible = false


func _on_day_ended(_day: int) -> void:
	visible = false # she can't act during the escort either


# Dev2 emits these only on change, so a HUD that appears mid-run has to ask
# for the current values once - see docs/CONTRACT.md on chase_progress_changed.
func _poll_enemy() -> void:
	var enemy := get_tree().get_first_node_in_group(&"enemy")
	if enemy == null:
		return

	if enemy.has_method("get_chase_progress"):
		_on_chase_progress_changed(enemy.get_chase_progress())
	if enemy.has_method("get_follow_progress"):
		_on_follow_progress_changed(enemy.get_follow_progress())


func _on_chase_progress_changed(progress: float) -> void:
	chase_bar.value = clampf(progress, 0.0, 1.0)


func _on_follow_progress_changed(progress: float) -> void:
	if _shows_follow:
		follow_bar.set_value(progress)


func _on_noise_source_silenced(_source: Node, remaining: int) -> void:
	_set_noise_count(remaining)


func _on_clue_revealed(digit_index: int, _digit_value: int, _flavour: String) -> void:
	# Deferred so GameManager - which connected first - has already written the
	# digit into passcode_digits by the time this reads it.
	_reveal_digit.call_deferred(digit_index)


func _on_run_started(_run_seed: int) -> void:
	_refresh_passcode_readout()


func _reveal_digit(digit_index: int) -> void:
	_refresh_passcode_readout()

	if digit_index < 0 or digit_index >= _digit_slots.size():
		return

	# A brief flare on the slot that just filled, so a digit found across the
	# house still reads as "that one, right there".
	var slot := _digit_slots[digit_index]
	slot.modulate = Color(2.2, 2.0, 1.6)
	create_tween().tween_property(slot, "modulate", Color.WHITE, 0.6)


## Mirrors GameManager.passcode_digits rather than keeping a second copy; that
## array is the one the exit keypad is actually checked against.
func _refresh_passcode_readout() -> void:
	var digits: Array[int] = GameManager.passcode_digits
	if _digit_slots.size() != digits.size():
		_build_digit_slots(digits.size())

	for i in digits.size():
		var found := digits[i] >= 0
		_digit_slots[i].text = str(digits[i]) if found else UNKNOWN_DIGIT
		_digit_slots[i].add_theme_color_override(
			"font_color", FOUND_COLOUR if found else UNKNOWN_COLOUR)


func _build_digit_slots(count: int) -> void:
	for child in digits_row.get_children():
		child.queue_free()
	_digit_slots.clear()

	var slot_style := StyleBoxFlat.new()
	slot_style.bg_color = Color(0.04, 0.035, 0.03, 0.9)
	slot_style.border_color = Color(0.45, 0.37, 0.22)
	slot_style.set_border_width_all(2)
	slot_style.set_corner_radius_all(4)

	for i in count:
		var slot := Label.new()
		slot.custom_minimum_size = Vector2(28, 34)
		slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot.add_theme_font_size_override("font_size", 22)
		slot.add_theme_stylebox_override("normal", slot_style)
		digits_row.add_child(slot)
		_digit_slots.append(slot)


## Forgetful's meter empties itself and then stops accumulating for the rest of
## the day, so leaving the ring up would read as a stuck bar. Paranoid's is not
## this signal's doing - he deposits into a bin and his meter refills for the
## next reward item - so the ring is only taken down when the day's personality
## is one that is actually finished with it.
func _on_enemy_dropped_item(item: ItemData, _world_position: Vector2) -> void:
	if GameManager.current_personality == PersonalityProfile.Personality.FORGETFUL:
		follow_bar.visible = false

	if item:
		GameEvents.message_requested.emit("%s dropped nearby." % item.display_name)


# No signal carries the day's starting count, so it's read straight off the
# group the noise furniture puts itself in.
func _refresh_noise_counter() -> void:
	if not _shows_noise:
		return

	var remaining := 0
	for source in get_tree().get_nodes_in_group(&"noise_source"):
		if source.get("is_active"):
			remaining += 1

	_set_noise_count(remaining)


func _set_noise_count(remaining: int) -> void:
	if not _shows_noise:
		return

	noise_counter.text = "Noise: %d" % remaining
