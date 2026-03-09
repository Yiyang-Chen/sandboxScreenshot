class_name AudioSystem extends System

## AudioSystem - 极简音频系统
##
## 管理 BGM 和 SFX 的播放。
## - 播放控制采用直接调用 API（播放是命令，不是通知）
## - 静音控制通过事件响应前端指令（WebParamsReceivedEvent）
##
## 设计原则：
## - 资源加载复用 ResourceSystem
## - 预加载由 loading 场景统一处理
##
## 使用示例：
## ```
## var audio = EnvironmentRuntime.get_system("AudioSystem") as AudioSystem
## audio.play_bgm("bgm_main_theme")
## audio.play_sfx("sfx_click")
## ```

# ===== 常量 =====
const MAX_SFX_PLAYERS: int = 8

# ===== 播放器 =====
var _bgm_player: AudioStreamPlayer = null
var _sfx_players: Array[AudioStreamPlayer] = []
var _custom_players: Array[AudioStreamPlayer] = []  ## 自定义播放器（需要手动控制的音效）

# ===== 音量 =====
var _bgm_volume: float = 1.0  ## BGM 音量乘数 (0.0 ~ 1.0)
var _sfx_volume: float = 1.0  ## SFX 音量乘数 (0.0 ~ 1.0)
var _current_bgm_base_volume: float = 0.7  ## 当前 BGM 的基础音量

# ===== 状态 =====
var _current_bgm_key: String = ""
var _audio_unlocked: bool = false
var _pending_bgm: Dictionary = {}
var _is_muted: bool = false

# ===== 依赖 =====
var _resource_system: ResourceSystem = null
var _web_bridge: WebBridgeSystem = null
var _event_system: EventSystem = null

# ===== Web 自动解锁相关 =====
var _js_unlock_callback: JavaScriptObject = null  ## JavaScript 回调引用（防止 GC）



# ========================================
# 生命周期
# ========================================

func _on_init() -> void:
	_resource_system = get_system("ResourceSystem") as ResourceSystem
	_web_bridge = get_system("WebBridgeSystem") as WebBridgeSystem
	_event_system = get_system("EventSystem") as EventSystem
	
	if _resource_system == null:
		log_error("[AudioSystem] ResourceSystem not found")
		return
	
	_setup_web_audio_unlock()
	log_info("[AudioSystem] Initialized")


func _on_shutdown() -> void:
	stop_bgm()
	stop_sfx()
	_cleanup_audio_players()
	_cleanup_web_audio_unlock()
	_resource_system = null
	_web_bridge = null
	_event_system = null
	log_info("[AudioSystem] Shutdown")


# ========================================
# BGM 控制
# ========================================

## 播放背景音乐
## @param key 音频资源 key（需在 game_config.json 注册）
## @param loop 是否循环播放
## @param volume 音量 (0.0 ~ 1.0)
func play_bgm(key: String, loop: bool = true, volume: float = 0.7) -> void:
	# 参数校验
	if key.is_empty():
		log_warn("[AudioSystem] play_bgm: empty key provided")
		return
	
	# 相同 BGM 正在播放，跳过
	if _current_bgm_key == key and _bgm_player != null and _bgm_player.playing:
		return
	
	# Web 未解锁，记录待播放
	if OS.has_feature("web") and not _audio_unlocked:
		_pending_bgm = {"key": key, "loop": loop, "volume": volume}
		log_info("[AudioSystem] BGM pending (audio not unlocked): %s" % key)
		return
	
	# 确保播放器已创建
	_create_audio_players_if_needed()
	
	_current_bgm_key = key
	
	_resource_system.load_resource(key,
		func(stream: AudioStream) -> void:
			if _current_bgm_key != key:
				return  # 竞态检查
			if _bgm_player == null:
				return
			# duplicate 避免修改 ResourceSystem 缓存的共享资源
			var stream_copy: AudioStream = stream.duplicate()
			_configure_stream_loop(stream_copy, loop)
			_current_bgm_base_volume = volume
			_bgm_player.stream = stream_copy
			_apply_bgm_volume()
			_bgm_player.play(),
		func(error: String) -> void:
			log_error("[AudioSystem] BGM load failed: %s - %s" % [key, error])
	)


