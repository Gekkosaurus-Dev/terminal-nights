@abstract
class_name Camera
extends Node2D

@export var rooms: Array[Array]
@export var jumpscares: AnimatedSprite2D

var current_feed: int = 0
var all_feeds: Array[Sprite2D]
var all_buttons: Array[TextureButton]

@onready var animtree: AnimationTree = $AnimationTree

func _ready() -> void:
	_initialize_buttons()
	_initialize_feeds()

func _initialize_buttons() -> void:
	# Adds the camera feeds and buttons into arrays so they can be synced up in 'func _on_click_cam'
	all_feeds.append_array($CamRooms.get_children())
	all_buttons.append_array($CamButtons.get_children())

func _initialize_feeds() -> void:
	# Gets the camera feed id's, then sets them up with the right frame
	update_feeds(type_convert(range(all_feeds.size()), TYPE_PACKED_INT32_ARRAY))

func set_feed(_feed_to_update: int) -> void:
	pass

func update_feeds(feeds_to_update: Array[int]) -> void:
	for i in feeds_to_update:
		set_feed(i)
		if current_feed == i:
			play_static()

# This function gets called when one of the cam map buttons get pressed
func switch_feed(new_feed: int) -> void:
	# This handles camera switching, but blocks it when clicking the same camera button
	if current_feed != new_feed:
		play_static()
		
		all_feeds[current_feed].visible = false
		all_buttons[current_feed].disabled = false
		
		all_feeds[new_feed].visible = true
		all_buttons[new_feed].disabled = true
		
		current_feed = new_feed
		check_whos_on_camera(new_feed)
		

func check_whos_on_camera(new_feed):
	var room_state: Array = rooms[new_feed]
	var room_feed: Sprite2D = all_feeds[new_feed]
	if room_state[0] == 1: # neko
		print("BOO NEKO IS HERE!")
	elif room_state[2] == 1: # bandit
		print("bandit on cams")
		pass
	elif room_state[4] == 1: # construct
		# if its cam 5 + construct is there, trigger the run
		if (new_feed == 4):
			print("construct should run here")
			play_construct_run(room_feed)
	
func play_construct_run(room_feed):
	for frame in range(4,12):
		room_feed.frame = frame
		await get_tree().create_timer(0.1).timeout
	room_feed.frame = 0
	print("construct kills you")
	jumpscares.play_jumpscare("construct")
	
func play_static() -> void:
	animtree["parameters/OneShot/request"] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE
	animtree.advance(0) # this fixes a problem where the static plays 1 frame too late
