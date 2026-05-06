extends Control

@export var game_manager: Node


func _ready() -> void:
	pass

func _on_exit_pressed():
	get_tree().quit()

func _on_play_pressed():
	game_manager.play()
	self.queue_free()
