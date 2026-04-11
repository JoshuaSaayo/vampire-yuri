extends Control

@onready var background: TextureRect = $Background
@onready var dialogue_box: Panel = $DialogueBox
@onready var speaker_name: Label = $DialogueBox/SpeakerName
@onready var dialogue_text: RichTextLabel = $DialogueBox/DialogueText
@onready var bgm_player: AudioStreamPlayer = $BGMPlayer

# Interactive areas
@onready var diary_area: Area2D = $InteractiveAreas/DiaryArea
@onready var wardrobe_area: Area2D = $InteractiveAreas/WardrobeArea
@onready var door_area: Area2D = $InteractiveAreas/DoorArea

# Dialogue data
var intro_dialogue_shown: bool = false
var current_interaction: String = ""
var is_showing_dialogue: bool = false
var dialogue_queue: Array = []

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
		# No intro, enable interactions immediately
		set_interactive_enabled(true)
		return
	
	dialogue_queue = intro_lines.duplicate()
	show_next_dialogue()

func show_next_dialogue():
	if dialogue_queue.is_empty():
		# Finished all dialogues
		dialogue_box.visible = false
		is_showing_dialogue = false
		
		if not intro_dialogue_shown:
			# Intro finished, enable interactions
			intro_dialogue_shown = true
			set_interactive_enabled(true)
		return
	
	is_showing_dialogue = true
	dialogue_box.visible = true
	
	var line = dialogue_queue.pop_front()
	var text = line.get("text", "")
	
	# Clear and type out text
	dialogue_text.text = ""
	dialogue_text.visible_characters = 0
	
	if tween:
		tween.kill()
	
	tween = create_tween()
	tween.tween_method(_update_dialogue_text, 0, text.length(), text.length() * typing_speed)
	await tween.finished
	
	dialogue_text.visible_characters = -1

func _update_dialogue_text(chars: int):
	dialogue_text.visible_characters = chars

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
	
	# Disable interactions during dialogue
	set_interactive_enabled(false)
	
	# Add all dialogues to queue
	dialogue_queue = dialogues.duplicate()
	
	# Show first dialogue
	show_next_dialogue()
	
	# Wait for dialogue to finish, then re-enable interactions
	await dialogue_finished()
	set_interactive_enabled(true)

func dialogue_finished():
	# Wait until dialogue queue is empty
	while not dialogue_queue.is_empty() or is_showing_dialogue:
		await get_tree().process_frame

func _input(event):
	# Click anywhere to advance dialogue
	if is_showing_dialogue and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if tween and tween.is_running():
			# Skip typing
			tween.kill()
			dialogue_text.visible_characters = -1
		else:
			# Advance to next line
			show_next_dialogue()
