extends SceneTree
## B28 probe: what duration does Godot's AudioStreamWAV report for each
## voice file? (the suite's formula said 1.0 s for one file that the
## OS-level wave module says is 5+ s)

func _init() -> void:
	for i in 31:
		var names := ["velvet", "pilsner", "marrow", "duchess", "mama_sun",
			"ash", "tam", "raz", "drunk", "okafor", "kessler", "mechanic",
			"club_owner", "yuen", "narrator"]
		var vi: int = i / 2
		var n: int = i % 2 + 1
		var path := "res://assets/voice/%s_%02d.wav" % [names[vi], n]
		if vi == 14:
			path = "res://assets/voice/narrator_%02d.wav" % n
		if not ResourceLoader.exists(path):
			print("PROBE missing: ", path)
			continue
		var st := load(path)
		if st is AudioStreamWAV:
			var wav := st as AudioStreamWAV
			print("PROBE %s: %.2fs (mix %d, bytes %d, fmt %d)" % [
					path.get_file(), float(wav.data.size()) / 2.0
					/ float(wav.mix_rate), wav.mix_rate,
					wav.data.size(), wav.format])
		else:
			print("PROBE %s: not a WAV stream (%s)" % [path.get_file(),
					str(st.get_class())])
	quit()
