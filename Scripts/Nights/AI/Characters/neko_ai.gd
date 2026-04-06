extends AI

enum {ROOM_01, ROOM_02, ROOM_03, ROOM_04, ROOM_05, ROOM_06, ROOM_07, ROOM_08}

func move_options() -> void:
	roll_move()

func roll_move():
	match randi_range(0,7):
		0:
			if not _is_room_empty(ROOM_01):
				move_to(ROOM_01)
			else:
				roll_move()
		1:
			if not _is_room_empty(ROOM_02):
				move_to(ROOM_02)
			else:
				roll_move()
		2:
			if not _is_room_empty(ROOM_03):
				move_to(ROOM_03)
			else:
				roll_move()
		3:
			if not _is_room_empty(ROOM_04):
				move_to(ROOM_04)
			else:
				roll_move()
		4:
			if not _is_room_empty(ROOM_05):
				move_to(ROOM_05)
			else:
				roll_move()
		5:
			if not _is_room_empty(ROOM_06):
				move_to(ROOM_06)
			else:
				roll_move()
		6:
			if not _is_room_empty(ROOM_07):
				move_to(ROOM_07)
			else:
				roll_move()
		7:
			if not _is_room_empty(ROOM_08):
				move_to(ROOM_08)
			else:
				roll_move()
