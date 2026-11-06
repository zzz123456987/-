extends Node2D

var dir := 1
var speed := 540.0
var target = null
var life := 1.5

const HIT_DATA := {
	"dmg": 8,
	"kb": Vector2(220, -90),
	"hitstun": 0.32,
	"hitstop": 0.07,
}

func _ready() -> void:
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(-8, 0), Vector2(0, -6), Vector2(8, 0), Vector2(0, 6),
	])
	poly.color = Color(0.85, 0.9, 1.0)
	add_child(poly)

func _physics_process(delta: float) -> void:
	position.x += dir * speed * delta
	rotation += dir * 18.0 * delta
	life -= delta
	if life <= 0.0 or position.x < -60.0 or position.x > 1260.0:
		queue_free()
		return
	if target != null and is_instance_valid(target):
		if Rect2(global_position - Vector2(8, 8), Vector2(16, 16)).intersects(target.hurt_rect()):
			target.take_hit(HIT_DATA, dir)
			Hitfx.burst(global_position, Color(0.7, 0.85, 1.0))
			queue_free()
