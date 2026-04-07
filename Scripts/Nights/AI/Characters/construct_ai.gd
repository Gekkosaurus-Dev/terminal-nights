extends AI

enum {ROOM_01, ROOM_02, ROOM_03, ROOM_04, ROOM_05, ROOM_06, ROOM_07, ROOM_08}
enum Constr_states {ACTIVE, LOCKED, COOLDOWN, PHASE_4}

var state = Constr_states.ACTIVE

func move_options() -> void:
	print("movement opportunity check")
	# if construct state is not locked or on cooldown it can move
	if allowed_to_move():
		match step:
			0:
				move_to(ROOM_04,State.ALT_1) #phase 2
			1:
				move_to(ROOM_04,State.ALT_2) #phase 3
			2:
				move_to(ROOM_05,State.PRESENT) #phase 4
				state = Constr_states.PHASE_4
				print("construct left for the hallway chat")
				#trigger attack after opening left hall cam OR after 25s passed
			3:
				move_to(ROOM_04,State.PRESENT,-step)
				#go back to start

# TODO: after hitting door, take x% power and return to pirates cove in phase 1 or 2

func allowed_to_move():
	# when the cams are on, puts construct into a locked state
	# when in locked state, auto fail all movement opportunities,
	if $"../../TabletElements".is_tablet_up:
		state = Constr_states.LOCKED
		$ConstructLockCooldownTimer.stop() # stops the lock cooldown if it's active
		print("locked construct")
		return false
	# after cams go off, remain locked for random 0.83-16.6s
	else:
		if (state == Constr_states.LOCKED):
			state = Constr_states.COOLDOWN
			$ConstructLockCooldownTimer.wait_time = randf_range(0.83,16.6)
			$ConstructLockCooldownTimer.start()
			print("put construct into cooldown")
			return false
		elif (state == Constr_states.COOLDOWN):
			print("cant move. in cooldown")
			return false
	print("CONTSTRUCT IS FREEEEEEE")
	return true
	
func _on_lock_cooldown_timeout():
	print("cooldown over lmao")
	state = Constr_states.ACTIVE
	$ConstructTimer.start(0)
