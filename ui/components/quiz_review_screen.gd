class_name QuizReviewScreen
extends CanvasLayer

signal review_closed

var root_control: Control
var review_scroll: ScrollContainer
var review_vbox: VBoxContainer

# Контейнер для подробного просмотра выбранного вопроса
var detail_view: VBoxContainer
var detail_question_label: Label
var detail_image_rect: TextureRect
var detail_answers_grid: GridContainer
var back_to_list_button: Button

# Постоянная нижняя панель с кнопкой закрытия
var bottom_bar: HBoxContainer
var close_review_button: Button

var current_history: Array = []
var base_file_path: String = ""

func _ready() -> void:
	visible = false
	layer = 100
	_build_ui()

func _build_ui() -> void:
	root_control = Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(root_control)

	# 1. Тёмный полупрозрачный фон
	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.12, 0.98)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	root_control.add_child(bg)

	# 2. Скролл-контейнер списка вопросов
	review_scroll = ScrollContainer.new()
	review_scroll.name = "ReviewScrollContainer"
	review_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	review_scroll.anchor_left = 0.1
	review_scroll.anchor_right = 0.9
	review_scroll.anchor_top = 0.08
	review_scroll.anchor_bottom = 0.85
	review_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	
	review_vbox = VBoxContainer.new()
	review_vbox.name = "ReviewVBox"
	review_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	review_vbox.add_theme_constant_override("separation", 10)
	review_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	
	review_scroll.add_child(review_vbox)
	root_control.add_child(review_scroll)

	# 3. Детальный просмотр карточки вопроса
	detail_view = VBoxContainer.new()
	detail_view.name = "DetailView"
	detail_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	detail_view.anchor_left = 0.05
	detail_view.anchor_right = 0.95
	detail_view.anchor_top = 0.05
	detail_view.anchor_bottom = 0.85
	detail_view.add_theme_constant_override("separation", 12)
	detail_view.alignment = BoxContainer.ALIGNMENT_CENTER
	detail_view.mouse_filter = Control.MOUSE_FILTER_PASS
	detail_view.visible = false
	
	# ТЕКСТ ВОПРОСА
	detail_question_label = Label.new()
	detail_question_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_question_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_question_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	detail_question_label.custom_minimum_size = Vector2(600, 50)
	detail_question_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	detail_question_label.add_theme_font_size_override("font_size", 20)
	detail_question_label.add_theme_color_override("font_color", Color("#2b2d42"))
	
	var q_style = StyleBoxFlat.new()
	q_style.bg_color = Color("#fff8ec")
	q_style.border_color = Color("#ffb703")
	q_style.set_border_width_all(3)
	q_style.set_corner_radius_all(14)
	q_style.content_margin_left = 20
	q_style.content_margin_right = 20
	q_style.content_margin_top = 8
	q_style.content_margin_bottom = 8
	detail_question_label.add_theme_stylebox_override("normal", q_style)
	
	# КАРТИНКА ВОПРОСА
	detail_image_rect = TextureRect.new()
	detail_image_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	detail_image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	detail_image_rect.custom_minimum_size = Vector2(240, 150)
	detail_image_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	detail_image_rect.visible = false
	
	# СЕТКА ВАРИАНТОВ ОТВЕТОВ
	detail_answers_grid = GridContainer.new()
	detail_answers_grid.columns = 2
	detail_answers_grid.add_theme_constant_override("h_separation", 14)
	detail_answers_grid.add_theme_constant_override("v_separation", 12)
	detail_answers_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	# КНОПКА ВОЗВРАТА К СПИСКУ
	back_to_list_button = Button.new()
	back_to_list_button.text = "🔙 Назад к списку ответов"
	back_to_list_button.custom_minimum_size = Vector2(260, 44)
	back_to_list_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_to_list_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_btn_style(back_to_list_button, Color("#4a5568"), Color("#cbd5e1"))
	back_to_list_button.pressed.connect(_on_back_to_list_pressed)
	
	detail_view.add_child(detail_question_label)
	detail_view.add_child(detail_image_rect)
	detail_view.add_child(detail_answers_grid)
	detail_view.add_child(back_to_list_button)
	
	root_control.add_child(detail_view)

	# 4. НИЖНЯЯ КНОПКА ЗАКРЫТИЯ
	bottom_bar = HBoxContainer.new()
	bottom_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_bar.offset_top = -65
	bottom_bar.offset_bottom = -15
	bottom_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	
	close_review_button = Button.new()
	close_review_button.text = "❌ Скрыть разбор ответов"
	close_review_button.custom_minimum_size = Vector2(260, 48)
	close_review_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_btn_style(close_review_button, Color("#e63946"), Color("#ff4d6d"))
	close_review_button.pressed.connect(_on_close_clicked)
	
	bottom_bar.add_child(close_review_button)
	root_control.add_child(bottom_bar)

