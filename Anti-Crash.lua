local runService = game:GetService("RunService")
local players = game:GetService("Players")
local httpService = game:GetService("HttpService")
local teleportService = game:GetService("TeleportService")
local lighting = game:GetService("Lighting")
local localPlayer = players.LocalPlayer
local guiService = game:GetService("GuiService")
local starterGui = game:GetService("StarterGui")
local userInputService = game:GetService("UserInputService")
local contentProvider = game:GetService("ContentProvider")

local CONFIG = {
    CRITICAL_MEMORY_THRESHOLD_MB = 400,
    AGGRESSIVE_GC_THRESHOLD_MB = 500,
    MEMORY_MONITOR_INTERVAL = 3,
    FREEZE_THRESHOLD_SECONDS = 3,
    FREEZE_COUNT_TRIGGER = 2,
    FREEZE_RECOVERY_INTERVAL = 20,
    FPS_CHECK_INTERVAL = 1.5,
    LOW_FPS_THRESHOLD = 25,
    DRASTIC_FPS_THRESHOLD = 15,
    FPS_DROP_COUNT_TRIGGER = 2,
    PING_CHECK_INTERVAL = 5,
    HIGH_PING_THRESHOLD_MS = 300,
    CRITICAL_PING_THRESHOLD_MS = 500,
    PING_SPIKE_COUNT_TRIGGER = 3,
    RECONNECT_DELAY_SECONDS = 3,
    DISCONNECT_MONITOR_INTERVAL = 8,
    INITIAL_QUALITY_CAP = 6,
    EMERGENCY_QUALITY_LEVEL = 1,
    DISABLE_PARTICLES_ON_EMERGENCY = true,
    DISABLE_SOUNDS_ON_EMERGENCY = true,
    DISABLE_SHADOWS_ON_EMERGENCY = true,
    DISABLE_WATER_REFLECTIONS = true,
    DISABLE_FOG = true,
    DISABLE_BLUR_EFFECTS = true,
    DISABLE_BLOOM_EFFECTS = true,
    DISABLE_COLOR_CORRECTION = true,
    DISABLE_POST_PROCESS_EFFECTS = true,
    DISABLE_DECORATIONS = true,
    DISABLE_PHYSICS_THROTTLING = false,
    REDUCE_RENDER_DISTANCE = true,
    LOG_FILE_NAME = "CrashLog_Optimized.txt",
    NOTIFICATION_DURATION = 4,
}

local lastHeartbeat = tick()
local crashLog = {}
local fpsDropCount = 0
local memOverloadCount = 0
local freezeCount = 0
local emergencyMode = false
local lastRespawn = 0
local lastPlayerCheckTime = tick()
local pingSpikeCount = 0
local initialQualityLevel = settings().Rendering.QualityLevel

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
        log(string.format("Memory at %.2fMB. Initiating cleanup%s.", mem, aggressive and " (aggressive)" or ""))
        task.wait(0.02)
        for i = 1, (aggressive and 3 or 1) do
            collectgarbage("collect")
            task.wait(0.02)
        end
        pcall(function()
            for _, obj in pairs(workspace:GetDescendants()) do
                if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Smoke") then
                    if CONFIG.DISABLE_PARTICLES_ON_EMERGENCY and (emergencyMode or aggressive) then
                        obj.Enabled = false
                    end
                elseif obj:IsA("Sound") and obj.Playing then
                    if CONFIG.DISABLE_SOUNDS_ON_EMERGENCY and (emergencyMode or aggressive) then
                        obj.Playing = false
                    end
                elseif obj:IsA("MeshPart") or obj:IsA("Part") then
                    if CONFIG.DISABLE_DECORATIONS and (emergencyMode or aggressive) and obj.Size.X * obj.Size.Y * obj.Size.Z < 10 then
                        obj.Transparency = 1
                        obj.CanCollide = false
                    end
                end
            end
            if CONFIG.DISABLE_SHADOWS_ON_EMERGENCY and (emergencyMode or aggressive) then
                lighting.GlobalShadows = false
                log("Global Shadows disabled.")
            end
            if CONFIG.DISABLE_WATER_REFLECTIONS and (emergencyMode or aggressive) then
                lighting.LegacyDynamicHeadsAndFaces = false
                lighting.WaterReflectance = 0
                log("Water reflections disabled.")
            end
            if CONFIG.DISABLE_FOG and (emergencyMode or aggressive) then
                lighting.FogEnd = math.huge
                lighting.FogStart = math.huge
                log("Fog disabled.")
            end
            if CONFIG.DISABLE_BLOOM_EFFECTS and (emergencyMode or aggressive) then
                local bloom = lighting:FindFirstChildOfClass("BloomEffect")
                if bloom then bloom.Enabled = false end
                log("Bloom effect disabled.")
            end
            if CONFIG.DISABLE_COLOR_CORRECTION and (emergencyMode or aggressive) then
                local cc = lighting:FindFirstChildOfClass("ColorCorrectionEffect")
                if cc then cc.Enabled = false end
                log("ColorCorrection effect disabled.")
            end
            if CONFIG.DISABLE_POST_PROCESS_EFFECTS and (emergencyMode or aggressive) then
                for _, effect in pairs(lighting:GetChildren()) do
                    if effect:IsA("PostEffect") then
                        effect.Enabled = false
                    end
                end
                log("Generic Post-Process effects disabled.")
            end
        end)
        task.wait(0.1)
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
        if CONFIG.DISABLE_BLUR_EFFECTS then
            for _, gui in pairs({game:GetService("CoreGui"), players.LocalPlayer:FindFirstChild("PlayerGui")}) do
                if gui then
                    for _, effect in pairs(gui:GetDescendants()) do
                        if effect:IsA("BlurEffect") or effect:IsA("DepthOfFieldEffect") then
                            effect.Enabled = false
                            log("Proactively disabled blur/DOF effect in GUI: " .. effect.Name)
                        end
                    end
                end
            end
        end
        if CONFIG.DISABLE_BLOOM_EFFECTS then
            local bloom = lighting:FindFirstChildOfClass("BloomEffect")
            if bloom then bloom.Enabled = false end
            log("Bloom effect disabled.")
        end
        if CONFIG.DISABLE_COLOR_CORRECTION then
            local cc = lighting:FindFirstChildOfClass("ColorCorrectionEffect")
            if cc then cc.Enabled = false end
            log("ColorCorrection effect disabled.")
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

