extends Node3D

# Сцены из assets/background. Полёт камеры — в background_camera.gd.

const BACKGROUNDS: Array[Dictionary] = [
	{
		"label": "🌲 Night Forest",
		"path": "res://assets/background/Night Forest.glb",
		"sky": Color("#070d18"),
		"horizon": Color("#1a2744"),
		"sun": Color("#c5d4f0"),
		"energy": 0.42,
		"ambient": 0.38,
	},
	{
		"label": "⛰️ Mountain Forest",
		"path": "res://assets/background/Mountain Forest.glb",
		"sky": Color("#8eb7df"),
		"horizon": Color("#d5e6f5"),
		"sun": Color("#fff4e0"),
		"energy": 1.2,
		"ambient": 0.85,
	},
	{
		"label": "🏙 Toy City",
		"path": "res://assets/background/Toy city.glb",
		"sky": Color("#9ec8ef"),
		"horizon": Color("#f3e2c2"),
		"sun": Color("#fff8ee"),
		"energy": 1.15,
		"ambient": 0.9,
	},
	{
		"label": "🏁 Racing Dark",
		"path": "res://assets/background/Racing Dark.glb",
		"sky": Color("#070910"),
		"horizon": Color("#1c1230"),
		"sun": Color("#9eb0d8"),
		"energy": 0.5,
		"ambient": 0.32,
	},
]

var _camera: BackgroundCamera


func _ready() -> void:
	top_level = true
	_camera = get_node_or_null("Camera3D") as BackgroundCamera
	if _camera == null:
		_camera = BackgroundCamera.new()
		_camera.name = "Camera3D"
		add_child(_camera)
	show_background(-1)


func set_manual_flight(enabled: bool) -> void:
	if _camera:
		_camera.manual = enabled


func background_labels() -> PackedStringArray:
	var labels := PackedStringArray()
	for entry in BACKGROUNDS:
		labels.append(str(entry["label"]))
	return labels


# index < 0 — случайная сцена.
func show_background(index: int) -> void:
	if BACKGROUNDS.is_empty():
		return
	if index < 0 or index >= BACKGROUNDS.size():
		index = randi() % BACKGROUNDS.size()
	for child in get_children():
		if child == _camera:
			continue
		child.free()
	var entry: Dictionary = BACKGROUNDS[index]
	var scene_root := _instance_scene(str(entry["path"]))
	if scene_root == null:
		return
	_add_lighting(entry)
	if _camera:
		_camera.fly_around(_measure(scene_root))


func _instance_scene(path: String) -> Node3D:
	if not ResourceLoader.exists(path):
		push_error("QuizBackground: нет файла %s" % path)
		return null
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		push_error("QuizBackground: не удалось открыть %s" % path)
		return null
	var root := packed.instantiate() as Node3D
	if root == null:
		push_error("QuizBackground: корень сцены не Node3D: %s" % path)
		return null
	add_child(root)
	for node in root.find_children("*", "Camera3D", true, false):
		var cam := node as Camera3D
		if cam:
			cam.current = false
	return root


func _add_lighting(entry: Dictionary) -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	var sky_color: Color = entry["sky"]
	var horizon: Color = entry["horizon"]
	sky_mat.sky_top_color = sky_color
	sky_mat.sky_horizon_color = horizon
	sky_mat.ground_horizon_color = horizon.darkened(0.35)
	sky_mat.ground_bottom_color = sky_color.darkened(0.55)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = horizon
	env.ambient_light_energy = float(entry["ambient"])
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 28, 0)
	sun.light_color = entry["sun"]
	sun.light_energy = float(entry["energy"])
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 250.0
	add_child(sun)


func _measure(root: Node) -> AABB:
	var merged := AABB()
	var found := false
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var node: Node = pending.pop_back() as Node
		for child in node.get_children():
			pending.append(child)
		if node is GeometryInstance3D:
			var geo := node as GeometryInstance3D
			var local: AABB = geo.get_aabb()
			if local.size.length_squared() < 0.000001:
				continue
			var global_box: AABB = geo.global_transform * local
			if not found:
				merged = global_box
				found = true
			else:
				merged = merged.merge(global_box)
	if not found:
		return AABB(Vector3(-8, 0, -8), Vector3(16, 6, 16))
	return merged
