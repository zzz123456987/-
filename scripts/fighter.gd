class_name Fighter
extends CharacterBody2D

signal health_changed(value, max_value)
signal spirit_changed(value, max_value)
signal died(fighter)

enum State { IDLE, WALK, JUMP, DASH, ATTACK, HURT, DEAD }
enum ControlMode { PLAYER, AI }

@export var control_mode: ControlMode = ControlMode.PLAYER
@export var fighter_name := "风羽"
@export var body_color := Color(0.25, 0.55, 1.0)
@export var facing := 1

const GRAVITY := 2200.0
const RUN_SPEED := 260.0
const JUMP_VELOCITY := -720.0
const DASH_SPEED := 620.0
const DASH_TIME := 0.14
const DASH_COOLDOWN := 0.35
const MAX_HEALTH := 100
const MAX_SPIRIT := 100
const BUFFER_WINDOW := 0.12

const ATTACKS := {
	"light1": {
		"dmg": 4, "startup": 0.07, "active": 0.07, "recover": 0.16,
		"kb": Vector2(140, -60), "hitstun": 0.28, "hitstop": 0.06,
		"chain": "light2", "lunge": 90.0, "width": 46.0, "height": 40.0,
	},
	"light2": {
		"dmg": 4, "startup": 0.07, "active": 0.07, "recover": 0.16,
		"kb": Vector2(150, -70), "hitstun": 0.28, "hitstop": 0.06,
		"chain": "light3", "lunge": 100.0, "width": 46.0, "height": 40.0,
	},
	"light3": {
		"dmg": 6, "startup": 0.09, "active": 0.08, "recover": 0.3,
		"kb": Vector2(360, -200), "hitstun": 0.4, "hitstop": 0.1,
		"chain": "", "lunge": 120.0, "width": 50.0, "height": 44.0,
	},
	"heavy": {
		"dmg": 12, "startup": 0.22, "active": 0.08, "recover": 0.34,
		"kb": Vector2(430, -230), "hitstun": 0.46, "hitstop": 0.11,
		"chain": "", "lunge": 60.0, "width": 54.0, "height": 48.0,
	},
	"dash_strike": {
		"dmg": 14, "startup": 0.05, "active": 0.18, "recover": 0.3,
		"kb": Vector2(390, -170), "hitstun": 0.42, "hitstop": 0.1,
		"chain": "", "lunge": 0.0, "width": 52.0, "height": 44.0,
		"cost": 30.0, "dash_speed": 760.0,
	},
	"shuriken": {
		"dmg": 0, "startup": 0.12, "active": 0.0, "recover": 0.25,
		"kb": Vector2.ZERO, "hitstun": 0.0, "hitstop": 0.0,
		"chain": "", "lunge": 0.0, "width": 0.0, "height": 0.0,
		"cost": 20.0, "spawn_projectile": true,
	},
}

var state: State = State.IDLE
var state_time := 0.0
var current_attack := ""
var has_hit := false
var flash_done := false
var has_spawned := false
var hurt_duration := 0.0
var dash_cd := 0.0
var locked := false

var health := MAX_HEALTH
var spirit := 20.0

var input_dir := 0.0
var buffer := {
	"jump": 0.0, "light": 0.0, "heavy": 0.0,
	"dash": 0.0, "skill1": 0.0, "skill2": 0.0,
}

var opponent: Fighter = null
var ai_timer := 0.3
var ai_move_dir := 0.0

const ProjectileScript := preload("res://scripts/projectile.gd")

func _ready() -> void:
	add_to_group("fighters")
	$Body.modulate = body_color
	$Nose.position.x = 12.0 * facing
	call_deferred("_find_opponent")

func _find_opponent() -> void:
	for f in get_tree().get_nodes_in_group("fighters"):
		if f != self:
			opponent = f

func hurt_rect() -> Rect2:
	return Rect2(global_position + Vector2(-15.0, -62.0), Vector2(30.0, 62.0))

func gain_spirit(v: float) -> void:
	spirit = clampf(spirit + v, 0.0, MAX_SPIRIT)
	spirit_changed.emit(spirit, MAX_SPIRIT)

# ---------------- input ----------------

func _input(event: InputEvent) -> void:
	if control_mode != ControlMode.PLAYER or locked or state == State.DEAD:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_W: buffer.jump = BUFFER_WINDOW
			KEY_J: buffer.light = BUFFER_WINDOW
			KEY_K: buffer.heavy = BUFFER_WINDOW
			KEY_L: buffer.dash = BUFFER_WINDOW
			KEY_U: buffer.skill1 = BUFFER_WINDOW
			KEY_I: buffer.skill2 = BUFFER_WINDOW

