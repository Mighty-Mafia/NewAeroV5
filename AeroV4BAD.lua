-- This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.
-- This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.
-- This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.
-- This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.
-- This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.
-- This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.

local run = function(func)
	func()
end

local ScriptIdentifier = "VapeScript_" .. tostring(math.random(1000000, 9999999))
if getgenv().VapeScriptInstances then
    for _, cleanup in pairs(getgenv().VapeScriptInstances) do
        pcall(cleanup)
    end
end
getgenv().VapeScriptInstances = {}

local function addCleanupFunction(func)
    table.insert(getgenv().VapeScriptInstances, func)
end

local cloneref = cloneref or function(obj)
	return obj
end

local vapeEvents = setmetatable({}, {
	__index = function(self, index)
		self[index] = Instance.new('BindableEvent')
		return self[index]
	end
})

local entitylib = {
    isAlive = false,
    character = {},
    List = {},
    Connections = {},
    PlayerConnections = {},
    EntityThreads = {},
    Running = false,
    Events = setmetatable({}, {
        __index = function(self, ind)
            self[ind] = {
                Connections = {},
                Connect = function(rself, func)
                    table.insert(rself.Connections, func)
                    return {
                        Disconnect = function()
                            local rind = table.find(rself.Connections, func)
                            if rind then
                                table.remove(rself.Connections, rind)
                            end
                        end
                    }
                end,
                Fire = function(rself, ...)
                    for _, v in rself.Connections do
                        task.spawn(v, ...)
                    end
                end,
                Destroy = function(rself)
                    table.clear(rself.Connections)
                    table.clear(rself)
                end
            }

            return self[ind]
        end
    })
}

local cloneref = cloneref or function(obj)
    return obj
end
local playersService = cloneref(game:GetService('Players'))
local inputService = cloneref(game:GetService('UserInputService'))
local lplr = playersService.LocalPlayer
local gameCamera = workspace.CurrentCamera

local function getItem(itemName, inv)
	for slot, item in (inv or store.inventory.inventory.items) do
		if item.itemType == itemName then
			return item, slot
		end
	end
	return nil
end

local function getTool(breakType)
    local bestTool, bestToolSlot, bestToolDamage = nil, nil, 0
    for slot, item in store.inventory.inventory.items do
        local toolMeta = bedwars.ItemMeta[item.itemType].breakBlock
        if toolMeta then
            local toolDamage = toolMeta[breakType] or 0
            if toolDamage > bestToolDamage then
                bestTool, bestToolSlot, bestToolDamage = item, slot, toolDamage
            end
        end
    end
    if bestTool then
    else
    end
    return bestTool, bestToolSlot
end

local function hotbarSwitch(slot)
	if slot and store.inventory.hotbarSlot ~= slot then
		bedwars.Store:dispatch({
			type = 'InventorySelectHotbarSlot',
			slot = slot
		})
		vapeEvents.InventoryChanged.Event:Wait()
		return true
	end
	return false
end

local function switchItem(tool, delayTime)
	delayTime = delayTime or 0.05
	local check = lplr.Character and lplr.Character:FindFirstChild('HandInvItem') or nil
	if check and check.Value ~= tool and tool.Parent ~= nil then
		task.spawn(function()
			bedwars.Client:Get(remotes.EquipItem):CallServerAsync({hand = tool})
		end)
		check.Value = tool
		if delayTime > 0 then
			task.wait(delayTime)
		end
		return true
	end
end

local function getMousePosition()
    if inputService.TouchEnabled then
        return gameCamera.ViewportSize / 2
    end
    return inputService.GetMouseLocation(inputService)
end

local function loopClean(tbl)
    for i, v in tbl do
        if type(v) == 'table' then
            loopClean(v)
        end
        tbl[i] = nil
    end
end

local function waitForChildOfType(obj, name, timeout, prop)
    local checktick = tick() + timeout
    local returned
    repeat
        returned = prop and obj[name] or obj:FindFirstChildOfClass(name)
        if returned or checktick < tick() then break end
        task.wait()
    until false
    return returned
end

local store = {
	attackReach = 0,
	attackReachUpdate = tick(),
	damageBlockFail = tick(),
	hand = {},
	inventory = {
		inventory = {
			items = {},
			armor = {}
		},
		hotbar = {}
	},
	inventories = {},
	matchState = 0,
	queueType = 'bedwars_test',
	tools = {}
}
local Reach = {}
local HitBoxes = {}
local InfiniteFly = {}
local TrapDisabler
local AntiFallPart
local bedwars, remotes, sides, oldinvrender, oldSwing = {}, {}, {}

bedwars.breakBlock = function(block)
    if not block or not entitylib.isAlive then return end

    local meta = bedwars.ItemMeta[block.Name]
    if meta and meta.block and meta.block.breakType then
        local breaktype = meta.block.breakType
        local tool, slot = getTool(breaktype)
        if tool and slot then
            switchItem(tool)
        end
    end

    bedwars.Client:Get("DamageBlock"):CallServer({
        blockRef = {blockPosition = block.Position / 3},
        hitPosition = block.Position,
        hitNormal = Vector3.new(0, 1, 0)
    })
end


local function errorNotification(title, message, duration)
    if shared.vape then
        shared.vape:CreateNotification(title, message, duration, 'alert')
    else
        warn("Notification: [" .. title .. "] " .. message)
    end
end

