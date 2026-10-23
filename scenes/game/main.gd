extends Node2D

# The one game scene for 1P, 2P and local versus: both playfields are always on screen,
# the one of a player who is not playing stays dimmed like the empty side of IIDX.

# Time the WIN/LOSE banners stay on screen before the result screen
const RESULT_DELAY : float = 3.0
# Metal plate between the two playfields, with the song title and the BPM screens
const CENTER_PLATE : PackedVector2Array = [Vector2(496, 652), Vector2(508, 640), Vector2(772, 640), Vector2(784, 652), Vector2(784, 720), Vector2(496, 720)]
const TITLE_SCREEN : Rect2 = Rect2(512, 647, 256, 30)
const BPM_SCREEN : Rect2 = Rect2(572, 683, 136, 32)
# Time the effector name replaces the title after it changes
const EFFECTOR_SHOW_TIME : float = 1.5
const EFFECTOR_COLOR : Color = Color(1.0, 0.75, 0.2)
const DECIDE_SCREEN : GDScript = preload("res://scenes/game/decide.gd")
const DECIDE_LAYER : int = 10
# TRAINING panel between the playfields, and the pause before a repeated section
const TRAINING_PANEL : GDScript = preload("res://scripts/training/training_panel.gd")
const TRAINING_RECT : Rect2 = Rect2(442, 6, 396, 488)
const TRAINING_REPEAT_DELAY : float = 1.0

var playersDone : int = 0
# Playfields that play, the first one gives the title and the BPM
var playing : Array[Playfield] = []
var netplay : bool = false
var songTitle : String = ""
@onready var titleColor : Color = $Title.get_theme_color("font_color")
var effectorTimer : SceneTreeTimer
var trainingPanel : Control = null
var repeatTimer : Timer = null

func _ready() -> void:
	# Netplay plays alone on this machine, the other side shows the live ranking
	var versus : bool = Global.p1_joined and Global.p2_joined
	netplay = not versus and Netplay.in_round()
	var solo : int = 2 if Global.p2_joined and not Global.p1_joined else 1
	# DOUBLE PLAY: the player alone plays both sides, with the inputs of both decks
	var double : bool = not versus and not netplay and Global.is_double_play()
	for side in [1, 2]:
		var field : Playfield = get_node("P%d" % side)
		var plays : bool = versus or double or side == solo
		field.setup(solo if double else side, plays, versus, netplay, side)
		if plays:
			playing.append(field)
		# In netplay the live ranking takes the place of the empty side, which is hidden
		elif netplay:
			field.hide()
		# The PACEMAKER graph of a player alone takes the place of the empty side, like on IIDX (not in TRAINING)
		elif not versus and not Training.active and Global.get_player_var(solo, "pacemaker") != 0:
			field.hide()
			var player_field : Playfield = get_node("P%d" % solo)
			player_field.pacemakerRect = Rect2(field.position - player_field.position + Playfield.SIDE_AREA.position, Playfield.SIDE_AREA.size)
	if double:
		$P1.pairWith($P2)
	if versus and not Training.active:
		$P1.finished.connect(playerFinished)
		$P2.finished.connect(playerFinished)
	if netplay:
		var scoreboard : Control = preload("res://scripts/netplay/scoreboard.gd").new()
		scoreboard.position = Vector2($P2.position.x, 0)
		scoreboard.size = Vector2(Playfield.PLAYFIELD_WIDTH, 540)
		add_child(scoreboard)
	# The DECIDE screen covers the loading, then shows the song and the options before the game.
	# Not when TRAINING opens the scene again for another difficulty
	var decide : Control = null
	if not (Training.active and Training.reload):
		var layer : CanvasLayer = CanvasLayer.new()
		layer.layer = DECIDE_LAYER
		add_child(layer)
		decide = DECIDE_SCREEN.new()
		layer.add_child(decide)
	await get_tree().process_frame
	await get_tree().process_frame
	for field in playing:
		field.decide = decide
		field.start()
	var info : Dictionary = playing[0].songInfo if not playing.is_empty() else {}
	songTitle = info.get("title", "")
	$Title.text = songTitle
	if decide:
		decide.play(songTitle if songTitle != "" else Loader.file_path.get_file().get_basename(),
			info.get("artist", ""), Loader.chart_difficulty, info.get("level", 0))
	if Training.active:
		setupTraining(decide)

func _process(_delta : float) -> void:
	queue_redraw()
	# The effector can be changed while playing, by either player
	if Effector.update_button(playing.map(func(field : Playfield) -> String: return field.prefix + "effect")):
		showEffector()

