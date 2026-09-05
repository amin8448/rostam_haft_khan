class_name Rostam
extends CharacterBody2D

enum State { IDLE, RUN, JUMP, FALL, ATTACK }

## Indices 0 to 2 are the ground combo, index 3 is the air attack. One set of
## arrays rather than two so every swing goes through the same code path.
const GROUND_SWINGS: int = 3
const AIR_SWING: int = 3

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

@export_group("Attack")
## Total length of each swing. The third is longer so it reads as heavier.
@export var swing_duration: Array[float] = [0.25, 0.25, 0.35, 0.25]
## Delay before the hitbox opens, so the swing has a wind-up to read.
@export var swing_windup: Array[float] = [0.08, 0.08, 0.12, 0.08]
## How long the hitbox stays open. The blade rectangle is visible for exactly
## this window, so the timing can be tuned by eye.
@export var swing_active: Array[float] = [0.08, 0.08, 0.10, 0.08]
@export var swing_damage: Array[int] = [1, 1, 1, 1]
## The third swing hits harder without hitting for more: section 5 asks for more
## knockback and a bigger box, not more damage.
@export var swing_knockback: Array[float] = [180.0, 180.0, 320.0, 180.0]
@export var swing_size: Array[Vector2] = [
	Vector2(34, 24), Vector2(34, 24), Vector2(46, 32), Vector2(34, 24),
]
## Forward step per swing, so attacking feels committed. The air attack gets
## none of it, to leave the jump arc alone.
@export var swing_step: Array[float] = [12.0, 12.0, 12.0, 0.0]
@export var swing_step_speed: float = 120.0
## Gap from Rostam's centre to the near edge of the blade.
@export var sword_reach: float = 10.0
@export var sword_height: float = -4.0
## No further attack input within this long after a swing and the combo drops
## back to the first hit.
@export var combo_reset_time: float = 0.4

var state: State = State.IDLE
var facing: int = 1

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _hit_pause_timer: float = 0.0
var _swing_index: int = 0
var _swing_timer: float = 0.0
var _combo_timer: float = 0.0
var _step_remaining: float = 0.0
var _attack_buffered: bool = false
var _air_attack_used: bool = false

@onready var _visuals: Node2D = $Visuals
@onready var _sword: Hitbox = $Visuals/SwordHitbox


func _physics_process(delta: float) -> void:
	# Hit pause freezes this body only. The camera keeps running, which is the
	# whole reason this is not Engine.time_scale.
	if _hit_pause_timer > 0.0:
		_hit_pause_timer -= delta
		return

	var input_x: float = Input.get_axis("move_left", "move_right")

	_update_timers(delta)

	if state == State.ATTACK:
		_update_swing(delta)
	else:
		_try_start_attack()

	if state == State.ATTACK:
		_apply_attack_motion(delta)
	else:
		_apply_horizontal(input_x, delta)

	_apply_gravity(delta)

	# Jump after gravity, so the launch tick is exactly -jump_velocity rather
	# than one tick of gravity short of it.
	if state != State.ATTACK:
		_handle_jump()

	move_and_slide()

	if state != State.ATTACK:
		_update_facing(input_x)
	_update_state(input_x)


## Anything that reads facing (the camera's look-ahead, the sword) goes through
## this rather than reaching into the node.
func get_facing() -> int:
	return facing


## Freezes this body for a moment on a landed hit. Called by Hitbox on both
## parties, so attacker and target stop together.
func apply_hit_pause(duration: float) -> void:
	_hit_pause_timer = maxf(_hit_pause_timer, duration)


func is_attacking() -> bool:
	return state == State.ATTACK


func get_swing_index() -> int:
	return _swing_index


func _update_timers(delta: float) -> void:
	if is_on_floor():
		_coyote_timer = coyote_time
		_air_attack_used = false
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)

	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)

	_combo_timer = maxf(_combo_timer - delta, 0.0)


func _try_start_attack(from_buffer: bool = false) -> void:
	if not from_buffer and not Input.is_action_just_pressed("attack"):
		return

	if is_on_floor():
		var next: int = 0
		if _combo_timer > 0.0 and _swing_index < GROUND_SWINGS - 1:
			next = _swing_index + 1
		_start_swing(next)
	elif not _air_attack_used:
		_air_attack_used = true
		_start_swing(AIR_SWING)


func _start_swing(index: int) -> void:
	_swing_index = index
	_swing_timer = 0.0
	_attack_buffered = false
	_step_remaining = _swing_f(swing_step, index)
	state = State.ATTACK

	_sword.damage = _swing_i(swing_damage, index)
	_sword.knockback_speed = _swing_f(swing_knockback, index)
	var box: Vector2 = _swing_v2(swing_size, index)
	_sword.size = box
	_sword.offset = Vector2(sword_reach + box.x * 0.5, sword_height)
	_sword.deactivate()


func _update_swing(delta: float) -> void:
	_swing_timer += delta

	var windup: float = _swing_f(swing_windup, _swing_index)
	var open: bool = _swing_timer >= windup \
			and _swing_timer < windup + _swing_f(swing_active, _swing_index)
	if open != _sword.is_active():
		if open:
			_sword.activate()
		else:
			_sword.deactivate()

	# Pressing attack mid-swing chains into the next one the moment this ends,
	# rather than being dropped for being early.
	if Input.is_action_just_pressed("attack"):
		_attack_buffered = true

	if _swing_timer >= _swing_f(swing_duration, _swing_index):
		_end_swing()


func _end_swing() -> void:
	_sword.deactivate()
	_combo_timer = combo_reset_time
	state = State.FALL if not is_on_floor() else State.IDLE

	if _attack_buffered:
		_attack_buffered = false
		_try_start_attack(true)


func _apply_attack_motion(delta: float) -> void:
	if not is_on_floor():
		# Keep the existing arc: an air swing should not stall a jump.
		return
	if _step_remaining > 0.0 and delta > 0.0:
		var move: float = minf(swing_step_speed * delta, _step_remaining)
		_step_remaining -= move
		velocity.x = float(facing) * move / delta
	else:
		velocity.x = 0.0


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
		State.ATTACK:
			pass
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


func _swing_f(values: Array[float], index: int) -> float:
	return 0.0 if values.is_empty() else values[clampi(index, 0, values.size() - 1)]


func _swing_i(values: Array[int], index: int) -> int:
	return 0 if values.is_empty() else values[clampi(index, 0, values.size() - 1)]


func _swing_v2(values: Array[Vector2], index: int) -> Vector2:
	return Vector2.ZERO if values.is_empty() else values[clampi(index, 0, values.size() - 1)]
