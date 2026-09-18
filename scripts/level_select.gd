extends Control

@onready var grid: GridContainer = %LevelGrid
@onready var custom_list: VBoxContainer = %CustomList
@onready var back_button: Button = %BackButton


func _ready() -> void:
	for level in range(1, GameState.campaign_size() + 1):
		var button := Button.new()
		button.text = str(level)
		button.custom_minimum_size = Vector2(88, 88)
		button.pressed.connect(GameState.start_run.bind(level))
		grid.add_child(button)
	_fill_custom_levels()
	back_button.pressed.connect(GameState.go_to_main_menu)
	if grid.get_child_count() > 0:
		grid.get_child(0).grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		GameState.go_to_main_menu()


func _fill_custom_levels() -> void:
	var paths := GameState.list_user_levels()
	if paths.is_empty():
		var empty := Label.new()
		empty.text = "Nenhuma fase criada ainda. Use o editor de fases no menu principal."
		empty.modulate = Color(0.6, 0.6, 0.6)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD
		custom_list.add_child(empty)
		return
	for path in paths:
		var data := LevelData.load_file(path)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var title := Label.new()
		title.text = data.name if data else "%s (arquivo inválido)" % path.get_file()
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		title.tooltip_text = path.get_file()
		title.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(title)
		var play := Button.new()
		play.text = "Jogar"
		play.disabled = data == null
		play.pressed.connect(GameState.play_custom.bind(path))
		row.add_child(play)
		var edit := Button.new()
		edit.text = "Editar"
		edit.disabled = data == null
		edit.pressed.connect(GameState.open_editor.bind(path))
		row.add_child(edit)
		custom_list.add_child(row)
