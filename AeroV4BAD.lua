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

local playersService = cloneref(game:GetService('Players'))
local inputService = cloneref(game:GetService('UserInputService'))
local lplr = playersService.LocalPlayer
local gameCamera = workspace.CurrentCamera

local function getMousePosition()
	if inputService.TouchEnabled then
		return gameCamera.ViewportSize / 2
	end
	return inputService.GetMouseLocation(inputService)
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

entitylib.targetCheck = function(ent)
	if ent.TeamCheck then
		return ent:TeamCheck()
	end
	if ent.NPC then return true end
	if not lplr.Team then return true end
	if not ent.Player.Team then return true end
	if ent.Player.Team ~= lplr.Team then return true end
	return #ent.Player.Team:GetPlayers() == #playersService:GetPlayers()
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
    HitBoxesMode = "Sword", -- "Sword" or "Player"
    HitBoxesExpandAmount = 30, 
    HitFixEnabled = true,
    InstantPPEnabled = true,
    AutoChargeBowEnabled = false,
    AutoToolEnabled = true,
}

pcall(function()
    if mainPlayersService.LocalPlayer.PlayerGui:FindFirstChild("VapeNotifications") then
        mainPlayersService.LocalPlayer.PlayerGui:FindFirstChild("VapeNotifications"):Destroy()
    end
end)

local NotificationGui = Instance.new("ScreenGui", mainPlayersService.LocalPlayer.PlayerGui)
NotificationGui.ResetOnSpawn = false
NotificationGui.Name = "VapeNotifications"

local currentNotification = nil

addCleanupFunction(function()
    if NotificationGui and NotificationGui.Parent then
        NotificationGui:Destroy()
    end
    currentNotification = nil
end)

local function showNotification(message, duration)
    duration = duration or 3
    
    if currentNotification and currentNotification.Parent then
        currentNotification:Destroy()
        currentNotification = nil
    end
    
    local notification = Instance.new("Frame")
    notification.Size = UDim2.new(0, 380, 0, 70)
    notification.Position = UDim2.new(0.5, -190, 0, 25)
    notification.BackgroundColor3 = Color3.fromRGB(20, 22, 25)
    notification.BorderSizePixel = 0
    notification.AnchorPoint = Vector2.new(0.5, 0)
    notification.Parent = NotificationGui
    
    currentNotification = notification

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = notification

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(70, 130, 255)
    stroke.Thickness = 2
    stroke.Parent = notification
    
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(25, 27, 30)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(15, 17, 20))
    }
    gradient.Rotation = 45
    gradient.Parent = notification

    local shadow = Instance.new("Frame")
    shadow.Size = UDim2.new(1, 10, 1, 10)
    shadow.Position = UDim2.new(0, -5, 0, -5)
    shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    shadow.BackgroundTransparency = 0.3
    shadow.ZIndex = notification.ZIndex - 1
    shadow.Parent = notification
    
    local shadowCorner = Instance.new("UICorner")
    shadowCorner.CornerRadius = UDim.new(0, 12)
    shadowCorner.Parent = shadow

    local iconFrame = Instance.new("Frame")
    iconFrame.Size = UDim2.new(0, 50, 1, -10)
    iconFrame.Position = UDim2.new(0, 5, 0, 5)
    iconFrame.BackgroundColor3 = Color3.fromRGB(70, 130, 255)
    iconFrame.BackgroundTransparency = 0.1
    iconFrame.Parent = notification
    
    local iconCorner = Instance.new("UICorner")
    iconCorner.CornerRadius = UDim.new(0, 8)
    iconCorner.Parent = iconFrame
    
    local iconLabel = Instance.new("TextLabel")
    iconLabel.Size = UDim2.new(1, 0, 1, 0)
    iconLabel.BackgroundTransparency = 1
    iconLabel.Text = "✓"
    iconLabel.TextColor3 = Color3.new(1, 1, 1)
    iconLabel.Font = Enum.Font.GothamBold
    iconLabel.TextSize = 24
    iconLabel.Parent = iconFrame

    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, -70, 1, -10)
    textLabel.Position = UDim2.new(0, 60, 0, 5)
    textLabel.BackgroundTransparency = 1
    textLabel.TextColor3 = Color3.new(1, 1, 1)
    textLabel.Font = Enum.Font.GothamSemibold
    textLabel.TextSize = 14
    textLabel.Text = message
    textLabel.TextXAlignment = Enum.TextXAlignment.Left
    textLabel.TextYAlignment = Enum.TextYAlignment.Center
    textLabel.TextWrapped = true
    textLabel.Parent = notification

    notification.Position = UDim2.new(0.5, -190, 0, -80)
    local tweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    local tween = mainTweenService:Create(notification, tweenInfo, {Position = UDim2.new(0.5, -190, 0, 25)})
    tween:Play()
    
    task.spawn(function()
        task.wait(duration)
        
        if currentNotification == notification then
            local outTweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            local outTween = mainTweenService:Create(notification, outTweenInfo, {Position = UDim2.new(0.5, -190, 0, -80)})
            outTween:Play()
            
            outTween.Completed:Wait()
            
            if notification and notification.Parent then
                notification:Destroy()
            end
            
            if currentNotification == notification then
                currentNotification = nil
            end
        end
    end)
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
local remotes = {}
local store = {
    attackReach = 0,
    attackReachUpdate = tick(),
    inventory = {
        inventory = {
            items = {},
            armor = {}
        },
        hotbar = {}
    },
    tools = {}
}

