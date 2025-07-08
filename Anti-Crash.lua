local runService = game:GetService("RunService")
local players = game:GetService("Players")
local httpService = game:GetService("HttpService")
local teleportService = game:GetService("TeleportService")
local lighting = game:GetService("Lighting")
local localPlayer = players.LocalPlayer
local guiService = game:GetService("GuiService")
local starterGui = game:GetService("StarterGui")

-- Optimized config with better thresholds
local CONFIG = {
    CRITICAL_MEMORY_THRESHOLD_MB = 350,
    AGGRESSIVE_GC_THRESHOLD_MB = 450,
    MEMORY_MONITOR_INTERVAL = 8,
    FREEZE_THRESHOLD_SECONDS = 3,
    FREEZE_COUNT_TRIGGER = 2,
    FREEZE_RECOVERY_INTERVAL = 45,
    FPS_CHECK_INTERVAL = 1,
    LOW_FPS_THRESHOLD = 25,
    DRASTIC_FPS_THRESHOLD = 15,
    FPS_DROP_COUNT_TRIGGER = 2,
    RECONNECT_DELAY_SECONDS = 3,
    DISCONNECT_MONITOR_INTERVAL = 15,
    INITIAL_QUALITY_CAP = 6,
    EMERGENCY_QUALITY_LEVEL = 2,
    MAX_LOG_ENTRIES = 50,
    NOTIFICATION_DURATION = 3,
    HEARTBEAT_BUFFER_SIZE = 10,
    PERFORMANCE_BOOST_MODE = true,
}

-- Performance optimized variables
local lastHeartbeat = tick()
local crashLog = {}
local fpsDropCount = 0
local memOverloadCount = 0
local freezeCount = 0
local emergencyMode = false
local lastRespawn = 0
local lastPlayerCheckTime = tick()
local heartbeatBuffer = {}
local bufferIndex = 1
local frameTimeAccumulator = 0
local frameCount = 0
local lastFPSCheck = tick()
local isMonitoring = true
local connections = {}

-- Optimized logging with buffer limit
local function log(txt)
    if #crashLog >= CONFIG.MAX_LOG_ENTRIES then
        table.remove(crashLog, 1)
    end
    local logMsg = string.format("[%s] %s", os.date("%X"), txt)
    table.insert(crashLog, logMsg)
    print("[Crash Helper] " .. txt)
end

-- Cached notification function
local notificationCache = {}
local function sendNotification(title, text, duration)
    local key = title .. text
    local now = tick()
    if notificationCache[key] and (now - notificationCache[key]) < 10 then
        return -- Prevent spam
    end
    notificationCache[key] = now
    
    task.spawn(function()
        pcall(function()
            starterGui:SetCore("SendNotification", {
                Title = title,
                Text = text,
                Duration = duration or CONFIG.NOTIFICATION_DURATION,
                Button1 = "OK",
            })
        end)
    end)
end

-- Ultra-optimized garbage collection
local lastGCTime = 0
local function safeCollectGarbage(aggressive)
    local now = tick()
    if now - lastGCTime < 2 then return end -- Rate limit GC
    lastGCTime = now
    
    local mem = collectgarbage("count") / 1024
    if mem > CONFIG.CRITICAL_MEMORY_THRESHOLD_MB or aggressive then
        log(string.format("Memory: %.1fMB - Cleaning", mem))
        
        -- Optimized GC sequence
        collectgarbage("step", 1000)
        task.wait()
        
        if aggressive then
            collectgarbage("collect")
            task.wait(0.03)
            
            -- Emergency cleanup
            task.spawn(function()
                pcall(function()
                    local cleaned = 0
                    for _, obj in pairs(workspace:GetDescendants()) do
                        if cleaned > 100 then break end -- Limit cleanup per cycle
                        
                        if obj:IsA("ParticleEmitter") and obj.Enabled then
                            obj.Enabled = false
                            cleaned = cleaned + 1
                        elseif obj:IsA("Trail") and obj.Enabled then
                            obj.Enabled = false
                            cleaned = cleaned + 1
                        elseif obj:IsA("Sound") and obj.Playing and emergencyMode then
                            obj.Playing = false
                            cleaned = cleaned + 1
                        end
                    end
                end)
            end)
        end
        
        log(string.format("Memory cleaned: %.1fMB", collectgarbage("count") / 1024))
    end
