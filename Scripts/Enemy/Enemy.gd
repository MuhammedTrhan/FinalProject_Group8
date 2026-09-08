class_name Enemy
extends CharacterBody2D
## The antagonist. The state machine below is SHARED across all three
## personalities; only the numbers (from PersonalityProfile) and the active
## PersonalityModule's hooks differ.
##
## Floor-crossing: Chase/Investigate resolve their nav target
## through _resolve_nav_target(), which substitutes a same-floor stairs
## approach point whenever the real target is on a different floor.

enum State { IDLE, PATROL, INVESTIGATE, CHASE, STUNNED, SPECIAL }

const PERSONALITY_PROFILES: Dictionary = {
	PersonalityProfile.Personality.FORGETFUL: preload("res://Resources/Personalities/forgetful.tres"),
	PersonalityProfile.Personality.PARANOID: preload("res://Resources/Personalities/paranoid.tres"),
	PersonalityProfile.Personality.OVERWHELMED: preload("res://Resources/Personalities/overwhelmed.tres"),
}

const PERSONALITY_MODULES: Dictionary = {
	PersonalityProfile.Personality.FORGETFUL: preload("res://Scripts/Enemy/PersonalityModules/ForgetfulModule.gd"),
	PersonalityProfile.Personality.PARANOID: preload("res://Scripts/Enemy/PersonalityModules/ParanoidModule.gd"),
	PersonalityProfile.Personality.OVERWHELMED: preload("res://Scripts/Enemy/PersonalityModules/OverwhelmedModule.gd"),
}

## Early-capture distance while there's already a clear line of sight, so
## catching the player doesn't depend on pixel-perfect TouchArea overlap.
const TOO_CLOSE_DISTANCE := 12.0
## How long Chase tolerates a lost line of sight before dropping to Investigate.
const LOST_TOLERANCE := 2.0
## Matches PlayerMovement.gd's start_teleport() default duration exactly -
const STAIR_TWEEN_DURATION := 0.5

@onready var anim_handler: EnemyAnimationHandler = $EnemyAnimationHandler
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var perception: Perception = $Perception
@onready var touch_area: Area2D = $TouchArea
@onready var debug_overlay: EnemyDebugOverlay = $EnemyDebugOverlay

var profile: PersonalityProfile
var active_module: PersonalityModule

var state: State = State.IDLE
## Real-world target Investigate is walking toward (a last-known-position or
## a noise source's world_position) - see _resolve_nav_target().
var investigate_target: Vector2
## How long Investigate looks around before giving up. Set by the active
## PersonalityModule's on_lost_target() (Forgetful shortens it, Paranoid
## lengthens it).
var investigate_look_around_time: float = 2.0

var is_teleporting: bool = false
var teleport_tween: Tween

var _pause_timer: float = 0.0
var _look_around_timer: float = 0.0
var _lost_timer: float = 0.0

var _ai_frozen: bool = false
var _debug_player_hidden: bool = false

## {[floor_a, floor_b]: Stairs} - built once in _index_stairs(). Bidirectional
## per pair, so a 3-floor / 2-pair level holds at most 4 entries.
var _stairs_by_floor_pair: Dictionary = {}
var _patrol_points: Array[Node2D] = []
var _patrol_index: int = 0


func _ready() -> void:
	touch_area.body_entered.connect(_on_touch_area_body_entered)
	anim_handler.animation_finished.connect(anim_handler._on_animation_finished)
	GameEvents.day_started.connect(_on_day_started)

	_index_stairs()
	_collect_patrol_points()

	debug_overlay.visible = false

	# Covers scenes where this Enemy already exists when the day starts (or
	# F1 was pressed before it existed) - apply whatever is already active.
	_apply_personality(GameManager.current_personality)


