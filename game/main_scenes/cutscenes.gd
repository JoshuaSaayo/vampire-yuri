extends Control

@onready var background: TextureRect = $Background
@onready var fade_rect: ColorRect = $FadeRect
@onready var dialogue_text: RichTextLabel = $DialogueLayer/DialogueBox/DialogueText
@onready var speaker_name: Label = $DialogueLayer/DialogueBox/SpeakerName
@onready var bgm_player: AudioStreamPlayer = $BGMPlayer
@onready var skip_btn: Button = $DialogueLayer/SkipBtn
@onready var hide_btn: Button = $DialogueLayer/HideBtn
@onready var dialogue_layer: CanvasLayer = $DialogueLayer


# Dictionary to store character nodes by position
var character_positions = {
	"left": null,
	"center": null,
	"right": null
}

# Dictionary to store active characters and their expressions
var active_characters = {}

var intro_data: Dictionary = {}
var scene_idx: int = 0
var line_idx: int = 0
var is_typing: bool = false
var is_transitioning: bool = false
var current_text: String = ""
var is_hidden: bool = false
var story_block = "intro"

@export var typing_speed: float = 0.03
@export var fade_duration: float = 0.7
@export var dim_brightness: float = 0.5

var tween: Tween

func _ready():
	# Map positions to actual nodes
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
		intro_data = json.data[story_block]
	else:
		push_error("JSON Parse Error: " + json.get_error_message())

func show_current_scene():
	if scene_idx >= intro_data.scenes.size():
		await FadeTransition.fade_to_scene("res://main_scenes/interactive_map.tscn")
		return
	
	clear_all_characters()
	
	var scene = intro_data.scenes[scene_idx]
	
	# Check if we need to change music (only if it's a different track)
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
	
	# Only fade out music if we're actually changing tracks
	if needs_music_change and bgm_player:
		var music_tween = create_tween()
		music_tween.tween_property(bgm_player, "volume_db", -80, fade_duration / 2)
	
	tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, fade_duration / 2.0)
	await tween.finished
	
	background.texture = load(intro_data.scenes[scene_idx].background)
	
	# Change music during black screen if needed
	if needs_music_change:
		var scene = intro_data.scenes[scene_idx]
		if scene.has("ost") and scene.ost != "":
			change_bgm(scene.ost)
	
	tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 0.0, fade_duration / 2.0)
	await tween.finished
	
	# Only fade music back in if we changed it
	if needs_music_change and bgm_player:
		var music_tween = create_tween()
		music_tween.tween_property(bgm_player, "volume_db", 0, fade_duration / 2)
	
	is_transitioning = false
	line_idx = 0
	show_current_line()

func show_current_line():
	var line = intro_data.scenes[scene_idx].lines[line_idx]
	speaker_name.text = line.speaker
	speaker_name.visible = line.speaker != ""
	current_text = line.text
	dialogue_text.text = ""
	dialogue_text.visible_characters = 0
	
	# Clear all characters first
	clear_all_characters()
	
	# Setup characters based on JSON positions
	setup_character("left", line.get("left"))
	setup_character("center", line.get("center"))
	setup_character("right", line.get("right"))
	
	# Apply brightness highlighting based on who's speaking
	highlight_speaker(line.speaker)
	
	start_typing()

func clear_all_characters():
	for position in character_positions:
		var char_node = character_positions[position]
		if char_node:
			char_node.hide_sprite()
			active_characters.erase(position)

func setup_character(position: String, expression_data):
	if expression_data == null:
		return
	
	# Check if it's an empty string (for string type)
	if expression_data is String and expression_data == "":
		return
	
	var char_node = character_positions[position]
	if not char_node:
		return
	
	# Parse expression data (can be string or dictionary for more complex data)
	var character_name = ""
	var expression = ""
	
	if expression_data is String:
		# Simple format: just the expression, character name from metadata
		expression = expression_data
		if char_node.has_meta("character_name"):
			character_name = char_node.get_meta("character_name")
	elif expression_data is Dictionary:
		# Advanced format: {"character": "Elara", "expression": "sad"}
		character_name = expression_data.get("character", "")
		expression = expression_data.get("expression", "")
	
	# Store which character is in this position
	active_characters[position] = {
		"node": char_node,
		"name": character_name,
		"expression": expression
	}
	
	# Apply the expression
	if expression != "":
		char_node.set_expression(expression)
	char_node.show_sprite()

func highlight_speaker(speaker: String):
	if speaker == "":
		# No speaker (narrative text) - dim all characters
		for position in active_characters:
			var char_data = active_characters[position]
			dim_character(char_data.node)
		return
	
	# Find which position has the speaking character
	var speaking_position = null
	for position in active_characters:
		var char_data = active_characters[position]
		if char_data.name == speaker:
			speaking_position = position
			break
	
	# Highlight speaking character, dim others
	for position in active_characters:
		var char_data = active_characters[position]
		if position == speaking_position:
			brighten_character(char_data.node)
		else:
			dim_character(char_data.node)

func brighten_character(char_node: Node2D):
	var t = create_tween()
	t.tween_property(
		char_node,
		"modulate",
		Color(1, 1, 1, 1), # full brightness
		0.1
	)

func dim_character(char_node: Node2D):
	var t = create_tween()
	var d = dim_brightness # like 0.5

	t.tween_property(
		char_node,
		"modulate",
		Color(d, d, d, 1), # darker, but fully opaque
		0.1
	)

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

func _input(event):

	if is_transitioning or PauseManager.is_paused:
		return
		

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		
		# 🔹 If hidden → just unhide (do nothing else)
		if is_hidden:
			is_hidden = false
			$DialogueLayer.visible = true
			return

		if is_typing:
			if tween:
				tween.kill()
			dialogue_text.text = current_text
			dialogue_text.visible_characters = -1
			is_typing = false
		else:
			var current_scene = intro_data.scenes[scene_idx]
			
			# Check BEFORE incrementing
			if line_idx + 1 >= current_scene.lines.size():
				scene_idx += 1
				line_idx = 0
				show_current_scene()
			else:
				line_idx += 1
				show_current_line()


func _on_skip_btn_pressed() -> void:
	await FadeTransition.fade_to_scene("res://main_scenes/interactive_map.tscn")


# func _on_hide_btn_pressed() -> void:
# 	is_hidden = true
# 	dialogue_layer.visible = false


func _on_pause_btn_pressed() -> void:
	if PauseManager.is_paused:
		return
	
	PauseManager.toggle_pause()
	
	var pause_scene = load("res://UI/pause_menu.tscn").instantiate()
	add_child(pause_scene)
