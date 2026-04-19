extends Control

@onready var background: TextureRect = $Background
@onready var bgm_player: AudioStreamPlayer = $BGMPlayer
@onready var dialogue_box: Panel = $DialogueBox
@onready var speaker_name: Label = $DialogueBox/SpeakerName
@onready var dialogue_text: RichTextLabel = $DialogueBox/DialogueText
@onready var choice_container: VBoxContainer = $DialogueBox/ChoiceContainer

@onready var interactive_areas = $InteractiveAreas.get_children()
@export var button_theme: Theme

var bedroom_data: Dictionary = {}
var dialogue_queue: Array = []
var current_full_text: String = ""

var is_showing_dialogue: bool = false
var is_typing: bool = false
var is_hidden: bool = false
var intro_dialogue_shown: bool = false
var waiting_for_choice: bool = false
var input_locked: bool = false

@export var typing_speed: float = 0.03

var tween: Tween

func _ready():
	dialogue_box.visible = false
	choice_container.visible = false
	print("=== INTERACTIVE MAP READY ===")
	
	load_bedroom_dialogue()
	setup_interactive_areas()
	show_intro_dialogue()

func load_bedroom_dialogue():
	var file = FileAccess.open("res://dialogues/interactive_dialogues.json", FileAccess.READ)
	if not file:
		push_error("Bedroom dialogue JSON not found")
		return
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK:
		bedroom_data = json.data
		print("✅ JSON loaded successfully!")
	else:
		push_error("JSON Parse Error")

func setup_interactive_areas():
	for area in interactive_areas:
		if not area is Area2D: continue
		area.mouse_entered.connect(func(): Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND))
		area.mouse_exited.connect(func(): Input.set_default_cursor_shape(Input.CURSOR_ARROW))
		area.input_event.connect(_on_area_clicked.bind(area))
	
	set_interactive_enabled(false)

func set_interactive_enabled(enabled: bool):
	for area in interactive_areas:
		if area is Area2D:
			area.monitoring = enabled
			area.monitorable = enabled

# ====================== AREA CLICKED ======================
func _on_area_clicked(_viewport, event, _shape_idx, area):
	if is_showing_dialogue or waiting_for_choice or is_hidden:
		return
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var id = area.get_meta("id", "")
		if id != "":
			show_item_dialogue(id)

# ====================== DIALOGUE ======================
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
		end_dialogue()
		return
	
	var line = dialogue_queue.pop_front()
	
	speaker_name.text = line.get("speaker", "")
	speaker_name.visible = speaker_name.text != ""
	
	current_full_text = line.get("text", "")
	dialogue_text.text = ""
	dialogue_text.visible_characters = 0
	
	clear_choices()
	choice_container.visible = false  # Make sure it's hidden initially
	waiting_for_choice = false
	
	# Store choices for this line
	var has_choices = line.has("choices") and line.choices.size() > 0
	
	# Start typing
	start_typing()
	
	if has_choices:
		input_locked = true  # 🔒 LOCK INPUT
		
		await tween.finished
		await get_tree().create_timer(0.2).timeout
		
		show_choices(line.choices)
		input_locked = false  # 🔓 UNLOCK AFTER CHOICES SHOW

func start_typing():
	is_typing = true
	if tween and tween.is_running():
		tween.kill()
	
	tween = create_tween()
	tween.tween_method(_update_text, 0, current_full_text.length(), current_full_text.length() * typing_speed)
	# Connect to finished signal properly
	tween.finished.connect(_on_typing_finished, CONNECT_ONE_SHOT)

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

# ====================== CHOICES ======================
func show_choices(choices: Array):
	if choices.is_empty():
		return
	
	waiting_for_choice = true
	choice_container.visible = true
	
	for choice in choices:
		var button = Button.new()
		button.text = choice.text
		button.theme = button_theme
		
			   # Add padding to make the button larger
		button.add_theme_constant_override("padding_left", 20)
		button.add_theme_constant_override("padding_right", 20)
		button.add_theme_constant_override("padding_top", 12)
		button.add_theme_constant_override("padding_bottom", 12)
		
		button.custom_minimum_size = Vector2(300, 70)
		
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_choice_selected.bind(choice.next))
		choice_container.add_child(button)


func _on_choice_selected(next_key: String):
	waiting_for_choice = false
	clear_choices()
	choice_container.visible = false
	
	print("Selected choice leading to: ", next_key)  # Debug
	
	if next_key == "return":
		end_dialogue()
		return
	
	if bedroom_data.has(next_key):
		# Get the next dialogue data
		var next_data = bedroom_data[next_key]
		var next_dialogues = next_data.get("dialogues", [])
		
		if next_dialogues.is_empty():
			end_dialogue()
			return
		
		# Add all dialogues to queue
		dialogue_queue = next_dialogues.duplicate()
		print("Added ", dialogue_queue.size(), " dialogues to queue")  # Debug
		show_next_dialogue()
	else:
		print("ERROR: Next key not found: ", next_key)
		end_dialogue()

func clear_choices():
	for child in choice_container.get_children():
		child.queue_free()

func end_dialogue():
	dialogue_box.visible = false
	choice_container.visible = false
	is_showing_dialogue = false
	is_typing = false
	waiting_for_choice = false
	
	if current_full_text == "[DEMO ENDS HERE]":
		await FadeTransition.fade_to_scene("res://UI/end_transition.tscn")
		return
		
	if not intro_dialogue_shown:
		intro_dialogue_shown = true
		set_interactive_enabled(true)

# ====================== INPUT ======================
func _input(event):
	if is_hidden or waiting_for_choice or input_locked:
		return
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_showing_dialogue:
			if is_typing:
				skip_typing()
				return
			elif not waiting_for_choice:  # Only advance if not waiting for choice
				show_next_dialogue()

# ====================== BUTTONS ======================
#func _on_skip_btn_pressed():
#	dialogue_queue.clear()
#	clear_choices()
#	end_dialogue()

func _on_hide_btn_pressed():
	is_hidden = not is_hidden
	dialogue_box.visible = not is_hidden

func _unhandled_input(event):
	if is_hidden and event is InputEventMouseButton and event.pressed:
		is_hidden = false
		dialogue_box.visible = true


func _on_pause_btn_pressed() -> void:
	if PauseManager.is_paused:
		return
	
	PauseManager.toggle_pause()
	
	var pause_scene = load("res://UI/pause_menu.tscn").instantiate()
	add_child(pause_scene)
