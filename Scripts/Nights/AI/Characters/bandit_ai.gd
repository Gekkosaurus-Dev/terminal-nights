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
			# outside door
			print("BANDIT IS AT DA DOOR")
			move_to(ROOM_08,State.ABSENT)
			#uhhhh do something so that hes present in the office when you use da light
		4:
			# attempt to get into office
			if is_door_open("right"): #if the door is closed
				print("bandit jumpscare!!!!")
				jumpscares.play_jumpscare("bandit")
			else:
				print("thunk!")
				# Returns to start position
				# not sure if i'll do this, but in fnaf 1 he goes back to room 7, not 1
				move_to(ROOM_01,State.PRESENT)
