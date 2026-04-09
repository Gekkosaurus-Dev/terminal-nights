extends Node2D

@export var office: Node2D

signal tablet_free

var left_door_open = true
var right_door_open = true
var vent_open = true


func _on_tablet_elements_darken_office():
	print('darken office pls')
	var tween = create_tween()
	tween.finished.connect(_on_room_brightness_finished)
	tween.tween_property(office, "modulate", Color(0.021, 0.021, 0.021, 1.0), 0.2)

func _on_tablet_elements_brighten_office():
	print('brightwen office pls')
	var tween = create_tween()
	tween.finished.connect(_on_room_brightness_finished)
	tween.tween_property(office, "modulate", Color(1.0, 1.0, 1.0, 1.0), 1.0)

func _on_room_brightness_finished():
	tablet_free.emit()

func _on_left_button_pressed(viewport, event, shape_idx):
	if event.is_action_pressed("click_left") and office.can_move:
		print("left button pressed")
		if left_door_open:
			$Office/Left_Door.play("close")
			left_door_open = false
		else:
			$Office/Left_Door.play("open")
			left_door_open = true

func _on_right_button_pressed(viewport, event, shape_idx):
	if event.is_action_pressed("click_left") and office.can_move:
		print("right button pressed")
		if right_door_open:
			$Office/Right_Door.play("close")
			right_door_open = false
		else:
			$Office/Right_Door.play("open")
			right_door_open = true
