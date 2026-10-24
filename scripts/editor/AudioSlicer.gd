extends RefCounted
class_name AudioSlicer

# Audio work of the BMS editor: decoding a song, cutting it into keysounds (16 bits WAV files like most BMS),
# cutting a keysound in two, and the envelope of a sound for the waveform. Can run in a thread.

# A slice goes on a little after its end, fading out: a slice started a frame late leaves no gap
const TAIL : float = 0.025
# Fade at the start of a slice, against the click of a sound starting on a non zero sample
const FADE_IN : float = 0.002
# Bins per second of the envelopes
const ENVELOPE_RATE : float = 200.0
# Frames read at once, and frames skipped when looking for the peaks
const MIX_FRAMES : int = 8192
const ENVELOPE_STRIDE : int = 4

static func loadStream(file : String) -> AudioStream:
	match file.get_extension().to_lower():
		"ogg":
			return AudioStreamOggVorbis.load_from_file(file)
		"wav":
			return AudioStreamWAV.load_from_file(file)
		"mp3":
			return AudioStreamMP3.load_from_file(file)
	return null

static func mixRate() -> int:
	return int(AudioServer.get_mix_rate())

# All the frames of a stream, at the mix rate of the audio server
static func decode(stream : AudioStream) -> PackedVector2Array:
	var frames : PackedVector2Array = []
	if stream == null:
		return frames
	var playback : AudioStreamPlayback = stream.instantiate_playback()
	var total : int = int(stream.get_length() * mixRate())
	playback.start(0.0)
	while frames.size() < total and playback.is_playing():
		frames.append_array(playback.mix_audio(1.0, mini(MIX_FRAMES, total - frames.size())))
	return frames

# Peak of each 1/ENVELOPE_RATE s of frames [from, to)
static func envelope(frames : PackedVector2Array, from : int = 0, to : int = -1) -> PackedFloat32Array:
	if to < 0:
		to = frames.size()
	var step : float = mixRate() / ENVELOPE_RATE
	var bins : PackedFloat32Array = []
	bins.resize(ceili((to - from) / step))
	for i in range(from, to, ENVELOPE_STRIDE):
		var bin : int = int((i - from) / step)
		var v : Vector2 = frames[i]
		bins[bin] = maxf(bins[bin], maxf(absf(v.x), absf(v.y)))
	return bins

static func soundEnvelope(file : String) -> PackedFloat32Array:
	return envelope(decode(loadStream(file)))

# Write the frames [from, to) as a slice, its tail taken after `to`
static func writeSlice(frames : PackedVector2Array, from : int, to : int, file : String, fadeIn : bool) -> Error:
	var rate : int = mixRate()
	var end : int = mini(to + int(TAIL * rate), frames.size())
	var data : PackedByteArray = []
	data.resize((end - from) * 4)
	var k : int = 0
	for i in range(from, end):
		var v : Vector2 = frames[i]
		data.encode_s16(k, clampi(int(v.x * 32767.0), -32768, 32767))
		data.encode_s16(k + 2, clampi(int(v.y * 32767.0), -32768, 32767))
		k += 4
	if fadeIn:
		fade(data, 2, 0, int(FADE_IN * rate), true)
	fade(data, 2, to - from, end - from, false)
	return saveWav(data, rate, true, file)

# Cut a 16 bits WAV in two at `at` seconds: the first part keeps a fading tail, the second one starts with a short fade in
static func splitWav(file : String, at : float, firstFile : String, secondFile : String) -> bool:
	var wav : AudioStreamWAV = AudioStreamWAV.load_from_file(file)
	if wav == null or wav.format != AudioStreamWAV.FORMAT_16_BITS:
		return false
	var channels : int = 2 if wav.stereo else 1
	var frameBytes : int = 2 * channels
	var frames : int = wav.data.size() / frameBytes
	var cut : int = int(at * wav.mix_rate)
	if cut <= 0 or cut >= frames:
		return false
	var end : int = mini(cut + int(TAIL * wav.mix_rate), frames)
	var first : PackedByteArray = wav.data.slice(0, end * frameBytes)
	fade(first, channels, cut, end, false)
	var second : PackedByteArray = wav.data.slice(cut * frameBytes)
	fade(second, channels, 0, int(FADE_IN * wav.mix_rate), true)
	return saveWav(first, wav.mix_rate, wav.stereo, firstFile) == OK and saveWav(second, wav.mix_rate, wav.stereo, secondFile) == OK

# Linear fade of the frames [from, to) of 16 bits data
static func fade(data : PackedByteArray, channels : int, from : int, to : int, fadeIn : bool) -> void:
	var frames : int = data.size() / (2 * channels)
	to = mini(to, frames)
	for i in range(from, to):
		var gain : float = float(i - from) / (to - from)
		if not fadeIn:
			gain = 1.0 - gain
		for c in channels:
			var at : int = (i * channels + c) * 2
			data.encode_s16(at, int(data.decode_s16(at) * gain))

static func saveWav(data : PackedByteArray, rate : int, stereo : bool, file : String) -> Error:
	var wav : AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = stereo
	wav.data = data
	return wav.save_to_wav(file)

# Short sine click of the metronome and the hitsounds
static func click(frequency : float, length : float = 0.05) -> AudioStreamWAV:
	var rate : int = 44100
	var data : PackedByteArray = []
	data.resize(int(rate * length) * 2)
	for i in data.size() / 2:
		var t : float = float(i) / rate
		data.encode_s16(i * 2, int(sin(TAU * frequency * t) * exp(-t * 60.0) * 26000))
	var stream : AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	return stream
