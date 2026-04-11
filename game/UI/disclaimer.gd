extends Control

@onready var transition_rect: ColorRect = $TransitionRect
@onready var label: Label = $DisclaimerPanel/Label
@onready var proceed_btn: Button = $Proceed

@export var full_text: String = "This title features mature themes, nudity, and sexual content. Players must be 18+ to access or download this game. All characters are fictional adults and no minors are depicted."
@export var typing_speed: float = 0.02  # seconds per character

var char_index := 0
var typing_timer := 0.0
var finished_typing := false

func _ready():
	label.text = ""
	proceed_btn.disabled = true  # disable button until text finishes
	transition_rect.modulate.a = 0.0
	proceed_btn.pressed.connect(_on_confirm_pressed)

	var tween = create_tween()
	tween.tween_property(transition_rect, "modulate:a", 0.0, 0.6)

func _process(delta):
	if not finished_typing:
		typing_timer += delta
		if typing_timer >= typing_speed:
			typing_timer = 0.0
			if char_index < full_text.length():
				label.text += full_text[char_index]
				char_index += 1
			else:
				finished_typing = true
				proceed_btn.disabled = false

func _on_confirm_pressed():
	_start_white_transition()
	

func _start_white_transition():
	proceed_btn.disabled = true

	var tween = create_tween()
	tween.tween_property(transition_rect, "modulate:a", 1.0, 0.6)
	tween.tween_callback(_go_to_main_menu)

func _go_to_main_menu():
	get_tree().change_scene_to_file("res://UI/menu.tscn")


func _on_exit_pressed() -> void:
	get_tree().quit()
