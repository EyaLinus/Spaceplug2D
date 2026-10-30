extends Node
## Audio manager: synthesizes all sound effects at startup (no audio assets needed yet),
## plays one-shots through a small player pool and keeps two loops (engine thrust, ambient drone).
## Reacts to EventBus game events so gameplay code never calls audio directly.

const RATE := 22050
const POOL := 8

var enabled := true
var sfx_volume_db := -6.0
var sounds: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _thrust: AudioStreamPlayer
var _ambient: AudioStreamPlayer


func _ready() -> void:
	sounds = {
		"click": _tone(880.0, 0.05, 0.4, "square"),
		"buy": _sweep(500.0, 900.0, 0.12, 0.5),
		"sell": _chord([660.0, 990.0, 1320.0], 0.35, 0.45),
		"dock": _sweep(300.0, 150.0, 0.4, 0.5),
		"undock": _sweep(150.0, 400.0, 0.35, 0.5),
		"alarm": _tone(1200.0, 0.18, 0.35, "square"),
		"bust": _sweep(400.0, 80.0, 0.8, 0.6, "square"),
		"lab_done": _chord([523.0, 784.0], 0.4, 0.4),
		"error": _tone(180.0, 0.15, 0.4, "square"),
		"upgrade": _chord([392.0, 523.0, 659.0, 784.0], 0.6, 0.4),
	}
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_thrust = AudioStreamPlayer.new()
	_thrust.stream = _noise_loop(0.5, 0.25)
	_thrust.volume_db = -80.0
	add_child(_thrust)
	_ambient = AudioStreamPlayer.new()
	_ambient.stream = _drone_loop(4.0)
	_ambient.volume_db = -18.0
	add_child(_ambient)
	EventBus.game_event.connect(_on_game_event)
	EventBus.toast.connect(func(_t: String, good: bool): if not good: play("error"))


func play(name: String) -> void:
	if not enabled or not sounds.has(name):
		return
	for p in _pool:
		if not p.playing:
			p.stream = sounds[name]
			p.volume_db = sfx_volume_db
			p.play()
			return


func set_thrust(amount: float) -> void:
	if not enabled:
		return
	if amount > 0.01 and not _thrust.playing:
		_thrust.play()
	_thrust.volume_db = lerpf(-60.0, -14.0, clampf(amount, 0.0, 1.0)) if amount > 0.01 else -80.0


func set_ambient(on: bool) -> void:
	if on and enabled and not _ambient.playing:
		_ambient.play()
	elif not on:
		_ambient.stop()


func set_enabled(on: bool) -> void:
	enabled = on
	if not on:
		_thrust.stop()
		_ambient.stop()
		for p in _pool:
			p.stop()


func _on_game_event(kind: String, _payload: Dictionary) -> void:
	match kind:
		"bought": play("buy")
		"sold": play("sell")
		"docked": play("dock")
		"undocked": play("undock")
		"busted": play("bust")
		"lab_done": play("lab_done")
		"upgraded": play("upgrade")


# ---------------------------------------------------------------- synthesis

func _wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = samples.size()
	return w


static func _osc(phase: float, wave: String) -> float:
	match wave:
		"square":
			return 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
		_:
			return sin(phase * TAU)


static func _env(t: float, length: float) -> float:
	var attack := 0.005
	return minf(t / attack, 1.0) * pow(1.0 - t / length, 2.0)


func _tone(freq: float, length: float, vol: float, wave := "sine") -> AudioStreamWAV:
	var n := int(length * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		s[i] = _osc(freq * t, wave) * _env(t, length) * vol
	return _wav(s)


func _sweep(f0: float, f1: float, length: float, vol: float, wave := "sine") -> AudioStreamWAV:
	var n := int(length * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		phase += lerpf(f0, f1, t / length) / RATE
		s[i] = _osc(phase, wave) * _env(t, length) * vol
	return _wav(s)


func _chord(freqs: Array, length: float, vol: float) -> AudioStreamWAV:
	var n := int(length * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for k in freqs.size():
			# arpeggio: each note starts a bit later
			var start := k * 0.04
			if t >= start:
				v += sin(freqs[k] * (t - start) * TAU) * _env(t - start, length - start)
		s[i] = v / freqs.size() * vol
	return _wav(s)


func _noise_loop(length: float, vol: float) -> AudioStreamWAV:
	var n := int(length * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var r := RandomNumberGenerator.new()
	r.seed = 42
	var lp := 0.0
	for i in n:
		lp = lerpf(lp, r.randf_range(-1.0, 1.0), 0.15)  # low-passed noise = rumble
		s[i] = lp * vol * 2.5
	return _wav(s, true)


func _drone_loop(length: float) -> AudioStreamWAV:
	var n := int(length * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	# frequencies chosen as whole cycles per loop so the loop is seamless
	var f := [55.0, 82.5, 110.25, 164.75]
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for k in f.size():
			v += sin(f[k] * t * TAU) * (0.5 + 0.5 * sin(TAU * t / length * (k + 1)))
		s[i] = v * 0.12
	return _wav(s, true)
