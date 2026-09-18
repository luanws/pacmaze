extends Control

@onready var score_label: Label = %ScoreLabel
@onready var continue_button: Button = %ContinueButton


func _ready() -> void:
	score_label.text = "Pontuação: %d" % GameState.score
	continue_button.pressed.connect(GameState.go_to_main_menu)
	continue_button.grab_focus()
