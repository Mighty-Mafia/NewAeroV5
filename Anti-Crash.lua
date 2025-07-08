-- still in beta lmao (like 200 update)
-- update don july 5th 2025

local runService = game:GetService("RunService")
local players = game:GetService("Players")
local httpService = game:GetService("HttpService")
local teleportService = game:GetService("TeleportService")
local lighting = game:GetService("Lighting")
local localPlayer = players.LocalPlayer
local guiService = game:GetService("GuiService")
local starterGui = game:GetService("StarterGui")

local CONFIG = {
    CRITICAL_MEMORY_THRESHOLD_MB = 450,
    AGGRESSIVE_GC_THRESHOLD_MB = 550,
    MEMORY_MONITOR_INTERVAL = 5,

    FREEZE_THRESHOLD_SECONDS = 4,
    FREEZE_COUNT_TRIGGER = 2,
    FREEZE_RECOVERY_INTERVAL = 30,

    FPS_CHECK_INTERVAL = 2,
    LOW_FPS_THRESHOLD = 20,
    DRASTIC_FPS_THRESHOLD = 10,
    FPS_DROP_COUNT_TRIGGER = 3,

    RECONNECT_DELAY_SECONDS = 5,
    DISCONNECT_MONITOR_INTERVAL = 10,

    INITIAL_QUALITY_CAP = 7,
    EMERGENCY_QUALITY_LEVEL = 1,
    DISABLE_PARTICLES_ON_EMERGENCY = true,
    DISABLE_SOUNDS_ON_EMERGENCY = true,
    DISABLE_SHADOWS_ON_EMERGENCY = true,
    DISABLE_WATER_REFLECTIONS = true,
    DISABLE_FOG = true,
    DISABLE_BLUR_EFFECTS = true,

    LOG_FILE_NAME = "CrashLog.txt",
    NOTIFICATION_DURATION = 5,
}

local lastHeartbeat = tick()
local crashLog = {}
local fpsDropCount = 0
local memOverloadCount = 0
local freezeCount = 0
local emergencyMode = false
local lastRespawn = 0
local lastPlayerCheckTime = tick()


local function log(txt)
    local logMsg = os.date("[%X] ") .. txt
    table.insert(crashLog, logMsg)
    print("[Crash Helper] " .. txt)
    task.spawn(function()
        pcall(function()
            writefile(CONFIG.LOG_FILE_NAME, httpService:JSONEncode(crashLog))
        end)
    end)
end

local function sendNotification(title, text, duration, messageType)
    pcall(function()
        starterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = duration,
            Button1 = "OK",
        })
    end)
end

local function safeCollectGarbage(aggressive)
    local mem = collectgarbage("count") / 1024
    if mem > CONFIG.CRITICAL_MEMORY_THRESHOLD_MB or aggressive then
        log(string.format("Memory at %.2fMB. Cleaning up.", mem))
        task.wait(0.05)
        collectgarbage("collect")
        task.wait(0.05)

        if aggressive then
            for i = 1, 2 do
                collectgarbage("collect")
                task.wait(0.05)
            end

            pcall(function()
                for _, obj in pairs(workspace:GetDescendants()) do
                    if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Smoke") then
                        obj.Enabled = false
                    elseif obj:IsA("Sound") and obj.Playing then
                        if emergencyMode and CONFIG.DISABLE_SOUNDS_ON_EMERGENCY then
                            obj.Playing = false
                        end
                    end
                end
                if CONFIG.DISABLE_SHADOWS_ON_EMERGENCY then
                    lighting.GlobalShadows = false
                end
            end)
        end

        task.wait(0.2)
        log(string.format("Memory cleaned. Now at: %.2fMB", collectgarbage("count") / 1024))
    end
end

local function enterEmergencyMode()
    if emergencyMode then return end
    emergencyMode = true
    log("!!! EMERGENCY MODE ACTIVATED - Taking extreme measures to prevent crash !!!")
    sendNotification("Crash Prevention", "Emergency mode activated to prevent crash!", CONFIG.NOTIFICATION_DURATION, "alert")

    safeCollectGarbage(true)

    pcall(function()
        settings().Rendering.QualityLevel = CONFIG.EMERGENCY_QUALITY_LEVEL
        log("Rendering quality set to level " .. CONFIG.EMERGENCY_QUALITY_LEVEL)

        if CONFIG.DISABLE_SHADOWS_ON_EMERGENCY then
            lighting.GlobalShadows = false
            log("Global Shadows disabled.")
        end

        if CONFIG.DISABLE_WATER_REFLECTIONS then
            lighting.LegacyDynamicHeadsAndFaces = false
            lighting.WaterReflectance = 0
            log("Water reflections disabled.")
        end
        if CONFIG.DISABLE_FOG then
            lighting.FogEnd = math.huge
            lighting.FogStart = math.huge
            log("Fog disabled.")
        end
    end)
end

local function monitorMemory()
    while task.wait(CONFIG.MEMORY_MONITOR_INTERVAL) do
        safeCollectGarbage(emergencyMode)

        local mem = collectgarbage("count") / 1024
        if mem > CONFIG.CRITICAL_MEMORY_THRESHOLD_MB then
            memOverloadCount = memOverloadCount + 1
            if memOverloadCount >= 2 then
                log(string.format("Persistent high memory detected! %.2fMB. Activating emergency sequence.", mem))
                enterEmergencyMode()
                memOverloadCount = 0
            end
        else
            memOverloadCount = 0
        end
    end
end

