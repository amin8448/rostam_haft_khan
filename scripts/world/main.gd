extends Node2D

## Wiring only. The RoomManager owns rooms, transitions and the respawn point;
## this connects Rostam's signals to it and to the HUD, then starts the game.

@onready var _manager: RoomManager = $RoomManager
@onready var _player: Rostam = $Rostam
@onready var _hud: CanvasLayer = $HealthHud


func _ready() -> void:
	_player.health_changed.connect(_on_health_changed)
	_player.died.connect(_manager.on_player_died)
	_on_health_changed(_player.health, _player.max_health)
	_manager.start()


func _on_health_changed(current: int, maximum: int) -> void:
	if _hud.has_method("set_health"):
		_hud.set_health(current, maximum)
