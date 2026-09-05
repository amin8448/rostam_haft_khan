class_name Rostam
extends CharacterBody2D

signal health_changed(current: int, maximum: int)
signal died

enum State { IDLE, RUN, JUMP, FALL, ATTACK, DEAD }

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
## A stick released or reversed rebounds past centre for a frame or two. Facing
## ignores anything weaker than this, so the rebound cannot spin Rostam round.
## Movement and acceleration still use the full analog value.
@export var facing_threshold: float = 0.5
## Consecutive physics ticks the input must hold a new direction before facing
## follows it. Catches a rebound strong enough to clear facing_threshold.
@export var facing_hold_ticks: int = 3

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
## How long the hitbox stays open. The mace head is visible for exactly
## this window, so the timing can be tuned by eye.
@export var swing_active: Array[float] = [0.08, 0.08, 0.10, 0.08]
@export var swing_damage: Array[int] = [1, 1, 1, 1]
## The third swing hits harder without hitting for more: section 5 asks for more
## knockback and a bigger box, not more damage.
@export var swing_knockback: Array[float] = [180.0, 180.0, 320.0, 180.0]
## The air swing is the odd one: bigger, and it sweeps the space above and in
## front of Rostam rather than straight ahead, because the things worth hitting
## in the air are overhead.
@export var swing_size: Array[Vector2] = [
	Vector2(34, 24), Vector2(34, 24), Vector2(46, 32), Vector2(44, 36),
]
## Forward step per swing. The two quick swings leave Rostam planted and only
## the finisher travels, so the third hit reads as a lunge rather than a third
## helping of the same shuffle. A 12 px step on every swing was tried first and
## cut. The air attack takes none, to leave the jump arc alone.
@export var swing_step: Array[float] = [0.0, 0.0, 20.0, 0.0]
## Effectively the finisher's lunge speed: no other swing steps.
@export var swing_step_speed: float = 120.0
## Gap from Rostam's centre to the near edge of the mace head, per swing. The
## air swing's is negative so the box straddles him instead of sitting purely in
## front, which is what lets it reach something directly overhead.
@export var swing_reach: Array[float] = [10.0, 10.0, 10.0, -12.0]
## Height of the mace box relative to Rostam's centre, positive being lower,
## per swing. The ground swings hang low because ground enemies are low: the
## Jackal is a 24 px slab and a chest-height swing cleared all but 4 px of it.
## The air swing goes the other way and sits above his head, so the box arrives
## before his hurtbox does when he rises into something.
@export var swing_height: Array[float] = [6.0, 6.0, 6.0, -34.0]
## No further attack input within this long after a swing and the combo drops
## back to the first hit.
@export var combo_reset_time: float = 0.4

@export_group("Health")
@export var max_health: int = 5
## Invulnerability after taking a hit, flickering so it is readable.
@export var invulnerable_time: float = 0.8
@export var flicker_interval: float = 0.06
## Brief loss of control on being hit, so a hit interrupts rather than being
## something you can run straight through.
@export var control_loss_time: float = 0.15

@export_group("Boss")
## Section 5's small self recoil on hitting a boss. How hard depends on what was
## hit: the target reports it, so nothing here knows what a boss is.
@export var recoil_time: float = 0.15
@export var recoil_friction: float = 900.0
## How far the visuals jitter while pinned in the Lion's phase 2.
@export var struggle_amount: float = 2.0

var health: int = 5
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
var _invuln_timer: float = 0.0
var _control_timer: float = 0.0
var _flicker_timer: float = 0.0
var _recoil_timer: float = 0.0
var _pinned: bool = false
var _facing_candidate: int = 0
var _facing_hold: int = 0

@onready var _visuals: Node2D = $Visuals
@onready var _mace: Hitbox = $Visuals/MaceHitbox
@onready var _hurtbox: Area2D = $Hurtbox


