extends Node

# Preview of the song under the cursor of the music select, like IIDX.
# The categories and the random entries play the music select BGM instead.
# The songs are loaded in a thread: a module is replayed and a BMS loads all its keysounds.

# The cursor often only passes over a song, wait before loading it (seconds)
const DELAY = 0.4
# The preview starts again after this time, with a fade in and a fade out (seconds)
const LENGTH = 20.0
const FADE_IN = 0.2
const FADE_OUT = 1.0
# Start of the preview when the chart gives none, as a part of the song
const DEFAULT_START = 1.0 / 3.0
const BUS = "Preview"

var bgm: AudioStreamPlayer
# Song to preview, "" for the BGM
var path = ""
var delay = 0.0
# Loadings in progress: [task id, {path, result}], result is [player, start, duration] or empty
var jobs: Array = []
# AudioStreamPlayer, ModPlayer or BmsPlayer of the preview
var player: Node
var start = 0.0
var duration = 0.0
var time = 0.0

func _ready() -> void:
	# The buses are created here, the threads only read them
	if AudioServer.get_bus_index(BUS) == -1:
		AudioServer.add_bus()
		var index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, BUS)
		AudioServer.set_bus_send(index, "Master")
	ModPlayer.panningBus(-1.0, BUS)
	ModPlayer.panningBus(1.0, BUS)

func select(new_path: String) -> void:
	if new_path == path:
		return
	path = new_path
	delay = DELAY
	stop_preview()
	bgm.stream_paused = path != ""

func stop_preview() -> void:
	if player != null:
		player.queue_free()
		player = null

func _process(delta: float) -> void:
	collect_jobs()
	if path != "" and player == null and delay > 0.0:
		delay -= delta
		# Coming back to a song still loading waits for it
		if delay <= 0.0 and not jobs.any(func(job): return job[1].path == path):
			var job = {"path": path, "result": []}
			jobs.append([WorkerThreadPool.add_task(load_preview.bind(job)), job])
	if player == null:
		return
	time += delta
	if time >= duration:
		restart()
	var fade = clampf(minf(time / FADE_IN, (duration - time) / FADE_OUT), 0.0, 1.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS), linear_to_db(fade) if fade > 0.0 else -80.0)

# Play the loaded song if it is still under the cursor
func collect_jobs() -> void:
	for job in jobs.duplicate():
		if not WorkerThreadPool.is_task_completed(job[0]):
			continue
		WorkerThreadPool.wait_for_task_completion(job[0])
		jobs.erase(job)
		var result = job[1].result
		if result.is_empty():
			continue
		if job[1].path != path or player != null:
			result[0].free()
			continue
		duration = minf(LENGTH, result[2] - result[1])
		if duration <= 0.0:
			result[0].free()
			continue
		player = result[0]
		start = result[1]
		add_child(player)
		restart()

func restart() -> void:
	time = 0.0
	if player is AudioStreamPlayer:
		player.play(start)
	else:
		player.play_from(start)

func _exit_tree() -> void:
	for job in jobs:
		WorkerThreadPool.wait_for_task_completion(job[0])
		if not job[1].result.is_empty():
			job[1].result[0].free()
	jobs.clear()

# Runs in a thread, the player is not in the tree yet
func load_preview(job: Dictionary) -> void:
	var file: String = job.path
	var dir = file.get_base_dir()
	if file.get_extension().to_lower() == "qua":
		var chart = QuaChart.load_file(file)
		if chart == null:
			return
		var stream = load_stream(dir.path_join(chart.audioFile))
		if stream == null:
			return
		var length = stream.get_length()
		var from = chart.previewTime if chart.previewTime >= 0.0 and chart.previewTime < length else length * DEFAULT_START
		job.result = [stream_player(stream), from, length]
	elif ModModule.is_module(file):
		var module = ModModule.load_file(file)
		if module == null:
			return
		job.result = [ModPlayer.new(module, BUS), measure_start(module.measures, module.length), module.length]
	elif BmsChart.is_bms(file):
		var chart = BmsChart.load_file(file, false)
		if chart == null:
			return
		# A preview file is much faster than all the keysounds
		if chart.previewFile != "":
			var files = {}
			BmsPlayer.indexFiles(dir, "", files)
			var stream = BmsPlayer.loadSound(dir, chart.previewFile, files)
			if stream != null:
				job.result = [stream_player(stream), 0.0, stream.get_length()]
				return
		var bms_player = BmsPlayer.new(chart, dir, BUS)
		var length = bms_player.length - BmsChart.LEAD_IN
		var measures = chart.measures.map(func(t): return t - BmsChart.LEAD_IN)
		job.result = [bms_player, measure_start(measures, length), length]

static func load_stream(file: String) -> AudioStream:
	match file.get_extension().to_lower():
		"mp3":
			return AudioStreamMP3.load_from_file(file)
		"ogg":
			return AudioStreamOggVorbis.load_from_file(file)
	return null

static func stream_player(stream: AudioStream) -> AudioStreamPlayer:
	var audio_player = AudioStreamPlayer.new()
	audio_player.stream = stream
	audio_player.bus = BUS
	return audio_player

# The measure closest to the default start, the music is easier to follow from there
static func measure_start(measures: Array, length: float) -> float:
	var target = length * DEFAULT_START
	var best = 0.0
	for t in measures:
		if t >= 0.0 and absf(t - target) < absf(best - target):
			best = t
	return best
