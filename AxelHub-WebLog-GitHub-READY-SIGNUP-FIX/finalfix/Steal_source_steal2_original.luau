-- Axel Hub bootstrap
-- Prefer a preloaded Oxide library; otherwise fetch the current library.
local LIB_URL = "https://raw.githubusercontent.com/xulfo/OxideUiLibary2/main/UiLibary/Libary.lua"

local function fetchLibrarySource(url)
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if ok and type(body) == "string" and #body > 1000 then
        return body
    end
    return nil
end

local function loadLibrary()
    local existing = rawget(_G, "OxideLib")
    -- Reuse only the library build that includes tab icon support.
    if type(existing) == "table"
        and type(existing.CreateWindow) == "function"
        and tonumber(existing.Version) and tonumber(existing.Version) >= 2.6 then
        return existing
    end

    local source = fetchLibrarySource(LIB_URL)
    if not source then
        local bust = LIB_URL .. "?cb=" .. tostring(os.time())
        source = fetchLibrarySource(bust)
    end
    if type(source) ~= "string" then
        error("[Axel Hub] Failed to fetch Oxide UI library", 0)
    end

    local chunk, err = loadstring(source)
    if type(chunk) ~= "function" then
        error("[Axel Hub] Oxide UI compile error: " .. tostring(err), 0)
    end

    local ok, lib = pcall(chunk)
    if not ok or type(lib) ~= "table" or type(lib.CreateWindow) ~= "function" then
        error("[Axel Hub] Invalid Oxide UI library", 0)
    end
    return lib
end

local Library = loadLibrary()

-- === HUB STRIP POINT - when executed through the hub ScriptLoader, which injects
--     "local Library = _G.OxideLib" above this line instead. ===
-- ==============================================================================

-- ==============================================================================
-- RE-EXECUTION GUARD + RESOURCE TRACKING
-- ==============================================================================
do
    local prev = _G.OxideStealAnEgg
    if prev and type(prev.Unload) == "function" then pcall(prev.Unload) end
end
local HUB = { conns = {}, drawings = {}, highlights = {}, dead = false }
_G.OxideStealAnEgg = HUB
local function track(conn) table.insert(HUB.conns, conn); return conn end
local function trackDrawing(d) if d then table.insert(HUB.drawings, d) end; return d end

-- Axel Hub branding: use the bundled Oxide library with an Axel yellow accent.
pcall(function()
    if type(Library.SetTheme) == "function" then
        Library:SetTheme({
            Accent = Color3.fromRGB(255, 193, 7),
            AccentDim = Color3.fromRGB(74, 58, 8),
            AccentText = Color3.fromRGB(20, 20, 20),
            KnobAccent = Color3.fromRGB(255, 193, 7),
        })
    end
end)

local Window = Library:CreateWindow({
    Logo = "rbxassetid://86949082023913",
    LogoZoom = 1.15,
    GuiName = "AxelHub",
    ReplaceExisting = true,

    Name = "Axel Hub | Steal an Egg",
    BrandSubtitle = "Made by secret agent",
    StatusText = "Axel is ready",
    LoadingAnimation = false,
    LoadingText = "Axel Hub",
    LoadingDuration = 0.0,
})

-- ==============================================================================
-- CONFIG / FLAG PERSISTENCE
-- ==============================================================================
local HAS_CONFIG = type(Library.SaveConfig) == "function"
    and type(Library.LoadConfig) == "function"
    and type(Library.ListConfigs) == "function"
local CONFIG_NAME = "stealanegg"

local dropdownResync = {}
local function registerResync(handle, applyFn)
    if handle and applyFn then
        table.insert(dropdownResync, function() applyFn(handle:Get()) end)
    end
end
local function ResyncAll()
    for _, fn in ipairs(dropdownResync) do pcall(fn) end
end

-- ==============================================================================
-- SERVICES & LOCALS
-- ==============================================================================
local Players             = game:GetService("Players")
local RS                  = game:GetService("ReplicatedStorage")
local ReplicatedStorage   = RS
local RunService          = game:GetService("RunService")
local UserInputService    = game:GetService("UserInputService")
local Workspace           = game:GetService("Workspace")
local Lighting            = game:GetService("Lighting")
local TeleportService     = game:GetService("TeleportService")
local VirtualUser         = game:GetService("VirtualUser")

local LP          = Players.LocalPlayer
local LocalPlayer = LP
local function GetCamera()
    return Workspace.CurrentCamera or Workspace:FindFirstChildOfClass("Camera")
end


-- Anti-Robux Purchase Prompt Shield: immediately dismisses accidental Robux purchase prompts
pcall(function()
    local coreGui = game:GetService("CoreGui")
    track(coreGui.ChildAdded:Connect(function(child)
        if child.Name == "PurchasePrompt" then
            task.wait(0.04)
            pcall(function()
                local cancel = child:FindFirstChild("CancelButton", true)
                if cancel and typeof(cancel) == "Instance" and cancel:IsA("GuiButton") then
                    pcall(function() cancel:Activate() end)
                end
            end)
        end
    end))
end)

local function Notify(title, content, kind, dur)
    pcall(function()
        Window:Notify({ Title = title, Content = content, Type = kind or "Info", Duration = dur or 2.5 })
    end)
end

