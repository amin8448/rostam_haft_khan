class_name GameCamera
extends Camera2D

@export var follow_speed: float = 7.0:
	set(value):
		follow_speed = value
		position_smoothing_speed = value
## How far ahead of the target the camera sits, in the target's facing direction.
@export var look_ahead_distance: float = 60.0
## Seconds for the look-ahead to swing across after the target turns around.
@export var look_ahead_time: float = 0.35
## The target may move this far vertically before the camera follows, so small
## jumps do not bob the view.
@export var vertical_dead_zone: float = 40.0
## Screen shake, written to Camera2D.offset rather than to the position. offset
## is applied after smoothing and after the room limits, so a shake cannot
## disturb the follow, the dead zone, or the snap on a room change. It can show
## a few pixels past a wall, which is why it is kept small.
@export var shake_decay: float = 26.0

var _target: Node2D
var _look_ahead: float = 0.0
var _shake: float = 0.0
var _focus_y: float = 0.0


func _ready() -> void:
	position_smoothing_enabled = true
	position_smoothing_speed = follow_speed
	# Run after the player has moved this tick, otherwise the camera always
	# frames where he was on the previous one.
	process_priority = 10


func set_target(target: Node2D) -> void:
	_target = target
	if _target == null:
		return
	_look_ahead = _facing() * look_ahead_distance
	_focus_y = _target.global_position.y
	snap()


## The area the camera may show. Rooms declare their own; call this before
## snapping on a room change.
func set_bounds(bounds: Rect2) -> void:
	if bounds.get_area() <= 0.0:
		push_warning("GameCamera was given empty bounds; limits left open.")
		return
	limit_left = int(bounds.position.x)
	limit_top = int(bounds.position.y)
	limit_right = int(bounds.end.x)
	limit_bottom = int(bounds.end.y)


## Jump straight to the target with no smoothing, so a room transition does not
## sweep the camera across the level.
func snap() -> void:
	if _target == null:
		return
	global_position = _focus_point()
	reset_smoothing()


func _physics_process(delta: float) -> void:
	if _target == null:
		return

	var rate: float = look_ahead_distance / maxf(look_ahead_time, 0.001)
	_look_ahead = move_toward(_look_ahead, _facing() * look_ahead_distance, rate * delta)

	var target_y: float = _target.global_position.y
	if target_y < _focus_y - vertical_dead_zone:
		_focus_y = target_y + vertical_dead_zone
	elif target_y > _focus_y + vertical_dead_zone:
		_focus_y = target_y - vertical_dead_zone

	global_position = _focus_point()
	_update_shake(delta)


## Section 8 asks for a light shake on the Lion's pounce landing and nothing
## else in this slice.
func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _update_shake(delta: float) -> void:
	if _shake <= 0.0:
		if offset != Vector2.ZERO:
			offset = Vector2.ZERO
		return
	_shake = maxf(_shake - shake_decay * delta, 0.0)
	offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake


func _focus_point() -> Vector2:
	return Vector2(_target.global_position.x + _look_ahead, _focus_y)


func _facing() -> float:
	if _target != null and _target.has_method("get_facing"):
		return float(_target.get_facing())
	return 0.0
