class_name Judge

# Judgement, EX score and groove gauge rules of beatmania IIDX, shared by main.gd and main_netplay.gd

# Judgement windows in ms, early or late (one 60 fps frame = 16.67 ms)
const PGREAT_WINDOW : float = 16.67
const GREAT_WINDOW  : float = 33.33
const GOOD_WINDOW   : float = 116.67
const BAD_WINDOW    : float = 250.0
# A key pressed this early before a note is an empty POOR: it only hurts the gauge
const EMPTY_POOR_WINDOW : float = 500.0
# EX score of each judgement, the others give nothing
const EX_POINTS : Dictionary = {"PGreat": 2, "Great": 1}

# Gauge levels, like Global.gauge_level
const NORMAL : int = 0
const EASY   : int = 1
const HARD   : int = 2
# Gauge lost by each judgement in percent, the others recover it
const DAMAGE : Dictionary = {
	NORMAL: {"Bad": 2.0, "Poor": 6.0, "EmptyPoor": 2.0},
	EASY:   {"Bad": 1.6, "Poor": 4.8, "EmptyPoor": 1.6},
	HARD:   {"Bad": 6.0, "Poor": 10.0, "EmptyPoor": 2.0},
}
# HARD gauge recovered by a PGREAT or GREAT, whatever the number of notes
const HARD_RECOVERY : float = 0.16
# HARD damage is halved at this gauge and below
const HARD_HALF_DAMAGE : float = 30.0

# Judgement of a hit, offset in seconds (negative when early), "" when out of the windows
static func judge(offset : float) -> String:
	var ms : float = absf(offset) * 1000.0
	if ms <= PGREAT_WINDOW:
		return "PGreat"
	if ms <= GREAT_WINDOW:
		return "Great"
	if ms <= GOOD_WINDOW:
		return "Good"
	if ms <= BAD_WINDOW:
		return "Bad"
	return ""

# Number of judgements of a chart, a long note is judged on press and on release like a CN
static func noteCount(noteArray : Array) -> int:
	var result : int = 0
	for lane in noteArray:
		for note in lane:
			result += 1 if len(note) == 1 else 2
	return result

# Gauge at the start of the song
static func gaugeStart(level : int) -> float:
	return 100.0 if level == HARD else 22.0

# NORMAL and EASY gauge recovered by a PGREAT or GREAT: the whole chart gives 7.605 × n / (0.01 × n + 6.5) %
static func gaugeRecovery(level : int, notes : int) -> float:
	if level == HARD:
		return HARD_RECOVERY
	return 7.605 / (0.01 * notes + 6.5)

# Gauge after a judgement, GOOD recovers half (nothing on HARD)
static func gaugeChange(level : int, judgement : String, gauge : float, recovery : float) -> float:
	if DAMAGE[level].has(judgement):
		var damage : float = DAMAGE[level][judgement]
		if level == HARD and gauge <= HARD_HALF_DAMAGE:
			damage /= 2.0
		gauge -= damage
	elif judgement == "PGreat" or judgement == "Great":
		gauge += recovery
	elif judgement == "Good" and level != HARD:
		gauge += recovery / 2.0
	# NORMAL and EASY never go under 2 %, HARD fails at 0
	return clampf(gauge, 0.0 if level == HARD else 2.0, 100.0)

# Gauge shown by steps of 2 % like the IIDX gauge, at least 2 % while HARD is alive
static func gaugeDisplay(level : int, gauge : float) -> int:
	var shown : int = int(gauge / 2.0) * 2
	if level == HARD and gauge > 0.0:
		shown = maxi(shown, 2)
	return shown
