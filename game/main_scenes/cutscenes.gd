extends Control

@onready var background: TextureRect = $Background
@onready var fade_rect: ColorRect = $FadeRect
@onready var dialogue_text: RichTextLabel = $DialogueLayer/DialogueBox/DialogueText
@onready var speaker_name: Label = $DialogueLayer/DialogueBox/SpeakerName

@onready var left_character: Node2D = $LeftCharacter
@onready var center_character: Node2D = $CenterCharacter
@onready var right_character: Node2D = $RightCharacter

var intro_data: Dictionary = {}
var scene_idx: int = 0
var line_idx: int = 0
var is_typing: bool = false
var is_transitioning: bool = false  # NEW: blocks input during fades
var current_text: String = ""

@export var typing_speed: float = 0.03
@export var fade_duration: float = 0.7

var tween: Tween

func _ready():
	fade_rect.modulate.a = 0.0
	load_dialogue_json()
	show_current_scene()

func load_dialogue_json():
	var file = FileAccess.open("res://dialogues/cutscene_dialogues.json", FileAccess.READ)
	if not file:
		push_error("JSON file not found")
		return
	
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK:
		intro_data = json.data
	else:
		push_error("JSON Parse Error: " + json.get_error_message())

func show_current_scene():
	if scene_idx >= intro_data.scenes.size():
		get_tree().change_scene_to_file("res://interactive_maps/bedroom_interactive.tscn")
		return
	
	if scene_idx > 0:
		fade_out_and_change_scene()
	else:
		background.texture = load(intro_data.scenes[0].background)
		show_current_line()

func fade_out_and_change_scene():
	is_transitioning = true  # Block input
	
	if tween:
		tween.kill()
	
	tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, fade_duration / 2.0)
	await tween.finished
	
	background.texture = load(intro_data.scenes[scene_idx].background)
	
	tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 0.0, fade_duration / 2.0)
	await tween.finished
	
	is_transitioning = false  # Unblock input
	line_idx = 0
	show_current_line()

func show_current_line():
	var line = intro_data.scenes[scene_idx].lines[line_idx]
	speaker_name.text = line.speaker
	speaker_name.visible = line.speaker != ""
	current_text = line.text
	dialogue_text.text = ""
	dialogue_text.visible_characters = 0
	
	# === SPRITE HANDLING ===
	update_character_sprite(left_character, line.get("left"))
	update_character_sprite(center_character, line.get("center"))
	update_character_sprite(right_character, line.get("right"))
	
	start_typing()

func update_character_sprite(char_node: Node2D, expression: Variant):
	if expression == null or expression == "":
		char_node.hide_sprite()
	else:
		char_node.set_expression(expression)
		char_node.show_sprite()

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
	# Ignore input during fade transitions
	if is_transitioning:
		return
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_typing:
			if tween:
				tween.kill()
			dialogue_text.text = current_text
			dialogue_text.visible_characters = -1
			is_typing = false
		else:
			line_idx += 1
			
			if line_idx >= intro_data.scenes[scene_idx].lines.size():
				scene_idx += 1
				line_idx = 0
				show_current_scene()
			else:
				show_current_line()
