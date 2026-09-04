class_name Rostam
extends CharacterBody2D

enum State { IDLE, RUN, JUMP, FALL }

@export_group("Run")
@export var run_speed: float = 320.0
## Seconds to reach full run speed from a standstill.
@export var time_to_max_speed: float = 0.1
## Seconds to come to a full stop once input is released.
@export var time_to_stop: float = 0.08

@export_group("Jump")
@export var jump_velocity: float = 640.0
## Upward velocity is scaled by this when jump is released while still rising,
## which is what makes jump height variable.
@export var jump_release_multiplier: float = 0.4
@export var rise_gravity: float = 1800.0
## Falling is heavier than rising so the arc has weight instead of floating.
@export var fall_gravity_multiplier: float = 1.6
@export var max_fall_speed: float = 900.0
## Grace period after walking off a ledge during which jump still works.
@export var coyote_time: float = 0.1
## Jump pressed this long before landing still fires on landing.
@export var jump_buffer_time: float = 0.1

var state: State = State.IDLE
var facing: int = 1

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0

@onready var _visuals: Node2D = $Visuals


func _physics_process(delta: float) -> void:
	var input_x: float = Input.get_axis("move_left", "move_right")

	_update_timers(delta)
	_apply_horizontal(input_x, delta)
	_apply_gravity(delta)
	_handle_jump()

	move_and_slide()

	_update_facing(input_x)
	_update_state(input_x)


## Anything that reads facing (the camera's look-ahead, attacks later) goes
## through this rather than reaching into the node.
func get_facing() -> int:
	return facing


func _update_timers(delta: float) -> void:
	if is_on_floor():
		_coyote_timer = coyote_time
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)

	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)


func _apply_horizontal(input_x: float, delta: float) -> void:
	var seconds: float = time_to_max_speed if not is_zero_approx(input_x) else time_to_stop
	# maxf guards against a zero tuned in the Inspector.
	var rate: float = run_speed / maxf(seconds, 0.001)
	velocity.x = move_toward(velocity.x, input_x * run_speed, rate * delta)


func _apply_gravity(delta: float) -> void:
	var gravity: float = rise_gravity
	if velocity.y >= 0.0:
		gravity *= fall_gravity_multiplier
	velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)


func _handle_jump() -> void:
	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		velocity.y = -jump_velocity
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0

	# Not an elif: a tap short enough to press and release inside one physics
	# tick should still be cut down to a minimum-height hop.
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_release_multiplier


func _update_facing(input_x: float) -> void:
	if absf(input_x) < 0.1:
		return
	facing = 1 if input_x > 0.0 else -1
	_visuals.scale.x = float(facing)


func _update_state(input_x: float) -> void:
	match state:
		State.IDLE, State.RUN:
			if is_on_floor():
				state = _grounded_state(input_x)
			else:
				state = State.JUMP if velocity.y < 0.0 else State.FALL
		State.JUMP:
			if is_on_floor():
				state = _grounded_state(input_x)
			elif velocity.y >= 0.0:
				state = State.FALL
		State.FALL:
			if is_on_floor():
				state = _grounded_state(input_x)
			elif velocity.y < 0.0:
				state = State.JUMP


func _grounded_state(input_x: float) -> State:
	return State.RUN if not is_zero_approx(input_x) else State.IDLE
