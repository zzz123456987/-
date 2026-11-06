extends Node2D

@onready var p1 = $Player
@onready var p2 = $Enemy
@onready var p1_hp: ProgressBar = $UI/Root/P1HP
@onready var p1_sp: ProgressBar = $UI/Root/P1SP
@onready var p2_hp: ProgressBar = $UI/Root/P2HP
@onready var p2_sp: ProgressBar = $UI/Root/P2SP
@onready var timer_label: Label = $UI/Root/TimerLabel
@onready var banner: Label = $UI/Root/BannerLabel

var time_left := 99.0
var round_over := false

func _ready() -> void:
	p1.health_changed.connect(func(v, _m): p1_hp.value = v)
	p1.spirit_changed.connect(func(v, _m): p1_sp.value = v)
	p2.health_changed.connect(func(v, _m): p2_hp.value = v)
	p2.spirit_changed.connect(func(v, _m): p2_sp.value = v)
	p1.died.connect(_on_fighter_died)
	p2.died.connect(_on_fighter_died)
	p1_hp.value = p1.health
	p1_sp.value = p1.spirit
	p2_hp.value = p2.health
	p2_sp.value = p2.spirit

func _process(delta: float) -> void:
	if round_over:
		return
	time_left -= delta
	timer_label.text = str(maxi(0, int(ceil(time_left))))
	if time_left <= 0.0:
		_time_up()

func _on_fighter_died(f) -> void:
	if round_over:
		return
	var winner = p2 if f == p1 else p1
	_end_round("K.O.！\n%s 获胜！" % winner.fighter_name)

func _time_up() -> void:
	if p1.health == p2.health:
		_end_round("时间到\n平局！")
	else:
		var winner = p1 if p1.health > p2.health else p2
		_end_round("时间到\n%s 获胜！" % winner.fighter_name)

func _end_round(text: String) -> void:
	round_over = true
	p1.locked = true
	p2.locked = true
	banner.text = text + "\n\n[R] 再来一局"
	banner.visible = true

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_R:
			Engine.time_scale = 1.0
			get_tree().reload_current_scene()
