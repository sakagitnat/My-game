class_name DayClock
extends RefCounted

# The time of day in the game. It runs only while the game is open, and for now it only changes how things look
# (tint, shadows); nothing in the rules depends on it. Later features (a visitor who only comes in the evening) can ask
# phase() or hour(). DAY_SECONDS is the one knob: how many real seconds of play make one game day.
const DAY_SECONDS := 720.0
const PHASES: Array[String] = ["morning", "day", "evening", "night"]
# where each phase starts, as a fraction of the day (the day begins with the morning)
const PHASE_START: Array[float] = [0.0, 1.0 / 6.0, 0.5, 2.0 / 3.0]
const START_HOUR := 6.0   # game clock hour at t = 0
# colour the whole scene is multiplied by, at the middle of each phase (it fades between them)
const TINT_KEYS := [
	[1.0 / 12.0, Color(1.0, 0.94, 0.84)],
	[1.0 / 3.0, Color(1.0, 1.0, 1.0)],
	[7.0 / 12.0, Color(1.0, 0.74, 0.58)],
	[5.0 / 6.0, Color(0.36, 0.42, 0.68)],
]
const SUN_UP_UNTIL := 2.0 / 3.0   # the sun is up from the start of the morning to the end of the evening

var t: float = 0.0       # 0..1 through the day; 0 is the start of the morning
var days: int = 0        # whole days gone by since the game began
var speed: float = 1.0   # 1 = normal; tests and the test button may change it

func reset() -> void:
	t = 0.0
	days = 0

# A new game begins at 9:00 (the restaurant's default opening hour), not at the start of the morning.
const NEW_GAME_HOUR := 9.0

func start_new_game() -> void:
	t = (NEW_GAME_HOUR - START_HOUR) / 24.0 + 0.0005

func tick(delta: float) -> void:
	t += delta * speed / DAY_SECONDS
	while t >= 1.0:
		t -= 1.0
		days += 1

func phase_index() -> int:
	var i := 0
	for k in range(PHASES.size()):
		if t >= PHASE_START[k]:
			i = k
	return i

func phase() -> String:
	return PHASES[phase_index()]

# Game clock hour, 0..24 (the morning starts at 6:00, the night runs from 22:00 to 6:00).
func hour() -> float:
	return fmod(START_HOUR + t * 24.0, 24.0)

# Jumps to the middle of the next phase (where its look is at its fullest). For testing.
func skip_to_next_phase() -> void:
	var next := (phase_index() + 1) % PHASES.size()
	if next == 0:
		days += 1
	var end := PHASE_START[next + 1] if next + 1 < PHASES.size() else 1.0
	t = (PHASE_START[next] + end) * 0.5

# What the scene is multiplied by now: warm in the morning, white at noon, orange in the evening, deep blue at night.
func tint() -> Color:
	var n := TINT_KEYS.size()
	var tt := t if t >= float(TINT_KEYS[0][0]) else t + 1.0   # before the first key we are between last night and this morning
	for i in range(n):
		var a: Array = TINT_KEYS[i]
		var b: Array = TINT_KEYS[(i + 1) % n]
		var ta: float = a[0]
		var tb: float = float(b[0]) + (1.0 if i == n - 1 else 0.0)
		if tt >= ta and tt < tb:
			return (a[1] as Color).lerp(b[1], smoothstep(0.0, 1.0, (tt - ta) / (tb - ta)))
	return Color.WHITE

# Shadow look now: dir -1..1 (which side they fall to: right in the morning, left in the evening), length (1 = a cell-ish
# ellipse stretched by this), alpha. Long and soft at dawn and dusk, short and dark at noon, faint at night.
func sun() -> Dictionary:
	var dir := 0.0
	var height := 0.0
	if t < SUN_UP_UNTIL:
		var s := t / SUN_UP_UNTIL
		dir = cos(PI * s)
		height = sin(PI * s)
	else:
		dir = -cos(PI * (t - SUN_UP_UNTIL) / (1.0 - SUN_UP_UNTIL))   # the moon's faint shadows drift back from left to right
	return {"dir": dir, "height": height, "length": lerpf(1.7, 0.85, height), "alpha": lerpf(0.10, 0.30, sqrt(height))}

func to_dict() -> Dictionary:
	return {"t": t, "days": days}

func load_dict(d: Dictionary) -> void:
	t = clampf(float(d.get("t", 0.0)), 0.0, 0.99999)
	days = maxi(0, int(d.get("days", 0)))