local function monitorNetwork()
    while task.wait(CONFIG.PING_CHECK_INTERVAL) do
        pcall(function()
            local ping = players.LocalPlayer:GetNetworkPing() * 1000
            log(string.format("Current Ping: %.0fms", ping))
            if ping > CONFIG.HIGH_PING_THRESHOLD_MS then
                pingSpikeCount = pingSpikeCount + 1
                log(string.format("High ping detected: %.0fms. Spike count: %d", ping, pingSpikeCount))
                if pingSpikeCount >= CONFIG.PING_SPIKE_COUNT_TRIGGER then
                    log("Persistent high ping detected. Activating emergency network measures.")
                    sendNotification("Network Issue", "High ping detected! Optimizing network performance.", CONFIG.NOTIFICATION_DURATION, "warning")
                    enterEmergencyMode()
                    pingSpikeCount = 0
                end
            else
                pingSpikeCount = 0
            end
        end)
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
        guiService.DescendantAdded:Connect(function(descendant)
            if descendant:IsA("Frame") and (descendant.Name == "ErrorPrompt" or descendant.Name == "DisconnectedPrompt") then
                log("Roblox error/disconnect prompt detected - Attempting to reconnect.")
                sendNotification("Crash Prevention", "Game error/disconnect detected. Reconnecting...", CONFIG.NOTIFICATION_DURATION, "alert")
                task.wait(CONFIG.RECONNECT_DELAY_SECONDS)
                teleportService:Teleport(game.PlaceId)
            end
        end)
    end)
end

pcall(function()
    initialQualityLevel = settings().Rendering.QualityLevel
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
        for _, gui in pairs({game:GetService("CoreGui"), players.LocalPlayer:FindFirstChild("PlayerGui")}) do
            if gui then
                for _, effect in pairs(gui:GetDescendants()) do
                    if effect:IsA("BlurEffect") or effect:IsA("DepthOfFieldEffect") then
                        effect.Enabled = false
                        log("Proactively disabled blur/DOF effect in GUI: " .. effect.Name)
                    end
                end
            end
        end
    end
    if CONFIG.DISABLE_BLOOM_EFFECTS then
        local bloom = lighting:FindFirstChildOfClass("BloomEffect")
        if bloom then bloom.Enabled = false end
        log("Proactively disabled Bloom effect.")
    end
    if CONFIG.DISABLE_COLOR_CORRECTION then
        local cc = lighting:FindFirstChildOfClass("ColorCorrectionEffect")
        if cc then cc.Enabled = false end
        log("Proactively disabled ColorCorrection effect.")
    end
    if CONFIG.DISABLE_POST_PROCESS_EFFECTS then
        for _, effect in pairs(lighting:GetChildren()) do
            if effect:IsA("PostEffect") then
                effect.Enabled = false
            end
        end
        log("Proactively disabled generic Post-Process effects.")
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
task.spawn(monitorNetwork)

log("Zero-Crash Prevention System Loaded. Maximum stability initiated!")