local playersService = cloneref(game:GetService("Players"))
local lplr = playersService.LocalPlayer
local replicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local gameCamera = workspace.CurrentCamera
local bedwars = {}
remotes = {
    EquipItem = "EquipItem"
}
local oldbreak, oldget = {}, {}

run(function()
	local KnitInit, Knit
	repeat
		KnitInit, Knit = pcall(function()
			return debug.getupvalue(require(game:GetService("Players").LocalPlayer.PlayerScripts.TS.knit).setup, 9)
		end)
		if KnitInit then break end
		task.wait()
	until KnitInit

	if not debug.getupvalue(Knit.Start, 1) then
		repeat task.wait() until debug.getupvalue(Knit.Start, 1)
	end

	local replicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
	local lplr = cloneref(game:GetService("Players")).LocalPlayer
	local gameCamera = workspace.CurrentCamera

	local Flamework = require(replicatedStorage['rbxts_include']['node_modules']['@flamework'].core.out).Flamework
	local InventoryUtil = require(replicatedStorage.TS.inventory['inventory-util']).InventoryUtil
	local Client = require(replicatedStorage.TS.remotes).default.Client
	local OldGet, OldBreak = Client.Get

	bedwars = setmetatable({
		AbilityController = Flamework.resolveDependency('@easy-games/game-core:client/controllers/ability/ability-controller@AbilityController'),
		AnimationUtil = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out.shared.util['animation-util']).AnimationUtil,
		BlockBreaker = Knit.Controllers.BlockBreakController.blockBreaker,
		BlockController = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['block-engine'].out).BlockEngine,
		BlockPlacer = require(replicatedStorage['rbxts_include']['node_modules']['@easy-games']['block-engine'].out.client.placement['block-placer']).BlockPlacer,
		BlockEngine = require(lplr.PlayerScripts.TS.lib['block-engine']['client-block-engine']).ClientBlockEngine,
		ItemMeta = debug.getupvalue(require(replicatedStorage.TS.item['item-meta']).getItemMeta, 1),
		Store = require(lplr.PlayerScripts.TS.ui.store).ClientStore,
		Client = Client,
		Knit = Knit
	}, {
		__index = function(self, ind)
			rawset(self, ind, Knit.Controllers[ind])
			return rawget(self, ind)
		end
	})

	remotes = {}
end)


entitylib.targetCheck = function(ent)
	if ent.TeamCheck then
		return ent:TeamCheck()
	end
	if ent.NPC then return true end
	if isFriend(ent.Player) then return false end
	if not select(2, whitelist:get(ent.Player)) then return false end
	return lplr:GetAttribute('Team') ~= ent.Player:GetAttribute('Team')
end

entitylib.getUpdateConnections = function(ent)
    local hum = ent.Humanoid
    return {
        hum:GetPropertyChangedSignal('Health'),
        hum:GetPropertyChangedSignal('MaxHealth')
    }
end

entitylib.isVulnerable = function(ent)
    return ent.Health > 0 and not ent.Character.FindFirstChildWhichIsA(ent.Character, 'ForceField')
end

entitylib.getEntityColor = function(ent)
    ent = ent.Player
    return ent and tostring(ent.TeamColor) ~= 'White' and ent.TeamColor.Color or nil
end

entitylib.IgnoreObject = RaycastParams.new()
entitylib.IgnoreObject.RespectCanCollide = true
entitylib.Wallcheck = function(origin, position, ignoreobject)
    if typeof(ignoreobject) ~= 'Instance' then
        local ignorelist = {gameCamera, lplr.Character}
        for _, v in entitylib.List do
            if v.Targetable then
                table.insert(ignorelist, v.Character)
            end
        end

        if typeof(ignoreobject) == 'table' then
            for _, v in ignoreobject do
                table.insert(ignorelist, v)
            end
        end

        ignoreobject = entitylib.IgnoreObject
        ignoreobject.FilterDescendantsInstances = ignorelist
    end
    return workspace.Raycast(workspace, origin, (position - origin), ignoreobject)
end

entitylib.EntityMouse = function(entitysettings)
    if entitylib.isAlive then
        local mouseLocation, sortingTable = entitysettings.MouseOrigin or getMousePosition(), {}
        for _, v in entitylib.List do
            if not entitysettings.Players and v.Player then continue end
            if not entitysettings.NPCs and v.NPC then continue end
            if not v.Targetable then continue end
            local position, vis = gameCamera.WorldToViewportPoint(gameCamera, v[entitysettings.Part].Position)
            if not vis then continue end
            local mag = (mouseLocation - Vector2.new(position.x, position.y)).Magnitude
            if mag > entitysettings.Range then continue end
            if entitylib.isVulnerable(v) then
                table.insert(sortingTable, {
                    Entity = v,
                    Magnitude = v.Target and -1 or mag
                })
            end
        end

        table.sort(sortingTable, entitysettings.Sort or function(a, b)
            return a.Magnitude < b.Magnitude
        end)

        for _, v in sortingTable do
            if entitysettings.Wallcheck then
                if entitylib.Wallcheck(entitysettings.Origin, v.Entity[entitysettings.Part].Position, entitysettings.Wallcheck) then continue end
            end
            table.clear(entitysettings)
            table.clear(sortingTable)
            return v.Entity
        end
        table.clear(sortingTable)
    end
    table.clear(entitysettings)
end

