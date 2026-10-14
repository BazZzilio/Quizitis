extends Control

var quiz_manager: QuizManager
var review_screen: QuizReviewScreen

const QuizAnimator = preload("res://scripts/quiz_animator.gd")
const QuizReviewScreenScript = preload("res://ui/components/quiz_review_screen.gd")

@onready var question_label: Label = %QuestionLabel
@onready var result_label: Label = %ResultLabel
@onready var question_image: TextureRect = %QuestionImage
@onready var file_dialog: FileDialog = %QuizFileDialog

@onready var answers_container: AnswerGrid = %AnswersContainer
@onready var end_game_buttons: HBoxContainer = %EndGameButtons
@onready var restart_button: Button = %RestartButton
@onready var select_file_button: Button = %SelectFileButton
@onready var show_answers_button: Button = %ShowAnswers if has_node("%ShowAnswers") else null

@onready var settings_container: VBoxContainer = %SettingsContainer
@onready var evasion_option_button: OptionButton = %EvasionOptionButton
@onready var start_quiz_button: Button = %StartQuizButton

var evasion_slider: HSlider
var evasion_slider_label: Label

var tts_option_button: OptionButton
var card_style_option_button: OptionButton
var background_option_button: OptionButton
var fly_check: CheckButton
var sfx_check: CheckButton
var sfx_player: AudioStreamPlayer
var _sfx_cache: Dictionary = {}

const SFX_RIGHT: Array[String] = [
	"res://assets/sfx/right.wav",
	"res://assets/sfx/right2.wav",
	"res://assets/sfx/right3.wav",
	"res://assets/sfx/right4.wav",
	"res://assets/sfx/right5.wav",
	"res://assets/sfx/right6.wav",
]
const SFX_FAIL: Array[String] = [
	"res://assets/sfx/fail.wav",
	"res://assets/sfx/fail2.wav",
	"res://assets/sfx/fail3.wav",
	"res://assets/sfx/fail4.wav",
	"res://assets/sfx/fail5.wav",
	"res://assets/sfx/fail6.wav",
]
const SFX_LOSE: Array[String] = [
	"res://assets/sfx/lose.wav",
	"res://assets/sfx/lose2.wav",
]
const SFX_WIN := "res://assets/sfx/win.wav"

var delay_slider: HSlider
var delay_slider_label: Label

var tts: QuizTTS
var quiz_background: Node
var _image_cache: Dictionary = {}
var _answer_busy := false

func _ready() -> void:
	print("--- QUIZ UI READY ---")
	
	quiz_manager = QuizManager.new()
	add_child(quiz_manager)

	tts = QuizTTS.new()
	tts.name = "QuizTTS"
	add_child(tts)

	sfx_player = AudioStreamPlayer.new()
	sfx_player.name = "SfxPlayer"
	add_child(sfx_player)
	
	review_screen = QuizReviewScreenScript.new()
	review_screen.name = "QuizReviewScreen"
	review_screen.review_closed.connect(_on_review_closed)
	add_child(review_screen)
	
	quiz_manager.question_changed.connect(_on_question_changed)
	quiz_manager.quiz_finished.connect(_on_quiz_finished)
	quiz_manager.error_occurred.connect(_on_quiz_error)
	
	if is_instance_valid(answers_container):
		answers_container.option_selected.connect(_on_option_selected)
		
	if is_instance_valid(restart_button):
		if restart_button.pressed.is_connected(_on_restart_pressed):
			restart_button.pressed.disconnect(_on_restart_pressed)
		restart_button.pressed.connect(_on_restart_pressed)
		
	if is_instance_valid(select_file_button):
		if select_file_button.pressed.is_connected(open_file_dialog):
			select_file_button.pressed.disconnect(open_file_dialog)
		select_file_button.pressed.connect(open_file_dialog)

	if not is_instance_valid(show_answers_button) and is_instance_valid(end_game_buttons):
		if end_game_buttons.has_node("ShowAnswers"):
			show_answers_button = end_game_buttons.get_node("ShowAnswers")
			
	if is_instance_valid(show_answers_button):
		if show_answers_button.pressed.is_connected(_on_toggle_answers_pressed):
			show_answers_button.pressed.disconnect(_on_toggle_answers_pressed)
		show_answers_button.pressed.connect(_on_toggle_answers_pressed)
	
	if is_instance_valid(file_dialog):
		file_dialog.file_selected.connect(_on_file_selected)
		file_dialog.canceled.connect(_on_dialog_canceled)
		file_dialog.close_requested.connect(_on_dialog_canceled)
		
	_style_question_and_result_labels()
	_style_end_game_buttons()
	quiz_background = get_parent().get_node_or_null("QuizBackground")
	_setup_settings_ui()

	_show_screen("file_select")
	await get_tree().process_frame
	open_file_dialog()

