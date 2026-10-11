# House kit

Parametric, static-shell house pieces. Drop a piece into a scene, then set its
size and options in the Inspector. It rebuilds straight away in the editor.
Generated meshes aren't saved into your scene, so scene files only hold the settings.

Find the pieces in `house/kit/pieces/` (drag them in), or use **Add Node** and
search for `Kit`. The `house/builder/house_builder.tscn` map has ground, sky and
lighting, plus an example house to copy or pull apart.

## Conventions

- Turn on grid snap at **0.5 m** and rotation snap at **90°**.
- A storey is **3.0 m** floor to floor. Put the ground floor at y = 0 and the
  next floor up at y = 3.
- Walls run along their **+X** from the origin, centred on the grid line. The
  **-Z side is outside** and the +Z side is inside. Doors, windows and the brick
  face follow from that.
- Floors span between wall grid lines; their edges tuck into the walls.
- Roofs sit on top of the walls (y = 3 or 6). Their `span` and `length` are
  measured between wall grid lines.

## Corners and junctions

Where two exterior walls meet, set one wall's end to **CORNER** and the other
wall's end to **BUTT_EXTERIOR**. The corner wall runs on and wraps its brick,
plinth and quoins round the corner. The other wall stops at its inside face.
An interior wall meeting an exterior wall uses BUTT_EXTERIOR. Meeting another
interior wall, it uses BUTT_INTERIOR.

## Pieces

| Piece | Notes |
|---|---|
| KitWall | Exterior (cavity brick, render, cladding or stone), interior or garden wall. Add doors, windows and open doorways under `openings`. |
| KitFloor | Floor finish, structure and ceiling below. Holes are optional, and stairs cut their own. |
| KitRoof | Gable, hip or open ends; lean-to option. Tiles, ridge, hips, bargeboards, fascias, gutters and downpipes. Cross two roofs to make a valley. |
| KitStairs | A straight flight; each side against a wall or open. Cuts the stairwell in the floor above automatically. |
| KitBalustrade | Landings and stairwell edges. Turn off one newel where two runs meet. |
| KitChimney | External stack, or an internal breast with a fireplace and mantelpiece. |
| KitPorch | Lean-to or gabled porch on posts, columns, piers or brackets. |
| KitSteps | External steps, with optional cheek walls and a handrail. |
| KitColumn, KitTrim, KitSlab | Posts and columns; cornices and bands; paths, terraces and decks. |
| KitLight, KitSwitch | A switch toggles every light with the same `circuit` name. |

Doors and windows are breakable voxel leaves on the house's existing hinges. They
open, lock and smash, and they fall out if their hinge side is destroyed.