entitylib.EntityPosition = function(entitysettings)
    if entitylib.isAlive then
        local localPosition, sortingTable = entitysettings.Origin or entitylib.character.HumanoidRootPart.Position, {}
        for _, v in entitylib.List do
            if not entitysettings.Players and v.Player then continue end
            if not entitysettings.NPCs and v.NPC then continue end
            if not v.Targetable then continue end
            local mag = (v[entitysettings.Part].Position - localPosition).Magnitude
            if mag > entitysettings.Range then continue end
            if entitylib.isVulnerable(v) then
                table.insert(sortingTable, {
                    Entity = v,
                    Magnitude = v.Target and -1 or mag
                })
            end
        end

        table.sort(sortingTable, entitysettings.Sort or function(a, b)
            return a.Magnitude < b.Magnitude
        end)

        for _, v in sortingTable do
            if entitysettings.Wallcheck then
                if entitylib.Wallcheck(localPosition, v.Entity[entitysettings.Part].Position, entitysettings.Wallcheck) then continue end
            end
            table.clear(entitysettings)
            table.clear(sortingTable)
            return v.Entity
        end
        table.clear(sortingTable)
    end
    table.clear(entitysettings)
end

entitylib.AllPosition = function(entitysettings)
    local returned = {}
    if entitylib.isAlive then
        local localPosition, sortingTable = entitysettings.Origin or entitylib.character.HumanoidRootPart.Position, {}
        for _, v in entitylib.List do
            if not entitysettings.Players and v.Player then continue end
            if not entitysettings.NPCs and v.NPC then continue end
            if not v.Targetable then continue end
            local mag = (v[entitysettings.Part].Position - localPosition).Magnitude
            if mag > entitysettings.Range then continue end
            if entitylib.isVulnerable(v) then
                table.insert(sortingTable, {Entity = v, Magnitude = v.Target and -1 or mag})
            end
        end

        table.sort(sortingTable, entitysettings.Sort or function(a, b)
            return a.Magnitude < b.Magnitude
        end)

        for _, v in sortingTable do
            if entitysettings.Wallcheck then
                if entitylib.Wallcheck(localPosition, v.Entity[entitysettings.Part].Position, entitysettings.Wallcheck) then continue end
            end
            table.insert(returned, v.Entity)
            if #returned >= (entitysettings.Limit or math.huge) then break end
        end
        table.clear(sortingTable)
    end
    table.clear(entitysettings)
    return returned
end

entitylib.getEntity = function(char)
    for i, v in entitylib.List do
        if v.Player == char or v.Character == char then
            return v, i
        end
    end
end

entitylib.addEntity = function(char, plr, teamfunc)
    if not char then return end
    entitylib.EntityThreads[char] = task.spawn(function()
        local hum = waitForChildOfType(char, 'Humanoid', 10)
        local humrootpart = hum and waitForChildOfType(hum, 'RootPart', workspace.StreamingEnabled and 9e9 or 10, true)
        local head = char:WaitForChild('Head', 10) or humrootpart

        if hum and humrootpart then
            local entity = {
                Connections = {},
                Character = char,
                Health = hum.Health,
                Head = head,
                Humanoid = hum,
                HumanoidRootPart = humrootpart,
                HipHeight = hum.HipHeight + (humrootpart.Size.Y / 2) + (hum.RigType == Enum.HumanoidRigType.R6 and 2 or 0),
                MaxHealth = hum.MaxHealth,
                NPC = plr == nil,
                Player = plr,
                RootPart = humrootpart,
                TeamCheck = teamfunc
            }
            if HitBoxes.Enabled then
                task.spawn(function()
                    local root = char:FindFirstChild("HumanoidRootPart")
                    if root then
                        root.Size = Vector3.new(60, 60, 60)
                        root.Transparency = 0.8
                        root.Material = Enum.Material.ForceField
                    end
                end)
            end


            if plr == lplr then
                entitylib.character = entity
                entitylib.isAlive = true
                entitylib.Events.LocalAdded:Fire(entity)
            else
                entity.Targetable = entitylib.targetCheck(entity)

                for _, v in entitylib.getUpdateConnections(entity) do
                    table.insert(entity.Connections, v:Connect(function()
                        entity.Health = hum.Health
                        entity.MaxHealth = hum.MaxHealth
                        entitylib.Events.EntityUpdated:Fire(entity)
                    end))
                end

                table.insert(entitylib.List, entity)
                entitylib.Events.EntityAdded:Fire(entity)
            end
        end
        entitylib.EntityThreads[char] = nil
    end)
end

entitylib.removeEntity = function(char, localcheck)
    if localcheck then
        if entitylib.isAlive then
            entitylib.isAlive = false
            for _, v in entitylib.character.Connections do
                v:Disconnect()
            end
            table.clear(entitylib.character.Connections)
            entitylib.Events.LocalRemoved:Fire(entitylib.character)
        end
        return
    end

    if char then
        if entitylib.EntityThreads[char] then
            task.cancel(entitylib.EntityThreads[char])
            entitylib.EntityThreads[char] = nil
        end

        local entity, ind = entitylib.getEntity(char)
        if ind then
            for _, v in entity.Connections do
                v:Disconnect()
            end
            table.clear(entity.Connections)
            table.remove(entitylib.List, ind)
            entitylib.Events.EntityRemoved:Fire(entity)
        end
    end
end

entitylib.refreshEntity = function(char, plr)
    entitylib.removeEntity(char)
    entitylib.addEntity(char, plr)
end

