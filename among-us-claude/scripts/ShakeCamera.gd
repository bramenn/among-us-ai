class_name ShakeCamera
extends Camera2D
## Cámara que sigue al jugador con screen shake.

var _trauma := 0.0


func shake(amount: float) -> void:
	_trauma = maxf(_trauma, amount)


func _process(delta: float) -> void:
	_trauma = move_toward(_trauma, 0.0, delta * 25.0)
	offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _trauma
