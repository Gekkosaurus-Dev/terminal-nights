extends AI

enum {ROOM_01, ROOM_02, ROOM_03, ROOM_04, ROOM_05, ROOM_06, ROOM_07, ROOM_08}

func move_options() -> void:
	match step:
		0:
			move_to(ROOM_03)
		1:
			move_to(ROOM_07)
		2:
			move_to(ROOM_08)
		3:
			# Returns to start position
			move_to(ROOM_01,State.PRESENT,-step)
