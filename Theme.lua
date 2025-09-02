-- Theme.lua
-- Simple theme helper for options.lib

local Theme = {}
Theme.Default = {
    Background = Color3.fromRGB(18, 18, 20),
    Accent = Color3.fromRGB(0, 170, 255),
    Text = Color3.fromRGB(235, 235, 235),
    Secondary = Color3.fromRGB(30, 30, 34),
}

function Theme:Clone(t)
    local out = {}
    for k,v in pairs(t) do out[k] = v end
    return out
end

return Theme
