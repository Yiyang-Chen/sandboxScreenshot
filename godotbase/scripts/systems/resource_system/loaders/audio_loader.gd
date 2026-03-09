class_name AudioLoader extends AssetLoader

## AudioLoader
##
## Loader for audio resources (OGG, MP3, WAV).
## Automatically detects format from Content-Type or tries all formats.


func _parse_data(data: PackedByteArray, headers: PackedStringArray) -> Variant:
	# 1. Try Content-Type first
	var content_type: String = _get_content_type(headers)
	if not content_type.is_empty():
		var resource: AudioStream = _parse_by_content_type(content_type, data)
		if resource != null:
			return resource
	
	# 2. Fallback: try all formats
	var audio: AudioStream = _load_ogg_from_buffer(data)
	if audio:
		return audio
	
	audio = _load_mp3_from_buffer(data)
	if audio:
		return audio
	
	return _load_wav_from_buffer(data)


func _parse_by_content_type(content_type: String, data: PackedByteArray) -> AudioStream:
	match content_type.to_lower():
		"audio/ogg":
			return _load_ogg_from_buffer(data)
		"audio/mpeg", "audio/mp3":
			return _load_mp3_from_buffer(data)
		"audio/wav", "audio/wave", "audio/x-wav":
			return _load_wav_from_buffer(data)
		_:
			return null


func _load_ogg_from_buffer(data: PackedByteArray) -> AudioStream:
	var stream: AudioStream = AudioStreamOggVorbis.load_from_buffer(data)
	if stream == null:
		_log_error("[AudioLoader] Failed to decode OGG: invalid or corrupted file")
		return null
	if stream.get_length() <= 0:
		_log_error("[AudioLoader] Failed to decode OGG: zero length audio")
		return null
	return stream


func _load_mp3_from_buffer(data: PackedByteArray) -> AudioStream:
	var stream: AudioStreamMP3 = AudioStreamMP3.new()
	stream.data = data
	if stream.get_length() <= 0:
		_log_error("[AudioLoader] Failed to decode MP3: invalid or corrupted file")
		return null
	return stream


func _load_wav_from_buffer(data: PackedByteArray) -> AudioStream:
	# WAV file format parsing
	# Minimum WAV header size: 44 bytes (RIFF header + fmt chunk + data chunk header)
	if data.size() < 44:
		_log_error("[AudioLoader] Failed to decode WAV: file too small")
		return null
	
	# Validate RIFF header
	var riff: String = data.slice(0, 4).get_string_from_ascii()
	var wave: String = data.slice(8, 12).get_string_from_ascii()
	if riff != "RIFF" or wave != "WAVE":
		_log_error("[AudioLoader] Failed to decode WAV: invalid RIFF/WAVE header")
		return null
	
	# Find fmt chunk
	var pos: int = 12
	var format: int = 0
	var channels: int = 0
	var sample_rate: int = 0
	var bits_per_sample: int = 0
	var pcm_data: PackedByteArray = PackedByteArray()
	
	while pos < data.size() - 8:
		var chunk_id: String = data.slice(pos, pos + 4).get_string_from_ascii()
		var chunk_size: int = data.decode_u32(pos + 4)
		
		if chunk_id == "fmt ":
			if chunk_size < 16:
				_log_error("[AudioLoader] Failed to decode WAV: fmt chunk too small")
				return null
			format = data.decode_u16(pos + 8)
			channels = data.decode_u16(pos + 10)
			sample_rate = data.decode_u32(pos + 12)
			bits_per_sample = data.decode_u16(pos + 22)
		elif chunk_id == "data":
			var data_start: int = pos + 8
			var data_end: int = mini(data_start + chunk_size, data.size())
			pcm_data = data.slice(data_start, data_end)
		
		pos += 8 + chunk_size
		# Align to even byte
		if chunk_size % 2 == 1:
			pos += 1
	
	# Validate parsed data
	if format != 1:  # 1 = PCM
		_log_error("[AudioLoader] Failed to decode WAV: unsupported format (only PCM supported)")
		return null
	if channels == 0 or sample_rate == 0 or bits_per_sample == 0:
		_log_error("[AudioLoader] Failed to decode WAV: missing fmt chunk data")
		return null
	if pcm_data.is_empty():
		_log_error("[AudioLoader] Failed to decode WAV: missing data chunk")
		return null
	
	# Create AudioStreamWAV
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.mix_rate = sample_rate
	stream.stereo = (channels == 2)
	
	match bits_per_sample:
		8:
			stream.format = AudioStreamWAV.FORMAT_8_BITS
		16:
			stream.format = AudioStreamWAV.FORMAT_16_BITS
		_:
			_log_error("[AudioLoader] Failed to decode WAV: unsupported bits per sample: %d" % bits_per_sample)
			return null
	
	stream.data = pcm_data
	
	if stream.get_length() <= 0:
		_log_error("[AudioLoader] Failed to decode WAV: zero length audio")
		return null
	
	return stream
