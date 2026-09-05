extends RefCounted

## Shared assertions for the headless simulation tests.
##
## Deliberately has no class_name: tests must not register globals into the
## shipped game. Tests reach it with `const Support = preload(...)`.

## A measurement counts as a miss when it is more than this far off the design
## target, as a fraction of the target.
const TOLERANCE: float = 0.1
## One physics tick at the project's 60 Hz.
const PHYSICS_TICK: float = 1.0 / 60.0


## Compares a measured number against a design target. A target of zero is
## checked absolutely, since a ratio against zero says nothing.
static func near(label: String, measured: float, target: float, unit: String = "px") -> bool:
	var ok: bool = false
	if is_zero_approx(target):
		ok = absf(measured) < 1.0
	else:
		ok = absf(measured - target) / absf(target) <= TOLERANCE
	print("%s  %-28s measured %9.2f %-4s target %9.2f" % [_mark(ok), label, measured, unit, target])
	return ok


## For timings, which are quantised to the physics tick and so cannot be
## measured more finely than one. For a short window one tick is already wider
## than 10%, which would make the plain rule unsatisfiable however correct the
## code is, so the tolerance is the larger of the two.
static func near_time(label: String, measured: float, target: float) -> bool:
	var allowed: float = maxf(absf(target) * TOLERANCE, PHYSICS_TICK)
	var ok: bool = absf(measured - target) <= allowed
	print("%s  %-28s measured %9.4f s    target %9.4f  (+/- %.4f)"
			% [_mark(ok), label, measured, target, allowed])
	return ok


## For values that must match outright, such as a facing direction or a state.
static func exact(label: String, measured: Variant, target: Variant) -> bool:
	var ok: bool = measured == target
	print("%s  %-28s measured %9s      target %9s" % [_mark(ok), label, str(measured), str(target)])
	return ok


static func report(suite: String, failures: int) -> int:
	if failures == 0:
		print("\n%s: all checks passed\n" % suite)
	else:
		printerr("\n%s: %d check(s) missed the design target by more than %d%%\n"
				% [suite, failures, int(TOLERANCE * 100.0)])
	return 1 if failures > 0 else 0


static func _mark(ok: bool) -> String:
	return "  ok" if ok else "FAIL"