end

-- Advanced emergency mode with performance boost
local function enterEmergencyMode()
    if emergencyMode then return end
    emergencyMode = true
    
    log("EMERGENCY MODE - Maximum performance boost activated")
    sendNotification("Performance Boost", "Emergency optimization active!")
    
    task.spawn(function()
        pcall(function()
            -- Graphics optimization
            local renderSettings = settings().Rendering
            renderSettings.QualityLevel = CONFIG.EMERGENCY_QUALITY_LEVEL
            renderSettings.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level04
            renderSettings.EagerBulkExecution = true
            
            -- Lighting optimization
            lighting.GlobalShadows = false
            lighting.FogEnd = 100000
            lighting.FogStart = 100000
            lighting.Brightness = 1
            lighting.EnvironmentDiffuseScale = 0.5
            lighting.EnvironmentSpecularScale = 0.5
            
            -- Workspace optimization
            workspace.StreamingEnabled = true
            workspace.StreamingMinRadius = 64
            workspace.StreamingTargetRadius = 256
            
            log("Emergency graphics optimization complete")
        end)
    end)
    
    safeCollectGarbage(true)
end

-- Optimized memory monitoring with adaptive intervals
local function monitorMemory()
    while isMonitoring do
        local interval = emergencyMode and 4 or CONFIG.MEMORY_MONITOR_INTERVAL
        task.wait(interval)
        
        if not isMonitoring then break end
        
        local mem = collectgarbage("count") / 1024
        
        if mem > CONFIG.CRITICAL_MEMORY_THRESHOLD_MB then
            memOverloadCount = memOverloadCount + 1
            if memOverloadCount >= 2 then
                log(string.format("High memory: %.1fMB - Emergency mode", mem))
                enterEmergencyMode()
                memOverloadCount = 0
            end
        else
            memOverloadCount = math.max(0, memOverloadCount - 1)
            if emergencyMode and mem < CONFIG.CRITICAL_MEMORY_THRESHOLD_MB * 0.7 then
                emergencyMode = false
                log("Memory stabilized - Emergency mode disabled")
            end
        end
        
        -- Proactive cleanup
        if mem > CONFIG.AGGRESSIVE_GC_THRESHOLD_MB then
            safeCollectGarbage(false)
        end
    end
end

-- High-performance FPS monitoring
local function monitorFPS()
    local connection
    connection = runService.Heartbeat:Connect(function(deltaTime)
        frameTimeAccumulator = frameTimeAccumulator + deltaTime
        frameCount = frameCount + 1
        
        local now = tick()
        if now - lastFPSCheck >= CONFIG.FPS_CHECK_INTERVAL then
            local fps = frameCount / frameTimeAccumulator
            frameCount = 0
            frameTimeAccumulator = 0
            lastFPSCheck = now
            
            if fps < CONFIG.LOW_FPS_THRESHOLD then
                fpsDropCount = fpsDropCount + 1
                if fpsDropCount >= CONFIG.FPS_DROP_COUNT_TRIGGER then
                    log(string.format("Low FPS: %.0f - Optimizing", fps))
                    
                    if fps < CONFIG.DRASTIC_FPS_THRESHOLD then
                        enterEmergencyMode()
                    else
                        safeCollectGarbage(true)
                    end
                    fpsDropCount = 0
                end
            else
                fpsDropCount = math.max(0, fpsDropCount - 1)
            end
        end
    end)
    
    table.insert(connections, connection)
end