## 停止背景音乐
func stop_bgm() -> void:
	if _bgm_player != null:
		_bgm_player.stop()
	_current_bgm_key = ""


## 暂停背景音乐
func pause_bgm() -> void:
	if _bgm_player != null:
		_bgm_player.stream_paused = true


## 恢复背景音乐
func resume_bgm() -> void:
	if _bgm_player != null:
		_bgm_player.stream_paused = false


## 设置 BGM 音量乘数
## @param multiplier 音量乘数 (0.0 ~ 1.0)
func set_bgm_volume(multiplier: float) -> void:
	_bgm_volume = clampf(multiplier, 0.0, 1.0)
	_apply_bgm_volume()


## 获取当前播放的 BGM key
func get_current_bgm() -> String:
	return _current_bgm_key


# ========================================
# SFX 控制
# ========================================

## 播放音效
## @param key 音频资源 key（需在 game_config.json 注册）
## @param volume 音量 (0.0 ~ 1.0)
func play_sfx(key: String, volume: float = 0.5) -> void:
	# 参数校验
	if key.is_empty():
		log_warn("[AudioSystem] play_sfx: empty key provided")
		return
	
	# Web 未解锁，跳过
	if OS.has_feature("web") and not _audio_unlocked:
		return
	
	# 检查资源是否已缓存
	var load_state: int = _resource_system.get_load_state(key)
	if load_state != AssetLoader.LoadState.LOADED:
		# 未缓存：触发加载但不播放（预热缓存供下次使用）
		_resource_system.load_resource(key, func(_s: AudioStream) -> void: pass, func(_e: String) -> void: pass)
		log_debug("[AudioSystem] SFX not cached, preloading: %s" % key)
		return
	
	# 已缓存：正常播放
	_create_audio_players_if_needed()
	
	_resource_system.load_resource(key,
		func(stream: AudioStream) -> void:
			var player: AudioStreamPlayer = _find_idle_sfx_player()
			player.stream = stream
			player.volume_db = linear_to_db(volume * _sfx_volume)
			player.play(),
		func(error: String) -> void:
			log_error("[AudioSystem] SFX load failed: %s - %s" % [key, error])
	)


## 停止所有音效
func stop_sfx() -> void:
	for player: AudioStreamPlayer in _sfx_players:
		player.stop()


## 设置 SFX 音量乘数
## @param multiplier 音量乘数 (0.0 ~ 1.0)
func set_sfx_volume(multiplier: float) -> void:
	_sfx_volume = clampf(multiplier, 0.0, 1.0)


# ========================================
# 自定义播放器（需要手动控制的音效）
# ========================================

## 创建自定义音频播放器
## 
## 用于需要手动控制的音效场景（如脚步声、引擎声、持续特效音等）。
## 调用方可以控制返回的 AudioStreamPlayer 的 stream_paused、pitch_scale 等属性。
## 用完后需要调用 release_custom_player() 释放。
## 
## @param key 音频资源 key（需在 game_config.json 注册）
## @param loop 是否循环播放
## @param volume 音量 (0.0 ~ 1.0)
## @return AudioStreamPlayer 播放器引用，失败返回 null
func create_custom_player(key: String, loop: bool = true, volume: float = 0.5) -> AudioStreamPlayer:
	if key.is_empty():
		log_warn("[AudioSystem] create_custom_player: empty key provided")
		return null
	
	if _resource_system == null:
		log_error("[AudioSystem] create_custom_player: ResourceSystem not found")
		return null
	
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		log_error("[AudioSystem] create_custom_player: no SceneTree")
		return null
	
	# 创建播放器
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.bus = "Master"
	player.volume_db = linear_to_db(volume * _sfx_volume)
	tree.root.add_child(player)
	_custom_players.append(player)
	
	# 异步加载音频流
	_resource_system.load_resource(key,
		func(stream: AudioStream) -> void:
			if not is_instance_valid(player):
				return
			var stream_copy: AudioStream = stream.duplicate()
			_configure_stream_loop(stream_copy, loop)
			player.stream = stream_copy
			player.stream_paused = true
			player.play(),
		func(error: String) -> void:
			log_error("[AudioSystem] Custom player load failed: %s - %s" % [key, error])
	)
	
	return player