func _style_question_and_result_labels() -> void:
	if is_instance_valid(question_label):
		question_label.add_theme_font_size_override("font_size", 22)
		question_label.add_theme_color_override("font_color", Color("#2b2d42"))
		question_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		question_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		question_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		
		var q_style = StyleBoxFlat.new()
		q_style.bg_color = Color("#fff8ec")
		q_style.border_color = Color("#ffb703")
		q_style.set_border_width_all(3)
		q_style.set_corner_radius_all(14)
		q_style.content_margin_left = 18
		q_style.content_margin_right = 18
		q_style.content_margin_top = 8
		q_style.content_margin_bottom = 8
		question_label.add_theme_stylebox_override("normal", q_style)

	if is_instance_valid(result_label):
		result_label.add_theme_font_size_override("font_size", 20)
		result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		
		var r_style = StyleBoxFlat.new()
		r_style.bg_color = Color(0.12, 0.12, 0.18, 0.88)
		r_style.border_color = Color("#4cc9f0")
		r_style.set_border_width_all(3)
		r_style.set_corner_radius_all(14)
		r_style.content_margin_left = 18
		r_style.content_margin_right = 18
		r_style.content_margin_top = 8
		r_style.content_margin_bottom = 8
		result_label.add_theme_stylebox_override("normal", r_style)

func _style_end_game_buttons() -> void:
	if is_instance_valid(end_game_buttons):
		end_game_buttons.add_theme_constant_override("separation", 24)
		end_game_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
		end_game_buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		end_game_buttons.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		end_game_buttons.offset_top = -100
		end_game_buttons.offset_bottom = -30
		
	if is_instance_valid(restart_button):
		restart_button.text = "🔄 Играть Снова"
		_apply_button_style(restart_button, Color("#3a86ff"), Color("#00f5d4"), Color("#1e293b"))
		_setup_button_hover_animations(restart_button)

	if is_instance_valid(select_file_button):
		select_file_button.text = "📁 Выбрать Файл"
		_apply_button_style(select_file_button, Color("#ffb703"), Color("#fb8500"), Color("#1e293b"))
		_setup_button_hover_animations(select_file_button)

	if is_instance_valid(show_answers_button):
		show_answers_button.text = "📋 Показать ответы"
		_apply_button_style(show_answers_button, Color("#7209b7"), Color("#f72585"), Color("#ffffff"))
		_setup_button_hover_animations(show_answers_button)

func _apply_button_style(btn: Button, main_color: Color, border_color: Color, _text_color: Color) -> void:
	btn.custom_minimum_size = Vector2(220, 56)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", Color.WHITE)

	var style_normal := _fancy_menu_box(main_color, border_color, Color(1, 1, 1, 0.85), Vector2(0, 4))
	var style_hover := _fancy_menu_box(main_color.lightened(0.12), Color.WHITE, border_color, Vector2(0, 2))
	var style_press := _fancy_menu_box(main_color.darkened(0.08), border_color.darkened(0.1), Color(1, 1, 1, 0.4), Vector2(0, 1))

	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_press)
	btn.add_theme_stylebox_override("focus", style_hover)

