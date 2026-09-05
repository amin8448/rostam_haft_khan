class_name TrainingDummy
extends Enemy

## TEMPORARY. A stationary target for judging combat feel: no AI, no attacks,
## and no contact damage, so it can be stood next to safely. Session 3 moves it
## to tests/fixtures/, where test_combat and test_health keep using it.
##
## Everything it used to do itself now lives in Enemy; all that is left is
## falling and bleeding off knockback.

func _tick(delta: float) -> void:
	_apply_gravity(delta)
	_apply_knockback_friction(delta)
	move_and_slide()
