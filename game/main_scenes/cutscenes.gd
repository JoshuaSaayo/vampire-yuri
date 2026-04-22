extends Control

@onready var background: TextureRect = $Background
@onready var fade_rect: ColorRect = $FadeRect
@onready var dialogue_text: RichTextLabel = $DialogueLayer/DialogueBox/DialogueText
@onready var speaker_name: Label = $DialogueLayer/DialogueBox/SpeakerName
@onready var bgm_player: AudioStreamPlayer = $BGMPlayer
@onready var dialogue_layer: CanvasLayer = $DialogueLayer

# ====================== CHARACTER POSITIONS ======================
var character_positions = {
	"left": null,
	"center": null,
	"right": null
}

var active_characters = {}

# ====================== DIALOGUE STATE ======================
var intro_data: Dictionary = {}
var scene_idx: int = 0
var line_idx: int = 0
var current_text: String = ""

var is_typing: bool = false
var is_transitioning: bool = false
var is_hidden: bool = false
var story_block: String = "intro"

# ====================== EXPORTS ======================
@export var typing_speed: float = 0.03
@export var fade_duration: float = 0.7
@export var dim_brightness: float = 0.5

var tween: Tween

# ====================== INITIALIZATION ======================
func _ready():
	character_positions["left"] = $LeftCharacter
	character_positions["center"] = $CenterCharacter
	character_positions["right"] = $RightCharacter
	
	fade_rect.modulate.a = 0.0
	story_block = CutsceneState.story_block
	
	load_dialogue_json()
	show_current_scene()

func load_dialogue_json():
	var file = FileAccess.open("res://dialogues/cutscene_dialogues.json", FileAccess.READ)
	if not file:
		push_error("JSON file not found")
		return
	
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK:
		var full_data = json.data
		print("📖 Full JSON loaded. Available keys: ", full_data.keys())
		
		if full_data.has(story_block):
			intro_data = full_data[story_block]
			print("✅ Loaded story block: ", story_block)
			print("📋 Has scenes: ", intro_data.has("scenes"))
			print("📋 Has endings: ", intro_data.has("endings"))
			if intro_data.has("endings"):
				print("🏆 Endings available: ", intro_data.endings.keys())
		else:
			push_error("Story block '", story_block, "' not found in JSON!")
	else:
		push_error("JSON Parse Error: " + json.get_error_message())

# ====================== SCENE MANAGEMENT ======================
func show_current_scene():
	print("📺 show_current_scene called - scene_idx: ", scene_idx, " / total scenes: ", intro_data.scenes.size())
	
	if scene_idx >= intro_data.scenes.size():
		print("🏁 Cutscene finished. story_block = ", story_block)
		
		# Check if this is chapter_1 and we have endings
		if story_block == "chapter_1" and intro_data.has("endings"):
			print("🎬 Determining ending for chapter_1...")
			await determine_and_play_ending()
		else:
			print("🚪 No endings found or not chapter_1. Fading to interactive map...")
			await FadeTransition.fade_to_scene("res://main_scenes/interactive_map.tscn")
		return
	
	# Safety check - ensure scene exists
	if scene_idx < 0 or scene_idx >= intro_data.scenes.size():
		push_error("Invalid scene index: ", scene_idx)
		await FadeTransition.fade_to_scene("res://main_scenes/interactive_map.tscn")
		return
	
	clear_all_characters()
	
	var scene = intro_data.scenes[scene_idx]
	
	var needs_music_change = false
	if scene.has("ost") and scene.ost != "":
		var current_music = bgm_player.stream.resource_path if bgm_player.stream else ""
		if current_music != scene.ost:
			needs_music_change = true
	
	if scene_idx > 0:
		fade_out_and_change_scene(needs_music_change)
	else:
		background.texture = load(scene.background)
		if needs_music_change:
			change_bgm(scene.ost)
		show_current_line()

func determine_and_play_ending():
	print("🔍 Starting determine_and_play_ending()")
	
	# Get the appropriate ending based on affection
	var ending = ChoiceManager.get_ending()
	print("🏆 Selected ending: ", ending)
	
	# Make sure intro_data has endings
	if not intro_data.has("endings"):
		print("❌ No 'endings' key in intro_data!")
		await FadeTransition.fade_to_scene("res://main_scenes/interactive_map.tscn")
		return
	
	var endings_data = intro_data["endings"]
	print("📚 Available endings: ", endings_data.keys())
	
	if not endings_data.has(ending):
		print("⚠️ Ending '", ending, "' not found! Available: ", endings_data.keys())
		# Fallback to neutral_ending
		if endings_data.has("neutral_ending"):
			ending = "neutral_ending"
			print("🔄 Falling back to neutral_ending")
		else:
			print("❌ No fallback ending found!")
			await FadeTransition.fade_to_scene("res://main_scenes/interactive_map.tscn")
			return
	
	var ending_data = endings_data[ending]
	var ending_scenes = ending_data.get("scenes", [])
	print("🎬 Ending scenes count for '", ending, "': ", ending_scenes.size())
	
	if ending_scenes.is_empty():
		print("❌ No scenes found in ending!")
		await FadeTransition.fade_to_scene("res://main_scenes/interactive_map.tscn")
		return
	
	# Update CutsceneState
	CutsceneState.set_ending(ending)
	CutsceneState.play_ending(ending)
	print("✅ Updated CutsceneState with ending: ", ending)
	
	# Replace current cutscene data with ending
	intro_data.scenes = ending_scenes
	scene_idx = 0
	line_idx = 0
	
	clear_all_characters()
	print("🎬 Playing ending cutscene now...")
	show_current_scene()

