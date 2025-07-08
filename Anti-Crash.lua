local runService = game:GetService("RunService")
local players = game:GetService("Players")
local httpService = game:GetService("HttpService")
local teleportService = game:GetService("TeleportService")
local lighting = game:GetService("Lighting")
local starterGui = game:GetService("StarterGui")
local userInputService = game:GetService("UserInputService")
local soundService = game:GetService("SoundService")
local collectionService = game:GetService("CollectionService")

local CONFIG = {
    CRITICAL_MEMORY_THRESHOLD_MB = 400,
    AGGRESSIVE_GC_THRESHOLD_MB = 500,
    MEMORY_MONITOR_INTERVAL = 3,
    FREEZE_THRESHOLD_SECONDS = 3.5,
    FREEZE_COUNT_TRIGGER = 2,
    FREEZE_RECOVERY_INTERVAL = 45,
    FPS_CHECK_INTERVAL = 1.5,
    LOW_FPS_THRESHOLD = 25,
    DRASTIC_FPS_THRESHOLD = 15,
    FPS_DROP_COUNT_TRIGGER = 2,
    RECONNECT_DELAY_SECONDS = 7,
    DISCONNECT_MONITOR_INTERVAL = 15,
    INITIAL_QUALITY_CAP = 6,
    EMERGENCY_QUALITY_LEVEL = 1,
    DISABLE_PARTICLES_ON_EMERGENCY = true,
    DISABLE_SOUNDS_ON_EMERGENCY = true,
    DISABLE_SHADOWS_ON_EMERGENCY = true,
    DISABLE_WATER_REFLECTIONS = true,
    DISABLE_FOG = true,
    DISABLE_BLUR_EFFECTS = true,
    LOG_FILE_NAME = "CrashLog.txt",
    NOTIFICATION_DURATION = 4,
    NOTIFICATION_DEBOUNCE_TIME = 10,
}

local lastHeartbeat = tick()
local lastInputActivity = tick()
local crashLog = {}
local fpsDropCount = 0
local memOverloadCount = 0
local freezeCount = 0
local emergencyMode = false
local lastRespawn = 0
local lastPlayerCheckTime = tick()
local lastNotificationTime = 0
local currentGraphicsQuality = settings().Rendering.QualityLevel

local function debounceNotification(title, text, messageType)
    local now = tick()
    if now - lastNotificationTime >= CONFIG.NOTIFICATION_DEBOUNCE_TIME then
        pcall(function()
            starterGui:SetCore("SendNotification", {
                Title = title,
                Text = text,
                Duration = CONFIG.NOTIFICATION_DURATION,
                Button1 = "OK",
            })
        end)
        lastNotificationTime = now
    end
end

local function log(txt)
    local logMsg = os.date("[%Y-%m-%d %X] ") .. txt
    table.insert(crashLog, logMsg)
    print("[Crash Helper] " .. txt)
    task.spawn(function()
        pcall(function()
            writefile(CONFIG.LOG_FILE_NAME, httpService:JSONEncode(crashLog))
        end)
    end)
end

local function safeCollectGarbage(aggressive)
    local mem = collectgarbage("count") / 1024
    log(string.format("Current Memory: %.2fMB", mem))
    if mem > CONFIG.CRITICAL_MEMORY_THRESHOLD_MB or aggressive then
        log(string.format("Memory at %.2fMB. Initiating cleanup.", mem))
        collectgarbage("collect")
        task.wait(0.05)
        if aggressive then
            collectgarbage("collect")
            task.wait(0.05)
            pcall(function()
                if CONFIG.DISABLE_PARTICLES_ON_EMERGENCY then
                    for _, obj in pairs(workspace:GetDescendants()) do
                        if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Smoke") then
                            if obj.Enabled then
                                obj.Enabled = false
                            end
                        end
                    end
                    log("Disabled particle emitters, trails, and smoke.")
                end
                if CONFIG.DISABLE_SOUNDS_ON_EMERGENCY then
                    for _, sound in pairs(soundService:GetDescendants()) do
                        if sound:IsA("Sound") and sound.Playing then
                            sound.Playing = false
                        end
                    end
                    log("Stopped all playing sounds.")
                end
                if CONFIG.DISABLE_SHADOWS_ON_EMERGENCY then
                    if lighting.GlobalShadows then
                        lighting.GlobalShadows = false
                        log("Global Shadows disabled.")
                    end
                end
                if CONFIG.DISABLE_WATER_REFLECTIONS then
                    if lighting.WaterReflectance > 0 then
                        lighting.WaterReflectance = 0
                        log("Water reflections disabled.")
                    end
                end
                if CONFIG.DISABLE_FOG then
                    if lighting.FogEnd ~= math.huge or lighting.FogStart ~= math.huge then
                        lighting.FogEnd = math.huge
                        lighting.FogStart = math.huge
                        log("Fog disabled.")
                    end
                end
            end)
        end
        task.wait(0.1)
        log(string.format("Memory cleaned. Now at: %.2fMB", collectgarbage("count") / 1024))
    end