func _fancy_menu_box(bg: Color, outer: Color, inner: Color, shadow_offset: Vector2) -> StyleBoxFancy:
	var box := StyleBoxFancy.new()
	box.color = bg
	box.corner_detail = 8
	box.set_corner_radius_all(18)
	box.set_corner_curvature_all(2)
	box.shadow_enabled = true
	box.shadow_color = Color(0, 0, 0, 0.35)
	box.shadow_blur = 8
	box.shadow_offset = shadow_offset
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	var outer_border := StyleBorder.new()
	outer_border.color = outer
	outer_border.set_width_all(4)
	var inner_border := StyleBorder.new()
	inner_border.color = inner
	inner_border.set_width_all(2)
	box.borders = [outer_border, inner_border]
	return box

func _setup_button_hover_animations(btn: Button) -> void:
	btn.pivot_offset = btn.size / 2.0
	if not btn.mouse_entered.is_connected(_on_btn_mouse_entered.bind(btn)):
		btn.mouse_entered.connect(_on_btn_mouse_entered.bind(btn))
	if not btn.mouse_exited.is_connected(_on_btn_mouse_exited.bind(btn)):
		btn.mouse_exited.connect(_on_btn_mouse_exited.bind(btn))

func _on_btn_mouse_entered(btn: Button) -> void:
	if btn.disabled: return
	btn.pivot_offset = btn.size / 2.0
	create_tween().tween_property(btn, "scale", Vector2(1.05, 1.05), 0.12)

func _on_btn_mouse_exited(btn: Button) -> void:
	if btn.disabled: return
	create_tween().tween_property(btn, "scale", Vector2(1.0, 1.0), 0.12)

