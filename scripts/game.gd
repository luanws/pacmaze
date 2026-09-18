extends Node2D
## Loads the current level, keeps the HUD up to date and handles level completion.

const HUD_HEIGHT := 56.0
const COMPLETE_DELAY := 1.5

var level: Level

@onready var level_container: Node2D = $LevelContainer
@onready var camera: Camera2D = $Camera2D
@onready var level_label: Label = %LevelLabel
@onready var moves_label: Label = %MovesLabel
@onready var time_label: Label = %TimeLabel
@onready var score_label: Label = %ScoreLabel
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
	level = data.instantiate()
	level_container.add_child(level)
	level.completed.connect(_on_level_completed)
	level.player.moved.connect(instructions.hide)
	level_label.text = GameState.level_title(data)
	instructions_label.text = level.instructions
	instructions.visible = not level.instructions.is_empty()
	complete_panel.hide()
	get_viewport().size_changed.connect(_fit_camera)
	_fit_camera()


func _process(_delta: float) -> void:
	moves_label.text = "Movimentos: %d" % level.move_count
	time_label.text = "Tempo: %ds" % int(level.elapsed)
	score_label.text = "Pontuação: %d" % GameState.score


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and level and not level.finished:
		pause_menu.open()
		get_viewport().set_input_as_handled()


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
	await get_tree().create_timer(COMPLETE_DELAY).timeout
	GameState.complete_level(gained)
