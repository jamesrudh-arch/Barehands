#!/usr/bin/env python3
"""B14b: pin the witness dice in the suites.

Heat.add() scales gains by who's watching (bible 4I crowds-are-
witnesses, B12): 0 wanderers near the player = alley_mult 0.6,
exactly 1 = x1.0, 2+ = witness_mult 1.5. Wanderers ROAM, so the eye
count at assertion time was a dice roll the suites were losing
once in a while (the B14 battery caught backroom + jobs red at
x0.6). Fix: a test pin on Heat - suites freeze the eye count at 1
(the x1.0 band) so every existing expected number stands exactly as
written. Default -1 keeps the live scan for the game itself.
"""
import re

P = "/home/z/my-project/bare-hands/"

# 1. heat.gd: the pin
s = open(P + "scripts/heat.gd").read()
old = """func add(amount: float) -> void:
	var was := heat
	# crowds are witnesses, alleys are not (bible 4I): a street with
	# eyes pays you back, an empty one lets it slide
	var p := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if p and amount > 0.0:
		var eyes := 0
		for w in get_tree().get_nodes_in_group("wanderer"):
			if (w as Node3D).global_position.distance_to(
					p.global_position) < 10.0:
				eyes += 1
		if eyes >= 2:
			amount *= float(Tuning.v("witness_mult"))
		elif eyes == 0:
			amount *= float(Tuning.v("alley_mult"))"""
assert old in s, "heat.add anchor"
new = """var test_pin_eyes := -1  # suites pin this (>= 0) to freeze the witness count


func add(amount: float) -> void:
	var was := heat
	# crowds are witnesses, alleys are not (bible 4I): a street with
	# eyes pays you back, an empty one lets it slide. Suites pin
	# test_pin_eyes (the x1.0 single-witness band) so heat arithmetic
	# is deterministic - wanderers roam, and a roaming witness is a
	# dice roll no assertion should ride on.
	var p := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if p and amount > 0.0:
		var eyes := test_pin_eyes
		if eyes < 0:
			eyes = 0
			for w in get_tree().get_nodes_in_group("wanderer"):
				if (w as Node3D).global_position.distance_to(
						p.global_position) < 10.0:
					eyes += 1
		if eyes >= 2:
			amount *= float(Tuning.v("witness_mult"))
		elif eyes == 0:
			amount *= float(Tuning.v("alley_mult"))"""
assert s.count(old) == 1
s = s.replace(old, new)
open(P + "scripts/heat.gd", "w").write(s)
print("heat pin added")

# 2. the suites: freeze the street at one pair of eyes
PIN = ('\t# one pair of eyes on the street: the witness multiplier sits at\n'
       '\t# x1.0 and every heat assertion in this suite is deterministic\n'
       '\tHeat.test_pin_eyes = 1\n')
for name in ["smoke_backroom", "smoke_jobs", "smoke_debt", "smoke_kidnap",
        "smoke_reactive", "smoke_worldsim", "smoke_economy", "smoke_combat"]:
    path = P + "tests/" + name + ".gd"
    s = open(path).read()
    if "Heat.test_pin_eyes" in s:
        print("already pinned:", name)
        continue
    m = re.search(r"func _ready\(\) -> void:\n", s)
    assert m, name + ": no _ready"
    s = s[:m.end()] + PIN + s[m.end():]
    open(path, "w").write(s)
    print("pinned:", name)

print("B14b pin complete")
