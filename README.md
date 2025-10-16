# NoBlockRotations
*This repository holds the files for the NoBlockRotations Minecraft texture pack.*

## What does this do?
This pack allows you to safely play on servers like DonutSMP without worrying about your base coordinates being leaked.

## How does it work?
It replaces the block rotation textures with non-rotated versions, thus getting rid of viewable block rotations.

## Why do you need to remove block rotations?
Well, block rotations are not tied to the seed, but the actual coordinates of the blocks. This means that if someone can see a screenshot of your base or a stream or video of your base, they can figure out the coordinates of your base just by looking at specific blocks that have rotations.

## Which blocks have rotations?
- Bedrock
- Concrete Powder
- Dirt
- Dirt Path
- Grass Block
- Lily Pad
- Mycelium
- Podzol
- Sand (Including Red Sand)
- Stone

## How do I use this?
1. Download the latest release from the [**Releases**](https://github.com/ProjectsForAll/NoBlockRotations/releases/latest).
2. Open Minecraft and go to "Options" -> "Resource Packs".
3. Click on "Open Pack Folder".
4. Move the downloaded `.zip` file into the opened folder.
5. Go back to Minecraft and click on the arrow next to "Available Resource Packs" to move the pack to "Selected Resource Packs".
6. Click "Done".

## Helpful Tips
* If the pack isn't working for you as a zip (there seems to be a bug with resource packs with just blockstates in the last few Minecraft updates), you will need to extract the "extractable" zip from [**here**](https://github.com/ProjectsForAll/NoBlockRotations/releases/latest) and then put *that* in the resource packs folder.
  * You can test this by going into a singleplayer world and placing down a bunch of bedrock. If they have a distinct pattern, it is working. If it looks like some of them are rotated, it is not working.