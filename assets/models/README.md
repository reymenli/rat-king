# Models

3D models exported from `blender/rat-king-lab.blend`. One GLB per piece, named after the Blender object. Do not edit the GLBs by hand, change the Blender file and export again (see `blender/README.md`).

## Layout

```
characters/
  rats/                       squad rats E, F and G, rigged, clips Idle, Run, Faint
environment/
  lab/
    architecture/
      walls/                  walls, door, gate, window, vent and rat hole walls, breakable wall, posts, pillar
      floors/                 floor tiles and grates
      ceilings/               ceiling panels, skylights, vents, beam
      stairs_catwalks/        stairs, ramp, catwalks, ladder, railing
      glass/                  glass wall, glass floor, window panes
      pipes_ducts/            pipes, air ducts, rat duct
    hazards/                  electric floor, animated spikes
      acid/                   acid pool tiles (full, edge, corner, inner corner, fill), drip pipe
      parkour/                stepping pads over the acid
      laser/                  laser emitter and beam
    interactables/            door, gate, lever, button, pressure plate, cage and lock, lift (all animated)
    rat_tubes/                glass tubes, bend and wall flange for the rats
    lighting/                 ceiling and wall lights
    signage/
      signs/                  warning and direction signs
      wiring/                 cables and indicator lights
  hideout/
    architecture/             walls, floors, ceilings, stairs and catwalks, channel and bridge, tubes, pipe
    furniture/                seating, TVs, nest, table, crates and barrels
    lighting/                 lanterns, string lights, lamps
    signage/                  plank signs
props/                        loose items such as the key
```

## Conventions

- 1 unit is 1 m. The kit is built on a 2 m grid with floor tops at y = 0. Wall pieces are 3 m tall and 0.24 m thick.
- Rat openings are 0.5 x 0.5 m. The glass tubes have a 0.5 m interior.
- Pieces are coloured with vertex colours. `tools/post_import.gd` turns them on and loops the `Idle` and `Run` clips, so every GLB's `.import` file must point at it.
- A node name ending in `-col` gets a collision body from Godot's importer.
- Models face +Z. Rotate characters 180 degrees about Y so they face Godot's forward direction.
- The rest pose of an animated piece is its closed or off state.