## 释放自定义播放器
## @param player 要释放的播放器
func release_custom_player(player: AudioStreamPlayer) -> void:
	if player == null:
		return
	
	var idx: int = _custom_players.find(player)
	if idx >= 0:
		_custom_players.remove_at(idx)
	
	if is_instance_valid(player):
		player.stop()
		player.queue_free()


# ========================================
# 全局静音控制（前端联动）
# ========================================

## 设置全局静音状态
## @param muted true 为静音，false 为取消静音
func set_muted(muted: bool) -> void:
	if _is_muted == muted:
		return
	
	_is_muted = muted
	AudioServer.set_bus_mute(0, muted)  # 0 是 Master bus
	log_info("[AudioSystem] Muted: %s" % muted)


## 获取当前静音状态
func is_muted() -> bool:
	return _is_muted


# ========================================
# 内部方法
# ========================================

## 延迟创建播放器（首次播放时调用，挂载到 SceneTree.root）
func _create_audio_players_if_needed() -> void:
	if _bgm_player != null:
		return  # 已创建
	
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		log_error("[AudioSystem] Cannot create players: no SceneTree")
		return
	
	# BGM 播放器
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = "Master"
	tree.root.add_child(_bgm_player)
	
	# SFX 播放器池
	for i: int in MAX_SFX_PLAYERS:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = "Master"
		tree.root.add_child(player)
		_sfx_players.append(player)
	
	log_debug("[AudioSystem] Audio players created")


## 清理音频播放器
func _cleanup_audio_players() -> void:
	if _bgm_player != null and is_instance_valid(_bgm_player):
		_bgm_player.queue_free()
		_bgm_player = null
	
	for player: AudioStreamPlayer in _sfx_players:
		if is_instance_valid(player):
			player.queue_free()
	_sfx_players.clear()
	
	for player: AudioStreamPlayer in _custom_players:
		if is_instance_valid(player):
			player.queue_free()
	_custom_players.clear()


## 应用 BGM 音量（基础音量 * 音量乘数）
func _apply_bgm_volume() -> void:
	if _bgm_player != null:
		_bgm_player.volume_db = linear_to_db(_current_bgm_base_volume * _bgm_volume)


## 配置音频流循环模式
func _configure_stream_loop(stream: AudioStream, loop: bool) -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = loop
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = loop
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED


## 查找空闲的 SFX 播放器
## TODO: 复杂音效场景需要优先级排序，当前实现在全忙时复用第一个播放器
func _find_idle_sfx_player() -> AudioStreamPlayer:
	for player: AudioStreamPlayer in _sfx_players:
		if not player.playing:
			return player
	return _sfx_players[0]  # 全忙则复用第一个


# ========================================
# Web 音频解锁
# ========================================

## 设置 Web 音频解锁
## 
## 解锁方式：自动监听用户交互（click/touch/key/pointer）
## 用户首次交互时自动解锁 Web Audio
func _setup_web_audio_unlock() -> void:
	if not OS.has_feature("web"):
		_audio_unlocked = true
		return
	
	# 注册用户交互监听器
	_register_user_interaction_listener()
	
	# 注册静音事件处理器
	_register_mute_event_handler()
	
	# 检查是否已收到静音参数（处理时序问题）
	if _web_bridge:
		var muted_value: String = _web_bridge.get_param("muted", "")
		if muted_value == "true":
			set_muted(true)
	
	log_info("[AudioSystem] Web audio unlock listener ready (auto)")