func _setup_settings_ui() -> void:
	if not is_instance_valid(settings_container): return
	
	settings_container.alignment = BoxContainer.ALIGNMENT_CENTER
	settings_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	settings_container.add_theme_constant_override("separation", 14)
	
	if is_instance_valid(evasion_option_button):
		evasion_option_button.clear()
		evasion_option_button.add_item("Убегают ВСЕ ответы", 0)
		evasion_option_button.add_item("Убегают ТОЛЬКО НЕПРАВИЛЬНЫЕ", 1)
		evasion_option_button.add_item("Шанс убегания 20%", 2)
		evasion_option_button.add_item("Уворачивание ОТКЛЮЧЕНО", 3)
		evasion_option_button.custom_minimum_size = Vector2(360, 48)

	if not settings_container.has_node("BackgroundOptionContainer"):
		var bg_box := VBoxContainer.new()
		bg_box.name = "BackgroundOptionContainer"
		bg_box.alignment = BoxContainer.ALIGNMENT_CENTER

		var bg_label := Label.new()
		bg_label.text = "🌄 Фон:"
		bg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

		background_option_button = OptionButton.new()
		background_option_button.name = "BackgroundOptionButton"
		background_option_button.add_item("🎲 Случайный", 0)
		if quiz_background and quiz_background.has_method("background_labels"):
			var labels: PackedStringArray = quiz_background.background_labels()
			for i in labels.size():
				background_option_button.add_item(labels[i], i + 1)
		background_option_button.selected = 0
		background_option_button.custom_minimum_size = Vector2(280, 48)
		background_option_button.item_selected.connect(_on_background_selected)

		fly_check = CheckButton.new()
		fly_check.name = "FlyCheck"
		fly_check.text = "✈ WASD"
		fly_check.custom_minimum_size = Vector2(140, 48)
		fly_check.tooltip_text = "Летать самой камерой: WASD, пробел вверх, Ctrl вниз, Shift быстрее. Зажать ПКМ, чтобы смотреть."
		fly_check.toggled.connect(_on_fly_toggled)

		var bg_row := HBoxContainer.new()
		bg_row.alignment = BoxContainer.ALIGNMENT_CENTER
		bg_row.add_theme_constant_override("separation", 12)
		bg_row.add_child(background_option_button)
		bg_row.add_child(fly_check)

		bg_box.add_child(bg_label)
		bg_box.add_child(bg_row)
		settings_container.add_child(bg_box)

	if not settings_container.has_node("CardStyleContainer"):
		var style_box = VBoxContainer.new()
		style_box.name = "CardStyleContainer"
		style_box.alignment = BoxContainer.ALIGNMENT_CENTER
		
		var style_label = Label.new()
		style_label.text = "🎨 Визуальный стиль карточек:"
		style_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		card_style_option_button = OptionButton.new()
		card_style_option_button.name = "CardStyleOptionButton"
		card_style_option_button.add_item("🟦 Современный (Прямоугольники)", 0)
		card_style_option_button.add_item("🟩 Wordwall Style (Квадратные плитки)", 1)
		card_style_option_button.selected = 0
		card_style_option_button.custom_minimum_size = Vector2(360, 48)
		
		style_box.add_child(style_label)
		style_box.add_child(card_style_option_button)
		settings_container.add_child(style_box)

	if not settings_container.has_node("EvasionPowerContainer"):
		var power_box = VBoxContainer.new()
		power_box.name = "EvasionPowerContainer"
		power_box.alignment = BoxContainer.ALIGNMENT_CENTER
		
		evasion_slider_label = Label.new()
		evasion_slider_label.text = "Мощность убегания: 100% (Нормально)"
		evasion_slider_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		evasion_slider = HSlider.new()
		evasion_slider.min_value = 0.5
		evasion_slider.max_value = 2.5
		evasion_slider.step = 0.1
		evasion_slider.value = 1.0
		evasion_slider.custom_minimum_size = Vector2(360, 32)
		evasion_slider.value_changed.connect(_on_slider_value_changed)
		
		power_box.add_child(evasion_slider_label)
		power_box.add_child(evasion_slider)
		settings_container.add_child(power_box)

	if not settings_container.has_node("TTSOptionContainer"):
		var tts_box = VBoxContainer.new()
		tts_box.name = "TTSOptionContainer"
		tts_box.alignment = BoxContainer.ALIGNMENT_CENTER
		
		var tts_label = Label.new()
		tts_label.text = "🗣️ Озвучка текста (TTS):"
		tts_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		tts_option_button = OptionButton.new()
		tts_option_button.add_item("🔇 Озвучка ОТКЛЮЧЕНА (Быстро / Без лагов)", 0)
		tts_option_button.add_item("❓ Зачитывать ТОЛЬКО вопрос", 1)
		tts_option_button.add_item("🔊 Зачитывать Вопрос И Выбранный Ответ", 2)
		tts_option_button.selected = 0
		tts_option_button.custom_minimum_size = Vector2(360, 48)
		
		tts_box.add_child(tts_label)
		tts_box.add_child(tts_option_button)
		settings_container.add_child(tts_box)

	if not settings_container.has_node("SfxOptionContainer"):
		var sfx_box = VBoxContainer.new()
		sfx_box.name = "SfxOptionContainer"
		sfx_box.alignment = BoxContainer.ALIGNMENT_CENTER

		sfx_check = CheckButton.new()
		sfx_check.name = "SfxCheck"
		sfx_check.text = "🔊 Звуковые эффекты"
		sfx_check.button_pressed = true
		sfx_check.custom_minimum_size = Vector2(360, 48)

		sfx_box.add_child(sfx_check)
		settings_container.add_child(sfx_box)

	if not settings_container.has_node("DelayContainer"):
		var delay_box = VBoxContainer.new()
		delay_box.name = "DelayContainer"
		delay_box.alignment = BoxContainer.ALIGNMENT_CENTER
		
		delay_slider_label = Label.new()
		delay_slider_label.text = "⏱️ Пауза перед след. вопросом: 1.2 сек"
		delay_slider_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		delay_slider = HSlider.new()
		delay_slider.min_value = 0.0
		delay_slider.max_value = 5.0
		delay_slider.step = 0.1
		delay_slider.value = 1.2
		delay_slider.custom_minimum_size = Vector2(360, 32)
		delay_slider.value_changed.connect(_on_delay_slider_value_changed)
		
		delay_box.add_child(delay_slider_label)
		delay_box.add_child(delay_slider)
		settings_container.add_child(delay_box)

	if is_instance_valid(start_quiz_button):
		settings_container.move_child(start_quiz_button, settings_container.get_child_count() - 1)
		start_quiz_button.text = "🚀 НАЧАТЬ КВИЗ!"
		_apply_button_style(start_quiz_button, Color("#06d6a0"), Color("#118ab2"), Color("#ffffff"))
		_setup_button_hover_animations(start_quiz_button)
		if start_quiz_button.pressed.is_connected(_on_start_quiz_pressed):
			start_quiz_button.pressed.disconnect(_on_start_quiz_pressed)
		start_quiz_button.pressed.connect(_on_start_quiz_pressed)