func display_review(history: Array, quiz_file_path: String = "") -> void:
	current_history = history
	base_file_path = quiz_file_path
	
	review_scroll.visible = true
	detail_view.visible = false
	
	if not is_instance_valid(review_vbox): return
	
	for child in review_vbox.get_children():
		child.queue_free()
		
	for i in range(history.size()):
		var item = history[i]
		
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(0, 56)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		
		var p_style = StyleBoxFlat.new()
		p_style.set_corner_radius_all(12)
		p_style.content_margin_left = 16
		p_style.content_margin_right = 16
		p_style.content_margin_top = 8
		p_style.content_margin_bottom = 8
		
		var is_cor = item.get("is_correct", false)
		if is_cor:
			p_style.bg_color = Color(0.12, 0.35, 0.2, 0.95)
			p_style.border_color = Color("#a6e3a1")
		else:
			p_style.bg_color = Color(0.4, 0.12, 0.2, 0.95)
			p_style.border_color = Color("#f38ba8")
			
		p_style.set_border_width_all(2)
		
		var hover_style = p_style.duplicate() as StyleBoxFlat
		hover_style.border_color = Color.WHITE
		
		btn.add_theme_stylebox_override("normal", p_style)
		btn.add_theme_stylebox_override("hover", hover_style)
		btn.add_theme_stylebox_override("pressed", p_style)
		btn.add_theme_stylebox_override("focus", hover_style)
		
		var q_text = item.get("question", "")
		var u_ans = item.get("user_answer", "")
		var c_ans = item.get("correct_answer", "")
		
		var text_str = "🔍 " + str(i + 1) + ". " + q_text + "  (Нажмите для просмотра)\n"
		if is_cor:
			text_str += "   ✅ Ответ: " + u_ans
		else:
			text_str += "   ❌ Ваш ответ: " + u_ans + "  |  💡 Верно: " + c_ans
			
		btn.text = text_str
		
		var item_ref = item
		var idx_ref = i
		btn.pressed.connect(func(): _open_question_detail(item_ref, idx_ref))
		
		review_vbox.add_child(btn)

func _open_question_detail(item: Dictionary, index: int) -> void:
	review_scroll.visible = false
	detail_view.visible = true
	
	detail_question_label.text = "❓ Вопрос " + str(index + 1) + "\n" + item.get("question", "")
	
	# Загрузка картинки
	_load_detail_image(item.get("image", ""))
	
	# Очистка старой сетки вариантов
	for child in detail_answers_grid.get_children():
		child.queue_free()
		
	var options = item.get("options", [])
	var user_ans = item.get("user_answer", "")
	var correct_ans = item.get("correct_answer", "")
	
	# Отрисовка вариантов ответа
	for opt_raw in options:
		var opt_text = ""
		var opt_image = ""
		if opt_raw is Dictionary:
			opt_text = str(opt_raw.get("text", opt_raw.get("answer", opt_raw.get("option", ""))))
			opt_image = str(opt_raw.get("image", "")).strip_edges()
		else:
			opt_text = str(opt_raw)
		opt_text = opt_text.strip_edges()
		
		var card = PanelContainer.new()
		card.custom_minimum_size = Vector2(360, 84 if opt_image != "" else 52)
		
		var card_style = StyleBoxFlat.new()
		card_style.set_corner_radius_all(12)
		card_style.set_border_width_all(2)
		card_style.content_margin_left = 10
		card_style.content_margin_right = 12
		card_style.content_margin_top = 8
		card_style.content_margin_bottom = 8
		
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var opt_texture := _texture_from_name(opt_image)
		if opt_texture:
			var pic := TextureRect.new()
			pic.texture = opt_texture
			pic.custom_minimum_size = Vector2(96, 68)
			pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(pic)

		var label = Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 16)
		
		# Подсветка верных и неверных вариантов
		if opt_text == correct_ans:
			card_style.bg_color = Color("#2a9d8f")
			card_style.border_color = Color("#52b788")
			label.text = "✅ " + opt_text
			label.add_theme_color_override("font_color", Color.WHITE)
		elif opt_text == user_ans and not item.get("is_correct", false):
			card_style.bg_color = Color("#e63946")
			card_style.border_color = Color("#ff4d6d")
			label.text = "❌ " + opt_text
			label.add_theme_color_override("font_color", Color.WHITE)
		else:
			card_style.bg_color = Color(0.2, 0.22, 0.28, 0.7)
			card_style.border_color = Color(0.4, 0.44, 0.5)
			label.text = "⚪ " + opt_text
			label.add_theme_color_override("font_color", Color("#cbd5e1"))
			card.modulate.a = 0.7
			
		card.add_theme_stylebox_override("panel", card_style)
		row.add_child(label)
		card.add_child(row)
		detail_answers_grid.add_child(card)

func _texture_from_name(img_name: String) -> Texture2D:
	if img_name == "":
		return null
	if FileAccess.file_exists(img_name):
		var direct := Image.load_from_file(img_name)
		if direct:
			return ImageTexture.create_from_image(direct)
	if base_file_path != "":
		var full_path := base_file_path.get_base_dir().path_join(img_name)
		if FileAccess.file_exists(full_path):
			var img := Image.load_from_file(full_path)
			if img:
				return ImageTexture.create_from_image(img)
	return null

func _load_detail_image(img_name: String) -> void:
	var loaded_texture := _texture_from_name(img_name)
	if loaded_texture:
		detail_image_rect.texture = loaded_texture
		detail_image_rect.custom_minimum_size = Vector2(240, 150)
		detail_image_rect.visible = true
	else:
		detail_image_rect.visible = false

func _on_back_to_list_pressed() -> void:
	detail_view.visible = false
	review_scroll.visible = true

func _on_close_clicked() -> void:
	visible = false
	review_closed.emit()

func _apply_btn_style(btn: Button, main_color: Color, border_color: Color) -> void:
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", Color.WHITE)
	
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = main_color
	style_normal.border_color = border_color
	style_normal.set_border_width_all(2)
	style_normal.set_corner_radius_all(12)
	
	var style_hover = style_normal.duplicate() as StyleBoxFlat
	style_hover.bg_color = main_color.lightened(0.12)
	
	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_normal)

func toggle_screen(history: Array, quiz_file_path: String = "") -> bool:
	visible = not visible
	if visible:
		display_review(history, quiz_file_path)
	return visible
