# Grow a Game: companion files

The files that go with the book *Grow a Game: Blender and Godot from Scratch*, a hands-on beginner course in Blender 5.2.2 LTS and Godot 4.7.2. The game you build is called Little Meadow.
You build low-poly farm assets in Blender, then a playable farm game in Godot with GDScript.

## What is here

One folder for each chapter that builds or changes a file. A chapter folder holds **only the files that chapter
builds or changes**, and it uses the same folder layout as the `LittleMeadow` folder in the book. Chapters that
produce no file of their own, such as Chapter 1, have no folder.

```
chapter-07-props/
  README.md            what is in this folder
  LittleMeadow/
    blender/lm_props.blend
chapter-27-.../
  LittleMeadow/
    godot/scripts/...
```

## Three ways to use it

1. **Check your own work.** Compare your file with the one in the chapter folder.
2. **Catch up.** Copy the `LittleMeadow` folder from a chapter folder into your own `LittleMeadow` folder. Do this
   chapter by chapter, in order, because later chapters build on earlier ones.
3. **Compare with Git.** Clone the repository and run `git diff --no-index` on your file and the one in the chapter folder. The book's chapter "Your Safety Net" shows how.

## What is not here

- **The game builds.** The Linux and Windows games are what you make in Chapter 35. They are not stored in this repository.
- **Godot's cache.** The `.godot` folder is rebuilt by Godot when you open the project.
- **The author's scratch files.**

## The Blender files

A `.blend` file is stored once, in the chapter where you first make it, in its **finished** state. Later chapters
keep adding to some of these files, so an early chapter's file can contain work from later chapters. The chapter
README lists which later chapters use each file.

## Versions

Blender 5.2.2 LTS, Godot 4.7.2, GDScript. Other versions can behave differently.

## Chapters

| Chapter | Title | Folder | Blender files | Godot files |
|---:|---|---|---:|---:|
| 2 | Controls and First Win | [`chapter-02-install-first-win`](chapter-02-install-first-win) | 1 |  |
| 3 | Interface and Navigation | [`chapter-03-interface`](chapter-03-interface) | 1 |  |
| 4 | Objects, Transforms, Precision | [`chapter-04-transforms`](chapter-04-transforms) | 1 |  |
| 5 | Edit Mode Modelling | [`chapter-05-edit-mode`](chapter-05-edit-mode) | 1 |  |
| 6 | Modifiers | [`chapter-06-modifiers`](chapter-06-modifiers) | 1 |  |
| 7 | Props: Crates, Barrels, Buckets, Signs, Tools | [`chapter-07-props`](chapter-07-props) | 1 |  |
| 8 | Structures: Fences, Gates, Farmhouse, Barn, Shed, Coop, Well | [`chapter-08-structures`](chapter-08-structures) | 1 |  |
| 9 | UVs and Hand-Painted Textures | [`chapter-09-uv-paint`](chapter-09-uv-paint) | 3 |  |
| 10 | Terrain and Landscape | [`chapter-10-terrain`](chapter-10-terrain) | 3 |  |
| 11 | Vegetation, Crops, Scenery | [`chapter-11-vegetation`](chapter-11-vegetation) | 3 |  |
| 12 | Geometry Nodes for the Farm | [`chapter-12-geometry-nodes`](chapter-12-geometry-nodes) | 1 |  |
| 13 | Machinery | [`chapter-13-machinery`](chapter-13-machinery) | 1 |  |
| 14 | The Farmer: A Low-Poly Character Ready for a Skeleton | [`chapter-14-farmer`](chapter-14-farmer) | 3 |  |
| 15 | Animals: Chicken, Dog and Cow Ready for Their Bones | [`chapter-15-animals`](chapter-15-animals) | 1 |  |
| 16 | Rigging: Bones for the Farmer and the Animals | [`chapter-16-rigging`](chapter-16-rigging) | 3 |  |
| 17 | Animation: Keyframes, Actions and 18 Game Clips | [`chapter-17-animation`](chapter-17-animation) | 1 |  |
| 18 | Physics, Particles and VFX | [`chapter-18-vfx`](chapter-18-vfx) | 7 |  |
| 19 | Add-ons: Node Wrangler and Your Own Exporter | [`chapter-19-addons`](chapter-19-addons) | 1 |  |
| 20 | Optimise and Export | [`chapter-20-export`](chapter-20-export) | 72 |  |
| 21 | Godot Editor Tour and Project Setup | [`chapter-21-godot-setup`](chapter-21-godot-setup) |  | 30 |
| 22 | GDScript Fundamentals | [`chapter-22-gdscript`](chapter-22-gdscript) |  | 49 |
| 23 | Importing Blender Assets | [`chapter-23-importing`](chapter-23-importing) |  | 158 |
| 24 | Building the Farm Scene | [`chapter-24-farm-scene`](chapter-24-farm-scene) |  | 48 |
| 25 | The Farmer: Click to Move | [`chapter-25-farmer`](chapter-25-farmer) |  | 13 |
| 26 | Interaction and Machines | [`chapter-26-interaction`](chapter-26-interaction) |  | 25 |
| 27 | The Farming Loop | [`chapter-27-farming`](chapter-27-farming) |  | 36 |
| 28 | Living Animals | [`chapter-28-animals`](chapter-28-animals) |  | 34 |
| 29 | Items, Inventory and the HUD | [`chapter-29-inventory-hud`](chapter-29-inventory-hud) |  | 41 |
| 30 | Time, Light, Weather and Effects | [`chapter-30-time-weather`](chapter-30-time-weather) |  | 37 |
| 31 | Build Mode | [`chapter-31-build-mode`](chapter-31-build-mode) |  | 43 |
| 32 | Shop and Economy | [`chapter-32-shop-economy`](chapter-32-shop-economy) |  | 49 |
| 33 | Saving and Loading | [`chapter-33-save-load`](chapter-33-save-load) |  | 35 |
| 34 | Audio, Menus and Polish | [`chapter-34-audio-menus`](chapter-34-audio-menus) |  | 111 |
| 35 | Test, Fix and Export | [`chapter-35-test-export`](chapter-35-test-export) |  | 27 |

## Licence

[FILL IN BEFORE RELEASE: the licence for the files in this repository. Until it is filled in, nobody has permission to reuse them.]

The Godot licence texts and third-party notices are in the Chapter 35 folder, under `LittleMeadow/godot/packaging/`.
