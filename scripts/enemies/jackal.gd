class_name Jackal
extends Enemy

## Ground enemy, design doc section 6. Patrols a platform edge to edge, turning
## at walls and ledges and never walking off. When Rostam is close and roughly
## level it stops, telegraphs, then lunges.
##
## Dumb on purpose: the pattern is the whole of it. Everything shared with the
## Vulture and the Lion lives in Enemy.

enum State { PATROL, TELEGRAPH, LUNGE, RECOVER }

@export var patrol_speed: float = 55.0
@export_enum("Left:-1", "Right:1") var start_facing: int = -1

@export_group("Attack")
## Horizontal distance at which Rostam is noticed.
@export var detect_range: float = 200.0
## Vertical slack for "roughly level". Anything further and he is ignored, which
## is what stops it lunging at someone standing on a platform overhead.
@export var level_tolerance: float = 40.0
@export var telegraph_time: float = 0.4
@export var lunge_speed: float = 260.0
@export var lunge_time: float = 0.35
## Still and exposed after the lunge. This is the opening.
@export var recover_time: float = 0.5

var state: State = State.PATROL
var facing: int = -1

var _timer: float = 0.0

@onready var _sensors: Node2D = $Sensors
@onready var _wall_cast: RayCast2D = $Sensors/WallCast
@onready var _ledge_cast: RayCast2D = $Sensors/LedgeCast


func get_facing() -> int:
	return facing


func _on_ready() -> void:
	facing = start_facing
	_apply_facing()


func _on_reset() -> void:
	state = State.PATROL
	_timer = 0.0
	facing = start_facing
	_apply_facing()


func _tick(delta: float) -> void:
	match state:
		State.PATROL:
			_patrol()
		State.TELEGRAPH:
			_telegraph(delta)
		State.LUNGE:
			_lunge(delta)
		State.RECOVER:
			_recover(delta)

	_apply_gravity(delta)
	move_and_slide()


func _patrol() -> void:
	if _at_edge():
		facing = -facing
		_apply_facing()
	velocity.x = float(facing) * patrol_speed

	if _sees_player():
		_enter_telegraph()


func _telegraph(delta: float) -> void:
	velocity.x = 0.0
	_timer -= delta
	if _timer <= 0.0:
		state = State.LUNGE
		_timer = lunge_time


func _lunge(delta: float) -> void:
	# The lunge respects ledges and walls too. A Jackal that dives off its own
	# platform reads as broken rather than as dumb.
	if _at_edge():
		velocity.x = 0.0
		_enter_recover()
		return

	velocity.x = float(facing) * lunge_speed
	_timer -= delta
	if _timer <= 0.0:
		_enter_recover()


func _recover(delta: float) -> void:
	_apply_knockback_friction(delta)
	_timer -= delta
	if _timer <= 0.0:
		state = State.PATROL


func _enter_telegraph() -> void:
	state = State.TELEGRAPH
	_timer = telegraph_time
	velocity.x = 0.0

	# Turn to face him first, so "lunges forward" goes somewhere useful.
	var player: Node2D = get_player()
	if player != null:
		var wanted: int = 1 if player.global_position.x > global_position.x else -1
		if wanted != facing:
			facing = wanted
			_apply_facing()

	telegraph(telegraph_time)


func _enter_recover() -> void:
	state = State.RECOVER
	_timer = recover_time


## A wall ahead, or no ground ahead. Both mean stop going this way.
func _at_edge() -> bool:
	return _wall_cast.is_colliding() or not _ledge_cast.is_colliding()


func _sees_player() -> bool:
	var player: Node2D = get_player()
	if player == null:
		return false
	if player.has_method("is_dead") and player.is_dead():
		return false
	var offset: Vector2 = player.global_position - global_position
	return absf(offset.y) <= level_tolerance and absf(offset.x) <= detect_range


func _apply_facing() -> void:
	_visuals.scale.x = float(facing)
	_sensors.scale.x = float(facing)
	# The casts have just moved. Without pushing the transform through and
	# re-casting, they answer for where they were last frame and the Jackal
	# turns straight back round again.
	_sensors.force_update_transform()
	_wall_cast.force_raycast_update()
	_ledge_cast.force_raycast_update()
