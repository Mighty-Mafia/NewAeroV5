local isfile = isfile or function(file)
    local suc, res = pcall(function()
        return readfile(file)
    end)
    return suc and res ~= nil and res ~= ''
end

local isfolder = isfolder or function(folder)
    local suc, res = pcall(function()
        return listfiles(folder)
    end)
    return suc and res ~= nil
end

local function makefolder(path)
    if not isfolder(path) then
        pcall(function()
            return makefolder(path)
        end)
    end
end

local function downloadFile(url, path)
    if not isfile(path) then
        local content = game:HttpGet(url, true)
        writefile(path, content)
    end
    return readfile(path)
end

local function checkAndDownload()
    makefolder("AeroV4Lib")
    
    local filesToDownload = {
        {
            url = "https://raw.githubusercontent.com/wrealaero/NewAeroV4/main/AeroV4BAD.lua",
            path = "AeroV4Lib/AeroV4BAD.lua"
        },
    
    for _, fileInfo in pairs(filesToDownload) do
        local success, err = pcall(function()
            downloadFile(fileInfo.url, fileInfo.path)
        end)
        
        if not success then
            warn("Failed to download " .. fileInfo.path .. ": " .. err)
        end
    end
    
    if isfile("AeroV4Lib/AeroV4BAD.lua") then
        return true
    end
    return false
end

local downloadSuccess = checkAndDownload()

if downloadSuccess then
    loadstring(game:HttpGet("https://raw.githubusercontent.com/wrealaero/NewAeroV4/main/AeroV4BAD.lua", true))()
else
    warn("failed to downlaod files check ur internet")
end