-- Optimized freeze detection with rolling buffer
local function monitorFreeze()
    while isMonitoring do
        task.wait(CONFIG.FREEZE_THRESHOLD_SECONDS * 0.5)
        
        local timeSinceHeartbeat = tick() - lastHeartbeat
        
        -- Rolling buffer for heartbeat timing
        heartbeatBuffer[bufferIndex] = timeSinceHeartbeat
        bufferIndex = (bufferIndex % CONFIG.HEARTBEAT_BUFFER_SIZE) + 1
        
        if timeSinceHeartbeat > CONFIG.FREEZE_THRESHOLD_SECONDS then
            freezeCount = freezeCount + 1
            log(string.format("Freeze detected: %.1fs (Count: %d)", timeSinceHeartbeat, freezeCount))
            
            if freezeCount >= CONFIG.FREEZE_COUNT_TRIGGER then
                log("Multiple freezes - Emergency intervention")
                enterEmergencyMode()
                safeCollectGarbage(true)
                freezeCount = 0
            end
        else
            -- Gradual recovery
            if freezeCount > 0 and (tick() - lastPlayerCheckTime) > CONFIG.FREEZE_RECOVERY_INTERVAL then
                freezeCount = math.max(0, freezeCount - 1)
                lastPlayerCheckTime = tick()
            end
        end
    end
end

-- Lightweight player monitoring
local function monitorPlayer()
    while isMonitoring do
        task.wait(CONFIG.DISCONNECT_MONITOR_INTERVAL)
        
        local currentPlayer = players.LocalPlayer
        if not currentPlayer then
            log("Player disconnected - Attempting reconnect")
            sendNotification("Reconnecting", "Connection lost, rejoining...")
            task.wait(CONFIG.RECONNECT_DELAY_SECONDS)
            teleportService:Teleport(game.PlaceId)
            return
        end
        
        if currentPlayer.Character then
            lastRespawn = tick()
        end
    end
end

-- Enhanced auto-reconnect with error handling
local function setupAutoReconnect()
    task.spawn(function()
        pcall(function()
            local connection = guiService.ErrorMessageChanged:Connect(function()
                if guiService:GetErrorMessage() ~= "" then
                    log("Roblox error detected - Auto reconnecting")
                    sendNotification("Error Recovery", "Reconnecting due to error...")
                    task.wait(CONFIG.RECONNECT_DELAY_SECONDS)
                    teleportService:Teleport(game.PlaceId)
                end
            end)
            table.insert(connections, connection)
        end)
    end)
end

-- Performance boost initialization
local function initializePerformanceBoost()
    task.spawn(function()
        pcall(function()
            -- Initial graphics optimization
            local renderSettings = settings().Rendering
            renderSettings.QualityLevel = CONFIG.INITIAL_QUALITY_CAP
            renderSettings.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level04
            
            -- Network optimization
            settings().Network.IncomingReplicationLag = 0
            
            -- Lighting optimization
            lighting.GlobalShadows = false
            lighting.FogEnd = 100000
            lighting.FogStart = 100000
            
            -- Workspace streaming
            if workspace.StreamingEnabled == false then
                workspace.StreamingEnabled = true
                workspace.StreamingMinRadius = 128
                workspace.StreamingTargetRadius = 512
            end
            
            log("Performance boost initialization complete")
        end)
    end)
end

-- Heartbeat connection with optimization
local heartbeatConnection = runService.Heartbeat:Connect(function()
    lastHeartbeat = tick()
end)
table.insert(connections, heartbeatConnection)

-- Cleanup function
local function cleanup()
    isMonitoring = false
    for _, connection in pairs(connections) do
        if connection then
            connection:Disconnect()
        end
    end
    connections = {}
end

-- Initialize all systems
initializePerformanceBoost()
task.spawn(monitorMemory)
task.spawn(monitorFreeze)
task.spawn(monitorPlayer)
task.spawn(monitorFPS)
setupAutoReconnect()

-- Cleanup on game shutdown
game:BindToClose(cleanup)

log("Advanced Zero-Crash System v2.0 - Maximum Performance Mode Activated!")
sendNotification("System Ready", "Advanced crash prevention loaded!")
