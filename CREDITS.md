# Credits

All third-party assets in this project are free for commercial use. Nothing here requires attribution, but the makers deserve it.

## bare-hands/assets/UAL1_Standard.glb

- **What**: rigged mannequin + 43 animation clips (idle/walk/sprint/jump/hits/punches/roll/death)
- **By**: Quaternius (https://quaternius.com)
- **Pack**: Universal Animation Library (https://quaternius.com/packs/universalanimationlibrary.html, also on itch.io)
- **License**: CC0 1.0 Universal — https://creativecommons.org/publicdomain/zero/1.0/
- **Used for**: the enemy mannequin, and the hero's entire animation set (all 43 clips drive the hero pieces)

## bare-hands/assets/hero/ (Superhero_Male_FullBody, Hair_Beard, T_Hero/body/hair/eye textures)

- **What**: Universal Base Characters — textured humanoid body + rigged hairstyles/beard on the same 65-bone UAL rig
- **By**: Quaternius (https://quaternius.com)
- **Pack**: Universal Base Characters (https://quaternius.com/packs/universalbasecharacters.html)
- **License**: CC0 1.0 Universal — https://creativecommons.org/publicdomain/zero/1.0/
- **Downloaded from**: GitHub mirror of the pack's free "Standard" edition (itch.io now requires an account for downloads): https://github.com/Xeiliex/Tactics-Bell-Web- (Assets/universal-base-characters/)
- **Used for**: the hero's body, head, hands and beard; textures downscaled to 1024/512 px for mobile

## bare-hands/assets/hero/ (Male_Ranger_Body/Arms/Legs/Feet_Boots, T_Ranger textures)

- **What**: Modular Character Outfits — Fantasy, the Male Ranger set (torso, sleeves, trousers, boots) on the same UAL rig
- **By**: Quaternius (https://quaternius.com)
- **Pack**: Modular Character Outfits - Fantasy (https://quaternius.com/packs/modularcharacteroutfitsfantasy.html)
- **License**: CC0 1.0 Universal — https://creativecommons.org/publicdomain/zero/1.0/
- **Downloaded from**: GitHub mirror (git-lfs media restored): https://github.com/slopwarefactory/terra (art/characters/quaternius/modular-outfits-fantasy/)
- **Used for**: the hero's clothes; textures downscaled to 1024/512 px for mobile

## bare-hands/assets/audio/ (Kenney sound effects)

- **What**: punches, body impacts, metal/wood/glass, footsteps (concrete, wood, carpet), cloth, doors, coins, knives, UI clicks, lasers (test weapon), low-frequency hits
- **By**: Kenney (https://kenney.nl)
- **Packs**: Impact Sounds, RPG Audio, Sci-Fi Sounds, Interface Sounds
- **License**: CC0 1.0 Universal - https://creativecommons.org/publicdomain/zero/1.0/
- **Downloaded from**: the GitHub mirror series-ai/jam-ready-assets (unpacked copies of the packs, fetched via git-lfs media CDN); files renamed for this project, otherwise unmodified
- **Proof of license**: bare-hands/assets/audio/KENNEY_AUDIO_LICENSE.txt

## bare-hands/assets/audio/ (ambience + music stems)

- **What**: rain on asphalt and metal, distant traffic, neon hum, distant siren, puddle splashes, and the five music stems (bed, tension, combat, heartbeat, resolve)
- **Made by**: this project - generated entirely in code (scripts/synth_audio.py in the repo). No third-party audio, no license restrictions.
- **Note**: the music stems are deliberate placeholders built so each can be swapped for a recorded stem of the same name and length.

## Built in code (no external assets)

The fedora and the swinging coat panels (scripts/hero_rig.gd), all level geometry, UI and the entire codebase.

## Engine

Godot 4.7 (MIT license) — https://godotengine.org

## Combo pass — code-built animation
- **Kick_Code** (the hero's kick): no CC0 clip existed in the Universal
  Animation Library, so the kick is built in code (`scripts/ual_bind.gd`,
  `_kick_clip()` - bone-keyframe animation on the pack's own rig). No
  external asset, nothing to credit.
