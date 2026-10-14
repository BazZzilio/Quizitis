class_name BackgroundCamera
extends Camera3D

# Полёт вокруг загруженной сцены. Меняй числа здесь.

var angular_speed := 0.1
var speed_wobble := 0.03
var radius_scale := 0.72
var min_radius := 3.0
var height_scale := 0.22
var height_from_span := 0.08
var breathe := 0.12
var height_base := 0.75
var height_bob := 0.28
var look_ahead := 0.2
var fov_degrees := 55.0
var near_clip := 0.05

# Ручной полёт: WASD, пробел вверх, Ctrl вниз, Shift быстрее, ПКМ — смотреть.
var manual := false
var fly_speed := 0.4
var fast_multiplier := 2.5
var mouse_sensitivity := 0.0025

var _center := Vector3.ZERO
var _orbit := 12.0
var _lift := 4.0
var _angle := 0.0


func fly_around(box: AABB) -> void:
	current = true
	fov = fov_degrees
	near = near_clip
	_center = box.get_center()
	var span := maxf(box.size.x, box.size.z)
	_orbit = maxf(span * radius_scale, box.size.y * 1.15)
	_orbit = maxf(_orbit, min_radius)
	_lift = maxf(box.size.y * height_scale, span * height_from_span)
	far = maxf(_orbit * 8.0, 200.0)
	_angle = randf() * TAU
	_place()


func _process(delta: float) -> void:
	if manual:
		_fly_manual(delta)
		return
	_angle += delta * (angular_speed + speed_wobble * sin(_angle * 0.37))
	_place()


func _input(event: InputEvent) -> void:
	if not manual:
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		var code := key.physical_keycode
		if code == KEY_W or code == KEY_A or code == KEY_S or code == KEY_D or code == KEY_SPACE or code == KEY_CTRL or code == KEY_SHIFT:
			get_viewport().set_input_as_handled()
	if not (event is InputEventMouseMotion):
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		return
	var motion := event as InputEventMouseMotion
	rotate_y(-motion.relative.x * mouse_sensitivity)
	rotate_object_local(Vector3.RIGHT, -motion.relative.y * mouse_sensitivity)
	rotation.x = clampf(rotation.x, deg_to_rad(-85.0), deg_to_rad(85.0))


func _fly_manual(delta: float) -> void:
	var direction := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		direction.z -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		direction.z += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		direction.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		direction.x += 1.0
	if Input.is_physical_key_pressed(KEY_SPACE):
		direction.y += 1.0
	if Input.is_physical_key_pressed(KEY_CTRL):
		direction.y -= 1.0
	if direction.length_squared() < 0.001:
		return
	var speed := maxf(_orbit, min_radius) * fly_speed
	if Input.is_physical_key_pressed(KEY_SHIFT):
		speed *= fast_multiplier
	global_position += global_transform.basis * direction.normalized() * speed * delta


func _place() -> void:
	var radius := _orbit * ((1.0 - breathe) + breathe * sin(_angle * 0.65))
	var height := _lift * (height_base + height_bob * sin(_angle * 0.5))
	var pos := Vector3(_center.x + cos(_angle) * radius, _center.y + height, _center.z + sin(_angle) * radius)
	global_position = pos
	var look := _center.lerp(pos, look_ahead)
	look.y = _center.y + _lift * 0.05
	if pos.distance_squared_to(look) < 0.01:
		look += Vector3(0, 0, -1)
	look_at(look, Vector3.UP)