local function safeCallback(fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then
            pcall(Notify, "Oxide HUB", "Error: " .. tostring(err), "Error", 4)
        end
    end
end

-- ==============================================================================
-- CLIENT AC NEUTRALIZER & UGI CONSTANT WIPER (Layer 1 + Layer 2)
-- ==============================================================================
local function bypassClientDetections()
    if typeof(filtergc) ~= "function" or typeof(debug) ~= "table" or typeof(debug.getupvalues) ~= "function" then
        return false, "no filtergc"
    end
    local ok, fn = pcall(function()
        return filtergc("function", {
            Constants = { "gmatch", "GetFullName" },
        }, true)
    end)
    if not ok or type(fn) ~= "function" then
        return false, "filter miss"
    end
    local setMeta = (typeof(setrawmetatable) == "function" and setrawmetatable)
        or (typeof(setmetatable) == "function" and setmetatable)
    if not setMeta then
        return false, "no setmeta"
    end
    local blocked = 0
    local okUv, ups = pcall(debug.getupvalues, fn)
    if not okUv or type(ups) ~= "table" then
        return false, "no upvalues"
    end
    for _, tbl in pairs(ups) do
        if typeof(tbl) == "table" then
            local okSet = pcall(setMeta, tbl, {
                __newindex = function() end,
            })
            if okSet then
                blocked = blocked + 1
            end
        end
    end
    return blocked > 0, blocked
end

pcall(bypassClientDetections)

-- Runtime AC Detection Table Freezer (Neutralizes violation storage)
pcall(function()
    local getgc = getgc or (debug and debug.getgc)
    local setmeta = setrawmetatable or setmetatable
    local getmeta = getrawmetatable or getmetatable

    if getgc and setmeta then
        for _, obj in ipairs(getgc(true)) do
            if typeof(obj) == "table" and not (getmeta and getmeta(obj)) then
                local mainrun = false
                for _, v in pairs(obj) do
                    if v == obj then
                        mainrun = true
                        break
                    end
                end
                if mainrun then
                    for _, v in pairs(obj) do
                        if typeof(v) == "number" and v >= 1 and v <= 3 and obj[v] == nil then
                            pcall(setmeta, obj, { __newindex = function() end })
                            break
                        end
                    end
                end
            end
        end
    end
end)

-- UGI Constant Wiper (neutralizes ReplicatedFirst.UGI watchdog)
pcall(function()
    local getconstants = getconstants or (debug and debug.getconstants)
    local setconstant = setconstant or (debug and debug.setconstant)
    local islclosure = islclosure or function(Function)
        return not pcall(setfenv, getfenv(Function))
    end

    if getgc and getconstants and setconstant then
        for _, Function in ipairs(getgc(true)) do
            if typeof(Function) == "function" and islclosure(Function) then
                local ok, Source = pcall(debug.info, Function, "s")
                if ok and type(Source) == "string" and Source:find("ReplicatedFirst", 1, true) and Source:find("UGI", 1, true) then
                    local okC, Constants = pcall(getconstants, Function)
                    if okC and type(Constants) == "table" then
                        for Index, Constant in next, Constants do
                            if type(Constant) == "string" and Constant == "Humanoid" then
                                pcall(setconstant, Function, Index, "")
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- Secondary Layer: X-14 Stack Scrubber & Token Neutralizer
pcall(function()
    local getconstants = getconstants or (debug and debug.getconstants)
    local islclosure = islclosure or function(fn) return not pcall(setfenv, getfenv(fn)) end
    local HookFn = hookfunction or replaceclosure or hookfunc
    if getgc and getconstants and HookFn and debug and debug.getstack and debug.setstack then
        for _, fn in ipairs(getgc(true)) do
            if typeof(fn) == "function" and islclosure(fn) then
                local ok, consts = pcall(getconstants, fn)
                if ok and type(consts) == "table" and table.find(consts, "X-14") then
                    local cb = nil
                    cb = HookFn(fn, function(...)
                        local stack = debug.getstack(1)
                        if type(stack) == "table" then
                            for idx, val in pairs(stack) do
                                if val == "X-14" then
                                    pcall(debug.setstack, 1, idx, nil)
                                end
                            end
                        end
                        if cb then return cb(...) end
                    end)
                end
            end
        end
    end
end)

-- Layer 3: Anti-Tamper State Table Sanitizer (19-upvalue detection neutralization)
pcall(function()
    local getgc = getgc or (debug and debug.getgc)
    local islclosure = islclosure or function(v) return not pcall(setfenv, getfenv(v)) end
    local getupvalues = getupvalues or (debug and debug.getupvalues)
    local getupvalue = getupvalue or (debug and debug.getupvalue)
    local setupvalue = setupvalue or (debug and debug.setupvalue)
    local clonefunction = clonefunction or function(f) return function(...) return f(...) end end

    if getgc and getupvalues and getupvalue and setupvalue then
        for _, v in ipairs(getgc(true)) do
            if typeof(v) == "function" and islclosure(v) then
                local ok, upvs = pcall(getupvalues, v)
                if ok and upvs and #upvs == 19 then
                    local ok2, u2 = pcall(getupvalue, v, 2)
                    if ok2 and typeof(u2) == "function" then
                        local old = clonefunction(u2)
                        pcall(setupvalue, v, 2, function(a, b)
                            if b and typeof(b) == "table" then
                                pcall(setmetatable, b, {})
                            end
                            return old(a, b)
                        end)
                    end
                end
            end
        end
    end
end)

-- ==============================================================================
-- CHARACTER & MOVEMENT HELPERS
-- ==============================================================================
local function findChar() return LP.Character end
local function findHum()
    local ch = LP.Character
    return ch and ch:FindFirstChildOfClass("Humanoid")
end
local function findHRP()
    local ch = LP.Character
    return ch and (ch:FindFirstChild("HumanoidRootPart") or ch.PrimaryPart or ch:FindFirstChildWhichIsA("BasePart"))
end

local GetCharacter = findChar
local GetHumanoid  = findHum
local GetHRP       = findHRP

local function GetRootCFrame()
    local hrp = findHRP()
    return hrp and hrp.CFrame
end

-- ==============================================================================
-- BAC TELEMETRY PACKET SPOOFER
-- ==============================================================================
local bxor = bit32.bxor
local unpack = table.unpack

local function isGuid(n)
    return #n==36 and n:sub(9,9)=="-" and n:sub(14,14)=="-" and n:sub(19,19)=="-" and n:sub(24,24)=="-" and n:gsub("-",""):match("^%x+$")~=nil
end

local remoteSet, anyRemote = {}, nil

local function scanRemotes()
    for _, s in ipairs(game:GetChildren()) do
        local ok, list = pcall(s.GetDescendants, s)
        if ok and list then
            for _, o in ipairs(list) do
                if o:IsA("RemoteEvent") and isGuid(o.Name) then
                    remoteSet[o] = true
                    anyRemote = anyRemote or o
                end
            end
        end
    end
end

scanRemotes()

local function parseCounter(v)
    if type(v) ~= "string" then return end
    local n = v:match("^X%-(%d+)$")
    return n and tonumber(n)
end

local function looksLikeState(t, r)
    if type(t) ~= "table" then return false end
    local hR, hM = false, false
    local ok = pcall(function()
        for _, v in pairs(t) do
            if v == r then hR = true
            elseif type(v) == "string" and v:match("^X%-%d+$") then hM = true end
        end
    end)
    return ok and hR and hM
end

local function findState(r)
    for l=2,24 do
        local _, fn = pcall(debug.info, l, "f")
        if type(fn) == "function" then
            local _, ups = pcall(debug.getupvalues, fn)
            if type(ups) == "table" then
                for _, v in pairs(ups) do
                    if looksLikeState(v, r) then return v end
                    if type(v) == "table" then
                        local nested
                        pcall(function()
                            for _, x in pairs(v) do
                                if looksLikeState(x, r) then nested = x; return end
                            end
                        end)
                        if nested then return nested end
                    end
                end
            end
        end
    end
end

local function mapState(st, a1, a2)
    local m = {}
    for k, v in pairs(st) do
        if type(v) == "string" then
            if v:match("^X%-%d+$") then m.marker = m.marker or k
            elseif a1 and v == a1 then m.arg1 = m.arg1 or k
            elseif a2 and v == a2 then m.arg2 = m.arg2 or k end
        end
    end
    return m
end

local model = nil

local function digits(n)
    n = n % 1000
    return math.floor(n/100), math.floor(n/10)%10, n%10
end

local function encode(m, c)
    local d1, d2, d3 = digits(c)
    return m.prefix .. string.char(bxor(d1, m.k1), bxor(d2, m.k2), bxor(d3, m.k3))
end

local function learn(r, a1, a2)
    local st = findState(r)
    if not st then return end
    local map = mapState(st, a1, a2)
    if not map.marker then return end
    local c = parseCounter(rawget(st, map.marker))
    if not c then return end
    local d1, d2, d3 = digits(c)
    local m = {
        state = st, map = map, remote = r,
        prefix = a1:sub(1, 9),
        k1 = bxor(a1:byte(10), d1),
        k2 = bxor(a1:byte(11), d2),
        k3 = bxor(a1:byte(12), d3),
        offset = c - os.time(),
        arg2 = a2
    }
    if encode(m, c) == a1 then return m end
end

local function liveCounter(m)
    if m.state and m.map.marker then
        local _, raw = pcall(rawget, m.state, m.map.marker)
        local c = parseCounter(raw)
        if c and math.abs((c - os.time()) - m.offset) <= 5 then
            return c
        end
    end
    return os.time() + m.offset
end

local function refreshArg2(m)
    if m.state and m.map.arg2 then
        local _, v = pcall(rawget, m.state, m.map.arg2)
        if type(v) == "string" then m.arg2 = v end
    end
    return m.arg2
end

local HookFn = hookfunction or replaceclosure or hookfunc or detour_function

if anyRemote and HookFn then
    local oldFire
    oldFire = HookFn(anyRemote.FireServer, function(self, ...)
        local args = table.pack(...)
        if not remoteSet[self] then
            return oldFire(self, unpack(args, 1, args.n))
        end

        local a1 = args[1]

        if type(a1) == "string" and #a1 == 12 then
            if not model then
                model = learn(self, a1, args[2])
            else
                local c = parseCounter(rawget(model.state, model.map.marker))
                if c and encode(model, c) ~= a1 then
                    local m = learn(self, a1, args[2])
                    if m then m.spoofed = model.spoofed; model = m end
                end
            end
            return oldFire(self, unpack(args, 1, args.n))
        end

        if model and type(a1) == "string" and #a1 == 4 then
            local c = liveCounter(model)
            args[1] = encode(model, c)
            args[2] = refreshArg2(model)
            model.spoofed = (model.spoofed or 0) + 1
            return oldFire(self, unpack(args, 1, math.max(args.n, 2)))
        end

        return oldFire(self, unpack(args, 1, args.n))
    end)
end

task.spawn(function()
    while not HUB.dead do
        task.wait(10)
        local alive = false
        for r in pairs(remoteSet) do
            if r:IsDescendantOf(game) then alive = true; break end
        end
        if not alive then
            table.clear(remoteSet)
            anyRemote = nil
            model = nil
            scanRemotes()
        end
    end
end)

-- Real-time Memory Evidence Scrubber for Character Integrity
task.spawn(function()
    if not getgc then return end
    local st = nil

    local function findIntegrityTable()
        local ok, objs = pcall(getgc, true)
        if ok and objs then
            for _, o in pairs(objs) do
                if type(o) == "table" then
                    local hit = false
                    pcall(function()
                        hit = (rawget(o, "ValidationLocked") ~= nil and rawget(o, "Evidence") ~= nil)
                            or (rawget(o, "ThreatLevel") ~= nil and rawget(o, "LastObservedSample") ~= nil)
                    end)
                    if hit then return o end
                end
            end
        end
        return nil
    end

    track(LP.CharacterAdded:Connect(function()
        task.wait(1)
        st = findIntegrityTable()
    end))

    while not HUB.dead do
        if not st then
            st = findIntegrityTable()
        end

        if st then
            pcall(function()
                local ev = rawget(st, "Evidence")
                if type(ev) == "table" then
                    if (tonumber(ev.Speed)    or 0) > 0 then rawset(ev, "Speed", 0) end
                    if (tonumber(ev.Teleport) or 0) > 0 then rawset(ev, "Teleport", 0) end
                    if (tonumber(ev.Flight)   or 0) > 0 then rawset(ev, "Flight", 0) end
                end
                if rawget(st, "ThreatLevel") ~= "Trusted" then rawset(st, "ThreatLevel", "Trusted") end
                if rawget(st, "ValidationLocked") == true then rawset(st, "ValidationLocked", false) end
                if rawget(st, "FirstSuspiciousAt") ~= nil then rawset(st, "FirstSuspiciousAt", nil) end
                if rawget(st, "KickQueued") == true then rawset(st, "KickQueued", false) end
                if rawget(st, "TamperScore") ~= nil then rawset(st, "TamperScore", 0) end
                if rawget(st, "InvalidHeartbeatCount") ~= nil then rawset(st, "InvalidHeartbeatCount", 0) end

                local los = rawget(st, "LastObservedSample")
                if los ~= nil then
                    if rawget(st, "LastGameplayTrustedSample") == nil then rawset(st, "LastGameplayTrustedSample", los) end
                    if rawget(st, "LastValidatedSample") == nil then rawset(st, "LastValidatedSample", los) end
                    if rawget(st, "LastValidatedGroundedSample") == nil then rawset(st, "LastValidatedGroundedSample", los) end
                    if rawget(st, "LastConfirmedGroundSample") == nil then rawset(st, "LastConfirmedGroundSample", los) end
                    if rawget(st, "LastGoodSample") == nil then rawset(st, "LastGoodSample", los) end
                end
            end)
        end
        task.wait(0.2)
    end
end)

-- ==============================================================================
-- GAME NETWORKING & MODULE INTEGRATION
-- ==============================================================================
local EggState, PlotState, AreasData, RarityData, AssetsData, EggToolDisplay, AreaEggSlotIdentity
pcall(function() EggState = require(RS.Client.EggState) end)
pcall(function() PlotState = require(RS.Client.PlotState) end)
pcall(function() AreasData = require(RS.Data.Areas) end)
pcall(function() RarityData = require(RS.Data.Rarity) end)
pcall(function() AssetsData = require(RS.Data.Assets) end)
local SaveModule
pcall(function() SaveModule = require(RS.Shared.Save) end)
pcall(function() EggToolDisplay = require(RS.Shared.Eggs.EggToolDisplay) end)
pcall(function()
    AreaEggSlotIdentity = (RS:FindFirstChild("Shared") and RS.Shared:FindFirstChild("Util") and require(RS.Shared.Util.AreaEggSlotIdentity))
        or (RS:FindFirstChild("Util") and require(RS.Util.AreaEggSlotIdentity))
        or (RS:FindFirstChild("Shared") and RS.Shared:FindFirstChild("Utils") and require(RS.Shared.Utils.AreaEggSlotIdentity))
end)

local function GetNetRemote(name)
    local net = RS:FindFirstChild("Packages") and RS.Packages:FindFirstChild("Networking")
    return net and net:FindFirstChild(name)
end

local function GetLocalSlot()
    if PlotState and PlotState.ResolveLocalSlot then
        local ok, slot = pcall(PlotState.ResolveLocalSlot)
        if ok and slot then return slot end
    end
    return 1
end

local function GetLocalPlotCenter()
    local plotObj = PlotState and PlotState.ResolvePlot and PlotState.ResolvePlot()
    local pt = plotObj and plotObj.CenterPoint and (typeof(plotObj.CenterPoint) == "Vector3" and plotObj.CenterPoint or (plotObj.CenterPoint:IsA("BasePart") and plotObj.CenterPoint.Position))
    if pt then
        return Vector3.new(pt.X, math.max(pt.Y, 70.4), pt.Z), CFrame.new(pt.X, math.max(pt.Y, 70.4), pt.Z)
    end
    return Vector3.new(464.7, 70.4, -364.0), CFrame.new(464.7, 70.4, -364.0)
end

-- ==============================================================================
-- CLEAN ROAD & FLIGHT PATH NAVIGATION (Anti-Trap & Zero Kick Engine)
-- ==============================================================================
local MAIN_ROAD_Z = -364.5

local stealMovementMethod    = "Tween Glide" -- "Tween Glide", "Fly Glide", "Safe Walk"
local avoidTrapsEnabled       = true
local autoClaimMonsterChests  = false
local autoFeedMonster         = false





local function restoreCollisions()
    local char = LP.Character
    if not char or not char.Parent then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            part.CanCollide = true
        end
    end
end


local function NeutralizeTraps()
    local debris = Workspace:FindFirstChild("__DEBRIS")
    if not debris then return end
    for _, d in ipairs(debris:GetChildren()) do
        if d.Name == "PlayerTrap" and d:GetAttribute("Owner") ~= LP.Name then
            if d:IsA("BasePart") then
                d.CanTouch = false
                d.CanQuery = false
            end
            for _, c in ipairs(d:GetChildren()) do
                if c:IsA("BasePart") then
                    c.CanTouch = false
                    c.CanQuery = false
                    if c.Name == "Hitbox" then
                        c.CFrame = CFrame.new(0, -999, 0)
                    end
                end
            end
            local tt = d:FindFirstChildWhichIsA("TouchTransmitter", true)
            if tt then pcall(function() tt:Destroy() end) end
        end
    end
end

local function MoveToPoint(target, speed, easeOut)
    local hrp = findHRP()
    if not hrp or not target then return false end

    local start = hrp.Position
    local dist = (target - start).Magnitude
    if dist < 1.0 then
        hrp.CFrame = CFrame.new(target.X, math.max(target.Y, 70.0), target.Z)
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        return true
    end

    speed = math.clamp(tonumber(speed) or tonumber(glideSpeed) or 750, 50, 750)

    local t0 = os.clock()
    local totalDist = dist
    while not HUB.dead do
        local dt = RunService.Heartbeat:Wait()
        local curPos = hrp.Position
        local toTarget = target - curPos
        local remain = toTarget.Magnitude
        if remain < 1.0 then break end
        local stepSpeed = speed
        if easeOut then
            local progress = 1 - math.clamp(remain / totalDist, 0, 1)
            stepSpeed = math.max(speed * (1 - progress * 0.8), 35)
        end
        local step = math.min(stepSpeed * dt, remain)
        local dir = toTarget.Unit
        local nextPos = curPos + dir * step
        hrp.CFrame = CFrame.lookAt(nextPos, nextPos + dir)
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        if os.clock() - t0 > (totalDist / 50 + 5) then break end
    end

    hrp.CFrame = CFrame.new(target.X, math.max(target.Y, 70.0), target.Z)
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    return true
end

local function FlyToPoint(target, speed, easeOut)
    local hrp = findHRP()
    if not hrp or not target then return false end
    local start = hrp.Position
    local dist = (target - start).Magnitude
    if dist < 1.0 then
        hrp.CFrame = CFrame.new(target.X, math.max(target.Y, 70.0), target.Z)
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
        return true
    end

    speed = math.clamp(tonumber(speed) or tonumber(glideSpeed) or 750, 50, 750)
    local moveTime = math.max(dist / speed, 0.02)
    if easeOut then
        moveTime = moveTime * 1.25
    end

    local t0 = os.clock()
    local delta = target - start
    local dir = delta.Magnitude > 0.001 and delta.Unit or Vector3.new(1, 0, 0)

    while os.clock() - t0 < moveTime and not HUB.dead do
        local dt = RunService.Heartbeat:Wait()
        local linearAlpha = math.clamp((os.clock() - t0) / moveTime, 0, 1)

        local a = linearAlpha
        if easeOut then
            a = math.sin(linearAlpha * (math.pi / 2))
        end

        local cur = start:Lerp(target, a)
        hrp.CFrame = CFrame.lookAt(cur, cur + dir)

        local curSpeed = speed
        if easeOut then
            curSpeed = math.max(speed * (1 - linearAlpha * 0.8), 35)
        end
        hrp.AssemblyLinearVelocity = Vector3.new(dir.X * curSpeed, math.clamp(dir.Y * curSpeed, -15, 150), dir.Z * curSpeed)
        hrp.AssemblyAngularVelocity = Vector3.zero
    end

    hrp.CFrame = CFrame.new(target.X, math.max(target.Y, 70.0), target.Z)
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero
    return true
end

local SAFE_BOUNDARY_X = 580 -- right before entering the safe zone
local SAFE_ZONE_SPEED = 245 -- 245 studs/s safe entry speed

local function TravelRoadPath(targetPos, speed, isApproach)
    local hrp = findHRP()
    if not hrp or not targetPos then return false end
    if avoidTrapsEnabled then pcall(NeutralizeTraps) end

    local startPos = hrp.Position
    local safeY = math.max(startPos.Y, targetPos.Y, 70.4)
    local isReturningToBase = (targetPos.X < 560)

    if isReturningToBase and startPos.X > SAFE_BOUNDARY_X then
        -- 1. Sprint to main road at full speed (750 studs/s)
        local p1 = Vector3.new(startPos.X, safeY, MAIN_ROAD_Z)
        MoveToPoint(p1, speed, false)

        -- 2. Sprint along main road at full speed until 20 studs BEFORE safe zone
        local pSafeApproach = Vector3.new(SAFE_BOUNDARY_X, safeY, MAIN_ROAD_Z)
        MoveToPoint(pSafeApproach, speed, false)

        -- 3. Slow down to 245 studs/s before entering the safe zone
        local pBaseRoad = Vector3.new(targetPos.X, safeY, MAIN_ROAD_Z)
        MoveToPoint(pBaseRoad, SAFE_ZONE_SPEED, false)

        -- 4. Enter base pen at 245 studs/s
        local pPen = targetPos + Vector3.new(0, 1.2, 0)
        MoveToPoint(pPen, SAFE_ZONE_SPEED, isApproach == true)
        return true
    else
        local p1 = Vector3.new(startPos.X, safeY, MAIN_ROAD_Z)
        local p2 = Vector3.new(targetPos.X, safeY, MAIN_ROAD_Z)
        local p3 = targetPos + Vector3.new(0, 1.2, 0)

        MoveToPoint(p1, speed, false)
        MoveToPoint(p2, speed, false)
        MoveToPoint(p3, speed, isApproach == true)
        return true
    end
end

local function TravelFlyDirect(targetPos, speed, isApproach)
    local hrp = findHRP()
    if not hrp or not targetPos then return false end
    if avoidTrapsEnabled then pcall(NeutralizeTraps) end

    local startPos = hrp.Position
    local isReturningToBase = (targetPos.X < 560)
    local flyAltitude = math.max(startPos.Y, targetPos.Y, 70.4) + 28

    if isReturningToBase and startPos.X > SAFE_BOUNDARY_X then
        -- Fly at full speed (750 studs/s) until right before safe zone
        local pSky1 = Vector3.new(startPos.X, flyAltitude, startPos.Z)
        local pSkySafe = Vector3.new(SAFE_BOUNDARY_X, flyAltitude, MAIN_ROAD_Z)
        FlyToPoint(pSky1, speed, false)
        FlyToPoint(pSkySafe, speed, false)

        -- Descend and slow down to 245 studs/s before entering safe zone
        local pGroundSafe = Vector3.new(SAFE_BOUNDARY_X, 70.4, MAIN_ROAD_Z)
        FlyToPoint(pGroundSafe, SAFE_ZONE_SPEED, false)

        local pBaseRoad = Vector3.new(targetPos.X, 70.4, MAIN_ROAD_Z)
        MoveToPoint(pBaseRoad, SAFE_ZONE_SPEED, false)

        local pPen = targetPos + Vector3.new(0, 1.2, 0)
        MoveToPoint(pPen, SAFE_ZONE_SPEED, isApproach == true)
        return true
    else
        local totalDist = (targetPos - startPos).Magnitude
        if totalDist < 25 then
            FlyToPoint(Vector3.new(targetPos.X, math.max(targetPos.Y, 70.0) + 1.2, targetPos.Z), speed, isApproach == true)
            return true
        end

        local pSky1 = Vector3.new(startPos.X, flyAltitude, startPos.Z)
        local pSky2 = Vector3.new(targetPos.X, flyAltitude, targetPos.Z)
        local pGround = Vector3.new(targetPos.X, math.max(targetPos.Y, 70.0) + 1.2, targetPos.Z)

        FlyToPoint(pSky1, speed, false)
        FlyToPoint(pSky2, speed, false)
        FlyToPoint(pGround, speed, isApproach == true)
        return true
    end
end

local function TravelSafeWalk(targetPos)
    local hum = findHum()
    local hrp = findHRP()
    if not hum or not hrp or not targetPos then return false end
    if avoidTrapsEnabled then pcall(NeutralizeTraps) end

    local startPos = hrp.Position
    local p1 = Vector3.new(startPos.X, startPos.Y, MAIN_ROAD_Z)
    local p2 = Vector3.new(targetPos.X, targetPos.Y, MAIN_ROAD_Z)
    local p3 = targetPos + Vector3.new(0, 1.2, 0)

    for _, pt in ipairs({ p1, p2, p3 }) do
        if HUB.dead then break end
        hum:MoveTo(pt)
        local t0 = os.clock()
        while (hrp.Position - pt).Magnitude > 4.5 and os.clock() - t0 < 5 and not HUB.dead do
            task.wait(0.05)
        end
    end
    return true
end

local function TravelToDestination(targetPos, speed, isApproach)
    if stealMovementMethod == "Fly Glide" then
        return TravelFlyDirect(targetPos, speed, isApproach)
    elseif stealMovementMethod == "Safe Walk" then
        return TravelSafeWalk(targetPos)
    else
        -- Tween Glide smoothly travels to the egg via road
        return TravelRoadPath(targetPos, speed, isApproach)
    end
end

-- ==============================================================================
-- RARITY & AREA DICTIONARIES (Dynamic scoring for Rare Egg Hunter)
-- ==============================================================================
local RARITY_SCORE_MAP = {
    ["Titan"]           = 1100,
    ["Divine"]          = 1000,
    ["Transcendent"]    = 1000,
    ["Superior"]        = 1000,
    ["Eternal"]         = 900,
    ["Limited"]         = 900,
    ["Secret"]          = 800,
    ["Exotic"]          = 800,
    ["Cosmic"]          = 700,
    ["Exclusive"]       = 700,
    ["Admin"]           = 700,
    ["Mythic"]          = 600,
    ["Mythical"]        = 600,
    ["Prismatic"]       = 600,
    ["Rainbow"]         = 600,
    ["Squishy God"]     = 600,
    ["BrainrotGod"]     = 600,
    ["Legendary"]       = 500,
    ["Epic"]            = 400,
    ["Rare"]            = 300,
    ["SuperRare"]       = 200,
    ["Celestial"]       = 200,
    ["Uncommon"]        = 200,
    ["Basic"]           = 100,
    ["Common"]          = 100,
}

local AREA_COORDINATES = {
    ["Base / Plot"]      = Vector3.new(491.7, 70.4, -364.4),
    ["Stands & Shops"]   = Vector3.new(539.5, 68.0, -364.5),
    ["Forest"]           = Vector3.new(596.0, 68.0, -328.0),
    ["Lake"]             = Vector3.new(744.0, 68.5, -408.0),
    ["Desert"]           = Vector3.new(948.0, 69.5, -323.0),
    ["Jungle"]           = Vector3.new(1188.0, 68.5, -408.0),
    ["Snow"]             = Vector3.new(1492.0, 69.0, -315.0),
    ["Volcano"]          = Vector3.new(1882.0, 68.0, -398.0),
    ["Abyss Ocean"]      = Vector3.new(2280.0, 68.0, -326.0),
    ["Prehistoric"]      = Vector3.new(2812.0, 69.0, -398.0),
    ["Cosmic"]           = Vector3.new(3390.0, 68.0, -324.0),
    ["Cherry Blossom"]   = Vector3.new(4028.0, 68.5, -396.0),
    ["Titan Temple"]     = Vector3.new(4796.0, 69.5, -328.0),
    ["Monster Event"]    = Vector3.new(539.5, 68.0, -411.3),
    ["Dragon Event"]     = Vector3.new(539.5, 68.0, -318.0),
}

local AREA_NAMES = {
    "Forest", "Lake", "Desert", "Jungle", "Snow", "Volcano",
    "Abyss Ocean", "Prehistoric", "Cosmic", "Cherry Blossom", "Titan Temple",
    "Monster Event", "Dragon Event"
}

local RARITY_NAMES = {
    "Titan", "Divine", "Superior", "Eternal", "Limited",
    "Secret", "Exotic", "Cosmic", "Exclusive", "Mythic", "Rainbow",
    "Squishy God", "Legendary", "Epic", "Rare", "Uncommon", "Common"
}

local MUTATION_FILTERS = {
    "Normal Only", "Mutated Only", "Parasite / Infested", "Rainbow Only", "Gold Only", "Silver Only", "Monstrous"
}

-- ==============================================================================
-- AUTOMATION STATE & PERSISTENT RETURN POSITION
-- ==============================================================================
local autoStealEnabled          = false
local rareEggHunter             = true
local stealParasiteOnly         = false
local stealBigEggsOnly          = false
local selectedStealRarities     = {}
local selectedStealAreas        = {}
local selectedMutationTypes     = {}
local stealDelay                = 1.5
local glideSpeed                = 750
local ignoredEggs               = {} -- [uid] = timestamp (prevents loops on failed eggs)

-- Auto Treadmill handoff state: train only while there is no matching egg.
local autoTreadmillEnabled      = false
local treadmillTrainingActive   = false
local treadmillHandoffBusy      = false
local treadmillLastNoMatchAt    = 0

-- Saved Return Position (automatically captured on first steal activation)
local savedReturnCFrame         = nil

local autoHatchEnabled          = false
local autoPlantEnabled          = false
local hatchCheckDelay           = 2.0

local autoUpgradeBase           = false
local autoUpgradeTreadmill      = false
local autoTrainSpeed            = false
local autoBuyTrails             = false
local autoEquipBestPets         = false
local autoClaimRewards          = false

local autoSellPets              = false
local autoSellEggs              = false
local selectedSellPetRarities   = {}
local selectedSellEggRarities   = {}

-- When no rarity filter is picked, only sell low-tier items (the default list
-- from the working satchel seller) instead of everything in the inventory.
local DEFAULT_LOW_TIER_SELL = {
    ["Common"] = true, ["Uncommon"] = true, ["Rare"] = true,
    ["Epic"] = true, ["Legendary"] = true, ["Mythic"] = true,
}
local SELL_REQUEST_DELAY = 0.1
local function getSellRarityFilter(selected)
    if not selected or next(selected) == nil then return DEFAULT_LOW_TIER_SELL end
    return selected
end

local noKnockbackEnabled        = true
local batAuraEnabled            = false
local batAuraRadius             = 20
local batAuraDelay              = 0.2
local antiRagdollEnabled        = true

-- ==============================================================================
-- EGG STEALING, PLANTING & HATCHING CORE LOGIC (Strict Rarity Matching)
-- ==============================================================================
local function GetEggRarityInfo(egg)
    if not egg then return "Common", 100 end

    -- 1. Direct rarity property on egg
    if egg.Rarity then
        local r = egg.Rarity
        local name = type(r) == "table" and (r.DisplayName or r._id or r.Name) or tostring(r)
        local score = RARITY_SCORE_MAP[name] or (type(r) == "table" and tonumber(r.RarityNumber) and r.RarityNumber * 100) or 100
        return name, score
    end

    -- 2. Individual Animal / Egg Rarity from Assets Catalog (AssetCategory)
    local cat = egg.AssetCategory or egg.Category or egg.Name
    if cat and AssetsData then
        local assetsDir = AssetsData.Directory or AssetsData
        local aInfo = assetsDir[cat]
        if aInfo and aInfo.Rarity then
            local r = aInfo.Rarity
            local name = type(r) == "table" and (r.DisplayName or r._id or r.Name) or tostring(r)
            local score = RARITY_SCORE_MAP[name] or (type(r) == "table" and tonumber(r.RarityNumber) and r.RarityNumber * 100) or 100
            return name, score
        end
    end

    -- 3. Fallback to Area mapping if asset category wasn't found in catalog
    local areaData = AreasData and (AreasData.Directory or AreasData) and (AreasData.Directory or AreasData)[egg.AreaId]
    local rarity = areaData and areaData.Rarity
    local rarityId = (type(rarity) == "table" and (rarity._id or rarity.DisplayName or rarity.Name)) or (type(rarity) == "string" and rarity) or "Common"
    local raritiesTable = RarityData and (RarityData.Rarities or RarityData) or {}
    local rInfo = raritiesTable[rarityId] or {}
    local rarityDisplayName = (type(rInfo) == "table" and (rInfo.DisplayName or rInfo._id)) or (type(rarity) == "table" and rarity.DisplayName) or rarityId or "Common"
    local baseScore = RARITY_SCORE_MAP[rarityDisplayName] or RARITY_SCORE_MAP[rarityId] or (type(rarity) == "table" and tonumber(rarity.RarityNumber) and rarity.RarityNumber * 100) or 100
    return rarityDisplayName, baseScore
end

local function isRarityAllowed(rarityName, filter)
    if not filter or type(filter) ~= "table" then return true end
    local count = 0
    for _ in pairs(filter) do count = count + 1 end
    if count == 0 then return true end

    if filter[rarityName] == true then return true end
    local rLower = string.lower(tostring(rarityName))
    for k, v in pairs(filter) do
        if type(v) == "string" and string.lower(v) == rLower then
            return true
        elseif type(k) == "string" and string.lower(k) == rLower and v == true then
            return true
        end
    end
    return false
end

local function isAreaAllowed(areaId, filter)
    if not filter or type(filter) ~= "table" then return true end
    local count = 0
    for _ in pairs(filter) do count = count + 1 end
    if count == 0 then return true end

    if filter[areaId] == true then return true end
    local aLower = string.lower(tostring(areaId))
    for k, v in pairs(filter) do
        if type(v) == "string" and string.lower(v) == aLower then
            return true
        elseif type(k) == "string" and string.lower(k) == aLower and v == true then
            return true
        end
    end
    return false
end

local function isMutationAllowed(muts, record, filter)
    local isParasite = (record and record.HasParasite == true)
        or (type(muts) == "table" and (table.find(muts, "Parasite") or table.find(muts, "Monstrous")))
        or (record and (record.BaseMutation == "Parasite" or record.BaseMutation == "Monstrous"))

    if stealParasiteOnly and not isParasite then
        return false
    end

    if not filter or type(filter) ~= "table" then return true end
    local count = 0
    for _ in pairs(filter) do count = count + 1 end
    if count == 0 then return true end

    local hasMut = type(muts) == "table" and #muts > 0
    local allowed = false
    for _, opt in pairs(filter) do
        if type(opt) == "string" then
            if opt == "Normal Only" and not hasMut and not isParasite then
                allowed = true
            elseif opt == "Mutated Only" and (hasMut or isParasite) then
                allowed = true
            elseif (opt == "Parasite / Infested" or opt == "Monstrous") and isParasite then
                allowed = true
            elseif opt == "Silver Only" and type(muts) == "table" and table.find(muts, "Silver") then
                allowed = true
            elseif opt == "Gold Only" and type(muts) == "table" and (table.find(muts, "Gold") or table.find(muts, "Golden")) then
                allowed = true
            elseif opt == "Rainbow Only" and type(muts) == "table" and table.find(muts, "Rainbow") then
                allowed = true
            end
        end
    end
    return allowed
end

local function isBigEgg(record)
    if not record then return false end
    local scale = tonumber(record.AssetScale) or 1
    local nestScale = tonumber(record.NestScale) or 1
    return scale >= 1.35 or nestScale >= 1.0
end

local function GetMatchingFieldEggs(areasFilter, raritiesFilter, mutationsFilter)
    if not EggState or not EggState.ReadFieldEggs then return {} end
    local ok, snapshot = pcall(EggState.ReadFieldEggs)
    if not ok or not snapshot or not snapshot.Records then return {} end

    local matched = {}
    for _, record in ipairs(snapshot.Records) do
        if record.State == "Slot" and record.BoundsCFrame then
            local isIgnored = ignoredEggs[record.Uid] and (os.clock() - ignoredEggs[record.Uid] < 2.5)
            if not isIgnored and (not stealBigEggsOnly or isBigEgg(record)) then
                local areaOk = isAreaAllowed(record.AreaId, areasFilter)
                local rarityName, baseScore = GetEggRarityInfo(record)
                local rarityOk = isRarityAllowed(rarityName, raritiesFilter)
                local muts = record.Mutations or {}
                local mutOk = isMutationAllowed(muts, record, mutationsFilter)

                -- Strict filter check: only insert if all selected filters match!
                if areaOk and rarityOk and mutOk then
                    local mutBonus = 0
                    for _, m in ipairs(muts) do
                        if m == "Rainbow" then mutBonus = mutBonus + 35
                        elseif m == "Gold" or m == "Golden" then mutBonus = mutBonus + 20
                        elseif m == "Silver" then mutBonus = mutBonus + 10 end
                    end

                    if record.HasParasite == true or (type(muts) == "table" and (table.find(muts, "Parasite") or table.find(muts, "Monstrous"))) then
                        mutBonus = mutBonus + 800
                    end

                    if isBigEgg(record) then
                        mutBonus = mutBonus + 600
                    end

                    table.insert(matched, {
                        record = record,
                        rarity = rarityName,
                        score = baseScore + mutBonus
                    })
                end
            end
        end
    end

    -- Rare Egg Hunter: sort matched eggs by total score descending (Highest Rarity First)
    if #matched > 1 then
        table.sort(matched, function(a, b)
            return a.score > b.score
        end)
    end

    return matched
end

local function EnsureSavedReturnPosition()
    if not savedReturnCFrame then
        local hrp = findHRP()
        if hrp then
            savedReturnCFrame = hrp.CFrame
        end
    end
end

local function isPlayerCarryingEgg()
    local pg = LP:FindFirstChildOfClass("PlayerGui")
    local dropGui = pg and pg:FindFirstChild("DropHeldEgg")
    if dropGui and dropGui.Enabled == true then
        return true
    end

    local char = LP.Character
    if char then
        for _, t in ipairs(char:GetChildren()) do
            if t:IsA("Model") and (t.Name:lower():find("egg") or t:GetAttribute("Uid") or t:GetAttribute("AssetCategory")) then
                return true
            end
            if t:IsA("Tool") then
                if EggToolDisplay and EggToolDisplay.IsEggTool and EggToolDisplay.IsEggTool(t) then
                    return true
                end
                if t:GetAttribute("IsEgg") == true or t:GetAttribute("Uid") ~= nil or t:GetAttribute("AssetCategory") ~= nil then
                    return true
                end
                local tName = t.Name:lower()
                if tName:find("egg") or (tName ~= "bat" and tName ~= "defaulttool" and not tName:find("bat") and not tName:find("slap") and not tName:find("coil") and not tName:find("potion") and not tName:find("lantern")) then
                    return true
                end
            end
        end
    end
    local bp = LP:FindFirstChild("Backpack")
    if bp then
        for _, t in ipairs(bp:GetChildren()) do
            if t:IsA("Tool") and EggToolDisplay and EggToolDisplay.IsEggTool and EggToolDisplay.IsEggTool(t) then
                return true
            end
        end
    end
    return false
end

local function PlantAllCarriedEggsInPen()
    local plotObj = PlotState and PlotState.ResolvePlot and PlotState.ResolvePlot()
    local plotCenter = plotObj and plotObj.CenterPoint and plotObj.CenterPoint.Position or Vector3.new(464.7, 68.2, -364.0)

    local toolsToPlant = {}
    for _, t in ipairs(LP.Character:GetChildren()) do
        if t:IsA("Tool") and EggToolDisplay and EggToolDisplay.IsEggTool and EggToolDisplay.IsEggTool(t) then
            local uid = EggToolDisplay.GetToolUid(t)
            if uid then table.insert(toolsToPlant, uid) end
        end
    end
    for _, t in ipairs(LP.Backpack:GetChildren()) do
        if t:IsA("Tool") and EggToolDisplay and EggToolDisplay.IsEggTool and EggToolDisplay.IsEggTool(t) then
            local uid = EggToolDisplay.GetToolUid(t)
            if uid then table.insert(toolsToPlant, uid) end
        end
    end

    local plantedCount = 0
    for _, eggUid in ipairs(toolsToPlant) do
        for attempt = 1, 3 do
            local offset = CFrame.new(math.random(-6, 6), 0, math.random(-6, 6))
            local ok, res = pcall(function()
                if EggState and EggState.PlantEgg then
                    return EggState.PlantEgg(eggUid, offset)
                end
                return false
            end)
            if ok and res then
                plantedCount = plantedCount + 1
                break
            end
            task.wait(0.1)
        end
    end
    return plantedCount
end

local function StealSpecificEggRobust(targetItem)
    local record = targetItem.record or targetItem
    if not record or not record.Uid or not record.BoundsCFrame then return false end

    -- Verify the egg is still present in the latest snapshot before traveling
    if EggState and EggState.ReadFieldEggs then
        local ok, snap = pcall(EggState.ReadFieldEggs)
        if ok and snap and snap.Records then
            local stillThere = false
            for _, r in ipairs(snap.Records) do
                if r.Uid == record.Uid and r.State == "Slot" then
                    stillThere = true
                    record = r
                    break
                end
            end
            if not stillThere then
                return false
            end
        end
    end

    local hrp = findHRP()
    local hum = findHum()
    if not hrp then return false end

    EnsureSavedReturnPosition()

    local targetPos = record.BoundsCFrame.Position
    local speed = math.clamp(tonumber(glideSpeed) or 750, 50, 750)
    local isInstantTP = false

    -- 1. Travel to egg nest: normal glide for all methods (including Anti Guard)
    TravelToDestination(targetPos + Vector3.new(0, 1.2, 0), speed, true)
    if hrp then
        hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 1.2, 0))
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero
    end
    task.wait(isInstantTP and 0.25 or 0.5)

    -- 2. Claim egg with instant stop & verification handshake
    local slotKey = nil
    if AreaEggSlotIdentity and AreaEggSlotIdentity.LooksLikeFirstAreaUid and AreaEggSlotIdentity.LooksLikeFirstAreaUid(record.Uid) then
        slotKey = AreaEggSlotIdentity.SlotKey(record.AreaId, record.NestId)
    end

    local net = RS:FindFirstChild("Packages") and RS.Packages:FindFirstChild("Networking")
    local carryRemote = net and net:FindFirstChild("RF/EggWorld/AskFieldEggCarry")
    if carryRemote then
        pcall(function() carryRemote:InvokeServer({ Uid = record.Uid, FirstAreaSlotKey = slotKey }) end)
    end
    pcall(function()
        if EggState and EggState.CarryFieldEgg then
            EggState.CarryFieldEgg(record.Uid, slotKey)
        end
    end)

    local prompt = nil
    for _, d in ipairs(Workspace:GetDescendants()) do
        if d:IsA("ProximityPrompt") and d.Name == "CarryAreaEgg" and d.Enabled then
            local act = (d.ActionText or ""):lower()
            local obj = (d.ObjectText or ""):lower()
            if not act:find("skip") and not act:find("robux") and not obj:find("skip") and not obj:find("robux") then
                local p = d.Parent
                if p:IsA("Attachment") then p = p.Parent end
                if p and (p.Position - hrp.Position).Magnitude < 14 then
                    prompt = d
                    break
                end
            end
        end
    end

    if prompt then
        prompt.HoldDuration = 0
        pcall(function() fireproximityprompt(prompt) end)
        
    end

    local safePlotCenter, _ = GetLocalPlotCenter()
    local safeCFrame = CFrame.new(safePlotCenter + Vector3.new(0, 1.2, 0))
    local tPickup = os.clock()
    local carried = false
    local instantFired = false
    local conns = {}
    local function fireInstantNow()
        if instantFired then return end
        instantFired = true
        carried = true
        task.spawn(function()
            TravelToDestination(safeCFrame.Position, 450, true)
            pcall(restoreCollisions)
            pcall(PlantAllCarriedEggsInPen)
        end)
    end
    if isInstantTP then
        local char = LP.Character
        local bp = LP:FindFirstChild("Backpack")
        local pg = LP:FindFirstChildOfClass("PlayerGui")
        pcall(function()
            if char then
                table.insert(conns, char.ChildAdded:Connect(function()
                    if isPlayerCarryingEgg() then fireInstantNow() end
                end))
            end
            if bp then
                table.insert(conns, bp.ChildAdded:Connect(function()
                    if isPlayerCarryingEgg() then fireInstantNow() end
                end))
            end
            if pg then
                table.insert(conns, pg.ChildAdded:Connect(function(c)
                    if c.Name == "DropHeldEgg" then fireInstantNow() end
                end))
                local dg = pg:FindFirstChild("DropHeldEgg")
                if dg then
                    table.insert(conns, dg:GetPropertyChangedSignal("Enabled"):Connect(function()
                        if dg.Enabled then fireInstantNow() end
                    end))
                end
            end
        end)
    end
    local maxWait = isInstantTP and 1.2 or 1.5
    while os.clock() - tPickup < maxWait and not HUB.dead do
        if carried or instantFired then
            carried = true
            break
        end
        if isPlayerCarryingEgg() then
            carried = true
            break
        end
        pcall(function()
            if EggState and EggState.CarryFieldEgg then
                EggState.CarryFieldEgg(record.Uid, slotKey)
            end
        end)
        if prompt then
            prompt.HoldDuration = 0
            pcall(function() fireproximityprompt(prompt) end)
        end
        if isInstantTP then
            task.wait()
        else
            task.wait(0.08)
        end
    end
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end

    if not carried then
        ignoredEggs[record.Uid] = os.clock()
        if isInstantTP then
            TravelToDestination(safeCFrame.Position, 450, true)
            restoreCollisions()
        end
        return false
    end

    -- 2.5 Guard-hit double pickup trick (user method: pickup -> get hit by guard -> pickup again -> glide back to avoid deliver error)
    do
        local guardHitEnabled = true -- pickup, let guard hit you, pick up again, then glide back (prevents deliver error)
        if guardHitEnabled and carried then
            local tGuardStart = os.clock()
            local startHealth = 100
            local hum0 = findHum()
            if hum0 then startHealth = hum0.Health end
            local wasHit = false
            -- Linger near egg to let guard hit us (up to 4s). Detect via health drop / ragdoll / egg drop.
            while os.clock() - tGuardStart < 4.0 and not HUB.dead do
                if not isPlayerCarryingEgg() then
                    wasHit = true
                    break
                end
                local h = findHum()
                if h then
                    local hs = h:GetState()
                    if h.Health < startHealth - 1.5 or hs == Enum.HumanoidStateType.Physics or hs == Enum.HumanoidStateType.Ragdoll or hs == Enum.HumanoidStateType.FallingDown then
                        wasHit = true
                        local tPost = os.clock()
                        while os.clock() - tPost < 0.85 and not HUB.dead do
                            if not isPlayerCarryingEgg() then break end
                            task.wait(0.05)
                        end
                        break
                    end
                end
                task.wait(0.05)
            end

            if wasHit or not isPlayerCarryingEgg() then
                -- The first carry is no longer valid after a guard hit/ragdoll.
                -- IMPORTANT: reset `carried` here so a failed second pickup can
                -- never fall through into the return-to-base movement.
                carried = false
                task.wait(0.65)
                -- Wait until not ragdolled anymore before re-pickup (guard hit -> stand up -> pickup again -> glide)
                do
                    local tRag = os.clock()
                    while os.clock() - tRag < 3.2 and not HUB.dead do
                        local h = findHum()
                        if not h then break end
                        local hs = h:GetState()
                        if hs ~= Enum.HumanoidStateType.Physics and hs ~= Enum.HumanoidStateType.Ragdoll and hs ~= Enum.HumanoidStateType.FallingDown then
                            break
                        end
                        pcall(function() h:ChangeState(Enum.HumanoidStateType.GettingUp) end)
                        task.wait(0.12)
                    end
                    task.wait(0.35)
                end
                local hrpNow = findHRP()
                if hrpNow and (hrpNow.Position - targetPos).Magnitude > 14 then
                    pcall(function()
                        hrpNow.CFrame = CFrame.new(targetPos + Vector3.new(0, 1.8, 0))
                        hrpNow.AssemblyLinearVelocity = Vector3.zero
                        hrpNow.AssemblyAngularVelocity = Vector3.zero
                    end)
                    task.wait(0.35)
                end
                -- Ensure fully standing before pickup attempt
                do
                    local tStand = os.clock()
                    while os.clock() - tStand < 1.5 and not HUB.dead do
                        local h = findHum()
                        if h and h:GetState() ~= Enum.HumanoidStateType.Physics and h:GetState() ~= Enum.HumanoidStateType.Ragdoll and h:GetState() ~= Enum.HumanoidStateType.FallingDown then
                            pcall(function()
                                h.PlatformStand = false
                                h.AutoRotate = true
                                h:ChangeState(Enum.HumanoidStateType.Running)
                            end)
                            break
                        end
                        task.wait(0.08)
                    end
                end
                -- Wait for guard to be back to sleep/idle before re-pickup (prevents instant re-alert & deliver error)
                do
                    local tGuardSleep = os.clock()
                    while os.clock() - tGuardSleep < 4.5 and not HUB.dead do
                        local guardAsleep = false
                        pcall(function()
                            local areasRoot = Workspace:FindFirstChild("__OBJECTS") and Workspace.__OBJECTS:FindFirstChild("Areas") and Workspace.__OBJECTS.Areas:FindFirstChild("GuardAreas")
                            local guardModel = nil
                            if areasRoot and record.AreaId then
                                local areaFolder = areasRoot:FindFirstChild(record.AreaId)
                                if areaFolder then
                                    guardModel = areaFolder:FindFirstChild("Guard") or areaFolder:FindFirstChild("ForestGuardAuthored") or areaFolder:FindFirstChildWhichIsA("Model", true)
                                end
                            end
                            if not guardModel then
                                local nearest, nd = nil, 1e9
                                for _, m in ipairs(Workspace:GetDescendants()) do
                                    if m:IsA("Model") and m.Name:lower():find("guard") and m.PrimaryPart then
                                        local d = (m.PrimaryPart.Position - targetPos).Magnitude
                                        if d < nd and d < 90 then nd = d; nearest = m end
                                    end
                                end
                                guardModel = nearest
                            end
                            if guardModel then
                                local alert = guardModel:GetAttribute("Alert") or guardModel:GetAttribute("Alerted") or guardModel:GetAttribute("IsAlerted") or guardModel:GetAttribute("Chasing")
                                local sleeping = guardModel:GetAttribute("Sleeping") or guardModel:GetAttribute("IsSleeping") or guardModel:GetAttribute("Asleep") or guardModel:GetAttribute("Sleep")
                                local state = guardModel:GetAttribute("State")
                                if sleeping == true then guardAsleep = true
                                elseif alert == false or alert == nil then
                                    local hum = guardModel:FindFirstChildOfClass("Humanoid")
                                    local hrp = guardModel.PrimaryPart or guardModel:FindFirstChild("HumanoidRootPart") or guardModel:FindFirstChildWhichIsA("BasePart", true)
                                    local eggPoint = guardModel:FindFirstChild("EggPoint", true)
                                    if hrp and eggPoint then
                                        local distToHome = (hrp.Position - eggPoint.Position).Magnitude
                                        if distToHome < 7 and (not hum or hum.MoveDirection.Magnitude < 0.12) then
                                            guardAsleep = true
                                        elseif distToHome < 12 and os.clock() - tGuardSleep > 1.2 and (not hum or hum.MoveDirection.Magnitude < 0.15) then
                                            guardAsleep = true
                                        end
                                    elseif state and tostring(state):lower():find("sleep") then guardAsleep = true
                                    elseif alert == nil and sleeping == nil and state == nil then
                                        if os.clock() - tGuardSleep > 1.6 then guardAsleep = true end
                                    elseif alert == false then guardAsleep = true
                                    end
                                end
                                if not guardAsleep then
                                    local alertGui = guardModel:FindFirstChild("Alert", true)
                                    if alertGui and alertGui:IsA("BillboardGui") and alertGui.Enabled == false then guardAsleep = true end
                                end
                            else
                                if os.clock() - tGuardSleep > 1.4 then guardAsleep = true end
                            end
                        end)
                        if guardAsleep then break end
                        task.wait(0.14)
                    end
                    task.wait(0.08)
                end
                task.wait(0.08)
                pcall(function()
                    local h = findHum()
                    local r = findHRP()
                    if h then
                        h.PlatformStand = false
                        h.AutoRotate = true
                        pcall(function() h:ChangeState(Enum.HumanoidStateType.Running) end)
                    end
                    if r then
                        r.AssemblyLinearVelocity = Vector3.zero
                        r.AssemblyAngularVelocity = Vector3.zero
                    end
                end)
                pcall(function()
                    if carryRemote then carryRemote:InvokeServer({ Uid = record.Uid, FirstAreaSlotKey = slotKey }) end
                end)
                pcall(function()
                    if EggState and EggState.CarryFieldEgg then EggState.CarryFieldEgg(record.Uid, slotKey) end
                end)
                task.wait(0.08)
                local prompt2 = nil
                for _, d in ipairs(Workspace:GetDescendants()) do
                    if d:IsA("ProximityPrompt") and d.Name == "CarryAreaEgg" and d.Enabled then
                        local p = d.Parent
                        if p and p:IsA("Attachment") then p = p.Parent end
                        if p then
                            local dist = (p.Position - (findHRP() and findHRP().Position or targetPos)).Magnitude
                            if dist < 16 then
                                local act = (d.ActionText or ""):lower()
                                if not act:find("skip") and not act:find("robux") then
                                    prompt2 = d
                                    break
                                end
                            end
                        end
                    end
                end
                if prompt2 then
                    prompt2.HoldDuration = 0
                    pcall(function() fireproximityprompt(prompt2) end)
                    
                else
                    for _, d in ipairs(Workspace:GetDescendants()) do
                        if d:IsA("ProximityPrompt") and d.Name == "CarryAreaEgg" and d.Enabled then
                            local p = d.Parent
                            if p and p:IsA("Attachment") then p = p.Parent end
                            if p and (p.Position - (findHRP() and findHRP().Position or targetPos)).Magnitude < 18 then
                                d.HoldDuration = 0
                                pcall(function() fireproximityprompt(d) end)
                                task.wait(0.08)
                                if isPlayerCarryingEgg() then break end
                            end
                        end
                    end
                end
                local tPickup2 = os.clock()
                while os.clock() - tPickup2 < 2.2 and not HUB.dead do
                    if isPlayerCarryingEgg() then carried = true break end
                    pcall(function()
                        if EggState and EggState.CarryFieldEgg then EggState.CarryFieldEgg(record.Uid, slotKey) end
                    end)
                    if prompt2 then pcall(function() fireproximityprompt(prompt2) end) end
                    task.wait(0.06)
                end
                if isPlayerCarryingEgg() then carried = true end
                -- Fast trigger back to safe area once egg re-attached
                -- Verify the second pickup before allowing any return movement.
                if isPlayerCarryingEgg() then
                    carried = true
                    task.wait(0.12)
                    isInstantTP = false
                else
                    -- Retry the carry handshake/prompt a few times. This fixes the
                    -- post-ragdoll case where the player is standing again but the
                    -- first re-carry request races the egg/character replication.
                    for retry = 1, 4 do
                        if HUB.dead then break end

                        pcall(function()
                            if carryRemote then
                                carryRemote:InvokeServer({ Uid = record.Uid, FirstAreaSlotKey = slotKey })
                            end
                        end)
                        pcall(function()
                            if EggState and EggState.CarryFieldEgg then
                                EggState.CarryFieldEgg(record.Uid, slotKey)
                            end
                        end)

                        local retryPrompt = nil
                        local currentHRP = findHRP()
                        local currentPos = currentHRP and currentHRP.Position or targetPos
                        for _, d in ipairs(Workspace:GetDescendants()) do
                            if d:IsA("ProximityPrompt") and d.Name == "CarryAreaEgg" and d.Enabled then
                                local parent = d.Parent
                                if parent and parent:IsA("Attachment") then parent = parent.Parent end
                                if parent and (parent.Position - currentPos).Magnitude < 20 then
                                    local act = (d.ActionText or ""):lower()
                                    local obj = (d.ObjectText or ""):lower()
                                    if not act:find("skip") and not act:find("robux") and not obj:find("skip") and not obj:find("robux") then
                                        retryPrompt = d
                                        break
                                    end
                                end
                            end
                        end

                        if retryPrompt then
                            retryPrompt.HoldDuration = 0
                            for fire = 1, 2 do
                                pcall(function() fireproximityprompt(retryPrompt) end)
                                task.wait(0.06)
                                if isPlayerCarryingEgg() then break end
                            end
                        end

                        local tRetry = os.clock()
                        while os.clock() - tRetry < 0.75 and not HUB.dead do
                            if isPlayerCarryingEgg() then
                                carried = true
                                break
                            end
                            task.wait(0.05)
                        end

                        if carried and isPlayerCarryingEgg() then
                            isInstantTP = false
                            break
                        end
                        task.wait(0.12)
                    end
                end
            end
        end
    end

    -- Never tween back empty after a guard hit. Reacquire must be confirmed first.
    if not carried and not isPlayerCarryingEgg() then
        ignoredEggs[record.Uid] = os.clock()
        pcall(restoreCollisions)
        return false
    end

    -- 3. Return to base: exact bypass TP back for "Anti Guard", fast-then-slow for others! (after guard-hit we glide)
    if isInstantTP then
        if not instantFired then
            TravelToDestination(safeCFrame.Position, 450, true)
            task.spawn(function()
                pcall(restoreCollisions)
                pcall(PlantAllCarriedEggsInPen)
            end)
        end
    else
        if speed > 250 then
            local hrpNow = findHRP()
            local curPos = hrpNow and hrpNow.Position or targetPos
            local toBase = safePlotCenter - curPos
            local distBase = toBase.Magnitude
            if distBase > 45 then
                local stagePos = safePlotCenter - toBase.Unit * 35
                stagePos = Vector3.new(stagePos.X, math.max(stagePos.Y, 70.4), stagePos.Z)
                TravelToDestination(stagePos, speed, false)
                local hrp2 = findHRP()
                if hrp2 then
                    hrp2.AssemblyLinearVelocity = Vector3.zero
                    hrp2.AssemblyAngularVelocity = Vector3.zero
                end
                task.wait(0.35)
            end
            TravelToDestination(safePlotCenter, 240, true)
        else
            TravelToDestination(safePlotCenter, speed, true)
        end
    end

    -- Settle in the base pen and wait for delivery to confirm
    local tDeliver = os.clock()
    while os.clock() - tDeliver < 1.5 and isPlayerCarryingEgg() and not HUB.dead do
        task.wait(0.08)
    end

    -- 4. Plant all carried egg tools in the base pen
    PlantAllCarriedEggsInPen()

    -- 5. Land safely on base pen ground (Never go under map)
    local char = LP.Character
    local h = char and char:FindFirstChild("HumanoidRootPart")
    local hu = char and char:FindFirstChildOfClass("Humanoid")
    if h then
        h.CFrame = CFrame.new(safePlotCenter.X, math.max(safePlotCenter.Y, 70.4), safePlotCenter.Z)
        h.AssemblyLinearVelocity = Vector3.zero
        h.AssemblyAngularVelocity = Vector3.zero
    end
    if hu then
        hu.PlatformStand = false
        hu.AutoRotate = true
        pcall(function() hu:ChangeState(Enum.HumanoidStateType.Running) end)
    end

    return carried or isPlayerCarryingEgg()
