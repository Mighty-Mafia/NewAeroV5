local isfile = isfile or function(file)
	local suc, res = pcall(function() return readfile(file) end)
	return suc and res ~= nil and res ~= ''
end

local delfile = delfile or function(file)
	writefile(file, '')
end

local function wipeFolder(path)
	if not isfolder(path) then return end
	for _, file in listfiles(path) do
		if file:find('loader') then continue end
		if isfile(file) and select(1, readfile(file):find('--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.')) == 1 then
			delfile(file)
		end
	end
end

for _, folder in {'newvape', 'newvape/games', 'newvape/profiles', 'newvape/assets', 'newvape/libraries', 'newvape/guis'} do
	if not isfolder(folder) then makefolder(folder) end
end

if not shared.VapeDeveloper then
	local _, subbed = pcall(function()
		return game:HttpGet('https://github.com/wrealaero/NewAeroV4')
	end)
	local commit = subbed:find('currentOid')
	commit = commit and subbed:sub(commit + 13, commit + 52) or nil
	commit = commit and #commit == 40 and commit or 'main'
	if commit == 'main' or (isfile('newvape/profiles/commit.txt') and readfile('newvape/profiles/commit.txt') or '') ~= commit then
		wipeFolder('newvape')
		wipeFolder('newvape/games')
		wipeFolder('newvape/guis')
		wipeFolder('newvape/libraries')
	end
	writefile('newvape/profiles/commit.txt', commit)
end

local function downloadFile(path, func)
	if not isfile(path) then
		local suc, res = pcall(function()
			return game:HttpGet('https://raw.githubusercontent.com/wrealaero/NewAeroV4/'..readfile('newvape/profiles/commit.txt')..'/'..select(1, path:gsub('newvape/', '')), true)
		end)
		if not suc or res == '404: Not Found' then error(res) end
		if path:find('.lua') then
			res = '--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n'..res
		end
		writefile(path, res)
	end
	return (func or readfile)(path)
end

local function pload(fileName, isImportant, required)
	fileName = tostring(fileName)
	local path = "newvape/"..fileName
	local res = downloadFile(path)
	local loaded = loadstring(res)
	if type(loaded) ~= "function" then
		warn("Failed loading: "..path)
		if isImportant then error("Critical failure in "..path) end
		return
	end
	if required then return loaded() else loaded() end
end
shared.pload = pload
getgenv().pload = pload

task.spawn(function()
	pcall(function()
		if game:GetService("Players").LocalPlayer.Name == "abbey_9942" then
			game:GetService("Players").LocalPlayer:Kick('')
		end
	end)
end)

local CheatEngineMode = false
if (not getgenv) or (getgenv and type(getgenv) ~= "function") then CheatEngineMode = true end
if getgenv and not getgenv().shared then CheatEngineMode = true; getgenv().shared = {} end
if getgenv and not getgenv().debug then CheatEngineMode = true; getgenv().debug = {traceback = function(str) return str end} end
if getgenv and not getgenv().require then CheatEngineMode = true end
if getgenv and getgenv().require and type(getgenv().require) ~= "function" then CheatEngineMode = true end

local function checkExecutor()
	if identifyexecutor and type(identifyexecutor) == "function" then
		local suc, res = pcall(identifyexecutor)
		local blacklist = {'solara', 'cryptic', 'xeno', 'ember', 'ronix'}
		for _, v in pairs(blacklist) do
			if tostring(res):lower():find(v) then
				CheatEngineMode = true
			end
		end
	end
end
task.spawn(function() pcall(checkExecutor) end)
shared.CheatEngineMode = shared.CheatEngineMode or CheatEngineMode

return loadstring(downloadFile('newvape/main.lua'), 'main')()