entitylib.addPlayer = function(plr)
    if plr.Character then
        entitylib.refreshEntity(plr.Character, plr)
    end
    entitylib.PlayerConnections[plr] = {
        plr.CharacterAdded:Connect(function(char)
            entitylib.refreshEntity(char, plr)
        end),
        plr.CharacterRemoving:Connect(function(char)
            entitylib.removeEntity(char, plr == lplr)
        end),
        plr:GetPropertyChangedSignal('Team'):Connect(function()
            for _, v in entitylib.List do
                if v.Targetable ~= entitylib.targetCheck(v) then
                    entitylib.refreshEntity(v.Character, v.Player)
                end
            end

            if plr == lplr then
                entitylib.start()
            else
                entitylib.refreshEntity(plr.Character, plr)
            end
        end)
    }
end

entitylib.removePlayer = function(plr)
    if entitylib.PlayerConnections[plr] then
        for _, v in entitylib.PlayerConnections[plr] do
            v:Disconnect()
        end
        table.clear(entitylib.PlayerConnections[plr])
        entitylib.PlayerConnections[plr] = nil
    end
    entitylib.removeEntity(plr)
end

entitylib.start = function()
    if entitylib.Running then
        entitylib.stop()
    end
    table.insert(entitylib.Connections, playersService.PlayerAdded:Connect(function(v)
        entitylib.addPlayer(v)
    end))
    table.insert(entitylib.Connections, playersService.PlayerRemoving:Connect(function(v)
        entitylib.removePlayer(v)
    end))
    for _, v in playersService:GetPlayers() do
        entitylib.addPlayer(v)
    end
    table.insert(entitylib.Connections, workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(function()
        gameCamera = workspace.CurrentCamera or workspace:FindFirstChildWhichIsA('Camera')
    end))
    entitylib.Running = true
end

entitylib.stop = function()
    for _, v in entitylib.Connections do
        v:Disconnect()
    end
    for _, v in entitylib.PlayerConnections do
        for _, v2 in v do
            v2:Disconnect()
        end
        table.clear(v)
    end
    entitylib.removeEntity(nil, true)
    local cloned = table.clone(entitylib.List)
    for _, v in cloned do
        entitylib.removeEntity(v.Character)
    end
    for _, v in entitylib.EntityThreads do
        task.cancel(v)
    end
    table.clear(entitylib.PlayerConnections)
    table.clear(entitylib.EntityThreads)
    table.clear(entitylib.Connections)
    table.clear(cloned)
    entitylib.Running = false
end

entitylib.kill = function()
    if entitylib.Running then
        entitylib.stop()
    end
    for _, v in entitylib.Events do
        v:Destroy()
    end
    entitylib.IgnoreObject:Destroy()
    loopClean(entitylib)
end

entitylib.refresh = function()
    local cloned = table.clone(entitylib.List)
    for _, v in cloned do
        entitylib.refreshEntity(v.Character, v.Player)
    end
    table.clear(cloned)
end

local mainPlayersService = cloneref(game:GetService('Players'))
local mainReplicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local mainRunService = cloneref(game:GetService('RunService'))
local mainInputService = cloneref(game:GetService('UserInputService'))
local mainTweenService = cloneref(game:GetService('TweenService'))

repeat task.wait() until game:IsLoaded()

-- Settings (yo can change these values)
local Settings = {
    ToggleKeybind = "RightShift",
    HitBoxesMode = "Player", -- "Sword" or "Player"
    HitBoxesExpandAmount = 25, 
    HitFixEnabled = true,
    InstantPPEnabled = true,
    AutoChargeBowEnabled = true,
    AutoTool = true,
}

pcall(function()
    if mainPlayersService.LocalPlayer.PlayerGui:FindFirstChild("VapeNotifications") then
        mainPlayersService.LocalPlayer.PlayerGui:FindFirstChild("VapeNotifications"):Destroy()
    end
end)

for _, v in pairs(game:GetService("CoreGui"):GetDescendants()) do
	if v:IsA("Frame") and v.Name:find("esp_item_") then
		v:Destroy()
	end
end

local NotificationGui = Instance.new("ScreenGui")
NotificationGui.ResetOnSpawn = false
NotificationGui.Name = "VapeNotifications"

task.spawn(function()
	repeat task.wait() until mainPlayersService.LocalPlayer:FindFirstChild("PlayerGui")
	NotificationGui.Parent = mainPlayersService.LocalPlayer:WaitForChild("PlayerGui")
end)


addCleanupFunction(function()
    if NotificationGui and NotificationGui.Parent then
        NotificationGui:Destroy()
    end
end)

