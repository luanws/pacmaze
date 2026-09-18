extends Node
## Global run state: current level and accumulated score.

const LEVEL_COUNT := 8
const GAME_SCENE := "res://scenes/game.tscn"
const GAME_OVER_SCENE := "res://scenes/game_over.tscn"
const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"
const LEVEL_SELECT_SCENE := "res://scenes/level_select.tscn"

var score := 0
var current_level := 1


func level_scene_path(level: int) -> String:
	return "res://scenes/levels/level_%d.tscn" % level


func start_run(level := 1) -> void:
	score = 0
	current_level = level
	_change_scene(GAME_SCENE)


func restart_level() -> void:
	_change_scene(GAME_SCENE)


func complete_level(level_score: int) -> void:
	score += level_score
	if current_level < LEVEL_COUNT:
		current_level += 1
		_change_scene(GAME_SCENE)
	else:
		_change_scene(GAME_OVER_SCENE)


func go_to_main_menu() -> void:
	_change_scene(MAIN_MENU_SCENE)


func go_to_level_select() -> void:
	_change_scene(LEVEL_SELECT_SCENE)


func _change_scene(path: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(path)
