-- Anti-Crash and Anti-Lag Script - Improved Version
-- Fixed memory leaks, improved performance monitoring, and added better error handling

local runService = game:GetService("RunService")
local players = game:GetService("Players")
local httpService = game:GetService("HttpService")
local teleportService = game:GetService("TeleportService")
local lighting = game:GetService("Lighting")
local localPlayer = players.LocalPlayer
local guiService = game:GetService("GuiService")
local starterGui = game:GetService("StarterGui")
local stats = game:GetService("Stats")

local CONFIG = {
    CRITICAL_MEMORY_THRESHOLD_MB = 400, -- Lowered for earlier intervention
    AGGRESSIVE_GC_THRESHOLD_MB = 500,
    MEMORY_MONITOR_INTERVAL = 3, -- More frequent monitoring
    FREEZE_THRESHOLD_SECONDS = 3, -- More sensitive freeze detection
    FREEZE_COUNT_TRIGGER = 2,
    FREEZE_RECOVERY_INTERVAL = 20,
    FPS_CHECK_INTERVAL = 1, -- More frequent FPS checks
    LOW_FPS_THRESHOLD = 25,
    DRASTIC_FPS_THRESHOLD = 15,
    FPS_DROP_COUNT_TRIGGER = 3,
    RECONNECT_DELAY_SECONDS = 3,
    DISCONNECT_MONITOR_INTERVAL = 8,
    INITIAL_QUALITY_CAP = 6, -- Slightly lower initial cap
    EMERGENCY_QUALITY_LEVEL = 1,
    DISABLE_PARTICLES_ON_EMERGENCY = true,
    DISABLE_SOUNDS_ON_EMERGENCY = true,
    DISABLE_SHADOWS_ON_EMERGENCY = true,
    DISABLE_WATER_REFLECTIONS = true,
    DISABLE_FOG = true,
    DISABLE_BLUR_EFFECTS = true,
    LOG_FILE_NAME = "CrashLog.txt",
    NOTIFICATION_DURATION = 4,
    PING_THRESHOLD_MS = 500, -- New: Monitor network lag
    MAX_LOG_ENTRIES = 100, -- Prevent log from growing too large
}

-- Improved state management
local state = {
    lastHeartbeat = tick(),
    crashLog = {},
    fpsDropCount = 0,
    memOverloadCount = 0,
    freezeCount = 0,
    emergencyMode = false,
    lastRespawn = 0,
    lastPlayerCheckTime = tick(),
    connections = {}, -- Track connections for cleanup
    currentFPS = 60,
    averagePing = 0,
    performanceScore = 100,
}

-- Improved logging with size management
local function log(txt)
    local logMsg = os.date("[%X] ") .. txt
    table.insert(state.crashLog, logMsg)
    
    -- Prevent log from growing too large
    if #state.crashLog > CONFIG.MAX_LOG_ENTRIES then
        table.remove(state.crashLog, 1)
    end
    
    print("[Crash Helper] " .. txt)
    
    -- Async file writing with error handling
    task.spawn(function()
        pcall(function()
            if writefile then
                writefile(CONFIG.LOG_FILE_NAME, table.concat(state.crashLog, "\n"))
            end
        end)
    end)
end

-- Improved notification system
local function sendNotification(title, text, duration)
    pcall(function()
        starterGui:SetCore("SendNotification", {
            Title = "🛡️ " .. title,
            Text = text,
            Duration = duration or CONFIG.NOTIFICATION_DURATION,
            Button1 = "OK",
        })
    end)
end

-- Enhanced memory management
local function safeCollectGarbage(aggressive)
    local startMem = collectgarbage("count") / 1024
    
    if startMem > CONFIG.CRITICAL_MEMORY_THRESHOLD_MB or aggressive then
        log(string.format("Memory cleanup started: %.2fMB", startMem))
        
        -- Progressive garbage collection
        for i = 1, (aggressive and 3 or 1) do
            collectgarbage("collect")
            if i < 3 then task.wait(0.03) end
        end
        
        -- Clean up specific objects in emergency mode
        if aggressive and state.emergencyMode then
            pcall(function()
                local cleaned = 0
                for _, obj in pairs(workspace:GetDescendants()) do
                    if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Smoke") or obj:IsA("Fire") then
                        if obj.Enabled then
                            obj.Enabled = false
                            cleaned = cleaned + 1
                        end
                    elseif obj:IsA("Sound") and obj.Playing and CONFIG.DISABLE_SOUNDS_ON_EMERGENCY then
                        obj:Stop()
                        cleaned = cleaned + 1
                    elseif obj:IsA("Decal") or obj:IsA("Texture") then
                        if obj.Transparency < 1 then
                            obj.Transparency = 1
                            cleaned = cleaned + 1
                        end
                    end
                    
                    -- Prevent script from hanging
                    if cleaned % 50 == 0 then
                        task.wait()
                    end
                end
                
                if cleaned > 0 then
                    log(string.format("Cleaned %d visual effects", cleaned))
                end
            end)
        end
        
        local endMem = collectgarbage("count") / 1024
        local saved = startMem - endMem
        log(string.format("Memory cleaned: %.2fMB → %.2fMB (saved %.2fMB)", startMem, endMem, saved))
        
        return saved
    end
    
    return 0