local function monitorFPS()
    local frameCount = 0
    local lastCheck = tick()

    runService.RenderStepped:Connect(function()
        frameCount = frameCount + 1
        local now = tick()

        if now - lastCheck >= CONFIG.FPS_CHECK_INTERVAL then
            local fps = frameCount / (now - lastCheck)
            frameCount = 0
            lastCheck = now

            if fps < CONFIG.LOW_FPS_THRESHOLD then
                fpsDropCount = fpsDropCount + 1
                if fpsDropCount >= CONFIG.FPS_DROP_COUNT_TRIGGER then
                    log(string.format("FPS is tanking: %.0f FPS. Taking action.", fps))

                    if fps < CONFIG.DRASTIC_FPS_THRESHOLD then
                        pcall(function()
                            local currentQuality = settings().Rendering.QualityLevel
                            if currentQuality > CONFIG.EMERGENCY_QUALITY_LEVEL then
                                settings().Rendering.QualityLevel = math.max(CONFIG.EMERGENCY_QUALITY_LEVEL, currentQuality - 1)
                                log("Auto-reduced graphics to level " .. settings().Rendering.QualityLevel)
                            end
                        end)
                        enterEmergencyMode()
                    else
                        safeCollectGarbage(true)
                    end
                    fpsDropCount = 0
                end
            else
                fpsDropCount = 0
            end
        end
    end)
end

local function monitorFreeze()
    while task.wait(CONFIG.FREEZE_THRESHOLD_SECONDS / 2) do
        if tick() - lastHeartbeat > CONFIG.FREEZE_THRESHOLD_SECONDS then
            freezeCount = freezeCount + 1
            log("Game detected a freeze: " .. (tick() - lastHeartbeat) .. " seconds elapsed. Freeze count: " .. freezeCount)

            safeCollectGarbage(true)

            if freezeCount >= CONFIG.FREEZE_COUNT_TRIGGER then
                log("Multiple freezes detected - Taking emergency action")
                enterEmergencyMode()
                freezeCount = 0
            end
        else
            if freezeCount > 0 and (tick() - lastHeartbeat < CONFIG.FREEZE_THRESHOLD_SECONDS) and (tick() - lastPlayerCheckTime > CONFIG.FREEZE_RECOVERY_INTERVAL) then
                freezeCount = math.max(0, freezeCount - 1)
                log("Game stable, reducing freeze count. Current: " .. freezeCount)
                lastPlayerCheckTime = tick()
            end
        end
    end
end

local function monitorPlayer()
    while task.wait(CONFIG.DISCONNECT_MONITOR_INTERVAL) do
        local currentLocalPlayer = players.LocalPlayer
        if not currentLocalPlayer then
            log("Local player is missing, likely disconnected or about to crash.")
            task.wait(1)
            currentLocalPlayer = players.LocalPlayer
            if not currentLocalPlayer then
                log("Local player still missing after delay. Initiating reconnect.")
                sendNotification("Crash Prevention", "Disconnected/Crash detected. Reconnecting...", CONFIG.NOTIFICATION_DURATION, "alert")
                teleportService:Teleport(game.PlaceId)
                return
            end
        end

        if currentLocalPlayer and not currentLocalPlayer.Character and (tick() - lastRespawn) > CONFIG.DISCONNECT_MONITOR_INTERVAL then
            log("Character missing when it should exist (not recently respawned). Possible issue.")
            safeCollectGarbage(true)
        end

        if currentLocalPlayer and currentLocalPlayer.Character then
            lastRespawn = tick()
        end
    end
end

local function autoReconnect()
    pcall(function()
        guiService.DescendantAdded:Connect(function(descendant)
            if descendant:IsA("Frame") and descendant.Name == "ErrorPrompt" then
                log("Roblox error prompt detected - Attempting to reconnect.")
                sendNotification("Crash Prevention", "Game error detected. Reconnecting...", CONFIG.NOTIFICATION_DURATION, "alert")
                task.wait(CONFIG.RECONNECT_DELAY_SECONDS)
                teleportService:Teleport(game.PlaceId)
            end
        end)
    end)
end


pcall(function()
    if settings().Rendering.QualityLevel > CONFIG.INITIAL_QUALITY_CAP then
        settings().Rendering.QualityLevel = CONFIG.INITIAL_QUALITY_CAP
        log("Reduced initial graphics quality for stability to level " .. CONFIG.INITIAL_QUALITY_CAP)
    end

    if CONFIG.DISABLE_WATER_REFLECTIONS then
        lighting.LegacyDynamicHeadsAndFaces = false
        lighting.WaterReflectance = 0
        log("Proactively disabled water reflections.")
    end
    if CONFIG.DISABLE_FOG then
        lighting.FogEnd = math.huge
        lighting.FogStart = math.huge
        log("Proactively disabled fog.")
    end

    if CONFIG.DISABLE_BLUR_EFFECTS then
        for _, gui in pairs(game:GetService("CoreGui"):GetChildren()) do
            if gui:IsA("ScreenGui") then
                for _, effect in pairs(gui:GetDescendants()) do
                    if effect:IsA("BlurEffect") or effect:IsA("DepthOfFieldEffect") then
                        effect.Enabled = false
                        log("Proactively disabled blur/DOF effect in GUI: " .. effect.Name)
                    end
                end
            end
        end
    end
end)


runService.Heartbeat:Connect(function()
    lastHeartbeat = tick()
end)

task.spawn(monitorMemory)
task.spawn(monitorFreeze)
task.spawn(monitorPlayer)
task.spawn(autoReconnect)
task.spawn(monitorFPS)

log("Zero-Crash Prevention System Loaded. Maximum stability initiated!")