end

local SendEggStolenWebhook

local function StealBestEggOnce()
    -- Auto Hatch is an independent worker. Do not force-hatch from Auto Steal.
    if autoHatchEnabled then
        pcall(HatchAllReadyEggs)
    end
    local eggs = GetMatchingFieldEggs(selectedStealAreas, selectedStealRarities, selectedMutationTypes)
    if #eggs == 0 then
        HUB.TriggerHopOnNoMatch()
        return false
    end

    local target = eggs[1]
    local success = StealSpecificEggRobust(target)

    if success and typeof(SendEggStolenWebhook) == "function" then
        task.spawn(function()
            pcall(SendEggStolenWebhook, target)
        end)
    end

    return success
end

-- ==============================================================================
-- AUTO TREADMILL -> EGG HANDOFF
-- ==============================================================================
local function GetTreadmillStandPosition()
    local treadmill = nil
    pcall(function()
        local plotObj = PlotState and PlotState.ResolvePlot and PlotState.ResolvePlot()
        local folder = plotObj and plotObj.PlotFolder
        treadmill = folder and folder:FindFirstChild("TreadmillBottom")
    end)
    if not treadmill or not treadmill:IsA("BasePart") then
        return nil
    end
    return treadmill.Position + Vector3.new(0, 4, 0)
