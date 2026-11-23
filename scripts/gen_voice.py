#!/usr/bin/env python3
"""B28 VOICE: generate the real voice recordings for LEVERAGE.

The game has carried an empty voice hook since Series-2 Phase 7:
scripts/dialogue.gd plays res://assets/voice/<voice_id>_<n>.wav if the
recording exists, and narrator.gd falls back to platform TTS or a
synthesised radio babble. This script records the actual lines with
the z-ai TTS CLI (one voice per speaker) into that exact contract.

Texts are WORD-FOR-WORD the subtitles the game shows (cast.gd /
narrator.gd); voice/speed per speaker from VOICE_MAP. Re-run safe:
skips files that already exist and pass the size check.
"""
import pathlib
import subprocess
import sys
import time

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "voice"

# voice_id -> list of (clip_no, tts_voice, speed, text)
# clip numbers follow the dialogue.gd run order (index + 1).
SPEAKERS = {
    "velvet": [
        (1, "kazi", 1.0, "You're the one burning through my neighbourhood. Bullets aren't sold, they're rented - from your wallet."),
        (2, "kazi", 1.0, "Five dollars leaves you the moment the hammer drops. The ledger keeps the receipts. Browse."),
    ],
    "pilsner": [
        (1, "douji", 1.05, "Every camera on this block is mine. Even the ones that aren't."),
        (2, "douji", 1.05, "Heat's just information with a siren on it. Stay out of sight and even the police forget."),
    ],
    "marrow": [
        (1, "xiaochen", 0.95, "The Knuckle Room runs on one rule: whoever's left standing set the price."),
        (2, "xiaochen", 0.95, "You've got hands. Good. Irons come later - and they never come cheap."),
    ],
    "duchess": [
        (1, "tongtong", 0.85, "No one is born with a gun, little shadow. Some of us are born holding the ledger."),
        (2, "tongtong", 0.85, "Spend carefully. Every dollar you fire is a dollar I own a little less of."),
    ],
    "mama_sun": [
        (1, "tongtong", 1.05, "You live above my noodles and you still look hungry. Sit. First bowl is on the house - the second is on your ledger."),
        (2, "tongtong", 1.05, "I have fed every faction in this city at two in the morning. Nobody shoots at a woman who fed them. Remember that."),
    ],
    "ash": [
        (1, "chuichui", 1.15, "I know every alley, every camera and every debt in this district. Costs you a soda."),
        (2, "chuichui", 1.15, "The Vulture guy by the wall? He's been writing down who goes in the bar. I saw him. Twice."),
    ],
    "tam": [
        (1, "chuichui", 1.0, "Table four's got dockworkers in tonight, so keep your fists off the furniture. Mama just varnished it."),
        (2, "chuichui", 1.0, "Tips go in the jar, not your pocket. The jar remembers. Everything in this city remembers."),
    ],
    "raz": [
        (1, "douji", 0.95, "The bar opens when I say and closes when the Duchess calls. You want a tab, you want a job, or you want trouble?"),
        (2, "douji", 0.95, "Word of advice, neighbour: the ones who drink slow are watching somebody. Look around next time."),
    ],
    "drunk": [
        (1, "luodo", 0.85, "I'm not drunk, I'm... informants drink free, that's the arrangement, don't tell Kessler..."),
        (2, "luodo", 0.85, "You're the brother's kid, aren't you. Same shoulders. He still owes me eleven dollars and a goodbye."),
    ],
    "okafor": [
        (1, "xiaochen", 0.9, "Talent is a rumour. Habits are real. Grab the dummy, review your MOVES, and I'll grade what you can keep."),
        (2, "xiaochen", 0.9, "The gym takes fighters who listen. The tournament takes fighters who win. The city takes whatever's left."),
    ],
    "kessler": [
        (1, "kazi", 0.88, "Curfew's a story we tell tourists. But heat is real - mine. Every mess you make lands in MY ledger."),
        (2, "kazi", 0.88, "I don't care who runs this block. I care how loud it gets. Stay quiet and we stay friendly."),
    ],
    "mechanic": [
        (1, "jam", 1.0, "Every car on this street, I know its engine note like a voice. Useful, when somebody wants a quiet ride."),
        (2, "jam", 1.0, "You keep showing up when I need hands. That's how friendships start - ask your ledger, not me."),
    ],
    "club_owner": [
        (1, "luodo", 1.0, "The queue outside my door is the city's true parliament. Everyone votes with their patience."),
        (2, "luodo", 1.0, "I book the fights, I book the DJs, I book the silence afterward. Which one are you shopping for?"),
    ],
    "yuen": [
        (1, "douji", 0.88, "The docks sleep with one eye open. Crates move at 3 AM and nobody signs anything."),
        (2, "douji", 0.88, "When you're ready to talk about the warehouse, you won't find me. I'll find you. That's how the docks say hello."),
    ],
    # the narrator's spoken keys (scripts/narrator.gd LINES)
    "narrator": [
        (1, "xiaochen", 0.85, "You sleeping good up there? The Family ain't. Five hundred by Friday, or I bring friends."),
        (2, "luodo", 1.05, "Your knuckles still remember the work? Private floor, Saturday. Cash questions, no names."),
        (3, "jam", 0.95, "Word of advice: the Corporation is buying the block your room sits on. Doors close fast around here. Keep moving."),
    ],
}

# narrator clip number -> LINES key the game asks for
NARRATOR_KEYS = {1: "call_demand", 2: "call_invite", 3: "voicemail"}


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    made = skipped = failed = 0
    for voice_id, clips in SPEAKERS.items():
        for clip_no, tts_voice, speed, text in clips:
            name = f"{voice_id}_{clip_no:02d}.wav"
            path = OUT / name
            if path.exists() and path.stat().st_size > 20000:
                skipped += 1
                continue
            cmd = ["z-ai", "tts", "-i", text, "-o", str(path),
                   "--voice", tts_voice, "--speed", str(speed),
                   "--format", "wav"]
            ok = False
            for attempt in range(4):
                r = subprocess.run(cmd, capture_output=True, text=True,
                                   timeout=180)
                ok = path.exists() and path.stat().st_size > 20000
                if ok:
                    break
                # 429 rate limit: back off and try the clip again
                time.sleep(6.0 + attempt * 6.0)
            # a small gap between clips keeps the API friendly
            time.sleep(1.5)
            if ok:
                made += 1
                print(f"VOICE ok: {name} ({tts_voice} @{speed}) "
                      f"{path.stat().st_size} bytes")
            else:
                failed += 1
                print(f"VOICE FAIL: {name}: {r.stdout.strip()[-120:]} "
                      f"{r.stderr.strip()[-120:]}")
    print(f"VOICE RESULT: {made} made, {skipped} kept, {failed} failed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
