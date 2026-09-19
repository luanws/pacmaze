extends Node2D
## Loads the current level, keeps the HUD up to date and handles level completion.

const HUD_HEIGHT := 56.0
const KEY_TEXTURE := preload("res://assets/sprites/key.png")
const KEY_ICON_SIZE := Vector2(40, 36)
const COMPLETE_DELAY := 1.5

var level: Level

@onready var level_container: Node2D = $LevelContainer
@onready var camera: Camera2D = $Camera2D
@onready var level_label: Label = %LevelLabel
@onready var moves_label: Label = %MovesLabel
@onready var time_label: Label = %TimeLabel
@onready var score_label: Label = %ScoreLabel
@onready var keys_bar: HBoxContainer = %KeysBar
@onready var instructions: Control = %Instructions
@onready var instructions_label: Label = %InstructionsLabel
@onready var complete_panel: Control = %CompletePanel
@onready var complete_label: Label = %CompleteLabel
@onready var pause_menu: PauseMenu = $PauseMenu


func _ready() -> void:
	var data := GameState.current_level_data()
	if data == null:
		push_error("Level could not be loaded")
		GameState.leave_level.call_deferred()
		set_process(false)
		return
	Sfx.play_playlist()
	level = data.instantiate()
	level_container.add_child(level)
	level.completed.connect(_on_level_completed)
	level.player.moved.connect(instructions.hide)
	level.keys_changed.connect(_update_keys_bar)
	_update_keys_bar()
	level_label.text = GameState.level_title(data)
	instructions_label.text = level.instructions
	instructions.visible = not level.instructions.is_empty()
	complete_panel.hide()
	get_viewport().size_changed.connect(_fit_camera)
	_fit_camera()
	Transition.focus_on(_player_screen_position())
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(_delta: float) -> void:
	moves_label.text = "Movimentos: %d" % level.move_count
	time_label.text = "Tempo: %ds" % int(level.elapsed)
	score_label.text = "Pontuação: %d" % GameState.score


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and level and not level.finished:
		pause_menu.open()
		get_viewport().set_input_as_handled()
	elif instructions.visible and event.is_pressed():
		instructions.hide()


## One icon, in the key's color, for each key the pac is carrying.
func _update_keys_bar() -> void:
	for icon in keys_bar.get_children():
		icon.queue_free()
	for key in level.get_held_keys():
		var icon := TextureRect.new()
		icon.texture = KEY_TEXTURE
		icon.modulate = key.modulate
		icon.custom_minimum_size = KEY_ICON_SIZE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		keys_bar.add_child(icon)


func _fit_camera() -> void:
	var bounds := level.get_bounds()
	var view := get_viewport_rect().size - Vector2(0, HUD_HEIGHT)
	var zoom := minf(view.x / bounds.size.x, view.y / bounds.size.y)
	camera.zoom = Vector2(zoom, zoom)
	camera.position = bounds.get_center() - Vector2(0, HUD_HEIGHT * 0.5 / zoom)


func _on_level_completed() -> void:
	var gained := level.compute_score()
	complete_label.text = "Fase concluída!\n+%d pontos" % gained
	complete_panel.show()
	Sfx.play("complete")
	await get_tree().create_timer(COMPLETE_DELAY).timeout
	GameState.complete_level(gained, _player_screen_position())


func _player_screen_position() -> Vector2:
	var offset := level.player.global_position - camera.position
	return offset * camera.zoom + get_viewport_rect().size / 2
