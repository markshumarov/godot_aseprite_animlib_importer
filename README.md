# Godot Aseprite to AnimationLibrary Importer

A scalable, resource-driven Aseprite importer for Godot 4. 

Most existing Aseprite integration tools rely on a Scene-Driven approach (generating `SpriteFrames` or hardcoding keys directly into a local `AnimationPlayer` node). This is an anti-pattern for scalable, data-driven games (like Tactical RPGs with dozens of units). It bloats scene sizes, causes merge conflicts, and tightly couples visual assets to scene logic.

This custom `EditorImportPlugin` implements a strictly **Resource-Driven pipeline**. It imports `.ase` and `.aseprite` files directly into a standalone `.res` `AnimationLibrary`, parsing Aseprite's Cel User Data to automatically bake `Call Method` tracks.

## Features

* **Native Resource Generation:** Compiles sprite sheets automatically in the background using the Aseprite CLI.
* **Lossless Compression:** The generated sprite sheet is immediately embedded as a `PortableCompressedTexture2D` to keep memory overhead minimal.
* **Data-Driven Triggers (Cel User Data):** Tag a specific frame with a string (e.g., `impact`) inside Aseprite using Cel Properties. The importer automatically bakes a `Call Method Track` into the `AnimationLibrary` and inserts a key calling `trigger_animation_phase("impact")` at the exact correct millisecond. Total synchronization with zero manual keyframing inside the Godot editor.
* **Customizable Import Rules:** All logic is exposed in the Godot Import dock.
  * **Auto-Looping:** Define a CSV list of animation names (e.g., `idle, walk, run`). The importer sets their `loop_mode` to `LOOP_LINEAR`.
  * **Speed Modifiers:** Tweak playback speeds globally without touching the source file (e.g., `idle:1.5`).
  * **Fallback Triggers:** Define essential method calls (like `charge`). If the artist forgot to tag a frame in Aseprite, the importer automatically injects the trigger at frame `0.0`.

## Installation

1. Download the repository or the latest release.
2. Copy the `addons/unit_importer` folder into the `addons/` directory of your Godot project.
3. Open your Godot project and go to **Project -> Project Settings -> Plugins**.
4. Enable the **Aseprite to AnimationLibrary** plugin.

## Configuration

Before importing files, configure your global import defaults:
1. Go to **Project -> Project Settings -> Import Defaults**.
2. Select **Aseprite to AnimationLibrary** from the Importer dropdown.
3. Set the absolute path to your Aseprite executable in the **Aseprite Executable** field (e.g., `C:/Program Files (x86)/Steam/steamapps/common/Aseprite/aseprite.exe`). Use forward slashes `/`.
4. Adjust other rules (`loop_animations`, `fallback_triggers`, `speed_modifiers`) to fit your project's naming conventions.

## Usage

Simply drop an `.ase` or `.aseprite` file into the Godot FileSystem. It will be recognized and imported as an `AnimationLibrary`. 

Your game code can then grab the `AnimationLibrary` from your database and apply it to its generic `AnimationPlayer` at runtime.

## Bonus Utility: Aseprite Auto-Tagging Script

If you are migrating existing PNG sprite sheets to this new `.ase` pipeline, manually splitting and tagging them in Aseprite can be tedious. The addon folder includes a helper Lua script (`aseprite_auto_tags.lua`) to automate this.

**What it does:**
It takes a flat PNG sprite sheet, splits it into frames based on the number of columns you specify, trims empty (transparent) frames at the end of each row, creates colored tags for every row, and automatically names the standard tags (`idle` for the first row, `death` for the last, `hurt` for the second to last).

**How to install and use:**

1. Open Aseprite.
2. Go to **File -> Scripts -> Open Scripts Folder**.
3. Copy the `aseprite_auto_tags.lua` file from this addon into that folder.
4. In Aseprite, go to **File -> Scripts -> Rescan Scripts**.
5. Open your flat PNG sprite sheet in Aseprite.
6. Run the script from **File -> Scripts -> aseprite_auto_tags**.
7. Enter the number of columns in your sprite sheet and click "Split and Clean".
8. Save the file as `.ase` or `.aseprite` and drop it into your Godot project.
You also can use Aseprite hotkeys to speed-up pipeline even further.  
## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
