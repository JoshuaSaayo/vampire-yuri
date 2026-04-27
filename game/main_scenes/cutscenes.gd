extends Control

@onready var background: TextureRect = $Background
@onready var fade_rect: ColorRect = $FadeRect
@onready var dialogue_text: RichTextLabel = $DialogueLayer/DialogueBox/DialogueText
@onready var speaker_name: Label = $DialogueLayer/DialogueBox/SpeakerName
@onready var bgm_player: AudioStreamPlayer = $BGMPlayer
@onready var dialogue_layer: CanvasLayer = $DialogueLayer
@onready var spine_background: Node2D = $SpineBackground


# ====================== CHARACTER POSITIONS ======================
var character_positions = {}
var active_characters = {}

# ====================== DIALOGUE STATE ======================
var intro_data := {}
var scene_idx := 0
var line_idx := 0
var current_text := ""

var is_typing := false
var is_transitioning := false
var is_hidden := false
var story_block := "intro"

# ====================== EXPORTS ======================
@export var typing_speed := 0.03
@export var fade_duration := 0.7
@export var dim_brightness := 0.5

var tween: Tween

# ====================== INITIALIZATION ======================
func _ready():
	character_positions = {
		"left": $LeftCharacter,
		"center": $CenterCharacter,
		"right": $RightCharacter
	}
	
	fade_rect.modulate.a = 0
	story_block = CutsceneState.story_block
	
	load_dialogue_json()
	show_current_scene()

func load_dialogue_json():
	var file = FileAccess.open("res://dialogues/cutscene_dialogues.json", FileAccess.READ)
	if not file:
		push_error("JSON missing")
		return
	
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error(json.get_error_message())
		return
	
	var data = json.data
	intro_data = data.get(story_block, data.get("intro", {}))

# ====================== SCENE MANAGEMENT ======================
func show_current_scene():
	if scene_idx >= intro_data.get("scenes", []).size():
		print("🏁 Cutscene finished. story_block = ", story_block)
		
		# If this is chapter_1 with endings, play the ending
		if story_block == "chapter_1" and intro_data.has("endings"):
			print("🎬 Determining ending for chapter_1...")
			await determine_and_play_ending()
			return
		
		# If this is an ending scene for chapter_1, go to credits
		if story_block == "chapter_1" and CutsceneState.last_ending != "":
			print("🏁 Ending finished, showing credits...")
			await show_to_be_continued()
			return
		
		# For intro or any other story block, go to interactive map
		print("🚪 Cutscene finished, going to interactive map...")
		await FadeTransition.fade_to_scene("res://main_scenes/interactive_map.tscn")
		return
	
	clear_all_characters()
	var scene = intro_data.scenes[scene_idx]
	
	var change_music = scene.has("ost") and scene.ost != "" \
		and (not bgm_player.stream or bgm_player.stream.resource_path != scene.ost)
	
	if scene_idx > 0:
		await fade_scene(scene, change_music)
	else:
		load_background(scene)
		if change_music: change_bgm(scene.ost)
		show_current_line()

func determine_and_play_ending():
	var ending = ChoiceManager.get_ending()
	var endings = intro_data.get("endings", {})
	
	print("🎯 Determined ending: ", ending)
	
	if not endings.has(ending):
		ending = "neutral_ending" if endings.has("neutral_ending") else ""
	
	if ending == "":
		print("⚠️ No valid ending found, going to interactive map")
		await FadeTransition.fade_to_scene("res://main_scenes/interactive_map.tscn")
		return
	
	CutsceneState.set_ending(ending)
	CutsceneState.play_ending(ending)
	print("🏆 Playing ending: ", ending)
	
	# Replace scenes with ending scenes
	intro_data.scenes = endings[ending].get("scenes", [])
	scene_idx = 0
	line_idx = 0
	clear_all_characters()
	show_current_scene()

func change_bgm(path: String):
	if bgm_player and path != "":
		bgm_player.stream = load(path)
		bgm_player.play()

func load_background(scene):
	# Clear previous Spine
	for c in spine_background.get_children():
		c.queue_free()
	
	# If Spine animation exists
	if scene.has("background_animation") and scene.background_animation != "":
		var inst = load(scene.background_animation).instantiate()
		spine_background.add_child(inst)
		spine_background.visible = true
		background.visible = false
	else:
		# Fallback to static image
		background.texture = load(scene.background)
		background.visible = true
		spine_background.visible = false



func fade_scene(scene, change_music):
	is_transitioning = true
	
	if tween: tween.kill()
	
	if change_music:
		create_tween().tween_property(bgm_player, "volume_db", -80, fade_duration/2)
	
	await create_tween().tween_property(fade_rect, "modulate:a", 1.0, fade_duration/2).finished
	
	load_background(scene)
	if change_music: change_bgm(scene.ost)
	
	await create_tween().tween_property(fade_rect, "modulate:a", 0.0, fade_duration/2).finished
	
	if change_music:
		create_tween().tween_property(bgm_player, "volume_db", 0, fade_duration/2)
	
	is_transitioning = false
	line_idx = 0
	show_current_line()

