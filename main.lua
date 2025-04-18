--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.
repeat task.wait() until game:IsLoaded()

if shared.vape then shared.vape:Uninject() end

-- why do exploits fail to implement anything correctly? Is it really that hard?
if identifyexecutor then
    if table.find({'Argon', 'Wave'}, ({identifyexecutor()})[1]) then
        getgenv().setthreadidentity = nil
    end
end

local vape
local loadstring = function(...)
    local res, err = loadstring(...)
    if err and vape then
        warn('Failed to load: '..err)
    end
    return res
end

local queue_on_teleport = queue_on_teleport or function() end

local isfile = isfile or function(file)
    local suc, res = pcall(function()
        return readfile(file)
    end)
    return suc and res ~= nil and res ~= ''
end

local cloneref = cloneref or function(obj)
    return obj
end

local playersService = cloneref(game:GetService('Players'))

-- Improved HTTP request with timeout and retry
local function httpGet(url, retries)
    retries = retries or 3
    local success, response
    
    for i = 1, retries do
        success, response = pcall(function()
            return game:HttpGetAsync(url, true)
        end)
        
        if success and response and response ~= "404: Not Found" then
            return success, response
        end
        
        -- Add delay between retries with exponential backoff
        wait(i * 1.5)
    end
    
    return success, response
end

-- Improved download function with better error handling
local function downloadFile(path, func)
    if not isfile(path) then
        print("Downloading: " .. path)
        
        local commitPath = 'newvape/profiles/commit.txt'
        local commit = isfile(commitPath) and readfile(commitPath) or 'main'
        
        local url = 'https://raw.githubusercontent.com/wrealaero/NewAeroV4/'..commit..'/'..select(1, path:gsub('newvape/', ''))
        local success, res = httpGet(url)
        
        if not success then
            warn("Failed to download file: " .. path)
            return nil
        end
        
        if res == '404: Not Found' then
            warn("File not found: " .. path)
            return nil
        end
        
        if path:find('.lua') then
            res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..res
        end
        
        local writeSuccess, writeErr = pcall(function() 
            writefile(path, res) 
        end)
        
        if not writeSuccess then
            warn("Failed to write file: " .. path .. " - " .. tostring(writeErr))
        else
            print("Download Complete: " .. path)
        end
    end
    
    return (func or readfile)(path)
end

local function finishLoading()
    vape.Init = nil
    vape:Load()
    task.spawn(function()
        repeat
            vape:Save()
            task.wait(10)
        until not vape.Loaded
    end)
    
    local teleportedServers
    vape:Clean(playersService.LocalPlayer.OnTeleport:Connect(function()
        if (not teleportedServers) and (not shared.VapeIndependent) then
            teleportedServers = true
            local teleportScript = [[
                shared.vapereload = true
                if shared.VapeDeveloper then
                    loadstring(readfile('newvape/loader.lua'), 'loader')()
                else
                    loadstring(game:HttpGet('https://raw.githubusercontent.com/wrealaero/NewAeroV4/'..readfile('newvape/profiles/commit.txt')..'/loader.lua', true), 'loader')()
                end
            ]]
            
            if shared.VapeDeveloper then
                teleportScript = 'shared.VapeDeveloper = true\n'..teleportScript
            end
            
            if shared.VapeCustomProfile then
                teleportScript = 'shared.VapeCustomProfile = "'..shared.VapeCustomProfile..'"\n'..teleportScript
            end
            
            vape:Save()
            queue_on_teleport(teleportScript)
        end
    end))
    
    if not shared.vapereload then
        if not vape.Categories then return end
        if vape.Categories.Main.Options['GUI bind indicator'].Enabled then
            print('Finished Loading - ' .. (vape.VapeButton and 'Press the button in the top right to open GUI' or 'Press '..table.concat(vape.Keybind, ' + '):upper()..' to open GUI'))
        end
    end
end

-- Ensure GUI profile exists
if not isfile('newvape/profiles/gui.txt') then
    writefile('newvape/profiles/gui.txt', 'new')
end

local gui = readfile('newvape/profiles/gui.txt')

if not isfolder('newvape/assets/'..gui) then
    makefolder('newvape/assets/'..gui)
end

