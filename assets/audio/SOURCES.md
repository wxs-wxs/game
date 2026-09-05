# Audio Sources

## Runtime music

The runtime music comes from the Ninja Adventure Asset Pack:

- Source: https://pixel-boy.itch.io/ninja-adventure-asset-pack
- Repository copy: https://github.com/pixel-boy/NinjaAdventure/tree/main/audio/music
- License: Creative Commons Zero (CC0). The author permits commercial use;
  attribution is not required but is appreciated.
- `assets/audio/music/exploration_day.ogg` - source `theme_plain.ogg`.
- `assets/audio/music/interior.ogg` - source `theme_lost_village.ogg`.
- `assets/audio/music/exploration_rain.ogg` - source `theme_swamp.ogg`.
- `assets/audio/music/exploration_threat.ogg` - source `theme_dream.ogg`.

## Runtime ambience

- `assets/audio/ambience/camp_night_loop.wav` - selected procedural camp-night
  ambience generated in this project by
  `tools/generate_audio_preview.js`. This is the user-selected environment
  candidate and is not an external download.

## Runtime sound effects

The runtime one-shot sounds come from Kenney RPG Audio:

- Source: https://kenney.nl/assets/rpg-audio
- License: Creative Commons Zero (CC0), confirmed by the pack's included
  `License.txt`. Commercial use is permitted and credit is optional.
- `footstep.ogg` - source `footstep00.ogg`.
- `metal_click.ogg` - source `metalClick.ogg`.
- `pickup.ogg` - source `handleCoins.ogg`.
- `door_open.ogg` - source `doorOpen_1.ogg`.
- `chop.ogg` - source `chop.ogg`.
- `knife_slice.ogg` - source `knifeSlice.ogg`.

The old placeholder WAV files remain in the project as legacy/development
resources. The runtime catalog now points selected cues to the assets above and
uses a silent stream only when a future resource is missing.