# ====================== TRANSITION ======================
func show_to_be_continued():
	save_game_progress()
	if tween: tween.kill()
	await create_tween().tween_property(fade_rect, "modulate:a", 1.0, fade_duration).finished
	get_tree().change_scene_to_file("res://UI/end_transition.tscn")

func save_game_progress():
	ChoiceManager.set_flag("game_completed", true)
	ChoiceManager.set_flag("last_ending", CutsceneState.last_ending)
	ChoiceManager.set_flag("lilith_affection_chapter1", ChoiceManager.get_affection("Lilith"))

# ====================== CHARACTER MANAGEMENT ======================
func clear_all_characters():
	for pos in character_positions:
		var node = character_positions[pos]
		if node:
			node.hide_sprite()
	active_characters.clear()

func setup_character(pos: String, data):
	if not data: return
	
	var node = character_positions.get(pos)
	if not node: return
	
	var name: String = data.get("character", "") if data is Dictionary else str(node.get_meta("character_name", ""))
	var expr: String = data.get("expression", data) if data is Dictionary else str(data)
	
	active_characters[pos] = { "node": node, "name": name }
	
	if expr != "": node.set_expression(expr)
	node.show_sprite()

# ====================== HIGHLIGHT SYSTEM ======================
func highlight_speaker(speaker: String):
	for pos in active_characters:
		var c = active_characters[pos]
		(c.node if c.name == speaker else c.node).modulate = \
			Color(1,1,1) if c.name == speaker else Color(dim_brightness, dim_brightness, dim_brightness)

# ====================== DIALOGUE DISPLAY ======================
func show_current_line():
	var scenes = intro_data.get("scenes", [])
	
	if scenes.is_empty():
		print("⚠️ No scenes found!")
		end_cutscene()
		return
	
	if scene_idx >= scenes.size():
		print("⚠️ Scene index out of bounds: ", scene_idx)
		end_cutscene()
		return
	
	var scene = scenes[scene_idx]
	
	if line_idx >= scene.lines.size():
		print("⚠️ Line index out of bounds: ", line_idx, " / ", scene.lines.size(), " for scene ", scene_idx)
		scene_idx += 1
		line_idx = 0
		show_current_scene()
		return
	
	var line = scene.lines[line_idx]
	print("🎬 Showing line ", line_idx, " of scene ", scene_idx, " | Total lines: ", scene.lines.size())
	
	if line.has("action"):
		handle_action(line.action)
		return
	
	speaker_name.text = line.speaker
	speaker_name.visible = line.speaker != ""
	current_text = line.text
	
	dialogue_text.text = ""
	dialogue_text.visible_characters = 0
	
	clear_all_characters()
	setup_character("left", line.get("left"))
	setup_character("center", line.get("center"))
	setup_character("right", line.get("right"))
	
	highlight_speaker(line.speaker)
	start_typing()

	
func handle_action(action: String):
	if action in ["end_cutscene", "chapter1_end"]:
		end_cutscene()

# ====================== TYPING SYSTEM ======================
func start_typing():
	is_typing = true
	if tween: tween.kill()
	
	tween = create_tween()
	tween.tween_method(_update_text, 0, current_text.length(), current_text.length() * typing_speed)
	tween.finished.connect(func(): is_typing = false)

func _update_text(c):
	dialogue_text.visible_characters = c
	dialogue_text.text = current_text

func skip_typing():
	if tween: tween.kill()
	dialogue_text.text = current_text
	dialogue_text.visible_characters = -1
	is_typing = false

# ====================== INPUT ======================
func _input(event):
	if is_transitioning or PauseManager.is_paused:
		return
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		
		if is_hidden:
			is_hidden = false
			dialogue_layer.visible = true
			return
		
		if is_typing:
			skip_typing()
			return
		
		# SAFETY CHECK: Ensure scene_idx is valid
		var scenes = intro_data.get("scenes", [])
		if scenes.is_empty() or scene_idx >= scenes.size():
			print("⚠️ Invalid scene_idx: ", scene_idx, " / scenes size: ", scenes.size())
			end_cutscene()
			return
		
		var scene = scenes[scene_idx]
		
		# Check if we're at the last line of current scene
		if line_idx + 1 >= scene.lines.size():
			# Move to next scene
			scene_idx += 1
			line_idx = 0
			show_current_scene()
			return
		
		# Move to next line in current scene
		line_idx += 1
		show_current_line()

# ====================== UTILITIES ======================
func end_cutscene():
	if tween: tween.kill()
	await show_to_be_continued()

# ====================== BUTTONS ======================
func _on_skip_btn_pressed():
	if tween: tween.kill()
	
	if story_block == "chapter_1":
		var ending = ChoiceManager.get_ending()
		CutsceneState.set_ending(ending)
		CutsceneState.play_ending(ending)
		save_game_progress()
		await show_to_be_continued()
	else:
		await FadeTransition.fade_to_scene("res://main_scenes/interactive_map.tscn")

func _on_hide_btn_pressed():
	is_hidden = true
	dialogue_layer.visible = false

func _on_pause_btn_pressed():
	if PauseManager.is_paused: return
	PauseManager.toggle_pause()
	add_child(load("res://UI/pause_menu.tscn").instantiate())
