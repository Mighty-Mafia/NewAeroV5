local old_require = require
getgenv().require = function(path)
    setthreadidentity(2)
    local _ = old_require(path)
    setthreadidentity(8)
    return _
end

local whitelist_url = "https://raw.githubusercontent.com/wrealaero/whitelistcheck/main/whitelist.json"
local player = game.Players.LocalPlayer
local userId = tostring(player.UserId)

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

local function getWhitelist()
    local success, response = httpGet(whitelist_url)
    
    if success and response then
        local successDecode, whitelist = pcall(function()
            return game:GetService("HttpService"):JSONDecode(response)
        end)
        
        if successDecode then
            return whitelist
        else
            warn("Failed to decode whitelist JSON")
        end
    else
        warn("Failed to fetch whitelist")
    end
    
    return nil
end

local whitelist = getWhitelist()

if whitelist and whitelist[userId] then
    -- Log to console instead of notification
    print("Access Granted: Whitelist check passed. Loading script...")
    
    local isfile = isfile or function(file)
        local suc, res = pcall(function() return readfile(file) end)
        return suc and res ~= nil and res ~= ''
    end
    
    local delfile = delfile or function(file)
        pcall(function() writefile(file, '') end)
    end
    
    -- Improved download function with console logging only
    local function downloadFile(path, func)
        if not isfile(path) then
            -- Log to console
            print("Downloading: " .. path)
            
            local commitPath = 'newvape/profiles/commit.txt'
            local commit = isfile(commitPath) and readfile(commitPath) or 'main'
            local url = 'https://raw.githubusercontent.com/wrealaero/NewAeroV4/' .. commit .. '/' .. select(1, path:gsub('newvape/', ''))
            
            local success, res = httpGet(url)
            
            if not success or res == '404: Not Found' then
                warn("Failed to download: " .. path)
                return nil
            end
            
            if path:find('.lua') then
                res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n' .. res
            end
            
            pcall(function() writefile(path, res) end)
            
            -- Log to console
            print("Download Complete: " .. path)
        end
        
        return (func or readfile)(path)
    end
    
    local function wipeFolder(path)
        if not isfolder(path) then return end
        for _, file in pairs(listfiles(path)) do
            if file:find('loader') then continue end
            if isfile(file) and select(1, readfile(file):find('--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.')) == 1 then
                delfile(file)
            end
        end
    end
    
    -- Create necessary folders
    for _, folder in pairs({'newvape', 'newvape/games', 'newvape/profiles', 'newvape/assets', 'newvape/libraries', 'newvape/guis'}) do
        if not isfolder(folder) then
            pcall(function() makefolder(folder) end)
        end
    end
    
    local function loadMainScript()
        if not shared.VapeDeveloper then
            local retries = 3
            local subbed
            
            -- Log to console
            print("Checking for latest version...")
            
            while retries > 0 do
                local success, response = pcall(function()
                    return game:HttpGet('https://github.com/wrealaero/NewAeroV4')
                end)
                
                if success and response then
                    subbed = response
                    break
                end
                
                retries = retries - 1
                wait(1.5)
            end
            
            if subbed then
                local commit = subbed:find('currentOid')
                commit = commit and subbed:sub(commit + 13, commit + 52) or nil
                commit = commit and #commit == 40 and commit or 'main'
                
                if commit == 'main' or (isfile('newvape/profiles/commit.txt') and readfile('newvape/profiles/commit.txt') or '') ~= commit then
                    -- Log to console
                    print("Cleaning up old files...")
                    
                    wipeFolder('newvape')
                    wipeFolder('newvape/games')
                    wipeFolder('newvape/guis')
                    wipeFolder('newvape/libraries')
                end
                
                pcall(function() writefile('newvape/profiles/commit.txt', commit) end)
            end
        end
        
        -- Log to console
        print("Loading main script...")
        
        local success, err = pcall(function()
            loadstring(downloadFile('newvape/main.lua'), 'main')()
        end)
        
        if not success then
            warn("Failed to load main script: " .. tostring(err))
            return false
        else
            print("Main script loaded successfully")
            return true
        end
    end
    
    local currentPlaceId = game.PlaceId
    local shopLoaded = false
    
    -- Try to load main script
    shopLoaded = loadMainScript()
    
    -- Handle teleportation
    game:GetService("Players").LocalPlayer.OnTeleport:Connect(function(state)
        if state == Enum.TeleportState.Started then
            syn = syn or {}
            if syn.queue_on_teleport then
                syn.queue_on_teleport([[
                    repeat wait() until game:IsLoaded()
                    loadstring(game:HttpGet('https://raw.githubusercontent.com/wrealaero/NewAeroV4/main/loader.lua'))()
                ]])
            end
        end
    end)
    
    -- Check for place changes and reload if needed
    game:GetService("RunService").Heartbeat:Connect(function()
        if game.PlaceId ~= currentPlaceId then
            currentPlaceId = game.PlaceId
            task.wait(5)
            shopLoaded = loadMainScript()
        end
        
        if not shopLoaded and game:GetService("Players").LocalPlayer and game:GetService("Players").LocalPlayer.Character then
            local inLobby = false
            if game.PlaceId == 6872265039 or
                game.PlaceId == 6872274481 or
                game:GetService("Players").LocalPlayer:FindFirstChild("InLobby") then
                inLobby = true
            end
            
            if inLobby then
                shopLoaded = loadMainScript()
            end
        end
    end)
    
    -- Reload on character spawn
    game:GetService("Players").LocalPlayer.CharacterAdded:Connect(function()
        task.wait(2)
        if not shopLoaded then
            shopLoaded = loadMainScript()
        end
    end)
    
    -- Check game state changes
    local gameStateChanged = false
    game:GetService("RunService").Heartbeat:Connect(function()
        local gameState = game:GetService("ReplicatedStorage"):FindFirstChild("GameState")
        if gameState then
            local currentState = gameState.Value
            if currentState == "Lobby" and not gameStateChanged then
                gameStateChanged = true
                shopLoaded = loadMainScript()
            elseif currentState ~= "Lobby" then
                gameStateChanged = false
            end
        end
    end)
else
    -- Keep only this notification
    game.StarterGui:SetCore("SendNotification", {
        Title = "Access Denied",
        Text = "You are not whitelisted",
        Duration = 3
    })
end
