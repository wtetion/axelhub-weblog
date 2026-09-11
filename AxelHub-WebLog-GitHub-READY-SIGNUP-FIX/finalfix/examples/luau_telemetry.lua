-- Axel Hub -> Node.js Web Log telemetry example
-- Put your public/reachable server URL in WEBLOG_URL.
-- The Node server expects POST /api/telemetry with x-axel-api-key.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LP = Players.LocalPlayer

local WEBLOG_URL = "http://YOUR_SERVER_IP:3000/api/telemetry"
local WEBLOG_API_KEY = "change-me"

local startedAt = os.clock()
local stolenCount = 0

local function getRequest()
    return (syn and syn.request)
        or (http and http.request)
        or http_request
        or request
end

local function countTable(t)
    if type(t) ~= "table" then return 0 end
    local n = 0
    for _ in pairs(t) do n += 1 end
    return n
end

-- Adapt this part to the game modules already present in Steal.luau.
local function readGameStats()
    local RS = game:GetService("ReplicatedStorage")
    local SaveModule
    pcall(function()
        SaveModule = require(RS.Shared.Save)
    end)

    local save
    if SaveModule and type(SaveModule.Get) == "function" then
        pcall(function() save = SaveModule.Get() end)
    end

    local eggInv = save and save.EggInventory or {}
    local petInv = save and save.Inventory or {}

    return {
        money = tonumber(save and save.Money) or 0,
        eggInventory = countTable(eggInv),
        eggCapacity = 0, -- set from your game's live capacity field if available
        petInventory = countTable(petInv),
        petCapacity = 0,
    }
end

local function getSpeed()
    local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    return hum and tonumber(hum.WalkSpeed) or 0
end

local function sendTelemetry()
    local req = getRequest()
    if type(req) ~= "function" then return false, "request unavailable" end

    local s = readGameStats()
    local eggsPerSecond = 0
    local petsPerSecond = 0

    local payload = {
        account = LP.Name,
        displayName = LP.DisplayName,
        pc = "YOUR_PC_NAME",
        money = s.money,
        speed = getSpeed(),
        petsPerSecond = petsPerSecond,
        eggsPerSecond = eggsPerSecond,
        totalPerSecond = petsPerSecond + eggsPerSecond,
        inventory = {
            eggs = s.eggInventory,
            eggCapacity = s.eggCapacity,
            pets = s.petInventory,
            petCapacity = s.petCapacity,
        },
        eggsStolen = stolenCount,
        petsHatched = 0,
        jobId = game.JobId,
        placeId = game.PlaceId,
        uptimeSeconds = os.clock() - startedAt,
    }

    local body = HttpService:JSONEncode(payload)
    local ok, result = pcall(function()
        return req({
            Url = WEBLOG_URL,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json",
                ["x-axel-api-key"] = WEBLOG_API_KEY,
            },
            Body = body,
        })
    end)

    return ok, result
end

-- Send every 10 seconds.
task.spawn(function()
    while true do
        task.wait(10)
        pcall(sendTelemetry)
    end
end)

-- Call this whenever your existing StealBestEggOnce succeeds.
-- stolenCount += 1
