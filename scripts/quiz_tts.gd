class_name QuizTTS
extends Node

# На Windows речь заранее рендерится в WAV фоновым PowerShell (System.Speech),
# а в игре только проигрывается — главный поток SAPI не трогает, фризов нет.
# На других ОС — обычный DisplayServer.tts_speak.

const CACHE_DIR := "user://tts_cache"
const SCRIPT_NAME := "render_tts.ps1"
const PENDING_TIMEOUT_SEC := 8.0

signal speech_finished

const RENDER_SCRIPT := """param([string]$list)
Add-Type -AssemblyName System.Speech
$s = New-Object System.Speech.Synthesis.SpeechSynthesizer
try {
	$s.SelectVoiceByHints([System.Speech.Synthesis.VoiceGender]::NotSet, [System.Speech.Synthesis.VoiceAge]::NotSet, 0, [System.Globalization.CultureInfo]::GetCultureInfo('en-US'))
} catch {}
foreach ($line in Get-Content -LiteralPath $list -Encoding UTF8) {
	$parts = $line -split "`t", 2
	if ($parts.Count -lt 2) { continue }
	$out = $parts[0]
	if (Test-Path -LiteralPath $out) { continue }
	$tmp = $out + '.part'
	$s.SetOutputToWaveFile($tmp)
	$s.Speak($parts[1])
	$s.SetOutputToNull()
	Move-Item -LiteralPath $tmp -Destination $out -Force
}
$s.Dispose()
"""

var _player: AudioStreamPlayer
var _streams: Dictionary = {}
var _requested: Dictionary = {}
var _queued_batches: Array[PackedStringArray] = []
var _worker: Thread
var _pending_path := ""
var _pending_age := 0.0
var _use_prerender := OS.get_name() == "Windows"
var _script_path := ""
var _system_voice := ""
var _cleaner := RegEx.new()

func _ready() -> void:
	_cleaner.compile("[^a-zA-Z0-9\\s,\\?!'.]")
	_player = AudioStreamPlayer.new()
	_player.name = "TTSPlayer"
	_player.finished.connect(_on_player_finished)
	add_child(_player)
	if _use_prerender:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CACHE_DIR))
		_script_path = ProjectSettings.globalize_path(CACHE_DIR.path_join(SCRIPT_NAME))
		var f := FileAccess.open(_script_path, FileAccess.WRITE)
		if f:
			f.store_string(RENDER_SCRIPT)
			f.close()
		else:
			_use_prerender = false
	set_process(false)

func _exit_tree() -> void:
	if _worker:
		_worker.wait_to_finish()
		_worker = null

func clean_text(raw_text: String) -> String:
	return _cleaner.sub(str(raw_text).strip_edges(), "", true).strip_edges()

# Заранее озвучить список фраз в фоне. Порядок важен: первые фразы будут готовы раньше.
func prepare(texts: Array) -> void:
	if not _use_prerender:
		return
	var lines := PackedStringArray()
	for t in texts:
		var clean := clean_text(str(t))
		if clean == "":
			continue
		var path := _path_for(clean)
		if _requested.has(path) or FileAccess.file_exists(path):
			continue
		_requested[path] = true
		lines.append(ProjectSettings.globalize_path(path) + "\t" + clean)
	if lines.is_empty():
		return
	_queued_batches.append(lines)
	_start_next_batch()
	set_process(true)

func speak(text: String) -> void:
	var clean := clean_text(text)
	if clean == "":
		return
	if not _use_prerender:
		_speak_system(clean)
		return
	var path := _path_for(clean)
	if FileAccess.file_exists(path):
		_pending_path = ""
		_play(path)
		return
	prepare([clean])
	_player.stop()
	_pending_path = path
	_pending_age = 0.0
	set_process(true)

func is_speaking() -> bool:
	if _use_prerender:
		return _pending_path != "" or (is_instance_valid(_player) and _player.playing)
	return DisplayServer.tts_is_speaking()

func wait_until_finished(max_wait: float = 12.0) -> void:
	if not is_speaking():
		return
	var start_time := Time.get_ticks_msec() / 1000.0
	while is_speaking():
		var now := Time.get_ticks_msec() / 1000.0
		if now - start_time >= max_wait:
			break
		if not is_inside_tree():
			break
		await get_tree().process_frame
	speech_finished.emit()

func _on_player_finished() -> void:
	speech_finished.emit()

func stop() -> void:
	_pending_path = ""
	if is_instance_valid(_player):
		_player.stop()
	if not _use_prerender and DisplayServer.tts_is_speaking():
		DisplayServer.tts_stop()
	speech_finished.emit()

func _process(delta: float) -> void:
	if _worker and not _worker.is_alive():
		_worker.wait_to_finish()
		_worker = null
		_start_next_batch()

	if _pending_path != "":
		if FileAccess.file_exists(_pending_path):
			var path := _pending_path
			_pending_path = ""
			_play(path)
		else:
			_pending_age += delta
			if _pending_age > PENDING_TIMEOUT_SEC:
				_pending_path = ""
				speech_finished.emit()

	if _worker == null and _queued_batches.is_empty() and _pending_path == "":
		set_process(false)

func _path_for(clean: String) -> String:
	return CACHE_DIR.path_join(clean.md5_text() + ".wav")

func _play(path: String) -> void:
	var stream: AudioStream = _streams.get(path)
	if stream == null:
		stream = AudioStreamWAV.load_from_file(ProjectSettings.globalize_path(path))
		if stream == null:
			speech_finished.emit()
			return
		if stream is AudioStreamWAV:
			(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_DISABLED
		_streams[path] = stream
	_player.stream = stream
	_player.play()

func _start_next_batch() -> void:
	if _worker != null or _queued_batches.is_empty():
		return
	var lines: PackedStringArray = _queued_batches.pop_front()
	var list_path := ProjectSettings.globalize_path(CACHE_DIR.path_join("batch_%d.txt" % Time.get_ticks_usec()))
	var f := FileAccess.open(list_path, FileAccess.WRITE)
	if not f:
		return
	f.store_string("\n".join(lines))
	f.close()
	_worker = Thread.new()
	_worker.start(_render_batch.bind(list_path))

func _render_batch(list_path: String) -> void:
	var args := PackedStringArray([
		"-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass",
		"-File", _script_path, "-list", list_path,
	])
	OS.execute("powershell.exe", args, [], false, false)
	DirAccess.remove_absolute(list_path)

func _speak_system(clean: String) -> void:
	if _system_voice == "":
		var voices := DisplayServer.tts_get_voices_for_language("en")
		if voices.is_empty():
			return
		_system_voice = voices[0]
	DisplayServer.tts_speak(clean, _system_voice, 50, 1.0, 1.0, 0, true)
