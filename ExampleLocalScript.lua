-- ExampleLocalScript.lua (updated)
-- Top-of-file auto-loader lines (using loadstring + HttpGet, typical for executors)
local options = loadstring(game:HttpGet("https://raw.githubusercontent.com/Robloxhacker3/Options.lib/main/OptionsLib.lua"))()
-- NOTE: The Data/Server script must be placed in ServerScriptService on the server.
-- Loading it on the client will likely error or do nothing useful. Included per request:
local Data = loadstring(game:HttpGet("https://raw.githubusercontent.com/Robloxhacker3/Options.lib/main/OptionsLibDataStoreServer.lua"))()
local themes = loadstring(game:HttpGet("https://raw.githubusercontent.com/Robloxhacker3/Options.lib/main/Theme.lua"))()
local icons = loadstring(game:HttpGet("https://raw.githubusercontent.com/Robloxhacker3/Options.lib/main/Icons.lua"))()

-- Create window via the loaded options.lib
local win = options("Vortexor - Example") -- calls OptionsLib:CreateWindow internally

local main = win:AddTab("Main")
main:AddToggle("Enable feature A", true, function(val)
    print("Feature A:", val)
end)

main:AddButton("Do Action", function()
    print("Action performed")
end)

main:AddSlider("Speed", 0, 100, 30, function(v)
    print("Speed:", math.floor(v))
end)

main:AddDropdown("Choose mode", {"Easy","Normal","Hard"}, function(v)
    print("Mode:", v)
end)

main:AddColorPicker("Accent color", nil, function(c)
    print("Color chosen:", c)
    -- Example of applying chosen accent color to the window theme immediately
    if win and win.Theme then
        win.Theme.Accent = c
    end
end)

-- Show the UI
win:Show()

-- Save theme example (client requests server save via RemoteEvent that the server-side script handles)
local saveBtn = main:AddButton("Save theme to server", function()
    -- This uses the OptionsLib:SaveTheme wrapper which fires the RemoteEvent to the server.
    -- Make sure the server script (OptionsLibDataStoreServer.lua) is running on the server to actually persist.
    win:SaveTheme("player_theme_" .. game.Players.LocalPlayer.UserId)
    print("Requested theme save to server for user:", game.Players.LocalPlayer.UserId)
end)

-- Load theme example (response will come from server via the server RemoteEvent -> LoadResponse)
win:LoadTheme("player_theme_" .. game.Players.LocalPlayer.UserId, function(data)
    if data then
        print("Loaded theme:", data)
        -- Apply loaded theme values (best-effort)
        for k,v in pairs(data) do
            if win.Theme[k] ~= nil then
                win.Theme[k] = v
            end
        end
    else
        print("No saved theme data found on server.")
    end
end)

-- Optional: example of saving arbitrary options data
local exampleSaveBtn = main:AddButton("Save custom data", function()
    local sample = {
        enabledFeatureA = true,
        speed = 42,
        mode = "Normal"
    }
    win:SaveData("custom_settings", sample)
    print("Requested save of custom_settings")
end)

-- Optional: example load for custom settings (server must return via LoadResponse)
local exampleLoadBtn = main:AddButton("Load custom data", function()
    win:LoadData("custom_settings", function(d)
        if d then
            print("Custom settings loaded:", d)
        else
            print("No custom settings saved.")
        end
    end)
end)

-- Reminder: If you host the Options.lib files on that GitHub repo, make sure the raw URLs are reachable.
-- If using a different executor/HTTP method, adapt the initial loadstring lines accordingly.
