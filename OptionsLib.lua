-- optionshub.lua
-- A modern, feature-rich GUI library for Roblox (ModuleScript)
-- v1.0.0 - Big feature set: tabs, add-tab(+), search, icons, theme, save/load, notifications, and many widgets.
-- Replace icon placeholders with your own decal/image asset ids.

local OptionsHub = {}
OptionsHub.__index = OptionsHub

-- Services
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local LOCAL_PLAYER = Players.LocalPlayer

-- RemoteEvent names used for saving/loading (server should create/handle)
local SAVE_EVENT_NAME = "OptionsLib_SaveEvent"
local LOAD_RESPONSE_NAME = "OptionsLib_LoadResponse"

-- Utility: safe find/create RemoteEvent on client (server normally creates these)
local function getRemote(name)
    local r = ReplicatedStorage:FindFirstChild(name)
    return r
end

-- Default icon map (lucide names -> placeholder rbxassetid)
local DEFAULT_ICONS = {
    plus = "rbxassetid://0",
    search = "rbxassetid://0",
    settings = "rbxassetid://0",
    save = "rbxassetid://0",
    close = "rbxassetid://0",
    toggle = "rbxassetid://0",
    slider = "rbxassetid://0",
    key = "rbxassetid://0",
    color = "rbxassetid://0",
    menu = "rbxassetid://0",
}

-- Default theme
local DEFAULT_THEME = {
    Background = Color3.fromRGB(18, 18, 20),
    Panel = Color3.fromRGB(26, 27, 31),
    Accent = Color3.fromRGB(0, 170, 255),
    AccentAlt = Color3.fromRGB(100, 200, 255),
    Text = Color3.fromRGB(235, 235, 235),
    Muted = Color3.fromRGB(140, 140, 150),
    Success = Color3.fromRGB(110, 210, 120),
    Danger = Color3.fromRGB(255, 80, 80),
    Transparency = 0.06,
}

-- Helper: create instance with properties
local function new(class, props)
    local inst = Instance.new(class)
    if props then
        for k,v in pairs(props) do
            pcall(function() inst[k] = v end)
        end
    end
    return inst
end

-- Helper: tween
local function tween(inst, info, props)
    local t = TweenService:Create(inst, TweenInfo.new(unpack(info)), props)
    t:Play()
    return t
end