func _on_background_selected(index: int) -> void:
	if quiz_background and quiz_background.has_method("show_background"):
		quiz_background.show_background(-1 if index == 0 else index - 1)

func _on_fly_toggled(enabled: bool) -> void:
	if quiz_background and quiz_background.has_method("set_manual_flight"):
		quiz_background.set_manual_flight(enabled)

func _on_slider_value_changed(val: float) -> void:
	if is_instance_valid(evasion_slider_label):
		var percent = int(val * 100)
		evasion_slider_label.text = "Мощность убегания: " + str(percent) + "%"

func _on_delay_slider_value_changed(val: float) -> void:
	if is_instance_valid(delay_slider_label):
		delay_slider_label.text = "⏱️ Пауза перед след. вопросом: " + str(val) + " сек"

func open_file_dialog() -> void:
	_show_screen("file_select")
	if is_instance_valid(file_dialog):
		file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		file_dialog.popup_centered(Vector2i(750, 550))

func _on_file_selected(path: String) -> void:
	if is_instance_valid(file_dialog): file_dialog.hide()
	if quiz_manager.load_quiz(path): _show_screen("settings")
	else:
		await get_tree().create_timer(1.5).timeout
		open_file_dialog()

func _on_start_quiz_pressed() -> void:
	if is_instance_valid(evasion_option_button):
		match evasion_option_button.selected:
			0: quiz_manager.settings.evasion_mode = QuizBehaviorSettings.EvasionMode.ALL
			1: quiz_manager.settings.evasion_mode = QuizBehaviorSettings.EvasionMode.WRONG_ONLY
			2: quiz_manager.settings.evasion_mode = QuizBehaviorSettings.EvasionMode.CHANCE_20
			3: quiz_manager.settings.evasion_mode = QuizBehaviorSettings.EvasionMode.DISABLED
			
	if is_instance_valid(card_style_option_button):
		match card_style_option_button.selected:
			0: quiz_manager.settings.card_style = QuizBehaviorSettings.CardStyle.MODERN
			1: quiz_manager.settings.card_style = QuizBehaviorSettings.CardStyle.WORDLE
			
	if is_instance_valid(evasion_slider):
		quiz_manager.settings.evasion_force_multiplier = evasion_slider.value
		
	if is_instance_valid(tts_option_button):
		match tts_option_button.selected:
			0: quiz_manager.settings.tts_mode = QuizBehaviorSettings.TTSMode.DISABLED
			1: quiz_manager.settings.tts_mode = QuizBehaviorSettings.TTSMode.QUESTION_ONLY
			2: quiz_manager.settings.tts_mode = QuizBehaviorSettings.TTSMode.ALL
			
	if is_instance_valid(sfx_check):
		quiz_manager.settings.sfx_enabled = sfx_check.button_pressed

	if is_instance_valid(delay_slider):
		quiz_manager.settings.question_delay = delay_slider.value

	_answer_busy = false
	if quiz_manager.settings.tts_mode != QuizBehaviorSettings.TTSMode.DISABLED:
		tts.prepare(_collect_tts_texts())
	else:
		tts.stop()

	_show_screen("quiz")
	quiz_manager.start_quiz()

func _on_restart_pressed() -> void:
	if is_instance_valid(tts):
		tts.stop()
	if quiz_manager.quiz_data.size() > 0:
		_show_screen("quiz")
		quiz_manager.start_quiz()
	else:
		open_file_dialog()

