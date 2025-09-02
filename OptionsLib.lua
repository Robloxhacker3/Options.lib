-- OptionsLib.lua
-- Main ModuleScript for the options.lib GUI library (client-side).
-- Usage:
-- local OptionsLib = require(path.to.OptionsLib)
-- local win = OptionsLib:CreateWindow("My Script")
-- local tab = win:AddTab("Main")
-- tab:AddToggle("Enable feature", false, function(val) ... end)
-- win:SaveData("myKey", {some = 'data'}) -- persists via a RemoteEvent to server

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

-- Attempt to get or create the RemoteEvent for persistence:
local SAVE_EVENT_NAME = "OptionsLib_SaveEvent"
local saveEvent = ReplicatedStorage:FindFirstChild(SAVE_EVENT_NAME)
-- if not present, we will assume server creates it. Client will error on Save/Load if missing.

local OptionsLib = {}
OptionsLib.__index = OptionsLib

-- Internal helpers
local function make(propTab)
    local inst = Instance.new(propTab.Class or "Frame")
    for k,v in pairs(propTab) do
        if k ~= "Class" then
            pcall(function() inst[k] = v end)
        end
    end
    return inst
end

local function tween(inst, props, time, style, dir)
    TweenService:Create(inst, TweenInfo.new(time or 0.25, Enum.EasingStyle[style or "Quart"], Enum.EasingDirection[dir or "Out"]), props):Play()
end