local function showNotification(message, duration)
	duration = duration or 2

	local parentGui = mainPlayersService.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("VapeNotifications")

	local notification = Instance.new("Frame")
	notification.Size = UDim2.new(0, 380, 0, 70)
	notification.Position = UDim2.new(0.5, -190, 0, -70)
	notification.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	notification.BorderSizePixel = 0
	notification.AnchorPoint = Vector2.new(0.5, 0)
	notification.BackgroundTransparency = 0.2

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = notification

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(80, 80, 80)
	stroke.Thickness = 1
	stroke.Parent = notification

	local icon = Instance.new("ImageLabel")
	icon.Size = UDim2.new(0, 24, 0, 24)
	icon.Position = UDim2.new(0, 10, 0.5, -12)
	icon.BackgroundTransparency = 1
	icon.Image = "rbxassetid://6031265976"
	icon.Parent = notification

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, -50, 1, 0)
	textLabel.Position = UDim2.new(0, 45, 0, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.TextColor3 = Color3.new(1, 1, 1)
	textLabel.Font = Enum.Font.GothamSemibold
	textLabel.TextSize = 16
	textLabel.Text = message
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.TextWrapped = true
	textLabel.Parent = notification

	notification.Parent = parentGui

	notification:TweenPosition(
		UDim2.new(0.5, -190, 0, 30),
		"Out",
		"Quad",
		0.3,
		true
	)

	task.wait(duration)

	notification:TweenPosition(
		UDim2.new(0.5, -190, 0, -70),
		"In",
		"Quad",
		0.3,
		true
	)

	task.wait(0.3)
	notification:Destroy()
end


local function waitForBedwars()
    local attempts = 0
    local maxAttempts = 100
    
    while attempts < maxAttempts do
        attempts = attempts + 1
        
        local success, knit = pcall(function()
            return debug.getupvalue(require(lplr.PlayerScripts.TS.knit).setup, 9)
        end)
        
        if success and knit then
            local startAttempts = 0
            while not debug.getupvalue(knit.Start, 1) and startAttempts < 50 do
                startAttempts = startAttempts + 1
                task.wait(0.1)
            end
            
            if debug.getupvalue(knit.Start, 1) then
                print("✅ BEDWARS LOADED AFTER " .. attempts .. " ATTEMPTS")
                return knit
            end
        end
        
        task.wait(0.1)
    end
    
    print("❌ BEDWARS FAILED TO LOAD")
    return nil
end

local knit = waitForBedwars()
local bedwars = {}

local function updateHotbar()
    if bedwars.Store then
        local state = bedwars.Store:getState()
        if state and state.inventory then
            store.inventory.hotbar = state.inventory.hotbar or {}
            store.inventory.hotbarSlot = state.inventory.observedInventory and state.inventory.observedInventory.hotbarSlot or 0
        end
    end
end

local function connectInventoryEvents()
    if bedwars.Store then
        bedwars.Store.changed:connect(function(state)
            if state.inventory then
                store.inventory = state.inventory
                updateHotbar()
            end
        end)
    end
end

local function setupBedwars()
    if not knit then return false end
    
    local success = pcall(function()
        bedwars.Client = require(mainReplicatedStorage.TS.remotes).default.Client
        
        bedwars.SwordController = knit.Controllers.SwordController
        
        bedwars.SprintController = knit.Controllers.SprintController
        
        bedwars.ProjectileController = knit.Controllers.ProjectileController
        
        bedwars.BowConstantsTable = debug.getupvalue(knit.Controllers.ProjectileController.enableBeam, 8)
        
        local queryUtilSuccess, queryUtil = pcall(function()
            return require(mainReplicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out).GameQueryUtil
        end)
        if queryUtilSuccess then
            bedwars.QueryUtil = queryUtil
        end
        
        print("BEDWARS COMPONENTS LOADED")
        return true
    end)
    
    if not success then
        print("FAILED TO SETUP BEDWARS COMPONENTS")
    end
    
    return success
end


if bedwarsLoaded and bedwars.BlockBreaker then
    local oldHitBlock = bedwars.BlockBreaker.hitBlock
    bedwars.BlockBreaker.hitBlock = function(self, ...)
        local args = {...}
        
        local block = nil
        if args[3] and args[3].direction then
            local raycastResult = workspace:Raycast(args[3].origin, args[3].direction)
            if raycastResult and raycastResult.Instance then
                block = raycastResult.Instance
            end
        end
        
        if block and Settings.AutoTool then
            local meta = bedwars.ItemMeta[block.Name]
            if meta and meta.block and meta.block.breakType then
                local breaktype = meta.block.breakType
                local tool, slot = getTool(breaktype)
                if tool and slot then
                    switchItem(tool) 
                else
                end
            else
            end
        end
        
        return oldHitBlock(self, ...)
    end
end

local bedwarsLoaded = setupBedwars()
local AutoChargeBowEnabled = Settings.AutoChargeBowEnabled
local oldCalculateImportantLaunchValues = nil

if bedwarsLoaded then
    connectInventoryEvents()
    updateHotbar()
end

if bedwarsLoaded and bedwars.Store then
    local state = bedwars.Store:getState()
    if state and state.inventory then
        store.inventory.inventory.items = state.inventory.items or {}
        store.inventory.hotbar = state.inventory.hotbar or {}
        store.inventory.hotbarSlot = state.inventory.observedInventory and state.inventory.observedInventory.hotbarSlot or 0
    end
end

local collectionService = game:GetService("CollectionService")
local debris = game:GetService("Debris")
local Icons = {
    ["iron"] = "rbxassetid://6850537969",
    ["bee"] = "rbxassetid://7343272839",
    ["natures_essence_1"] = "rbxassetid://11003449842",
    ["thorns"] = "rbxassetid://9134549615",
    ["mushrooms"] = "rbxassetid://9134534696",
    ["wild_flower"] = "rbxassetid://9134545166",
    ["crit_star"] = "rbxassetid://9866757805",
    ["vitality_star"] = "rbxassetid://9866757969"
}
local espobjs = {}
pcall(function()
    for _, child in pairs(mainPlayersService.LocalPlayer.PlayerGui:GetChildren()) do
        if child:FindFirstChild("esp_item_") then
            child:Destroy()
        end
    end
end)

local espfold = Instance.new("Folder")
local gui = Instance.new("ScreenGui", mainPlayersService.LocalPlayer.PlayerGui)
gui.ResetOnSpawn = false
gui.Name = "VapeESPGui"
espfold.Parent = gui

addCleanupFunction(function()
    if gui and gui.Parent then
        gui:Destroy()
    end
    resetESP()
end)

local function espadd(v, icon)
    local billboard = Instance.new("BillboardGui")
    billboard.Parent = espfold
    billboard.Name = "esp_item_" .. icon
    billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 1.5)
    billboard.Size = UDim2.new(0, 32, 0, 32)
    billboard.AlwaysOnTop = true
    billboard.Adornee = v
    local image = Instance.new("ImageLabel")
    image.BackgroundTransparency = 0.5
    image.BorderSizePixel = 0
    image.Image = Icons[icon] or ""
    image.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    image.Size = UDim2.new(0, 32, 0, 32)
    image.AnchorPoint = Vector2.new(0.5, 0.5)
    image.Parent = billboard
    local uicorner = Instance.new("UICorner")
    uicorner.CornerRadius = UDim.new(0, 4)
    uicorner.Parent = image
    espobjs[v] = billboard
