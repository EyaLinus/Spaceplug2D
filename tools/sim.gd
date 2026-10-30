extends SceneTree
## Balance sim: runs the scripted bot on several seeds and prints metrics.
## godot --headless --path . -s res://tools/sim.gd -- [--runs 5] [--seed 100]

const Data = preload("res://scripts/core/data.gd")
const Bot = preload("res://tools/bot.gd")


func _init() -> void:
	var runs := 5
	var seed0 := 100
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--runs":
			runs = int(args[i + 1])
		elif args[i] == "--seed":
			seed0 = int(args[i + 1])
	var data := Data.load_all()
	var won := 0
	var days := 0
	for r in runs:
		var res: Dictionary = Bot.play(data, seed0 + r)
		print("SIM seed=%d state=%s day=%d credits=%d debt=%d earned=%d units=%d busts=%d upgrades=%s" % [
			seed0 + r, res.state, res.day, res.credits, res.debt, res.earned, res.units, res.busts, res.upgrades])
		if res.state == "won":
			won += 1
			days += res.day
	print("SUMMARY won=%d/%d avg_win_day=%.1f" % [won, runs, float(days) / maxi(won, 1)])
	quit()
