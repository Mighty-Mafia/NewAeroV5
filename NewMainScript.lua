local old_require = require
getgenv().require = function(path)
	setthreadidentity(2)
	local _ = old_require(path)
	setthreadidentity(8)
	return _
end

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local whitelist_url = "https://raw.githubusercontent.com/wrealaero/whitelistcheck/main/whitelist.json"

local function sha256(str)
	local ok, result = pcall(function()
		return (syn and syn.crypt and syn.crypt.hash or crypt and crypt.hash or hashlib and hashlib.sha256 or function(s)
			error("No SHA256 function found!")
		end)(str, "sha256"):lower()
	end)

	if ok then return result end
	error("SHA256 hashing not supported on this executor.")
end

local function getWhitelist()
	local success, response = pcall(function()
		return game:HttpGet(whitelist_url)
	end)
	if success and response then
		local successDecode, whitelist = pcall(function()
			return HttpService:JSONDecode(response)
		end)
		if successDecode then
			return whitelist
		end
	end
	return nil
end

-- Hash current userId
local hashedId = sha256(tostring(player.UserId))
local whitelist = getWhitelist()

if whitelist and whitelist[hashedId] then
	-- ✅ WHITELISTED USERS ONLY

	-- File helpers
	local isfile = isfile or function(file)
		local suc, res = pcall(function() return readfile(file) end)
		return suc and res ~= nil and res ~= ''
	end

	local delfile = delfile or function(file)
		pcall(function() writefile(file, '') end)
	end

	local function downloadFile(path, func)
		if not isfile(path) then
			local suc, res = pcall(function()
				return game:HttpGet('https://raw.githubusercontent.com/wrealaero/NewAeroV4/' .. readfile('newvape/profiles/commit.txt') .. '/' .. select(1, path:gsub('newvape/', '')), true)
			end)
			if not suc or res == '404: Not Found' then
				warn("Failed to download file: " .. tostring(res))
				return nil
			end
			if path:find('.lua') then
				res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n' .. res
			end
			pcall(function() writefile(path, res) end)
		end
		return (func or readfile)(path)
	end

	local function wipeFolder(path)
		if not isfolder(path) then return end
		for _, file in pairs(listfiles(path)) do
			if file:find('loader') then continue end
			if isfile(file) and select(1, readfile(file):find('--This watermark is used to delete the file if its cached')) == 1 then
				delfile(file)
			end
		end
	end

	local function loadMainScript()
		if not shared.VapeDeveloper then
			local retries = 3
			local subbed

			while retries > 0 do
				local success, response = pcall(function()
					return game:HttpGet('https://github.com/wrealaero/NewAeroV4')
				end)

				if success and response then
					subbed = response
					break
				end

				retries -= 1
				wait(1)
			end

			if subbed then
				local commit = subbed:find('currentOid')
				commit = commit and subbed:sub(commit + 13, commit + 52) or nil
				commit = commit and #commit == 40 and commit or 'main'

				if commit == 'main' or (isfile('newvape/profiles/commit.txt') and readfile('newvape/profiles/commit.txt') or '') ~= commit then
					wipeFolder('newvape')
					wipeFolder('newvape/games')
					wipeFolder('newvape/guis')
					wipeFolder('newvape/libraries')
				end

				pcall(function() writefile('newvape/profiles/commit.txt', commit) end)
			end
		end

		local success, err = pcall(function()
			loadstring(downloadFile('newvape/main.lua'), 'main')()
		end)
		if not success then
			warn("Failed to load script: " .. tostring(err))
			return false
		else
			return true
		end
	end

	local currentPlaceId = game.PlaceId
	local shopLoaded = false

	shopLoaded = loadMainScript()

	player.OnTeleport:Connect(function(state)
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

	game:GetService("RunService").Heartbeat:Connect(function()
		if game.PlaceId ~= currentPlaceId then
			currentPlaceId = game.PlaceId
			task.wait(5)
			shopLoaded = loadMainScript()
		end

		if not shopLoaded and player and player.Character then
			local inLobby = false

			if game.PlaceId == 6872265039 or game.PlaceId == 6872274481 or player:FindFirstChild("InLobby") then
				inLobby = true
			end

			if inLobby then
				shopLoaded = loadMainScript()
			end
		end
	end)

	player.CharacterAdded:Connect(function()
		task.wait(2)
		if not shopLoaded then
			shopLoaded = loadMainScript()
		end
	end)

	game:GetService("RunService").Heartbeat:Connect(function()
		local gameState = game:GetService("ReplicatedStorage"):FindFirstChild("GameState")
		if gameState then
			local currentState = gameState.Value
			if currentState == "Lobby" then
				shopLoaded = loadMainScript()
			end
		end
	end)
else
    game.StarterGui:SetCore("SendNotification", {
        Title = "Fuck nah u thought",
        Text = "ur not whitelisted nn lmao",
        Duration = 2
    })
end
