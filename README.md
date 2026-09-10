# Freja — Third-Person Demo with Outfit Customization

A small Godot 4.7 demo: control **Freja** (the CloudRig demo character) in third person
across a grassy field, and open a wardrobe screen to swap outfits and clothing pieces at
runtime.

Built for **desktop** (keyboard + mouse) and **mobile-exportable** (touch controls,
`mobile` renderer, Android preset included).

---

## Run it

Open the project in **Godot 4.7** and press Play (`scenes/main.tscn` is the main scene).

From the CLI:

```bash
godot --path .
```

### Controls

| Desktop | Action |
|---|---|
| `W A S D` / arrows | Move (camera-relative) |
| Mouse | Look |
| `Shift` | Sprint |
| `C` / `Ctrl` | Crouch (toggle-hold) |
| `Space` | Jump |
| `Q` | Toggle over-the-shoulder camera |
| Mouse wheel | Zoom |
| `I` / `Tab` | Open / close the wardrobe |
| `Esc` | Close the wardrobe |

On touch devices a left thumbstick, right-side look pad and Jump / Run / Crouch buttons
appear automatically. Force them on desktop with `godot --path . -- --touch`.

---

## What's in the scene

- **World** (`scripts/world/world_builder.gd`) — procedural ground, ~55k wind-animated
  grass blades (`grass.gdshader`, MultiMesh), scattered trees + rocks with collision, a
  soft play boundary. Sky, sun + cascaded shadows, SSAO, fog and tonemapping are set up
  in `scripts/game/main.gd`.
- **Player** (`scripts/player/player.gd`) — `CharacterBody3D`, PUBG-style camera-relative
  movement, sprint, crouch (with head-room check), jump, gravity. Owns a `SpringArm3D`
  camera rig (`camera_rig.gd`) and a procedural locomotion driver (`locomotion.gd`) that
  poses the skeleton's leg / arm / spine chains by a walk phase (the glb ships no
  animation clips).
- **Freja** (`scripts/character/freja.gd`) — loads `assets/characters/freja/freja.glb`
  (all 5 outfits + shape keys, 423 deform bones), indexes every garment mesh, rebuilds
  materials (`material_factory.gd`) from `assets/textures/`, and applies a `FrejaConfig`.
- **Wardrobe UI** (`scripts/ui/customization_screen.gd`) — opened from the top-right
  inventory button (`hud.gd`). Pick one of 5 outfits, toggle individual pieces
  (gloves, cape, boots, helmet…), change hair / eye colour, skin tone (Combat outfit),
  and body shape sliders. Changes apply live to the character, framed by an orbiting
  preview camera.

### The 5 outfits

`Combat (OW2)`, `Heart of Courage`, `Scarlett`, `Streetwear` (default), `Archangel` —
defined in `scripts/character/wardrobe.gd` (mesh lists + default piece states), distilled
from the CloudRig rig data in `assets/cloudrig_freja_customization_schema.json`.

---

## Asset pipeline

`assets/characters/freja/freja.glb` was re-exported from `source/Freja_1.3.0.blend` with
all outfit collections, shape keys (morph targets) and only the 423 deform bones; the
CloudRig procedural shaders and the "mask stack" GeoNodes are dropped, so Godot rebuilds
approximate materials from the loose maps in `assets/textures/` keyed by material name.

Reference data (not loaded at runtime, kept for provenance):
`assets/cloudrig_freja_customization_schema.json`, `_cheatsheet.json`, `_truth_table.json`.

---

## Export

`export_presets.cfg` has **macOS** and **Android** (arm64) presets. Install the matching
export templates in Godot, then:

```bash
godot --headless --path . --export-release "macOS"  build/macos/FrejaDemo.zip
godot --headless --path . --export-release "Android" build/android/FrejaDemo.apk
```

---

## Layout

```
scenes/main.tscn            # 1-node scene; everything is built in code
scripts/game/               # main orchestrator, input map, screenshot harness
scripts/player/             # controller, camera rig, procedural locomotion
scripts/character/          # glb loader, wardrobe data, material factory, FrejaConfig
scripts/ui/                 # HUD, wardrobe screen, virtual joystick
scripts/world/              # world builder + grass shader
assets/                     # freja.glb, textures, CloudRig reference JSON
source/                     # Freja_1.3.0.blend (Godot-ignored)
_codex_archive/             # the previous attempt, kept for reference (Godot-ignored)
```

Launch with `--capture` to run a scripted screenshot pass into `.debug/`.