end

local function IsDoubleSpeedVisible()
    local ok, visible = pcall(function()
        local pg = LP:FindFirstChild("PlayerGui")
        local elements = pg and pg:FindFirstChild("Elements")
        local left = elements and elements:FindFirstChild("Left")
        local tools = left and left:FindFirstChild("Tools")
        local doubleSpeed = tools and tools:FindFirstChild("DoubleYourSpeed")
        return doubleSpeed ~= nil and doubleSpeed.Visible == true
    end)
    return ok and visible == true
end

local function DismountTreadmill()
    pcall(function()
        local input = game:GetService("VirtualInputManager")
        input:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
        task.wait(0.05)
        input:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
    end)
    local h = findHum()
    if h then
        h.Jump = true
        pcall(function() h:ChangeState(Enum.HumanoidStateType.Jumping) end)
    end
end

local function StopTreadmillTraining()
    treadmillTrainingActive = false

    -- Unequip first, then force a jump so the character is no longer treated as mounted.
    pcall(function()
        local rf = GetNetRemote("RF/Treadmill/AskDoff")
        if rf then rf:InvokeServer() end
    end)

    for _ = 1, 3 do
        DismountTreadmill()
        task.wait(0.08)
        if not IsDoubleSpeedVisible() then
            break
        end
    end

    -- Give the character one final state reset before travelling to an egg.
    local h = findHum()
    if h then
        h.Jump = false
        pcall(function() h:ChangeState(Enum.HumanoidStateType.Running) end)
    end
end

local function RunAutoTreadmillTraining()
    -- This function may be called by HandleAutoTreadmillHandoff while
    -- treadmillHandoffBusy is already true. Do not reject that internal call.
    if not autoTreadmillEnabled or isPlayerCarryingEgg() then
        return false
    end

    -- Never mount the treadmill while a matching target is currently available.
    local matching = GetMatchingFieldEggs(selectedStealAreas, selectedStealRarities, selectedMutationTypes)
    if type(matching) == "table" and #matching > 0 then
        return false
    end

    local pos = GetTreadmillStandPosition()
    local root = findHRP()
    if not pos or not root then
        return false
    end

    if (root.Position - pos).Magnitude > 12 then
        if not TravelToDestination(pos, math.min(glideSpeed, 300), true) then
            return false
        end
        task.wait(0.08)
    end

    -- Re-check after travelling: an egg may have spawned while we were moving.
    matching = GetMatchingFieldEggs(selectedStealAreas, selectedStealRarities, selectedMutationTypes)
    if type(matching) == "table" and #matching > 0 then
        return false
    end

    local ok = pcall(function()
        local rf = GetNetRemote("RF/Treadmill/AskWearStill")
        if rf then rf:InvokeServer() end
    end)
    if not ok then
        treadmillTrainingActive = false
        return false
    end
    treadmillTrainingActive = true
    return true
end

local function GetMatchingEggCount()
    local ok, eggs = pcall(GetMatchingFieldEggs, selectedStealAreas, selectedStealRarities, selectedMutationTypes)
    if not ok or type(eggs) ~= "table" then
        return 0
    end
    return #eggs
end

local function HandleAutoTreadmillHandoff()
    if not autoTreadmillEnabled or treadmillHandoffBusy or HUB.dead then
        return false
    end

    treadmillHandoffBusy = true
    local ok, result = pcall(function()
        if isPlayerCarryingEgg() then
            return false
        end

        -- State 1: matching egg exists -> treadmill OFF -> grab/return -> rescan.
        local matches = GetMatchingFieldEggs(selectedStealAreas, selectedStealRarities, selectedMutationTypes)
        local matchCount = type(matches) == "table" and #matches or 0

        if matchCount > 0 then
            if treadmillTrainingActive or IsDoubleSpeedVisible() then
                StopTreadmillTraining()
                task.wait(0.12)
            end

            -- Extra dismount is intentional: some clients keep the mount state for a frame
            -- after AskDoff returns, which can make the first travel command fail.
            DismountTreadmill()
            task.wait(0.08)

            local stolen = StealBestEggOnce()
            treadmillLastNoMatchAt = 0
            return stolen == true
        end

        -- State 2: nothing matches -> treadmill ON.
        treadmillLastNoMatchAt = os.clock()
        if not treadmillTrainingActive and not IsDoubleSpeedVisible() then
            return RunAutoTreadmillTraining()
        end

        return true
    end)
    treadmillHandoffBusy = false
    return ok and result or false
end

local function HatchAllReadyEggs()
    -- Adapted from the Ready-Egg flow, but uses this hub's existing UI state
    -- (`autoHatchEnabled`) instead of the other UI's H.isOn()/flag system.
    if not autoHatchEnabled or HUB.dead then
        return 0
    end

    local save = nil
    pcall(function()
        if SaveModule and type(SaveModule.Get) == "function" then
            save = SaveModule.Get()
        end
    end)

    local eggInventory = save and save.EggInventory
    if type(eggInventory) ~= "table" then
        return 0
    end

    local hatchedAny = 0
    local attempted = {}

    for uid, egg in pairs(eggInventory) do
        if HUB.dead or not autoHatchEnabled then
            break
        end

        -- Only placed eggs are eligible for Auto Hatch Ready.
        if type(uid) == "string" and type(egg) == "table" and egg.Placement ~= nil then
            local ready = false

            -- Prefer the live EggState readiness check from the reference flow.
            if EggState and type(EggState.IsReadyToHatch) == "function" then
                pcall(function()
                    ready = EggState.IsReadyToHatch(uid) == true
                end)
            end

            -- Fallback for clients that expose readiness directly on the saved egg.
            if not ready then
                if egg.Ready == true or egg.IsReady == true or egg.ReadyToHatch == true then
                    ready = true
                else
                    local finishAt = tonumber(
                        egg.HatchEndTime or egg.HatchAt or egg.ReadyAt or egg.FinishAt
                    )
                    if finishAt and finishAt <= os.time() then
                        ready = true
                    end
                end
            end

            if ready and not attempted[uid] then
                attempted[uid] = true

                local started = false
                if EggState and type(EggState.BeginHatch) == "function" then
                    pcall(function()
                        started = EggState.BeginHatch(uid) == true
                    end)
                end

                -- Some builds return nil from BeginHatch even though the request
                -- was accepted. Give the state a moment, then finish the hatch.
                if started or (EggState and type(EggState.FinishHatch) == "function") then
                    task.wait(0.05)

                    local completed = false
                    if EggState and type(EggState.FinishHatch) == "function" then
                        pcall(function()
                            local result = EggState.FinishHatch(uid)
                            completed = result ~= false
                        end)
                    end

                    if started or completed then
                        hatchedAny += 1
                        task.wait(0.35)
                    end
                end
            end
        end
    end

    return hatchedAny
end

-- ==============================================================================
-- BASE, HOMESTEAD & REWARDS AUTOMATION LOGIC
-- ==============================================================================
local function UpgradeHomesteadBase()
    local re1 = GetNetRemote("RE/Homestead/AskNearbyPurchase")
    if re1 then pcall(function() re1:FireServer() end) end
    local re2 = GetNetRemote("RE/Homestead/AskBaseTierRaise")
    if re2 then pcall(function() re2:FireServer() end) end
end

local function UpgradeTreadmillTier()
    local rf = GetNetRemote("RF/Treadmill/AskTierRaise")
    if rf then pcall(function() rf:InvokeServer() end) end
end

local function EquipBestPets()
    local rf = GetNetRemote("RF/Haul/WearBest") or GetNetRemote("RF/PenRoster/ConfirmEquipBestBadge")
    if rf then pcall(function() rf:InvokeServer() end) end
end

local function GetMyMonsterPosition()
    local myMonster = Workspace:FindFirstChild("MonsterParasiteMonsters") and Workspace.MonsterParasiteMonsters:FindFirstChild("Monster_" .. LP.UserId)
    if myMonster then
        local pos = (myMonster.PrimaryPart and myMonster.PrimaryPart.Position) or myMonster:GetPivot().Position
        return pos
    end
    local standPad = Workspace:FindFirstChild("Stands") and Workspace.Stands:FindFirstChild("Pads") and Workspace.Stands.Pads:FindFirstChild("Monster")
    if standPad then return standPad.Position end
    return Vector3.new(545.1, 68.0, -413.4)
end

local function ClaimMonsterChests()
    pcall(function()
        local rf1 = GetNetRemote("RF/MonsterParasite/AskChestClaim")
        if rf1 then rf1:InvokeServer() end
        local rf2 = GetNetRemote("RF/MonsterParasite/AskChestTake")
        if rf2 then rf2:InvokeServer() end
    end)
end

local function FeedMonsterParasite()
    local rf = GetNetRemote("RF/MonsterParasite/AskFeed")
    if not rf then return false end

    local hrp = findHRP()
    if not hrp then return false end

    local mPos = GetMyMonsterPosition()
    local dist = (hrp.Position - mPos).Magnitude
    local savedSpot = nil

    if dist > 12 then
        savedSpot = hrp.CFrame
        TravelToDestination(mPos + Vector3.new(0, 1.2, 0), glideSpeed or 200, true)
        task.wait(0.08)
    end

    local ok, res = pcall(function() return rf:InvokeServer() end)

    if savedSpot then
        task.wait(0.1)
        TravelToDestination(savedSpot.Position, glideSpeed or 200, true)
        local h = findHRP()
        if h then h.CFrame = savedSpot end
    end

    return ok and res
end

local function DropHeldEgg()
    local rf = GetNetRemote("RF/EggWorld/AskFieldEggDrop")
    if rf then pcall(function() rf:InvokeServer() end) end
    if EggState and EggState.DropFieldEgg then pcall(EggState.DropFieldEgg) end
end

local function BuyAffordableTrails()
    local rf = GetNetRemote("RF/Trailwear/AskPurchase")
    local TrailsData = RS:FindFirstChild("Data") and RS.Data:FindFirstChild("Trails") and require(RS.Data.Trails)
    local save = nil
    pcall(function() save = SaveModule and SaveModule.Get and SaveModule.Get() end)
    if not rf or not TrailsData or not save then return end

    local myMoney = tonumber(save.Money) or 0
    local inv = save.TrailInventory or {}

    for _, t in pairs(TrailsData.Directory or TrailsData) do
        if type(t) == "table" and t._id and not inv[t._id] then
            local price = tonumber(t.Price) or math.huge
            if myMoney >= price then
                pcall(function() rf:InvokeServer(t._id) end)
                task.wait(0.25)
            end
        end
    end
end

local function SetNoKnockback(enabled)
    noKnockbackEnabled = enabled
    if enabled then
        pcall(function()
            local rigSync = GetNetRemote("RE/RigSync/Refresh")
            if rigSync and getconnections then
                for _, conn in ipairs(getconnections(rigSync.OnClientEvent)) do
                    pcall(function() conn:Disconnect() end)
                end
            end
        end)
    end
end

-- Auto-enable defensive features by default (user request)
pcall(function() if avoidTrapsEnabled then NeutralizeTraps() end end)
pcall(function() if noKnockbackEnabled then SetNoKnockback(true) end end)

local function SellSelectedPets()
    local re = GetNetRemote("RE/PetSatchel/SellPet")
    if not re or not SaveModule then return end
    local save = nil
    pcall(function() save = SaveModule.Get and SaveModule.Get() end)
    local inv = save and save.Inventory
    if type(inv) ~= "table" then return end

    for uid, petData in pairs(inv) do
        if type(petData) == "table" and not petData.Locked then
            local rName = petData.Rarity or "Common"
            if isRarityAllowed(rName, getSellRarityFilter(selectedSellPetRarities)) then
                pcall(function() re:FireServer(uid) end)
                task.wait(0.08)
            end
        end
    end
end

local function SellSelectedEggs()
    if not SaveModule then return end
    local save = nil
    pcall(function() save = SaveModule.Get and SaveModule.Get() end)
    if not save then return end
    local inv = save.EggInventory
    if type(inv) ~= "table" then return end

    local wear = GetNetRemote("RF/EggWorld/AskWearTool")
    local sell = GetNetRemote("RE/PetSatchel/SellPet")
    if not wear or not sell then return end

    for uid, eggData in pairs(inv) do
        if type(eggData) == "table" and not eggData.Placement and not eggData.Locked then
            local rName = GetEggRarityInfo(eggData)
            if isRarityAllowed(rName, getSellRarityFilter(selectedSellEggRarities)) then
                pcall(function() wear:InvokeServer(uid) end)
                pcall(function() sell:FireServer({ uid }) end)
                task.wait(SELL_REQUEST_DELAY)
            end
        end
    end
end

local function DeleteOwnPetRenders()
    local count = 0
    local function sweep(container)
        if not container then return end
        for _, child in ipairs(container:GetChildren()) do
            if child:IsA("Model") or child:IsA("BasePart") then
                pcall(function()
                    child:Destroy()
                    count = count + 1
                end)
            end
        end
    end
    sweep(Workspace:FindFirstChild("Pets"))
    sweep(Workspace:FindFirstChild("RenderedPets"))
    return count
end

local function ClaimAllAvailableRewards()
    pcall(function()
        local rf1 = GetNetRemote("RF/AwayEarnings/AskCollect")
        if rf1 then rf1:InvokeServer() end
    end)
    pcall(function()
        local rf2 = GetNetRemote("RF/Codex/AskRedeemAll")
        if rf2 then rf2:InvokeServer() end
    end)
    pcall(function()
        local rf3 = GetNetRemote("RF/GroupPerk/RedeemPerk")
        if rf3 then rf3:InvokeServer() end
    end)
    pcall(ClaimMonsterChests)