end

local function enterEmergencyMode()
    if emergencyMode then return end
    emergencyMode = true
    log("!!! EMERGENCY MODE ACTIVATED - Taking extreme measures to prevent crash !!!")
    debounceNotification("Crash Prevention", "Emergency mode activated to prevent crash!", "alert")
    safeCollectGarbage(true)
    pcall(function()
        if settings().Rendering.QualityLevel > CONFIG.EMERGENCY_QUALITY_LEVEL then
            settings().Rendering.QualityLevel = CONFIG.EMERGENCY_QUALITY_LEVEL
            log("Rendering quality set to level " .. CONFIG.EMERGENCY_QUALITY_LEVEL)
        end
        if CONFIG.DISABLE_SHADOWS_ON_EMERGENCY and lighting.GlobalShadows then
            lighting.GlobalShadows = false
            log("Global Shadows disabled.")
        end
        if CONFIG.DISABLE_WATER_REFLECTIONS and lighting.WaterReflectance > 0 then
            lighting.WaterReflectance = 0
            log("Water reflections disabled.")
        end
        if CONFIG.DISABLE_FOG and (lighting.FogEnd ~= math.huge or lighting.FogStart ~= math.huge) then
            lighting.FogEnd = math.huge
            lighting.FogStart = math.huge
            log("Fog disabled.")
        end
        if CONFIG.DISABLE_BLUR_EFFECTS then
            local guisToScan = {players.LocalPlayer:WaitForChild("PlayerGui")}
            pcall(function() table.insert(guisToScan, game:GetService("CoreGui")) end)
            for _, gui in pairs(guisToScan) do
                if gui and gui:IsA("ScreenGui") then
                    for _, effect in pairs(gui:GetDescendants()) do
                        if effect:IsA("BlurEffect") or effect:IsA("DepthOfFieldEffect") then
                            if effect.Enabled then
                                effect.Enabled = false
                                log("Proactively disabled blur/DOF effect in GUI: " .. effect.Name)
                            end
                        end
                    end
                end
            end
        end
    end)
end

local function exitEmergencyMode()
    if not emergencyMode then return end
    emergencyMode = false
    log("Emergency mode deactivated. Restoring some settings.")
    debounceNotification("Crash Prevention", "Performance improved. Exiting emergency mode.", "info")
    pcall(function()
        if settings().Rendering.QualityLevel == CONFIG.EMERGENCY_QUALITY_LEVEL then
            settings().Rendering.QualityLevel = math.min(currentGraphicsQuality, CONFIG.INITIAL_QUALITY_CAP)
            log("Restored graphics quality to level " .. settings().Rendering.QualityLevel)
        end
    end)
end

local function monitorMemory()
    while task.wait(CONFIG.MEMORY_MONITOR_INTERVAL) do
        local mem = collectgarbage("count") / 1024
        safeCollectGarbage(emergencyMode)
        if mem > CONFIG.CRITICAL_MEMORY_THRESHOLD_MB then
            memOverloadCount += 1
            if memOverloadCount >= 2 then
                log(string.format("Persistent high memory detected! %.2fMB. Activating emergency sequence.", mem))
                enterEmergencyMode()
                memOverloadCount = 0
            end
        else
            if memOverloadCount > 0 then
                memOverloadCount = math.max(0, memOverloadCount - 1)
                log(string.format("Memory stable, reducing overload count. Current: %d", memOverloadCount))
            end
        end
    end
end

local function monitorFPS()
    local frameCount = 0
    local lastCheck = tick()
    runService.RenderStepped:Connect(function()
        frameCount += 1
        local now = tick()
        if now - lastCheck >= CONFIG.FPS_CHECK_INTERVAL then
            local fps = frameCount / (now - lastCheck)
            frameCount = 0
            lastCheck = now
            if fps < CONFIG.LOW_FPS_THRESHOLD then
                fpsDropCount += 1
                log(string.format("Low FPS detected: %.0f FPS. Drop count: %d", fps, fpsDropCount))
                if fpsDropCount >= CONFIG.FPS_DROP_COUNT_TRIGGER then
                    log(string.format("Consistent low FPS: %.0f FPS. Taking action.", fps))
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
                if fpsDropCount > 0 then
                    fpsDropCount = math.max(0, fpsDropCount - 1)
                    log(string.format("FPS stable, reducing drop count. Current: %d", fpsDropCount))
                end
                if emergencyMode and fps > CONFIG.LOW_FPS_THRESHOLD * 1.5 then
                    exitEmergencyMode()
                end
            end
        end
    end)