func change_bgm(music_path: String):
	if not bgm_player:
		return
	
	var new_stream = load(music_path)
	if new_stream:
		bgm_player.stream = new_stream
		bgm_player.play()

func fade_out_and_change_scene(needs_music_change: bool = false):
	is_transitioning = true
	
	if tween:
		tween.kill()
	
	if needs_music_change and bgm_player:
		var music_tween = create_tween()
		music_tween.tween_property(bgm_player, "volume_db", -80, fade_duration / 2)
	
	tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, fade_duration / 2.0)
	await tween.finished
	
	background.texture = load(intro_data.scenes[scene_idx].background)
	
	if needs_music_change:
		var scene = intro_data.scenes[scene_idx]
		if scene.has("ost") and scene.ost != "":
			change_bgm(scene.ost)
	
	tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 0.0, fade_duration / 2.0)
	await tween.finished
	
	if needs_music_change and bgm_player:
		var music_tween = create_tween()
		music_tween.tween_property(bgm_player, "volume_db", 0, fade_duration / 2)
	
	is_transitioning = false
	line_idx = 0
	show_current_line()

# ====================== CHARACTER MANAGEMENT ======================
func clear_all_characters():
	for position in character_positions:
		var char_node = character_positions[position]
		if char_node:
			char_node.hide_sprite()
			active_characters.erase(position)

func setup_character(position: String, expression_data):
	if expression_data == null:
		return
	
	if expression_data is String and expression_data == "":
		return
	
	var char_node = character_positions[position]
	if not char_node:
		return
	
	var character_name = ""
	var expression = ""
	
	if expression_data is String:
		expression = expression_data
		if char_node.has_meta("character_name"):
			character_name = char_node.get_meta("character_name")
	elif expression_data is Dictionary:
		character_name = expression_data.get("character", "")
		expression = expression_data.get("expression", "")
	
	active_characters[position] = {
		"node": char_node,
		"name": character_name,
		"expression": expression
	}
	
	if expression != "":
		char_node.set_expression(expression)
	char_node.show_sprite()

# ====================== HIGHLIGHT SYSTEM ======================
func highlight_speaker(speaker: String):
	if speaker == "":
		for position in active_characters:
			var char_data = active_characters[position]
			dim_character(char_data.node)
		return
	
	var speaking_position = null
	for position in active_characters:
		var char_data = active_characters[position]
		if char_data.name == speaker:
			speaking_position = position
			break
	
	for position in active_characters:
		var char_data = active_characters[position]
		if position == speaking_position:
			brighten_character(char_data.node)
		else:
			dim_character(char_data.node)

func brighten_character(char_node: Node2D):
	var t = create_tween()
	t.tween_property(char_node, "modulate", Color(1, 1, 1, 1), 0.1)

func dim_character(char_node: Node2D):
	var t = create_tween()
	var d = dim_brightness
	t.tween_property(char_node, "modulate", Color(d, d, d, 1), 0.1)

# ====================== DIALOGUE DISPLAY ======================
func show_current_line():
	if scene_idx >= intro_data.scenes.size():
		push_error("Scene index out of bounds: ", scene_idx)
		end_cutscene()
		return
	
	var current_scene = intro_data.scenes[scene_idx]
	
	if line_idx >= current_scene.lines.size():
		push_error("Line index out of bounds: ", line_idx, " / ", current_scene.lines.size())
		scene_idx += 1
		line_idx = 0
		show_current_scene()
		return
	
	var line = current_scene.lines[line_idx]
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

# ====================== TYPING SYSTEM ======================
func start_typing():
	is_typing = true
	if tween:
		tween.kill()
	
	tween = create_tween()
	tween.tween_method(_update_text, 0, current_text.length(), current_text.length() * typing_speed)
	tween.finished.connect(_on_typing_finished)

func _update_text(chars: int):
	dialogue_text.visible_characters = chars
	dialogue_text.text = current_text

func _on_typing_finished():
	is_typing = false
	dialogue_text.visible_characters = -1

func skip_typing():
	if tween and tween.is_running():
		tween.kill()
	dialogue_text.text = current_text
	dialogue_text.visible_characters = -1
	is_typing = false

# ====================== INPUT ======================
func _input(event):
	if is_transitioning or PauseManager.is_paused:
		return
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# If hidden, just unhide and stop (don't advance dialogue)
		if is_hidden:
			is_hidden = false
			dialogue_layer.visible = true
			return
		
		if is_typing:
			skip_typing()
		else:
			if scene_idx >= intro_data.scenes.size():
				end_cutscene()
				return
			
			var current_scene = intro_data.scenes[scene_idx]
			
			if line_idx + 1 >= current_scene.lines.size():
				scene_idx += 1
				line_idx = 0
				show_current_scene()
			else:
				line_idx += 1
				show_current_line()

# ====================== UTILITIES ======================
func end_cutscene():
	await FadeTransition.fade_to_scene("res://main_scenes/interactive_map.tscn")

# ====================== BUTTONS ======================
func _on_skip_btn_pressed():
	# Skip to appropriate destination based on context
	if story_block == "chapter_1":
		# When skipping during chapter_1, still determine ending
		await determine_and_play_ending()
	else:
		await FadeTransition.fade_to_scene("res://main_scenes/interactive_map.tscn")

func _on_hide_btn_pressed():
	is_hidden = true
	dialogue_layer.visible = false

func _on_pause_btn_pressed():
	if PauseManager.is_paused:
		return
	
	PauseManager.toggle_pause()
	var pause_scene = load("res://UI/pause_menu.tscn").instantiate()
	add_child(pause_scene)