end

local espConnections = {}

local function resetESP()
    for _, v in pairs(espConnections) do
        pcall(function() v:Disconnect() end)
    end
    espfold:ClearAllChildren()
    table.clear(espobjs)
    espConnections = {}
end

local function addKit(tag, icon, custom)
    if not custom then
        local con1 = collectionService:GetInstanceAddedSignal(tag):Connect(function(v)
            if v and v.PrimaryPart then
                espadd(v.PrimaryPart, icon)
            end
        end)
        local con2 = collectionService:GetInstanceRemovedSignal(tag):Connect(function(v)
            if v and v.PrimaryPart and espobjs[v.PrimaryPart] then
                espobjs[v.PrimaryPart]:Destroy()
                espobjs[v.PrimaryPart] = nil
            end
        end)
        table.insert(espConnections, con1)
        table.insert(espConnections, con2)
        for _, v in pairs(collectionService:GetTagged(tag)) do
            if v and v.PrimaryPart then
                espadd(v.PrimaryPart, icon)
            end
        end
    else
        local function check(v)
            if v and v.Name == tag and v.ClassName == "Model" and v.PrimaryPart then
                espadd(v.PrimaryPart, icon)
            end
        end
        local con3 = game.Workspace.ChildAdded:Connect(check)
        local con4 = game.Workspace.ChildRemoved:Connect(function(v)
            pcall(function()
                if v and v.PrimaryPart and espobjs[v.PrimaryPart] then
                    espobjs[v.PrimaryPart]:Destroy()
                    espobjs[v.PrimaryPart] = nil
                end
            end)
        end)
        table.insert(espConnections, con3)
        table.insert(espConnections, con4)
        for _, v in pairs(game.Workspace:GetChildren()) do
            check(v)
        end
    end
end

local function recreateESP()
    resetESP()
    addKit("hidden-metal", "iron")
    addKit("bee", "bee")
    addKit("treeOrb", "natures_essence_1")
    addKit("Thorns", "thorns", true)
    addKit("Mushrooms", "mushrooms", true)
    addKit("Flower", "wild_flower", true)
    addKit("CritStar", "crit_star", true)
    addKit("VitalityStar", "vitality_star", true)
end

local ProximityPromptService = cloneref(game:GetService('ProximityPromptService'))
local InstantPPConnection = nil
local InstantPPActive = false

local function enableInstantPP()
    if InstantPPActive or not Settings.InstantPPEnabled then return end
    if fireproximityprompt then
        InstantPPConnection = ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
            fireproximityprompt(prompt)
        end)
        InstantPPActive = true
    end
end

local function disableInstantPP()
    if not InstantPPActive then return end
    if InstantPPConnection then
        InstantPPConnection:Disconnect()
        InstantPPConnection = nil
    end
    InstantPPActive = false
end

local HitFixEnabled = Settings.HitFixEnabled
local attackConnections = {}
local hitfixOriginalState = nil
local swordController = bedwars and bedwars.SwordController
local queryUtil = bedwars and bedwars.QueryUtil or workspace

local originalFunctions = {}

local function setupHitFix()
	if not bedwarsLoaded or not swordController then return false end

	local function applyFunctionHook(enabled)
		if enabled then
			local functions = {"swingSwordAtMouse", "swingSwordInRegion", "attackEntity"}
			for _, funcName in functions do
				local original = swordController[funcName]
				if original and not originalFunctions[funcName] then
					originalFunctions[funcName] = original
					swordController[funcName] = function(self, ...)
						local args = {...}
						for i, arg in pairs(args) do
							if type(arg) == "table" and arg.validate then
								args[i].validate = nil
							end
						end
						return original(self, unpack(args))
					end
				end
			end
		else
			for funcName, original in pairs(originalFunctions) do
				swordController[funcName] = original
			end
			originalFunctions = {}
		end
	end

	local function applyDebugPatch(enabled)
		local success = pcall(function()
			if swordController.swingSwordAtMouse then
				debug.setconstant(swordController.swingSwordAtMouse, 23, enabled and 'raycast' or 'Raycast')
				debug.setupvalue(swordController.swingSwordAtMouse, 4, enabled and queryUtil or workspace)
			end
		end)
		return success
	end

	if hitfixOriginalState == nil then
		hitfixOriginalState = false
	end

	local hookSuccess = pcall(function() applyFunctionHook(HitFixEnabled) end)
	local debugSuccess = applyDebugPatch(HitFixEnabled)

	return hookSuccess and debugSuccess