end

-- Enhanced emergency mode with gradual recovery
local function enterEmergencyMode()
    if state.emergencyMode then return end
    
    state.emergencyMode = true
    state.performanceScore = 0
    
    log("🚨 EMERGENCY MODE ACTIVATED - Extreme stability measures engaged!")
    sendNotification("Emergency Mode", "Taking extreme measures to prevent crash!", 6)
    
    -- Immediate memory cleanup
    safeCollectGarbage(true)
    
    pcall(function()
        -- Graphics settings
        local renderSettings = settings().Rendering
        renderSettings.QualityLevel = CONFIG.EMERGENCY_QUALITY_LEVEL
        
        -- Lighting optimizations
        lighting.GlobalShadows = false
        lighting.FogEnd = math.huge
        lighting.FogStart = math.huge
        lighting.WaterReflectance = 0
        lighting.WaterTransparency = 1
        lighting.WaterWaveSize = 0
        lighting.WaterWaveSpeed = 0
        
        -- Additional performance settings
        if renderSettings:FindFirstChild("MeshPartDetailLevel") then
            renderSettings.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Level04
        end
        
        log("Emergency graphics settings applied")
    end)
    
    -- Schedule emergency mode recovery check
    task.spawn(function()
        task.wait(30) -- Wait 30 seconds before considering recovery
        
        while state.emergencyMode do
            task.wait(10)
            
            -- Check if we can exit emergency mode
            local currentMem = collectgarbage("count") / 1024
            if currentMem < CONFIG.CRITICAL_MEMORY_THRESHOLD_MB * 0.7 and 
               state.currentFPS > CONFIG.LOW_FPS_THRESHOLD and
               state.freezeCount == 0 then
                
                state.emergencyMode = false
                state.performanceScore = 50 -- Partial recovery
                log("Emergency mode deactivated - Performance stabilized")
                sendNotification("Recovery", "Emergency mode deactivated - Performance improved!")
                break
            end
        end
    end)
end

-- Improved FPS monitoring with better averaging
local function monitorFPS()
    local frameCount = 0
    local lastCheck = tick()
    local fpsHistory = {}
    
    local connection = runService.RenderStepped:Connect(function()
        frameCount = frameCount + 1
        local now = tick()
        
        if now - lastCheck >= CONFIG.FPS_CHECK_INTERVAL then
            local fps = frameCount / (now - lastCheck)
            state.currentFPS = fps
            
            -- Maintain FPS history for better averaging
            table.insert(fpsHistory, fps)
            if #fpsHistory > 10 then
                table.remove(fpsHistory, 1)
            end
            
            -- Calculate average FPS
            local avgFPS = 0
            for _, f in ipairs(fpsHistory) do
                avgFPS = avgFPS + f
            end
            avgFPS = avgFPS / #fpsHistory
            
            frameCount = 0
            lastCheck = now
            
            -- FPS-based actions
            if avgFPS < CONFIG.LOW_FPS_THRESHOLD then
                state.fpsDropCount = state.fpsDropCount + 1
                state.performanceScore = math.max(0, state.performanceScore - 10)
                
                if state.fpsDropCount >= CONFIG.FPS_DROP_COUNT_TRIGGER then
                    log(string.format("Sustained low FPS: %.1f (avg: %.1f)", fps, avgFPS))
                    
                    if avgFPS < CONFIG.DRASTIC_FPS_THRESHOLD then
                        enterEmergencyMode()
                    else
                        -- Gradual quality reduction
                        pcall(function()
                            local currentQuality = settings().Rendering.QualityLevel
                            if currentQuality > CONFIG.EMERGENCY_QUALITY_LEVEL then
                                settings().Rendering.QualityLevel = math.max(CONFIG.EMERGENCY_QUALITY_LEVEL, currentQuality - 1)
                                log("Auto-reduced graphics to level " .. settings().Rendering.QualityLevel)
                            end
                        end)
                        safeCollectGarbage(true)
                    end
                    
                    state.fpsDropCount = 0
                end
            else
                state.fpsDropCount = math.max(0, state.fpsDropCount - 1)
                if not state.emergencyMode then
                    state.performanceScore = math.min(100, state.performanceScore + 2)
                end
            end
        end
    end)
    
    state.connections.fpsMonitor = connection
