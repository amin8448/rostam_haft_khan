extends Node2D

## Owns the room, the player, the camera and the HUD, and runs the death and
## respawn sequence. No autoload: everything death needs is already here.

## Seconds to fade out, and again to fade back in. Section 5 asks for a fade to
## black on death; the room transition fade in section 7 will reuse this.
@export var fade_time: float = 0.25

var _respawning: bool = false

@onready var _room: Room = $Room
@onready var _player: Rostam = $Rostam
@onready var _camera: GameCamera = $GameCamera
@onready var _hud: CanvasLayer = $HealthHud
@onready var _fade: ColorRect = $FadeLayer/Fade


func _ready() -> void:
	_player.global_position = _room.get_spawn_position()
	_camera.set_bounds(_room.bounds)
	_camera.set_target(_player)

	_player.health_changed.connect(_on_health_changed)
	_player.died.connect(_on_player_died)
	_on_health_changed(_player.health, _player.max_health)


func _on_health_changed(current: int, maximum: int) -> void:
	if _hud.has_method("set_health"):
		_hud.set_health(current, maximum)


func _on_player_died() -> void:
	if _respawning:
		return
	_respawning = true

	var tween: Tween = create_tween()
	tween.tween_property(_fade, "color:a", 1.0, fade_time)
	tween.tween_callback(_respawn)
	tween.tween_property(_fade, "color:a", 0.0, fade_time)
	tween.tween_callback(func() -> void: _respawning = false)


## Everything resets while the screen is black, so the snap is never seen.
func _respawn() -> void:
	_player.respawn(_room.get_spawn_position())
	if _room.has_method("reset"):
		_room.reset()
	_camera.set_target(_player)
