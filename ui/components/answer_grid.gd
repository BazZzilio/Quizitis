class_name AnswerGrid
extends ScrollContainer

signal option_selected(index: int)

const WORDWALL_COLORS: Array[Color] = [
	Color("#3B88C3"),
	Color("#E67E22"),
	Color("#27AE60"),
	Color("#8E44AD"),
	Color("#E74C3C"),
	Color("#16A085"),
	Color("#F39C12"),
	Color("#2C3E50"),
]

# Доля ячейки, которую занимает карточка при включённом убегании (остальное — место для уворота).
const MODERN_EVADE_INSET := Vector2(0.72, 0.84)
const WORDWALL_EVADE_INSET := Vector2(0.80, 0.80)
const FLIP_COMMIT_SEC := 0.35

var current_buttons: Array[Button] = []
var internal_grid: GridContainer

var _slots: Array[Control] = []
var _movers: Array[Control] = []
var _offsets: Array[Vector2] = []
var _evasive: Array[bool] = []
var _flip_targets: Array[Vector2] = []
var _flip_timers: Array[float] = []

var _wordle_host: CenterContainer
var _wordle_rows: VBoxContainer
var _layout_is_wordle := false
var _has_evasion := false
var _evasion_mult := 1.0
var _cell_gap := 16.0
var _image_base := ""
var _tex_cache: Dictionary = {}

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	clip_contents = false
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	if not resized.is_connected(_on_resized):
		resized.connect(_on_resized)
	set_process(false)

func _on_resized() -> void:
	if _layout_is_wordle:
		_fit_wordle_tiles()
	else:
		_fit_modern_grid()

func _clear_layout() -> void:
	set_process(false)
	for child in get_children():
		remove_child(child)
		child.queue_free()
	current_buttons.clear()
	_slots.clear()
	_movers.clear()
	_offsets.clear()
	_evasive.clear()
	_flip_targets.clear()
	_flip_timers.clear()
	internal_grid = null
	_wordle_host = null
	_wordle_rows = null
	_has_evasion = false

func display_options(options: Array, quiz_manager: QuizManager, forced_layout: String = "auto") -> void:
	var selected_style = QuizBehaviorSettings.CardStyle.MODERN
	_evasion_mult = 1.0
	if quiz_manager and quiz_manager.settings:
		selected_style = quiz_manager.settings.card_style
		_evasion_mult = quiz_manager.settings.evasion_force_multiplier

	_image_base = ""
	if quiz_manager and quiz_manager.current_file_path != "":
		_image_base = quiz_manager.current_file_path.get_base_dir()

	_clear_layout()

	# Считаем один раз: в режиме «шанс 20%» повторный вызов дал бы другой результат.
	var evade_flags: Array[bool] = []
	for i in range(options.size()):
		var evade := quiz_manager != null and quiz_manager.should_option_evade(i)
		evade_flags.append(evade)
		if evade:
			_has_evasion = true

	if selected_style == QuizBehaviorSettings.CardStyle.WORDLE:
		_build_wordwall(options, evade_flags)
	else:
		_build_modern(options, forced_layout, evade_flags)

	_on_resized.call_deferred()
	set_process(_has_evasion)

# --- СОВРЕМЕННЫЙ: прямоугольники на всю ширину ---
func _build_modern(options: Array, forced_layout: String, evade_flags: Array[bool]) -> void:
	_layout_is_wordle = false
	custom_minimum_size = Vector2.ZERO
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var margin = MarginContainer.new()
	margin.name = "ModernHost"
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_SHRINK_END
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)

	internal_grid = GridContainer.new()
	internal_grid.name = "InternalGridContainer"
	internal_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(internal_grid)

	var total_opts = options.size()
	if forced_layout == "grid_2":
		internal_grid.columns = 2
	elif forced_layout == "single":
		internal_grid.columns = 1
	else:
		internal_grid.columns = 2 if total_opts > 4 else 1

	_cell_gap = 24.0 if _has_evasion else 14.0
	internal_grid.add_theme_constant_override("h_separation", int(_cell_gap))
	internal_grid.add_theme_constant_override("v_separation", int(_cell_gap))

	for i in range(total_opts):
		var btn = Button.new()
		_apply_modern_rect_style(btn)
		var slot = _create_card(btn, _option_text(options[i]), i, evade_flags[i], false, _option_texture(options[i]))
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		internal_grid.add_child(slot)