func _read_movement_keys() -> void:
	input_dir = 0.0
	if Input.is_physical_key_pressed(KEY_A):
		input_dir -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		input_dir += 1.0

# ---------------- AI ----------------

func _ai_update(delta: float) -> void:
	ai_timer -= delta
	if ai_timer <= 0.0:
		ai_timer = randf_range(0.14, 0.26)
		_ai_think()
	input_dir = ai_move_dir

func _ai_think() -> void:
	ai_move_dir = 0.0
	if opponent == null or opponent.state == State.DEAD:
		return
	var dx: float = opponent.global_position.x - global_position.x
	var dir := signf(dx)
	var adx := absf(dx)
	var r := randf()
	if adx > 260.0:
		if spirit >= 20.0 and r < 0.25:
			buffer.skill2 = BUFFER_WINDOW
		elif r < 0.5 and dash_cd <= 0.0:
			ai_move_dir = dir
			buffer.dash = BUFFER_WINDOW
		else:
			ai_move_dir = dir
	elif adx > 75.0:
		if r < 0.6:
			ai_move_dir = dir
		elif r < 0.75 and spirit >= 30.0:
			ai_move_dir = dir
			buffer.skill1 = BUFFER_WINDOW
		elif r < 0.87:
			ai_move_dir = -dir
		else:
			buffer.jump = BUFFER_WINDOW
	else:
		if r < 0.5:
			buffer.light = BUFFER_WINDOW
		elif r < 0.65:
			buffer.heavy = BUFFER_WINDOW
		elif r < 0.78 and spirit >= 30.0:
			buffer.skill1 = BUFFER_WINDOW
		elif r < 0.88:
			buffer.jump = BUFFER_WINDOW
		else:
			ai_move_dir = -dir

# ---------------- physics / state machine ----------------

func _physics_process(delta: float) -> void:
	_decay_buffers(delta)
	var dashing_attack: bool = state == State.ATTACK and ATTACKS[current_attack].get("dash_speed", 0.0) != 0.0
	if not is_on_floor() and state != State.DASH and not dashing_attack:
		velocity.y += GRAVITY * delta

	if state != State.DEAD and not locked:
		if control_mode == ControlMode.AI:
			_ai_update(delta)
		else:
			_read_movement_keys()
		_update_facing()
		match state:
			State.IDLE, State.WALK:
				_grounded_update(delta)
			State.JUMP:
				_air_update(delta)
			State.DASH:
				_dash_update(delta)
			State.ATTACK:
				_attack_update(delta)
			State.HURT:
				_hurt_update(delta)
	elif state == State.DEAD and is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)

	move_and_slide()
	position.x = clampf(position.x, 16.0, 1184.0)
	if state == State.JUMP and is_on_floor():
		state = State.IDLE

func _decay_buffers(delta: float) -> void:
	for k in buffer:
		buffer[k] = maxf(0.0, buffer[k] - delta)
	dash_cd = maxf(0.0, dash_cd - delta)

func _update_facing() -> void:
	if state == State.IDLE or state == State.WALK:
		if input_dir != 0.0:
			facing = int(signf(input_dir))
	$Nose.position.x = 12.0 * facing

func _grounded_update(_delta: float) -> void:
	velocity.x = input_dir * RUN_SPEED
	state = State.IDLE if input_dir == 0.0 else State.WALK
	if buffer.skill1 > 0.0:
		buffer.skill1 = 0.0
		if start_attack("dash_strike"):
			return
	if buffer.skill2 > 0.0:
		buffer.skill2 = 0.0
		if start_attack("shuriken"):
			return
	if buffer.heavy > 0.0:
		buffer.heavy = 0.0
		start_attack("heavy")
		return
	if buffer.light > 0.0:
		buffer.light = 0.0
		start_attack("light1")
		return
	if buffer.dash > 0.0 and dash_cd <= 0.0:
		buffer.dash = 0.0
		state = State.DASH
		state_time = 0.0
		return
	if buffer.jump > 0.0:
		buffer.jump = 0.0
		velocity.y = JUMP_VELOCITY
		state = State.JUMP

func _air_update(_delta: float) -> void:
	velocity.x = input_dir * RUN_SPEED * 0.85
	if buffer.light > 0.0:
		buffer.light = 0.0
		start_attack("light1")

func _dash_update(delta: float) -> void:
	state_time += delta
	velocity = Vector2(facing * DASH_SPEED, 0.0)
	if state_time >= DASH_TIME:
		state = State.IDLE
		dash_cd = DASH_COOLDOWN