local function quickTween(inst, props, time)
    TweenService:Create(inst, TweenInfo.new(time or 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

-- Pretty small utility to set text properties
local function styleText(lbl, size, bold)
    lbl.Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham
    lbl.TextSize = size or 14
    lbl.TextColor3 = DEFAULT_THEME.Text
    lbl.BackgroundTransparency = 1
end

-- Toasts / Notifications
local function makeToast(parent, text, duration)
    duration = duration or 3
    local toast = new("Frame", {
        Parent = parent,
        Size = UDim2.new(0, 320, 0, 44),
        Position = UDim2.new(1, -340, 1, -84),
        BackgroundTransparency = 1,
        ZIndex = 1000,
    })
    local bg = new("Frame", {
        Parent = toast,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Color3.fromRGB(28,28,32),
    })
    local corner = new("UICorner", {Parent = bg, CornerRadius = UDim.new(0,8)})
    local txt = new("TextLabel", {
        Parent = bg,
        Size = UDim2.new(1, -16, 1, 0),
        Position = UDim2.new(0,8,0,0),
        Text = text,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    styleText(txt, 14, false)
    local goal1 = {BackgroundTransparency = 0}
    tween(bg, {0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out}, goal1)
    delay(duration, function()
        tween(bg, {0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In}, {BackgroundTransparency = 1})
        wait(0.2)
        toast:Destroy()
    end)
end

-- Main creator
function OptionsHub.new(opts)
    opts = opts or {}
    local self = setmetatable({}, OptionsHub)

    -- Public config
    self.Icons = opts.Icons or DEFAULT_ICONS
    self.Theme = opts.Theme or DEFAULT_THEME
    self.Name = opts.Name or "OptionsHub"
    self.Width = opts.Width or 720
    self.Height = opts.Height or 460

    -- Internal state
    self.ScreenGui = nil
    self.Tabs = {}
    self.Pages = {}
    self.CurrentPage = nil
    self.SearchIndex = {} -- maps token -> widgets
    self.SaveEvent = getRemote(SAVE_EVENT_NAME)
    self.LoadResponse = getRemote(LOAD_RESPONSE_NAME)

    -- Build UI
    local function build()
        -- ScreenGui (not ResetOnSpawn so it persists while in session)
        local sg = new("ScreenGui", {Name = self.Name .. "_SG", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling})
        self.ScreenGui = sg

        -- Optional: Blur background for "premium" look (client-only)
        local blurFrame = new("Frame", {Parent = sg, Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1})
        local bg = new("Frame", {Parent = blurFrame, Size = UDim2.new(1,0,1,0), BackgroundColor3 = self.Theme.Background, BackgroundTransparency = 0})
        bg.ZIndex = 0

        -- Main window container
        local main = new("Frame", {
            Parent = sg,
            Name = "Main",
            Size = UDim2.new(0, self.Width, 0, self.Height),
            Position = UDim2.new(0.5, -self.Width/2, 0.5, -self.Height/2),
            BackgroundTransparency = 0,
            BackgroundColor3 = self.Theme.Panel,
            Active = true,
            AnchorPoint = Vector2.new(0.5, 0.5),
        })
        local mainCorner = new("UICorner", {Parent = main, CornerRadius = UDim.new(0, 12)})
        local mainStroke = new("UIStroke", {Parent = main, Color = Color3.fromRGB(0,0,0), Transparency = 0.8, Thickness = 1})
        main.ZIndex = 2

        -- Header area
        local header = new("Frame", {Parent = main, Name = "Header", Size = UDim2.new(1,0,0,56), BackgroundTransparency = 1})
        local title = new("TextLabel", {Parent = header, Text = self.Name, Position = UDim2.new(0, 18, 0, 12), Size = UDim2.new(0, 300, 0, 32)})
        styleText(title, 20, true)
        title.TextColor3 = self.Theme.Text

        -- Search bar (top center)
        local searchContainer = new("Frame", {Parent = header, Size = UDim2.new(0, 380, 0, 34), Position = UDim2.new(0.5, -190, 0, 12), BackgroundColor3 = Color3.fromRGB(24,24,28)})
        new("UICorner", {Parent = searchContainer, CornerRadius = UDim.new(0, 8)})
        local searchBox = new("TextBox", {Parent = searchContainer, Size = UDim2.new(1, -40, 1, 0), Position = UDim2.new(0, 12, 0, 0), PlaceholderText = "Search options...", Text = ""})
        styleText(searchBox, 14, false)
        searchBox.TextColor3 = self.Theme.Text
        searchBox.BackgroundTransparency = 1
        local searchIcon = new("ImageLabel", {Parent = searchContainer, Size = UDim2.new(0, 24, 0, 24), Position = UDim2.new(1, -34, 0.5, -12), BackgroundTransparency = 1, Image = self.Icons.search})
        -- quick clear on Escape
        searchBox.FocusLost:Connect(function(enter)
            if not enter then searchBox.Text = "" end
        end)

        -- Left tab bar
        local leftBar = new("Frame", {Parent = main, Name = "LeftBar", Size = UDim2.new(0, 180, 1, -56), Position = UDim2.new(0, 0, 0, 56), BackgroundColor3 = Color3.fromRGB(22, 22, 26)})
        new("UICorner", {Parent = leftBar, CornerRadius = UDim.new(0, 10)})
        local leftLayout = new("UIListLayout", {Parent = leftBar, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder})
        leftLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        local tabHolder = new("ScrollingFrame", {Parent = leftBar, Name = "TabScroll", Size = UDim2.new(1, -12, 1, -24), Position = UDim2.new(0, 6, 0, 12), BackgroundTransparency = 1, ScrollBarImageColor3 = Color3.fromRGB(70,70,75)})
        tabHolder.CanvasSize = UDim2.new(0, 0, 0, 0)
        tabHolder.AutomaticCanvasSize = Enum.AutomaticSize.Y
        local addTabBtn = new("TextButton", {Parent = leftBar, Text = "+", Size = UDim2.new(0, 30, 0, 30), Position = UDim2.new(0.5, -15, 1, -44), BackgroundColor3 = self.Theme.Accent})
        new("UICorner", {Parent = addTabBtn, CornerRadius = UDim.new(0, 6)})
        addTabBtn.TextColor3 = Color3.new(1,1,1)
        addTabBtn.Font = Enum.Font.GothamBold
        addTabBtn.TextSize = 20

        -- Right content area (pages)
        local content = new("Frame", {Parent = main, Name = "Content", Position = UDim2.new(0, 180, 0, 56), Size = UDim2.new(1, -180, 1, -56), BackgroundTransparency = 1})
        local pageHolder = new("Frame", {Parent = content, Name = "Pages", BackgroundTransparency = 1, Size = UDim2.new(1,0,1,0)})
        local pagesLayout = new("UIListLayout", {Parent = pageHolder, SortOrder = Enum.SortOrder.LayoutOrder})
        pagesLayout.Padding = UDim.new(0, 10)

        -- Footer: small hint + save/load buttons
        local footer = new("Frame", {Parent = main, Name = "Footer", Size = UDim2.new(1,0,0,40), Position = UDim2.new(0,0,1,-40), BackgroundTransparency = 1})
        local footerText = new("TextLabel", {Parent = footer, Text = "OptionsHub — beautiful settings library", Position = UDim2.new(0, 18, 0, 8), Size = UDim2.new(0.5, 0, 1, -8)})
        styleText(footerText, 13, false)
        footerText.TextColor3 = self.Theme.Muted

        local saveBtn = new("TextButton", {Parent = footer, Text = "Save Theme", Size = UDim2.new(0, 110, 0, 28), Position = UDim2.new(1, -250, 0.5, -14), BackgroundColor3 = self.Theme.Accent})
        new("UICorner", {Parent = saveBtn, CornerRadius = UDim.new(0, 6)})
        saveBtn.TextColor3 = Color3.new(1,1,1)
        saveBtn.Font = Enum.Font.GothamSemibold
        saveBtn.TextSize = 14

        local loadBtn = new("TextButton", {Parent = footer, Text = "Load Theme", Size = UDim2.new(0, 110, 0, 28), Position = UDim2.new(1, -130, 0.5, -14), BackgroundColor3 = Color3.fromRGB(54,54,58)})
        new("UICorner", {Parent = loadBtn, CornerRadius = UDim.new(0, 6)})
        loadBtn.TextColor3 = Color3.new(1,1,1)
        loadBtn.Font = Enum.Font.GothamSemibold
        loadBtn.TextSize = 14

        -- attach to self
        self.ScreenGui = sg
        self.Main = main
        self.LeftBar = leftBar
        self.TabScroll = tabHolder
        self.AddTabBtn = addTabBtn
        self.PageHolder = pageHolder
        self.SearchBox = searchBox
        self.SaveBtn = saveBtn
        self.LoadBtn = loadBtn
        self.ToastParent = main

        -- Make draggable main (roblox provides Draggable on frame, but custom dragging gives smoother control)
        local dragging = false
        local dragStart = nil
        local startPos = nil
        header.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = true
                dragStart = input.Position
                startPos = main.Position
            end
        end)
        header.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement then
                -- handled by InputChanged above
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                local delta = input.Position - dragStart
                main.Position = startPos + UDim2.new(0, delta.X, 0, delta.Y)
            end
        end)
        header.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = false
            end
        end)

        -- Add tab handler
        local function createTab(name)
            name = name or ("Tab " .. tostring(#self.Tabs + 1))
            -- Button in left bar
            local btn = new("TextButton", {Parent = tabHolder, Size = UDim2.new(1, -12, 0, 36), Text = name, BackgroundColor3 = Color3.fromRGB(20,20,22)})
            new("UICorner", {Parent = btn, CornerRadius = UDim.new(0,6)})
            styleText(btn, 14, false)
            btn.TextColor3 = self.Theme.Text
            -- Page
            local page = new("Frame", {Parent = pageHolder, Size = UDim2.new(1,0,0, 10), BackgroundTransparency = 1, Visible = false})
            local pageLayout = new("UIListLayout", {Parent = page, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder})
            pageLayout.FillDirection = Enum.FillDirection.Vertical

            local tabRec = {
                Name = name,
                Button = btn,
                Page = page,
                Widgets = {}
            }

            function tabRec:AddToggle(label, default, callback)
                local frame = new("Frame", {Parent = page, Size = UDim2.new(1, -16, 0, 40), BackgroundColor3 = Color3.fromRGB(28,28,32)})
                new("UICorner", {Parent = frame, CornerRadius = UDim.new(0,8)})
                local lbl = new("TextLabel", {Parent = frame, Text = label or "Toggle", Position = UDim2.new(0, 12, 0, 6), Size = UDim2.new(1, -120, 0, 28)})
                styleText(lbl, 14, false)
                lbl.TextColor3 = self.Theme.Text
                local btn = new("TextButton", {Parent = frame, Text = default and "On" or "Off", Size = UDim2.new(0, 84, 0, 28), Position = UDim2.new(1, -96, 0, 6), BackgroundColor3 = default and self.Theme.Accent or Color3.fromRGB(70,70,74)})
                new("UICorner", {Parent = btn, CornerRadius = UDim.new(0,6)})
                btn.TextColor3 = Color3.new(1,1,1)
                local state = default and true or false
                btn.MouseButton1Click:Connect(function()
                    state = not state
                    btn.Text = state and "On" or "Off"
                    quickTween(btn, {BackgroundColor3 = state and OptionsHub.Theme.Accent or Color3.fromRGB(70,70,74)}, 0.16)
                    if callback then pcall(callback, state) end
                end)
                -- index for search
                table.insert(self.Widgets, {type="toggle", label=label, widget=frame, get=function() return state end})
                return frame
            end

            function tabRec:AddButton(label, callback)
                local btn = new("TextButton", {Parent = page, Text = label or "Button", Size = UDim2.new(1, -16, 0, 36), BackgroundColor3 = self.Theme.Accent})
                new("UICorner", {Parent = btn, CornerRadius = UDim.new(0,8)})
                btn.Font = Enum.Font.GothamSemibold
                btn.TextColor3 = Color3.new(1,1,1)
                btn.MouseButton1Click:Connect(function() pcall(callback) end)
                table.insert(self.Widgets, {type="button", label=label, widget=btn})
                return btn
            end

            function tabRec:AddSlider(label, min, max, default, callback)
                local frame = new("Frame", {Parent = page, Size = UDim2.new(1, -16, 0, 56), BackgroundColor3 = Color3.fromRGB(28,28,32)})
                new("UICorner", {Parent = frame, CornerRadius = UDim.new(0,8)})
                local lbl = new("TextLabel", {Parent = frame, Text = label or "Slider", Position = UDim2.new(0, 12, 0, 6), Size = UDim2.new(1, -24, 0, 20)})
                styleText(lbl, 14, false)
                lbl.TextColor3 = self.Theme.Text
                local barBg = new("Frame", {Parent = frame, Size = UDim2.new(1, -36, 0, 14), Position = UDim2.new(0, 12, 0, 30), BackgroundColor3 = Color3.fromRGB(48,48,52)})
                new("UICorner", {Parent = barBg, CornerRadius = UDim.new(0,6)})
                local fill = new("Frame", {Parent = barBg, Size = UDim2.new(((default or min)-min)/(max-min), 0, 1, 0), BackgroundColor3 = self.Theme.Accent})
                new("UICorner", {Parent = fill, CornerRadius = UDim.new(0,6)})
                local dragging = false
                local function updateFromPosition(x)
                    local rel = math.clamp((x - barBg.AbsolutePosition.X) / barBg.AbsoluteSize.X, 0, 1)
                    fill.Size = UDim2.new(rel, 0, 1, 0)
                    local val = min + rel * (max - min)
                    if callback then pcall(callback, val) end
                end
                barBg.InputBegan:Connect(function(inp)
                    if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                        dragging = true
                        updateFromPosition(inp.Position.X)
                    end
                end)
                UserInputService.InputChanged:Connect(function(inp)
                    if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
                        updateFromPosition(inp.Position.X)
                    end
                end)
                UserInputService.InputEnded:Connect(function(inp)
                    if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                        dragging = false
                    end
                end)
                table.insert(self.Widgets, {type="slider", label=label, widget=frame})
                return frame
            end

            function tabRec:AddDropdown(label, items, callback)
                local frame = new("Frame", {Parent = page, Size = UDim2.new(1, -16, 0, 36), BackgroundColor3 = Color3.fromRGB(28,28,32)})
                new("UICorner", {Parent = frame, CornerRadius = UDim.new(0,8)})
                local lbl = new("TextLabel", {Parent = frame, Text = label or "Dropdown", Position = UDim2.new(0,12,0,6), Size = UDim2.new(1, -120, 1, 0)})
                styleText(lbl, 14, false)
                local btn = new("TextButton", {Parent = frame, Text = "Select", Position = UDim2.new(1, -96, 0, 6), Size = UDim2.new(0, 84, 0, 24), BackgroundColor3 = Color3.fromRGB(70,70,74)})
                new("UICorner", {Parent = btn, CornerRadius = UDim.new(0,6)})
                btn.TextColor3 = Color3.new(1,1,1)
                local list = new("Frame", {Parent = frame, Size = UDim2.new(1, 0, 0, 0), Position = UDim2.new(0, 0, 1, 6), BackgroundTransparency = 1, ClipsDescendants = true})
                local open = false
                btn.MouseButton1Click:Connect(function()
                    open = not open
                    if open then
                        local total = 0
                        for i, v in ipairs(items or {}) do
                            local it = new("TextButton", {Parent = list, Text = tostring(v), Size = UDim2.new(1, -16, 0, 28), Position = UDim2.new(0, 8, 0, total), BackgroundColor3 = Color3.fromRGB(34,34,36)})
                            new("UICorner", {Parent = it, CornerRadius = UDim.new(0,6)})
                            it.TextColor3 = self.Theme.Text
                            total = total + 34
                            it.MouseButton1Click:Connect(function()
                                btn.Text = tostring(v)
                                if callback then pcall(callback, v) end
                                for _,c in ipairs(list:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
                                quickTween(list, {Size = UDim2.new(1,0,0,0)}, 0.15)
                                open = false
                            end)
                        end
                        quickTween(list, {Size = UDim2.new(1,0,0, math.min(6,#items)*34)}, 0.15)
                    else
                        for _,c in ipairs(list:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
                        quickTween(list, {Size = UDim2.new(1,0,0,0)}, 0.15)
                    end
                end)
                table.insert(self.Widgets, {type="dropdown", label=label, widget=frame})
                return frame
            end

            function tabRec:AddColorPicker(label, default, callback)
                local frame = new("Frame", {Parent = page, Size = UDim2.new(1,-16,0,44), BackgroundColor3 = Color3.fromRGB(28,28,32)})
                new("UICorner", {Parent = frame, CornerRadius = UDim.new(0,8)})
                local lbl = new("TextLabel", {Parent = frame, Text = label or "Color", Position = UDim2.new(0,12,0,6), Size = UDim2.new(1, -120, 0, 20)})
                styleText(lbl, 14, false)
                local preview = new("Frame", {Parent = frame, Size = UDim2.new(0,34,0,28), Position = UDim2.new(1, -52, 0, 8), BackgroundColor3 = default or self.Theme.Accent})
                new("UICorner", {Parent = preview, CornerRadius = UDim.new(0,6)})
                local btn = new("TextButton", {Parent = frame, Text = "Edit", Size = UDim2.new(0, 64, 0, 28), Position = UDim2.new(1, -120, 0, 8), BackgroundColor3 = Color3.fromRGB(40,40,44)})
                new("UICorner", {Parent = btn, CornerRadius = UDim.new(0,6)})
                btn.TextColor3 = self.Theme.Text
                btn.MouseButton1Click:Connect(function()
                    -- Simple color picker popup
                    local popup = new("Frame", {Parent = self.ScreenGui, Size = UDim2.new(0, 300, 0, 140), Position = UDim2.new(0.5, -150, 0.5, -70), BackgroundColor3 = self.Theme.Panel})
                    new("UICorner", {Parent = popup, CornerRadius = UDim.new(0,8)})
                    local lblR = new("TextLabel", {Parent = popup, Text = "R", Position = UDim2.new(0, 10, 0, 6), Size = UDim2.new(0, 20, 0, 20)}); styleText(lblR, 12, false)
                    local sR = new("Frame", {Parent = popup, Position = UDim2.new(0, 40, 0, 6), Size = UDim2.new(0, 240, 0, 20), BackgroundColor3 = Color3.fromRGB(60,60,64)})
                    new("UICorner", {Parent = sR, CornerRadius = UDim.new(0,6)})
                    local fR = new("Frame", {Parent = sR, Size = UDim2.new(preview.BackgroundColor3.R, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(200,0,0)})
                    for i=1,3 do
                        local y = 6 + i*36
                        local lab = new("TextLabel", {Parent = popup, Text = (i==1 and "R") or (i==2 and "G") or "B", Position = UDim2.new(0, 10, 0, y), Size = UDim2.new(0, 20, 0, 20)}); styleText(lab, 12, false)
                        local slab = new("Frame", {Parent = popup, Position = UDim2.new(0, 40, 0, y), Size = UDim2.new(0, 240, 0, 20), BackgroundColor3 = Color3.fromRGB(60,60,64)})
                        new("UICorner", {Parent = slab, CornerRadius = UDim.new(0,6)})
                        local fill = new("Frame", {Parent = slab, Size = UDim2.new((preview.BackgroundColor3[i] or 0), 0, 1, 0), BackgroundColor3 = Color3.fromRGB(200,200,200)})
                        -- dragging & update
                        local dragging = false
                        slab.InputBegan:Connect(function(inp)
                            if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                                dragging = true
                                local function onMove(move)
                                    local rel = math.clamp((move.Position.X - slab.AbsolutePosition.X) / slab.AbsoluteSize.X, 0, 1)
                                    fill.Size = UDim2.new(rel,0,1,0)
                                    local c = preview.BackgroundColor3
                                    local r,g,b = c.R, c.G, c.B
                                    if i==1 then r = rel end
                                    if i==2 then g = rel end
                                    if i==3 then b = rel end
                                    preview.BackgroundColor3 = Color3.new(r,g,b)
                                    if callback then pcall(callback, preview.BackgroundColor3) end
                                end
                                local conn
                                conn = UserInputService.InputChanged:Connect(function(m)
                                    if m.UserInputType == Enum.UserInputType.MouseMovement then onMove(m) end
                                end)
                                local up
                                up = UserInputService.InputEnded:Connect(function(m)
                                    if m.UserInputType == Enum.UserInputType.MouseButton1 then conn:Disconnect(); up:Disconnect() end
                                end)
                            end
                        end)
                    end
                    local closeBtn = new("TextButton", {Parent = popup, Text = "Close", Size = UDim2.new(0, 80, 0, 28), Position = UDim2.new(1, -90, 1, -38)})
                    new("UICorner", {Parent = closeBtn, CornerRadius = UDim.new(0,6)})
                    closeBtn.MouseButton1Click:Connect(function() popup:Destroy() end)
                end)
                table.insert(self.Widgets, {type="color", label=label, widget=frame})
                return frame
            end

            function tabRec:AddKeybind(label, default, callback)
                local frame = new("Frame", {Parent = page, Size = UDim2.new(1, -16, 0, 40), BackgroundColor3 = Color3.fromRGB(28,28,32)})
                new("UICorner", {Parent = frame, CornerRadius = UDim.new(0,8)})
                local lbl = new("TextLabel", {Parent = frame, Text = label or "Keybind", Position = UDim2.new(0,12,0,6), Size = UDim2.new(1, -160, 0, 28)})
                styleText(lbl, 14, false)
                local keyBtn = new("TextButton", {Parent = frame, Text = tostring(default) or "None", Size = UDim2.new(0,120,0,28), Position = UDim2.new(1, -140, 0, 6), BackgroundColor3 = Color3.fromRGB(70,70,74)})
                new("UICorner", {Parent = keyBtn, CornerRadius = UDim.new(0,6)})
                keyBtn.TextColor3 = Color3.new(1,1,1)
                local current = default
                keyBtn.MouseButton1Click:Connect(function()
                    keyBtn.Text = "Press key..."
                    local conn
                    conn = UserInputService.InputBegan:Connect(function(inp, gameProcessed)
                        if gameProcessed then return end
                        if inp.UserInputType == Enum.UserInputType.Keyboard then
                            current = inp.KeyCode.Name
                            keyBtn.Text = current
                            if callback then pcall(callback, current) end
                            conn:Disconnect()
                        end
                    end)
                end)
                -- run callback on key pressed (global)
                UserInputService.InputBegan:Connect(function(inp, gp)
                    if gp then return end
                    if inp.UserInputType == Enum.UserInputType.Keyboard then
                        if inp.KeyCode.Name == current then
                            pcall(callback, current)
                        end
                    end
                end)
                table.insert(self.Widgets, {type="keybind", label=label, widget=frame})
                return frame
            end

            function tabRec:AddTextbox(label, placeholder, callback)
                local frame = new("Frame", {Parent = page, Size = UDim2.new(1,-16,0,44), BackgroundColor3 = Color3.fromRGB(28,28,32)})
                new("UICorner", {Parent = frame, CornerRadius = UDim.new(0,8)})
                local lbl = new("TextLabel", {Parent = frame, Text = label or "Input", Position = UDim2.new(0, 12, 0, 6), Size = UDim2.new(1, -140, 0, 18)})
                styleText(lbl, 14, false)
                local box = new("TextBox", {Parent = frame, PlaceholderText = placeholder or "Type here", Size = UDim2.new(0.6, 0, 0, 28), Position = UDim2.new(0.38, -12, 0, 8), BackgroundColor3 = Color3.fromRGB(40,40,44)})
                new("UICorner", {Parent = box, CornerRadius = UDim.new(0,6)})
                styleText(box, 14, false)
                box.TextColor3 = self.Theme.Text
                box.FocusLost:Connect(function(enter)
                    if enter then
                        if callback then pcall(callback, box.Text) end
                    end
                end)
                table.insert(self.Widgets, {type="textbox", label=label, widget=frame})
                return frame
            end

            -- when a tab is clicked, show page
            btn.MouseButton1Click:Connect(function()
                if self.CurrentPage and self.CurrentPage ~= page then
                    self.CurrentPage.Visible = false
                end
                page.Visible = true
                self.CurrentPage = page
            end)

            table.insert(self.Tabs, tabRec)
            return tabRec
        end

        -- connect add tab button
        addTabBtn.MouseButton1Click:Connect(function()
            local name = "Custom " .. tostring(#self.Tabs + 1)
            createTab(name)
            makeToast(self.ToastParent, "Created tab: " .. name, 2.5)
            -- auto select last tab
            local last = self.Tabs[#self.Tabs]
            wait() -- small delay for layout
            last.Button:CaptureFocus()
            last.Button:MouseButton1Click()
        end)

        -- search logic: simple label scanning across widgets
        searchBox:GetPropertyChangedSignal("Text"):Connect(function()
            local txt = searchBox.Text:lower()
            for _, tab in ipairs(self.Tabs) do
                for _, w in ipairs(tab.Widgets) do
                    local label = (w.label or ""):lower()
                    if label:find(txt) then
                        if tab.Page then tab.Page.Visible = true end
                        -- optionally highlight widget
                        if w.widget and w.widget.BackgroundColor3 then
                            local original = w.widget.BackgroundColor3
                            quickTween(w.widget, {BackgroundColor3 = Color3.fromRGB(60,60,66)}, 0.08)
                            delay(0.4, function() quickTween(w.widget, {BackgroundColor3 = original}, 0.14) end)
                        end
                    else
                        -- Hide page if nothing matches in that page
                        -- We'll do a quick check
                        local found = false
                        for _, ww in ipairs(tab.Widgets) do
                            if (ww.label or ""):lower():find(txt) then found = true; break end
                        end
                        tab.Page.Visible = found and (tab.Page == self.CurrentPage or found)
                    end
                end
            end
        end)

        -- save / load hooks
        saveBtn.MouseButton1Click:Connect(function()
            if not self.SaveEvent then
                makeToast(self.ToastParent, "SaveEvent missing in ReplicatedStorage. Server script must create it.", 4)
                return
            end
            -- Save theme as an example
            local payload = {Action = "Save", Key = "theme_default", Data = self.Theme}
            self.SaveEvent:FireServer(payload)
            makeToast(self.ToastParent, "Save requested", 2.2)
        end)
        loadBtn.MouseButton1Click:Connect(function()
            if not self.SaveEvent then
                makeToast(self.ToastParent, "SaveEvent missing in ReplicatedStorage. Server script must create it.", 4)
                return
            end
            local payload = {Action = "Load", Key = "theme_default"}
            self.SaveEvent:FireServer(payload)
            makeToast(self.ToastParent, "Load requested", 2.2)
        end)

        -- if server sends LoadResponse, apply theme
        if self.LoadResponse then
            self.LoadResponse.OnClientEvent:Connect(function(response)
                if response and response.Key and response.Data then
                    if response.Key == "theme_default" then
                        for k,v in pairs(response.Data) do
                            if self.Theme[k] ~= nil then
                                self.Theme[k] = v
                            end
                        end
                        makeToast(self.ToastParent, "Theme loaded from server", 2.2)
                    end
                else
                    makeToast(self.ToastParent, "No theme data on server", 2.2)
                end
            end)
        end

        -- Quick visual entrance
        main.Position = UDim2.new(0.5, -self.Width/2, -1, -self.Height) -- start off-screen
        tween(main, {0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out}, {Position = UDim2.new(0.5, -self.Width/2, 0.5, -self.Height/2)})
        -- return references
    end

    build()

    -- Public API
    function self:Show(parent)
        parent = parent or LOCAL_PLAYER:WaitForChild("PlayerGui")
        self.ScreenGui.Parent = parent
        return self
    end

    function self:Hide()
        if self.ScreenGui then self.ScreenGui.Parent = nil end
    end

    function self:CreateTab(name)
        local tab = nil
        -- call inner createTab by firing the add button's logic - but we need direct access to createTab
        -- For simplicity, simulate by creating a new tab via AddTab function exposed below
        tab = (function()
            -- create same structure as internal build createTab
            local index = #self.Tabs + 1
            local btn = new("TextButton", {Parent = self.TabScroll, Size = UDim2.new(1, -12, 0, 36), Text = name or ("Tab "..index), BackgroundColor3 = Color3.fromRGB(20,20,22)})
            new("UICorner", {Parent = btn, CornerRadius = UDim.new(0,6)})
            styleText(btn, 14, false)
            btn.TextColor3 = self.Theme.Text
            local page = new("Frame", {Parent = self.PageHolder, Size = UDim2.new(1,0,0, 10), BackgroundTransparency = 1, Visible = false})
            local pageLayout = new("UIListLayout", {Parent = page, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder})
            pageLayout.FillDirection = Enum.FillDirection.Vertical

            local tabRec = {
                Name = name,
                Button = btn,
                Page = page,
                Widgets = {},
            }
            -- Bind simple show
            btn.MouseButton1Click:Connect(function()
                if self.CurrentPage and self.CurrentPage ~= page then
                    self.CurrentPage.Visible = false
                end
                page.Visible = true
                self.CurrentPage = page
            end)
            table.insert(self.Tabs, tabRec)
            return tabRec
        end)()
        return tab
    end

    function self:GetTabs()
        return self.Tabs
    end

    function self:Toast(text, dur)
        makeToast(self.ToastParent, text, dur)
    end

    -- Convenience: Add some starter tabs/widgets for the example
    do
        local t1 = self:CreateTab("Main")
        -- create simple widgets using the internal "Add..." functions defined earlier are not accessible through this stubbed CreateTab.
        -- Instead, we directly mimic the earlier API for the example usage: we'll provide a simpler AddToggle/AddButton for these created tabs.
        function t1:AddToggle(label, default, callback)
            local frame = new("Frame", {Parent = t1.Page, Size = UDim2.new(1, -16, 0, 40), BackgroundColor3 = Color3.fromRGB(28,28,32)})
            new("UICorner", {Parent = frame, CornerRadius = UDim.new(0,8)})
            local lbl = new("TextLabel", {Parent = frame, Text = label or "Toggle", Position = UDim2.new(0, 12, 0, 6), Size = UDim2.new(1, -120, 0, 28)})
            styleText(lbl, 14, false)
            lbl.TextColor3 = self.Theme.Text
            local btn = new("TextButton", {Parent = frame, Text = default and "On" or "Off", Size = UDim2.new(0, 84, 0, 28), Position = UDim2.new(1, -96, 0, 6), BackgroundColor3 = default and self.Theme.Accent or Color3.fromRGB(70,70,74)})
            new("UICorner", {Parent = btn, CornerRadius = UDim.new(0,6)})
            btn.TextColor3 = Color3.new(1,1,1)
            local state = default or false
            btn.MouseButton1Click:Connect(function()
                state = not state
                btn.Text = state and "On" or "Off"
                quickTween(btn, {BackgroundColor3 = state and OptionsHub.Theme.Accent or Color3.fromRGB(70,70,74)}, 0.16)
                if callback then pcall(callback, state) end
            end)
            table.insert(t1.Widgets, {type="toggle", label=label, widget=frame})
            return frame
        end
        function t1:AddButton(label, callback)
            local btn = new("TextButton", {Parent = t1.Page, Text = label or "Button", Size = UDim2.new(1, -16, 0, 36), BackgroundColor3 = self.Theme.Accent})
            new("UICorner", {Parent = btn, CornerRadius = UDim.new(0,8)})
            btn.Font = Enum.Font.GothamSemibold
            btn.TextColor3 = Color3.new(1,1,1)
            btn.MouseButton1Click:Connect(function() pcall(callback) end)
            table.insert(t1.Widgets, {type="button", label=label, widget=btn})
            return btn
        end
        function t1:AddSlider(label, min, max, default, cb)
            local frame = new("Frame", {Parent = t1.Page, Size = UDim2.new(1, -16, 0, 56), BackgroundColor3 = Color3.fromRGB(28,28,32)})
            new("UICorner", {Parent = frame, CornerRadius = UDim.new(0,8)})
            local lbl = new("TextLabel", {Parent = frame, Text = label or "Slider", Position = UDim2.new(0, 12, 0, 6), Size = UDim2.new(1, -24, 0, 20)})
            styleText(lbl, 14, false)
            lbl.TextColor3 = self.Theme.Text
            local barBg = new("Frame", {Parent = frame, Size = UDim2.new(1, -36, 0, 14), Position = UDim2.new(0, 12, 0, 30), BackgroundColor3 = Color3.fromRGB(48,48,52)})
            new("UICorner", {Parent = barBg, CornerRadius = UDim.new(0,6)})
            local fill = new("Frame", {Parent = barBg, Size = UDim2.new(((default or min)-min)/(max-min), 0, 1, 0), BackgroundColor3 = self.Theme.Accent})
            new("UICorner", {Parent = fill, CornerRadius = UDim.new(0,6)})
            local dragging = false
            local function updateFromPosition(x)
                local rel = math.clamp((x - barBg.AbsolutePosition.X) / barBg.AbsoluteSize.X, 0, 1)
                fill.Size = UDim2.new(rel, 0, 1, 0)
                local val = min + rel * (max - min)
                if cb then pcall(cb, val) end
            end
            barBg.InputBegan:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.MouseButton1 then
                    dragging = true
                    updateFromPosition(inp.Position.X)
                end
            end)
            UserInputService.InputChanged:Connect(function(inp)
                if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then
                    updateFromPosition(inp.Position.X)
                end
            end)
            UserInputService.InputEnded:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
            end)
            table.insert(t1.Widgets, {type="slider", label=label, widget=frame})
            return frame
        end

        -- fill with example widgets
        t1:AddToggle("Enable A", true, function(v) print("Enable A:", v) end)
        t1:AddSlider("Speed", 0, 100, 32, function(v) print("Speed:", math.floor(v)) end)
        t1:AddButton("Do Action", function() print("Action!") end)

        local t2 = self:CreateTab("Visuals")
        function t2:AddColorPicker(label, default, cb)
            -- copy of earlier small impl
            local frame = new("Frame", {Parent = t2.Page, Size = UDim2.new(1,-16,0,44), BackgroundColor3 = Color3.fromRGB(28,28,32)})
            new("UICorner", {Parent = frame, CornerRadius = UDim.new(0,8)})
            local lbl = new("TextLabel", {Parent = frame, Text = label or "Color", Position = UDim2.new(0,12,0,6), Size = UDim2.new(1, -120, 0, 20)})
            styleText(lbl, 14, false)
            local preview = new("Frame", {Parent = frame, Size = UDim2.new(0,34,0,28), Position = UDim2.new(1, -52, 0, 8), BackgroundColor3 = default or self.Theme.Accent})
            new("UICorner", {Parent = preview, CornerRadius = UDim.new(0,6)})
            local btn = new("TextButton", {Parent = frame, Text = "Edit", Size = UDim2.new(0, 64, 0, 28), Position = UDim2.new(1, -120, 0, 8), BackgroundColor3 = Color3.fromRGB(40,40,44)})
            new("UICorner", {Parent = btn, CornerRadius = UDim.new(0,6)})
            btn.TextColor3 = self.Theme.Text
            btn.MouseButton1Click:Connect(function() -- reuse earlier popup technique
                makeToast(self.ToastParent, "Open color editor (demo)", 1.8)
            end)
            table.insert(t2.Widgets, {type="color", label=label, widget=frame})
            return frame
        end
        t2:AddColorPicker("Accent Color", self.Theme.Accent, function(c) self.Theme.Accent = c end)
        t2:AddButton("Reset Theme", function()
            self.Theme = DEFAULT_THEME
            makeToast(self.ToastParent, "Theme reset", 2)
        end)
    end

    -- Return API
    return self
end

-- Example quick usage (if required by the user, otherwise remove these lines and require the module externally)
--[[
local hub = OptionsHub.new({Name="Vortexor Options", Width=800, Height=520})
hub:Show() -- shows in PlayerGui
hub:Toast("Welcome to OptionsHub!", 3)
]]

return OptionsHub
