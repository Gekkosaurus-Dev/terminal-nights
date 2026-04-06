extends Node2D

@export var office: Node2D

signal tablet_free

func _on_area_2d_input_event(_viewport, event, _shape_idx) -> void:
	# This is just a test function for the Button Example
	if event.is_action_pressed("click_left") and office.can_move:
		print('Button Pressed !')

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