func _fit_modern_grid() -> void:
	if not is_instance_valid(internal_grid) or _slots.is_empty():
		return
	var cols: int = max(internal_grid.columns, 1)
	var rows := int(ceil(float(_slots.size()) / float(cols)))
	var pictured := _any_option_picture()
	var usable_h := get_viewport_rect().size.y * (0.52 if pictured else 0.45)

	var desired_h := 120.0 if pictured else 86.0
	if not pictured and _slots.size() > 6:
		desired_h = 60.0
	elif not pictured and _slots.size() > 4:
		desired_h = 72.0
	var card_h := floorf((usable_h - _cell_gap * float(rows - 1)) / float(rows))
	if pictured:
		card_h = clampf(minf(card_h, desired_h), 84.0, 148.0)
	else:
		card_h = clampf(minf(card_h, desired_h), 50.0, 96.0)

	var font_sz := 18
	if card_h < 62.0:
		font_sz = 14
	elif card_h < 76.0:
		font_sz = 16
	elif pictured and card_h < 110.0:
		font_sz = 16

	for i in range(_slots.size()):
		_slots[i].custom_minimum_size = Vector2(0, card_h)
		current_buttons[i].add_theme_font_size_override("font_size", font_sz)
		var caption := _caption_of(current_buttons[i])
		if caption:
			caption.add_theme_font_size_override("font_size", font_sz)
		var pic := _picture_of(current_buttons[i])
		if pic:
			pic.custom_minimum_size = Vector2(card_h - 16.0, 0)

# --- WORDWALL: цветные квадраты по центру ---
func _build_wordwall(options: Array, evade_flags: Array[bool]) -> void:
	_layout_is_wordle = true
	custom_minimum_size = Vector2(0, 220)
	# Здесь размер плиток считается от доступного места, поэтому минимум контента наружу не пробрасываем.
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER

	_wordle_host = CenterContainer.new()
	_wordle_host.name = "WordleCenterHost"
	_wordle_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wordle_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_wordle_host)

	_wordle_rows = VBoxContainer.new()
	_wordle_rows.name = "WordleRows"
	_wordle_rows.alignment = BoxContainer.ALIGNMENT_CENTER
	_wordle_host.add_child(_wordle_rows)

	var columns := _wordle_columns(options.size())
	var current_row: HBoxContainer = null
	for i in range(options.size()):
		if i % columns == 0:
			current_row = HBoxContainer.new()
			current_row.alignment = BoxContainer.ALIGNMENT_CENTER
			_wordle_rows.add_child(current_row)
		var btn = Button.new()
		_apply_wordwall_tile_style(btn, i)
		current_row.add_child(_create_card(btn, _option_text(options[i]), i, evade_flags[i], true, _option_texture(options[i])))

func _fit_wordle_tiles() -> void:
	if not is_instance_valid(_wordle_host) or _slots.is_empty():
		return
	var columns := _wordle_columns(_slots.size())
	var rows := int(ceil(float(_slots.size()) / float(columns)))
	var pad := 20.0
	var avail_w := maxf(80.0, size.x - pad * 2.0)
	var avail_h := maxf(80.0, size.y - pad * 2.0)

	_cell_gap = clampf(minf(avail_w, avail_h) * 0.04, 12.0, 22.0)
	var side_w := (avail_w - _cell_gap * float(columns - 1)) / float(columns)
	var side_h := (avail_h - _cell_gap * float(rows - 1)) / float(rows)
	var max_side := 250.0 if _any_option_picture() else 210.0
	var side := clampf(floorf(minf(side_w, side_h)), 64.0, max_side)

	var tile_side := side * (WORDWALL_EVADE_INSET.x if _has_evasion else 1.0)
	var font_sz := clampi(int(tile_side * 0.15), 14, 30)
	var caption_sz := clampi(int(tile_side * 0.12), 13, 22)

	_wordle_rows.add_theme_constant_override("separation", int(_cell_gap))
	for row in _wordle_rows.get_children():
		(row as HBoxContainer).add_theme_constant_override("separation", int(_cell_gap))
	for i in range(_slots.size()):
		_slots[i].custom_minimum_size = Vector2(side, side)
		current_buttons[i].add_theme_font_size_override("font_size", font_sz)
		var caption := _caption_of(current_buttons[i])
		if caption:
			caption.add_theme_font_size_override("font_size", caption_sz)
			caption.custom_minimum_size = Vector2(0, clampf(tile_side * 0.22, 26.0, 46.0))

	_wordle_host.custom_minimum_size = Vector2.ZERO
	var cluster := _wordle_rows.get_combined_minimum_size()
	_wordle_host.custom_minimum_size = Vector2(maxf(cluster.x, size.x), maxf(cluster.y, size.y))

