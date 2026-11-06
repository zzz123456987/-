extends Node

func hitstop(duration := 0.08, scale := 0.05) -> void:
	Engine.time_scale = scale
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0

func shake(amount := 0.4) -> void:
	var cams := get_tree().get_nodes_in_group("shake_camera")
	if cams.size() > 0:
		cams[0].add_trauma(amount)

func burst(pos: Vector2, color := Color(1.0, 0.85, 0.3)) -> void:
	var p := CPUParticles2D.new()
	p.amount = 14
	p.lifetime = 0.4
	p.one_shot = true
	p.explosiveness = 1.0
	p.spread = 180.0
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 320.0
	p.gravity = Vector2(0, 900)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = color
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 6.0
	add_child(p)
	p.global_position = pos
	p.emitting = true
	get_tree().create_timer(1.2, true, false, true).timeout.connect(p.queue_free)
