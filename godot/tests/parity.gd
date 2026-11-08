# Parity test: the GDScript engine must replay the JS engine exactly.
# Run from the project folder:
#   godot --headless --path <repo root> -s res://godot/tests/parity.gd
# Expected values were produced by the JS engine in the Cut the Deck artifact
# with the same seeds and the same greedy bot (play the first playable card,
# else end turn; take the first reward; leave every workshop).

extends SceneTree

const DB := preload("res://godot/engine/db.gd")
const Rng := preload("res://godot/engine/rng.gd")
const Run := preload("res://godot/engine/run.gd")
const Combat := preload("res://godot/engine/combat.gd")

const EXPECT_RNG42 := "0.601103752,0.448290559,0.852465793,0.669734041,0.174813899"
const EXPECT_BOT := {
	1: "defeat hp=0 node=5 deck=14 ink=18 lines=280 md5=3501e761c94d575c5f705caffc78cfb4",
	12345: "defeat hp=0 node=5 deck=14 ink=18 lines=412 md5=46656bfdc279fdae063d6bcd41d7e945",
	777: "defeat hp=0 node=5 deck=14 ink=18 lines=234 md5=872d92baf5659ad364410cf42d2468f6",
}


func _init() -> void:
	var db := DB.load_db()
	var failures := 0

	var s := {"seed": 42}
	var vals := []
	for i in 5:
		vals.append("%.9f" % Rng.rand(s))
	failures += _check("rng seed 42", ",".join(PackedStringArray(vals)), EXPECT_RNG42)

	for rs in EXPECT_BOT:
		failures += _check("bot run seed %d" % rs, _bot(db, rs), EXPECT_BOT[rs])

	print("" if failures else "ALL PARITY CHECKS PASSED")
	quit(1 if failures else 0)


func _check(label: String, got: String, want: String) -> int:
	if got == want:
		print("ok    %s" % label)
		return 0
	print("FAIL  %s\n      got:  %s\n      want: %s" % [label, got, want])
	return 1


func _bot(db: Dictionary, rng_seed: int) -> String:
	var run := Run.new_run(db, rng_seed)
	var lines := []
	for guard in 500:
		var phase: String = run["phase"]
		if phase == "victory" or phase == "defeat":
			break
		match phase:
			"map":
				Run.enter_node(db, run)
			"combat":
				var c: Dictionary = run["combat"]
				var turns := 0
				while c["phase"] == "player" and turns < 200:
					var played := false
					for uid in c["hand"]:
						if Combat.play_info(db, c, uid)["can"]:
							Combat.play_card(db, c, uid, c["target"])
							played = true
							break
					if not played:
						Combat.end_turn(db, c)
						turns += 1
				for l in c["log"]:
					lines.append("%d %s" % [l["turn"], l["msg"]])
				Run.finish_combat(db, run)
			"reward":
				Run.take_reward(db, run, run["reward"]["choices"][0])
			"workshop":
				Run.leave_workshop(db, run)
	var text := "\n".join(PackedStringArray(lines))
	return "%s hp=%d node=%d deck=%d ink=%d lines=%d md5=%s" % [run["phase"], run["hp"], run["node"], run["deck"].size(), run["ink"], lines.size(), text.md5_text()]