func _wordle_columns(total_opts: int) -> int:
	if total_opts <= 4:
		return 2
	if total_opts <= 6:
		return 3
	return 4

# --- Общая сборка карточки: slot (раскладывает контейнер) → mover (уворот) → button (анимации) ---
func _create_card(btn: Button, opt_text: String, index: int, evasive: bool, is_wordwall: bool, texture: Texture2D = null) -> Control:
	var slot = Control.new()
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var mover = Control.new()
	mover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(mover)

	btn.text = opt_text
	if texture:
		_attach_option_image(btn, opt_text, texture, is_wordwall)
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn.clip_text = false
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(func(): option_selected.emit(index))
	mover.add_child(btn)
	btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	if not evasive:
		_enable_hover_zoom(btn, 1.04 if is_wordwall else 1.03)

	var card_index := _slots.size()
	_slots.append(slot)
	_movers.append(mover)
	_offsets.append(Vector2.ZERO)
	_evasive.append(evasive)
	_flip_targets.append(Vector2.ZERO)
	_flip_timers.append(0.0)
	current_buttons.append(btn)

	slot.resized.connect(func(): _layout_card(card_index))
	return slot

func _card_inset() -> Vector2:
	if not _has_evasion:
		return Vector2.ONE
	return WORDWALL_EVADE_INSET if _layout_is_wordle else MODERN_EVADE_INSET

func _card_base(slot: Control, mover_size: Vector2) -> Vector2:
	return (slot.size - mover_size) / 2.0

# Максимальный сдвиг: своя ячейка плюс половина зазора — соседние карточки физически не пересекаются.
func _max_offset(slot: Control, mover_size: Vector2) -> Vector2:
	var reach := maxf(_cell_gap * 0.5 - 2.0, 0.0)
	return _card_base(slot, mover_size) + Vector2(reach, reach)

func _layout_card(i: int) -> void:
	if i < 0 or i >= _slots.size():
		return
	var slot := _slots[i]
	var mover := _movers[i]
	if not is_instance_valid(slot) or not is_instance_valid(mover):
		return
	mover.size = (slot.size * _card_inset()).floor()
	mover.pivot_offset = mover.size / 2.0
	var max_off := _max_offset(slot, mover.size)
	_offsets[i] = _offsets[i].clamp(-max_off, max_off)
	mover.position = _card_base(slot, mover.size) + _offsets[i]
	var btn := current_buttons[i]
	if is_instance_valid(btn):
		btn.pivot_offset = mover.size / 2.0

func clear_cards() -> void:
	_clear_layout()

func disable_all() -> void:
	set_process(false)
	for btn in current_buttons:
		if is_instance_valid(btn):
			btn.disabled = true