func _ready() -> void:
	health = max_health
	health_changed.emit(health, max_health)
	_mace.hit_landed.connect(_on_mace_hit)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	# Pinned: the phase 2 sequence owns him. No input, no attack, no dying, and
	# a small shake in place so it reads as a struggle rather than a freeze.
	if _pinned:
		_visuals.position = Vector2(
			randf_range(-struggle_amount, struggle_amount),
			randf_range(-struggle_amount, struggle_amount))
		velocity.x = 0.0
		_apply_gravity(delta)
		move_and_slide()
		return

	# Hit pause freezes this body only. The camera keeps running, which is the
	# whole reason this is not Engine.time_scale.
	if _hit_pause_timer > 0.0:
		_hit_pause_timer -= delta
		return

	_update_timers(delta)

	# Control loss is what makes a hit land: input is ignored for a moment, but
	# gravity and the knockback keep applying.
	var stunned: bool = _control_timer > 0.0
	var input_x: float = 0.0 if stunned else Input.get_axis("move_left", "move_right")

	if state == State.ATTACK:
		_update_swing(delta)
	elif not stunned:
		_try_start_attack()

	if state == State.ATTACK:
		_apply_attack_motion(delta)
	else:
		_apply_horizontal(input_x, delta)

	_apply_gravity(delta)

	# Jump after gravity, so the launch tick is exactly -jump_velocity rather
	# than one tick of gravity short of it.
	if state != State.ATTACK and not stunned:
		_handle_jump()

	move_and_slide()

	if state != State.ATTACK:
		_update_facing(input_x)
	_update_state(input_x)


## Anything that reads facing (the camera's look-ahead, the mace) goes through
## this rather than reaching into the node.
func get_facing() -> int:
	return facing


## Freezes this body for a moment on a landed hit. Called by Hitbox on both
## parties, so attacker and target stop together.
func apply_hit_pause(duration: float) -> void:
	_hit_pause_timer = maxf(_hit_pause_timer, duration)


func is_attacking() -> bool:
	return state == State.ATTACK


func is_hit_paused() -> bool:
	return _hit_pause_timer > 0.0


func is_invulnerable() -> bool:
	return _invuln_timer > 0.0


func is_dead() -> bool:
	return state == State.DEAD


func is_pinned() -> bool:
	return _pinned


## Locks control for a scripted moment. Invulnerable while it lasts, so the
## sequence cannot be interrupted by whatever was already in flight.
func set_pinned(pinned: bool) -> void:
	_pinned = pinned
	if pinned:
		_cancel_swing()
		velocity = Vector2.ZERO
		state = State.IDLE
	else:
		_visuals.position = Vector2.ZERO


## Returns true only when damage was actually applied, so the attacker can tell
## a real hit from one absorbed by invulnerability.
func take_damage(amount: int, knockback: Vector2, _source: Node2D) -> bool:
	if amount <= 0 or state == State.DEAD or _invuln_timer > 0.0 or _pinned:
		return false

	health = maxi(health - amount, 0)
	health_changed.emit(health, max_health)
	_cancel_swing()

	if health == 0:
		state = State.DEAD
		velocity = Vector2.ZERO
		_invuln_timer = 0.0
		_visuals.visible = true
		# A corpse is not a target. This also drops the overlap with whatever
		# killed him, which matters on respawn: see below.
		_hurtbox.monitorable = false
		died.emit()
		return true

	_invuln_timer = invulnerable_time
	_control_timer = control_loss_time
	_flicker_timer = flicker_interval
	velocity = knockback
	state = State.IDLE if is_on_floor() else State.FALL
	return true


## Refills health without moving him or clearing anything else. Resting at a
## grazing ground uses this; dying uses respawn().
func heal_full() -> void:
	if state == State.DEAD or health == max_health:
		return
	health = max_health
	health_changed.emit(health, max_health)


