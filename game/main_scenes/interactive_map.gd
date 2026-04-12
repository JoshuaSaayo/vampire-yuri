extends Control

@onready var background: TextureRect = $Background
@onready var bgm_player: AudioStreamPlayer = $BGMPlayer
@onready var dialogue_box: Panel = $DialogueBox
@onready var speaker_name: Label = $DialogueBox/SpeakerName
@onready var dialogue_text: RichTextLabel = $DialogueBox/DialogueText

# Interactive areas container
@onready var interactive_areas = $InteractiveAreas.get_children()

# Dialogue system
var bedroom_data: Dictionary = {}
var dialogue_queue: Array = []
var current_full_text: String = ""

var is_showing_dialogue: bool = false
var is_typing: bool = false
var is_hidden: bool = false
var intro_dialogue_shown: bool = false

@export var typing_speed: float = 0.03

var tween: Tween

func _ready():
	dialogue_box.visible = false
	load_bedroom_dialogue()
	setup_interactive_areas()
	
	# Show intro dialogue automatically when scene starts
	show_intro_dialogue()

func load_bedroom_dialogue():
	var file = FileAccess.open("res://dialogues/interactive_dialogues.json", FileAccess.READ)
	if not file:
		push_error("Bedroom dialogue JSON not found")
		return
	
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK:
		bedroom_data = json.data
		print("✅ Bedroom dialogue JSON loaded successfully!")
	else:
		push_error("JSON Parse Error: " + json.get_error_message())

func setup_interactive_areas():
	for area in interactive_areas:
		if not area is Area2D:
			continue
			
		area.mouse_entered.connect(func(): Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND))
		area.mouse_exited.connect(func(): Input.set_default_cursor_shape(Input.CURSOR_ARROW))
		
		# Connect input event with area reference
		area.input_event.connect(_on_area_clicked.bind(area))
		
	# Disable interaction until intro is finished
	set_interactive_enabled(false)

func set_interactive_enabled(enabled: bool):
	for area in interactive_areas:
		if area is Area2D:
			area.monitoring = enabled
			area.monitorable = enabled

# ====================== AREA CLICKED ======================
func _on_area_clicked(_viewport, event, _shape_idx, area):
	if is_showing_dialogue or is_hidden:
		return
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var id = area.get_meta("id", "")
		if id != "":
			show_item_dialogue(id)

# ====================== DIALOGUE SYSTEM ======================
func show_intro_dialogue():
	var intro_lines = bedroom_data.get("intro", [])
	if intro_lines.is_empty():
		set_interactive_enabled(true)
		return
	
	dialogue_queue = intro_lines.duplicate()
	is_showing_dialogue = true
	dialogue_box.visible = true
	show_next_dialogue()

func show_item_dialogue(item_id: String):
	var item_data = bedroom_data.get(item_id, {})
	var dialogues = item_data.get("dialogues", [])
	
	if dialogues.is_empty():
		return
	
	set_interactive_enabled(false)
	dialogue_queue = dialogues.duplicate()
	is_showing_dialogue = true
	dialogue_box.visible = true
	show_next_dialogue()

func show_next_dialogue():
	if dialogue_queue.is_empty():
		dialogue_box.visible = false
		is_showing_dialogue = false
		if not intro_dialogue_shown:
			intro_dialogue_shown = true
			set_interactive_enabled(true)
		return
	
	var line = dialogue_queue.pop_front()
	
	speaker_name.text = line.get("speaker", "")
	speaker_name.visible = speaker_name.text != ""
	
	current_full_text = line.get("text", "")
	dialogue_text.text = ""
	dialogue_text.visible_characters = 0
	
	start_typing()

func start_typing():
	is_typing = true
	if tween and tween.is_running():
		tween.kill()
	
	tween = create_tween()
	tween.tween_method(_update_text, 0, current_full_text.length(), current_full_text.length() * typing_speed)
	tween.finished.connect(_on_typing_finished)

func _update_text(chars: int):
	dialogue_text.visible_characters = chars
	dialogue_text.text = current_full_text

func _on_typing_finished():
	is_typing = false
	dialogue_text.visible_characters = -1

func skip_typing():
	if tween and tween.is_running():
		tween.kill()
	dialogue_text.text = current_full_text
	dialogue_text.visible_characters = -1
	is_typing = false

# ====================== INPUT ======================
func _input(event):
	if not is_showing_dialogue:
		return
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_typing:
			skip_typing()
		else:
			show_next_dialogue()

# ====================== BUTTONS ======================
func _on_skip_btn_pressed() -> void:
	if is_typing:
		skip_typing()
	dialogue_queue.clear()
	dialogue_box.visible = false
	is_showing_dialogue = false
	is_typing = false
	intro_dialogue_shown = true
	set_interactive_enabled(true)

func _on_hide_btn_pressed() -> void:
	is_hidden = not is_hidden
	dialogue_box.visible = not is_hidden

# Optional: Click anywhere to show dialogue again when hidden
func _unhandled_input(event):
	if is_hidden and event is InputEventMouseButton and event.pressed:
		is_hidden = false
		dialogue_box.visible = true
