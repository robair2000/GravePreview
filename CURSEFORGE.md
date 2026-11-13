# CurseForge upload sheet — GravePreview

## Project basics

- **Game:** World of Warcraft
- **Project type:** Addons
- **Name:** GravePreview
- **Summary:** Shows a corpse icon on the world map at the graveyard you are most likely to respawn at. Works with OpenMap.
- **Category:** Map & Minimap
- **Tags:** Map, PvP, Graveyard, Resurrect, OpenMap, Forever, Classic
- **License:** choose your own (MIT is a common choice for addon code)

## Supported game versions

- WoW Forever 1.60.1 (Interface 16001)
- Classic Era 1.15.9 (Interface 11509)
- TBC Anniversary 2.5.6 (Interface 20506)

## Upload file

Use `GravePreview-CurseForge.zip`. Its root contains the `GravePreview/` folder.

Do **not** upload the development zip that contains `tests/` and `preview.svg`.

## Project images

Prepared in the project folder:

- **Project avatar/logo:** `CurseForge-logo.png` — 512 × 512 px
- **Gallery screenshot:** `CurseForge-screenshot.png` — 1280 × 720 px

The screenshot is clearly marked **PREVIEW** because it is a polished mockup,
not a live in-game capture. Replace or supplement it with 2–3 real in-game
screenshots when you can (open map in Hillsbrad, hover the pin, and the
`/gpreview debug` output).

## Suggested description

```markdown
# GravePreview

Shows a **corpse icon on the world map** at the graveyard you are most likely to
respawn at if you die at your current location.

Open the map while questing and you immediately see where your ghost would end
up. Hover the icon for the graveyard name and the straight-line distance.

## Features

- Corpse icon on the world map at the closest eligible graveyard
- Tooltip with graveyard name and approximate distance
- Updates while the map is open
- Faction-aware: Horde in Hillsbrad gets Tarren Mill, Alliance gets Southshore
- **OpenMap support:** draws over OpenMap's stitched map, above the map art
- Falls back to a normal Blizzard map pin when OpenMap is not stitched
- Bundled Forever 1.60.1 spirit healer dataset, plus API fallbacks

## Works in

- Open world. Live prediction needs player coordinates, which WoW hides in
  instances and battlegrounds.
- WoW Forever, Classic Era and TBC Anniversary.

## Limitations

- The result is the closest eligible graveyard, not a 100% guarantee. WoW's
  hidden zone rules can pick another one near zone borders.
- The distance is straight-line, not the actual travel distance.
- If the currently displayed map does not contain the predicted graveyard, no
  icon is shown.

## Commands

`/gpreview` — help  
`/gpreview on | off` — enable or disable  
`/gpreview update` — refresh the pin  
`/gpreview status` — current state  
`/gpreview debug` — print position, map IDs and the chosen graveyard

## Credits

Graveyard positions are derived from WoW Forever game data; thanks to the
HandyNotes_SpiritHealers project for cross-checking the positions.
```

## Changelog for the first file

```text
Initial release.

- Corpse icon on the world map at the closest eligible graveyard.
- Tooltip with graveyard name and distance.
- Faction-aware graveyard selection.
- OpenMap stitched-map overlay with zoom compensation.
- Bundled Forever 1.60.1 spirit healer data.
```

## Before publishing: data credit/licence

`GravePreviewData.lua` was generated from positions cross-checked against the
HandyNotes_SpiritHealers addon, which is marked **All Rights Reserved** on
CurseForge. The coordinates and names are factual game data, but if you want to
be extra safe:

1. Ask the HandyNotes_SpiritHealers author for permission to reuse the
   coordinates, or
2. Regenerate the table directly from the WoW Forever client DB2
   (`WorldSafeLocs`) instead, or
3. Keep the credit in the README/description and publish as-is if you are
   comfortable that the underlying facts are not copyrightable.

## TOC fields to add after the project exists

`X-License: MIT` is already in all three TOCs. After the project exists, add:

```
## X-Website: https://www.curseforge.com/wow/addons/gravepreview
## X-Curse-Project-ID: <project-id>
```

to `GravePreview.toc` (and optionally the flavour-specific TOCs).

The project ID is shown in the CurseForge project dashboard/URL after creation.

## Upload steps

1. Sign in at https://www.curseforge.com.
2. Open the author dashboard and choose **Create Project**.
3. Select **World of Warcraft** → **Addons**.
4. Fill in the name, summary, description, category and licence.
5. After the project is created, open **Files** → **Upload File**.
6. Choose the game versions listed above and release type **Release**.
7. Upload `GravePreview-CurseForge.zip`.
8. Paste the changelog and publish.
9. Add screenshots in **Gallery** and a project avatar in **Settings**.
10. Test the downloaded file in a clean `Interface/AddOns` folder.
```
