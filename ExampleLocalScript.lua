-- ExampleLocalScript.lua
-- Place in StarterPlayerScripts or run from an executor for quick testing.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local OptionsLib = require(game:GetService("StarterPlayer").StarterPlayerScripts:WaitForChild("OptionsLib"))
local win = OptionsLib("Vortexor - Example")

local main = win:AddTab("Main")
main:AddToggle("Enable feature A", true, function(val)
    print("Feature A:", val)
end)
main:AddButton("Do Action", function()
    print("Action performed")
end)
main:AddSlider("Speed", 0, 100, 30, function(v) print("Speed:", math.floor(v)) end)
main:AddDropdown("Choose mode", {"Easy","Normal","Hard"}, function(v) print("Mode:", v) end)
main:AddColorPicker("Accent color", nil, function(c) print("Color chosen:", c) end)

-- Show the UI
win:Show()

-- Saving example
local saveBtn = main:AddButton("Save theme to server", function()
    win:SaveTheme("player_theme_" .. game.Players.LocalPlayer.UserId)
    print("Requested save")
end)

-- Loading example (response will come from server)
win:LoadTheme("player_theme_" .. game.Players.LocalPlayer.UserId, function(data)
    if data then
        print("Loaded theme:", data)
    else
        print("No theme saved yet.")
    end
end)