end


-- ==============================================================================
-- SERVER HOP CORE (register-safe / src1 only)
-- ==============================================================================
HUB.ServerHopState = HUB.ServerHopState or {
    AutoHop = false,
    MaxHops = 20,
    HopDelay = 10,
    HopCount = 0,
    Busy = false,
    HopOnNoMatch = false,
    LastHopAt = 0,
    AutoEnabledAt = 0,
}

function HUB.ServerHopRequest(url)
    local req = (syn and syn.request) or (http and http.request) or http_request or request
    if type(req) == "function" then
        local ok, res = pcall(req, {
            Url = url,
            Method = "GET",
            Headers = { ["Content-Type"] = "application/json" },
        })
        if ok and res then
            local status = tonumber(res.StatusCode or res.Status or 200) or 0
            if status >= 200 and status < 300 and type(res.Body) == "string" then
                return res.Body
            end
        end
    end
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if ok and type(body) == "string" then return body end
    return nil
end

function HUB.JoinServer(placeId, jobId)
    placeId = tonumber(placeId)
    if not placeId or placeId <= 0 then return false, "invalid place id" end
    if not jobId or tostring(jobId) == "" then return false, "missing server id" end
    local ok, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(placeId, tostring(jobId), LP)
    end)
    if not ok then return false, tostring(err) end
    return true
end

function HUB.FindOpenPublicServer(placeId)
    placeId = tonumber(placeId)
    if not placeId then return nil, "invalid place id" end
    local hs = game:GetService("HttpService")
    local currentJob = tostring(game.JobId or "")
    local cursor = ""
    local base = "https://games.roblox.com/v1/games/" .. tostring(placeId) .. "/servers/Public?sortOrder=Asc&limit=100"
    for _ = 1, 5 do
        local url = base
        if cursor ~= "" then url = url .. "&cursor=" .. hs:UrlEncode(cursor) end
        local body = HUB.ServerHopRequest(url)
        if not body then return nil, "server list request failed" end
        local ok, data = pcall(hs.JSONDecode, hs, body)
        if not ok or type(data) ~= "table" then return nil, "invalid server list" end
        for _, server in ipairs(data.data or {}) do
            local id = tostring(server.id or "")
            local playing = tonumber(server.playing) or 0
            local maxPlayers = tonumber(server.maxPlayers) or 0
            if id ~= "" and id ~= currentJob and playing < maxPlayers then
                return { placeId = placeId, jobId = id, playing = playing, maxPlayers = maxPlayers }
            end
        end
        cursor = tostring(data.nextPageCursor or "")
        if cursor == "" then break end
    end
    return nil, "no open server found"
end

function HUB.HopOnce()
    local state = HUB.ServerHopState
    if state.Busy then return false, "busy" end
    if state.HopCount >= state.MaxHops then
        state.AutoHop = false
        return false, "hop limit reached"
    end
    state.Busy = true
    local target, err = HUB.FindOpenPublicServer(game.PlaceId)
    if not target then
        state.Busy = false
        return false, tostring(err or "no server")
    end
    local ok, joinErr = HUB.JoinServer(target.placeId, target.jobId)
    if ok then
        state.HopCount += 1
        state.LastHopAt = os.clock()
        state.Busy = false
        return true, "Teleporting"
    end
    state.Busy = false
    return false, tostring(joinErr or "teleport failed")
end

function HUB.TriggerHopOnNoMatch()
    local state = HUB.ServerHopState
    if not state.AutoHop or not state.HopOnNoMatch then return end
    if state.Busy then return end
    if os.clock() - state.LastHopAt < state.HopDelay then return end
    if state.HopCount >= state.MaxHops then
        state.AutoHop = false
        return
    end
    task.spawn(function()
        pcall(HUB.HopOnce)
    end)
end

task.spawn(function()
    while not HUB.dead do
        local state = HUB.ServerHopState
        if state.AutoHop then
            if state.HopCount >= state.MaxHops then
                state.AutoHop = false
            elseif not state.Busy then
                local now = os.clock()
                local anchor = math.max(state.LastHopAt or 0, state.AutoEnabledAt or 0)
                if now - anchor >= state.HopDelay then
                    task.spawn(function()
                        local ok = pcall(HUB.HopOnce)
                        if not ok then
                            state.Busy = false
                        end
                    end)
                end
            end
        end
        task.wait(0.25)
    end
end)

-- ==============================================================================
-- WORKER LOOPS
-- ==============================================================================
-- 1. Auto Steal Eggs Loop
task.spawn(function()
    while not HUB.dead do
        -- Both toggles can stay ON at the same time. Auto Treadmill acts as
        -- the fallback state, while Auto Steal remains the egg-selection/steal
        -- feature. Matching eggs always take priority over treadmill training.
        if autoTreadmillEnabled then
            pcall(HandleAutoTreadmillHandoff)
        elseif autoStealEnabled then
            pcall(StealBestEggOnce)
        end
        task.wait(autoTreadmillEnabled and 0.25 or stealDelay)
    end
end)

-- 2. Auto Hatch & Auto Plant Loop
task.spawn(function()
    while not HUB.dead do
        if autoHatchEnabled then
            pcall(HatchAllReadyEggs)
        end
        if autoPlantEnabled then
            pcall(PlantAllCarriedEggsInPen)
        end
        task.wait(hatchCheckDelay)
    end
end)

-- 3. Base, Homestead, Sales & Event Upgrades Loop
task.spawn(function()
    while not HUB.dead do
        if autoUpgradeBase then pcall(UpgradeHomesteadBase) end
        if autoUpgradeTreadmill then pcall(UpgradeTreadmillTier) end
        if autoEquipBestPets then pcall(EquipBestPets) end
        if autoClaimRewards then pcall(ClaimAllAvailableRewards) end
        if autoClaimMonsterChests then pcall(ClaimMonsterChests) end
        if autoFeedMonster then pcall(FeedMonsterParasite) end
        if autoSellPets then pcall(SellSelectedPets) end
        if autoSellEggs then pcall(SellSelectedEggs) end
        task.wait(2.5)
    end
end)

-- 4. Bat / Slap Aura Loop
task.spawn(function()
    local batRe = GetNetRemote("RE/BatSwing/Trigger")
    while not HUB.dead do
        if batAuraEnabled and batRe then
            local hrp = findHRP()
            if hrp then
                local foundNearby = false
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LP and p.Character then
                        local oHrp = p.Character:FindFirstChild("HumanoidRootPart")
                        if oHrp and (oHrp.Position - hrp.Position).Magnitude <= batAuraRadius then
                            foundNearby = true
                            break
                        end
                    end
                end
                if foundNearby then
                    pcall(function() batRe:FireServer() end)
                end
            end
        end
        task.wait(batAuraDelay)
    end
end)

-- 5. Trap Neutralizer Loop
task.spawn(function()
    local debris = Workspace:FindFirstChild("__DEBRIS")
    if debris then
        track(debris.ChildAdded:Connect(function(child)
            if avoidTrapsEnabled and child.Name == "PlayerTrap" then
                task.wait(0.05)
                if child:GetAttribute("Owner") ~= LP.Name then
                    if child:IsA("BasePart") then child.CanTouch = false end
                    for _, c in ipairs(child:GetChildren()) do
                        if c:IsA("BasePart") then c.CanTouch = false end
                    end
                end
            end
        end))
    end

    while not HUB.dead do
        if avoidTrapsEnabled or autoStealEnabled then
            pcall(NeutralizeTraps)
        end
        task.wait(1.5)
    end
end)

-- ==============================================================================
-- VISUALS & ESP
-- ==============================================================================
local esp = {
    enabled         = false,
    eggs            = true,
    traps           = false,
    players         = false,
    guards          = false,
    rareEggsOnly    = false,
    showPetIcons    = true,
    maxDistance     = 800,

    eggColor        = Color3.fromRGB(255, 200, 50),
    rareEggColor    = Color3.fromRGB(255, 60, 220),
    trapColor       = Color3.fromRGB(255, 60, 60),
    playerColor     = Color3.fromRGB(100, 220, 100),
    guardColor      = Color3.fromRGB(255, 60, 60),
}

local hasDrawing = type(Drawing) == "table" and type(Drawing.new) == "function"
local trackedEspObjects = {}
local espBillboards = {}
local espContainer = nil

local function getEspContainer()
    if espContainer and espContainer.Parent then return espContainer end
    local p = nil
    pcall(function() p = (gethui and gethui()) end)
    if not p then pcall(function() p = game:GetService("CoreGui") end) end
    if not p then p = LP:FindFirstChild("PlayerGui") or Workspace end

    pcall(function()
        for _, c in ipairs(p:GetChildren()) do
            if c:IsA("Folder") and c.Name == "SAE_Esp_Holder" then c:Destroy() end
        end
    end)
    espContainer = Instance.new("Folder")
    espContainer.Name = "SAE_Esp_Holder"
    pcall(function() espContainer.Parent = p end)
    return espContainer
end

local function updateEggBillboard(key, pos, icon)
    local bb = espBillboards[key]
    if not bb or not bb.gui or not bb.gui.Parent then
        local holder = getEspContainer()
        local part = Instance.new("Part")
        part.Name = "EspAnchor"
        part.Size = Vector3.new(1, 1, 1)
        part.Transparency = 1
        part.Anchored = true
        part.CanCollide = false
        part.CanQuery = false
        part.CanTouch = false
        part.CFrame = CFrame.new(pos)
        part.Parent = holder

        local gui = Instance.new("BillboardGui")
        gui.Name = "EggIconBillboard"
        gui.Adornee = part
        gui.Size = UDim2.fromOffset(28, 28)
        gui.StudsOffset = Vector3.new(-2.2, 1.2, 0)
        gui.AlwaysOnTop = true
        gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        gui.Parent = part

        local img = Instance.new("ImageLabel")
        img.Name = "PetImage"
        img.Size = UDim2.fromScale(1, 1)
        img.BackgroundTransparency = 1
        img.ScaleType = Enum.ScaleType.Fit
        img.Image = icon or ""
        img.Parent = gui

        bb = {
            part = part,
            gui = gui,
            img = img
        }
        espBillboards[key] = bb
    else
        bb.part.CFrame = CFrame.new(pos)
        bb.img.Image = icon or ""
        bb.gui.Enabled = (icon ~= nil and icon ~= "")
    end
    return bb
end

local function createDrawingObject()
    if not hasDrawing then return {} end
    local o = {}
    o.name = trackDrawing(Drawing.new("Text"))
    o.name.Size = 13; o.name.Center = true; o.name.Outline = true; o.name.Visible = false

    o.dist = trackDrawing(Drawing.new("Text"))
    o.dist.Size = 11; o.dist.Center = true; o.dist.Outline = true; o.dist.Visible = false

    o.box = trackDrawing(Drawing.new("Square"))
    o.box.Thickness = 1.5; o.box.Filled = false; o.box.Visible = false

    return o
end

track(RunService.RenderStepped:Connect(function()
    if HUB.dead or not esp.enabled then
        for _, obj in pairs(trackedEspObjects) do
            if obj.name then obj.name.Visible = false end
            if obj.dist then obj.dist.Visible = false end
            if obj.box then obj.box.Visible = false end
        end
        for _, bb in pairs(espBillboards) do
            if bb.gui then bb.gui.Enabled = false end
        end
        return
    end

    local hrp = findHRP()
    local myPos = hrp and hrp.Position or Vector3.zero
    local renderItems = {}
    local activeBbKeys = {}

    -- Eggs ESP
    if esp.eggs and EggState and EggState.ReadFieldEggs then
        local ok, snap = pcall(EggState.ReadFieldEggs)
        if ok and snap and snap.Records then
            for _, egg in ipairs(snap.Records) do
                if egg.State == "Slot" and egg.BoundsCFrame then
                    local pos = egg.BoundsCFrame.Position
                    local dist = (pos - myPos).Magnitude
                    if esp.maxDistance <= 0 or dist <= esp.maxDistance then
                        local muts = egg.Mutations or {}
                        local isRare = #muts > 0
                        if not esp.rareEggsOnly or isRare then
                            local mutText = isRare and (" [" .. table.concat(muts, ",") .. "]") or ""
                            local rName = GetEggRarityInfo(egg)
                            local label = (egg.AssetCategory or "Egg") .. " (" .. rName .. ")" .. mutText
                            local cat = egg.AssetCategory
                            local aInfo = AssetsData and (AssetsData.Directory or AssetsData) and (AssetsData.Directory or AssetsData)[cat]
                            local petIcon = aInfo and (aInfo.Icon or (aInfo.Egg and aInfo.Egg.Icon)) or ""

                            local itemColor = isRare and esp.rareEggColor or esp.eggColor

                            table.insert(renderItems, {
                                Key = egg.Uid,
                                Pos = pos,
                                Name = label,
                                Color = itemColor,
                                Dist = dist,
                            })

                            if esp.showPetIcons and petIcon ~= "" then
                                activeBbKeys[egg.Uid] = true
                                updateEggBillboard(egg.Uid, pos, petIcon)
                            end
                        end
                    end
                end
            end
        end
    end

    -- Traps ESP
    if esp.traps then
        local debris = Workspace:FindFirstChild("__DEBRIS")
        if debris then
            for _, trap in ipairs(debris:GetChildren()) do
                if trap.Name == "PlayerTrap" and trap:IsA("BasePart") then
                    local pos = trap.Position
                    local dist = (pos - myPos).Magnitude
                    if esp.maxDistance <= 0 or dist <= esp.maxDistance then
                        local owner = trap:GetAttribute("Owner") or "Enemy"
                        table.insert(renderItems, {
                            Key = trap,
                            Pos = pos + Vector3.new(0, 1.5, 0),
                            Name = "[TRAP] @" .. owner,
                            Color = esp.trapColor,
                            Dist = dist,
                        })
                    end
                end
            end
        end
    end

    -- Players ESP
    if esp.players then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP and p.Character then
                local oHrp = p.Character:FindFirstChild("HumanoidRootPart")
                if oHrp then
                    local dist = (oHrp.Position - myPos).Magnitude
                    if esp.maxDistance <= 0 or dist <= esp.maxDistance then
                        table.insert(renderItems, {
                            Key = p,
                            Pos = oHrp.Position,
                            Name = p.DisplayName .. " (@" .. p.Name .. ")",
                            Color = esp.playerColor,
                            Dist = dist,
                        })
                    end
                end
            end
        end
    end

    -- Hide unreferenced billboards
    for k, bb in pairs(espBillboards) do
        if not activeBbKeys[k] and bb.gui then
            bb.gui.Enabled = false
        end
    end

    local cam = GetCamera()
    local activeKeys = {}
    for _, item in ipairs(renderItems) do
        activeKeys[item.Key] = true
        local obj = trackedEspObjects[item.Key]
        if not obj then
            obj = createDrawingObject()
            trackedEspObjects[item.Key] = obj
        end

        local screenPos, onScreen = nil, false
        if cam then
            screenPos, onScreen = cam:WorldToViewportPoint(item.Pos)
        end
        if onScreen and hasDrawing and screenPos then
            if obj.name then
                obj.name.Text = item.Name
                obj.name.Position = Vector2.new(screenPos.X, screenPos.Y - 14)
                obj.name.Color = item.Color
                obj.name.Visible = true
            end
            if obj.dist then
                obj.dist.Text = math.floor(item.Dist) .. " studs"
                obj.dist.Position = Vector2.new(screenPos.X, screenPos.Y + 2)
                obj.dist.Color = Color3.fromRGB(220, 220, 220)
                obj.dist.Visible = true
            end
        else
            if obj.name then obj.name.Visible = false end
            if obj.dist then obj.dist.Visible = false end
            if obj.box then obj.box.Visible = false end
        end
    end

    for k, obj in pairs(trackedEspObjects) do
        if not activeKeys[k] then
            if obj.name then obj.name.Visible = false end
            if obj.dist then obj.dist.Visible = false end
            if obj.box then obj.box.Visible = false end
        end
    end
end))

-- Fullbright
local fullbrightEnabled = false
local defaultAmbient = Lighting.Ambient
local defaultOutdoor = Lighting.OutdoorAmbient
local defaultBrightness = Lighting.Brightness
local defaultClockTime = Lighting.ClockTime

local function SetFullbright(v)
    fullbrightEnabled = v
    if v then
        Lighting.Ambient = Color3.fromRGB(255, 255, 255)
        Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
    else
        Lighting.Ambient = defaultAmbient
        Lighting.OutdoorAmbient = defaultOutdoor
        Lighting.Brightness = defaultBrightness
        Lighting.ClockTime = defaultClockTime
    end
end

-- ==============================================================================
-- MOVEMENT & PLAYER MODIFIERS
-- ==============================================================================
local walkSpeedEnabled = false
local walkSpeedVal     = 24
local jumpPowerEnabled = false
local jumpPowerVal     = 60
local infiniteJump     = false
local flying           = false
local flySpeed         = 60
local antiAFK          = false

local function ApplyWalkSpeed(v)
    walkSpeedVal = v
    local hum = findHum()
    if hum and walkSpeedEnabled then hum.WalkSpeed = v end
end

local function ApplyJumpPower(v)
    jumpPowerVal = v
    local hum = findHum()
    if hum and jumpPowerEnabled then
        hum.UseJumpPower = true
        hum.JumpPower = v
    end
end

track(RunService.Stepped:Connect(function()
    if HUB.dead then return end
    local hum = findHum()
    if hum then
        if walkSpeedEnabled then hum.WalkSpeed = walkSpeedVal end
        if jumpPowerEnabled then hum.UseJumpPower = true; hum.JumpPower = jumpPowerVal end
    end
end))

track(UserInputService.JumpRequest:Connect(function()
    if HUB.dead then return end
    local hum = findHum()
    if hum then
        hum.Jump = true
        hum:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end))

local function startFly()
    if flying then return end
    local hrp = findHRP()
    local hum = findHum()
    if not (hrp and hum) then return end
    flying = true
    hrp.Anchored = true

    local bodyGyro = Instance.new("BodyGyro")
    bodyGyro.MaxTorque = Vector3.new(1, 1, 1) * 1e5
    bodyGyro.P = 1e5
    bodyGyro.CFrame = hrp.CFrame
    bodyGyro.Parent = hrp

    HUB._fly = {
        hrp = hrp,
        gyro = bodyGyro,
        conn = track(RunService.RenderStepped:Connect(function(dt)
            if not flying or HUB.dead then return end
            local cam = GetCamera()
            if not cam then return end
            local look = cam.CFrame.LookVector
            local right = cam.CFrame.RightVector
            local flatLook = Vector3.new(look.X, 0, look.Z)
            flatLook = flatLook.Magnitude > 0.001 and flatLook.Unit or Vector3.new(0, 0, -1)
            local flatRight = Vector3.new(right.X, 0, right.Z)
            flatRight = flatRight.Magnitude > 0.001 and flatRight.Unit or Vector3.new(1, 0, 0)

            local dir = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + flatLook end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - flatLook end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - flatRight end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + flatRight end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.new(0, 1, 0) end

            if dir.Magnitude > 0 then
                hrp.CFrame = hrp.CFrame + dir.Unit * flySpeed * math.min(dt, 0.1)
            end
            bodyGyro.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + look)
        end))
    }
end

local function stopFly()
    flying = false
    local f = HUB._fly
    if f then
        pcall(function() f.conn:Disconnect() end)
        pcall(function() f.hrp.Anchored = false end)
        pcall(function() f.gyro:Destroy() end)
        HUB._fly = nil
    end
end

local antiAfkConn = nil
local function SetAntiAFK(v)
    antiAFK = v
    if v and not antiAfkConn then
        antiAfkConn = track(LocalPlayer.Idled:Connect(function()
            if antiAFK then
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end
        end))
    elseif not v and antiAfkConn then
        pcall(function() antiAfkConn:Disconnect() end)
        antiAfkConn = nil
    end
