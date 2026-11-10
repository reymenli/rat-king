# Blender source

`rat-king-lab.blend` holds the lab and hideout kits, the props, the interactables and the squad rats.
This folder has a `.gdignore`, so Godot never imports the `.blend` itself. Godot only sees the GLB exports in `assets/models/`.

## Layout of the exports

| Folder | Contents |
|---|---|
| `assets/models/lab/kit` | floors, walls, posts, ceilings, ducts |
| `assets/models/lab/props` | pipes, electric floor, laser, glass, breakable wall, key |
| `assets/models/lab/structure` | stairs, ramp, catwalks, ladder, railing |
| `assets/models/lab/signs_wiring` | signs, cables, indicator lights |
| `assets/models/lab/lights` | wall and ceiling lights |
| `assets/models/lab/acid` | acid pool tiles, parkour pads, drip pipe |
| `assets/models/lab/rat_tubes` | glass tubes the rats travel through |
| `assets/models/hideout/*` | hideout kit, furniture and lights |
| `assets/models/interactables` | gate, door, lever, button, plate, cage, spikes, lift, each with animations |
| `assets/models/rats` | rigged squad rats E, F and G |

One GLB per piece, named after the Blender object.

## Conventions

- 1 Blender unit is 1 m, the kit is built on a 2 m grid, and floor tiles have their top at z = 0.
- Rat openings are 0.5 x 0.5 m. Glass tubes have a 0.5 m interior, and the bend radius is 1 m.
- Pieces are painted with vertex colours. `tools/post_import.gd` turns vertex colours on for every material and marks the `Idle` and `Run` clips as looping. Every GLB's `.import` file points at it.
- A piece whose node name ends in `-col` gets a collision body from Godot's importer. The suffix is added only during export.
- Models face +Z in Godot, because Blender's front (-Y) becomes +Z. Rotate characters 180 degrees about Y to face Godot's forward.
- Animations are NLA tracks, exported by track name. The rest pose is the first frame of the first track, so doors are closed and levers are off.

## Animation names

| Piece | Clips |
|---|---|
| Rats | `Idle` (loops), `Run` (loops), `Faint` |
| Door | `Open`, `Close` |
| Gate | `Open`, `Close` (rolls up into the header) |
| Lever | `On`, `Off` |
| Button | `Press`, `Release` |
| Pressure plate | `Press`, `Release` |
| Cage | `Open` (door), `Unlock` (lock drops) |
| Spikes | `Retract`, `Extend` |
| Lift | `Up`, `Down` |

## Exporting again

Use File > Export > glTF 2.0 with these settings: Selected Objects, Vertex Color from Material, Animation mode NLA Tracks (only for animated pieces), Y Up. Set the scene frame to 0 first so the rest pose is exported, and move the piece to the origin.
