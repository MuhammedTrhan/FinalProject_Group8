extends "res://Scripts/Trailer/TrailerDirector.gd"
## The 60 s cut: the premise, then each of his three faces and what the game
## asks of her around them, then the way out. Reuses the teaser's study shot;
## everything else is new.

const PROFILE_PATHS := {
	PersonalityProfile.Personality.FORGETFUL: "res://Resources/Personalities/forgetful.tres",
	PersonalityProfile.Personality.PARANOID: "res://Resources/Personalities/paranoid.tres",
	PersonalityProfile.Personality.OVERWHELMED: "res://Resources/Personalities/overwhelmed.tres",
}
const UV_FLASHLIGHT := preload("res://Resources/Items/uv_flashlight.tres")
const UV_CLUE := preload("res://Scenes/Puzzles/uv_clue.tscn")

## "This House" has a rising siren-like sweep 22 s into the track. The teaser
## gets it on the title by luck; here the music is moved back so it lands there
## too. TITLE_LEAD is how long the cut takes from the jump to the title fading in.
const SWEEP_AT := 22.0
const TITLE_LEAD := 15.85

## Bounds of the bathroom shot, and of the ground floor (up to the exit door's wall).
const BATHROOM_LIMITS := Rect2(2100, 560, 395, 440)
const GROUND_FLOOR_LIMITS := Rect2(60, 100, 640, 900)
const EXIT_DOOR_SPOT := Vector2(610, 788)

var _tag_label: Label
var _face: TextureRect
var _rocking := false


func _ready() -> void:
	super()

	var layer := _caption.get_parent()
	_tag_label = _make_label(layer, 30, GOLD)
	_tag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_tag_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_tag_label.offset_left = 40.0
	_tag_label.offset_top = 28.0

	_face = TextureRect.new()
	_face.set_anchors_preset(Control.PRESET_CENTER)
	_face.offset_left = -150.0
	_face.offset_right = 150.0
	_face.offset_top = -230.0
	_face.offset_bottom = 70.0
	_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_face.modulate.a = 0.0
	layer.add_child(_face)


func _process(delta: float) -> void:
	super(delta)

	# The Loud Guy's rocking, as in OverwhelmedModule (his AI isn't running).
	if _rocking and _enemy != null:
		_enemy.sprite.rotation = deg_to_rad(8.0) * sin(_time * TAU / 2.2)


# --- The trailer ------------------------------------------------------------

func _run() -> void:
	await get_tree().scene_changed
	await _wait_for_actors()

	_heartbeat.play()
	create_tween().tween_property(_heartbeat, "volume_db", -6.0, 2.0)

	# Her opening night plays out under the black.
	_say(0.4, "SHE WOKE UP LOCKED IN.", 1.7)
	_say(2.5, "IN SOMEONE ELSE'S HOUSE.", 1.7)
	await _until(func() -> bool: return not _player.is_being_escorted and _time > 4.4)
	_puppet_enemy()
	create_tween().tween_property(_heartbeat, "volume_db", -40.0, 0.8)
	_player.camera.zoom = Vector2(3.0, 3.0)
	_set_limits(FLOOR_LIMITS)
	await _fade(0.0, 0.5)

	_say(0.1, "HE'S NOT ONE PERSON.", 1.8, true)
	await _walk_to(Vector2(1907, 215))
	_press_interact()
	await _wait(1.4)
	DayOneTerminal._turn_page(1)
	await _wait(1.4)
	DayOneTerminal._turn_page(1)
	await _wait(1.5)

	GameManager._retired_personalities = [
		PersonalityProfile.Personality.PARANOID,
		PersonalityProfile.Personality.OVERWHELMED,
	]
	DayOneTerminal.close()

	# Behind the game's own "DAY 1" card, set the first shot up.
	await _wait(0.95)
	_enemy.escort_controller._escorting = false
	# A clue sends the enemy to walk her home; he isn't running, so don't let
	# the finding in the UV shot lock her movement.
	GameEvents.clue_revealed.disconnect(_enemy.escort_controller._on_clue_revealed)

	_stage_study()
	_tag(0.6, "THE HAPPY ONE")
	await _study_shot()
	_hideable("Studyroom/Hideable").reveal_player(_player)

	await _cut_to(_stage_scary)
	await _scary_shot()
	await _cut_to(_stage_loud)
	await _loud_shot()
	await _cut_to(_stage_uv)
	await _uv_shot()
	await _cut_to(_stage_chase)
	await _long_chase_shot()
	await _cut_to(_stage_keypad)
	await _keypad_shot()
	await _faces_and_title()

	get_tree().quit()


# --- Shots ------------------------------------------------------------------