end

-- ==============================================================================
-- UI CREATION - MAIN TABS
-- ==============================================================================
local EggsTab     = Window:AddTab({ Name = "Eggs", Subtitle = "Steal, hatch & plant", Icon = "crown" })
local BaseTab     = Window:AddTab({ Name = "Base", Subtitle = "Homestead & training", Icon = "bolt" })
local CombatTab   = Window:AddTab({ Name = "Combat", Subtitle = "Bat, slaps & defense", Icon = "combat" })
local PlayerTab   = Window:AddTab({ Name = "Player", Subtitle = "Movement & teleports", Icon = "player" })
local SettingsTab = Window:AddTab({ Name = "Settings", Subtitle = "Configs & unloader", Icon = "gear" })
local ServerTab   = Window:AddTab({ Name = "Server", Subtitle = "Server hop", Icon = "globe" })



-- -----------------------------------------------------------------------------
-- SERVER HOP DYNAMIC ISLAND GUI
-- -----------------------------------------------------------------------------
do
    function HUB.OpenServerHopGui()
        local existing = HUB.ServerHopGuiInstance
        if existing and existing.Parent then
            return existing
        end

        local services = {
            Players = Players,
            TeleportService = TeleportService,
            HttpService = game:GetService("HttpService"),
            CoreGui = game:GetService("CoreGui"),
            TweenService = game:GetService("TweenService"),
        }

        local Theme = {
            Background = Color3.fromRGB(15, 15, 17),
            Panel = Color3.fromRGB(24, 24, 26),
            AccentLightYellow = Color3.fromRGB(252, 233, 158),
            AccentMuted = Color3.fromRGB(180, 165, 110),
            TextMain = Color3.fromRGB(250, 250, 250),
            TextSub = Color3.fromRGB(170, 170, 170),
            RedCancel = Color3.fromRGB(180, 60, 60),
            GreenActive = Color3.fromRGB(252, 233, 158),
        }

        local gui = Instance.new("ScreenGui")
        gui.Name = "AxelHubServerHop"
        gui.ResetOnSpawn = false
        gui.IgnoreGuiInset = true
        pcall(function() gui.Parent = services.CoreGui end)
        if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
        HUB.ServerHopGuiInstance = gui

        local island = Instance.new("Frame")
        island.Name = "IslandFrame"
        island.Size = UDim2.new(0, 220, 0, 48)
        island.Position = UDim2.new(0.5, -110, 0, 16)
        island.BackgroundColor3 = Theme.Background
        island.BorderSizePixel = 0
        island.Active = true
        island.Draggable = true
        island.ClipsDescendants = true
        island.Parent = gui

        local islandCorner = Instance.new("UICorner")
        islandCorner.CornerRadius = UDim.new(1, 0)
        islandCorner.Parent = island
        local islandGlow = Instance.new("UIStroke")
        islandGlow.Color = Theme.AccentLightYellow
        islandGlow.Transparency = 0.2
        islandGlow.Thickness = 1.5
        islandGlow.Parent = island

        local topBar = Instance.new("Frame")
        topBar.Size = UDim2.new(1, 0, 0, 48)
        topBar.BackgroundTransparency = 1
        topBar.Parent = island

        local avatar = Instance.new("ImageLabel")
        avatar.Size = UDim2.new(0, 32, 0, 32)
        avatar.Position = UDim2.new(0, 10, 0.5, -16)
        avatar.BackgroundTransparency = 1
        avatar.Image = "rbxassetid://86949082023913"
        avatar.Parent = topBar
        Instance.new("UICorner", avatar).CornerRadius = UDim.new(1, 0)

        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, -95, 1, 0)
        title.Position = UDim2.new(0, 50, 0, 0)
        title.BackgroundTransparency = 1
        title.Font = Enum.Font.GothamBold
        title.Text = "Axel Hub Hop"
        title.TextColor3 = Theme.AccentLightYellow
        title.TextSize = 14
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.Parent = topBar

        local toggle = Instance.new("TextButton")
        toggle.Size = UDim2.new(0, 32, 0, 32)
        toggle.Position = UDim2.new(1, -38, 0.5, -16)
        toggle.BackgroundColor3 = Theme.Panel
        toggle.BorderSizePixel = 0
        toggle.Font = Enum.Font.GothamBold
        toggle.Text = "+"
        toggle.TextColor3 = Theme.AccentLightYellow
        toggle.TextSize = 18
        toggle.Parent = topBar
        Instance.new("UICorner", toggle).CornerRadius = UDim.new(1, 0)

        local content = Instance.new("Frame")
        content.Size = UDim2.new(1, -24, 1, -64)
        content.Position = UDim2.new(0, 12, 0, 54)
        content.BackgroundColor3 = Theme.Background
        content.BorderSizePixel = 0
        content.Visible = false
        content.Parent = island

        local info = Instance.new("Frame")
        info.Size = UDim2.new(1, 0, 0, 115)
        info.BackgroundColor3 = Theme.Panel
        info.BorderSizePixel = 0
        info.Parent = content
        Instance.new("UICorner", info).CornerRadius = UDim.new(0, 12)
        local infoStroke = Instance.new("UIStroke")
        infoStroke.Color = Theme.AccentMuted
        infoStroke.Thickness = 1
        infoStroke.Parent = info

        local infoList = Instance.new("UIListLayout")
        infoList.SortOrder = Enum.SortOrder.LayoutOrder
        infoList.Padding = UDim.new(0, 6)
        infoList.HorizontalAlignment = Enum.HorizontalAlignment.Center
        infoList.Parent = info
        local infoPad = Instance.new("UIPadding")
        infoPad.PaddingTop = UDim.new(0, 12)
        infoPad.PaddingLeft = UDim.new(0, 12)
        infoPad.PaddingRight = UDim.new(0, 12)
        infoPad.Parent = info

        local function createTextRow(textStr)
            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(1, 0, 0, 20)
            label.BackgroundTransparency = 1
            label.Font = Enum.Font.GothamMedium
            label.Text = textStr
            label.TextColor3 = Theme.TextSub
            label.TextSize = 12
            label.TextXAlignment = Enum.TextXAlignment.Left
            label.Parent = info
        end
        createTextRow("🌟 Target: Best Ping Server")
        createTextRow("🛡️ Safe & Undetected Hop")
        createTextRow("✨ Powered by Axel Hub")

        local jobRow = Instance.new("Frame")
        jobRow.Size = UDim2.new(1, 0, 0, 36)
        jobRow.Position = UDim2.new(0, 0, 0, 127)
        jobRow.BackgroundTransparency = 1
        jobRow.Parent = content

        local jobInput = Instance.new("TextBox")
        jobInput.Size = UDim2.new(0.68, 0, 1, 0)
        jobInput.Position = UDim2.new(0, 0, 0, 0)
        jobInput.BackgroundColor3 = Theme.Panel
        jobInput.BorderSizePixel = 0
        jobInput.Font = Enum.Font.GothamMedium
        jobInput.PlaceholderText = "Enter Job ID ..."
        jobInput.Text = ""
        jobInput.TextColor3 = Theme.TextMain
        jobInput.PlaceholderColor3 = Theme.TextSub
        jobInput.TextSize = 12
        jobInput.ClearTextOnFocus = false
        jobInput.Parent = jobRow
        Instance.new("UICorner", jobInput).CornerRadius = UDim.new(0, 10)
        local jobInputStroke = Instance.new("UIStroke")
        jobInputStroke.Color = Theme.AccentMuted
        jobInputStroke.Parent = jobInput

        local joinJobButton = Instance.new("TextButton")
        joinJobButton.Size = UDim2.new(0.30, 0, 1, 0)
        joinJobButton.Position = UDim2.new(0.70, 0, 0, 0)
        joinJobButton.BackgroundColor3 = Theme.Panel
        joinJobButton.BorderSizePixel = 0
        joinJobButton.Font = Enum.Font.GothamBold
        joinJobButton.Text = "Join Job ID"
        joinJobButton.TextColor3 = Theme.AccentLightYellow
        joinJobButton.TextSize = 12
        joinJobButton.Parent = jobRow
        Instance.new("UICorner", joinJobButton).CornerRadius = UDim.new(0, 10)
        local joinJobStroke = Instance.new("UIStroke")
        joinJobStroke.Color = Theme.AccentLightYellow
        joinJobStroke.Parent = joinJobButton

        local buttons = Instance.new("Frame")
        buttons.Size = UDim2.new(1, 0, 0, 36)
        buttons.Position = UDim2.new(0, 0, 0, 173)
        buttons.BackgroundTransparency = 1
        buttons.Parent = content

        local function makeButton(text, x, width)
            local button = Instance.new("TextButton")
            button.Size = UDim2.new(width or 0.23, 0, 1, 0)
            button.Position = UDim2.new(x, 0, 0, 0)
            button.BackgroundColor3 = Theme.Panel
            button.BorderSizePixel = 0
            button.Font = Enum.Font.GothamBold
            button.Text = text
            button.TextColor3 = Theme.TextMain
            button.TextSize = 11
            button.Parent = buttons
            Instance.new("UICorner", button).CornerRadius = UDim.new(0, 10)
            local stroke = Instance.new("UIStroke")
            stroke.Color = Theme.AccentMuted
            stroke.Parent = button
            return button, stroke
        end

        local resetButton = makeButton("Refresh", 0, 0.23)
        local rejoinButton = makeButton("Rejoin", 0.255, 0.23)
        local fewestButton = makeButton("Fewest", 0.51, 0.23)
        local autoButton, autoStroke = makeButton("Auto: OFF", 0.765, 0.235)
        autoButton.TextColor3 = Theme.RedCancel
        autoStroke.Color = Theme.RedCancel

        local listContainer = Instance.new("Frame")
        listContainer.Size = UDim2.new(1, 0, 1, -221)
        listContainer.Position = UDim2.new(0, 0, 0, 221)
        listContainer.BackgroundColor3 = Theme.Panel
        listContainer.BorderSizePixel = 0
        listContainer.Parent = content
        Instance.new("UICorner", listContainer).CornerRadius = UDim.new(0, 12)
        local listStroke = Instance.new("UIStroke")
        listStroke.Color = Theme.AccentMuted
        listStroke.Parent = listContainer

        local list = Instance.new("ScrollingFrame")
        list.Size = UDim2.new(1, -16, 1, -16)
        list.Position = UDim2.new(0, 8, 0, 8)
        list.BackgroundTransparency = 1
        list.BorderSizePixel = 0
        list.CanvasSize = UDim2.new(0, 0, 0, 0)
        list.ScrollBarThickness = 3
        list.ScrollBarImageColor3 = Theme.AccentLightYellow
        list.Parent = listContainer
        local listLayout = Instance.new("UIListLayout")
        listLayout.SortOrder = Enum.SortOrder.LayoutOrder
        listLayout.Padding = UDim.new(0, 6)
        listLayout.Parent = list

        local notifyFrame = Instance.new("Frame")
        notifyFrame.Size = UDim2.new(0, 260, 0, 45)
        notifyFrame.Position = UDim2.new(0, 16, 1, 80)
        notifyFrame.BackgroundColor3 = Theme.Background
        notifyFrame.BorderSizePixel = 0
        notifyFrame.Parent = gui
        Instance.new("UIStroke", notifyFrame).Color = Theme.AccentLightYellow
        Instance.new("UICorner", notifyFrame).CornerRadius = UDim.new(0, 12)
        local notifyLabel = Instance.new("TextLabel")
        notifyLabel.Size = UDim2.new(1, -24, 1, 0)
        notifyLabel.Position = UDim2.new(0, 12, 0, 0)
        notifyLabel.BackgroundTransparency = 1
        notifyLabel.Font = Enum.Font.GothamMedium
        notifyLabel.Text = ""
        notifyLabel.TextColor3 = Theme.AccentLightYellow
        notifyLabel.TextSize = 13
        notifyLabel.TextXAlignment = Enum.TextXAlignment.Left
        notifyLabel.Parent = notifyFrame

        local servers = {}
        local expanded = false

        local function notifyLeft(text)
            notifyLabel.Text = tostring(text)
            services.TweenService:Create(notifyFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Position = UDim2.new(0, 16, 1, -60)
            }):Play()
            task.delay(3, function()
                if notifyFrame.Parent then
                    services.TweenService:Create(notifyFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
                        Position = UDim2.new(0, 16, 1, 80)
                    }):Play()
                end
            end)
        end

        local function getHopServers()
            servers = {}
            local cursor = ""
            local fetchedCount = 0
            for _ = 1, 5 do
                local url = "https://games.roblox.com/v1/games/" .. tostring(game.PlaceId) .. "/servers/Public?sortOrder=Asc&limit=100"
                if cursor ~= "" then url = url .. "&cursor=" .. services.HttpService:UrlEncode(cursor) end
                local body = HUB.ServerHopRequest(url)
                if not body then break end
                local ok, data = pcall(services.HttpService.JSONDecode, services.HttpService, body)
                if not ok or type(data) ~= "table" then break end
                for _, server in ipairs(data.data or {}) do
                    local id = tostring(server.id or "")
                    local playing = tonumber(server.playing) or 0
                    local maxPlayers = tonumber(server.maxPlayers) or 0
                    if id ~= "" and id ~= tostring(game.JobId) and playing < maxPlayers then
                        servers[#servers + 1] = {id = id, playing = playing, maxPlayers = maxPlayers}
                        fetchedCount += 1
                        if fetchedCount >= 100 then break end
                    end
                end
                cursor = tostring(data.nextPageCursor or "")
                if cursor == "" or fetchedCount >= 100 then break end
            end
        end

        local function joinFewestServer()
            if #servers == 0 then
                getHopServers()
            end
            local target = nil
            for _, server in ipairs(servers) do
                if type(server) == "table" and server.id then
                    if not target or (tonumber(server.playing) or math.huge) < (tonumber(target.playing) or math.huge) then
                        target = server
                    end
                end
            end
            if not target then
                notifyLeft("No open server found")
                return false
            end
            notifyLeft("Fewest Server · " .. tostring(target.playing) .. "/" .. tostring(target.maxPlayers))
            local ok, err = HUB.JoinServer(game.PlaceId, target.id)
            if not ok then
                notifyLeft("Fewest Server failed")
            end
            return ok
        end

        local function rebuildList()
            for _, child in ipairs(list:GetChildren()) do
                if child:IsA("Frame") then child:Destroy() end
            end
            for i, server in ipairs(servers) do
                local row = Instance.new("Frame")
                row.Size = UDim2.new(1, -8, 0, 42)
                row.BackgroundColor3 = Theme.Background
                row.BorderSizePixel = 0
                row.Parent = list
                Instance.new("UICorner", row).CornerRadius = UDim.new(0, 10)
                local rowStroke = Instance.new("UIStroke")
                rowStroke.Color = Theme.AccentMuted
                rowStroke.Transparency = 0.45
                rowStroke.Parent = row

                local label = Instance.new("TextLabel")
                label.Size = UDim2.new(1, -82, 1, 0)
                label.Position = UDim2.new(0, 12, 0, 0)
                label.BackgroundTransparency = 1
                label.Font = Enum.Font.GothamMedium
                label.Text = "Server " .. tostring(i) .. " · " .. tostring(server.playing) .. "/" .. tostring(server.maxPlayers)
                label.TextColor3 = Theme.TextMain
                label.TextSize = 12
                label.TextXAlignment = Enum.TextXAlignment.Left
                label.Parent = row

                local join = Instance.new("TextButton")
                join.Size = UDim2.new(0, 60, 0, 26)
                join.Position = UDim2.new(1, -68, 0.5, -13)
                join.BackgroundColor3 = Theme.Panel
                join.BorderSizePixel = 0
                join.Font = Enum.Font.GothamBold
                join.Text = "Join"
                join.TextColor3 = Theme.AccentLightYellow
                join.TextSize = 12
                join.Parent = row
                Instance.new("UICorner", join).CornerRadius = UDim.new(0, 8)
                local joinStroke = Instance.new("UIStroke")
                joinStroke.Color = Theme.AccentLightYellow
                joinStroke.Parent = join

                join.MouseButton1Click:Connect(function()
                    notifyLeft("Joining Safe Server...")
                    HUB.JoinServer(game.PlaceId, server.id)
                end)
            end
            list.CanvasSize = UDim2.new(0, 0, 0, math.max(0, #servers * 48))
        end

        joinJobButton.MouseButton1Click:Connect(function()
            local jobId = tostring(jobInput.Text or ""):gsub("^%s+", ""):gsub("%s+$", "")
            if jobId == "" then
                notifyLeft("Enter a Job ID first")
                return
            end
            notifyLeft("Joining Job ID...")
            task.spawn(function()
                local ok, err = HUB.JoinServer(game.PlaceId, jobId)
                if not ok then
                    notifyLeft("Join failed: " .. tostring(err or "unknown error"))
                end
            end)
        end)

        fewestButton.MouseButton1Click:Connect(function()
            notifyLeft("Scanning Fewest Server...")
            task.spawn(function()
                getHopServers()
                joinFewestServer()
            end)
        end)

        resetButton.MouseButton1Click:Connect(function()
            notifyLeft("Scanning Safe Servers...")
            task.spawn(function()
                getHopServers()
                rebuildList()
                notifyLeft("Found " .. tostring(#servers) .. " servers")
            end)
        end)

        rejoinButton.MouseButton1Click:Connect(function()
            notifyLeft("Rejoining Game...")
            pcall(function()
                services.TeleportService:Teleport(game.PlaceId, LP)
            end)
        end)

        autoButton.MouseButton1Click:Connect(function()
            local state = HUB.ServerHopState
            state.AutoHop = not state.AutoHop
            if state.AutoHop then
                state.AutoEnabledAt = os.clock()
                state.LastHopAt = os.clock()
                autoButton.Text = "Auto: ON"
                autoButton.TextColor3 = Theme.Background
                autoButton.BackgroundColor3 = Theme.GreenActive
                autoStroke.Color = Theme.GreenActive
                notifyLeft("Auto Hop Active · " .. tostring(state.HopDelay) .. "s")
            else
                state.Busy = false
                autoButton.Text = "Auto: OFF"
                autoButton.TextColor3 = Theme.RedCancel
                autoButton.BackgroundColor3 = Theme.Panel
                autoStroke.Color = Theme.RedCancel
                notifyLeft("Auto Hop Inactive")
            end
        end)

        toggle.MouseButton1Click:Connect(function()
            expanded = not expanded
            if expanded then
                toggle.Text = "-"
                islandCorner.CornerRadius = UDim.new(0, 16)
                services.TweenService:Create(island, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                    Size = UDim2.new(0, 400, 0, 520),
                    Position = UDim2.new(0.5, -200, 0, 16)
                }):Play()
                task.wait(0.05)
                content.Visible = true
            else
                toggle.Text = "+"
                content.Visible = false
                services.TweenService:Create(island, TweenInfo.new(0.4, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                    Size = UDim2.new(0, 220, 0, 48),
                    Position = UDim2.new(0.5, -110, 0, 16)
                }):Play()
                task.wait(0.2)
                islandCorner.CornerRadius = UDim.new(1, 0)
            end
        end)

        task.spawn(function()
            getHopServers()
            rebuildList()
            while gui.Parent and not HUB.dead do
                local state = HUB.ServerHopState
                autoButton.Text = state.AutoHop and "Auto: ON" or "Auto: OFF"
                if state.AutoHop then
                    autoButton.TextColor3 = Theme.Background
                    autoButton.BackgroundColor3 = Theme.GreenActive
                    autoStroke.Color = Theme.GreenActive
                else
                    autoButton.TextColor3 = Theme.RedCancel
                    autoButton.BackgroundColor3 = Theme.Panel
                    autoStroke.Color = Theme.RedCancel
                end
                task.wait(0.25)
            end
        end)

        return gui
    end
end

-- -----------------------------------------------------------------------------
-- SERVER TAB
-- -----------------------------------------------------------------------------
do
    local ServerHopSub = ServerTab:AddSubTab("Server Hop")
    local ServerHopStatus = ServerHopSub:AddParagraph({
        Title = "Server Hop",
        Content = "0 hops this session · waiting",
    })

    ServerHopSub:AddToggle({
        Name = "Enable Auto Server Hop",
        Default = false,
        Flag = "server_autohop",
        Callback = safeCallback(function(v)
            local state = HUB.ServerHopState
            state.AutoHop = v == true
            if state.AutoHop then
                state.AutoEnabledAt = os.clock()
                state.LastHopAt = os.clock()
            else
                state.Busy = false
            end
            if state.HopCount >= state.MaxHops then
                state.AutoHop = false
            end
        end)
    })

    ServerHopSub:AddToggle({
        Name = "Hop on No Matching Egg",
        Default = false,
        Flag = "server_hop_no_match",
        Callback = function(v)
            HUB.ServerHopState.HopOnNoMatch = v == true
        end,
    })

    ServerHopSub:AddSlider({
        Name = "Max Hops",
        Min = 1,
        Max = 100,
        Default = HUB.ServerHopState.MaxHops,
        Suffix = "",
        Flag = "server_max_hops",
        Callback = function(v)
            HUB.ServerHopState.MaxHops = math.max(1, math.floor(tonumber(v) or 1))
            if HUB.ServerHopState.HopCount >= HUB.ServerHopState.MaxHops then
                HUB.ServerHopState.AutoHop = false
            end
        end,
    })

    ServerHopSub:AddSlider({
        Name = "Check Delay",
        Min = 5,
        Max = 120,
        Default = HUB.ServerHopState.HopDelay,
        Suffix = "s",
        Flag = "server_hop_delay",
        Callback = function(v)
            HUB.ServerHopState.HopDelay = math.max(5, math.floor(tonumber(v) or 5))
        end,
    })

    ServerHopSub:AddButton({
        Name = "Open Axel Hub Server Hop",
        Primary = true,
        Callback = safeCallback(function()
            HUB.OpenServerHopGui()
        end),
    })

    ServerHopSub:AddButton({
        Name = "Server Hop Now",
        Callback = safeCallback(function()
            task.spawn(function()
                local ok, msg = HUB.HopOnce()
                Notify("Server Hop", tostring(msg or (ok and "Teleporting." or "Failed")), ok and "Success" or "Error")
            end)
        end)
    })

    ServerHopSub:AddButton({
        Name = "Rejoin Current Server",
        Callback = safeCallback(function()
            local ok, err = HUB.JoinServer(game.PlaceId, game.JobId)
            if not ok then Notify("Server", tostring(err), "Error") end
        end)
    })

    task.spawn(function()
        while not HUB.dead do
            task.wait(0.5)
            if ServerHopStatus and ServerHopStatus.Set then
                local state = HUB.ServerHopState
                local suffix = state.HopCount == 1 and " hop" or " hops"
                local mode = state.HopOnNoMatch and "no-match" or "manual"
                local enabled = state.AutoHop and "on" or "off"
                pcall(ServerHopStatus.Set, ServerHopStatus, enabled .. " · " .. tostring(state.HopCount) .. suffix .. " · " .. mode)
            end
        end
    end)
end

-- -----------------------------------------------------------------------------
-- TAB 1: EGGS
-- -----------------------------------------------------------------------------
local StealSub = EggsTab:AddSubTab("Auto Steal")
local HatchSub = EggsTab:AddSubTab("Auto Hatch & Plant")
local EggEspSub = EggsTab:AddSubTab("Egg Tracker ESP")

-- SubTab: Auto Steal
StealSub:AddToggle({
    Name = "Auto Steal Eggs", Default = false, Flag = "steal_auto",
    Callback = safeCallback(function(v)
        autoStealEnabled = v
        if v then
            EnsureSavedReturnPosition()
            -- Do not disable Auto Treadmill. When both are ON, the treadmill
            -- controller will steal matching eggs and resume training when none exist.
            if autoTreadmillEnabled and not isPlayerCarryingEgg() then
                task.spawn(function()
                    task.wait(0.05)
                    HandleAutoTreadmillHandoff()
                end)
            end
        elseif autoTreadmillEnabled and not isPlayerCarryingEgg() then
            task.spawn(function()
                task.wait(0.05)
                HandleAutoTreadmillHandoff()
            end)
        end
        Notify("Auto Steal", v and "Enabled" or "Disabled", v and "Success" or "Error")
    end)
})
StealSub:AddDropdown({
    Name = "Steal Movement Method", Options = { "Tween Glide", "Fly Glide", "Safe Walk", "Anti Guard" }, Default = "Tween Glide", Flag = "steal_method",
    Callback = function(v) stealMovementMethod = v end
})
StealSub:AddToggle({
    Name = "Steal Infested / Parasite Eggs Only", Default = false, Flag = "steal_parasite_only",
    Callback = function(v)
        stealParasiteOnly = v
        Notify("Parasite Eggs", v and "Targeting Infested Eggs Only" or "All Filtered Eggs", v and "Success" or "Info")
    end
})
StealSub:AddToggle({
    Name = "Rare Egg Hunter (Highest Rarity First)", Default = true, Flag = "rare_hunter",
    Callback = function(v) rareEggHunter = v end
})
StealSub:AddMultiDropdown({
    Name = "Filter by Rarity (Multi-Select)", Options = RARITY_NAMES, Default = {}, Flag = "steal_rarities",
    Callback = function(selectedList) selectedStealRarities = selectedList end
})
StealSub:AddMultiDropdown({
    Name = "Filter by Area (Multi-Select)", Options = AREA_NAMES, Default = {}, Flag = "steal_areas",
    Callback = function(selectedList) selectedStealAreas = selectedList end
})
StealSub:AddMultiDropdown({
    Name = "Filter by Mutation (Multi-Select)", Options = MUTATION_FILTERS, Default = {}, Flag = "steal_muts",
    Callback = function(selectedList) selectedMutationTypes = selectedList end
})
StealSub:AddSlider({
    Name = "Glide / Travel Speed", Min = 50, Max = 750, Default = 750, Suffix = " studs/s", Flag = "glide_speed",
    Callback = function(v) glideSpeed = tonumber(v) or 750 end
})
StealSub:AddSlider({
    Name = "Steal Delay Gap", Min = 0.5, Max = 10, Default = 1.5, Suffix = "s", Flag = "steal_gap",
    Callback = function(v) stealDelay = v end
})
StealSub:AddButton({
    Name = "Steal Best Available Egg Once", Primary = true,
    Callback = safeCallback(function()
        local ok = StealBestEggOnce()
        Notify("Steal Egg", ok and "Stealing target egg" or "No matching egg found for selected filters", ok and "Success" or "Info")
    end)
})

-- SubTab: Auto Hatch & Plant
HatchSub:AddToggle({
    Name = "Auto Hatch Ready Eggs", Default = false, Flag = "hatch_auto",
    Callback = safeCallback(function(v)
        autoHatchEnabled = v
        Notify("Auto Hatch", v and "Enabled" or "Disabled", v and "Success" or "Error")
    end)
})
HatchSub:AddToggle({
    Name = "Auto Place Egg (Base Pen)", Default = false, Flag = "plant_auto",
    Callback = function(v)
        autoPlantEnabled = v
        Notify("Auto Place Egg", v and "Enabled" or "Disabled", v and "Success" or "Error")
    end
})
HatchSub:AddSlider({
    Name = "Hatch Check Delay", Min = 0.5, Max = 10, Default = 2.0, Suffix = "s", Flag = "hatch_gap",
    Callback = function(v) hatchCheckDelay = v end
})
HatchSub:AddButton({
    Name = "Hatch All Ready Eggs Now", Primary = true,
    Callback = safeCallback(function()
        local count = HatchAllReadyEggs() or 0
        Notify("Hatch", "Hatched " .. tostring(count) .. " egg(s)", count > 0 and "Success" or "Info")
    end)
})
HatchSub:AddButton({
    Name = "Place Carried Eggs in Pen Now",
    Callback = safeCallback(function()
        local count = PlantAllCarriedEggsInPen()
        Notify("Plant Eggs", "Planted " .. count .. " egg(s) in pen", "Success")
    end)
})

-- SubTab: Egg Tracker ESP
EggEspSub:AddToggle({
    Name = "Egg ESP Enabled", Default = false, Flag = "esp_eggs_enabled",
    Callback = safeCallback(function(v)
        esp.enabled = v
        Notify("Egg ESP", v and "Enabled" or "Disabled", v and "Success" or "Error")
    end)
})
EggEspSub:AddToggle({
    Name = "Show 3D Pet Image Badges", Default = true, Flag = "esp_pet_icons",
    Callback = function(v) esp.showPetIcons = v end
})
EggEspSub:AddToggle({
    Name = "Trap ESP (Highlights Enemy Traps)", Default = false, Flag = "esp_traps",
    Callback = function(v) esp.traps = v end
})
EggEspSub:AddToggle({
    Name = "Show Mutated / Rare Eggs Only", Default = false, Flag = "esp_eggs_rare_only",
    Callback = function(v) esp.rareEggsOnly = v end
})
EggEspSub:AddSlider({
    Name = "Max ESP Distance", Min = 100, Max = 2500, Default = 800, Suffix = " studs", Flag = "esp_max_dist",
    Callback = function(v) esp.maxDistance = v end
})

-- -----------------------------------------------------------------------------
-- TAB 2: BASE & UPGRADES
-- -----------------------------------------------------------------------------
do
local UpgradesSub = BaseTab:AddSubTab("Homestead & Treadmill")
local PetsSub     = BaseTab:AddSubTab("Pets & Satchel")
local SalesSub    = BaseTab:AddSubTab("Auto Sell")
local EventsSub   = BaseTab:AddSubTab("Events & Bosses")
local RewardsSub  = BaseTab:AddSubTab("Claim Rewards")

-- SubTab: Homestead & Treadmill
UpgradesSub:AddToggle({
    Name = "Auto Upgrade Base / Plot", Default = false, Flag = "up_base_auto",
    Callback = function(v) autoUpgradeBase = v end
})
UpgradesSub:AddToggle({
    Name = "Auto Upgrade Treadmill Tier", Default = false, Flag = "up_tread_auto",
    Callback = function(v) autoUpgradeTreadmill = v end
})
UpgradesSub:AddToggle({
    Name = "Auto Treadmill", Default = false, Flag = "auto_treadmill",
    Callback = safeCallback(function(v)
        autoTreadmillEnabled = v == true
        if not autoTreadmillEnabled then
            StopTreadmillTraining()
        else
            if autoStealEnabled then
                EnsureSavedReturnPosition()
            end
            if not isPlayerCarryingEgg() then
                task.spawn(function()
                    task.wait(0.15)
                    HandleAutoTreadmillHandoff()
                end)
            end
        end
        Notify("Auto Treadmill", autoTreadmillEnabled and "Enabled" or "Disabled", autoTreadmillEnabled and "Success" or "Info")
    end)
})
UpgradesSub:AddToggle({
    Name = "Auto Buy Speed Trails", Default = false, Flag = "auto_buy_trails",
    Callback = function(v) autoBuyTrails = v end
})
UpgradesSub:AddButton({
    Name = "Upgrade Base Now", Primary = true,
    Callback = safeCallback(function()
        UpgradeHomesteadBase()
        Notify("Base Upgrade", "Requested base upgrade", "Success")
    end)
})
UpgradesSub:AddButton({
    Name = "Upgrade Treadmill Now",
    Callback = safeCallback(function()
        UpgradeTreadmillTier()
        Notify("Treadmill Upgrade", "Requested treadmill upgrade", "Success")
    end)
})

-- SubTab: Pets & Satchel
PetsSub:AddToggle({
    Name = "Auto Equip Best Pets", Default = false, Flag = "equip_best_pets",
    Callback = function(v) autoEquipBestPets = v end
})
PetsSub:AddButton({
    Name = "Equip Best Pets Now", Primary = true,
    Callback = safeCallback(function()
        EquipBestPets()
        Notify("Pets", "Equipped best pets", "Success")
    end)
})

-- SubTab: Auto Sell
SalesSub:AddToggle({
    Name = "Auto Sell Low-Tier Pets", Default = false, Flag = "auto_sell_pets",
    Callback = function(v) autoSellPets = v end
})
SalesSub:AddMultiDropdown({
    Name = "Filter Pet Sell Rarities", Options = RARITY_NAMES, Default = {}, Flag = "sell_pet_rarities",
    Callback = function(selectedList) selectedSellPetRarities = selectedList end
})
SalesSub:AddToggle({
    Name = "Auto Sell Low-Tier Eggs", Default = false, Flag = "auto_sell_eggs",
    Callback = function(v) autoSellEggs = v end
})
SalesSub:AddMultiDropdown({
    Name = "Filter Egg Sell Rarities", Options = RARITY_NAMES, Default = {}, Flag = "sell_egg_rarities",
    Callback = function(selectedList) selectedSellEggRarities = selectedList end
})
SalesSub:AddButton({
    Name = "Sell Selected Pets Now", Primary = true,
    Callback = safeCallback(function()
        SellSelectedPets()
        Notify("Sales", "Sold matching pets", "Success")
    end)
})
SalesSub:AddButton({
    Name = "Sell Selected Eggs Now",
    Callback = safeCallback(function()
        SellSelectedEggs()
        Notify("Sales", "Sold matching eggs", "Success")
    end)
})

-- SubTab: Events & Bosses
EventsSub:AddToggle({
    Name = "Auto Claim Monster Chests", Default = false, Flag = "auto_monster_chests",
    Callback = function(v) autoClaimMonsterChests = v end
})
EventsSub:AddToggle({
    Name = "Auto Feed Monster Parasite", Default = false, Flag = "auto_feed_monster",
    Callback = function(v) autoFeedMonster = v end
})
EventsSub:AddButton({
    Name = "Claim Monster Chest Now", Primary = true,
    Callback = safeCallback(function()
        ClaimMonsterChests()
        Notify("Monster Event", "Claimed monster chest", "Success")
    end)
})
EventsSub:AddButton({
    Name = "Feed Monster Parasite Now",
    Callback = safeCallback(function()
        FeedMonsterParasite()
        Notify("Monster Event", "Fed monster parasite", "Success")
    end)
})

-- SubTab: Claim Rewards
RewardsSub:AddToggle({
    Name = "Auto Claim Away Earnings & Codex", Default = false, Flag = "claim_auto_rewards",
    Callback = function(v) autoClaimRewards = v end
})
RewardsSub:AddButton({
    Name = "Claim Away Earnings & Codex Now", Primary = true,
    Callback = safeCallback(function()
        ClaimAllAvailableRewards()
        Notify("Rewards", "Claimed all ready rewards and earnings", "Success")
    end)
})
end

-- -----------------------------------------------------------------------------
-- TAB 3: COMBAT & DEFENSE
-- -----------------------------------------------------------------------------
do
local BatSub   = CombatTab:AddSubTab("Bat & Slap Aura")
local GuardSub = CombatTab:AddSubTab("Defense & Guards")

-- SubTab: Bat & Slap Aura
BatSub:AddToggle({
    Name = "Bat / Slap Aura", Default = false, Flag = "bat_aura_enabled",
    Callback = safeCallback(function(v)
        batAuraEnabled = v
        Notify("Bat Aura", v and "Enabled" or "Disabled", v and "Success" or "Error")
    end)
})
BatSub:AddSlider({
    Name = "Aura Radius", Min = 5, Max = 50, Default = 20, Suffix = " studs", Flag = "bat_radius",
    Callback = function(v) batAuraRadius = v end
})
BatSub:AddSlider({
    Name = "Swing Delay", Min = 0.05, Max = 1.0, Default = 0.2, Suffix = "s", Flag = "bat_delay",
    Callback = function(v) batAuraDelay = v end
})
BatSub:AddButton({
    Name = "Swing Bat Once (Manual)", Primary = true,
    Callback = safeCallback(function()
        local re = GetNetRemote("RE/BatSwing/Trigger")
        if re then re:FireServer() end
        Notify("Bat", "Triggered bat swing", "Info")
    end)
})

-- SubTab: Defense & Guards
GuardSub:AddToggle({
    Name = "Anti-Trap (Full Immunity / Destroy Hitboxes)", Default = true, Flag = "avoid_traps",
    Callback = safeCallback(function(v)
        avoidTrapsEnabled = v
        if v then pcall(NeutralizeTraps) end
        Notify("Anti-Trap", v and "Immunity Active (Enemy Hitboxes Destroyed)" or "Anti-Trap Disabled", v and "Success" or "Error")
    end)
})

GuardSub:AddToggle({
    Name = "No Knockback / Ragdoll Immunity", Default = true, Flag = "no_knockback",
    Callback = safeCallback(function(v)
        SetNoKnockback(v)
        Notify("Knockback", v and "Ragdoll Immunity Active" or "Knockback Enabled", v and "Success" or "Error")
    end)
})

GuardSub:AddToggle({
    Name = "Anti-Ragdoll (Quick Standup)", Default = true, Flag = "anti_ragdoll",
    Callback = function(v) antiRagdollEnabled = v end
})

track(RunService.Heartbeat:Connect(function()
    if HUB.dead or not antiRagdollEnabled then return end
    local hum = findHum()
    if hum and hum:GetState() == Enum.HumanoidStateType.Physics then
        hum:ChangeState(Enum.HumanoidStateType.GettingUp)
    end
end))
end

-- -----------------------------------------------------------------------------
-- TAB 4: PLAYER & MOVEMENT
-- -----------------------------------------------------------------------------
do
local MoveSub     = PlayerTab:AddSubTab("Movement")
local AreaTpSub   = PlayerTab:AddSubTab("Area Travel")
local PlotTpSub   = PlayerTab:AddSubTab("Plot Travel")
local PlayerTpSub = PlayerTab:AddSubTab("Player Travel")
local PerfSub     = PlayerTab:AddSubTab("Visuals & Performance")

-- SubTab: Movement
MoveSub:AddToggle({
    Name = "Enable WalkSpeed", Default = false, Flag = "speed_enabled",
    Callback = safeCallback(function(v)
        walkSpeedEnabled = v
        if not v then
            local hum = findHum()
            if hum then hum.WalkSpeed = 16 end
        end
        Notify("WalkSpeed", v and "Enabled" or "Disabled", v and "Success" or "Error")
    end)
})
MoveSub:AddSlider({
    Name = "WalkSpeed Value", Min = 16, Max = 10000, Default = 24, Suffix = " studs/s", Flag = "speed_val",
    Callback = function(v) ApplyWalkSpeed(v) end
})
MoveSub:AddToggle({
    Name = "Enable JumpPower", Default = false, Flag = "jump_enabled",
    Callback = safeCallback(function(v)
        jumpPowerEnabled = v
        if not v then
            local hum = findHum()
            if hum then hum.JumpPower = 50 end
        end
        Notify("JumpPower", v and "Enabled" or "Disabled", v and "Success" or "Error")
    end)
})
MoveSub:AddSlider({
    Name = "JumpPower Value", Min = 50, Max = 300, Default = 60, Suffix = "", Flag = "jump_val",
    Callback = function(v) ApplyJumpPower(v) end
})
MoveSub:AddToggle({
    Name = "Infinite Jump", Default = false, Flag = "inf_jump",
    Callback = function(v) infiniteJump = v end
})
MoveSub:AddToggle({
    Name = "Smooth Fly (WASD + Space/Shift)", Default = false, Flag = "fly_enabled",
    Callback = safeCallback(function(v)
        if v then startFly() else stopFly() end
        Notify("Fly", v and "Enabled" or "Disabled", v and "Success" or "Error")
    end)
})
MoveSub:AddSlider({
    Name = "Fly Speed", Min = 20, Max = 250, Default = 60, Suffix = " studs/s", Flag = "fly_speed",
    Callback = function(v) flySpeed = v end
})
MoveSub:AddToggle({
    Name = "Anti-AFK (Bypass 20min Kick)", Default = false, Flag = "anti_afk",
    Callback = function(v) SetAntiAFK(v) end
})

-- SubTab: Area Travel
local selectedAreaTp = "Base / Plot"
local areaKeys = {}
for k in pairs(AREA_COORDINATES) do table.insert(areaKeys, k) end
table.sort(areaKeys)

AreaTpSub:AddDropdown({
    Name = "Select Area", Options = areaKeys, Items = areaKeys, Default = "Base / Plot", Flag = "tele_area",
    Callback = function(v) selectedAreaTp = v end
})
AreaTpSub:AddButton({
    Name = "Travel to Selected Area", Primary = true,
    Callback = safeCallback(function()
        local pos = AREA_COORDINATES[selectedAreaTp]
        if selectedAreaTp == "Base / Plot" then
            pos = GetLocalPlotCenter()
        end
        if pos then
            Notify("Travel", "Traveling to " .. selectedAreaTp, "Info")
            TravelRoadPath(pos, glideSpeed or 200)
            Notify("Travel", "Arrived at " .. selectedAreaTp, "Success")
        else
            Notify("Travel", "Area position not found", "Error")
        end
    end)
})

-- SubTab: Plot Travel
local selectedPlotNum = "Plot 1"
local plotOptions = { "Plot 1", "Plot 2", "Plot 3", "Plot 4", "Plot 5", "Plot 6", "Plot 7", "My Plot" }

PlotTpSub:AddDropdown({
    Name = "Select Plot", Options = plotOptions, Items = plotOptions, Default = "My Plot", Flag = "tele_plot",
    Callback = function(v) selectedPlotNum = v end
})
PlotTpSub:AddButton({
    Name = "Travel to Plot", Primary = true,
    Callback = safeCallback(function()
        local slotNum = selectedPlotNum == "My Plot" and GetLocalSlot() or tonumber(selectedPlotNum:match("%d+")) or 1
        local plot = Workspace.Plots:FindFirstChild(tostring(slotNum))
        local targetPos = plot and (plot:FindFirstChild("CenterPoint") and plot.CenterPoint.Position or plot:GetPivot().Position)
        if targetPos then
            TravelRoadPath(targetPos + Vector3.new(0, 2, 0), glideSpeed or 200)
            Notify("Plot", "Arrived at Plot " .. tostring(slotNum), "Success")
        else
            Notify("Plot", "Plot not found", "Error")
        end
    end)
})

do
    local _setupPlayerTravel = function()
    -- SubTab: Player Travel
    local selectedPlayerName = nil
    local function GetPlayerList()
        local names = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP then table.insert(names, p.Name) end
        end
        table.sort(names)
        if #names == 0 then names = { "(no other players)" } end
        return names
    end

    local playerDropdown = PlayerTpSub:AddDropdown({
        Name = "Select Player", Options = GetPlayerList(), Items = GetPlayerList(), Default = nil, Flag = "tele_plr",
        Callback = function(v) selectedPlayerName = v end
    })

    PlayerTpSub:AddButton({
        Name = "Refresh Player List",
        Callback = function()
            playerDropdown:SetOptions(GetPlayerList())
            Notify("Players", "Refreshed player list", "Info")
        end
    })
    PlayerTpSub:AddButton({
        Name = "Travel to Player", Primary = true,
        Callback = safeCallback(function()
            if not selectedPlayerName then return end
            local targetPlr = Players:FindFirstChild(selectedPlayerName)
            local tHrp = targetPlr and targetPlr.Character and targetPlr.Character:FindFirstChild("HumanoidRootPart")
            if tHrp then
                TravelRoadPath(tHrp.Position + Vector3.new(0, 2, 0), glideSpeed or 200)
                Notify("Player", "Arrived at " .. selectedPlayerName, "Success")
            else
                Notify("Player", "Player unavailable", "Error")
            end
        end)
    })

    end
    _setupPlayerTravel()
end

-- SubTab: Visuals & Performance
PerfSub:AddToggle({
    Name = "Fullbright (Daylight Visuals)", Default = false, Flag = "fullbright",
    Callback = function(v) SetFullbright(v) end
})
PerfSub:AddButton({
    Name = "Delete Own Pet Renders (FPS Boost)", Primary = true,
    Callback = safeCallback(function()
        local count = DeleteOwnPetRenders()
        Notify("Performance", "Removed " .. count .. " rendered pet model(s)", "Success")
    end)
})
end


-- =============================================================================
-- ==============================================================================
-- AXEL HUB WEBHOOK TAB
-- Scoped separately to avoid Luau's 200-local-register limit.
-- ==============================================================================
(function()
    local axelWebhookUrl = ""
    local axelWebhookEnabled = false
    local webhookNotifyAnimal = true
    local webhookNotifyRarity = true
    local webhookNotifyEgg = true
    local webhookNotifyCount = true
    local webhookStealCount = 0

    local function GetAxelWebhookRequest()
        return (syn and syn.request)
            or (http and http.request)
            or http_request
            or request
    end

    local function PostAxelWebhook(payload, force)
        if type(payload) ~= "table" then
            return false, "invalid payload"
        end

        if not force and not axelWebhookEnabled then
            return false, "webhook disabled"
        end

        local url = tostring(axelWebhookUrl or "")
        if url == "" or not url:match("^https://discord%.com/api/webhooks/")
           and not url:match("^https://discordapp%.com/api/webhooks/") then
            return false, "invalid webhook URL"
        end

        local req = GetAxelWebhookRequest()
        if type(req) ~= "function" then
            return false, "HTTP request function unavailable"
        end

        local okEncode, body = pcall(function()
            return game:GetService("HttpService"):JSONEncode(payload)
        end)
        if not okEncode then
            return false, "JSON encode failed"
        end

        local okRequest, response = pcall(function()
            return req({
                Url = url,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = body,
            })
        end)

        if not okRequest then
            return false, tostring(response)
        end

        local status = type(response) == "table" and tonumber(response.StatusCode)
        if status and status >= 400 then
            return false, "HTTP " .. tostring(status)
        end

        return true, response
    end

    -- Axel Hub logo from the URL supplied by the user.
    local AXEL_WEBHOOK_LOGO =
        "https://media.discordapp.net/attachments/1474749204973883508/1474749350461706361/axel_hub_2.png?ex=6aa2a6dc&is=6aa1555c&hm=a231cf00e3ecedb25eced50aec0042af2e1373be8298348665fa689d63acbbe2&=&format=webp&quality=lossless"

    -- Bottom banner/background.
    -- IMPORTANT: Discord needs a DIRECT image URL here (GIF/PNG/JPG/WEBP).
    -- A Canva share page such as canva.link/... is not an image URL and will not render.
    -- Put your animated GIF/WebP CDN URL here after uploading it somewhere public.
    local AXEL_WEBHOOK_BANNER = "https://www.image2url.com/r2/default/gifs/1788963639200-c2fed6c8-1d70-4d0a-9c80-6a6daec994aa.gif"

    -- Emoji used in the embed. Unicode emoji render reliably in Discord webhooks.
    -- The discord.com/assets/...svg links are not embeddable image markdown inside
    -- normal embed text, so use Unicode or Discord custom emoji syntax instead.
    local AXEL_EMOJI = {
        Egg      = "🥚",
        Animal   = "🐾",
        Rarity   = "💎",
        Score    = "🌟",
        Mutation = "🧬",
        Area     = "📍",
        Count    = "📦",
        Discord  = "🔗",
        Check    = "✅",
    }

    -- Discord embed color is driven by rarity.
    local RARITY_WEBHOOK_COLORS = {
        Titan        = 0xFF2D55,
        Divine       = 0xFF1493,
        Transcendent = 0xFF1493,
        Superior     = 0xFF1493,
        Eternal      = 0x8B5CF6,
        Limited      = 0xF43F5E,
        Secret       = 0x7C3AED,
        Exotic       = 0xA855F7,
        Cosmic       = 0x06B6D4,
        Exclusive    = 0x14B8A6,
        Admin        = 0xEF4444,
        Mythic       = 0xEC4899,
        Mythical     = 0xEC4899,
        Prismatic    = 0xF59E0B,
        Rainbow      = 0xF59E0B,
        ["Squishy God"] = 0xF59E0B,
        BrainrotGod  = 0xF59E0B,
        Legendary    = 0xFBBF24,
        Epic         = 0xA855F7,
        Rare         = 0x3B82F6,
        SuperRare    = 0x60A5FA,
        Celestial    = 0x22D3EE,
        Uncommon     = 0x22C55E,
        Basic        = 0x94A3B8,
        Common       = 0x9CA3AF,
        Unknown      = 0x6B7280,
    }

    local function GetWebhookRarityColor(rarity)
        local name = tostring(rarity or "Unknown")
        local key = RARITY_WEBHOOK_COLORS[name] and name
        if key then
            return RARITY_WEBHOOK_COLORS[key]
        end

        local lower = string.lower(name)
        for rarityName, color in pairs(RARITY_WEBHOOK_COLORS) do
            if string.lower(rarityName) == lower then
                return color
            end
        end

        return RARITY_WEBHOOK_COLORS.Unknown
    end

    local function BuildWebhookEmbed(title, description, fields, color)
        local embed = {
            author = {
                name = "AXEL HUB",
                icon_url = AXEL_WEBHOOK_LOGO,
            },
            title = tostring(title),
            description = tostring(description),
            color = tonumber(color) or 0xFFC107,
            fields = fields or {},
            footer = {
                text = "Axel Hub  •  Steal an Egg",
                icon_url = AXEL_WEBHOOK_LOGO,
            },
            thumbnail = {
                url = AXEL_WEBHOOK_LOGO,
            },
            timestamp = DateTime.now():ToIsoDate(),
        }

        -- Discord renders embed.image BELOW the fields, which matches the
        -- bottom-banner look in your reference. Animated GIF/WebP can animate
        -- there when the URL points directly to the media file.
        if type(AXEL_WEBHOOK_BANNER) == "string"
            and AXEL_WEBHOOK_BANNER ~= ""
            and (
                AXEL_WEBHOOK_BANNER:match("%.gif([?#]|$)")
                or AXEL_WEBHOOK_BANNER:match("%.webp([?#]|$)")
                or AXEL_WEBHOOK_BANNER:match("%.png([?#]|$)")
                or AXEL_WEBHOOK_BANNER:match("%.jpe?g([?#]|$)")
                or AXEL_WEBHOOK_BANNER:match("^https?://")
            ) then
            embed.image = {
                url = AXEL_WEBHOOK_BANNER,
            }
        end

        return {
            username = "Axel Hub",
            avatar_url = AXEL_WEBHOOK_LOGO,
            embeds = { embed },
        }
    end

    local function GetAssetDisplayName(category)
        if type(category) ~= "string" or category == "" then
            return "Unknown"
        end
        if AssetsData then
            local dir = AssetsData.Directory or AssetsData
            local info = type(dir) == "table" and dir[category]
            if type(info) == "table" then
                local name = info.DisplayName or info.Name or info.PetName or info.AssetName
                if type(name) == "string" and name ~= "" then
                    return name
                end
            end
        end
        return category
    end

    local function GetTargetAnimalName(record)
        if type(record) ~= "table" then
            return "Unknown"
        end

        local direct = record.AnimalName or record.PetName or record.Animal
            or record.ContainedAnimal or record.ResultName
        if type(direct) == "string" and direct ~= "" then
            return direct
        end

        return GetAssetDisplayName(record.AssetCategory or record.Category or record.Name)
    end

    local function GetTargetRarity(record)
        if type(record) ~= "table" then
            return "Unknown", 0
        end

        local ok, rarity, score = pcall(function()
            return GetEggRarityInfo(record)
        end)

        if ok then
            return tostring(rarity or "Common"), tonumber(score) or 100
        end

        return "Common", 100
    end

    local function GetTargetMutationText(record)
        if type(record) ~= "table" then
            return "Normal"
        end

        local mutations = record.Mutations
        if type(mutations) == "table" then
            local out = {}
            for _, mutation in ipairs(mutations) do
                if type(mutation) == "string" and mutation ~= "" then
                    table.insert(out, mutation)
                end
            end
            if #out > 0 then
                return table.concat(out, ", ")
            end
        end

        local mutation = record.Mutation or record.BaseMutation
        if type(mutation) == "string" and mutation ~= "" then
            return mutation
        end

        return "Normal"
    end

    local function SendAxelReady(force)
        return PostAxelWebhook(BuildWebhookEmbed(
            "[" .. AXEL_EMOJI.Check .. "] Webhook Connected",
            "",
            {
                { name = "Game", value = "Steal an Egg", inline = true },
                { name = "Player", value = tostring(LP.DisplayName or LP.Name), inline = true },
                { name = "Job ID", value = tostring(game.JobId), inline = false },
            },
            0xFFC107
        ), force)
    end

    -- This assigns the predeclared outer reference so the steal system can call it.
    SendEggStolenWebhook = function(targetItem)
        local record = targetItem and (targetItem.record or targetItem)
        if type(record) ~= "table" then
            return false, "missing egg record"
        end

        if not webhookNotifyAnimal and not webhookNotifyRarity
           and not webhookNotifyEgg and not webhookNotifyCount then
            return false, "all notifications disabled"
        end

        webhookStealCount += 1

        local rarity, score = GetTargetRarity(record)
        local animalName = GetTargetAnimalName(record)
        local mutationText = GetTargetMutationText(record)
        local eggName = GetAssetDisplayName(record.AssetCategory or record.EggName or record.Name)

        local fields = {}

        if webhookNotifyAnimal then
            table.insert(fields, {
                name = "[" .. AXEL_EMOJI.Animal .. "] Animal",
                value = tostring(animalName),
                inline = true,
            })
        end

        if webhookNotifyEgg then
            table.insert(fields, {
                name = "[" .. AXEL_EMOJI.Egg .. "] Egg",
                value = tostring(eggName),
                inline = true,
            })
        end

        if webhookNotifyRarity then
            table.insert(fields, {
                name = "[" .. AXEL_EMOJI.Rarity .. "] Rarity",
                value = tostring(rarity),
                inline = true,
            })
            table.insert(fields, {
                name = "[" .. AXEL_EMOJI.Score .. "] Score",
                value = tostring(math.floor(score)),
                inline = true,
            })
        end

        table.insert(fields, {
            name = "[" .. AXEL_EMOJI.Mutation .. "] Mutation",
            value = mutationText,
            inline = true,
        })

        table.insert(fields, {
            name = "[" .. AXEL_EMOJI.Area .. "] Area",
            value = tostring(record.AreaId or "Unknown"),
            inline = true,
        })

        if webhookNotifyCount then
            table.insert(fields, {
                name = "[" .. AXEL_EMOJI.Count .. "] Stolen Count",
                value = tostring(webhookStealCount),
                inline = true,
            })
        end

        table.insert(fields, {
            name = "[" .. AXEL_EMOJI.Discord .. "] Discord",
            value = "discord.gg/axelhub",
            inline = false,
        })

        return PostAxelWebhook(BuildWebhookEmbed(
            "AXEL HUB",
            "",
            fields,
            GetWebhookRarityColor(rarity)
        ))
    end

    local WebhookTab = Window:AddTab({
        Name = "Webhook",
        Subtitle = "Discord notifications",
        Icon = "!",
    })

    local WebhookMain = WebhookTab:AddSubTab("Webhook")
    local WebhookEvents = WebhookTab:AddSubTab("Notifications")

    WebhookMain:AddParagraph({
        Title = "Discord Webhook",
        Content = "Send a Discord notification when an egg is successfully collected.",
    })

    WebhookMain:AddInput({
        Name = "Webhook URL",
        Default = "",
        Flag = "axel_webhook_url",
        Callback = function(v)
            axelWebhookUrl = tostring(v or "")
        end,
    })

    WebhookMain:AddToggle({
        Name = "Enable Webhook",
        Default = false,
        Flag = "axel_webhook_enabled",
        Callback = function(v)
            axelWebhookEnabled = v == true
            Notify("Webhook", axelWebhookEnabled and "Enabled" or "Disabled",
                axelWebhookEnabled and "Success" or "Info")
        end,
    })

    WebhookMain:AddButton({
        Name = "Test Send Now",
        Primary = true,
        Callback = safeCallback(function()
            local ok, err = SendAxelReady(true)
            Notify("Webhook",
                ok and "Test sent successfully" or ("Send failed: " .. tostring(err)),
                ok and "Success" or "Error")
        end),
    })

    WebhookMain:AddDivider()

    WebhookEvents:AddToggle({
        Name = "Animal",
        Default = true,
        Flag = "webhook_animal",
        Callback = function(v) webhookNotifyAnimal = v == true end,
    })

    WebhookEvents:AddToggle({
        Name = "Rarity",
        Default = true,
        Flag = "webhook_rarity",
        Callback = function(v) webhookNotifyRarity = v == true end,
    })

    WebhookEvents:AddToggle({
        Name = "Egg",
        Default = true,
        Flag = "webhook_egg",
        Callback = function(v) webhookNotifyEgg = v == true end,
    })

    WebhookEvents:AddToggle({
        Name = "Stolen Count",
        Default = true,
        Flag = "webhook_count",
        Callback = function(v) webhookNotifyCount = v == true end,
    })
end)()

-- -----------------------------------------------------------------------------
-- TAB 5: SETTINGS & CONFIG
-- -----------------------------------------------------------------------------
do
local ConfigSub = SettingsTab:AddSubTab("Configuration")

if HAS_CONFIG then
    ConfigSub:AddInput({
        Name = "Config Name", Default = CONFIG_NAME, Flag = "cfg_name",
        Callback = function(v) if v and #v > 0 then CONFIG_NAME = v end end
    })
    ConfigSub:AddButton({
        Name = "Save Config", Primary = true,
        Callback = safeCallback(function()
            local ok, err = Library:SaveConfig(CONFIG_NAME)
            Notify("Config", ok and ("Saved config '" .. CONFIG_NAME .. "'") or ("Save failed: " .. tostring(err)), ok and "Success" or "Error")
        end)
    })
    ConfigSub:AddButton({
        Name = "Load Config",
        Callback = safeCallback(function()
            local ok, err = Library:LoadConfig(CONFIG_NAME)
            if ok then
                ResyncAll()
                Notify("Config", "Loaded config '" .. CONFIG_NAME .. "'", "Success")
            else
                Notify("Config", "Load failed: " .. tostring(err), "Error")
            end
        end)
    })
end

ConfigSub:AddKeybind({
    Name = "Toggle UI Keybind", Default = Enum.KeyCode.RightControl, Flag = "ui_toggle_key",
    OnPress = function()
        Window:Toggle()
    end
})

ConfigSub:AddDivider()

ConfigSub:AddButton({
    Name = "Unload Axel Hub",
    Callback = safeCallback(function()
        pcall(function() HUB.Unload() end)
    end)
})

    ConfigSub:AddParagraph({
        Title = "Axel Hub | Steal an Egg",
        Content = "Axel Hub · Steal an Egg\nYellow Axel Hub theme\nAutomated egg stealing, hatching, treadmill, rewards, pets, ESP, travel and settings."
    })
end

-- ==============================================================================
-- HUB CLEANUP & UNLOAD HANDLER
-- ==============================================================================
HUB.Unload = function()
    HUB.dead = true
    ServerHopLoopRunning = false

    for _, c in ipairs(HUB.conns) do pcall(function() c:Disconnect() end) end
    HUB.conns = {}

    for _, d in ipairs(HUB.drawings) do pcall(function() d:Remove() end) end
    HUB.drawings = {}

    for _, h in ipairs(HUB.highlights) do pcall(function() h:Destroy() end) end
    HUB.highlights = {}

    stopFly()
    SetFullbright(false)

    local hum = findHum()
    if hum then
        hum.PlatformStand = false
        hum.WalkSpeed = 16
        hum.JumpPower = 50
    end

    pcall(function() Window:Destroy() end)
    _G.OxideStealAnEgg = nil
end

Notify("Axel Hub", "Steal an Egg loaded successfully!", "Success", 3.5)
