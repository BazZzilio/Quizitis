class_name QuizBehaviorSettings
extends RefCounted

enum EvasionMode { ALL, WRONG_ONLY, CHANCE_20, DISABLED }
enum TTSMode { DISABLED, QUESTION_ONLY, ALL }

# Выбор визуального стиля карточек ответов
enum CardStyle {
	MODERN, # Сочные прямоугольные карточки
	WORDLE  # Квадратные плитки в стиле Wordle
}

var evasion_mode: EvasionMode = EvasionMode.ALL
var evasion_force_multiplier: float = 1.0

var tts_mode: TTSMode = TTSMode.DISABLED
var tts_voice_language: String = "en"

var card_style: CardStyle = CardStyle.MODERN

var sfx_enabled: bool = true

var question_delay: float = 1.2
var shuffle_questions: bool = false
var shuffle_options: bool = true