local function getItem(itemName, inv)
    for slot, item in (inv or store.inventory.inventory.items) do
        if item.itemType == itemName then
            return item, slot
        end
    end
    return nil
end

local function getSword()
    local bestSword, bestSwordSlot, bestSwordDamage = nil, nil, 0
    for slot, item in store.inventory.inventory.items do
        local swordMeta = bedwars.ItemMeta[item.itemType].sword
        if swordMeta then
            local swordDamage = swordMeta.damage or 0
            if swordDamage > bestSwordDamage then
                bestSword, bestSwordSlot, bestSwordDamage = item, slot, swordDamage
            end
        end
    end
    return bestSword, bestSwordSlot
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

local function setupBedwars()
    if not knit then return false end
    
    local success = pcall(function()
        bedwars.Client = require(mainReplicatedStorage.TS.remotes).default.Client
        
        bedwars.SwordController = knit.Controllers.SwordController
        
        bedwars.SprintController = knit.Controllers.SprintController
        
        bedwars.ProjectileController = knit.Controllers.ProjectileController

        bedwars.QueryUtil = require(mainReplicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out).GameQueryUtil or workspace
        
        bedwars.BowConstantsTable = debug.getupvalue(knit.Controllers.ProjectileController.enableBeam, 8)
        
        bedwars.ItemMeta = debug.getupvalue(require(mainReplicatedStorage.TS.item['item-meta']).getItemMeta, 1)
        
        bedwars.Store = require(lplr.PlayerScripts.TS.ui.store).ClientStore
        
        bedwars.BlockBreaker = knit.Controllers.BlockBreakController.blockBreaker
        
        pcall(function()
            bedwars.QueryUtil = require(mainReplicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out).GameQueryUtil
        end)
        
        local combatConstantSuccess = pcall(function()
            bedwars.CombatConstant = require(mainReplicatedStorage.TS.combat['combat-constant']).CombatConstant
        end)
        
        if combatConstantSuccess and bedwars.Client then
            pcall(function()
                local remoteNames = {
                    AttackEntity = bedwars.SwordController.sendServerRequest
                }
                
                local function dumpRemote(tab)
                    local ind
                    for i, v in tab do
                        if v == 'Client' then
                            ind = i
                            break
                        end
                    end
                    return ind and tab[ind + 1] or ''
                end
                
                remotes = remotes or {}
                for i, v in remoteNames do
                    local remote = dumpRemote(debug.getconstants(v))
                    if remote ~= '' then
                        remotes[i] = remote
                        print(" DEBUG - Remote found:", i, "->", remote)
                    else
                        print("DEBUG - Failed to find remote:", i)
                    end
                end
            end)
        end

        if combatConstantSuccess and bedwars.Client then
            pcall(function()
                bedwars.AttackEntityRemote = bedwars.Client:Get("AttackEntity")
            end)
        end
        
        print(" DEBUG - CombatConstant loaded:", combatConstantSuccess)
        if combatConstantSuccess then
            print(" DEBUG - Original reach distance:", bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE)
        end
        
        print("BEDWARS COMPONENTS LOADED - CombatConstant:", combatConstantSuccess and "SUCCESS" or "FAILED")

        pcall(function()
            local function updateStore(new, old)
                if new.Inventory ~= old.Inventory then
                    local newinv = (new.Inventory and new.Inventory.observedInventory or {inventory = {}})
                    local oldinv = (old.Inventory and old.Inventory.observedInventory or {inventory = {}})
                    store.inventory = newinv

                    if newinv ~= oldinv then
                        vapeEvents.InventoryChanged:Fire()
                    end

                    if newinv.inventory.items ~= oldinv.inventory.items then
                        vapeEvents.InventoryAmountChanged:Fire()
                        store.tools.sword = getSword()
                        for _, v in {'stone', 'wood', 'wool'} do
                            store.tools[v] = getTool(v)
                        end
                    end
                end
            end

            local storeChanged = bedwars.Store.changed:connect(updateStore)
            updateStore(bedwars.Store:getState(), {})
            
            addCleanupFunction(function()
                if storeChanged then
                    storeChanged:disconnect()
                end
            end)
        end)
        return true
    end)
    
    if not success then
        print("FAILED TO SETUP BEDWARS COMPONENTS")
    end
    
    return success
end

local bedwarsLoaded = setupBedwars()
local AutoChargeBowEnabled = Settings.AutoChargeBowEnabled
local oldCalculateImportantLaunchValues = nil

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
local queryUtil = nil

local originalFunctions = {}
local OldGet = nil