func _physics_process(delta: float) -> void:
	if is_teleporting:
		return

	if _ai_frozen:
		anim_handler.update_animations(Vector2.ZERO)
		return

	perception.facing_dir = anim_handler.get_facing_vector()
	var dwelled := perception.update(delta)

	match state:
		State.IDLE:
			_process_idle(delta)
		State.PATROL:
			_process_patrol(delta)
		State.INVESTIGATE:
			_process_investigate(delta)
		State.CHASE:
			_process_chase(delta)
		State.STUNNED:
			_process_stunned(delta)
		State.SPECIAL:
			velocity = Vector2.ZERO
			if active_module:
				active_module.process_special(delta)

	if state != State.SPECIAL:
		_check_perception_transitions(dwelled)
		move_and_slide()

	anim_handler.update_animations(velocity)
	GameEvents.enemy_state_changed.emit(StringName(State.keys()[state]))


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return

	if event.is_action_pressed("debug_toggle_ai"):
		_ai_frozen = not _ai_frozen
	elif event.is_action_pressed("debug_warp_enemy"):
		var p := get_tree().get_first_node_in_group(&"player")
		if p:
			global_position = p.global_position
	elif event.is_action_pressed("debug_force_succeed"):
		drop_reward()
	elif event.is_action_pressed("debug_force_fail"):
		GameEvents.player_caught.emit(&"timeout")
	elif event.is_action_pressed("debug_toggle_hidden"):
		_debug_player_hidden = not _debug_player_hidden
		GameEvents.player_hidden_changed.emit(_debug_player_hidden)
	elif event.is_action_pressed("debug_toggle_overlay"):
		debug_overlay.visible = not debug_overlay.visible


# --- Day cycle ---------------------------------------------------------------

func _on_day_started(_day: int, personality: int) -> void:
	_apply_personality(personality)


func _apply_personality(personality: int) -> void:
	profile = PERSONALITY_PROFILES.get(personality)
	if profile == null:
		push_error("Enemy: no PersonalityProfile.tres registered for personality %d" % personality)
		return

	anim_handler.apply_personality(profile)
	perception.view_distance = profile.view_distance
	perception.fov_degrees = profile.fov_degrees
	perception.detect_dwell = profile.detect_dwell

	if active_module:
		active_module.queue_free()
	var module_script: Script = PERSONALITY_MODULES.get(personality)
	active_module = module_script.new() if module_script else null
	if active_module:
		active_module.enemy = self
		add_child(active_module)

	if profile.starts_in_special:
		_enter_special()
	else:
		_enter_state(State.PATROL)


# --- State transitions --------------------------------------------------------

func _enter_state(new_state: State) -> void:
	state = new_state
	_pause_timer = 0.0
	_look_around_timer = 0.0
	_lost_timer = 0.0

	if new_state == State.PATROL:
		_go_to_next_patrol_point()


func _enter_special() -> void:
	state = State.SPECIAL
	velocity = Vector2.ZERO
	if active_module:
		active_module.on_enter_special()


func _check_perception_transitions(dwelled: bool) -> void:
	if not dwelled:
		return
	if state == State.CHASE or state == State.INVESTIGATE:
		return

	if profile.can_chase:
		investigate_target = perception.last_known_position
		_enter_state(State.CHASE)
	else:
		# A personality that never chases ends the run the instant it sees
		# you. can_chase is true for all three personalities, so this
		# path is effectively unused today - it keeps &"seen"'s place in the
		# signal contract ready for a future personality that needs it.
		GameEvents.player_caught.emit(&"seen")


# --- State bodies --------------------------------------------------------------

func _process_idle(delta: float) -> void:
	_pause_timer += delta
	if _pause_timer >= profile.pause_duration_range.x:
		_enter_state(State.PATROL)


func _process_patrol(_delta: float) -> void:
	_move_toward(nav_agent.get_next_path_position(), profile.move_speed)

	if nav_agent.is_navigation_finished():
		if randf() < profile.pause_chance:
			_enter_state(State.IDLE)
		else:
			if randf() < profile.turn_around_chance and not _patrol_points.is_empty():
				_patrol_index = (_patrol_index + _patrol_points.size() - 1) % _patrol_points.size()
			_go_to_next_patrol_point()


func _process_investigate(delta: float) -> void:
	nav_agent.target_position = _resolve_nav_target(investigate_target)
	_move_toward(nav_agent.get_next_path_position(), profile.move_speed)

	if nav_agent.is_navigation_finished():
		_look_around_timer += delta
		if _look_around_timer >= investigate_look_around_time:
			_enter_state(State.PATROL)


