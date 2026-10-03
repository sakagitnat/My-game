# Salvora Art Workshop

Browser tool for the owner to draw a consistent top-down set and cut their own sprite sheets. Uses a 128 px grid and orthogonal top/front drawing guides; no isometric artwork was generated.

## Open now

1. On GitHub open `assets/td/art_workshop/index.html` on branch `gpt/visuals`.
2. Choose **Download raw file** (the download icon). GitHub’s code preview does not execute the editor.
3. Open the downloaded `index.html` in Chrome, Edge, or Firefox. It works offline.

Alternatively download `salvora_art_workshop.zip`, extract it, and open `Salvora-Art-Workshop.html`.

The standalone HTML embeds all templates, the atlas, and the template ZIP. Image processing happens in the browser; drawings are not uploaded to a server.

## Included

- 37 starter templates: doors, windows, tables, chairs, stools, bench, counters, prep table, sink, stove, oven, refrigerator, shelf, cookware, dishes, utensils, crate, barrel, bin, and farm tools.
- Transparent drawing-guide PNG, completely transparent blank PNG, and editable SVG for every template.
- 1024×2560 guide atlas and blank atlas, with a JSON layout and anchor positions.
- Grid slicing with configurable cell size and offsets, transparent-cell skipping, pointer-drawn crop regions, and the exact 37-item atlas layout.
- PNG and ZIP export, editable names/anchors, optional transparent padding to multiples of 128, alpha reporting, and a visual 5×5 repeat preview.
- Thai drawing instructions and responsive desktop/mobile layout.

**Hide the guide layer before exporting game art.** Guides are drawing aids, not finished game sprites. Tile seamlessness is a visual check, not automatically guaranteed. JPEG backgrounds are retained; this tool does not remove backgrounds automatically.

`salvora_templates.zip` contains the original guide/blank/SVG files and layout. Dimensions and suggested names are starter recommendations, not certified Salvora runtime assets. `docs/ART_TOPDOWN.md` and `docs/templates_td/` were absent from main and gpt/visuals when checked. Existing repo docs/CI still describe the older asset format.

## Validation performed

- All 37 guide and blank PNG pairs have their declared dimensions, divisible by 128, and RGBA mode. Blank PNG alpha is zero everywhere; guides have transparent pixels.
- Browser interaction check: 37 atlas crops; category filtering; imported 384×128 fixture yields two 128×128 opaque crops while skipping one transparent cell; 64×70 manual crop pads to 128×128 with unchanged pixels and transparent padding; anchor values clamp to crop bounds.
- Actual downloaded PNG and ZIP files verified using Pillow/zipfile: CRC checks, dimensions, crop colors, alpha, and export manifest.
- Browser has no page errors; desktop at 1440 px and mobile at 390 px have no horizontal page overflow.
- 5×5 preview rendering checked; this package contains guides, not final seamless tile art.

## Handoff to Claude: GitHub Pages

The existing `.github/workflows/web-salvora.yml` exports the game into `build/web` and uploads only that directory. Uploading this HTML to the source repo alone does not publish a new web page.

Please add this after **Export web build**, before **upload-pages-artifact**, in the existing Pages workflow:

```yaml
      - name: Include drawing workshop
        run: |
          mkdir -p build/web/art-workshop
          cp assets/td/art_workshop/index.html build/web/art-workshop/index.html
```

Because `index.html` is self-contained, one copied file is enough. Keep the game’s root index unchanged. After main is merged and the Pages deployment succeeds, the editor will be at the existing Pages origin plus `/art-workshop/`. Verify the actual deployed URL before announcing it.

The package includes `.gdignore` to keep the Godot importer from treating drawing-guide tooling as runtime art. No gameplay scripts, footprints, schemas, CI workflows, or Pages settings were changed by this upload.
