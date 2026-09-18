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

var mode := Mode.CAMPAIGN
var score := 0
var current_level := 1 ## 1-based index into the campaign.
var custom_path := ""
## Kept here so the editor gets its level back after a test run.
var editor_data: LevelData
var editor_path := ""
var campaign_files := PackedStringArray()


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(USER_LEVELS_DIR)
	campaign_files = _list_levels(CAMPAIGN_DIR)


func campaign_size() -> int:
	return campaign_files.size()


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


func complete_level(level_score: int) -> void:
	match mode:
		Mode.CAMPAIGN:
			score += level_score
			if current_level < campaign_size():
				current_level += 1
				_change_scene(GAME_SCENE)
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