func _attack_update(delta: float) -> void:
	state_time += delta
	var data: Dictionary = ATTACKS[current_attack]
	var t := state_time
	var startup: float = data.startup
	var active: float = data.active
	var recover: float = data.recover

	if data.get("dash_speed", 0.0) != 0.0 and t >= startup and t < startup + active:
		velocity = Vector2(facing * data.dash_speed, 0.0)
	elif data.lunge != 0.0 and t < startup + active:
		velocity.x = facing * data.lunge
	else:
		velocity.x = move_toward(velocity.x, 0.0, 1400.0 * delta)

	if data.get("spawn_projectile", false) and not has_spawned and t >= startup:
		has_spawned = true
		_spawn_projectile()

	if active > 0.0 and t >= startup and t < startup + active:
		if not flash_done:
			flash_done = true
			_spawn_attack_flash(data, active)
		if not has_hit and opponent != null and opponent.state != State.DEAD:
			if _attack_rect(data).intersects(opponent.hurt_rect()):
				has_hit = true
				opponent.take_hit(data, facing)
				gain_spirit(8.0)

	if t >= startup + active and data.chain != "" and buffer.light > 0.0 and is_on_floor():
		buffer.light = 0.0
		start_attack(data.chain)
		return
	if t >= startup + active + recover:
		state = State.IDLE if is_on_floor() else State.JUMP

func _hurt_update(delta: float) -> void:
	state_time += delta
	velocity.x = move_toward(velocity.x, 0.0, 700.0 * delta)
	if state_time >= hurt_duration:
		state = State.IDLE if is_on_floor() else State.JUMP

# ---------------- combat ----------------

func start_attack(attack_name: String) -> bool:
	var data: Dictionary = ATTACKS[attack_name]
	var cost: float = data.get("cost", 0.0)
	if cost > spirit:
		return false
	if cost > 0.0:
		gain_spirit(-cost)
	state = State.ATTACK
	state_time = 0.0
	current_attack = attack_name
	has_hit = false
	flash_done = false
	has_spawned = false
	return true

func _attack_rect(data: Dictionary) -> Rect2:
	var w: float = data.width
	var h: float = data.height
	var center := global_position + Vector2(facing * (12.0 + w * 0.5), -34.0)
	return Rect2(center - Vector2(w * 0.5, h * 0.5), Vector2(w, h))

func take_hit(data: Dictionary, dir: int) -> void:
	if state == State.DEAD:
		return
	health = maxi(0, health - int(data.dmg))
	health_changed.emit(health, MAX_HEALTH)
	gain_spirit(6.0)
	Hitfx.hitstop(data.get("hitstop", 0.06))
	Hitfx.shake(0.35 if data.dmg < 10 else 0.6)
	Hitfx.burst(global_position + Vector2(0, -36), Color(1.0, 0.8, 0.3))
	velocity = Vector2(dir * data.kb.x, data.kb.y)
	if health <= 0:
		die()
		return
	state = State.HURT
	state_time = 0.0
	hurt_duration = data.get("hitstun", 0.3)
	_flash_hurt()

func die() -> void:
	state = State.DEAD
	health_changed.emit(0, MAX_HEALTH)
	modulate = Color(0.5, 0.5, 0.55)
	Hitfx.hitstop(0.6, 0.25)
	died.emit(self)

func _flash_hurt() -> void:
	modulate = Color(1.0, 0.35, 0.35)
	get_tree().create_timer(0.12, true, false, true).timeout.connect(
		func(): if state != State.DEAD: modulate = Color.WHITE
	)

func _spawn_attack_flash(data: Dictionary, duration: float) -> void:
	var w: float = data.width
	var h: float = data.height
	var flash := Polygon2D.new()
	flash.polygon = PackedVector2Array([
		Vector2(-w * 0.5, -h * 0.5), Vector2(w * 0.5, -h * 0.5),
		Vector2(w * 0.5, h * 0.5), Vector2(-w * 0.5, h * 0.5),
	])
	flash.color = Color(1.0, 1.0, 1.0, 0.45)
	flash.position = Vector2(facing * (12.0 + w * 0.5), -34.0)
	add_child(flash)
	get_tree().create_timer(duration + 0.04, true, false, true).timeout.connect(flash.queue_free)

func _spawn_projectile() -> void:
	var dart: Node2D = ProjectileScript.new()
	dart.dir = facing
	dart.target = opponent
	dart.global_position = global_position + Vector2(facing * 22.0, -40.0)
	get_tree().current_scene.add_child(dart)
