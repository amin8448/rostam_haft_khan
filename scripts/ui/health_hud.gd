extends CanvasLayer

## Five health pips, top-left. Section 5: nothing else yet.
##
## Pips are built in code rather than laid out in the scene so max_health stays
## a single tunable number instead of a node count to keep in sync.

@export var pip_size: Vector2 = Vector2(18, 18)
@export var pip_gap: float = 6.0
@export var margin: Vector2 = Vector2(16, 16)
@export var full_color: Color = Color(0.85, 0.27, 0.32, 1)
@export var empty_color: Color = Color(0.18, 0.18, 0.22, 1)

var _pips: Array[ColorRect] = []


func set_health(current: int, maximum: int) -> void:
	_build(maximum)
	for i in _pips.size():
		_pips[i].color = full_color if i < current else empty_color


func _build(count: int) -> void:
	if _pips.size() == count:
		return
	for pip in _pips:
		pip.queue_free()
	_pips.clear()
	for i in count:
		var pip: ColorRect = ColorRect.new()
		pip.size = pip_size
		pip.position = margin + Vector2((pip_size.x + pip_gap) * i, 0.0)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(pip)
		_pips.append(pip)