-- Window constructor
function OptionsLib:CreateWindow(title, options)
    options = options or {}
    local sg = Instance.new("ScreenGui")
    sg.Name = "OptionsLib_UI_" .. title:gsub("%s+","_")
    sg.ResetOnSpawn = false

    local main = make{Class="Frame", Name="MainWindow", AnchorPoint=Vector2.new(0.5,0.5), Size=UDim2.new(0,620,0,420), Position=UDim2.new(0.5,0.5,0.5,0)}
    main.Parent = sg
    main.BackgroundColor3 = options.Background or Color3.fromRGB(18,18,20)
    main.Active = true
    main.Draggable = true

    -- Header
    local header = make{Class="Frame", Name="Header", Size=UDim2.new(1,0,0,48), Position=UDim2.new(0,0,0,0)}
    header.BackgroundColor3 = options.Secondary or Color3.fromRGB(30,30,34)
    header.Parent = main

    local titleLbl = make{Class="TextLabel", Text=title, Font=Enum.Font.GothamBold, TextSize=20, Size=UDim2.new(1,-96,1,0), Position=UDim2.new(0,12,0,0), BackgroundTransparency=1}
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.TextColor3 = options.Text or Color3.fromRGB(235,235,235)
    titleLbl.Parent = header

    local btnClose = make{Class="TextButton", Name="Close", Text="X", Size=UDim2.new(0,36,0,28), Position=UDim2.new(1,-44,0,10), BackgroundTransparency=0, Parent=header}
    btnClose.BackgroundColor3 = Color3.fromRGB(40,40,44)
    btnClose.TextColor3 = Color3.new(1,1,1)

    btnClose.MouseButton1Click:Connect(function()
        sg:Destroy()
    end)

    local leftBar = make{Class="Frame", Name="LeftBar", Size=UDim2.new(0,160,1,-48), Position=UDim2.new(0,0,0,48)}
    leftBar.BackgroundColor3 = options.Secondary or Color3.fromRGB(28,28,32)
    leftBar.Parent = main

    local content = make{Class="Frame", Name="Content", Size=UDim2.new(1,-160,1,-48), Position=UDim2.new(0,160,0,48)}
    content.BackgroundTransparency = 1
    content.Parent = main

    -- Tab container
    local tabButtons = Instance.new("UIListLayout", leftBar)
    tabButtons.Padding = UDim.new(0,6)
    tabButtons.HorizontalAlignment = Enum.HorizontalAlignment.Center
    tabButtons.SortOrder = Enum.SortOrder.LayoutOrder

    -- Content layout
    local contentHolder = make{Class="Frame", Name="Pages", Size=UDim2.new(1,0,1,0), BackgroundTransparency=1}
    contentHolder.Parent = content

    -- API for window
    local self = setmetatable({
        ScreenGui = sg,
        MainFrame = main,
        Tabs = {},
        CurrentPage = nil,
        Theme = {
            Background = main.BackgroundColor3,
            Accent = options.Accent or Color3.fromRGB(0,170,255),
            Text = options.Text or Color3.fromRGB(235,235,235),
            Secondary = options.Secondary or Color3.fromRGB(30,30,34),
        },
        SaveBackend = options.SaveBackend or "remote", -- "remote" uses ReplicatedStorage event
    }, OptionsLib)

    function self:AddTab(name)
        -- button
        local btn = make{Class="TextButton", Text=name, Size=UDim2.new(1,-20,0,36), BackgroundTransparency=0, BackgroundColor3=self.Theme.Secondary}
        btn.TextColor3 = self.Theme.Text
        btn.Parent = leftBar

        local page = make{Class="Frame", Name="Page_"..name, Size=UDim2.new(1,0,1,0), BackgroundTransparency=1, Visible=false}
        page.Parent = contentHolder

        -- page layout
        local layout = Instance.new("UIListLayout", page)
        layout.Padding = UDim.new(0,8)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.FillDirection = Enum.FillDirection.Vertical

        btn.MouseButton1Click:Connect(function()
            if self.CurrentPage then
                self.CurrentPage.Visible = false
            end
            page.Visible = true
            self.CurrentPage = page
        end)

        -- auto select first tab
        if #self.Tabs == 0 then
            btn:CaptureFocus()
            btn.MouseButton1Click:Fire()
            page.Visible = true
            self.CurrentPage = page
        end

        local tabObj = {
            Name = name,
            Button = btn,
            Page = page,
            AddToggle = function(_, label, default, callback)
                local frame = Instance.new("Frame", page)
                frame.Size = UDim2.new(1,-16,0,38)
                frame.BackgroundColor3 = self.Theme.Secondary
                local txt = Instance.new("TextLabel", frame)
                txt.Size = UDim2.new(1,-86,1,0)
                txt.Position = UDim2.new(0,8,0,0)
                txt.Text = label
                txt.TextColor3 = self.Theme.Text
                txt.BackgroundTransparency = 1
                txt.Font = Enum.Font.Gotham
                txt.TextSize = 14

                local toggle = Instance.new("TextButton", frame)
                toggle.Size = UDim2.new(0,60,0,22)
                toggle.Position = UDim2.new(1,-70,0,8)
                toggle.Text = default and "On" or "Off"
                toggle.BackgroundColor3 = default and self.Theme.Accent or Color3.fromRGB(80,80,84)
                toggle.TextColor3 = Color3.new(1,1,1)
                local state = default
                toggle.MouseButton1Click:Connect(function()
                    state = not state
                    toggle.Text = state and "On" or "Off"
                    tween(toggle, {BackgroundColor3 = state and self.Theme.Accent or Color3.fromRGB(80,80,84)}, 0.18)
                    if callback then pcall(callback, state) end
                end)
                return frame
            end,
            AddButton = function(_, label, callback)
                local btn = Instance.new("TextButton", page)
                btn.Size = UDim2.new(1,-16,0,36)
                btn.Text = label
                btn.Font = Enum.Font.GothamSemibold
                btn.TextSize = 15
                btn.BackgroundColor3 = self.Theme.Accent
                btn.TextColor3 = Color3.new(1,1,1)
                btn.MouseButton1Click:Connect(function() pcall(callback) end)
                return btn
            end,
            AddSlider = function(_, label, min, max, default, callback)
                local frame = Instance.new("Frame", page)
                frame.Size = UDim2.new(1,-16,0,54)
                frame.BackgroundColor3 = self.Theme.Secondary
                local txt = Instance.new("TextLabel", frame)
                txt.Size = UDim2.new(1,0,0,18); txt.Text = label; txt.BackgroundTransparency = 1; txt.TextColor3 = self.Theme.Text; txt.Font = Enum.Font.Gotham; txt.TextSize = 14
                local barBg = Instance.new("Frame", frame)
                barBg.Size = UDim2.new(1,-20,0,12); barBg.Position = UDim2.new(0,10,0,28); barBg.BackgroundColor3 = Color3.fromRGB(60,60,64)
                local fill = Instance.new("Frame", barBg)
                fill.Size = UDim2.new((default-min)/(max-min),0,1,0)
                fill.BackgroundColor3 = self.Theme.Accent
                -- dragging
                local dragging = false
                local function updateFromInput(x)
                    local rel = math.clamp((x - barBg.AbsolutePosition.X) / barBg.AbsoluteSize.X, 0, 1)
                    fill.Size = UDim2.new(rel,0,1,0)
                    local val = min + rel * (max - min)
                    if callback then pcall(callback, val) end
                end
                barBg.InputBegan:Connect(function(inp)
                    if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                        dragging = true
                        updateFromInput(inp.Position.X)
                    end
                end)
                game:GetService("UserInputService").InputChanged:Connect(function(inp)
                    if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
                        updateFromInput(inp.Position.X)
                    end
                end)
                game:GetService("UserInputService").InputEnded:Connect(function(inp)
                    if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                        dragging = false
                    end
                end)
                return frame
            end,
            AddDropdown = function(_, label, items, callback)
                local frame = Instance.new("Frame", page)
                frame.Size = UDim2.new(1,-16,0,36)
                frame.BackgroundColor3 = self.Theme.Secondary
                local txt = Instance.new("TextLabel", frame)
                txt.Size = UDim2.new(1,-86,1,0)
                txt.Position = UDim2.new(0,8,0,0)
                txt.Text = label
                txt.TextColor3 = self.Theme.Text
                txt.BackgroundTransparency = 1
                txt.Font = Enum.Font.Gotham
                txt.TextSize = 14

                local btn = Instance.new("TextButton", frame)
                btn.Size = UDim2.new(0,60,0,22)
                btn.Position = UDim2.new(1,-70,0,8)
                btn.Text = "Select"
                btn.BackgroundColor3 = Color3.fromRGB(80,80,84)
                btn.TextColor3 = Color3.new(1,1,1)

                local list = Instance.new("Frame", frame)
                list.Size = UDim2.new(1,0,0,0)
                list.Position = UDim2.new(0,0,1,0)
                list.BackgroundTransparency = 1
                list.ClipsDescendants = true

                local layout = Instance.new("UIListLayout", list)
                layout.SortOrder = Enum.SortOrder.LayoutOrder

                local opened = false
                btn.MouseButton1Click:Connect(function()
                    opened = not opened
                    spawn(function()
                        for i=1, #items do
                            local it = Instance.new("TextButton", list)
                            it.Size = UDim2.new(1, -16, 0, 28)
                            it.Position = UDim2.new(0, 8, 0, 0)
                            it.Text = tostring(items[i])
                            it.BackgroundColor3 = self.Theme.Secondary
                            it.TextColor3 = self.Theme.Text
                            it.MouseButton1Click:Connect(function()
                                btn.Text = tostring(items[i])
                                if callback then pcall(callback, items[i]) end
                                list:ClearAllChildren()
                                opened = false
                            end)
                        end
                    end)
                    tween(list, {Size = opened and UDim2.new(1,0,0, math.min(6, #items)*28) or UDim2.new(1,0,0,0)}, 0.18)
                end)
                return frame
            end,
            AddColorPicker = function(_, label, default, callback)
                local frame = Instance.new("Frame", page)
                frame.Size = UDim2.new(1,-16,0,44)
                frame.BackgroundColor3 = self.Theme.Secondary
                local txt = Instance.new("TextLabel", frame)
                txt.Size = UDim2.new(1,-86,0,18)
                txt.Position = UDim2.new(0,8,0,0)
                txt.Text = label
                txt.TextColor3 = self.Theme.Text
                txt.BackgroundTransparency = 1
                txt.Font = Enum.Font.Gotham
                txt.TextSize = 14

                local preview = Instance.new("Frame", frame)
                preview.Size = UDim2.new(0,36,0,22)
                preview.Position = UDim2.new(1,-52,0,8)
                preview.BackgroundColor3 = default or self.Theme.Accent

                local btn = Instance.new("TextButton", frame)
                btn.Size = UDim2.new(0,36,0,22)
                btn.Position = UDim2.new(1,-96,0,8)
                btn.Text = "Edit"
                btn.BackgroundColor3 = self.Theme.Secondary
                btn.TextColor3 = self.Theme.Text

                -- VERY SIMPLE color dialog (three sliders)
                btn.MouseButton1Click:Connect(function()
                    local dialog = Instance.new("Frame", self.ScreenGui.MainWindow)
                    dialog.Size = UDim2.new(0,260,0,140)
                    dialog.Position = UDim2.new(0.5,-130,0.5,-70)
                    dialog.BackgroundColor3 = self.Theme.Secondary
                    dialog.Parent = self.ScreenGui

                    local rs = {{"R"}, {"G"}, {"B"}}
                    for i=1,3 do
                        local lab = Instance.new("TextLabel", dialog)
                        lab.Position = UDim2.new(0,8,0,8 + (i-1)*36)
                        lab.Size = UDim2.new(0,36,0,20)
                        lab.Text = rs[i][1]
                        lab.BackgroundTransparency = 1
                        lab.TextColor3 = self.Theme.Text

                        local sliderBg = Instance.new("Frame", dialog)
                        sliderBg.Position = UDim2.new(0,50,0,8 + (i-1)*36)
                        sliderBg.Size = UDim2.new(0,192,0,20)
                        sliderBg.BackgroundColor3 = Color3.fromRGB(60,60,64)

                        local fill = Instance.new("Frame", sliderBg)
                        fill.Size = UDim2.new(1,0,1,0)
                        fill.BackgroundColor3 = Color3.fromRGB(200,200,200)

                        -- simple drag to change value (not fully robust)
                        sliderBg.InputBegan:Connect(function(inp)
                            if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                                local function onMove(input)
                                    local x = math.clamp((input.Position.X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X, 0, 1)
                                    fill.Size = UDim2.new(x,0,1,0)
                                    local c = preview.BackgroundColor3
                                    local r,g,b = c.R, c.G, c.B
                                    if i==1 then r = x end
                                    if i==2 then g = x end
                                    if i==3 then b = x end
                                    preview.BackgroundColor3 = Color3.new(r,g,b)
                                    if callback then pcall(callback, preview.BackgroundColor3) end
                                end
                                local conn
                                conn = game:GetService("UserInputService").InputChanged:Connect(function(inpt)
                                    if inpt.UserInputType == Enum.UserInputType.MouseMovement then
                                        onMove(inpt)
                                    end
                                end)
                                local upconn
                                upconn = game:GetService("UserInputService").InputEnded:Connect(function(inpt)
                                    if inpt.UserInputType == Enum.UserInputType.MouseButton1 then
                                        conn:Disconnect(); upconn:Disconnect()
                                    end
                                end)
                            end
                        end)
                    end
                    wait(0.2)
                end)
                return frame
            end,
        }

        table.insert(self.Tabs, tabObj)
        return tabObj
    end

    function self:Show()
        self.ScreenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    end

    function self:Destroy()
        self.ScreenGui:Destroy()
    end

    -- Save / Load using RemoteEvent to server
    function self:SaveData(key, tbl)
        if not saveEvent then
            warn("[OptionsLib] Save event not found in ReplicatedStorage:", SAVE_EVENT_NAME)
            return false
        end
        local payload = {Action="Save", Key=key, Data=tbl}
        saveEvent:FireServer(payload)
        return true
    end

    function self:LoadData(key, callback)
        if not saveEvent then
            warn("[OptionsLib] Save event not found in ReplicatedStorage:", SAVE_EVENT_NAME)
            if callback then callback(nil) end
            return
        end
        local payload = {Action="Load", Key=key}
        -- Use Invoke if available (better) or event-based; we'll use FireServer + client event would require server to respond
        -- For simple approach, we FireServer and expect server to use :FireClient to return (server script included handles it).
        saveEvent:FireServer(payload)
        -- The response will be handled by a "OptionsLib_LoadResponse" RemoteEvent fired to client by server; listen once:
        local respName = "OptionsLib_LoadResponse"
        local respEvent = ReplicatedStorage:FindFirstChild(respName)
        if respEvent and respEvent:IsA("RemoteEvent") then
            local conn
            conn = respEvent.OnClientEvent:Connect(function(response)
                if response.Key == key then
                    if callback then pcall(callback, response.Data) end
                    conn:Disconnect()
                end
            end)
        else
            warn("[OptionsLib] No response event found. Please add a RemoteEvent named 'OptionsLib_LoadResponse' in ReplicatedStorage or use a custom backend.")
            if callback then callback(nil) end
        end
    end

    -- Theme save/load wrappers
    function self:SaveTheme(key)
        self:SaveData("theme_"..(key or "default"), self.Theme)
    end

    function self:LoadTheme(key, cb)
        self:LoadData("theme_"..(key or "default"), function(data)
            if data then
                for k,v in pairs(data) do
                    if self.Theme[k] ~= nil then
                        self.Theme[k] = v
                    end
                end
            end
            if cb then cb(data) end
        end)
    end

    return self
end

return setmetatable({}, {
    __call = function(_, ...) return OptionsLib:CreateWindow(...) end
})