# ПРИНУДИТЕЛЬНАЯ ПРИВЯЗКА ОТВЕТОВ К НИЖНЕМУ КРАЮ ЭКРАНА С ПРУЖИНОЙ-СПЕЙСЕРОМ
func _on_question_changed(data: Dictionary, index: int, total: int) -> void:
	_answer_busy = false
	if is_instance_valid(result_label):
		result_label.text = ""
		result_label.modulate.a = 0.0
		
	var q_text = data.get("question", "")
	question_label.text = "❓ Вопрос " + str(index + 1) + " из " + str(total) + "\n" + q_text
	
	_load_image(data.get("image", ""))
	
	var parent = question_label.get_parent()
	if parent:
		var spacer: Control
		if parent.has_node("BottomSpacer"):
			spacer = parent.get_node("BottomSpacer")
		else:
			spacer = Control.new()
			spacer.name = "BottomSpacer"
			parent.add_child(spacer)

		var is_wordle := quiz_manager and quiz_manager.settings \
			and quiz_manager.settings.card_style == QuizBehaviorSettings.CardStyle.WORDLE
		if is_wordle:
			spacer.visible = false
			spacer.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			spacer.custom_minimum_size = Vector2.ZERO
			if is_instance_valid(answers_container):
				answers_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
				answers_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if is_instance_valid(question_image) and question_image.visible:
				question_image.custom_minimum_size = Vector2(140, 140)
		else:
			spacer.visible = true
			spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
			if is_instance_valid(answers_container):
				answers_container.clip_contents = false
				answers_container.size_flags_vertical = Control.SIZE_SHRINK_END
				answers_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if is_instance_valid(question_image) and question_image.visible:
				question_image.custom_minimum_size = Vector2(150, 150)

		parent.move_child(question_label, 0)
		if is_instance_valid(question_image): parent.move_child(question_image, 1)
		if is_instance_valid(result_label): parent.move_child(result_label, 2)
		parent.move_child(spacer, 3)
		if is_instance_valid(answers_container): parent.move_child(answers_container, 4)
	
	var options = data.get("options", [])
	var forced_layout = data.get("layout", "auto")
	if is_instance_valid(answers_container):
		answers_container.display_options(options, quiz_manager, forced_layout)
		
	QuizAnimator.play_random_question_intro(question_label, question_image, answers_container)

	_preload_upcoming_images(index)

	if quiz_manager.settings.tts_mode != QuizBehaviorSettings.TTSMode.DISABLED:
		tts.speak(q_text)

func _on_option_selected(option_index: int) -> void:
	if _answer_busy:
		return
	_answer_busy = true
	var selected_text: String = ""
	
	if quiz_manager and quiz_manager.quiz_data.size() > quiz_manager.current_question_index:
		var current_q: Dictionary = quiz_manager.quiz_data[quiz_manager.current_question_index]
		var options: Array = current_q.get("options", [])
		
		if option_index >= 0 and option_index < options.size():
			var raw_opt = options[option_index]
			if raw_opt is Dictionary:
				selected_text = str(raw_opt.get("text", raw_opt.get("answer", raw_opt.get("option", ""))))
			else:
				selected_text = str(raw_opt)
			selected_text = selected_text.strip_edges()

	if quiz_manager.settings.tts_mode == QuizBehaviorSettings.TTSMode.ALL and selected_text != "":
		tts.speak(selected_text)

	if is_instance_valid(answers_container):
		answers_container.disable_all()
	
	var is_correct = quiz_manager.check_answer(option_index)
	
	result_label.remove_theme_color_override("font_color")
	if is_correct:
		result_label.text = "✅ ВЕРНО! ОТЛИЧНО!"
		result_label.modulate = Color("#a6e3a1")
		_play_sfx(SFX_RIGHT.pick_random())
	else:
		result_label.text = "❌ НЕПРАВИЛЬНО!"
		result_label.modulate = Color("#f38ba8")
		_play_sfx(SFX_FAIL.pick_random())
		
	_animate_result_pop()

	var wait_time: float = quiz_manager.settings.question_delay
	var delay_timer: SceneTreeTimer = null
	if wait_time > 0.0:
		delay_timer = get_tree().create_timer(wait_time)

	# Не переключаемся на следующий вопрос, пока не завершится чтение TTS
	if is_instance_valid(tts) and quiz_manager.settings.tts_mode != QuizBehaviorSettings.TTSMode.DISABLED:
		if tts.is_speaking():
			await tts.wait_until_finished()
			# Небольшая естественная пауза (0.25 сек), чтобы вопрос не исчезал резко на последнем звуке
			await get_tree().create_timer(0.25).timeout

	# Дожидаемся минимальной паузы из настроек (если таймер ещё не истёк)
	if delay_timer and delay_timer.time_left > 0.0:
		await delay_timer.timeout

	quiz_manager.next_question()

