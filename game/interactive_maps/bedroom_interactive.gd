extends Control

@onready var background: TextureRect = $Background
@onready var bgm_player: AudioStreamPlayer = $BGMPlayer
@onready var dialogue_box: Panel = $DialogueBox
@onready var speaker_name: Label = $DialogueBox/SpeakerName
@onready var dialogue_text: RichTextLabel = $DialogueBox/DialogueText

# Interactive areas
@onready var diary_area: Area2D = $InteractiveAreas/DiaryArea
@onready var wardrobe_area: Area2D = $InteractiveAreas/WardrobeArea
@onready var door_area: Area2D = $InteractiveAreas/DoorArea

# Dialogue data
var intro_dialogue_shown: bool = false
var is_showing_dialogue: bool = false
var is_typing: bool = false
var dialogue_queue: Array = []
var current_full_text: String = ""

# Dialogue JSON data
var bedroom_data: Dictionary = {}

@export var typing_speed: float = 0.03

var tween: Tween

func _ready():
	dialogue_box.visible = false
	load_bedroom_dialogue()
	setup_interactive_areas()
	
	# Show intro dialogue first
	show_intro_dialogue()

func load_bedroom_dialogue():
	var file = FileAccess.open("res://dialogues/bedroom_dialogues.json", FileAccess.READ)
	if not file:
		push_error("Bedroom dialogue JSON not found")
		return
	
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK:
		bedroom_data = json.data
	else:
		push_error("JSON Parse Error: " + json.get_error_message())

func setup_interactive_areas():
	# Connect mouse enter/exit for cursor change
	diary_area.mouse_entered.connect(func(): Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND))
	diary_area.mouse_exited.connect(func(): Input.set_default_cursor_shape(Input.CURSOR_ARROW))
	wardrobe_area.mouse_entered.connect(func(): Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND))
	wardrobe_area.mouse_exited.connect(func(): Input.set_default_cursor_shape(Input.CURSOR_ARROW))
	door_area.mouse_entered.connect(func(): Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND))
	door_area.mouse_exited.connect(func(): Input.set_default_cursor_shape(Input.CURSOR_ARROW))
	
	# Connect click events
	diary_area.input_event.connect(_on_diary_click)
	wardrobe_area.input_event.connect(_on_wardrobe_click)
	door_area.input_event.connect(_on_door_click)
	
	# Disable interactions until intro is done
	set_interactive_enabled(false)

func set_interactive_enabled(enabled: bool):
	diary_area.monitoring = enabled
	diary_area.monitorable = enabled
	wardrobe_area.monitoring = enabled
	wardrobe_area.monitorable = enabled
	door_area.monitoring = enabled
	door_area.monitorable = enabled

func show_intro_dialogue():
	var intro_lines = bedroom_data.get("intro", [])
	if intro_lines.is_empty():
		set_interactive_enabled(true)
		return
	
	dialogue_queue = intro_lines.duplicate()
	show_next_dialogue()

func show_next_dialogue():
	if dialogue_queue.is_empty():
		dialogue_box.visible = false
		is_showing_dialogue = false
		
		if not intro_dialogue_shown:
			intro_dialogue_shown = true
			set_interactive_enabled(true)
		return
	
	is_showing_dialogue = true
	dialogue_box.visible = true
	
	var line = dialogue_queue.pop_front()
	var speaker = line.get("speaker", "")
	current_full_text = line.get("text", "")
	
	# Set speaker name
	speaker_name.text = speaker
	speaker_name.visible = speaker != ""
	
	# Clear and start typing
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

func _on_diary_click(viewport: Node, event: InputEvent, shape_idx: int):
	if not is_showing_dialogue and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		show_item_dialogue("diary")

func _on_wardrobe_click(viewport: Node, event: InputEvent, shape_idx: int):
	if not is_showing_dialogue and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		show_item_dialogue("wardrobe")

func _on_door_click(viewport: Node, event: InputEvent, shape_idx: int):
	if not is_showing_dialogue and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		show_item_dialogue("door")

func show_item_dialogue(item: String):
	var item_data = bedroom_data.get(item, {})
	var dialogues = item_data.get("dialogues", [])
	
	if dialogues.is_empty():
		return
	
	set_interactive_enabled(false)
	dialogue_queue = dialogues.duplicate()
	show_next_dialogue()

func _input(event):
	if not is_showing_dialogue:
		return
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_typing:
			skip_typing()
		else:
			show_next_dialogue()
