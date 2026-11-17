#!/usr/bin/env python3
"""Phase 1 refactor: anonymous enums -> named State enums, class_name, no raw
int state literals, route hit emits through Fx.emit_hit. One-shot tool."""
import re, pathlib

ROOT = pathlib.Path("/home/z/my-project/bare-hands")

def sub_file(path, pairs, header_pairs=()):
    p = ROOT / path
    s = p.read_text()
    for old, new in header_pairs:
        assert old in s, f"{path}: header '{old}' not found"
        s = s.replace(old, new, 1)
    for old, new in pairs:
        s = re.sub(old, new, s)
    p.write_text(s)
    print(f"ok {path}")

# --- player.gd ---
sub_file(
    "scripts/player.gd",
    pairs=[
        (r"\benum \{ GROUND, AIR, CLIMB, PUNCH, DODGE \}",
         "enum State { GROUND, AIR, CLIMB, PUNCH, DODGE }"),
        (r"\bvar state := GROUND\b", "var state: State = State.GROUND"),
        (r"\bstate == GROUND\b", "state == State.GROUND"),
        (r"\bstate == AIR\b", "state == State.AIR"),
        (r"\bstate == CLIMB\b", "state == State.CLIMB"),
        (r"\bstate == PUNCH\b", "state == State.PUNCH"),
        (r"\bstate != PUNCH\b", "state != State.PUNCH"),
        (r"\bstate == DODGE\b", "state == State.DODGE"),
        (r"\bstate = GROUND\b", "state = State.GROUND"),
        (r"\bstate = AIR\b", "state = State.AIR"),
        (r"\bstate = CLIMB\b", "state = State.CLIMB"),
        (r"\bstate = PUNCH\b", "state = State.PUNCH"),
        (r"\bstate = DODGE\b", "state = State.DODGE"),
        (r"\bstate not in \[GROUND, PUNCH\]", "state not in [State.GROUND, State.PUNCH]"),
        (r"match state:\n\t\tCLIMB:", "match state:\n\t\tState.CLIMB:"),
        (r"match state:\n\t\tPUNCH:", "match state:\n\t\tState.PUNCH:"),
        (r"match state:\n\t\tDODGE:", "match state:\n\t\tState.DODGE:"),
        (r"target\.state == 6  # STAGGER", "target.state == Enemy.State.STAGGER"),
        (r"if e\.state == 7:  # DOWN: no hitting bodies on the floor",
         "if e.state == Enemy.State.DOWN:  # no hitting bodies on the floor"),
        (r"Fx\.hit_landed\.emit\(", "Fx.emit_hit("),
    ],
    header_pairs=[("extends CharacterBody3D\n", "class_name Player\nextends CharacterBody3D\n")],
)

# --- enemy.gd ---
sub_file(
    "scripts/enemy.gd",
    pairs=[
        (r"\benum \{ IDLE, WALK, TELEGRAPH, STRIKE, RECOVER, FLINCH, STAGGER, DOWN \}",
         "enum State { IDLE, WALK, TELEGRAPH, STRIKE, RECOVER, FLINCH, STAGGER, DOWN }"),
        (r"\bvar state := IDLE\b", "var state: State = State.IDLE"),
        (r"\bstate == IDLE\b", "state == State.IDLE"),
        (r"\bstate == WALK\b", "state == State.WALK"),
        (r"\bstate == RECOVER\b", "state == State.RECOVER"),
        (r"\bstate == TELEGRAPH\b", "state == State.TELEGRAPH"),
        (r"\bstate == STRIKE\b", "state == State.STRIKE"),
        (r"\bstate == DOWN\b", "state == State.DOWN"),
        (r"\bstate == TELEGRAPH\b", "state == State.TELEGRAPH"),
        (r"\bstate != TELEGRAPH\b", "state != State.TELEGRAPH"),
        (r"\bstate = IDLE\b", "state = State.IDLE"),
        (r"\bstate = WALK\b", "state = State.WALK"),
        (r"\bstate = TELEGRAPH\b", "state = State.TELEGRAPH"),
        (r"\bstate = STRIKE\b", "state = State.STRIKE"),
        (r"\bstate = RECOVER\b", "state = State.RECOVER"),
        (r"\bstate = FLINCH\b", "state = State.FLINCH"),
        (r"\bstate = STAGGER\b", "state = State.STAGGER"),
        (r"\bstate = DOWN\b", "state = State.DOWN"),
        (r"match state:\n\t\tIDLE, RECOVER:", "match state:\n\t\tState.IDLE, State.RECOVER:"),
        (r"match state:\n\t\tWALK:", "match state:\n\t\tState.WALK:"),
        (r"match state:\n\t\tTELEGRAPH:", "match state:\n\t\tState.TELEGRAPH:"),
        (r"match state:\n\t\tSTRIKE:", "match state:\n\t\tState.STRIKE:"),
        (r"match state:\n\t\tFLINCH:", "match state:\n\t\tState.FLINCH:"),
        (r"match state:\n\t\tSTAGGER:", "match state:\n\t\tState.STAGGER:"),
        (r"match state:\n\t\tDOWN:", "match state:\n\t\tState.DOWN:"),
        (r"if state == DOWN and _state_t > RESPAWN_TIME",
         "if state == State.DOWN and _state_t > RESPAWN_TIME"),
        (r"if state != WALK:", "if state != State.WALK:"),
        (r"elif state == RECOVER and _state_t > 0\.5:",
         "elif state == State.RECOVER and _state_t > 0.5:"),
        (r"if state == WALK:", "if state == State.WALK:"),
        (r"Fx\.hit_landed\.emit\(", "Fx.emit_hit("),
    ],
    header_pairs=[("extends CharacterBody3D\n", "class_name Enemy\nextends CharacterBody3D\n")],
)

# --- tests: named enum refs instead of int literals ---
sub_file(
    "tests/smoke.gd",
    pairs=[
        (r"if _player\.state == 2:  # CLIMB", "if _player.state == Player.State.CLIMB:"),
        (r"and _player\.state == 0:", "and _player.state == Player.State.GROUND:"),
    ],
)

sub_file(
    "tests/smoke_combat.gd",
    pairs=[
        (r"# enemy\.gd states\nconst E_IDLE := 0\nconst E_TELEGRAPH := 2\nconst E_STAGGER := 6\nconst E_DOWN := 7\n# player\.gd states\nconst P_DODGE := 4\n",
         "# states live in the named enums (scripts/enemy.gd, scripts/player.gd)\n"),
        (r"\bE_IDLE\b", "Enemy.State.IDLE"),
        (r"\bE_TELEGRAPH\b", "Enemy.State.TELEGRAPH"),
        (r"\bE_STAGGER\b", "Enemy.State.STAGGER"),
        (r"\bE_DOWN\b", "Enemy.State.DOWN"),
        (r"const P_DODGE := 4", "const P_DODGE := Player.State.DODGE"),
        (r"_player\.state = 0  # GROUND", "_player.state = Player.State.GROUND"),
    ],
)
print("done")
