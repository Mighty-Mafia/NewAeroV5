-- still in beta lmao (like 200 update)
-- update don april 9 2025

local AntiCrash = {}
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local OriginalFunctions = {}

local CONFIG = {
    MaxParticles = 500,
    MaxEffects = 200,
    MaxSounds = 100,
    MemoryThreshold = 800,
    CheckInterval = 5,
    DisableHighParticleSystems = true,
    LimitRenderDistance = true,
    MaxRenderDistance = 1000,
    ProtectGlobalEnvironment = true,
    MonitorFramerate = true,
    MinAcceptableFramerate = 15,
    OptimizeOnLowFPS = true
}

local function GetMemoryUsage()
    return stats():GetTotalMemoryUsageMb()
end

local function SafeCall(func, ...)
    local success, result = pcall(func, ...)
    if not success then
        warn("[AntiCrash] Error in function call: " .. tostring(result))
        return nil
    end
    return result
end

function AntiCrash:CleanExcessParticles()
    local particleSystems = {}
    for _, instance in pairs(workspace:GetDescendants()) do
        if instance:IsA("ParticleEmitter") then
            table.insert(particleSystems, instance)
        end
    end
    if #particleSystems > CONFIG.MaxParticles then
        table.sort(particleSystems, function(a, b)
            local aDistance = (a.Parent and a.Parent:IsA("BasePart")) and 
                (a.Parent.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude or math.huge
            local bDistance = (b.Parent and b.Parent:IsA("BasePart")) and 
                (b.Parent.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude or math.huge
            return aDistance < bDistance
        end)
        for i = CONFIG.MaxParticles + 1, #particleSystems do
            particleSystems[i].Enabled = false
        end
        print("[AntiCrash] Disabled " .. (#particleSystems - CONFIG.MaxParticles) .. " particle systems")
    end
end

function AntiCrash:LimitRenderDistance()
    if not CONFIG.LimitRenderDistance then return end
    for _, part in pairs(workspace:GetDescendants()) do
        if part:IsA("BasePart") and not part:IsDescendantOf(LocalPlayer.Character) then
            local distance = (part.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
            if distance > CONFIG.MaxRenderDistance then
                if part:FindFirstChild("OriginalTransparency") == nil then
                    local originalTransparency = Instance.new("NumberValue")
                    originalTransparency.Name = "OriginalTransparency"
                    originalTransparency.Value = part.Transparency
                    originalTransparency.Parent = part
                    part.Transparency = 1
                end
            else
                local originalTransparency = part:FindFirstChild("OriginalTransparency")
                if originalTransparency then
                    part.Transparency = originalTransparency.Value
                    originalTransparency:Destroy()
                end
            end
        end
    end
end

local frameRateMonitor = {
    frames = 0,
    lastCheck = tick(),
    currentFPS = 60
}

function AntiCrash:MonitorFramerate()
    frameRateMonitor.frames = frameRateMonitor.frames + 1
    local currentTime = tick()
    local elapsed = currentTime - frameRateMonitor.lastCheck
    if elapsed >= 1 then
        frameRateMonitor.currentFPS = frameRateMonitor.frames / elapsed
        frameRateMonitor.frames = 0
        frameRateMonitor.lastCheck = currentTime
        if CONFIG.OptimizeOnLowFPS and frameRateMonitor.currentFPS < CONFIG.MinAcceptableFramerate then
            self:EmergencyOptimize()
        end
    end
end

function AntiCrash:EmergencyOptimize()
    print("[AntiCrash] Emergency optimization triggered - FPS: " .. math.floor(frameRateMonitor.currentFPS))
    local oldRenderDistance = CONFIG.MaxRenderDistance
    CONFIG.MaxRenderDistance = CONFIG.MaxRenderDistance * 0.5
    self:LimitRenderDistance()
    for _, instance in pairs(game:GetDescendants()) do
        if instance:IsA("ParticleEmitter") or instance:IsA("Trail") or instance:IsA("Beam") then
            instance.Enabled = false
        elseif instance:IsA("BlurEffect") or instance:IsA("BloomEffect") or instance:IsA("SunRaysEffect") then
            instance.Enabled = false
        end
    end
    delay(5, function()
        CONFIG.MaxRenderDistance = oldRenderDistance
    end)
end

function AntiCrash:MonitorMemory()
    local memoryUsage = GetMemoryUsage()
    if memoryUsage > CONFIG.MemoryThreshold then
        print("[AntiCrash] High memory usage detected: " .. memoryUsage .. "MB - Cleaning up...")
        for i = 1, 5 do
            game:GetService("Debris"):AddItem(Instance.new("Frame"), 0)
        end
        for _, instance in pairs(workspace:GetDescendants()) do
            if instance:IsA("Debris") then
                instance:Destroy()
            end
        end
        for _, sound in pairs(workspace:GetDescendants()) do
            if sound:IsA("Sound") and not sound.Playing then
                sound:Destroy()
            end
        end
    end
end

function AntiCrash:ProtectGlobalEnvironment()
    if not CONFIG.ProtectGlobalEnvironment then return end
    if not OriginalFunctions.error then
        OriginalFunctions.error = error
        error = function(msg, level)
            warn("[AntiCrash] Caught error: " .. tostring(msg))
            return nil
        end
    end
    setmetatable(_G, {
        __index = function(t, k)
            if rawget(t, k) == nil then
                warn("[AntiCrash] Attempted to access nil global: " .. tostring(k))
                return function() end
            end
            return rawget(t, k)
        end
    })
end

function AntiCrash:Initialize()
    print("[AntiCrash] Initializing anti-crash protection...")
    self:ProtectGlobalEnvironment()
    RunService.Heartbeat:Connect(function()
        SafeCall(function() self:MonitorFramerate() end)
    end)
    spawn(function()
        while wait(CONFIG.CheckInterval) do
            SafeCall(function() self:CleanExcessParticles() end)
            SafeCall(function() self:LimitRenderDistance() end)
            SafeCall(function() self:MonitorMemory() end)
        end
    end)
    print("[AntiCrash] Protection active")
end

AntiCrash:Initialize()

return AntiCrash