## Puts Rostam back at a spawn point with nothing left over from the run that
## killed him: no timers, no combo, no velocity, no half-open hitbox.
func respawn(at: Vector2) -> void:
	global_position = at
	velocity = Vector2.ZERO
	health = max_health
	state = State.IDLE
	facing = 1

	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	_hit_pause_timer = 0.0
	_invuln_timer = 0.0
	_control_timer = 0.0
	_flicker_timer = 0.0
	_combo_timer = 0.0
	_swing_index = 0
	_swing_timer = 0.0
	_step_remaining = 0.0
	_attack_buffered = false
	_air_attack_used = false
	_recoil_timer = 0.0
	_pinned = false
	_visuals.position = Vector2.ZERO
	_facing_candidate = 0
	_facing_hold = 0

	_mace.deactivate()
	_visuals.visible = true
	_visuals.scale.x = 1.0

	# Teleporting does not move the hurtbox in the physics broadphase until the
	# next step, so the hazard he died on still reported an overlap and landed a
	# free hit the moment he respawned, half a room away. Push the transform
	# through before the hurtbox becomes a target again.
	force_update_transform()
	_hurtbox.force_update_transform()
	_hurtbox.monitorable = true

	health_changed.emit(health, max_health)


func _cancel_swing() -> void:
	_mace.deactivate()
	_step_remaining = 0.0
	_attack_buffered = false


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
	_control_timer = maxf(_control_timer - delta, 0.0)
	_update_invulnerability(delta)


func _update_invulnerability(delta: float) -> void:
	if _invuln_timer <= 0.0:
		return
	_invuln_timer -= delta
	if _invuln_timer <= 0.0:
		_visuals.visible = true
		return
	_flicker_timer -= delta
	if _flicker_timer <= 0.0:
		_flicker_timer = flicker_interval
		_visuals.visible = not _visuals.visible


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

	_mace.damage = _swing_i(swing_damage, index)
	_mace.knockback_speed = _swing_f(swing_knockback, index)
	var box: Vector2 = _swing_v2(swing_size, index)
	_mace.size = box
	_mace.offset = Vector2(_swing_f(swing_reach, index) + box.x * 0.5,
			_swing_f(swing_height, index))
	_mace.deactivate()


func _update_swing(delta: float) -> void:
	_swing_timer += delta

	var windup: float = _swing_f(swing_windup, _swing_index)
	var open: bool = _swing_timer >= windup \
			and _swing_timer < windup + _swing_f(swing_active, _swing_index)
	if open != _mace.is_active():
		if open:
			_mace.activate()
		else:
			_mace.deactivate()

	# Pressing attack mid-swing chains into the next one the moment this ends,
	# rather than being dropped for being early.
	if Input.is_action_just_pressed("attack"):
		_attack_buffered = true

	if _swing_timer >= _swing_f(swing_duration, _swing_index):
		_end_swing()


func _end_swing() -> void:
	_mace.deactivate()
	_combo_timer = combo_reset_time
	state = State.FALL if not is_on_floor() else State.IDLE

	if _attack_buffered:
		_attack_buffered = false
		_try_start_attack(true)


func _apply_attack_motion(delta: float) -> void:
	if not is_on_floor():
		# Keep the existing arc: an air swing should not stall a jump.
		return
	if _recoil_timer > 0.0:
		# Riding the recoil off a boss. Without this the swing would zero it on
		# the very next tick and the recoil would never be felt.
		_recoil_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, recoil_friction * delta)
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
	if absf(input_x) < facing_threshold:
		_facing_candidate = 0
		_facing_hold = 0
		return

	var wanted: int = 1 if input_x > 0.0 else -1
	if wanted == facing:
		_facing_candidate = 0
		_facing_hold = 0
		return

	if wanted != _facing_candidate:
		_facing_candidate = wanted
		_facing_hold = 1
	else:
		_facing_hold += 1

	if _facing_hold < facing_hold_ticks:
		return
	facing = wanted
	_visuals.scale.x = float(facing)
	_facing_candidate = 0
	_facing_hold = 0


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


## Section 5's self recoil. The target says how hard it shoves back, so a Jackal
## reports nothing and the Lion reports a real number.
func _on_mace_hit(target: Node2D) -> void:
	if target == null or not target.has_method("get_attacker_recoil"):
		return
	var recoil: float = target.get_attacker_recoil()
	if recoil <= 0.0:
		return
	velocity.x = -float(facing) * recoil
	_recoil_timer = recoil_time
