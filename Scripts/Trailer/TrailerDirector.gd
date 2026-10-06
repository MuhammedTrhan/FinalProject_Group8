extends Node
## Plays a scripted trailer inside the real game: the real player, enemy
## sprites, computer terminal and lighting, with a bot pressing the keys, the
## enemy walked along set routes (his AI is switched off so every take is the
## same) and captions laid over the top. Started by TrailerLauncher.gd.

const HEARTBEAT := preload("res://Assets/Audio/zapsplat_human_heartbeat_med_fast_72972.wav")
const GOLD := Color(0.83, 0.68, 0.35)
const CREAM := Color(0.9, 0.85, 0.75)

## Bounds of the top floor, so the camera never shows the grey outside.
const FLOOR_LIMITS := Rect2(1745, 100, 665, 900)

var _shots_dir := ""
var _time := 0.0
var _next_shot_time := 0.0
var _show_hud := false
## Bumped at every cut, which ends any enemy route still running from the last shot.
var _shot_number := 0

var _player: Player
var _enemy: Enemy

var _overlay: ColorRect
var _grade: Control
var _caption: Label
var _title: Label
var _subtitle: Label
var _byline: Label
var _heartbeat: AudioStreamPlayer


## A coroutine started without waiting for it, so a shot can run the enemy's
## route alongside the player's and check on it later.
class Job:
	var done := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # the terminal pauses the tree

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots_dir = arg.trim_prefix("--shots=")
			DirAccess.make_dir_recursive_absolute(_shots_dir)

	_build_overlay()
	_run()


func _process(delta: float) -> void:
	_time += delta

	# Tutorial hints, the clock and the HUD would sit over every shot.
	HintLabel.visible = false
	PhaseClock.visible = false
	Hud.visible = _show_hud
	if _player != null:
		_player.prompt_label.self_modulate.a = 0.0
		_player.message_label.self_modulate.a = 0.0

	if _shots_dir != "" and _time >= _next_shot_time:
		_next_shot_time += 0.5
		get_viewport().get_texture().get_image().save_png("%s/t%05.1f.png" % [_shots_dir, _time])


func _build_overlay() -> void:
	# A dark edge and a little tint over the gameplay, under the captions.
	var grade_layer := CanvasLayer.new()
	grade_layer.layer = 90
	add_child(grade_layer)

	_grade = Control.new()
	_grade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grade.visible = false
	grade_layer.add_child(_grade)

	var tint := ColorRect.new()
	tint.color = Color(0.02, 0.0, 0.05, 0.12)
	tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grade.add_child(tint)

	var gradient := Gradient.new()
	gradient.set_color(0, Color(0, 0, 0, 0))
	gradient.set_color(1, Color(0, 0, 0, 0.7))
	gradient.set_offset(0, 0.55)
	var vignette_texture := GradientTexture2D.new()
	vignette_texture.gradient = gradient
	vignette_texture.fill = GradientTexture2D.FILL_RADIAL
	vignette_texture.fill_from = Vector2(0.5, 0.5)
	vignette_texture.fill_to = Vector2(1.0, 0.5)
	vignette_texture.width = 256
	vignette_texture.height = 256
	var vignette := TextureRect.new()
	vignette.texture = vignette_texture
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grade.add_child(vignette)

	# Above every other layer in the game: the fade to black and the text.
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)

	_overlay = ColorRect.new()
	_overlay.color = Color.BLACK
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_overlay)

	_caption = _make_label(layer, 56, CREAM)
	_title = _make_label(layer, 104, GOLD)
	_subtitle = _make_label(layer, 34, CREAM)
	_byline = _make_label(layer, 22, Color(0.65, 0.6, 0.52))

	_heartbeat = AudioStreamPlayer.new()
	_heartbeat.stream = HEARTBEAT
	_heartbeat.volume_db = -80.0
	_heartbeat.bus = &"SFX"
	add_child(_heartbeat)