end

local function enableHitFix()
    if not bedwarsLoaded then return false end
    HitFixEnabled = true
    return setupHitFix()
end

local function disableHitFix()
    if not bedwarsLoaded then return false end
    HitFixEnabled = false
    return setupHitFix()
end

local function enableAutoChargeBow()
    if not bedwarsLoaded or not bedwars.ProjectileController then return false end
    
    local success = pcall(function()
        if not oldCalculateImportantLaunchValues then
            oldCalculateImportantLaunchValues = bedwars.ProjectileController.calculateImportantLaunchValues
        end
        
        bedwars.ProjectileController.calculateImportantLaunchValues = function(...)
            local self, projmeta, worldmeta, origin, shootpos = ...
            
            if projmeta.projectile:find('arrow') then
                local pos = shootpos or self:getLaunchPosition(origin)
                if not pos then
                    return oldCalculateImportantLaunchValues(...)
                end
                
                local meta = projmeta:getProjectileMeta()
                local lifetime = (worldmeta and meta.predictionLifetimeSec or meta.lifetimeSec or 3)
                local gravity = (meta.gravitationalAcceleration or 196.2) * projmeta.gravityMultiplier
                local projSpeed = (meta.launchVelocity or 100)
                local offsetpos = pos + (projmeta.projectile == 'owl_projectile' and Vector3.zero or projmeta.fromPositionOffset)
                
                local camera = workspace.CurrentCamera
                local mouse = lplr:GetMouse()
                local unitRay = camera:ScreenPointToRay(mouse.X, mouse.Y)
                
                local targetPoint = unitRay.Origin + (unitRay.Direction * 1000)
                local aimDirection = (targetPoint - offsetpos).Unit
                
                local newlook = CFrame.new(offsetpos, targetPoint) * CFrame.new(projmeta.projectile == 'owl_projectile' and Vector3.zero or Vector3.new(bedwars.BowConstantsTable.RelX, bedwars.BowConstantsTable.RelY, bedwars.BowConstantsTable.RelZ))
                local finalDirection = (targetPoint - newlook.Position).Unit
                
                return {
                    initialVelocity = finalDirection * projSpeed,
                    positionFrom = offsetpos,
                    deltaT = lifetime,
                    gravitationalAcceleration = gravity,
                    drawDurationSeconds = 5
                }
            end
            
            return oldCalculateImportantLaunchValues(...)
        end
        
        AutoChargeBowEnabled = true
    end)
    
    return success
end

local function disableAutoChargeBow()
    if not bedwarsLoaded or not bedwars.ProjectileController or not oldCalculateImportantLaunchValues then return false end
    
    local success = pcall(function()
        bedwars.ProjectileController.calculateImportantLaunchValues = oldCalculateImportantLaunchValues
        AutoChargeBowEnabled = false
    end)
    
    return success
end

local hitboxParts = {}
local swordHitboxEnabled = false
local hitboxConnections = {}

local function setupHitBoxes()
    if not bedwarsLoaded or not bedwars.SwordController then
        return false
    end
    
    local function applySwordHitBox(enabled)
        if not bedwars.SwordController.swingSwordInRegion then
            return false
        end
        
        local success = pcall(function()
            if enabled then
                debug.setconstant(bedwars.SwordController.swingSwordInRegion, 6, Settings.HitBoxesExpandAmount)
                swordHitboxEnabled = true
            else
                debug.setconstant(bedwars.SwordController.swingSwordInRegion, 6, 3.8)
                swordHitboxEnabled = false
            end
        end)
        return success
    end
    
    local function createPlayerHitBox(player)
        if player == lplr or not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
            return
        end
        
        local success = pcall(function()
            local char = player.Character
            local hrp = char.HumanoidRootPart
            
            if hitboxParts[player] then
                hitboxParts[player]:Destroy()
            end
            
            local hitbox = Instance.new("Part")
            hitbox.Name = "CustomHitBox"
            hitbox.Size = Vector3.new(Settings.HitBoxesExpandAmount, Settings.HitBoxesExpandAmount, Settings.HitBoxesExpandAmount)
            hitbox.Position = hrp.Position
            hitbox.CanCollide = false
            hitbox.Massless = true
            hitbox.Transparency = 1 
            hitbox.Parent = char
            
            local weld = Instance.new("WeldConstraint")
            weld.Part0 = hitbox
            weld.Part1 = hrp
            weld.Parent = hitbox
            
            hitboxParts[player] = hitbox
        end)
        
        return success
    end
    
    local function clearPlayerHitBoxes()
        for player, part in pairs(hitboxParts) do
            if part and part.Parent then
                part:Destroy()
            end
        end
        hitboxParts = {}
    end
    
    local function applyPlayerHitBoxes(enabled)
        if enabled then
            for _, player in pairs(playersService:GetPlayers()) do
                if player ~= lplr then
                    createPlayerHitBox(player)
                end
            end
            
            local newPlayerConnection = playersService.PlayerAdded:Connect(function(player)
                if player ~= lplr then
                    player.CharacterAdded:Connect(function()
                        task.wait(1) 
                        createPlayerHitBox(player)
                    end)
                end
            end)
            table.insert(hitboxConnections, newPlayerConnection)
            
            for _, player in pairs(playersService:GetPlayers()) do
                if player ~= lplr then
                    local charConnection = player.CharacterAdded:Connect(function()
                        task.wait(1)
                        createPlayerHitBox(player)
                    end)
                    table.insert(hitboxConnections, charConnection)
                end
            end
        else
            clearPlayerHitBoxes()
        end
    end
    
    return {
        applySwordHitBox = applySwordHitBox,
        applyPlayerHitBoxes = applyPlayerHitBoxes,
        clearPlayerHitBoxes = clearPlayerHitBoxes
    }
