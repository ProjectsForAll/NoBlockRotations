# NoBlockRotations
*This repository holds the files for the NoBlockRotations Minecraft resource pack.*

## What does this do?
This pack allows you to safely play on servers like DonutSMP without worrying about your base coordinates being leaked.

## How does it work?
It replaces the block rotation textures with non-rotated versions, thus getting rid of viewable block rotations.

## Why do you need to remove block rotations?
Well, block rotations are not tied to the seed, but the actual coordinates of the blocks. This means that if someone can see a screenshot of your base or a stream or video of your base, they can figure out the coordinates of your base just by looking at specific blocks that have rotations.

## Which blocks have rotations?
- Bedrock
- Concrete Powder (1.12+)
- Dirt
- Dirt Path / Grass Path (1.9+)
- Grass Block
- Lily Pad
- Mycelium
- Podzol
- Sand (Including Red Sand)
- Stone

## Supported Minecraft versions
Separate packs are generated for Java Edition **1.8 through 26.3**, each with the correct `pack_format` / `min_format`+`max_format` and era-appropriate block names (e.g. `grass` vs `grass_block`, `grass_path` vs `dirt_path`).

Zip naming:

```text
NoBlockRotations-<mc-version>-<pack-version>.zip
```

Example: `NoBlockRotations-1.21.10-1.0.0.zip`

## How do I use this?
1. Download the zip for your Minecraft version from the [**Releases**](https://github.com/ProjectsForAll/NoBlockRotations/releases/latest).
2. Open Minecraft and go to "Options" -> "Resource Packs".
3. Click on "Open Pack Folder".
4. Move the downloaded `.zip` file into the opened folder (do not extract it).
5. Go back to Minecraft and click the arrow next to "Available Resource Packs" to move the pack to "Selected Resource Packs".
6. Click "Done".

## Building packs locally
Pack version is stored in `VERSION`. Icon is `pack.png`. Per-version sources and zips are generated (not hand-edited).

```powershell
.\Build-Packs.ps1
```

This regenerates:
- `packs/<mc-version>/` — unpacked pack per Minecraft version
- `dist/NoBlockRotations-<mc-version>-<pack-version>.zip` — import-ready zips
- `NoBlockRotations/` — convenience copy of the newest version in the matrix

Useful flags:

```powershell
.\Build-Packs.ps1 -McVersion 1.21.4          # one version only
.\Build-Packs.ps1 -PackVersion 1.0.1         # override VERSION
.\Build-Packs.ps1 -SkipZip                   # regenerate packs/ only
```

Each zip has `pack.mcmeta` at the archive root so Minecraft can import it directly.

## Publishing to Modrinth
`Publish-Modrinth.ps1` builds every pack using the current **git short hash** as the pack version, then uploads one Modrinth version per Minecraft target (`loaders: ["minecraft"]`).

1. Create a PAT at [modrinth.com/settings/account](https://modrinth.com/settings/account)
2. Enable **VERSION_CREATE** (missing scopes also return HTTP 401)
3. Pass the raw `mrp_...` token — not `Bearer ...`

```powershell
$env:MODRINTH_TOKEN = 'mrp_...'
.\Publish-Modrinth.ps1 -Token $env:MODRINTH_TOKEN -ProjectId YOUR_PROJECT_ID_OR_SLUG
```

Useful flags:

```powershell
.\Publish-Modrinth.ps1 -Token $env:MODRINTH_TOKEN -ProjectId YOUR_ID -DryRun
.\Publish-Modrinth.ps1 -Token $env:MODRINTH_TOKEN -ProjectId YOUR_ID -McVersion 1.21.10
.\Publish-Modrinth.ps1 -Token $env:MODRINTH_TOKEN -ProjectId YOUR_ID -SkipBuild
```

Zip / Modrinth naming for commit `abc1234`:

- File: `NoBlockRotations-1.21.10-abc1234.zip`
- Modrinth `version_number`: `abc1234+1.21.10`

## Helpful Tips
* You can test the pack in a singleplayer world by placing a bunch of bedrock. If they have a distinct pattern, it is working. If it looks like some of them are rotated, it is not working.
* Always use the zip that matches your game version — older/newer `pack_format` values will show as incompatible.