func _make_label(parent: Node, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	label.modulate.a = 0.0
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


# --- The trailer ------------------------------------------------------------

func _run() -> void:
	await get_tree().scene_changed
	await _wait_for_actors()

	_heartbeat.play()
	create_tween().tween_property(_heartbeat, "volume_db", -6.0, 2.0)

	# Her opening night plays out under the black: the enemy walks her home
	# and locks the door.
	_say(0.4, "SHE WOKE UP LOCKED IN.", 1.7)
	_say(2.5, "HE'S NOT ONE PERSON.", 1.7)
	await _until(func() -> bool: return not _player.is_being_escorted and _time > 4.4)
	_puppet_enemy() # his own AI is done for the night - from here the director walks him
	create_tween().tween_property(_heartbeat, "volume_db", -40.0, 0.8)
	_player.camera.zoom = Vector2(3.0, 3.0)
	_set_limits(FLOOR_LIMITS)
	await _fade(0.0, 0.5)

	# The computer: his three faces, one page at a time.
	await _walk_to(Vector2(1907, 215))
	_press_interact()
	await _wait(0.9)
	DayOneTerminal._turn_page(1)
	await _wait(0.85)
	DayOneTerminal._turn_page(1)
	await _wait(1.0)

	# Only the Happy One is awake for the shots that follow.
	GameManager._retired_personalities = [
		PersonalityProfile.Personality.PARANOID,
		PersonalityProfile.Personality.OVERWHELMED,
	]
	DayOneTerminal.close()

	# The game's own "DAY 1" card now covers the screen; set the next shot up
	# behind it.
	await _wait(0.95)
	_enemy.escort_controller._escorting = false
	_stage_study()
	await _study_shot()
	await _chase_shot()
	await _title_card()

	get_tree().quit()


## He follows her into the study; she waits for him in the bookcase.
func _stage_study() -> void:
	_open_door("HorizontalDoor4") # her room, unlocked
	_open_door("HorizontalDoor5") # the study
	_player.global_position = Vector2(2192, 470)
	_player.camera.reset_smoothing()
	_enemy.global_position = Vector2(2395, 525) # the far end of the hallway
	_grade.visible = true


func _study_shot() -> void:
	await _wait(0.6) # the card is still fading out

	_say(0.2, "STAY QUIET.", 1.3, true)
	_say(2.0, "HE'S LISTENING.", 1.5, true)
	_walk_player([Vector2(2192, 390), Vector2(2187, 207)])
	var enemy_route := _start(func() -> void:
		await _wait(0.5)
		await _walk_enemy([
			Vector2(2192, 525), Vector2(2192, 440), Vector2(2200, 320), Vector2(2215, 245),
		], 115.0))

	await _until(func() -> bool: return _player.global_position.distance_to(Vector2(2187, 207)) < 8.0)
	await get_tree().physics_frame
	_press_interact() # hide in the bookcase
	create_tween().tween_property(_player.camera, "zoom", Vector2(3.4, 3.4), 3.0)

	await _until(func() -> bool: return enemy_route.done)
	await _wait(1.4) # he stands there, close enough to touch the bookcase


## He sees her; she runs for her room.
func _chase_shot() -> void:
	_hideable("Studyroom/Hideable").reveal_player(_player)
	_player.global_position = Vector2(2290, 330)
	_player.camera.zoom = Vector2(2.7, 2.7)
	_player.camera.reset_smoothing()
	_enemy.global_position = Vector2(2395, 245)

	_say(0.2, "RUN.", 1.3, true)
	_walk_player([
		Vector2(2192, 395), Vector2(2192, 525), Vector2(1960, 525),
		Vector2(1936, 500), Vector2(1936, 380),
	])
	var enemy_route := _start(func() -> void:
		await _walk_enemy([
			Vector2(2192, 390), Vector2(2192, 525), Vector2(1960, 525),
			Vector2(1936, 500), Vector2(1936, 380),
		], 164.0, true))
	await _wait(4.0)
	_overlay.color.a = 1.0 # cut before he reaches her


func _title_card() -> void:
	_grade.visible = false
	await _wait(0.5)
	await _reveal(_title, "TOO MANY FACES", 0.9)
	await _wait(0.5)
	await _reveal(_subtitle, "FIND THE CODE. ESCAPE THE HOUSE.", 0.7, 90.0)
	await _wait(0.5)
	await _reveal(_byline, "A GAME BY MUHAMMED TURHAN, REYYAN PAK & EMELIE MEINHARDT", 0.7, 190.0)
	await _wait(2.2)
	create_tween().tween_property(Music, "volume_db", -60.0, 1.0)
	for label: Label in [_title, _subtitle, _byline]:
		create_tween().tween_property(label, "modulate:a", 0.0, 1.0)
	await _wait(1.2)


# --- Helpers ----------------------------------------------------------------

func _start(routine: Callable) -> Job:
	var job := Job.new()
	var run := func() -> void:
		await routine.call()
		job.done = true
	run.call()
	return job


func _wait_for_actors() -> void:
	while true:
		_player = get_tree().get_first_node_in_group(&"player")
		_enemy = get_tree().get_first_node_in_group(&"enemy")
		if _player != null and _enemy != null:
			return
		await get_tree().process_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _until(condition: Callable) -> void:
	while not condition.call():
		await get_tree().process_frame


func _fade(alpha: float, seconds: float) -> void:
	var tween := create_tween()
	tween.tween_property(_overlay, "color:a", alpha, seconds)
	await tween.finished


## A line of text over the picture, starting `delay` seconds from now: fades
## in, holds, fades out. Not awaited - captions run alongside the action.
func _say(delay: float, text: String, hold: float, low := false) -> void:
	await get_tree().create_timer(delay).timeout
	_caption.text = text
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM if low else VERTICAL_ALIGNMENT_CENTER
	_caption.offset_bottom = -48.0 if low else 0.0
	var tween := create_tween()
	tween.tween_property(_caption, "modulate:a", 1.0, 0.25)
	tween.tween_interval(hold)
	tween.tween_property(_caption, "modulate:a", 0.0, 0.25)


## Fades a title line in at `offset` pixels below the middle of the screen.
func _reveal(label: Label, text: String, seconds: float, offset := 0.0) -> void:
	label.text = text
	label.offset_top = offset
	label.offset_bottom = offset
	var tween := create_tween()
	tween.tween_property(label, "modulate:a", 1.0, seconds)
	await tween.finished


func _hideable(path: String) -> Hideable:
	return get_tree().current_scene.get_node("Furnitures/Floor2/" + path)


func _set_limits(bounds: Rect2) -> void:
	_player.camera.limit_left = int(bounds.position.x)
	_player.camera.limit_top = int(bounds.position.y)
	_player.camera.limit_right = int(bounds.end.x)
	_player.camera.limit_bottom = int(bounds.end.y)


func _open_door(door_name: String) -> void:
	var door: Door = get_tree().current_scene.get_node("Furnitures/Doors/" + door_name)
	if door.is_locked:
		door.toogle_lock()
	door.open_door()


# --- The enemy --------------------------------------------------------------

## His AI would wander off and catch her; from here on the director walks him.
func _puppet_enemy() -> void:
	_enemy.set_physics_process(false)
	_enemy.touch_area.monitoring = false


## Walks the enemy through `points` at `speed` (pixels per second). Awaitable,
## and stops early if the trailer cuts to another shot meanwhile.
func _walk_enemy(points: Array, speed: float, running := false) -> void:
	var shot := _shot_number
	for point: Vector2 in points:
		while _enemy.global_position.distance_to(point) > 2.0:
			if shot != _shot_number:
				return
			var to_point := point - _enemy.global_position
			var step := minf(speed * get_physics_process_delta_time(), to_point.length())
			_enemy.velocity = to_point.normalized() * speed
			_enemy.global_position += to_point.normalized() * step
			_enemy.anim_handler.update_animations(_enemy.velocity, running)
			_face_cone()
			await get_tree().physics_frame
	_enemy.velocity = Vector2.ZERO
	_enemy.anim_handler.update_animations(Vector2.ZERO)
	_face_cone()


## His vision cone follows his sprite's facing (his own AI normally sets this).
func _face_cone() -> void:
	_enemy.perception.facing_dir = _enemy.anim_handler.get_facing_vector()


# --- The player -------------------------------------------------------------

func _press_interact() -> void:
	for pressed in [true, false]:
		var ev := InputEventAction.new()
		ev.action = &"Interact"
		ev.pressed = pressed
		Input.parse_input_event(ev)


## Holds the movement keys towards `direction` (zero lets go of all of them).
## A `strength` below 1 is a gentle push on the stick - a slower, sneaking walk.
func _drive(direction: Vector2, strength := 1.0) -> void:
	var dir := direction.normalized() * strength
	_set_action(&"right", maxf(dir.x, 0.0))
	_set_action(&"left", maxf(-dir.x, 0.0))
	_set_action(&"down", maxf(dir.y, 0.0))
	_set_action(&"up", maxf(-dir.y, 0.0))


func _set_action(action: StringName, strength: float) -> void:
	if strength > 0.0:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)


## Walks the player along the navigation mesh the enemy uses.
func _walk_to(target: Vector2) -> void:
	var nav_map := _enemy.nav_agent.get_navigation_map()
	await _walk_player(NavigationServer2D.map_get_path(nav_map, _player.global_position, target, true))


## Presses the keys to walk the player through `points`. Awaitable.
func _walk_player(points: Array, tolerance := 6.0, timeout := 15.0, strength := 1.0) -> void:
	var elapsed := 0.0
	for point: Vector2 in points:
		while _player.global_position.distance_to(point) > tolerance and elapsed < timeout:
			_drive(point - _player.global_position, strength)
			await get_tree().physics_frame
			elapsed += get_physics_process_delta_time()
	_drive(Vector2.ZERO)