## 注册用户交互监听器（参考 2dplatform 实现）
##
## 监听 DOM 事件：click, touchstart, keydown, pointerdown
## 用户首次交互时自动解锁 Web Audio
func _register_user_interaction_listener() -> void:
	# 创建 Godot 回调（必须保持引用防止被 GC）
	_js_unlock_callback = JavaScriptBridge.create_callback(_on_js_user_interaction)
	
	# 设置全局回调引用，供 JavaScript 调用
	var window: JavaScriptObject = JavaScriptBridge.get_interface("window")
	window.set("_godotAudioUnlockCallback", _js_unlock_callback)
	
	# 注入 JavaScript 监听器
	var js_code: String = """
	(function() {
		// 防止重复设置
		if (window._godotAudioUnlockSetup) return;
		window._godotAudioUnlockSetup = true;
		
		var events = ['click', 'touchstart', 'keydown', 'pointerdown'];
		var unlocked = false;
		
		var handler = function(e) {
			if (unlocked) return;
			unlocked = true;
			
			// 调用 Godot 回调
			if (window._godotAudioUnlockCallback) {
				try {
					window._godotAudioUnlockCallback();
				} catch (err) {
					console.error('[AudioSystem] Godot callback error:', err);
				}
			}
			
			// 移除所有监听器
			events.forEach(function(eventType) {
				document.removeEventListener(eventType, handler);
			});
			
			console.log('[AudioSystem] User interaction detected, audio unlocking...');
		};
		
		// 添加监听器
		events.forEach(function(eventType) {
			document.addEventListener(eventType, handler, { once: true, passive: true });
		});
		
		console.log('[AudioSystem] Auto unlock listeners registered');
	})()
	"""
	JavaScriptBridge.eval(js_code)
	log_debug("[AudioSystem] Auto unlock listener registered via JavaScript")


## JavaScript 用户交互回调
func _on_js_user_interaction(_args: Array) -> void:
	log_info("[AudioSystem] User interaction detected (auto unlock)")
	_handle_audio_unlock()


## 注册静音事件处理器（通过 WebBridge postMessage）
func _register_mute_event_handler() -> void:
	if _event_system == null:
		log_warn("[AudioSystem] EventSystem not found, cannot listen to mute events")
		return
	
	_event_system.register(WebParamsReceivedEvent, _on_web_params_received)
	log_debug("[AudioSystem] Registered mute event handler")


## 处理 WebBridge 参数事件（仅静音控制）
func _on_web_params_received(event: WebParamsReceivedEvent) -> void:
	# 处理静音控制
	if event.new_params.has("muted"):
		var muted_value: String = event.new_params.get("muted", "")
		if muted_value == "true":
			set_muted(true)
		elif muted_value == "false":
			set_muted(false)


## 处理音频解锁（用户首次交互后调用）
func _handle_audio_unlock() -> void:
	if _audio_unlocked:
		return
	
	_audio_unlocked = true
	log_info("[AudioSystem] Audio unlocked")
	
	# 通知前端音频已解锁
	_notify_parent_audio_unlocked()
	
	# 播放待播放的 BGM
	if not _pending_bgm.is_empty():
		var key: String = _pending_bgm.get("key", "")
		var loop: bool = _pending_bgm.get("loop", true)
		var volume: float = _pending_bgm.get("volume", 0.7)
		_pending_bgm = {}
		
		if not key.is_empty():
			play_bgm(key, loop, volume)


## 通知前端音频已解锁
func _notify_parent_audio_unlocked() -> void:
	if not OS.has_feature("web"):
		return
	
	var js_code: String = """
		(function() {
			window.parent.postMessage({
				type: 'godotAudioUnlocked',
				timestamp: Date.now()
			}, '*');
			console.log('[AudioSystem] Notified parent: audio unlocked');
		})()
	"""
	JavaScriptBridge.eval(js_code)


## 清理 Web 音频解锁相关资源
func _cleanup_web_audio_unlock() -> void:
	# 注销事件监听
	if _event_system != null:
		_event_system.unregister(WebParamsReceivedEvent, _on_web_params_received)
	
	# 清理 JavaScript 回调（仅 Web 平台）
	if OS.has_feature("web") and _js_unlock_callback != null:
		var js_cleanup: String = """
		(function() {
			window._godotAudioUnlockCallback = null;
			window._godotAudioUnlockSetup = false;
		})()
		"""
		JavaScriptBridge.eval(js_cleanup)
		_js_unlock_callback = null
		log_debug("[AudioSystem] JavaScript unlock callback cleaned up")
