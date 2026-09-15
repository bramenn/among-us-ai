class_name Transition
extends CanvasLayer
## Transición de pantalla: cortinas que se cierran con un título y se abren.

var _top: ColorRect
var _bottom: ColorRect
var _title: Label


func _ready() -> void:
	layer = 50
	_top = _panel()
	_bottom = _panel()
	_title = Label.new()
	UIKit.place(_title, Control.PRESET_CENTER, Vector2(-500, -50), Vector2(1000, 100))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 56)
	_title.add_theme_constant_override("outline_size", 10)
	_title.add_theme_color_override("font_outline_color", Color.BLACK)
	_title.modulate.a = 0.0
	add_child(_title)
	_layout(0.0)


func _panel() -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0.05, 0.02, 0.04)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r


## closed: 0 abierto, 1 cerrado.
func _layout(closed: float) -> void:
	var vs := get_viewport().get_visible_rect().size
	var h := vs.y * 0.5 * closed
	_top.position = Vector2(0, 0)
	_top.size = Vector2(vs.x, h)
	_bottom.position = Vector2(0, vs.y - h)
	_bottom.size = Vector2(vs.x, h)
	_top.visible = closed > 0.0
	_bottom.visible = closed > 0.0


## Cierra, muestra `title`, ejecuta `mid` y vuelve a abrir.
func play(title: String, col: Color, mid: Callable, hold := 1.1) -> void:
	_title.text = title
	_title.add_theme_color_override("font_color", col)
	_title.scale = Vector2(1.4, 1.4)
	_title.pivot_offset = _title.size * 0.5
	var tw := create_tween()
	tw.tween_method(_layout, 0.0, 1.0, 0.3).set_ease(Tween.EASE_IN)
	tw.tween_property(_title, "modulate:a", 1.0, 0.15)
	tw.parallel().tween_property(_title, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold)
	tw.tween_callback(mid)
	tw.tween_property(_title, "modulate:a", 0.0, 0.15)
	tw.tween_method(_layout, 1.0, 0.0, 0.35).set_ease(Tween.EASE_OUT)
