extends CanvasLayer

## The Lion's health, shown only while the fight is running.
##
## Section 5 says the HUD is five pips and nothing else. This is the stated
## exception: 30 health with no bar is unreadable, and the colour carries a
## second read on top of the length, running orange to red to dark red as the
## fight goes on, so the state of it is legible at a glance.

@export var bar_size: Vector2 = Vector2(420, 16)
@export var top_margin: float = 26.0
@export var full_color: Color = Color(0.95, 0.55, 0.15, 1)
@export var half_color: Color = Color(0.82, 0.21, 0.13, 1)
@export var low_color: Color = Color(0.38, 0.06, 0.06, 1)
@export var back_color: Color = Color(0.1, 0.09, 0.11, 1)

var _back: ColorRect
var _fill: ColorRect


func _ready() -> void:
	_back = ColorRect.new()
	_back.color = back_color
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_back)

	_fill = ColorRect.new()
	_fill.color = full_color
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fill)

	hide_bar()
	get_viewport().size_changed.connect(_layout)
	_layout()


func show_bar() -> void:
	_layout()
	_back.visible = true
	_fill.visible = true


func hide_bar() -> void:
	_back.visible = false
	_fill.visible = false


func set_health(current: int, maximum: int) -> void:
	if maximum <= 0:
		return
	var fraction: float = clampf(float(current) / float(maximum), 0.0, 1.0)
	_fill.size = Vector2(bar_size.x * fraction, bar_size.y)
	_fill.color = _color_for(fraction)


## Orange at full, red by half, dark red as it runs out.
func _color_for(fraction: float) -> Color:
	if fraction >= 0.5:
		return half_color.lerp(full_color, (fraction - 0.5) * 2.0)
	return low_color.lerp(half_color, fraction * 2.0)


func _layout() -> void:
	var view: Vector2 = Vector2(get_viewport().get_visible_rect().size)
	var origin: Vector2 = Vector2((view.x - bar_size.x) * 0.5, top_margin)
	_back.position = origin
	_back.size = bar_size
	_fill.position = origin
