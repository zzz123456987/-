extends Camera2D

var trauma := 0.0
const MAX_OFFSET := 26.0

func _ready() -> void:
	add_to_group("shake_camera")

func add_trauma(v: float) -> void:
	trauma = clampf(trauma + v, 0.0, 1.0)

func _process(delta: float) -> void:
	trauma = maxf(0.0, trauma - delta * 2.2)
	if trauma > 0.0:
		offset = Vector2(
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0)
		) * MAX_OFFSET * trauma * trauma
	else:
		offset = Vector2.ZERO
