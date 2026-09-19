extends Control

@onready var continue_button: Button = %ContinueButton
@onready var new_game_button: Button = %NewGameButton
@onready var select_button: Button = %SelectButton
@onready var editor_button: Button = %EditorButton
@onready var instructions_button: Button = %InstructionsButton
@onready var fullscreen_button: Button = %FullscreenButton
@onready var quit_button: Button = %QuitButton
@onready var instructions_dialog: AcceptDialog = %InstructionsDialog


func _ready() -> void:
	Sfx.play_song(0)
	# Continue picks up at the furthest unlocked level; hidden until there is progress to resume.
	continue_button.pressed.connect(func() -> void: GameState.start_run(GameState.unlocked_level))
	continue_button.visible = GameState.unlocked_level > 1
	new_game_button.pressed.connect(GameState.start_run)
	select_button.pressed.connect(GameState.go_to_level_select)
	editor_button.pressed.connect(GameState.open_editor)
	instructions_button.pressed.connect(instructions_dialog.popup_centered)
	# The dialog is its own window; give the menu its focus back so a gamepad can keep navigating.
	instructions_dialog.visibility_changed.connect(func() -> void:
		if not instructions_dialog.visible:
			instructions_button.grab_focus())
	GameState.bind_fullscreen_button(fullscreen_button)
	quit_button.pressed.connect(get_tree().quit)
	quit_button.visible = not OS.has_feature("web")
	(continue_button if continue_button.visible else new_game_button).grab_focus()
