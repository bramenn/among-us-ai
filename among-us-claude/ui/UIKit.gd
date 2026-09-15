class_name UIKit
extends RefCounted
## Helpers de UI compartidos.


## Ancla `c` al preset y fija offsets relativos (sobrevive a cambios de tamaño de ventana).
static func place(c: Control, preset: Control.LayoutPreset, off: Vector2, sz: Vector2) -> void:
	c.set_anchors_preset(preset)
	c.offset_left = off.x
	c.offset_top = off.y
	c.offset_right = off.x + sz.x
	c.offset_bottom = off.y + sz.y


static func box(bg: Color, border: Color, radius := 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb
