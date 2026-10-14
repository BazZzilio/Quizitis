class_name QuizAnimator
extends Node

enum QuestionAnimStyle {
	BOUNCE_DOWN,
	ZOOM_IN,
	SLIDE_LEFT
}

enum CardAnimStyle {
	BOUNCE_CASCADE,
	FLIP_IN,
	SLIDE_UP,
	SCALE_POP
}

enum VictoryAnimStyle {
	CONFETTI,
	FIREWORKS,
	STAR_RAIN,
	BALLOONS,
	SPARKLE_RING
}

static var _last_victory: int = -1

# 1. Запуск случайной анимации появления вопроса
static func play_random_question_intro(question_label: Control, image_rect: Control, cards_container: Control) -> void:
	var q_style = QuestionAnimStyle.values().pick_random()
	var card_style = CardAnimStyle.values().pick_random()
	
	_animate_question(question_label, q_style)
	_animate_image(image_rect)
	_animate_cards(cards_container, card_style)

# 2. Случайный финал после квиза. Салют остаётся одним из вариантов.
static func play_random_victory(target_node: Node) -> void:
	if not is_instance_valid(target_node): return
	var styles := VictoryAnimStyle.values()
	var pick: int = styles.pick_random()
	var guard := 0
	while pick == _last_victory and styles.size() > 1 and guard < 8:
		pick = styles.pick_random()
		guard += 1
	_last_victory = pick

	var layer := _begin_celebration(target_node)
	var viewport := target_node.get_viewport().get_visible_rect().size
	var tree := target_node.get_tree()
	match pick:
		VictoryAnimStyle.CONFETTI:
			_spawn_confetti(layer, viewport, tree)
		VictoryAnimStyle.FIREWORKS:
			_spawn_fireworks(layer, viewport, tree)
		VictoryAnimStyle.STAR_RAIN:
			_spawn_star_rain(layer, viewport)
		VictoryAnimStyle.BALLOONS:
			_spawn_balloons(layer, viewport)
		VictoryAnimStyle.SPARKLE_RING:
			_spawn_sparkle_ring(layer, viewport, tree)
	_free_celebration(tree, layer, 6.5)

static func spawn_confetti_burst(target_node: Node) -> void:
	play_random_victory(target_node)

static func _begin_celebration(target_node: Node) -> CanvasLayer:
	if target_node.has_meta(&"victory_fx"):
		var previous: Variant = target_node.get_meta(&"victory_fx")
		# «is» на уже удалённом узле роняет игру; is_instance_valid для него просто false.
		if is_instance_valid(previous):
			(previous as Node).queue_free()
		target_node.remove_meta(&"victory_fx")
	var canvas_layer := CanvasLayer.new()
	canvas_layer.layer = 100
	target_node.add_child(canvas_layer)
	target_node.set_meta(&"victory_fx", canvas_layer)
	return canvas_layer

static func _free_celebration(tree: SceneTree, canvas_layer: CanvasLayer, after_sec: float) -> void:
	tree.create_timer(after_sec).timeout.connect(func():
		if not is_instance_valid(canvas_layer):
			return
		var owner := canvas_layer.get_parent()
		if is_instance_valid(owner) and owner.has_meta(&"victory_fx"):
			owner.remove_meta(&"victory_fx")
		canvas_layer.queue_free()
	)

static func _party_gradient() -> Gradient:
	var gradient := Gradient.new()
	gradient.add_point(0.0, Color("#ff0054"))
	gradient.add_point(0.2, Color("#ffb703"))
	gradient.add_point(0.4, Color("#06d6a0"))
	gradient.add_point(0.6, Color("#118ab2"))
	gradient.add_point(0.8, Color("#7209b7"))
	gradient.add_point(1.0, Color("#f72585"))
	return gradient

static func _spawn_confetti(canvas_layer: CanvasLayer, viewport_size: Vector2, tree: SceneTree) -> void:
	
	# Точки спавна 4-х батарей салюта
	var spawn_configs = [
		{"pos": Vector2(viewport_size.x * 0.1, viewport_size.y * 0.95), "dir": Vector2(0.5, -1.0)},
		{"pos": Vector2(viewport_size.x * 0.9, viewport_size.y * 0.95), "dir": Vector2(-0.5, -1.0)},
		{"pos": Vector2(viewport_size.x * 0.05, viewport_size.y * 0.6), "dir": Vector2(1.0, -0.6)},
		{"pos": Vector2(viewport_size.x * 0.95, viewport_size.y * 0.6), "dir": Vector2(-1.0, -0.6)}
	]
	
	# Запуск в 2 волны с задержкой
	for wave in range(2):
		var wave_delay = wave * 0.35
		
		for config in spawn_configs:
			var particles = CPUParticles2D.new()
			particles.position = config["pos"]
			particles.amount = 120
			particles.lifetime = 4.0
			particles.one_shot = true
			particles.explosiveness = 0.9
			
			# Физика разлёта
			particles.direction = config["dir"]
			particles.spread = 55.0
			particles.gravity = Vector2(0, 380)
			particles.initial_velocity_min = 500.0
			particles.initial_velocity_max = 850.0
			particles.angular_velocity_min = -360.0
			particles.angular_velocity_max = 360.0
			particles.scale_amount_min = 10.0
			particles.scale_amount_max = 22.0
			particles.color_ramp = _party_gradient()
			
			tree.create_timer(wave_delay).timeout.connect(func():
				if is_instance_valid(canvas_layer):
					canvas_layer.add_child(particles)
					particles.emitting = true
			)

static func _spawn_fireworks(canvas_layer: CanvasLayer, viewport_size: Vector2, tree: SceneTree) -> void:
	var colors: Array[Color] = [
		Color("#ffd166"), Color("#ef476f"), Color("#06d6a0"),
		Color("#118ab2"), Color("#f72585"), Color("#ffb703"), Color("#ffffff")
	]
	for i in range(7):
		var delay := i * 0.32
		var burst_pos := Vector2(
			randf_range(viewport_size.x * 0.12, viewport_size.x * 0.88),
			randf_range(viewport_size.y * 0.1, viewport_size.y * 0.48)
		)
		var burst_color: Color = colors[i % colors.size()]
		tree.create_timer(delay).timeout.connect(func():
			if not is_instance_valid(canvas_layer):
				return
			var burst := CPUParticles2D.new()
			burst.position = burst_pos
			burst.amount = 90
			burst.lifetime = 1.6
			burst.one_shot = true
			burst.explosiveness = 1.0
			burst.direction = Vector2(0, -1)
			burst.spread = 180.0
			burst.gravity = Vector2(0, 90)
			burst.initial_velocity_min = 180.0
			burst.initial_velocity_max = 420.0
			burst.scale_amount_min = 5.0
			burst.scale_amount_max = 12.0
			burst.angular_velocity_min = -240.0
			burst.angular_velocity_max = 240.0
			var ramp := Gradient.new()
			ramp.add_point(0.0, Color.WHITE)
			ramp.add_point(0.25, burst_color)
			ramp.add_point(1.0, Color(burst_color.r, burst_color.g, burst_color.b, 0.0))
			burst.color_ramp = ramp
			canvas_layer.add_child(burst)
			burst.emitting = true
		)

static func _spawn_star_rain(canvas_layer: CanvasLayer, viewport_size: Vector2) -> void:
	var rain := CPUParticles2D.new()
	rain.position = Vector2(viewport_size.x * 0.5, -30.0)
	rain.amount = 70
	rain.lifetime = 5.2
	rain.explosiveness = 0.15
	rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	rain.emission_rect_extents = Vector2(viewport_size.x * 0.52, 8.0)
	rain.direction = Vector2(0.15, 1.0)
	rain.spread = 16.0
	rain.gravity = Vector2(0, 30)
	rain.initial_velocity_min = 90.0
	rain.initial_velocity_max = 190.0
	rain.angular_velocity_min = -140.0
	rain.angular_velocity_max = 140.0
	rain.scale_amount_min = 7.0
	rain.scale_amount_max = 16.0
	var ramp := Gradient.new()
	ramp.add_point(0.0, Color("#fff6d6"))
	ramp.add_point(0.45, Color("#ffd166"))
	ramp.add_point(1.0, Color("#ffffff"))
	rain.color_ramp = ramp
	canvas_layer.add_child(rain)
	rain.emitting = true

static func _spawn_balloons(canvas_layer: CanvasLayer, viewport_size: Vector2) -> void:
	var colors: Array[Color] = [
		Color("#ef476f"), Color("#ffd166"), Color("#06d6a0"),
		Color("#118ab2"), Color("#7209b7"), Color("#f72585")
	]
	for i in range(14):
		var side := randf_range(28.0, 52.0)
		var balloon := Panel.new()
		balloon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		balloon.size = Vector2(side, side * 1.15)
		var style := StyleBoxFlat.new()
		style.bg_color = colors[i % colors.size()]
		style.set_corner_radius_all(int(side))
		style.shadow_color = Color(0, 0, 0, 0.25)
		style.shadow_size = 4
		balloon.add_theme_stylebox_override("panel", style)
		var start_x := randf_range(viewport_size.x * 0.04, viewport_size.x * 0.92)
		balloon.position = Vector2(start_x, viewport_size.y + randf_range(20.0, 220.0))
		canvas_layer.add_child(balloon)
		var duration := randf_range(3.6, 5.6)
		balloon.create_tween().tween_property(
			balloon, "position",
			Vector2(start_x + randf_range(-80.0, 80.0), -140.0),
			duration
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

static func _spawn_sparkle_ring(canvas_layer: CanvasLayer, viewport_size: Vector2, tree: SceneTree) -> void:
	var origin := Vector2(viewport_size.x * 0.5, viewport_size.y * 0.38)
	for ring in range(3):
		var delay := ring * 0.45
		tree.create_timer(delay).timeout.connect(func():
			if not is_instance_valid(canvas_layer):
				return
			var burst := CPUParticles2D.new()
			burst.position = origin
			burst.amount = 110
			burst.lifetime = 1.35
			burst.one_shot = true
			burst.explosiveness = 1.0
			burst.direction = Vector2.RIGHT
			burst.spread = 180.0
			burst.gravity = Vector2.ZERO
			burst.initial_velocity_min = 220.0 + ring * 80.0
			burst.initial_velocity_max = 280.0 + ring * 90.0
			burst.scale_amount_min = 4.0
			burst.scale_amount_max = 9.0
			burst.damping_min = 80.0
			burst.damping_max = 140.0
			burst.color_ramp = _party_gradient()
			canvas_layer.add_child(burst)
			burst.emitting = true
		)

# --- АНИМАЦИИ ВОПРОСА ---
static func _animate_question(label: Control, style: QuestionAnimStyle) -> void:
	if not is_instance_valid(label): return
	label.pivot_offset = label.size / 2.0
	
	match style:
		QuestionAnimStyle.BOUNCE_DOWN:
			label.scale = Vector2(0.3, 0.3)
			label.modulate.a = 0.0
			var tween = label.create_tween().set_parallel(true)
			tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.35)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(label, "modulate:a", 1.0, 0.2)
			
		QuestionAnimStyle.ZOOM_IN:
			label.scale = Vector2(1.3, 1.3)
			label.modulate.a = 0.0
			var tween = label.create_tween().set_parallel(true)
			tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.3)\
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.tween_property(label, "modulate:a", 1.0, 0.2)
			
		QuestionAnimStyle.SLIDE_LEFT:
			var orig_pos = label.position
			label.position.x -= 150.0
			label.modulate.a = 0.0
			var tween = label.create_tween().set_parallel(true)
			tween.tween_property(label, "position:x", orig_pos.x, 0.35)\
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(label, "modulate:a", 1.0, 0.25)

# --- АНИМАЦИЯ ИЛЛЮСТРАЦИИ ---
static func _animate_image(image_rect: Control) -> void:
	if not is_instance_valid(image_rect) or not image_rect.visible: return
	
	image_rect.pivot_offset = image_rect.size / 2.0
	image_rect.scale = Vector2(0.0, 0.0)
	image_rect.rotation_degrees = [-10.0, 10.0, -5.0, 5.0].pick_random()
	
	var tween = image_rect.create_tween().set_parallel(true)
	tween.tween_property(image_rect, "scale", Vector2(1.0, 1.0), 0.4)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(image_rect, "rotation_degrees", 0.0, 0.3)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

# --- АНИМАЦИИ КАРТОЧЕК ---
static func _animate_cards(container: Control, style: CardAnimStyle) -> void:
	if not is_instance_valid(container): return

	var cards: Array = []
	if container is AnswerGrid and not (container as AnswerGrid).current_buttons.is_empty():
		for btn in (container as AnswerGrid).current_buttons:
			if is_instance_valid(btn):
				cards.append(btn)
	else:
		cards = container.get_children()

	var delay = 0.0
	for i in range(cards.size()):
		var card = cards[i] as Control
		if not is_instance_valid(card): continue

		match style:
			CardAnimStyle.BOUNCE_CASCADE:
				_card_bounce(card, delay)
			CardAnimStyle.FLIP_IN:
				_card_flip(card, delay)
			CardAnimStyle.SLIDE_UP:
				_card_slide(card, delay)
			CardAnimStyle.SCALE_POP:
				_card_pop(card, delay)

		delay += 0.07

static func _card_bounce(card: Control, delay: float) -> void:
	card.pivot_offset = card.size / 2.0
	card.scale = Vector2(0.0, 0.0)
	card.modulate.a = 0.0
	var tween = card.create_tween().set_parallel(true)
	tween.tween_property(card, "scale", Vector2(1.0, 1.0), 0.38)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)
	tween.tween_property(card, "modulate:a", 1.0, 0.2).set_delay(delay)

static func _card_flip(card: Control, delay: float) -> void:
	card.pivot_offset = card.size / 2.0
	card.scale = Vector2(0.0, 1.0)
	card.modulate.a = 0.0
	var tween = card.create_tween().set_parallel(true)
	tween.tween_property(card, "scale", Vector2(1.0, 1.0), 0.32)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(delay)
	tween.tween_property(card, "modulate:a", 1.0, 0.2).set_delay(delay)

static func _card_slide(card: Control, delay: float) -> void:
	var base_pos = card.position
	card.position.y += 100.0
	card.modulate.a = 0.0
	var tween = card.create_tween().set_parallel(true)
	tween.tween_property(card, "position:y", base_pos.y, 0.32)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_delay(delay)
	tween.tween_property(card, "modulate:a", 1.0, 0.2).set_delay(delay)

static func _card_pop(card: Control, delay: float) -> void:
	card.pivot_offset = card.size / 2.0
	card.scale = Vector2(1.12, 1.12)
	card.modulate.a = 0.0
	var tween = card.create_tween().set_parallel(true)
	tween.tween_property(card, "scale", Vector2(1.0, 1.0), 0.28)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)
	tween.tween_property(card, "modulate:a", 1.0, 0.18).set_delay(delay)
