# Asset integration report

- **Discovered:** Gobkit nature GLBs and the Low Poly City Kit. Repository-specific license/README reviewed; exact files pinned in `ASSET_LICENSES.md`.
- **Downloaded:** 4 GLBs (tree, rock, bush, house), plus 2 upstream license files.
- **Imported:** 4 GLBs were imported by the custom Godot 4.7.2 headless editor; target machines must reimport. Three embedded Gobkit textures were extracted to adjacent `_0.png` files by Godot.
- **Integrated in source:** four GLBs are instantiated in `Main`: three as seeded streamed props, one as outpost houses; all four are instantiated by `AssetShowcase.tscn`. Scaling is set in scene code; surface orientation follows the radial normal. No animations are included in these four assets.
- **Tested:** all four imported scenes loaded in the headless scene test and the showcase ran headlessly; Python also checked GLB headers, JSON, mesh and material counts, and absence of external image URIs. This is not visual, rendering, material, Android or animation validation. See `TEST_REPORT.md`.

The house is a contemporary stylized placeholder and not a final fantasy building. Player, NPC and slimes currently use primitive meshes, not downloaded characters. No terrain, audio, weapon, monster or animation packs have been integrated.
