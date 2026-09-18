class_name PauseMenu
extends CanvasLayer

@onready var resume_button: Button = %ResumeButton
@onready var restart_button: Button = %RestartButton
@onready var menu_button: Button = %MenuButton


func _ready() -> void:
	hide()
	resume_button.pressed.connect(close)
	restart_button.pressed.connect(GameState.restart_level)
	menu_button.pressed.connect(GameState.leave_level)
	if GameState.mode == GameState.Mode.EDITOR_TEST:
		menu_button.text = "Voltar ao editor"


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	show()
	get_tree().paused = true
	resume_button.grab_focus()


func close() -> void:
	hide()
	get_tree().paused = false
