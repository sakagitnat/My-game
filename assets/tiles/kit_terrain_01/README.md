# Terrain painting kit 01

Six independent 1024x1024 transparent PNGs: tile_grass_01, tile_sand_01, tile_soil_dry_01, tile_path_dirt_01, tile_water_fresh_01, tile_water_sea_01. Surface diamond 1024x512 centered vertically (bbox 0,256,1024,768); one cell is 64x32 in game. No props, fog, outlines, raised sides or hard-coded map layout.

The owner will sketch the locations of land, water, sea and paths. These images are not registered in the map editor yet. No existing root tiles, code, or docs/ASSETS.md are changed.

Verified: dimensions, exact diamond bounds, real binary transparency, opaque diamond interior; 5x5 repeats visually reviewed at 64x32 cell spacing with nearest filtering. The repeat preview is a compositing check, not an actual game screenshot. Linear filtering and fractional camera positions need separate in-game review; the asset renderer may need alpha edge handling to avoid thin gaps.

Textures are low-contrast generated artwork, not mathematically periodic. Sea was revised to reduce per-tile lighting gradients. Water is static base art; use world-coordinate animated ripples/highlights across the entire water region. Coastlines and grass/sand/path boundaries need blended terrain or transition assets; this is not a finished transition tileset.

Files remain in this kit folder until Claude supplies the map-editor contract and the graphics integration is reviewed. Editor terrain painting should be separate from furniture/object placement and save editable terrain types, rather than bake a fixed arrangement.