end

local function monitorFreeze()
    while task.wait(CONFIG.FREEZE_THRESHOLD_SECONDS / 2) do
        local timeSinceLastHeartbeat = tick() - lastHeartbeat
        local timeSinceLastInput = tick() - lastInputActivity
        if timeSinceLastHeartbeat > CONFIG.FREEZE_THRESHOLD_SECONDS and timeSinceLastInput > CONFIG.FREEZE_THRESHOLD_SECONDS then
            freezeCount += 1
            log(string.format("Game detected a freeze (Heartbeat: %.2fs, Input: %.2fs). Freeze count: %d", timeSinceLastHeartbeat, timeSinceLastInput, freezeCount))
            safeCollectGarbage(true)
            if freezeCount >= CONFIG.FREEZE_COUNT_TRIGGER then
                log("Multiple freezes detected - Taking emergency action")
                enterEmergencyMode()
                freezeCount = 0
            end
        else
            if freezeCount > 0 and (tick() - lastPlayerCheckTime > CONFIG.FREEZE_RECOVERY_INTERVAL) then
                freezeCount = math.max(0, freezeCount - 1)
                log("Game stable, reducing freeze count. Current: " .. freezeCount)
                lastPlayerCheckTime = tick()
            end
            if emergencyMode and freezeCount == 0 and timeSinceLastHeartbeat < CONFIG.FREEZE_THRESHOLD_SECONDS / 2 then
                exitEmergencyMode()
            end
        end
    end
end

local function monitorPlayer()
    while task.wait(CONFIG.DISCONNECT_MONITOR_INTERVAL) do
        local currentLocalPlayer = players.LocalPlayer
        if not currentLocalPlayer then
            log("Local player is missing, likely disconnected or about to crash. Waiting for reconnect.")
            task.wait(1)
            currentLocalPlayer = players.LocalPlayer
            if not currentLocalPlayer then
                log("Local player still missing after delay. Initiating reconnect.")
                debounceNotification("Crash Prevention", "Disconnected/Crash detected. Reconnecting...", "alert")
                pcall(function()
                    teleportService:Teleport(game.PlaceId)
                end)
                return
            end
        end
        if currentLocalPlayer and not currentLocalPlayer.Character and (tick() - lastRespawn) > CONFIG.DISCONNECT_MONITOR_INTERVAL then
            log("Character missing when it should exist (not recently respawned). Possible issue, performing GC.")
            safeCollectGarbage(true)
        end
        if currentLocalPlayer and currentLocalPlayer.Character then
            lastRespawn = tick()
        end
    end
end

local function autoReconnect()
    pcall(function()
        starterGui.DescendantAdded:Connect(function(descendant)
            if descendant:IsA("Frame") and (string.find(descendant.Name:lower(), "error") or string.find(descendant.Name:lower(), "disconnected")) then
                log("Roblox error/disconnect prompt detected - Attempting to reconnect.")
                debounceNotification("Crash Prevention", "Game error detected. Reconnecting...", "alert")
                task.wait(CONFIG.RECONNECT_DELAY_SECONDS)
                pcall(function()
                    teleportService:Teleport(game.PlaceId)
                end)
            end
        end)
    end)
end

local function monitorInputActivity()
    userInputService.InputBegan:Connect(function(input)
        lastInputActivity = tick()
    end)
end

pcall(function()
    currentGraphicsQuality = settings().Rendering.QualityLevel
    if settings().Rendering.QualityLevel > CONFIG.INITIAL_QUALITY_CAP then
        settings().Rendering.QualityLevel = CONFIG.INITIAL_QUALITY_CAP
        log("Reduced initial graphics quality for stability to level " .. CONFIG.INITIAL_QUALITY_CAP)
    end
    if CONFIG.DISABLE_WATER_REFLECTIONS then
        lighting.WaterReflectance = 0
        log("Proactively disabled water reflections.")
    end
    if CONFIG.DISABLE_FOG then
        lighting.FogEnd = math.huge
        lighting.FogStart = math.huge
        log("Proactively disabled fog.")
    end
    if CONFIG.DISABLE_BLUR_EFFECTS then
        local playerGui = players.LocalPlayer:WaitForChild("PlayerGui", 5)
        if playerGui then
            for _, gui in pairs(playerGui:GetDescendants()) do
                if gui:IsA("BlurEffect") or gui:IsA("DepthOfFieldEffect") then
                    if gui.Enabled then
                        gui.Enabled = false
                        log("Proactively disabled blur/DOF effect in PlayerGui: " .. gui.Name)
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
task.spawn(monitorInputActivity)

log("Zero-Crash Prevention System Loaded. Maximum stability initiated!")
