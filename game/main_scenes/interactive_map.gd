extends Control

@onready var background: TextureRect = $Background
@onready var dialogue_box: Panel = $DialogueBox
@onready var speaker_name: Label = $DialogueBox/SpeakerName
@onready var dialogue_text: RichTextLabel = $DialogueBox/DialogueText
@onready var choice_container: VBoxContainer = $DialogueBox/ChoiceContainer
@onready var interactive_areas = $InteractiveAreas.get_children()

@export var button_theme: Theme
@export var typing_speed: float = 0.03

var bedroom_data: Dictionary = {}
var dialogue_queue: Array = []
var current_text: String = ""

var is_active: bool = false
var is_typing: bool = false
var is_hidden: bool = false
var waiting_for_choice: bool = false
var input_locked: bool = false  # RESTORED: Prevents input during critical transitions

var tween: Tween

# ====================== INITIALIZATION ======================
func _ready():
	dialogue_box.visible = false
	choice_container.visible = false
	load_dialogue()
	setup_interactive_areas()
	show_intro()

func load_dialogue():
	var file = FileAccess.open("res://dialogues/interactive_dialogues.json", FileAccess.READ)
	if not file:
		push_error("Dialogue JSON not found")
		return
	
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK:
		bedroom_data = json.data
	else:
		push_error("JSON Parse Error")

# ====================== INTERACTIVE AREAS ======================
func setup_interactive_areas():
	for area in interactive_areas:
		if not area is Area2D: 
			continue
		
		area.mouse_entered.connect(func(): Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND))
		area.mouse_exited.connect(func(): Input.set_default_cursor_shape(Input.CURSOR_ARROW))
		area.input_event.connect(_on_area_clicked.bind(area))
	
	set_interactive_enabled(false)

func set_interactive_enabled(enabled: bool):
	for area in interactive_areas:
		if area is Area2D:
			area.monitoring = enabled
			area.monitorable = enabled

func _on_area_clicked(_viewport, event, _shape_idx, area):
	if is_active or waiting_for_choice or is_hidden or input_locked:
		return
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var id = area.get_meta("id", "")
		if id:
			show_dialogue(id)

# ====================== DIALOGUE SYSTEM ======================
func show_intro():
	var intro = bedroom_data.get("intro", [])
	if intro.is_empty():
		set_interactive_enabled(true)
		return
	
	start_dialogue(intro)

func show_dialogue(item_id: String):
	var item = bedroom_data.get(item_id, {})
	var dialogues = item.get("dialogues", [])
	
	if dialogues.is_empty():
		return
	
	set_interactive_enabled(false)
	start_dialogue(dialogues)

func start_dialogue(lines: Array):
	dialogue_queue = lines.duplicate()
	is_active = true
	dialogue_box.visible = true
	show_next_line()

func show_next_line():
	if dialogue_queue.is_empty():
		end_dialogue()
		return
	
	var line = dialogue_queue.pop_front()
	
	speaker_name.text = line.get("speaker", "")
	speaker_name.visible = not speaker_name.text.is_empty()
	
	current_text = line.get("text", "")
	dialogue_text.text = ""
	dialogue_text.visible_characters = 0
	
	clear_choices()
	choice_container.visible = false
	waiting_for_choice = false
	
	start_typing()
	
	# Check if this line has choices
	if line.has("choices") and not line.choices.is_empty():
		input_locked = true  # LOCK INPUT while waiting for typing to finish
		# Wait for typing to complete before showing choices
		await tween.finished
		await get_tree().create_timer(0.1).timeout
		show_choices(line.choices)
		input_locked = false  # UNLOCK after choices are shown

# ====================== TYPING SYSTEM ======================
func start_typing():
	is_typing = true
	
	if tween and tween.is_running():
		tween.kill()
	
	tween = create_tween()
	tween.tween_method(_update_text, 0, current_text.length(), current_text.length() * typing_speed)
	tween.finished.connect(_on_typing_finished, CONNECT_ONE_SHOT)

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

# ====================== CHOICE SYSTEM ======================
func show_choices(choices: Array):
	if choices.is_empty():
		return
	
	waiting_for_choice = true
	choice_container.visible = true
	
	for choice in choices:
		var button = Button.new()
		button.text = choice.text
		button.theme = button_theme
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
	
	if next_key == "return":
		end_dialogue()
		return
	
	var next_data = bedroom_data.get(next_key, {})
	var next_dialogues = next_data.get("dialogues", [])
	
	if next_dialogues.is_empty():
		end_dialogue()
	else:
		dialogue_queue = next_dialogues.duplicate()
		show_next_line()

func clear_choices():
	for child in choice_container.get_children():
		child.queue_free()

func end_dialogue():
	dialogue_box.visible = false
	choice_container.visible = false
	is_active = false
	is_typing = false
	waiting_for_choice = false
	input_locked = false  # Reset lock on end
	
	# Handle special ending
	if current_text == "Her journey was only beginning beyond the door.":
		CutsceneState.story_block = "chapter_1"
		await FadeTransition.fade_to_scene("res://main_scenes/cutscenes.tscn")
		return
	
	if not get_meta("intro_shown", false):
		set_meta("intro_shown", true)
		set_interactive_enabled(true)

# ====================== INPUT ======================
func _input(event):
	# Check locks first
	if is_hidden or waiting_for_choice or not is_active or input_locked:
		return
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_typing:
			skip_typing()
		elif not waiting_for_choice:
			show_next_line()

func _unhandled_input(event):
	if is_hidden and event is InputEventMouseButton and event.pressed:
		is_hidden = false
		dialogue_box.visible = true

# ====================== BUTTONS ======================
func _on_hide_btn_pressed():
	is_hidden = not is_hidden
	dialogue_box.visible = not is_hidden

func _on_pause_btn_pressed():
	if PauseManager.is_paused:
		return
	
	PauseManager.toggle_pause()
	var pause_scene = load("res://UI/pause_menu.tscn").instantiate()
	add_child(pause_scene)