func _process(delta: float) -> void:
	var chase := 1.0 - exp(-(10.0 + 6.0 * _evasion_mult) * delta)
	var settle := 1.0 - exp(-5.0 * delta)

	for i in range(_slots.size()):
		if not _evasive[i]:
			continue
		var slot := _slots[i]
		var mover := _movers[i]
		var btn := current_buttons[i]
		if not is_instance_valid(slot) or not is_instance_valid(btn) or btn.disabled:
			continue

		var max_off := _max_offset(slot, mover.size)
		var offset := _offsets[i]
		var target := Vector2.ZERO

		if _flip_timers[i] > 0.0:
			_flip_timers[i] -= delta
			target = _flip_targets[i]
		else:
			var mouse := slot.get_local_mouse_position()
			var center := slot.size / 2.0 + offset
			var radius := mover.size.length() * 0.5 + 40.0 * _evasion_mult
			var dist := center.distance_to(mouse)
			if dist < radius:
				var away := (center - mouse) / dist if dist > 0.5 else Vector2.RIGHT.rotated(randf() * TAU)
				target = (mouse + away * radius - slot.size / 2.0).clamp(-max_off, max_off)
				# Прижали к краю — перепрыгиваем на противоположную сторону ячейки.
				var cornered_center := slot.size / 2.0 + target
				if cornered_center.distance_to(mouse) < radius * 0.55:
					var flip := Vector2(
						-signf(target.x) * max_off.x if absf(target.x) > max_off.x * 0.6 else target.x,
						-signf(target.y) * max_off.y if absf(target.y) > max_off.y * 0.6 else target.y
					)
					_flip_targets[i] = flip
					_flip_timers[i] = FLIP_COMMIT_SEC
					target = flip

		var weight := settle if target == Vector2.ZERO else chase
		offset = offset.lerp(target, weight).clamp(-max_off, max_off)
		_offsets[i] = offset
		mover.position = _card_base(slot, mover.size) + offset
		mover.rotation = lerpf(mover.rotation, clampf((target.x - offset.x) * 0.004, -0.14, 0.14), chase)

func _any_option_picture() -> bool:
	for btn in current_buttons:
		if _picture_of(btn):
			return true
	return false

func _picture_of(btn: Button) -> TextureRect:
	return btn.find_child("Picture", true, false) as TextureRect

func _caption_of(btn: Button) -> Label:
	return btn.find_child("Caption", true, false) as Label

func _option_texture(raw_opt) -> Texture2D:
	var img_name := ""
	if raw_opt is Dictionary:
		img_name = str(raw_opt.get("image", "")).strip_edges()
	if img_name == "":
		return null
	var paths: Array[String] = [img_name]
	if _image_base != "":
		paths.append(_image_base.path_join(img_name))
	for path in paths:
		if _tex_cache.has(path):
			var cached: Variant = _tex_cache[path]
			return cached if cached is Texture2D else null
		if FileAccess.file_exists(path):
			var img := Image.load_from_file(path)
			if img:
				var tex := ImageTexture.create_from_image(img)
				_tex_cache[path] = tex
				return tex
	return null

func _attach_option_image(btn: Button, opt_text: String, texture: Texture2D, is_wordwall: bool) -> void:
	btn.text = ""
	var host := MarginContainer.new()
	host.name = "OptionBody"
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_theme_constant_override("margin_left", 8)
	host.add_theme_constant_override("margin_top", 8)
	host.add_theme_constant_override("margin_right", 8 if is_wordwall else 10)
	host.add_theme_constant_override("margin_bottom", 16 if is_wordwall else 8)

	var box := BoxContainer.new()
	box.vertical = is_wordwall
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6 if is_wordwall else 12)

	var pic := TextureRect.new()
	pic.name = "Picture"
	pic.texture = texture
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pic.size_flags_horizontal = Control.SIZE_EXPAND_FILL if is_wordwall else Control.SIZE_SHRINK_CENTER

	var caption := Label.new()
	caption.name = "Caption"
	caption.text = opt_text
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.add_theme_color_override("font_color", Color.WHITE)
	caption.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	caption.add_theme_constant_override("outline_size", 4)
	if is_wordwall:
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		caption.custom_minimum_size = Vector2(0, 28)
	else:
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		caption.size_flags_vertical = Control.SIZE_EXPAND_FILL

	box.add_child(pic)
	box.add_child(caption)
	host.add_child(box)
	btn.add_child(host)

