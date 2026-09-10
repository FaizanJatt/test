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
| **Hold left/right mouse + drag** | Look around (the cursor is only hidden while you drag — the window never traps it) |
| Mouse wheel | Zoom |
| `Shift` | Sprint |
| `C` / `Ctrl` | Crouch (toggle-hold) |
| `Space` | Jump |
| `Q` | Toggle over-the-shoulder camera |
| `I` / `Tab` | Open / close the wardrobe |
| `Esc` | Close the wardrobe |

On touch devices a left thumbstick, right-side look pad and Jump / Run / Crouch buttons
appear automatically. Force them on desktop with `godot --path . -- --touch`.

---

## What's in the scene

- **World** (`scripts/world/world_builder.gd`) — a textured grass ground (PolyHaven CC0),
  ~40k wind-animated grass tufts (Kenney tuft mesh in a MultiMesh + `grass.gdshader`), and
  scattered **Kenney Nature Kit** trees / rocks / bushes / flowers / logs. Trees get trunk
  collision; a ring wall bounds the play area. Kenney's GLTF pack ships broken placeholder
  material colours, so `scripts/world/prop_kit.gd` remaps them to a natural palette. Sky,
  sun + cascaded shadows, SSAO, fog and tonemapping are in `scripts/game/main.gd`.
- **Player** (`scripts/player/player.gd`) — `CharacterBody3D`, PUBG-style camera-relative
  movement, sprint, crouch (with head-room check), jump, gravity. Owns a `SpringArm3D`
  camera rig (`camera_rig.gd`) and a procedural locomotion driver (`locomotion.gd`).
  The glb ships no animation clips **and** its "deform bones only" export flattened
  ~375 bones onto the armature root, so `locomotion.gd` rebuilds a virtual FK
  hierarchy in code, drives every segment of each bendy limb by a gait phase
  (idle / walk / run / crouch / crouch-walk, blended by speed + crouch), grounds
  the lower foot, and rigidly re-attaches every detached bone (hands, toes, hair,
  breasts, belt…) to its nearest driver each frame.
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

## Third-party assets (all CC0)

- **Kenney Nature Kit** — trees, rocks, plants, flowers, grass tuft (`assets/props/`).
  https://kenney.nl/assets/nature-kit
- **Poly Haven — `aerial_grass_rock`** — ground texture (`assets/textures/ground/`).
  https://polyhaven.com/a/aerial_grass_rock
- **Freja / CloudRig** — the character, from Blender Studio's CloudRig demo file.

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