func _stage_scary() -> void:
	_become(PersonalityProfile.Personality.PARANOID)
	_open_door("HorizontalDoor4")
	_place_player(Vector2(2025, 525), "right")
	_place_enemy(Vector2(2085, 525), "right")
	_use_view(Vector2(3.0, 3.0), FLOOR_LIMITS)


## He creeps down the hallway with her tiptoeing behind him; he stops, warns,
## and turns - and she has to be out of the hallway by then.
func _scary_shot() -> void:
	_tag(0.0, "THE SCARY ONE")
	_say(0.3, "DON'T BE SEEN.", 1.5, true)
	_say(2.7, "ONE SECOND IS ALL IT TAKES.", 1.8, true)

	var turning := Job.new()
	_start(func() -> void:
		await _walk_enemy([Vector2(2200, 525)], 80.0)
		_enemy.is_turn_warning = true
		turning.done = true
		await _wait(1.2)
		_enemy.is_turn_warning = false
		await _walk_enemy([Vector2(1990, 525)], 100.0))

	await _walk_player([Vector2(2120, 525)], 6.0, 15.0, 0.55)
	await _until(func() -> bool: return turning.done)
	await _wait(0.3) # frozen for a moment, watching the "!"
	await _walk_player([Vector2(1960, 525), Vector2(1936, 500), Vector2(1936, 430)])
	await _wait(1.8)


func _stage_loud() -> void:
	_become(PersonalityProfile.Personality.OVERWHELMED)
	_open_door("VerticalDoor7")
	_sink().activate()
	_place_player(Vector2(2185, 690), "right")
	_place_enemy(Vector2(2400, 720), "down")
	_enemy.anim_handler.play_special_pose(&"sit_special")
	_rocking = true
	_use_view(Vector2(3.0, 3.0), BATHROOM_LIMITS)


## The running water is driving him mad; she has to reach the tap quietly.
func _loud_shot() -> void:
	_tag(0.0, "THE LOUD GUY")
	_say(0.3, "KEEP THE HOUSE QUIET.", 2.0, true)

	await _walk_player([Vector2(2262, 690), Vector2(2325, 672), Vector2(2320, 656)], 5.0)
	_player.anim_handler.set_facing_direction("left")
	await _wait(0.3)
	_press_interact() # turn the tap off
	await _wait(0.4)
	_rocking = false
	_enemy.sprite.rotation = 0.0
	_enemy.anim_handler.update_animations(Vector2.ZERO)
	await _wait(2.8)


## The mark found here is a stand-in, in the main bedroom: the real one stays
## where the game hides it, out of the trailer.
func _stage_uv() -> void:
	_rocking = false
	_enemy.sprite.rotation = 0.0
	var mark: Node2D = UV_CLUE.instantiate()
	mark.position = Vector2(2040, 850)
	get_tree().current_scene.add_child(mark)
	_place_player(Vector2(2040, 940), "up")
	_place_enemy(Vector2(300, 700), "down") # on another floor
	_use_view(Vector2(3.0, 3.0), FLOOR_LIMITS)
	GameEvents.item_use_requested.emit(UV_FLASHLIGHT, true)


## The UV flashlight finds a mark on the floor.
func _uv_shot() -> void:
	_tag(0.0, "THE CLUE")
	_say(0.3, "SEARCH EVERY ROOM.", 2.0, true)
	await _wait(0.6)
	await _walk_player([Vector2(2040, 895)], 4.0, 6.0, 0.6)
	await _wait(2.8)


## She types the code beside the locked exit door, on the ground floor.
func _stage_keypad() -> void:
	_place_player(EXIT_DOOR_SPOT, "right")
	_place_enemy(Vector2(610, 935), "up") # in the room below, out of frame
	_use_view(Vector2(3.0, 3.0), GROUND_FLOOR_LIMITS)


## Three digits, typed in.
func _keypad_shot() -> void:
	_say(0.2, "FIND THE CODE.", 2.2, true)
	ExitKeypad.open()
	await _wait(0.8)
	for digit in ProceduralGenerator.get_passcode():
		ExitKeypad.code_input.text += str(digit)
		await _wait(0.5)
	await _wait(1.1)
	ExitKeypad.close()
	_overlay.color.a = 1.0 # cut to the faces


func _stage_chase() -> void:
	GameEvents.item_use_requested.emit(UV_FLASHLIGHT, false)
	GameManager._day_transition.reset() # the "CLUE FOUND" caption
	await _align_music()
	_become(PersonalityProfile.Personality.FORGETFUL)
	_place_player(Vector2(2290, 330), "down")
	_place_enemy(Vector2(2395, 245), "left")
	_use_view(Vector2(2.7, 2.7), FLOOR_LIMITS)