# The effector name takes the place of the title for a moment
func showEffector() -> void:
	$Title.text = Effector.current_name()
	$Title.add_theme_color_override("font_color", EFFECTOR_COLOR)
	effectorTimer = get_tree().create_timer(EFFECTOR_SHOW_TIME)
	var timer : SceneTreeTimer = effectorTimer
	await timer.timeout
	# A newer change keeps its own timer
	if timer != effectorTimer:
		return
	$Title.text = songTitle
	$Title.add_theme_color_override("font_color", titleColor)

func _draw() -> void:
	Playfield.drawMetal(self, CENTER_PLATE)
	Playfield.drawScreen(self, TITLE_SCREEN)
	Playfield.drawScreen(self, BPM_SCREEN)
	draw_string(Playfield.FONT, BPM_SCREEN.position + Vector2(10, 21), "BPM", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Playfield.LABEL_COLOR)
	var bpm : float = playing[0].currentBpm() if not playing.is_empty() else 0.0
	if bpm > 0.0:
		Playfield.drawNumber(self, Vector2(BPM_SCREEN.end.x - 10, BPM_SCREEN.position.y + 25), roundi(bpm), 3, 20)

func playerFinished() -> void:
	playersDone += 1
	if playersDone < 2:
		return
	# Both players are done, the highest score wins
	for player in [1, 2]:
		var result : String = Global.get_versus_result(player)
		var label : Label = get_node("P%dResult" % player)
		label.text = result
		label.add_theme_color_override("font_color", Global.VERSUS_RESULT_COLORS[result])
		label.show()
		get_node("P%d/getready" % player).hide()
	await get_tree().create_timer(RESULT_DELAY).timeout
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://scenes/result/result.tscn")

# TRAINING: the panel chooses the section, the playfields play it, then the panel comes back (or the section again)
func setupTraining(decide : Control) -> void:
	Training.reload = false
	# The chart could not be loaded, the scene is leaving
	if playing.is_empty() or playing[0].trainingNotes.is_empty():
		return
	trainingPanel = TRAINING_PANEL.new()
	trainingPanel.fields = playing
	trainingPanel.song_title = songTitle if songTitle != "" else Loader.file_path.get_file().get_basename()
	trainingPanel.position = TRAINING_RECT.position
	add_child(trainingPanel)
	trainingPanel.play_requested.connect(playTraining)
	for field in trainingScorers():
		field.finished.connect(trainingFinished)
	repeatTimer = Timer.new()
	repeatTimer.one_shot = true
	repeatTimer.timeout.connect(playTraining)
	add_child(repeatTimer)
	if decide and not decide.done:
		await decide.closed
	trainingPanel.enabled = true

# Play the section from the panel, the clock starts early enough for the first notes to come from the top
func playTraining() -> void:
	repeatTimer.stop()
	var first : Playfield = playing[0]
	var from : float = first.measureTime(Training.first_measure)
	var to : float = first.measureTime(Training.last_measure + 1)
	var begin : float = from - first.speed - Playfield.TRAINING_LEAD
	var rate : float = Training.rate()
	var keysounds = first.keysoundPlayer
	if keysounds:
		keysounds.stop()
		keysounds.owners.fill(0)
	else:
		$audio.stop()
	for field in playing:
		field.resetPlay()
	for field in playing:
		field.playSection(from, to, begin, rate)
	Training.set_bus_rate(rate)
	if keysounds:
		keysounds.play_from(begin - (ModChart.LEAD_IN if keysounds is ModPlayer else BmsChart.LEAD_IN), rate)
	trainingPanel.playing = true

# Playfields keeping a score: both in BATTLE, the 1P side in DOUBLE PLAY
func trainingScorers() -> Array:
	return playing.filter(func(field : Playfield) -> bool: return field.scorer == field)

# A side is done: the section is over when both sides of a BATTLE are, META on either side stops both.
# The panel then shows the scores, REPEAT plays the section again unless it was stopped
func trainingFinished() -> void:
	var scorers : Array = trainingScorers()
	var gaveUp : bool = scorers.any(func(field : Playfield) -> bool: return field.gaveUp)
	if not gaveUp and not scorers.all(func(field : Playfield) -> bool: return field.done):
		return
	for field in scorers:
		if not field.done:
			field.stop()
	if scorers[0].keysoundPlayer:
		scorers[0].keysoundPlayer.stop()
	else:
		$audio.stop()
	trainingPanel.section_over(scorers.map(func(field : Playfield) -> Dictionary: return {"player": field.player,
		"ex": field.exScore, "max_ex": field.noteCount * 2, "counts": field.judgeCounts.duplicate(), "combo": field.comboMax, "gave_up": gaveUp}))
	if Training.repeat and not gaveUp:
		repeatTimer.start(TRAINING_REPEAT_DELAY)
