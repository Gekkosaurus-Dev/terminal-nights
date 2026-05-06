extends AnimatedSprite2D

@export_enum("Neko", "Hacker", "Bandit", "Idol", "Construct", "Keeper") var character: int

func play_jumpscare(character):
	visible = true
	play(character)
	
	#hides all the UI so it doesnt render above the jumpscare
	$"../OfficeElements".visible = false
	$"../TabletElements".visible = false
	$"../CameraElements".visible = false
	
	#stop all AI movement 
