-- OptionsLibDataStoreServer.lua
-- Put this in ServerScriptService.
-- It listens for RemoteEvent calls from the client to save/load JSON data per player using DataStoreService.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local SAVE_EVENT_NAME = "OptionsLib_SaveEvent"
local LOAD_RESPONSE_NAME = "OptionsLib_LoadResponse"

local saveEvent = ReplicatedStorage:FindFirstChild(SAVE_EVENT_NAME)
if not saveEvent then
    saveEvent = Instance.new("RemoteEvent")
    saveEvent.Name = SAVE_EVENT_NAME
    saveEvent.Parent = ReplicatedStorage
end

local respEvent = ReplicatedStorage:FindFirstChild(LOAD_RESPONSE_NAME)
if not respEvent then
    respEvent = Instance.new("RemoteEvent")
    respEvent.Name = LOAD_RESPONSE_NAME
    respEvent.Parent = ReplicatedStorage
end

local store = DataStoreService:GetDataStore("OptionsLibPlayerData_v1")

saveEvent.OnServerEvent:Connect(function(player, payload)
    if type(payload) ~= "table" then return end
    local action = payload.Action
    local key = tostring(payload.Key or "default")
    if action == "Save" then
        local ok, err = pcall(function()
            store:SetAsync(player.UserId .. "_" .. key, payload.Data)
        end)
        if not ok then
            warn("[OptionsLib] Failed to save:", err)
        end
    elseif action == "Load" then
        -- load and send back
        local ok, data = pcall(function()
            return store:GetAsync(player.UserId .. "_" .. key)
        end)
        if ok then
            respEvent:FireClient(player, {Key = key, Data = data})
        else
            warn("[OptionsLib] Failed to load for", player.Name, key)
            respEvent:FireClient(player, {Key = key, Data = nil})
        end
    end
end)

-- Optional: autosave on leave for players with saved state
Players.PlayerRemoving:Connect(function(player)
    -- Implement if needed: keep server-side caches, etc.
end)