func _option_text(raw_opt) -> String:
	var opt_text := ""
	if raw_opt is Dictionary:
		opt_text = str(raw_opt.get("text", raw_opt.get("answer", raw_opt.get("option", ""))))
	else:
		opt_text = str(raw_opt)
	return opt_text.strip_edges()

func _apply_modern_rect_style(btn: Button) -> void:
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.7))

	var style_norm := _fancy_answer_box(
		Color("#2b2d42"), 22, 2,
		[Color("#ffb703"), Color("#1a1c2e")],
		[5, 3], 14, Vector2(0, 5)
	)
	var style_hover := _fancy_answer_box(
		Color("#3d405b"), 22, 2,
		[Color("#00f5d4"), Color("#ffb703")],
		[5, 3], 14, Vector2(0, 3)
	)
	var style_press := _fancy_answer_box(
		Color("#242636"), 22, 2,
		[Color("#fb8500"), Color("#12131f")],
		[4, 3], 14, Vector2(0, 1)
	)
	var style_disabled := _fancy_answer_box(
		Color("#24263a"), 22, 2,
		[Color("#6b5a32"), Color("#1a1c2e")],
		[4, 2], 14, Vector2(0, 2)
	)
	btn.add_theme_stylebox_override("normal", style_norm)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_press)
	btn.add_theme_stylebox_override("focus", style_hover)
	btn.add_theme_stylebox_override("disabled", style_disabled)

func _apply_wordwall_tile_style(btn: Button, index: int) -> void:
	var fill: Color = WORDWALL_COLORS[index % WORDWALL_COLORS.size()]
	var edge := fill.darkened(0.22)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	btn.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.75))
	btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.35))
	btn.add_theme_constant_override("outline_size", 5)

	var rim := fill.lightened(0.35)
	var style_norm := _fancy_answer_box(fill, 20, 2, [edge, rim], [4, 2], 12, Vector2(0, 6), 8)
	var style_hover := _fancy_answer_box(fill.lightened(0.08), 20, 2, [Color.WHITE, rim], [5, 2], 12, Vector2(0, 4), 10)
	var style_press := _fancy_answer_box(fill.darkened(0.1), 20, 2, [edge, fill.darkened(0.2)], [3, 2], 12, Vector2(0, 1), 3)
	var style_disabled := _fancy_answer_box(fill.darkened(0.28), 20, 2, [edge.darkened(0.2), edge], [3, 2], 12, Vector2(0, 2), 4)
	btn.add_theme_stylebox_override("normal", style_norm)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_press)
	btn.add_theme_stylebox_override("focus", style_hover)
	btn.add_theme_stylebox_override("disabled", style_disabled)

func _fancy_answer_box(bg: Color, radius: int, curvature: int, border_colors: Array[Color], border_widths: Array[int], margin: int, shadow_offset: Vector2, bottom_extra: int = 0) -> StyleBoxFancy:
	var box := StyleBoxFancy.new()
	box.color = bg
	box.corner_detail = 10
	box.set_corner_radius_all(radius)
	box.set_corner_curvature_all(curvature)
	box.shadow_enabled = true
	box.shadow_color = Color(0, 0, 0, 0.38)
	box.shadow_blur = 10
	box.shadow_offset = shadow_offset
	box.content_margin_left = margin
	box.content_margin_right = margin
	box.content_margin_top = margin
	box.content_margin_bottom = margin + bottom_extra
	var stack: Array[StyleBorder] = []
	for i in range(border_colors.size()):
		var border := StyleBorder.new()
		border.color = border_colors[i]
		border.set_width_all(border_widths[i])
		if i == 0 and bottom_extra > 0:
			border.width_bottom = border_widths[i] + bottom_extra
		stack.append(border)
	box.borders = stack
	return box

func _enable_hover_zoom(btn: Button, zoom: float) -> void:
	btn.mouse_entered.connect(func():
		if btn.disabled: return
		create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)\
			.tween_property(btn, "scale", Vector2(zoom, zoom), 0.1)
	)
	btn.mouse_exited.connect(func():
		if btn.disabled: return
		create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)\
			.tween_property(btn, "scale", Vector2.ONE, 0.1)
	)