func _animate_result_pop() -> void:
	result_label.pivot_offset = result_label.size / 2.0
	result_label.scale = Vector2(0.5, 0.5)
	result_label.modulate.a = 0.0
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(result_label, "modulate:a", 1.0, 0.15)
	tween.tween_property(result_label, "scale", Vector2(1.1, 1.1), 0.15)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	create_tween().tween_property(result_label, "scale", Vector2(1.0, 1.0), 0.1).set_delay(0.15)

func _on_quiz_finished(correct: int, wrong: int, total_time_sec: float) -> void:
	var total = correct + wrong
	var accuracy = 0
	if total > 0: accuracy = int((float(correct) / float(total)) * 100)
		
	var minutes = int(total_time_sec) / 60
	var seconds = int(total_time_sec) % 60
	var time_str = "%02d:%02d" % [minutes, seconds]
		
	question_label.text = "🏆 КВИЗ ЗАВЕРШЁН!"
	result_label.text = "⏱️ Время прохождения: " + time_str + "\n" \
		+ "🎯 Точность: " + str(accuracy) + "%\n" \
		+ "✅ Правильных ответов: " + str(correct) + "\n" \
		+ "❌ Ошибок: " + str(wrong)
		
	var passed: bool = int(accuracy) > 70
	result_label.modulate = Color.WHITE
	result_label.modulate.a = 1.0
	result_label.add_theme_color_override("font_color", Color("#06d6a0") if passed else Color("#e63946"))
	_play_sfx(SFX_WIN if passed else SFX_LOSE.pick_random())
	
	_load_victory_image()
	
	if is_instance_valid(answers_container):
		answers_container.clear_cards()
			
	_show_screen("end_game")
	QuizAnimator.play_random_victory(self)

func _play_sfx(path: String) -> void:
	if not quiz_manager or not quiz_manager.settings or not quiz_manager.settings.sfx_enabled:
		return
	if not is_instance_valid(sfx_player):
		return
	var stream: AudioStream = _sfx_cache.get(path)
	if stream == null:
		stream = load(path)
		if stream == null and FileAccess.file_exists(path):
			stream = AudioStreamWAV.load_from_file(ProjectSettings.globalize_path(path))
		if stream == null:
			return
		_sfx_cache[path] = stream
	sfx_player.stream = stream
	sfx_player.play()

func _on_toggle_answers_pressed() -> void:
	if not is_instance_valid(review_screen): return
	review_screen.toggle_screen(quiz_manager.user_history, quiz_manager.current_file_path)

func _on_review_closed() -> void:
	pass

func _load_victory_image() -> void:
	if not is_instance_valid(question_image): return
	var base_dir = ""
	if quiz_manager and quiz_manager.current_file_path != "":
		base_dir = quiz_manager.current_file_path.get_base_dir()
		
	var victory_files = ["victory.png", "victory.jpg", "win.png", "cat.jpg"]
	var loaded_texture: Texture2D = null
	
	for file_name in victory_files:
		var full_path = file_name
		if base_dir != "": full_path = base_dir.path_join(file_name)
		if FileAccess.file_exists(full_path):
			var img = Image.load_from_file(full_path)
			if img:
				loaded_texture = ImageTexture.create_from_image(img)
				break
				
	if loaded_texture:
		question_image.texture = loaded_texture
		question_image.custom_minimum_size = Vector2(180, 180)
		question_image.visible = true