local function hookClientGet()
    if not bedwars.Client or OldGet then return end
    
    OldGet = bedwars.Client.Get
    bedwars.Client.Get = function(self, remoteName)
        local call = OldGet(self, remoteName)
        
        if remoteName == (remotes and remotes.AttackEntity or "AttackEntity") then
            return {
                instance = call.instance,
                SendToServer = function(_, attackTable, ...)
                    if attackTable and attackTable.validate then
                        local selfpos = attackTable.validate.selfPosition and attackTable.validate.selfPosition.value
                        local targetpos = attackTable.validate.targetPosition and attackTable.validate.targetPosition.value
                        
                        if selfpos and targetpos then
                            store.attackReach = ((selfpos - targetpos).Magnitude * 100) // 1 / 100
                            store.attackReachUpdate = tick() + 1
                            
                            if HitFixEnabled then
                                attackTable.validate.raycast = attackTable.validate.raycast or {}
                                attackTable.validate.selfPosition.value += CFrame.lookAt(selfpos, targetpos).LookVector * math.max((selfpos - targetpos).Magnitude - 14.399, 0)
                            end
                        end
                    end
                    return call:SendToServer(attackTable, ...)
                end
            }
        end
        
        return call
    end
end

local originalReachDistance = nil
local REACH_DISTANCE = 18
local remotes = {}

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
            if swordController and swordController.swingSwordAtMouse then
                debug.setconstant(swordController.swingSwordAtMouse, 23, enabled and 'raycast' or 'Raycast')
                debug.setupvalue(swordController.swingSwordAtMouse, 4, enabled and bedwars.QueryUtil or workspace)
            end
        end)
        return success
    end

    local function applyReach(enabled)
        local success = pcall(function()
            if bedwars and bedwars.CombatConstant then
                if enabled then
                    if originalReachDistance == nil then
                        originalReachDistance = bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE
                    end
                    bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = 18 + 2
                else
                    if originalReachDistance ~= nil then
                        bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = originalReachDistance
                    end
                end
                return true
            end
            return false
        end)
        return success
    end

    if hitfixOriginalState == nil then
        hitfixOriginalState = false
    end

    hookClientGet()
    local hookSuccess = pcall(function() applyFunctionHook(HitFixEnabled) end)
    local debugSuccess = applyDebugPatch(HitFixEnabled)
    local reachSuccess = applyReach(HitFixEnabled)


    return hookSuccess and reachSuccess
end

local function enableHitFix()
    if not bedwarsLoaded then return false end
    HitFixEnabled = true
    local success = setupHitFix()
    return success
end

local function disableHitFix()
    if not bedwarsLoaded then return false end
    HitFixEnabled = false
    local success = setupHitFix()
    return success
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

local AutoToolEnabled = false
local autoToolConnections = {}
local oldHitBlock = nil

local function switchHotbarItem(block)
    if not Settings.AutoToolEnabled or not bedwarsLoaded then return false end
    
    if block and not block:GetAttribute('NoBreak') and not block:GetAttribute('Team'..(lplr:GetAttribute('Team') or 0)..'NoBreak') then
        local blockMeta = bedwars.ItemMeta[block.Name]
        if not blockMeta or not blockMeta.block then return false end
        
        local tool, slot = store.tools[blockMeta.block.breakType], nil
        if tool then
            for i, v in store.inventory.hotbar do
                if v.item and v.item.itemType == tool.itemType then 
                    slot = i - 1 
                    break 
                end
            end

            if hotbarSwitch(slot) then
                return true
            end
        end
    end
    return false
end

local function enableAutoTool()
    if AutoToolEnabled or not bedwarsLoaded or not bedwars.BlockBreaker then return false end
    
    local success = pcall(function()
        oldHitBlock = bedwars.BlockBreaker.hitBlock
        bedwars.BlockBreaker.hitBlock = function(self, maid, raycastparams, ...)
            local block = self.clientManager:getBlockSelector():getMouseInfo(1, {ray = raycastparams})
            if switchHotbarItem(block and block.target and block.target.blockInstance or nil) then 
                return 
            end
            return oldHitBlock(self, maid, raycastparams, ...)
        end
        AutoToolEnabled = true
    end)
    
    return success
end

local function disableAutoTool()
    if not AutoToolEnabled or not bedwarsLoaded or not bedwars.BlockBreaker then return false end
    
    local success = pcall(function()
        if oldHitBlock then
            bedwars.BlockBreaker.hitBlock = oldHitBlock
            oldHitBlock = nil
        end
        AutoToolEnabled = false
    end)
    
    for _, conn in pairs(autoToolConnections) do
        pcall(function() conn:Disconnect() end)
    end
    autoToolConnections = {}
    
    return success
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
    if Settings.AutoToolEnabled then
        enableAutoTool()
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
    disableAutoTool()
    allFeaturesEnabled = false
    task.spawn(function()
        showNotification("Script disabled. Press RightShift to re-enable.", 3)
    end)
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
        if originalReachDistance ~= nil and bedwars and bedwars.CombatConstant then
            bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = originalReachDistance
        end
        if OldGet and bedwars.Client then
            bedwars.Client.Get = OldGet
        end
        if oldHitBlock and bedwars.BlockBreaker then
            bedwars.BlockBreaker.hitBlock = oldHitBlock
        end
    end)
end)