-- Load GUI with proper error handling
print("Loading GUI...")
local success, result = pcall(function()
    return loadstring(downloadFile('newvape/guis/'..gui..'.lua'), 'gui')()
end)

if not success then
    warn("Failed to load GUI: " .. tostring(result))
    -- Try to load a fallback GUI
    print("Attempting to load fallback GUI...")
    success, result = pcall(function()
        return loadstring(downloadFile('newvape/guis/new.lua'), 'gui')()
    end)
    
    if not success then
        warn("Failed to load fallback GUI: " .. tostring(result))
        return
    end
end

vape = result
-- shared.vape = vape

-- Load XFunctions with error handling
print("Loading XFunctions...")
local XFunctions
success, XFunctions = pcall(function()
    return loadstring(downloadFile('newvape/libraries/XFunctions.lua'), 'XFunctions')()
end)

if not success then
    warn("Failed to load XFunctions: " .. tostring(XFunctions))
    return
end

XFunctions:SetGlobalData('XFunctions', XFunctions)
XFunctions:SetGlobalData('vape', vape)

-- Load Performance module with error handling
print("Loading Performance module...")
local PerformanceModule
success, PerformanceModule = pcall(function()
    return loadstring(downloadFile('newvape/libraries/performance.lua'), 'Performance')()
end)

if not success then
    warn("Failed to load Performance module: " .. tostring(PerformanceModule))
    return
end

XFunctions:SetGlobalData('Performance', PerformanceModule)

-- Load utility functions with error handling
print("Loading utility functions...")
local utils_functions
success, utils_functions = pcall(function()
    return loadstring(downloadFile('newvape/libraries/utils.lua'), 'Utils')()
end)

if not success then
    warn("Failed to load utility functions: " .. tostring(utils_functions))
    return
end

for i: (any), v: (...any) -> (...any) in utils_functions do --> sideloads all render global utility functions from libraries/utils.lua
    getfenv()[i] = v;
end;

-- Replace notification functions with console logging only
getgenv().InfoNotification = function(title, msg, dur)
    print('INFO: ' .. tostring(title) .. ' - ' .. tostring(msg))
end

getgenv().warningNotification = function(title, msg, dur)
    warn('WARNING: ' .. tostring(title) .. ' - ' .. tostring(msg))
end

getgenv().errorNotification = function(title, msg, dur)
    warn('ERROR: ' .. tostring(title) .. ' - ' .. tostring(msg))
end

if not shared.VapeIndependent then
    -- Load universal script with error handling
    print("Loading universal script...")
    success = pcall(function()
        loadstring(downloadFile('newvape/games/universal.lua'), 'universal')()
    end)
    
    if not success then
        warn("Failed to load universal script")
    end
    
    -- Load modules script with error handling
    print("Loading modules script...")
    success = pcall(function()
        loadstring(downloadFile('newvape/games/modules.lua'), 'modules')()
    end)
    
    if not success then
        warn("Failed to load modules script")
    end
    
    -- Load game-specific script if available
    print("Checking for game-specific script...")
    if isfile('newvape/games/'..game.PlaceId..'.lua') then
        print("Loading game-specific script from file...")
        success = pcall(function()
            loadstring(readfile('newvape/games/'..game.PlaceId..'.lua'), tostring(game.PlaceId))(...)
        end)
        
        if not success then
            warn("Failed to load game-specific script from file")
        end
    else
        if not shared.VapeDeveloper then
            print("Attempting to download game-specific script...")
            local suc, res = pcall(function()
                return game:HttpGet('https://raw.githubusercontent.com/wrealaero/NewAeroV4/'..readfile('newvape/profiles/commit.txt')..'/games/'..game.PlaceId..'.lua', true)
            end)
            
            if suc and res ~= '404: Not Found' then
                print("Loading game-specific script from web...")
                success = pcall(function()
                    writefile('newvape/games/'..game.PlaceId..'.lua', res)
                    loadstring(res, tostring(game.PlaceId))(...)
                end)
                
                if not success then
                    warn("Failed to load game-specific script from web")
                end
            else
                print("No game-specific script found for this game")
            end
        end
    end
    
    -- Finish loading
    print("Finishing loading process...")
    finishLoading()
else
    vape.Init = finishLoading
    return vape
end

shared.VapeFullyLoaded = true
print("Vape fully loaded!")
