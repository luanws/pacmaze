extends Node
## Global run state: which level is being played, accumulated score and the level being edited.

enum Mode { CAMPAIGN, CUSTOM, EDITOR_TEST }

const CAMPAIGN_DIR := "res://levels/campaign"
const USER_LEVELS_DIR := "user://levels"
const GAME_SCENE := "res://scenes/game.tscn"
const GAME_OVER_SCENE := "res://scenes/game_over.tscn"
const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"
const LEVEL_SELECT_SCENE := "res://scenes/level_select.tscn"
const EDITOR_SCENE := "res://scenes/level_editor.tscn"
const PROGRESS_FILE := "user://progress.cfg"

var mode := Mode.CAMPAIGN
var score := 0
var current_level := 1 ## 1-based index into the campaign.
var custom_path := ""
## Kept here so the editor gets its level back after a test run.
var editor_data: LevelData
var editor_path := ""
var campaign_files := PackedStringArray()
## Highest campaign level the player may start (1-based); saved between sessions.
var unlocked_level := 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(USER_LEVELS_DIR)
	campaign_files = _list_levels(CAMPAIGN_DIR)
	_load_progress()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		toggle_fullscreen()
		get_viewport().set_input_as_handled()


func is_fullscreen() -> bool:
	return DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN


func toggle_fullscreen() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if is_fullscreen() else DisplayServer.WINDOW_MODE_FULLSCREEN)


## Keeps a fullscreen toggle button's text in sync, including when the browser leaves fullscreen on Esc.
func bind_fullscreen_button(button: Button) -> void:
	var refresh := func() -> void: button.text = "Sair da tela cheia" if is_fullscreen() else "Tela cheia"
	refresh.call()
	button.pressed.connect(toggle_fullscreen)
	button.get_tree().root.size_changed.connect(refresh)
	button.tree_exiting.connect(func() -> void: button.get_tree().root.size_changed.disconnect(refresh))


func campaign_size() -> int:
	return campaign_files.size()


func is_level_unlocked(level: int) -> bool:
	return level <= unlocked_level


func list_user_levels() -> PackedStringArray:
	return _list_levels(USER_LEVELS_DIR)


func current_level_data() -> LevelData:
	match mode:
		Mode.CAMPAIGN:
			return LevelData.load_file(campaign_files[current_level - 1])
		Mode.CUSTOM:
			return LevelData.load_file(custom_path)
		_:
			return editor_data


func level_title(data: LevelData) -> String:
	match mode:
		Mode.CAMPAIGN:
			return "Fase %d/%d" % [current_level, campaign_size()]
		Mode.CUSTOM:
			return data.name
		_:
			return "Teste: %s" % data.name


func start_run(level := 1) -> void:
	mode = Mode.CAMPAIGN
	score = 0
	current_level = level
	_change_scene(GAME_SCENE)


func play_custom(path: String) -> void:
	mode = Mode.CUSTOM
	score = 0
	custom_path = path
	_change_scene(GAME_SCENE)


func test_level(data: LevelData, path: String) -> void:
	mode = Mode.EDITOR_TEST
	editor_data = data
	editor_path = path
	_change_scene(GAME_SCENE)


func restart_level() -> void:
	_change_scene(GAME_SCENE)


## `focus` is the screen point the transition to the next campaign level closes on.
func complete_level(level_score: int, focus: Variant = null) -> void:
	match mode:
		Mode.CAMPAIGN:
			score += level_score
			_unlock_level(current_level + 1)
			if current_level < campaign_size():
				current_level += 1
				Transition.change_scene(GAME_SCENE, "Fase %d" % current_level, focus)
			else:
				_change_scene(GAME_OVER_SCENE)
		Mode.CUSTOM:
			score = level_score
			_change_scene(GAME_OVER_SCENE)
		Mode.EDITOR_TEST:
			open_editor()


## Leaves the level being played, back to wherever it was started from.
func leave_level() -> void:
	if mode == Mode.EDITOR_TEST:
		open_editor()
	else:
		go_to_main_menu()


func open_editor(path := "") -> void:
	if not path.is_empty():
		var data := LevelData.load_file(path)
		if data:
			editor_data = data
			editor_path = path
	_change_scene(EDITOR_SCENE)


func go_to_main_menu() -> void:
	_change_scene(MAIN_MENU_SCENE)


func go_to_level_select() -> void:
	_change_scene(LEVEL_SELECT_SCENE)


func _unlock_level(level: int) -> void:
	level = mini(level, campaign_size())
	if level <= unlocked_level:
		return
	unlocked_level = level
	var config := ConfigFile.new()
	config.set_value("campaign", "unlocked_level", unlocked_level)
	config.save(PROGRESS_FILE)


func _load_progress() -> void:
	var config := ConfigFile.new()
	if config.load(PROGRESS_FILE) == OK:
		unlocked_level = clampi(int(config.get_value("campaign", "unlocked_level", 1)), 1, maxi(campaign_size(), 1))


func _list_levels(dir: String) -> PackedStringArray:
	var paths := PackedStringArray()
	for file in DirAccess.get_files_at(dir):
		if file.get_extension() == "json":
			paths.append(dir.path_join(file))
	paths.sort()
	return paths


func _change_scene(path: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(path)
