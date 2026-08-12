extends Node

const SFX_POOL_SIZE := 4

var current_bgm_id := ""
var _bgm_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _next_sfx_index := 0
var _bgm_tween: Tween


func _ready() -> void:
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "BGMPlayer"
	_bgm_player.bus = "BGM"
	add_child(_bgm_player)

	for index in range(SFX_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.name = "SFXPlayer%d" % (index + 1)
		player.bus = "SFX"
		add_child(player)
		_sfx_players.append(player)


func play_bgm(stream: AudioStream, fade_duration: float = 0.0) -> void:
	if stream == null:
		return

	if _bgm_player.stream == stream and _bgm_player.playing:
		return

	_kill_bgm_tween()
	_bgm_player.stream = stream
	current_bgm_id = stream.resource_path
	_bgm_player.volume_db = -80.0 if fade_duration > 0.0 else 0.0
	_bgm_player.play()
	if fade_duration > 0.0:
		_bgm_tween = create_tween()
		_bgm_tween.tween_property(_bgm_player, "volume_db", 0.0, maxf(fade_duration, 0.0))


func play_bgm_by_id(bgm_id: String, fade_duration: float = 0.0) -> void:
	if bgm_id.is_empty():
		return
	var stream := AssetRegistry.get_audio("bgm", bgm_id)
	if stream == null:
		return
	play_bgm(stream, fade_duration)
	current_bgm_id = bgm_id


func stop_bgm(fade_duration: float = 0.0) -> void:
	if not _bgm_player.playing:
		return

	_kill_bgm_tween()
	if fade_duration <= 0.0:
		_finish_stop_bgm()
		return

	_bgm_tween = create_tween()
	_bgm_tween.tween_property(_bgm_player, "volume_db", -80.0, fade_duration)
	_bgm_tween.tween_callback(_finish_stop_bgm)


func pause_bgm() -> void:
	if _bgm_player.playing:
		_bgm_player.stream_paused = true


func resume_bgm() -> void:
	if _bgm_player.stream != null:
		_bgm_player.stream_paused = false


func play_sfx(stream: AudioStream) -> void:
	if stream == null or _sfx_players.is_empty():
		return

	var player := _find_available_sfx_player()
	player.stream = stream
	player.play()


func play_sfx_by_id(sfx_id: String) -> void:
	if sfx_id.is_empty():
		return
	var stream := AssetRegistry.get_audio("sfx", sfx_id)
	if stream != null:
		play_sfx(stream)


func stop_all_sfx() -> void:
	for player in _sfx_players:
		player.stop()


func is_bgm_playing() -> bool:
	return _bgm_player != null and _bgm_player.playing and not _bgm_player.stream_paused


func get_bgm_bus_name() -> String:
	return _bgm_player.bus if _bgm_player != null else ""


func get_sfx_bus_names() -> Array:
	var names := []
	for player in _sfx_players:
		names.append(player.bus)
	return names


func _find_available_sfx_player() -> AudioStreamPlayer:
	for player in _sfx_players:
		if not player.playing:
			return player

	var player := _sfx_players[_next_sfx_index]
	_next_sfx_index = (_next_sfx_index + 1) % _sfx_players.size()
	return player


func _finish_stop_bgm() -> void:
	_bgm_player.stop()
	_bgm_player.stream = null
	_bgm_player.volume_db = 0.0
	current_bgm_id = ""


func _kill_bgm_tween() -> void:
	if _bgm_tween != null and _bgm_tween.is_valid():
		_bgm_tween.kill()
	_bgm_tween = null
