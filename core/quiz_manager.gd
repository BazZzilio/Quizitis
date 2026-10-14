class_name QuizManager
extends Node

signal question_changed(question_data: Dictionary, current_index: int, total_questions: int)
signal quiz_finished(correct_count: int, wrong_count: int, total_time_sec: float)
signal error_occurred(message: String)

var quiz_data: Array = []
var current_question_index: int = 0
var correct_count: int = 0
var wrong_count: int = 0

var user_history: Array = []
var start_time: float = 0.0
var total_time_sec: float = 0.0

var current_file_path: String = ""
var settings: QuizBehaviorSettings

func _init() -> void:
	settings = QuizBehaviorSettings.new()

# Загрузка и парсинг JSON-файла с квизом
func load_quiz(file_path: String) -> bool:
	current_file_path = file_path
	if not FileAccess.file_exists(file_path):
		error_occurred.emit("Файл не найден: " + file_path)
		return false
		
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		error_occurred.emit("Не удалось открыть файл: " + file_path)
		return false
		
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_text)
	if parse_result != OK:
		error_occurred.emit("Ошибка парсинга JSON (строка %d): %s" % [json.get_error_line(), json.get_error_message()])
		return false
		
	var parsed_data = json.data
	if parsed_data is Array:
		quiz_data = parsed_data
	elif parsed_data is Dictionary and parsed_data.has("questions"):
		quiz_data = parsed_data["questions"]
	else:
		error_occurred.emit("Неверная структура JSON: ожидал массив вопросов или объект с ключом 'questions'")
		return false
		
	if quiz_data.size() == 0:
		error_occurred.emit("JSON-файл не содержит вопросов!")
		return false
		
	return true

# Запуск квиза с обнулением результатов
func start_quiz() -> void:
	current_question_index = 0
	correct_count = 0
	wrong_count = 0
	user_history.clear()
	start_time = Time.get_ticks_msec() / 1000.0
	
	if settings and settings.shuffle_questions:
		quiz_data.shuffle()
		
	_emit_current_question()

# Проверка, является ли опция по индексу правильным ответом
func is_correct_option(option_index: int) -> bool:
	if current_question_index >= quiz_data.size():
		return false
	var q_data: Dictionary = quiz_data[current_question_index]
	var correct_idx: int = int(q_data.get("answer", 0))
	return option_index == correct_idx

# Определяет, должна ли кнопка с данным индексом убегать от курсора
func should_option_evade(option_index: int) -> bool:
	if not settings:
		return false
		
	match settings.evasion_mode:
		QuizBehaviorSettings.EvasionMode.DISABLED:
			return false
		QuizBehaviorSettings.EvasionMode.ALL:
			return true
		QuizBehaviorSettings.EvasionMode.WRONG_ONLY:
			return not is_correct_option(option_index)
		QuizBehaviorSettings.EvasionMode.CHANCE_20:
			return randf() < 0.2
		_:
			return false

# Проверка ответа пользователя и сохранение информации в историю
func check_answer(selected_index: int) -> bool:
	if current_question_index >= quiz_data.size():
		return false
		
	var q_data: Dictionary = quiz_data[current_question_index]
	var correct_idx: int = int(q_data.get("answer", 0))
	var is_correct = (selected_index == correct_idx)
	
	if is_correct:
		correct_count += 1
	else:
		wrong_count += 1
		
	var options: Array = q_data.get("options", [])
	var user_ans_text = "Нет ответа"
	var correct_ans_text = "Неизвестно"
	
	if selected_index >= 0 and selected_index < options.size():
		var raw_u = options[selected_index]
		if raw_u is Dictionary:
			user_ans_text = str(raw_u.get("text", raw_u.get("answer", raw_u.get("option", ""))))
		else:
			user_ans_text = str(raw_u)
		user_ans_text = user_ans_text.strip_edges()
		
	if correct_idx >= 0 and correct_idx < options.size():
		var raw_c = options[correct_idx]
		if raw_c is Dictionary:
			correct_ans_text = str(raw_c.get("text", raw_c.get("answer", raw_c.get("option", ""))))
		else:
			correct_ans_text = str(raw_c)
		correct_ans_text = correct_ans_text.strip_edges()

	user_history.append({
		"question": q_data.get("question", ""),
		"image": q_data.get("image", ""),
		"options": options,
		"user_answer": user_ans_text,
		"correct_answer": correct_ans_text,
		"user_index": selected_index,
		"correct_index": correct_idx,
		"is_correct": is_correct
	})
		
	return is_correct

# Переход к следующему вопросу или завершение
func next_question() -> void:
	current_question_index += 1
	if current_question_index < quiz_data.size():
		_emit_current_question()
	else:
		var end_time = Time.get_ticks_msec() / 1000.0
		total_time_sec = end_time - start_time
		quiz_finished.emit(correct_count, wrong_count, total_time_sec)

func _emit_current_question() -> void:
	if current_question_index < quiz_data.size():
		question_changed.emit(quiz_data[current_question_index], current_question_index, quiz_data.size())