end

-- Enhanced memory monitoring
local function monitorMemory()
    task.spawn(function()
        while task.wait(CONFIG.MEMORY_MONITOR_INTERVAL) do
            local mem = collectgarbage("count") / 1024
            
            -- Regular cleanup
            if mem > CONFIG.AGGRESSIVE_GC_THRESHOLD_MB then
                safeCollectGarbage(false)
                mem = collectgarbage("count") / 1024
            end
            
            -- Critical memory handling
            if mem > CONFIG.CRITICAL_MEMORY_THRESHOLD_MB then
                state.memOverloadCount = state.memOverloadCount + 1
                state.performanceScore = math.max(0, state.performanceScore - 15)
                
                if state.memOverloadCount >= 2 then
                    log(string.format("Critical memory overload: %.2fMB", mem))
                    enterEmergencyMode()
                    state.memOverloadCount = 0
                end
            else
                state.memOverloadCount = math.max(0, state.memOverloadCount - 1)
            end
        end
    end)
end

-- Improved freeze detection
local function monitorFreeze()
    task.spawn(function()
        while task.wait(CONFIG.FREEZE_THRESHOLD_SECONDS / 3) do
            local timeSinceHeartbeat = tick() - state.lastHeartbeat
            
            if timeSinceHeartbeat > CONFIG.FREEZE_THRESHOLD_SECONDS then
                state.freezeCount = state.freezeCount + 1
                state.performanceScore = math.max(0, state.performanceScore - 20)
                
                log(string.format("Freeze detected: %.2fs elapsed (count: %d)", timeSinceHeartbeat, state.freezeCount))
                
                -- Immediate action on freeze
                safeCollectGarbage(true)
                
                if state.freezeCount >= CONFIG.FREEZE_COUNT_TRIGGER then
                    log("Multiple freezes detected - Emergency action required")
                    enterEmergencyMode()
                    state.freezeCount = 0
                end
            else
                -- Recovery logic
                if state.freezeCount > 0 and (tick() - state.lastPlayerCheckTime > CONFIG.FREEZE_RECOVERY_INTERVAL) then
                    state.freezeCount = math.max(0, state.freezeCount - 1)
                    if state.freezeCount == 0 then
                        log("Freeze recovery completed")
                    end
                    state.lastPlayerCheckTime = tick()
                end
            end
        end
    end)
end

-- Enhanced player monitoring
local function monitorPlayer()
    task.spawn(function()
        while task.wait(CONFIG.DISCONNECT_MONITOR_INTERVAL) do
            local currentPlayer = players.LocalPlayer
            
            if not currentPlayer then
                log("LocalPlayer missing - Connection issue detected")
                task.wait(2)
                
                if not players.LocalPlayer then
                    log("LocalPlayer still missing - Initiating reconnect")
                    sendNotification("Connection Lost", "Reconnecting to prevent crash...")
                    task.wait(CONFIG.RECONNECT_DELAY_SECONDS)
                    teleportService:Teleport(game.PlaceId)
                    return
                end
            end
            
            -- Character monitoring
            if currentPlayer and not currentPlayer.Character and (tick() - state.lastRespawn) > 15 then
                log("Character missing for extended period")
                safeCollectGarbage(true)
            end
            
            if currentPlayer and currentPlayer.Character then
                state.lastRespawn = tick()
            end
        end
    end)
end

-- Network monitoring (new feature)
local function monitorNetwork()
    task.spawn(function()
        while task.wait(5) do
            pcall(function()
                local networkStats = stats:FindFirstChild("Network")
                if networkStats then
                    local serverStatsItem = networkStats:FindFirstChild("ServerStatsItem")
                    if serverStatsItem then
                        local ping = serverStatsItem["Data Ping"]:GetValue()
                        state.averagePing = ping
                        
                        if ping > CONFIG.PING_THRESHOLD_MS then
                            log(string.format("High ping detected: %dms", ping))
                            state.performanceScore = math.max(0, state.performanceScore - 5)
                        end
                    end
                end
            end)
        end
    end)
