#!/usr/bin/env python3
"""Series 2 Phase 1: download Kenney CC0 audio from the GitHub mirror
series-ai/jam-ready-assets (unpacked copies of kenney.nl packs, all CC0).
Saved to quarantine, then curated into bare-hands/assets/audio/."""
import pathlib, urllib.request, sys

RAW = "https://media.githubusercontent.com/media/series-ai/jam-ready-assets/main/kenney-%s/audio/Audio/%s"
OUT = pathlib.Path("/home/z/my-project/downloads_check/audio")
OUT.mkdir(parents=True, exist_ok=True)

# (pack, filename, game name)
PICKS = [
    # combat impacts
    ("impact-sounds", "impactPunch_medium_000.ogg", "punch_med_0.ogg"),
    ("impact-sounds", "impactPunch_medium_002.ogg", "punch_med_1.ogg"),
    ("impact-sounds", "impactPunch_medium_003.ogg", "punch_med_2.ogg"),
    ("impact-sounds", "impactPunch_heavy_000.ogg", "punch_heavy_0.ogg"),
    ("impact-sounds", "impactPunch_heavy_001.ogg", "punch_heavy_1.ogg"),
    ("impact-sounds", "impactPunch_heavy_003.ogg", "punch_heavy_2.ogg"),
    ("impact-sounds", "impactSoft_medium_001.ogg", "body_med_0.ogg"),
    ("impact-sounds", "impactSoft_heavy_000.ogg", "body_heavy_0.ogg"),
    ("impact-sounds", "impactSoft_heavy_002.ogg", "body_heavy_1.ogg"),
    ("impact-sounds", "impactPlate_heavy_001.ogg", "metal_ring_0.ogg"),
    ("impact-sounds", "impactPlate_medium_000.ogg", "metal_ring_1.ogg"),
    ("impact-sounds", "impactWood_heavy_000.ogg", "wood_heavy_0.ogg"),
    ("impact-sounds", "impactWood_medium_002.ogg", "wood_med_0.ogg"),
    ("impact-sounds", "impactGlass_heavy_000.ogg", "glass_heavy_0.ogg"),
    ("impact-sounds", "impactGlass_medium_001.ogg", "glass_med_0.ogg"),
    ("impact-sounds", "impactBell_heavy_002.ogg", "bell_heavy_0.ogg"),
    ("sci-fi-sounds", "lowFrequency_explosion_000.ogg", "sub_hit_0.ogg"),
    ("sci-fi-sounds", "lowFrequency_explosion_001.ogg", "sub_hit_1.ogg"),
    ("sci-fi-sounds", "laserSmall_001.ogg", "gun_test_0.ogg"),
    ("sci-fi-sounds", "laserSmall_003.ogg", "gun_test_1.ogg"),
    # footsteps by surface
    ("impact-sounds", "footstep_concrete_000.ogg", "step_asphalt_0.ogg"),
    ("impact-sounds", "footstep_concrete_001.ogg", "step_asphalt_1.ogg"),
    ("impact-sounds", "footstep_concrete_002.ogg", "step_asphalt_2.ogg"),
    ("impact-sounds", "footstep_concrete_003.ogg", "step_asphalt_3.ogg"),
    ("impact-sounds", "footstep_wood_000.ogg", "step_wood_0.ogg"),
    ("impact-sounds", "footstep_wood_001.ogg", "step_wood_1.ogg"),
    ("impact-sounds", "footstep_wood_002.ogg", "step_wood_2.ogg"),
    ("impact-sounds", "footstep_wood_003.ogg", "step_wood_3.ogg"),
    ("impact-sounds", "footstep_carpet_000.ogg", "step_carpet_0.ogg"),
    ("impact-sounds", "footstep_carpet_001.ogg", "step_carpet_1.ogg"),
    ("impact-sounds", "footstep_carpet_002.ogg", "step_carpet_2.ogg"),
    # cloth + doors + coins (rpg audio)
    ("rpg-audio", "cloth1.ogg", "cloth_0.ogg"),
    ("rpg-audio", "cloth2.ogg", "cloth_1.ogg"),
    ("rpg-audio", "cloth3.ogg", "cloth_2.ogg"),
    ("rpg-audio", "doorOpen_1.ogg", "door_open_0.ogg"),
    ("rpg-audio", "doorClose_1.ogg", "door_close_0.ogg"),
    ("rpg-audio", "creak1.ogg", "creak_0.ogg"),
    ("rpg-audio", "handleCoins.ogg", "coins_0.ogg"),
    ("rpg-audio", "handleCoins2.ogg", "coins_1.ogg"),
    ("rpg-audio", "metalClick.ogg", "metal_click_0.ogg"),
    ("rpg-audio", "metalLatch.ogg", "latch_0.ogg"),
    ("rpg-audio", "knifeSlice.ogg", "knife_0.ogg"),
    ("rpg-audio", "knifeSlice2.ogg", "knife_1.ogg"),
    ("rpg-audio", "dropLeather.ogg", "drop_0.ogg"),
    # ui
    ("interface-sounds", "click_002.ogg", "ui_click_0.ogg"),
    ("interface-sounds", "confirmation_002.ogg", "ui_confirm_0.ogg"),
    ("interface-sounds", "error_001.ogg", "ui_error_0.ogg"),
    ("interface-sounds", "bong_001.ogg", "ui_bong_0.ogg"),
    ("interface-sounds", "glass_002.ogg", "ui_glass_0.ogg"),
    ("interface-sounds", "drop_002.ogg", "ui_drop_0.ogg"),
]


def main() -> int:
    ok = 0
    for pack, src, dst in PICKS:
        url = RAW % (pack, src)
        dest = OUT / dst
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "curl/8"})
            with urllib.request.urlopen(req, timeout=60) as r, open(dest, "wb") as f:
                f.write(r.read())
            if dest.stat().st_size > 500:
                ok += 1
            else:
                print("TOO SMALL", dst)
        except Exception as e:
            print("FAIL", dst, e)
    print(f"downloaded {ok}/{len(PICKS)}")
    return 0 if ok == len(PICKS) else 1


if __name__ == "__main__":
    sys.exit(main())
