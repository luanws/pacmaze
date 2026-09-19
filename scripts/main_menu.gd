extends Control

@onready var play_button: Button = %PlayButton
@onready var select_button: Button = %SelectButton
@onready var editor_button: Button = %EditorButton
@onready var instructions_button: Button = %InstructionsButton
@onready var quit_button: Button = %QuitButton
@onready var instructions_dialog: AcceptDialog = %InstructionsDialog


func _ready() -> void:
	Sfx.play_song(0)
	play_button.pressed.connect(GameState.start_run)
	select_button.pressed.connect(GameState.go_to_level_select)
	editor_button.pressed.connect(GameState.open_editor)
	instructions_button.pressed.connect(instructions_dialog.popup_centered)
	quit_button.pressed.connect(get_tree().quit)
	quit_button.visible = not OS.has_feature("web")
	play_button.grab_focus()
