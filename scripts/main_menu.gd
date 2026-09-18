extends Control

@onready var play_button: Button = %PlayButton
@onready var select_button: Button = %SelectButton
@onready var editor_button: Button = %EditorButton
@onready var quit_button: Button = %QuitButton


func _ready() -> void:
	play_button.pressed.connect(GameState.start_run)
	select_button.pressed.connect(GameState.go_to_level_select)
	editor_button.pressed.connect(GameState.open_editor)
	quit_button.pressed.connect(get_tree().quit)
	quit_button.visible = not OS.has_feature("web")
	play_button.grab_focus()