end

-- Enhanced error prompt detection
local function setupAutoReconnect()
    pcall(function()
        local connection = guiService.ErrorMessageChanged:Connect(function()
            if guiService:GetErrorMessage() ~= "" then
                log("Roblox error detected: " .. guiService:GetErrorMessage())
                sendNotification("Error Detected", "Reconnecting to prevent crash...")
                task.wait(CONFIG.RECONNECT_DELAY_SECONDS)
                teleportService:Teleport(game.PlaceId)
            end
        end)
        
        state.connections.errorMonitor = connection
    end)
end

-- Performance reporting
local function startPerformanceReporting()
    task.spawn(function()
        while task.wait(30) do
            local memUsage = collectgarbage("count") / 1024
            local status = state.emergencyMode and "EMERGENCY" or "NORMAL"
            
            log(string.format("Performance Report - Status: %s | FPS: %.1f | Memory: %.1fMB | Score: %d | Ping: %dms", 
                status, state.currentFPS, memUsage, state.performanceScore, state.averagePing))
            
            -- Auto-recovery attempts if performance is stable
            if not state.emergencyMode and state.performanceScore > 80 then
                pcall(function()
                    local currentQuality = settings().Rendering.QualityLevel
                    if currentQuality < CONFIG.INITIAL_QUALITY_CAP then
                        settings().Rendering.QualityLevel = math.min(CONFIG.INITIAL_QUALITY_CAP, currentQuality + 1)
                        log("Auto-improved graphics to level " .. settings().Rendering.QualityLevel)
                    end
                end)
            end
        end
    end)
end

-- Cleanup function for script termination
local function cleanup()
    log("Cleaning up anti-crash system...")
    for name, connection in pairs(state.connections) do
        if connection and connection.Connected then
            connection:Disconnect()
            log("Disconnected: " .. name)
        end
    end
end

-- Enhanced initialization with better error handling
local function initialize()
    log("Initializing Zero-Crash Prevention System v2.0...")
    
    -- Initial optimizations
    pcall(function()
        local renderSettings = settings().Rendering
        
        -- Set initial quality cap
        if renderSettings.QualityLevel > CONFIG.INITIAL_QUALITY_CAP then
            renderSettings.QualityLevel = CONFIG.INITIAL_QUALITY_CAP
            log("Set initial graphics quality to level " .. CONFIG.INITIAL_QUALITY_CAP)
        end
        
        -- Proactive optimizations
        if CONFIG.DISABLE_WATER_REFLECTIONS then
            lighting.WaterReflectance = 0
            lighting.WaterTransparency = 0.5
            lighting.WaterWaveSize = 0.05
            lighting.WaterWaveSpeed = 5
            log("Optimized water settings")
        end
        
        if CONFIG.DISABLE_FOG then
            lighting.FogEnd = 100000
            lighting.FogStart = 100000
            log("Disabled fog for performance")
        end
        
        -- Optimize existing particles
        local particleCount = 0
        for _, obj in pairs(workspace:GetDescendants()) do
            if obj:IsA("ParticleEmitter") then
                obj.Rate = math.min(obj.Rate, 50) -- Limit particle rate
                particleCount = particleCount + 1
            elseif obj:IsA("Trail") then
                obj.Lifetime = math.min(obj.Lifetime, 2) -- Limit trail lifetime
            end
            
            if particleCount % 20 == 0 then
                task.wait() -- Prevent script timeout
            end
        end
        
        if particleCount > 0 then
            log(string.format("Optimized %d particle emitters", particleCount))
        end
        
        -- Memory optimization
        collectgarbage("collect")
        log("Initial memory cleanup completed")
    end)
    
    -- Setup heartbeat monitoring
    state.connections.heartbeat = runService.Heartbeat:Connect(function()
        state.lastHeartbeat = tick()
    end)
    
    -- Start all monitoring systems
    monitorMemory()
    monitorFreeze()
    monitorPlayer()
    monitorNetwork()
    monitorFPS()
    setupAutoReconnect()
    startPerformanceReporting()
    
    -- Handle script termination
    game:BindToClose(cleanup)
    
    -- Success notification
    sendNotification("System Active", "Zero-Crash Prevention System loaded successfully!")
    log("All monitoring systems activated successfully!")
    
    -- Initial performance baseline
    state.performanceScore = 85
    log(string.format("Initial performance score: %d", state.performanceScore))
end