func _on_dialog_canceled() -> void:
	if quiz_manager.quiz_data.size() == 0:
		question_label.text = "Сначала выберите JSON-файл викторины!"
		await get_tree().create_timer(0.4).timeout
		open_file_dialog()

func _on_quiz_error(msg: String) -> void:
	question_label.text = msg

func _show_screen(screen_name: String) -> void:
	if screen_name != "quiz" and is_instance_valid(tts):
		tts.stop()

	if is_instance_valid(answers_container): 
		answers_container.visible = (screen_name == "quiz")
		
	if is_instance_valid(settings_container): 
		settings_container.visible = (screen_name == "settings")
		
	if is_instance_valid(end_game_buttons): 
		end_game_buttons.visible = (screen_name == "end_game")
		if screen_name == "end_game":
			end_game_buttons.move_to_front()
			if is_instance_valid(restart_button): restart_button.disabled = false
			if is_instance_valid(select_file_button): select_file_button.disabled = false
			if is_instance_valid(show_answers_button): show_answers_button.disabled = false
		
	if is_instance_valid(question_image): 
		question_image.visible = (screen_name == "quiz" and question_image.texture != null) or (screen_name == "end_game" and question_image.texture != null)
	
	if is_instance_valid(review_screen):
		review_screen.visible = false
	
	if screen_name == "quiz":
		result_label.text = ""
		result_label.modulate.a = 0.0

func _load_image(img_name: String) -> void:
	if img_name == "":
		if is_instance_valid(question_image): question_image.visible = false
		return

	var loaded_texture := _texture_from_path(img_name)
	if loaded_texture and is_instance_valid(question_image):
		question_image.texture = loaded_texture
		question_image.visible = true
		var is_wordle := quiz_manager and quiz_manager.settings \
			and quiz_manager.settings.card_style == QuizBehaviorSettings.CardStyle.WORDLE
		question_image.custom_minimum_size = Vector2(140, 140) if is_wordle else Vector2(150, 150)
	else:
		if is_instance_valid(question_image): question_image.visible = false

func _texture_from_path(img_name: String) -> Texture2D:
	var candidates: Array[String] = [img_name]
	if quiz_manager and quiz_manager.current_file_path != "":
		candidates.append(quiz_manager.current_file_path.get_base_dir().path_join(img_name))
	for full_path in candidates:
		if _image_cache.has(full_path):
			return _image_cache[full_path]
		if FileAccess.file_exists(full_path):
			var img = Image.load_from_file(full_path)
			if img:
				var tex := ImageTexture.create_from_image(img)
				_image_cache[full_path] = tex
				return tex
	return null

# Порядок совпадает с ходом квиза: вопрос, затем его варианты — первые фразы озвучатся раньше.
func _collect_tts_texts() -> Array:
	var texts: Array = []
	var with_options := quiz_manager.settings.tts_mode == QuizBehaviorSettings.TTSMode.ALL
	for q in quiz_manager.quiz_data:
		if not (q is Dictionary):
			continue
		texts.append(str(q.get("question", "")))
		if with_options:
			for raw_opt in q.get("options", []):
				if raw_opt is Dictionary:
					texts.append(str(raw_opt.get("text", raw_opt.get("answer", raw_opt.get("option", "")))).strip_edges())
				else:
					texts.append(str(raw_opt).strip_edges())
	return texts

func _preload_upcoming_images(current_index: int) -> void:
	if not quiz_manager:
		return
	var next_index := current_index + 1
	if next_index >= quiz_manager.quiz_data.size():
		return
	var next_q: Dictionary = quiz_manager.quiz_data[next_index]
	var next_img := str(next_q.get("image", ""))
	if next_img != "":
		_texture_from_path(next_img)
