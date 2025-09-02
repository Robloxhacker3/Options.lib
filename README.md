# options.lib

A lightweight, beautiful Roblox GUI library for creating script GUIs with:
- Tabs, toggles, buttons, sliders, dropdowns, color pickers.
- Lucide-style icon mapping (placeholders to swap with your own Decal IDs).
- Theme system (save/load themes).
- Data persistence via server DataStore (server script included).
- Smooth easing animations and draggable windows.

**Contents**
- `src/OptionsLib.lua` - the main ModuleScript (client-side).
- `src/Icons.lua` - a small map of lucide icon names -> Roblox ImageId placeholders.
- `src/Theme.lua` - theme helper.
- `examples/ExampleLocalScript.lua` - example usage (place in StarterPlayerScripts or run in executor).
- `server/OptionsLibDataStoreServer.lua` - server-side script for saving/loading player data.
- `README.md` - this file.

**Quick start**
1. Put `OptionsLib.lua`, `Icons.lua`, and `Theme.lua` under `StarterPlayer > StarterPlayerScripts` as ModuleScripts (or use your preferred structure).
2. Add the server script `OptionsLibDataStoreServer.lua` to `ServerScriptService`.
3. Place a `RemoteEvent` in `ReplicatedStorage` named `OptionsLib_SaveEvent` for save/load RPCs (the server script will create it if missing).
4. Example usage is in `examples/ExampleLocalScript.lua`.

**Notes**
- The library uses `ReplicatedStorage:WaitForChild("OptionsLib_SaveEvent")` to communicate with the server DataStore for persistence. Adjust to your own backend if you prefer.
- Replace icon placeholders in `Icons.lua` with actual Decal/Image asset IDs for Lucide icons.
- This library is written to be easy to extend. Read comments in `OptionsLib.lua`.
