extends Node

@export_range(0, 20) var neko_level: int
@export_range(0, 20) var hacker_level: int
@export_range(0, 20) var bandit_level: int
@export_range(0, 20) var idol_level: int
@export_range(0, 20) var construct_level: int
@export_range(0, 20) var keeper_level: int

func _ready() -> void:
	randomize() # Sets new RNG seed
	_initialize_char_levels()

func _initialize_char_levels() -> void:
	$Neko.ai_level = neko_level
	$Hacker.ai_level = hacker_level
	$Bandit.ai_level = bandit_level
	$Idol.ai_level = idol_level
	$Construct.ai_level = construct_level
	$Keeper.ai_level = keeper_level