-- Advanced crash prediction system
local function setupCrashPrediction()
    task.spawn(function()
        local crashRiskFactors = {
            highMemory = 0,
            lowFPS = 0,
            networkLag = 0,
            freezeEvents = 0,
            errorCount = 0
        }
        
        while task.wait(10) do
            -- Calculate crash risk
            local memUsage = collectgarbage("count") / 1024
            crashRiskFactors.highMemory = memUsage > CONFIG.CRITICAL_MEMORY_THRESHOLD_MB and 
                crashRiskFactors.highMemory + 1 or math.max(0, crashRiskFactors.highMemory - 1)
            
            crashRiskFactors.lowFPS = state.currentFPS < CONFIG.LOW_FPS_THRESHOLD and 
                crashRiskFactors.lowFPS + 1 or math.max(0, crashRiskFactors.lowFPS - 1)
            
            crashRiskFactors.networkLag = state.averagePing > CONFIG.PING_THRESHOLD_MS and 
                crashRiskFactors.networkLag + 1 or math.max(0, crashRiskFactors.networkLag - 1)
            
            crashRiskFactors.freezeEvents = state.freezeCount
            
            -- Calculate total risk score
            local totalRisk = crashRiskFactors.highMemory + crashRiskFactors.lowFPS + 
                            crashRiskFactors.networkLag + crashRiskFactors.freezeEvents
            
            -- Predictive actions based on risk
            if totalRisk >= 6 and not state.emergencyMode then
                log(string.format("High crash risk detected (score: %d) - Taking preventive action", totalRisk))
                enterEmergencyMode()
            elseif totalRisk >= 4 then
                log(string.format("Moderate crash risk (score: %d) - Performing maintenance", totalRisk))
                safeCollectGarbage(true)
                
                -- Gradual quality reduction
                pcall(function()
                    local currentQuality = settings().Rendering.QualityLevel
                    if currentQuality > CONFIG.EMERGENCY_QUALITY_LEVEL + 1 then
                        settings().Rendering.QualityLevel = currentQuality - 1
                        log("Preventively reduced graphics quality to " .. settings().Rendering.QualityLevel)
                    end
                end)
            end
        end
    end)
end

-- Enhanced error handling wrapper
local function safeExecute(func, name)
    local success, error = pcall(func)
    if not success then
        log(string.format("Error in %s: %s", name, tostring(error)))
        -- Don't let individual component failures crash the whole system
        return false
    end
    return true
end

-- Memory leak detection
local function setupMemoryLeakDetection()
    task.spawn(function()
        local memoryHistory = {}
        
        while task.wait(60) do -- Check every minute
            local currentMem = collectgarbage("count") / 1024
            table.insert(memoryHistory, {time = tick(), memory = currentMem})
            
            -- Keep only last 10 minutes of data
            while #memoryHistory > 10 do
                table.remove(memoryHistory, 1)
            end
            
            -- Detect memory leaks (consistent upward trend)
            if #memoryHistory >= 5 then
                local trend = 0
                for i = 2, #memoryHistory do
                    if memoryHistory[i].memory > memoryHistory[i-1].memory then
                        trend = trend + 1
                    end
                end
                
                -- If memory consistently increases
                if trend >= 4 then
                    local memIncrease = memoryHistory[#memoryHistory].memory - memoryHistory[1].memory
                    if memIncrease > 50 then -- 50MB increase over monitoring period
                        log(string.format("Memory leak detected! Increased by %.1fMB over %d minutes", 
                            memIncrease, #memoryHistory))
                        
                        -- Aggressive cleanup
                        safeCollectGarbage(true)
                        
                        -- If still high after cleanup, enter emergency mode
                        task.wait(2)
                        if collectgarbage("count") / 1024 > CONFIG.CRITICAL_MEMORY_THRESHOLD_MB then
                            enterEmergencyMode()
                        end
                    end
                end
            end
        end
    end)
end

-- Start the system with comprehensive error handling
safeExecute(function()
    initialize()
    setupCrashPrediction()
    setupMemoryLeakDetection()
end, "System Initialization")

-- Final status
log("Zero-Crash Prevention System v2.0 - Fully Loaded and Active!")
log("Features: Memory Management | FPS Monitoring | Freeze Detection | Network Monitoring | Crash Prediction | Memory Leak Detection")

-- Keep script alive and provide status updates
task.spawn(function()
    while task.wait(300) do -- Every 5 minutes
        if state.emergencyMode then
            log("Status: EMERGENCY MODE ACTIVE - Maximum protection engaged")
        else
            log(string.format("Status: NORMAL OPERATION - Performance Score: %d/100", state.performanceScore))
        end
    end
end)
