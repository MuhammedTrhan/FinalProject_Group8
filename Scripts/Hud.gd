extends CanvasLayer
## In-run readouts fed by Dev2's enemy (see docs/CONTRACT.md):
##   - chase bar: how close she is to being chased right now. Every day has
##     one, though each personality measures it differently.
##   - trust ring: Forgetful's own "stay close and he warms up to you" meter.
##   - noise counter: how many of Overwhelmed's noise sources are still on.
##
## Only shown during the day - night is when day mechanics stop being
## evaluated, so none of these mean anything then.

@onready var chase_bar: ProgressBar = $Root/ChaseBar
@onready var follow_bar: RadialBar = $Root/FollowBar
@onready var noise_counter: Label = $Root/NoiseCounter

# Which readouts today's personality actually has. The noise furniture never
# switches itself back off, so "are any still on" can't stand in for this.
var _shows_trust := false
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


func _on_day_started(_day: int, personality: int) -> void:
	_shows_trust = personality == PersonalityProfile.Personality.FORGETFUL
	_shows_noise = personality == PersonalityProfile.Personality.OVERWHELMED

	# Cleared right away so yesterday's readings can't show for the frame
	# before the deferred poll below lands.
	chase_bar.value = 0.0
	follow_bar.set_value(0.0)
	follow_bar.visible = _shows_trust
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
	if _shows_trust:
		follow_bar.set_value(progress)


func _on_noise_source_silenced(_source: Node, remaining: int) -> void:
	_set_noise_count(remaining)


## The meter that earned this empties itself and then stops accumulating for
## the rest of the day, so leaving the ring up would read as a stuck bar.
func _on_enemy_dropped_item(item: ItemData, _world_position: Vector2) -> void:
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