func _process_chase(delta: float) -> void:
	var player := perception.get_player()
	if player == null or not is_instance_valid(player):
		_enter_state(State.PATROL)
		return

	if perception.is_player_visible():
		_lost_timer = 0.0
		investigate_target = player.global_position
	else:
		_lost_timer += delta
		if _lost_timer >= LOST_TOLERANCE:
			investigate_target = perception.last_known_position
			if active_module:
				active_module.on_lost_target()
			_enter_state(State.INVESTIGATE)
			return

	nav_agent.target_position = _resolve_nav_target(player.global_position)
	_move_toward(nav_agent.get_next_path_position(), profile.chase_speed)

	if perception.is_player_visible() and global_position.distance_to(player.global_position) <= TOO_CLOSE_DISTANCE:
		GameEvents.player_caught.emit(&"too_close")


func _process_stunned(delta: float) -> void:
	# Planned for the optional Neat Freak personality - this is a
	_pause_timer += delta
	if _pause_timer >= 1.5:
		_enter_state(State.PATROL)


# --- Movement helpers ----------------------------------------------------------

func _move_toward(target: Vector2, speed: float) -> void:
	if global_position.distance_to(target) < 2.0:
		velocity = velocity.move_toward(Vector2.ZERO, speed)
		return
	velocity = (target - global_position).normalized() * speed


func _go_to_next_patrol_point() -> void:
	if _patrol_points.is_empty():
		return
	nav_agent.target_position = _patrol_points[_patrol_index].global_position
	_patrol_index = (_patrol_index + 1) % _patrol_points.size()


func _collect_patrol_points() -> void:
	# Populated by whichever level places this Enemy - patrol points are
	# expected to sit in a "patrol_point_<floor index>" group (see
	# Scenes/Enemy/patrol_routes.tscn, not built yet). Falls back to standing
	# still rather than erroring if none exist. NOTE: this reads
	# global_position at _ready() time, so it needs re-running if something
	# later repositions this Enemy to an EnemySpawnPoint.
	for n in get_tree().get_nodes_in_group("patrol_point_%d" % FloorZones.get_floor(global_position)):
		if n is Node2D:
			_patrol_points.append(n)


# --- Floor crossing ------------------------------------------------------------

func _index_stairs() -> void:
	for s in get_tree().get_nodes_in_group(&"stairs"):
		if not s.get("destination_stairs"):
			continue
		var my_floor := FloorZones.get_floor(s.global_position)
		var dest_floor := FloorZones.get_floor(s.destination_stairs.global_position)
		_stairs_by_floor_pair[[my_floor, dest_floor]] = s


## Never hands NavigationAgent2D a cross-floor target directly.
## Substitutes a same-floor stairs approach point instead;
## the physical trigger (Scripts/Stairs.gd) does the rest.
func _resolve_nav_target(real_target: Vector2) -> Vector2:
	var my_floor := FloorZones.get_floor(global_position)
	var target_floor := FloorZones.get_floor(real_target)

	if my_floor == target_floor:
		return real_target

	var stairs = _find_stairs_toward(my_floor, target_floor)
	if stairs == null:
		return real_target  # safety net - never crash, never stall forever

	return stairs.tween_start_pos


func _find_stairs_toward(my_floor: int, target_floor: int) -> Node:
	var step := signi(target_floor - my_floor)
	return _stairs_by_floor_pair.get([my_floor, my_floor + step])


## Called by Stairs.gd's teleport() via duck typing (body.has_method(...)),
## exactly like PlayerMovement.gd's version - but with no camera/fade.
## Duration matches PlayerMovement.gd's default exactly so neither side
## gets a speed advantage.
func start_teleport(target_position: Vector2, tween_target_pos: Vector2, _stairs_end: Vector2 = Vector2.ZERO) -> void:
	if teleport_tween:
		teleport_tween.kill()

	is_teleporting = true
	velocity = Vector2.ZERO

	teleport_tween = create_tween()
	teleport_tween.tween_property(self, "global_position", tween_target_pos, STAIR_TWEEN_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	teleport_tween.tween_callback(func(): end_teleport(target_position))


func end_teleport(target_position: Vector2) -> void:
	global_position = target_position
	velocity = Vector2.ZERO
	is_teleporting = false


# --- Misc hooks ------------------------------------------------------------------

## Called by OverwhelmedModule when the house goes quiet in time,
## ForgetfulModule when player succesfully follows him, and by F4
## (debug_force_succeed). item is left null until we create UV-Flashlight
## and crowbar item Inventory only cares that the signal fires with
## a valid ItemData, so wire the real item later.
func drop_reward() -> void:
	GameEvents.enemy_dropped_item.emit(null, global_position)


func _on_touch_area_body_entered(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		GameEvents.player_caught.emit(&"touched")
