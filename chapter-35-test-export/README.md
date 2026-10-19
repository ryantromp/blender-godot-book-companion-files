# Chapter 35: Test, Fix and Export

Part 3: Godot, Build the Game

## How to use this folder

Copy the contents of the `LittleMeadow` folder in here into your own `LittleMeadow` folder, keeping the subfolders. Files with the same name are replaced. You can also use it only to compare your own work with the book's.

## Godot project files

### New in this chapter

- `export_presets.cfg`
- `packaging/COPYRIGHT-GODOT.txt`
- `packaging/LICENSE-GODOT.txt`
- `packaging/README.txt`
- `packaging/THIRD-PARTY-NOTICES.txt`
- `packaging/icon.icns`
- `packaging/icon.ico`
- `packaging/icon_1024.png`
- `scratch/ex35_debug.gd`
- `scratch/ex35_debug.tscn`
- `tests/README.md`
- `tests/run_tests.gd`
- `tests/test_ch35.gd`
- `tools/make_icons.py`
- `tools/render_icon.gd`
- 5 Godot-generated `.import` and `.uid` files that belong to the files above

### Changed in this chapter

- `project.godot`
- `resources/credits.json`
- `scripts/build/build_grid.gd`
- `scripts/farming/soil_plot.gd`
- `tests/test_ch28.gd`
- `tests/test_ch30.gd`
- `tests/test_ch34.gd`

These files sit under `LittleMeadow/godot`, the project folder of the book.

## After the book

This folder also carries the last fixes made after the chapter was written: a steadier `tests/test_ch28.gd`, the standalone test runner `tests/run_tests.gd` with `tests/README.md`, the Godot licence texts and third-party notices in `packaging/`, and the refreshed `resources/credits.json`. The credits file names the licences of the game's own files (see `LICENSE` and `LICENSE-ASSETS` at the top of this repository).