func _long_chase_shot() -> void:
	_say(0.2, "RUN.", 1.3, true)
	_walk_player([
		Vector2(2192, 395), Vector2(2192, 525), Vector2(1960, 525),
		Vector2(1936, 500), Vector2(1936, 380),
	])
	_start(func() -> void:
		await _walk_enemy([
			Vector2(2192, 390), Vector2(2192, 525), Vector2(1960, 525),
			Vector2(1936, 500), Vector2(1936, 380),
		], 164.0, true))
	await _wait(4.0)
	_overlay.color.a = 1.0 # cut before he reaches her
	_ease_out_heartbeat()


## His three faces, then the title.
func _faces_and_title() -> void:
	_grade.visible = false
	_tag_label.modulate.a = 0.0
	await _wait(0.5)

	for personality: PersonalityProfile.Personality in PROFILE_PATHS:
		var profile: PersonalityProfile = load(PROFILE_PATHS[personality])
		_face.texture = profile.portrait
		_subtitle.text = profile.display_name.to_upper()
		_subtitle.offset_top = 120.0
		_subtitle.offset_bottom = 120.0
		_face.modulate.a = 1.0
		_subtitle.modulate.a = 1.0
		await _wait(0.9)
		_face.modulate.a = 0.0
		_subtitle.modulate.a = 0.0
		await _wait(0.1)

	await _say_and_wait("ONE HOUSE.", 1.0)
	await _say_and_wait("ONE WAY OUT.", 1.2)
	await _wait(0.3)

	await _reveal(_title, "TOO MANY FACES", 0.9)
	await _wait(0.5)
	await _reveal(_subtitle, "FIND THE CODE. ESCAPE THE HOUSE.", 0.7, 90.0)
	await _wait(0.5)
	await _reveal(_byline, "A GAME BY MUHAMMED TURHAN, REYYAN PAK & EMELIE MEINHARDT", 0.7, 190.0)
	await _wait(5.0)
	create_tween().tween_property(Music, "volume_db", -60.0, 1.0)
	for label: Label in [_title, _subtitle, _byline]:
		create_tween().tween_property(label, "modulate:a", 0.0, 1.0)
	await _wait(1.2)


# --- Helpers ----------------------------------------------------------------

## Cuts to black, sets the next shot up, and fades back in.
func _cut_to(stage: Callable) -> void:
	_shot_number += 1
	_overlay.color.a = 1.0
	_tag_label.modulate.a = 0.0
	_caption.modulate.a = 0.0
	await stage.call()
	await _wait(0.1)
	await _fade(0.0, 0.3)


func _tag(delay: float, text: String) -> void:
	await get_tree().create_timer(delay).timeout
	_tag_label.text = text
	var tween := create_tween()
	tween.tween_property(_tag_label, "modulate:a", 1.0, 0.25)
	tween.tween_interval(2.4)
	tween.tween_property(_tag_label, "modulate:a", 0.0, 0.25)


func _say_and_wait(text: String, hold: float) -> void:
	_say(0.0, text, hold, false)
	await _wait(hold + 0.5)


## He is still right behind her when the picture cuts, so her heartbeat would
## go on pounding under the faces and the title. Eases it out instead.
func _ease_out_heartbeat() -> void:
	var heartbeat: Node = _player.get_node("Heartbeat")
	var fade := create_tween().set_parallel()
	fade.tween_property(heartbeat, "min_volume_db", -22.0, 1.2)
	fade.tween_property(heartbeat, "max_volume_db", -22.0, 1.2)


## Jumps the music back so its sweep starts just as the title appears. Done
## under the black between two shots, with a quick dip so it isn't a click.
func _align_music() -> void:
	var lag: float = Music.get_playback_position() - _time # the music started a hair before the director
	var dip := create_tween()
	dip.tween_property(Music, "volume_db", -60.0, 0.12)
	await dip.finished
	Music.seek(SWEEP_AT + lag - TITLE_LEAD)
	create_tween().tween_property(Music, "volume_db", Music.playing_db, 0.12)


## Switches whose personality the enemy is wearing, sprites and all.
func _become(personality: PersonalityProfile.Personality) -> void:
	_enemy._apply_personality(personality)


func _place_player(pos: Vector2, facing: String) -> void:
	_player.global_position = pos
	_player.anim_handler.set_facing_direction(facing)
	_player.anim_handler.update_animations(Vector2.ZERO)
	_player.camera.reset_smoothing()


func _place_enemy(pos: Vector2, facing: String) -> void:
	_enemy.global_position = pos
	_enemy.anim_handler.set_facing_direction(facing)
	_enemy.anim_handler.update_animations(Vector2.ZERO)
	_face_cone()


func _use_view(zoom: Vector2, bounds: Rect2) -> void:
	_player.camera.zoom = zoom
	_set_limits(bounds)
	_player.camera.reset_smoothing()
	_grade.visible = true


func _sink() -> NoiseSourceFurniture:
	return get_tree().current_scene.get_node("Furnitures/Floor2/ParentToilet/Sink")
