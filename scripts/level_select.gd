extends Control

@onready var grid: GridContainer = %LevelGrid
@onready var back_button: Button = %BackButton


func _ready() -> void:
	for level in range(1, GameState.LEVEL_COUNT + 1):
		var button := Button.new()
		button.text = str(level)
		button.custom_minimum_size = Vector2(96, 96)
		button.pressed.connect(GameState.start_run.bind(level))
		grid.add_child(button)
	back_button.pressed.connect(GameState.go_to_main_menu)
	grid.get_child(0).grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		GameState.go_to_main_menu()
