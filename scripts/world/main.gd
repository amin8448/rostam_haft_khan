extends Node2D

@onready var _room: Room = $Room
@onready var _player: Node2D = $Rostam
@onready var _camera: GameCamera = $GameCamera


func _ready() -> void:
	_player.global_position = _room.get_spawn_position()
	_camera.set_bounds(_room.bounds)
	_camera.set_target(_player)