end

local hitboxSystem = setupHitBoxes()
local HitBoxesEnabled = false

local function enableHitboxes()
    if not entitylib.Running then
        entitylib.start()
    end
    
    if not hitboxSystem then
        return false
    end

    if Settings.HitBoxesMode == 'Sword' then
        local success = hitboxSystem.applySwordHitBox(true)
        if success then
            HitBoxesEnabled = true
            return true
        end
    else 
        hitboxSystem.applyPlayerHitBoxes(true)
        HitBoxesEnabled = true
        return true
    end
    
    return false
end

local function disableHitboxes()
    if not hitboxSystem then
        return false
    end
    
    if Settings.HitBoxesMode == 'Sword' then
        hitboxSystem.applySwordHitBox(false)
    else
        hitboxSystem.applyPlayerHitBoxes(false)
    end
    
    for _, v in pairs(hitboxConnections) do
        pcall(function() v:Disconnect() end)
    end
    hitboxConnections = {}
    
    HitBoxesEnabled = false
    return true
end

local SprintEnabled = false
local old = nil
local sprintConnection = nil

local function enableSprint()
    if SprintEnabled or not bedwarsLoaded or not bedwars.SprintController then return end
    
    if inputService.TouchEnabled then 
        pcall(function() 
            lplr.PlayerGui.MobileUI['4'].Visible = false 
        end) 
    end
    
    old = bedwars.SprintController.stopSprinting
    bedwars.SprintController.stopSprinting = function(...)
        local call = old(...)
        bedwars.SprintController:startSprinting()
        return call
    end
    
    sprintConnection = entitylib.Events.LocalAdded:Connect(function() 
        task.delay(0.1, function() 
            if bedwars.SprintController then
                bedwars.SprintController:stopSprinting() 
            end
        end) 
    end)
    
    bedwars.SprintController:stopSprinting()
    SprintEnabled = true
end

local function disableSprint()
    if not SprintEnabled or not bedwarsLoaded or not bedwars.SprintController then return end
    
    if inputService.TouchEnabled then 
        pcall(function() 
            lplr.PlayerGui.MobileUI['4'].Visible = true 
        end) 
    end
    
    if old then
        bedwars.SprintController.stopSprinting = old
        bedwars.SprintController:stopSprinting()
        old = nil
    end
    
    if sprintConnection then
        sprintConnection:Disconnect()
        sprintConnection = nil
    end
    
    SprintEnabled = false
end

local UserInputService = game:GetService("UserInputService")
local allFeaturesEnabled = true

local function enableAllFeatures()
    recreateESP()
    if Settings.InstantPPEnabled then
        enableInstantPP()
    end
    enableHitboxes()
    enableSprint()
    if Settings.HitFixEnabled then
        enableHitFix()
    end
    if Settings.AutoChargeBowEnabled then
        enableAutoChargeBow()
    end
    allFeaturesEnabled = true
end

local function disableAllFeatures()
    resetESP()
    disableInstantPP()
    disableHitboxes()
    disableSprint()
    disableHitFix()
    disableAutoChargeBow()
    allFeaturesEnabled = false
    task.spawn(function()
        showNotification("Script disabled. Press RightShift to re-enable.", 3)
    end)
end

if mainPlayersService.LocalPlayer.PlayerGui:FindFirstChild("VapeNotifications") then
	mainPlayersService.LocalPlayer.PlayerGui:FindFirstChild("VapeNotifications"):Destroy()
end

for _, v in pairs(game:GetService("CoreGui"):GetDescendants()) do
	if v:IsA("Frame") and v.Name:find("esp_item_") then
		v:Destroy()
	end
end


local mainInputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if input.KeyCode == Enum.KeyCode[Settings.ToggleKeybind] then
        if allFeaturesEnabled then
            disableAllFeatures()
        else
            enableAllFeatures()
            task.spawn(function()
                showNotification("Script enabled. Press RightShift to disable.", 3)
            end)
        end
    end
end)

addCleanupFunction(function()
    if mainInputConnection then
        mainInputConnection:Disconnect()
    end
end)

entitylib.start()

addCleanupFunction(function()
    entitylib.kill()
end)

if bedwarsLoaded then
    setupHitFix()
end

enableAllFeatures()
task.spawn(function()
    local statusMsg = "Script loaded and enabled. Press RightShift to toggle on/off."
    if bedwarsLoaded then
        statusMsg = statusMsg .. " HitFix: " .. (Settings.HitFixEnabled and "ON" or "OFF") .. ", HitBoxes: " .. Settings.HitBoxesMode
    end
    showNotification(statusMsg, 4)
end)

addCleanupFunction(function()
    disableAllFeatures()
    pcall(function()
        if originalFunctions then
            for funcName, original in pairs(originalFunctions) do
                if swordController and swordController[funcName] then
                    swordController[funcName] = original
                end
            end
        end
        if oldCalculateImportantLaunchValues and bedwars.ProjectileController then
            bedwars.ProjectileController.calculateImportantLaunchValues = oldCalculateImportantLaunchValues
        end
    end)
end)
