class_name ShopHours
extends RefCounted

# When the restaurant takes new customers. Time keeps running either way; a closed restaurant only gets no new arrivals
# (customers already inside are served as usual). The player sets the opening and closing hour; "open now" / "close now" override
# the schedule until the schedule next changes (the next opening or closing time), then the schedule takes over again.
const DEFAULT_OPEN := 9
const DEFAULT_CLOSE := 21
const EPS := 0.001   # clock floats a hair under a whole hour still count as that hour

var open_hour: int = DEFAULT_OPEN
var close_hour: int = DEFAULT_CLOSE
var override: String = ""             # "", "open" or "closed"
var _override_sched: bool = false     # whether the schedule said open when the override was set

func reset() -> void:
	open_hour = DEFAULT_OPEN
	close_hour = DEFAULT_CLOSE
	override = ""
	_override_sched = false

# What the schedule alone says at game-clock `hour` (0..24).
func scheduled_open(hour: float) -> bool:
	return hour >= float(open_hour) - EPS and hour < float(close_hour) - EPS

# Whether new customers come at `hour`: the override while the schedule has not changed since it was set, else the schedule.
func is_open(hour: float) -> bool:
	var sched := scheduled_open(hour)
	if override != "" and sched == _override_sched:
		return override == "open"
	return sched

# Drops an override the schedule has moved past (call as the clock runs).
func refresh(hour: float) -> void:
	if override != "" and scheduled_open(hour) != _override_sched:
		override = ""

func force(open: bool, hour: float) -> void:
	override = "open" if open else "closed"
	_override_sched = scheduled_open(hour)

# Sets the hours: opening 0..23, closing after it up to 24 (at least one hour open). The hour being asked for wins; the other is moved.
func set_hours(open_at: int, close_at: int, hour: float) -> void:
	open_at = clampi(open_at, 0, 23)
	close_at = clampi(close_at, open_at + 1, 24)
	open_hour = open_at
	close_hour = close_at
	refresh(hour)

func to_dict() -> Dictionary:
	return {"open": open_hour, "close": close_hour, "override": override, "sched": _override_sched}

func load_dict(d: Dictionary) -> void:
	open_hour = clampi(int(d.get("open", DEFAULT_OPEN)), 0, 23)
	close_hour = clampi(int(d.get("close", DEFAULT_CLOSE)), open_hour + 1, 24)
	var o := str(d.get("override", ""))
	override = o if o == "open" or o == "closed" else ""
	_override_sched = bool(d.get("sched", false))
