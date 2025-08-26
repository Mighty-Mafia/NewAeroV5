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
local gameCamera = workspace.CurrentCamera

repeat task.wait() until game:IsLoaded()

-- Settings (you can change these values)
local Settings = {
    ToggleKeybind = "RightShift",
    HitBoxesMode = "Player", -- "Sword" or "Player"
    HitBoxesExpandAmount = 70, 
    HitFixEnabled = true,
    InstantPPEnabled = true,
    AutoChargeBowEnabled = false,
    AutoToolEnabled = true,
    VelocityEnabled = true,
    VelocityHorizontal = 65,
    VelocityVertical = 65,
    VelocityChance = 100,
    VelocityTargetCheck = false,
    FastBreakEnabled = true,
    FastBreakSpeed = 0.21,
    NoFallEnabled = true,
    NoFallMode = "Packet", -- "Packet", "Gravity", "Teleport", "Bounce"
    NoSlowdownEnabled = true,
    DebugMode = false, -- for aero to debug shi
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

local function debugPrint(message, level)
    if not Settings.DebugMode then return end
    level = level or "INFO"
    local timestamp = os.date("%H:%M:%S")
    print(string.format("[%s] [%s] %s", timestamp, level, message))
end

local Velocity = {
    Enabled = Settings.VelocityEnabled,
    Horizontal = {Value = Settings.VelocityHorizontal},
    Vertical = {Value = Settings.VelocityVertical},
    Chance = {Value = Settings.VelocityChance},
    TargetCheck = {Enabled = Settings.VelocityTargetCheck}
}
local velocityOld = nil
local rand = Random.new()

local bedwars = {}
local remotes = {}
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

local function entityPosition(options)
    options = options or {}
    local range = options.Range or 50
    local part = options.Part or 'RootPart'
    local players = options.Players
    
    debugPrint(string.format("entityPosition() called - Range: %d, Part: %s, Players: %s", 
        range, part, tostring(players)), "ENTITY")
    
    if not entitylib.isAlive then 
        debugPrint("entityPosition() failed: player not alive", "ENTITY")
        return nil 
    end
    
    local localPos = entitylib.character.RootPart.Position
    local entityCount = 0
    local targetableCount = 0
    local closest = nil
    local closestDistance = range
    
    for _, entity in pairs(entitylib.List) do
        entityCount = entityCount + 1
        if entity.Targetable and entity[part] then
            targetableCount = targetableCount + 1
            local distance = (localPos - entity[part].Position).Magnitude
            debugPrint(string.format("Found entity at distance: %.2f (range: %d)", distance, range), "ENTITY")
            
            if distance <= closestDistance then
                if players and entity.Player then
                    closest = entity
                    closestDistance = distance
                    debugPrint(string.format("entityPosition() found closer player target: %s at %.2f", entity.Player.Name, distance), "ENTITY")
                elseif not players then
                    closest = entity
                    closestDistance = distance
                    debugPrint("entityPosition() found closer non-player target", "ENTITY")
                end
            end
        end
    end
    
    debugPrint(string.format("entityPosition() result - Total entities: %d, Targetable: %d, Found: %s", 
        entityCount, targetableCount, closest and "YES" or "NO"), "ENTITY")
    return closest
end

local function setupBedwars()
    if not knit then return false end

    local success = pcall(function()
        bedwars.Client = require(mainReplicatedStorage.TS.remotes).default.Client

        bedwars.SwordController = knit.Controllers.SwordController
        debugPrint("SwordController loaded: " .. tostring(bedwars.SwordController ~= nil), "DEBUG")
        if bedwars.SwordController and bedwars.SwordController.swingSwordInRegion then
            debugPrint("swingSwordInRegion function found", "DEBUG")
        else
            debugPrint("swingSwordInRegion function NOT found", "ERROR")
        end

        bedwars.SprintController = knit.Controllers.SprintController
        bedwars.ProjectileController = knit.Controllers.ProjectileController
        bedwars.QueryUtil = require(mainReplicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out).GameQueryUtil or workspace
        bedwars.BowConstantsTable = debug.getupvalue(knit.Controllers.ProjectileController.enableBeam, 8)
        bedwars.ItemMeta = debug.getupvalue(require(mainReplicatedStorage.TS.item['item-meta']).getItemMeta, 1)
        bedwars.Store = require(lplr.PlayerScripts.TS.ui.store).ClientStore
        bedwars.BlockBreaker = knit.Controllers.BlockBreakController.blockBreaker
        bedwars.BlockBreakController = knit.Controllers.BlockBreakController
        bedwars.KnockbackUtil = require(mainReplicatedStorage.TS.damage['knockback-util']).KnockbackUtil

        debugPrint("bedwars.KnockbackUtil loaded successfully", "SUCCESS")

        local combatConstantSuccess = false
        local combatConstantPaths = {
            function() return require(mainReplicatedStorage.TS.combat['combat-constant']).CombatConstant end,
            function() return require(mainReplicatedStorage.TS.combat.CombatConstant) end,
            function() return knit.Controllers.SwordController.CombatConstant end
        }

        for i, pathFunc in ipairs(combatConstantPaths) do
            local success = pcall(function()
                bedwars.CombatConstant = pathFunc()
                if bedwars.CombatConstant and bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE then
                    combatConstantSuccess = true
                    debugPrint(string.format("CombatConstant loaded via path %d, reach distance: %s", i, tostring(bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE)), "DEBUG")
                end
            end)
            if combatConstantSuccess then break end
        end

        if not combatConstantSuccess then
            debugPrint("All CombatConstant paths failed, trying direct constant modification", "DEBUG")
            pcall(function()
                local constants = debug.getconstants(bedwars.SwordController.swingSwordInRegion)
                for i, v in pairs(constants) do
                    if v == 3.8 then
                        debugPrint("Found sword range constant at index " .. i, "DEBUG")
                        break
                    end
                end
            end)
        end

        if combatConstantSuccess and bedwars.Client then
            pcall(function()
                local remoteNames = {
                    AttackEntity = bedwars.SwordController.sendServerRequest,
                    GroundHit = knit.Controllers.FallDamageController.KnitStart
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
                        debugPrint("Remote found: " .. i .. " -> " .. remote, "DEBUG")
                    else
                        debugPrint("Failed to find remote: " .. i, "ERROR")
                    end
                end
            end)
        end

        if combatConstantSuccess and bedwars.Client then
            pcall(function()
                bedwars.AttackEntityRemote = bedwars.Client:Get("AttackEntity")
            end)
        end

        debugPrint("CombatConstant loaded: " .. tostring(combatConstantSuccess), "DEBUG")
        if combatConstantSuccess then
            debugPrint("Original reach distance: " .. tostring(bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE), "DEBUG")
        end

        debugPrint("BEDWARS COMPONENTS LOADED - CombatConstant: " .. (combatConstantSuccess and "SUCCESS" or "FAILED"), "SUCCESS")

        if knit.Controllers.BlockBreakController then
            debugPrint("BlockBreakController found: " .. tostring(knit.Controllers.BlockBreakController ~= nil), "DEBUG")
            if knit.Controllers.BlockBreakController.blockBreaker then
                debugPrint("blockBreaker found: " .. tostring(knit.Controllers.BlockBreakController.blockBreaker ~= nil), "DEBUG")
                if knit.Controllers.BlockBreakController.blockBreaker.setCooldown then
                    debugPrint("setCooldown function found: " .. tostring(type(knit.Controllers.BlockBreakController.blockBreaker.setCooldown)), "DEBUG")
                else
                    debugPrint("setCooldown function NOT found", "ERROR")
                end
            else
                debugPrint("blockBreaker NOT found", "ERROR")
            end
        else
            debugPrint("BlockBreakController NOT found", "ERROR")
        end

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
        debugPrint("FAILED TO SETUP BEDWARS COMPONENTS", "ERROR")
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
                                attackTable.validate.selfPosition.value = selfpos + CFrame.lookAt(selfpos, targetpos).LookVector * math.max((selfpos - targetpos).Magnitude - 14.399, 0)
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
                local originalResult = oldCalculateImportantLaunchValues(...)
                if originalResult then
                    originalResult.drawDurationSeconds = 5
                    return originalResult
                end
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

local hitboxObjects = {}
local hitboxSet = nil
local hitboxConnections = {}
local HitBoxesEnabled = false

local FastBreakEnabled = false

local NoFallEnabled = false
local noFallConnections = {}
local groundHit = nil
local NoSlowdownEnabled = false
local oldSlowdown = nil

local function createHitbox(ent)
    debugPrint(string.format("createHitbox() called for entity: %s", ent.Player and ent.Player.Name or "NPC"), "HITBOX")
    
    if ent.Targetable and ent.Player then
        local success = pcall(function()
            local hitbox = Instance.new('Part')
            hitbox.Size = Vector3.new(3, 6, 3) + Vector3.one * (Settings.HitBoxesExpandAmount / 5)
            hitbox.Position = ent.RootPart.Position
            hitbox.CanCollide = false
            hitbox.Massless = true
            hitbox.Transparency = 1
            hitbox.Parent = ent.Character
            
            local weld = Instance.new('Motor6D')
            weld.Part0 = hitbox
            weld.Part1 = ent.RootPart
            weld.Parent = hitbox
            
            hitboxObjects[ent] = hitbox
            debugPrint(string.format("Created hitbox for %s with size: %s", ent.Player.Name, tostring(hitbox.Size)), "HITBOX")
        end)
        
        if not success then
            debugPrint(string.format("Failed to create hitbox for %s", ent.Player and ent.Player.Name or "unknown"), "HITBOX")
        end
    end
end

local function removeHitbox(ent)
    if hitboxObjects[ent] then
        hitboxObjects[ent]:Destroy()
        hitboxObjects[ent] = nil
        debugPrint(string.format("Removed hitbox for %s", ent.Player and ent.Player.Name or "unknown"), "HITBOX")
    end
end

local function applySwordHitbox(enabled)
    if not bedwarsLoaded or not bedwars or not bedwars.SwordController then
        debugPrint("applySwordHitbox() failed: bedwars not loaded or SwordController missing", "HITBOX")
        return false
    end
    
    if not bedwars.SwordController.swingSwordInRegion then
        debugPrint("applySwordHitbox() failed: swingSwordInRegion function not found", "HITBOX")
        return false
    end
    
    local success, errorMsg = pcall(function()
        if enabled then
            debug.setconstant(bedwars.SwordController.swingSwordInRegion, 6, (Settings.HitBoxesExpandAmount / 3))
            hitboxSet = true
            debugPrint(string.format("Applied sword hitbox with range: %.2f", Settings.HitBoxesExpandAmount / 3), "HITBOX")
        else
            debug.setconstant(bedwars.SwordController.swingSwordInRegion, 6, 3.8)
            hitboxSet = nil
            debugPrint("Removed sword hitbox, restored to 3.8", "HITBOX")
        end
    end)
    
    if not success then
        debugPrint("applySwordHitbox() failed to modify swingSwordInRegion: " .. tostring(errorMsg), "HITBOX")
    end
    
    return success
end

local function updatePlayerHitboxes()
    for ent, part in pairs(hitboxObjects) do
        if part and part.Parent then
            part.Size = Vector3.new(3, 6, 3) + Vector3.one * (Settings.HitBoxesExpandAmount / 5)
            debugPrint(string.format("Updated hitbox size for %s: %s", ent.Player.Name, tostring(part.Size)), "HITBOX")
        end
    end
end

local function enableHitboxes()
    debugPrint(string.format("enableHitboxes() called - Mode: %s, Expand: %.2f", Settings.HitBoxesMode, Settings.HitBoxesExpandAmount), "HITBOX")
    
    if not entitylib.Running then
        entitylib.start()
        debugPrint("Started entitylib for hitboxes", "HITBOX")
    end
    
    if Settings.HitBoxesMode == 'Sword' then
        local success = applySwordHitbox(true)
        if success then
            HitBoxesEnabled = true
            debugPrint("Sword hitboxes enabled successfully", "HITBOX")
            return true
        else
            debugPrint("Failed to enable sword hitboxes", "HITBOX")
            return false
        end
    else 
        for _, conn in pairs(hitboxConnections) do
            pcall(function() conn:Disconnect() end)
        end
        hitboxConnections = {}
        table.insert(hitboxConnections, entitylib.Events.EntityAdded:Connect(createHitbox))
        table.insert(hitboxConnections, entitylib.Events.EntityRemoved:Connect(removeHitbox))
        
        for _, ent in pairs(entitylib.List) do
            createHitbox(ent)
        end
        
        HitBoxesEnabled = true
        debugPrint(string.format("Player hitboxes enabled successfully - Created %d hitboxes", #hitboxObjects), "HITBOX")
        return true
    end
end

local function disableHitboxes()
    debugPrint("disableHitboxes() called", "HITBOX")
    
    if Settings.HitBoxesMode == 'Sword' then
        if hitboxSet then
            applySwordHitbox(false)
        end
    else
        for ent, part in pairs(hitboxObjects) do
            if part and part.Parent then
                part:Destroy()
            end
        end
        table.clear(hitboxObjects)
        debugPrint("Cleaned up all player hitboxes", "HITBOX")
    end
    
    for _, conn in pairs(hitboxConnections) do
        pcall(function() conn:Disconnect() end)
    end
    hitboxConnections = {}
    
    HitBoxesEnabled = false
    debugPrint("Hitboxes disabled successfully", "HITBOX")
    return true
end

local function updateHitboxSettings()
    if HitBoxesEnabled then
        if Settings.HitBoxesMode == 'Sword' and hitboxSet then
            applySwordHitbox(true) 
        elseif Settings.HitBoxesMode == 'Player' then
            updatePlayerHitboxes()
        end
        debugPrint(string.format("Updated hitbox settings - Mode: %s, Expand: %.2f", Settings.HitBoxesMode, Settings.HitBoxesExpandAmount), "HITBOX")
    end
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

local function enableVelocity()
    debugPrint("enableVelocity() called", "DEBUG")
    
    if not bedwarsLoaded then
        debugPrint("enableVelocity() failed: bedwarsLoaded is false", "ERROR")
        return false
    end
    
    if not bedwars.KnockbackUtil then
        debugPrint("enableVelocity() failed: bedwars.KnockbackUtil not found", "ERROR")
        return false
    end
    
    debugPrint("enableVelocity() prerequisites met, attempting to hook", "DEBUG")
    
    local success = pcall(function()
        if not velocityOld then
            velocityOld = bedwars.KnockbackUtil.applyKnockback
            debugPrint("enableVelocity() stored original applyKnockback function", "DEBUG")
        end
        
        bedwars.KnockbackUtil.applyKnockback = function(root, mass, dir, knockback, ...)
            debugPrint(string.format("Knockback applied! Chance: %d%%, Horizontal: %d%%, Vertical: %d%%", 
                Velocity.Chance.Value, Velocity.Horizontal.Value, Velocity.Vertical.Value), "VELOCITY")
            
            local chanceRoll = rand:NextNumber(0, 100)
            debugPrint(string.format("Chance roll: %.2f vs %d", chanceRoll, Velocity.Chance.Value), "VELOCITY")
            
            if chanceRoll > Velocity.Chance.Value then 
                debugPrint("Chance roll failed, applying normal knockback", "VELOCITY")
                return velocityOld(root, mass, dir, knockback, ...)
            end
            
            local check = (not Velocity.TargetCheck.Enabled) or entityPosition({
                Range = 50,
                Part = 'RootPart',
                Players = true
            })
            
            debugPrint(string.format("Target check enabled: %s, Check result: %s", 
                tostring(Velocity.TargetCheck.Enabled), tostring(check ~= nil)), "VELOCITY")

            if check then
                knockback = knockback or {}
                local originalH = knockback.horizontal or 1
                local originalV = knockback.vertical or 1
                
                if Velocity.Horizontal.Value == 0 and Velocity.Vertical.Value == 0 then 
                    debugPrint("Both horizontal and vertical are 0, blocking knockback completely", "VELOCITY")
                    return 
                end
                
                knockback.horizontal = originalH * (Velocity.Horizontal.Value / 100)
                knockback.vertical = originalV * (Velocity.Vertical.Value / 100)
                
                debugPrint(string.format("Modified knockback - H: %.2f -> %.2f, V: %.2f -> %.2f", 
                    originalH, knockback.horizontal, originalV, knockback.vertical), "VELOCITY")
            else
                debugPrint("Target check failed, applying normal knockback", "VELOCITY")
            end
            
            return velocityOld(root, mass, dir, knockback, ...)
        end
        
        Velocity.Enabled = true
        debugPrint("enableVelocity() hook applied successfully", "DEBUG")
    end)
    
    if success then
        debugPrint("enableVelocity() completed successfully", "SUCCESS")
    else
        debugPrint("enableVelocity() failed with error", "ERROR")
    end
    
    return success
end

local function disableVelocity()
    debugPrint("disableVelocity() called", "DEBUG")
    
    if not bedwarsLoaded then
        debugPrint("disableVelocity() failed: bedwarsLoaded is false", "ERROR")
        return false
    end
    
    if not bedwars.KnockbackUtil then
        debugPrint("disableVelocity() failed: bedwars.KnockbackUtil not found", "ERROR")
        return false
    end
    
    if not velocityOld then
        debugPrint("disableVelocity() failed: velocityOld not stored", "ERROR")
        return false
    end
    
    local success = pcall(function()
        bedwars.KnockbackUtil.applyKnockback = velocityOld
        Velocity.Enabled = false
        debugPrint("disableVelocity() restored original function", "DEBUG")
    end)
    
    if success then
        debugPrint("disableVelocity() completed successfully", "SUCCESS")
    else
        debugPrint("disableVelocity() failed with error", "ERROR")
    end
    
    return success
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

local fastBreakLoop = nil

local function enableFastBreak()
    if FastBreakEnabled or not bedwarsLoaded then return false end
    
    debugPrint("enableFastBreak() called", "DEBUG")
    
    local success = pcall(function()
        if bedwars.BlockBreakController and bedwars.BlockBreakController.blockBreaker then
            FastBreakEnabled = true
            
            fastBreakLoop = task.spawn(function()
                while FastBreakEnabled do
                    if bedwars.BlockBreakController.blockBreaker and bedwars.BlockBreakController.blockBreaker.setCooldown then
                        bedwars.BlockBreakController.blockBreaker:setCooldown(Settings.FastBreakSpeed)
                    end
                    task.wait(0.1)
                end
            end)
            
            debugPrint("FastBreak enabled successfully with speed: " .. tostring(Settings.FastBreakSpeed), "SUCCESS")
        else
            debugPrint("BlockBreakController or blockBreaker not found", "ERROR")
            return false
        end
    end)
    
    if not success then
        debugPrint("enableFastBreak() failed", "ERROR")
    end
    
    return success
end

local function disableFastBreak()
    if not FastBreakEnabled then return false end
    
    debugPrint("disableFastBreak() called", "DEBUG")
    
    FastBreakEnabled = false
    
    if fastBreakLoop then
        task.cancel(fastBreakLoop)
        fastBreakLoop = nil
    end
    
    local success = pcall(function()
        if bedwars.BlockBreakController and bedwars.BlockBreakController.blockBreaker and bedwars.BlockBreakController.blockBreaker.setCooldown then
            bedwars.BlockBreakController.blockBreaker:setCooldown(0.3)
            debugPrint("FastBreak disabled successfully, restored to 0.3", "SUCCESS")
        end
    end)
    
    if not success then
        debugPrint("disableFastBreak() failed", "ERROR")
    end
    
    return success
end

local function enableNoFall()
    if NoFallEnabled or not bedwarsLoaded then return false end
    
    debugPrint("enableNoFall() called with mode: " .. Settings.NoFallMode, "DEBUG")
    
    local success = pcall(function()
        if not groundHit then
            task.spawn(function()
                local attempts = 0
                while not groundHit and attempts < 100 do
                    attempts = attempts + 1
                    pcall(function()
                        if bedwars.Client and bedwars.Client.Get then
                            local remoteResult = bedwars.Client:Get(remotes.GroundHit or "GroundHit")
                            if remoteResult and remoteResult.instance then
                                groundHit = remoteResult.instance
                                debugPrint("GroundHit remote found via bedwars.Client:Get", "SUCCESS")
                            end
                        end
                    end)
                    if not groundHit then
                        pcall(function()
                            if knit and knit.Controllers and knit.Controllers.FallDamageController then
                                groundHit = knit.Controllers.FallDamageController.KnitStart
                                debugPrint("GroundHit remote found via FallDamageController", "SUCCESS")
                            end
                        end)
                    end
                    if groundHit then break end
                    task.wait(0.1)
                end
                if not groundHit then
                    debugPrint("GroundHit remote not found after " .. attempts .. " attempts", "ERROR")
                end
            end)
        end
        
        local rayParams = RaycastParams.new()
        local tracked = 0
        
        if Settings.NoFallMode == 'Gravity' then
            local extraGravity = 0
            local gravityConnection = mainRunService.PreSimulation:Connect(function(dt)
                if entitylib.isAlive and entitylib.character.RootPart then
                    local root = entitylib.character.RootPart
                    if root.AssemblyLinearVelocity.Y < -85 then
                        rayParams.FilterDescendantsInstances = {lplr.Character, gameCamera}
                        rayParams.CollisionGroup = root.CollisionGroup

                        local rootSize = root.Size.Y / 2 + entitylib.character.HipHeight
                        local ray = workspace:Blockcast(root.CFrame, Vector3.new(3, 3, 3), Vector3.new(0, (tracked * 0.1) - rootSize, 0), rayParams)
                        if not ray then
                            root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, -86, root.AssemblyLinearVelocity.Z)
                            root.CFrame += Vector3.new(0, extraGravity * dt, 0)
                            extraGravity += -workspace.Gravity * dt
                        end
                    else
                        extraGravity = 0
                    end
                end
            end)
            table.insert(noFallConnections, gravityConnection)
        else
            local noFallLoop = task.spawn(function()
                repeat
                    if entitylib.isAlive and entitylib.character.RootPart and entitylib.character.Humanoid then
                        local root = entitylib.character.RootPart
                        tracked = entitylib.character.Humanoid.FloorMaterial == Enum.Material.Air and math.min(tracked, root.AssemblyLinearVelocity.Y) or 0

                        if tracked < -85 then
                            if Settings.NoFallMode == 'Packet' and groundHit then
                                groundHit:FireServer(nil, Vector3.new(0, tracked, 0), workspace:GetServerTimeNow())
                                debugPrint("NoFall packet sent with velocity: " .. tostring(tracked), "DEBUG")
                            else
                                rayParams.FilterDescendantsInstances = {lplr.Character, gameCamera}
                                rayParams.CollisionGroup = root.CollisionGroup

                                local rootSize = root.Size.Y / 2 + entitylib.character.HipHeight
                                if Settings.NoFallMode == 'Teleport' then
                                    local ray = workspace:Blockcast(root.CFrame, Vector3.new(3, 3, 3), Vector3.new(0, -1000, 0), rayParams)
                                    if ray then
                                        root.CFrame -= Vector3.new(0, root.Position.Y - (ray.Position.Y + rootSize), 0)
                                        debugPrint("NoFall teleported to ground", "DEBUG")
                                    end
                                else 
                                    local ray = workspace:Blockcast(root.CFrame, Vector3.new(3, 3, 3), Vector3.new(0, (tracked * 0.1) - rootSize, 0), rayParams)
                                    if ray then
                                        tracked = 0
                                        root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, -80, root.AssemblyLinearVelocity.Z)
                                        debugPrint("NoFall bounced player", "DEBUG")
                                    end
                                end
                            end
                        end
                    end

                    task.wait(0.03)
                until not NoFallEnabled
            end)
            table.insert(noFallConnections, {Disconnect = function() task.cancel(noFallLoop) end})
        end
        
        NoFallEnabled = true
        debugPrint("NoFall enabled successfully with mode: " .. Settings.NoFallMode, "SUCCESS")
    end)
    
    if not success then
        debugPrint("enableNoFall() failed", "ERROR")
    end
    
    return success
end

local function disableNoFall()
    if not NoFallEnabled then return false end
    
    debugPrint("disableNoFall() called", "DEBUG")
    
    NoFallEnabled = false
    
    for _, conn in pairs(noFallConnections) do
        pcall(function() conn:Disconnect() end)
    end
    noFallConnections = {}
    
    debugPrint("NoFall disabled successfully", "SUCCESS")
    return true
end

local function enableNoSlowdown()
    if NoSlowdownEnabled or not bedwarsLoaded then return false end
    
    debugPrint("enableNoSlowdown() called", "DEBUG")
    
    local success = pcall(function()
        if bedwars.SprintController then
            local modifier = bedwars.SprintController:getMovementStatusModifier()
            if modifier then
                oldSlowdown = modifier.addModifier
                modifier.addModifier = function(self, tab)
                    if tab.moveSpeedMultiplier then
                        tab.moveSpeedMultiplier = math.max(tab.moveSpeedMultiplier, 1)
                    end
                    return oldSlowdown(self, tab)
                end

                for i in modifier.modifiers do
                    if (i.moveSpeedMultiplier or 1) < 1 then
                        modifier:removeModifier(i)
                    end
                end
                
                NoSlowdownEnabled = true
                debugPrint("NoSlowdown enabled successfully", "SUCCESS")
            else
                debugPrint("Movement status modifier not found", "ERROR")
                return false
            end
        else
            debugPrint("SprintController not found", "ERROR")
            return false
        end
    end)
    
    if not success then
        debugPrint("enableNoSlowdown() failed", "ERROR")
    end
    
    return success
end

local function disableNoSlowdown()
    if not NoSlowdownEnabled or not bedwarsLoaded then return false end
    
    debugPrint("disableNoSlowdown() called", "DEBUG")
    
    local success = pcall(function()
        if bedwars.SprintController and oldSlowdown then
            local modifier = bedwars.SprintController:getMovementStatusModifier()
            if modifier then
                modifier.addModifier = oldSlowdown
                oldSlowdown = nil
                NoSlowdownEnabled = false
                debugPrint("NoSlowdown disabled successfully", "SUCCESS")
            end
        end
    end)
    
    if not success then
        debugPrint("disableNoSlowdown() failed", "ERROR")
    end
    
    return success
end

local UserInputService = game:GetService("UserInputService")
local allFeaturesEnabled = true

local function enableAllFeatures()
    debugPrint("enableAllFeatures() called", "DEBUG")
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
    if Settings.VelocityEnabled then
        enableVelocity()
    end
    if Settings.FastBreakEnabled then
        enableFastBreak()
    end
    if Settings.NoFallEnabled then
        enableNoFall()
    end
    if Settings.NoSlowdownEnabled then
        enableNoSlowdown()
    end
    allFeaturesEnabled = true
end

local function disableAllFeatures()
    debugPrint("disableAllFeatures() called", "DEBUG")
    resetESP()
    disableInstantPP()
    disableHitboxes()
    disableSprint()
    disableHitFix()
    disableAutoChargeBow()
    disableAutoTool()
    disableVelocity()
    disableFastBreak()
    disableNoFall()
    disableNoSlowdown()
    allFeaturesEnabled = false
    task.spawn(function()
        showNotification("Script disabled. Press RightShift to re-enable.", 3)
    end)
end

local mainInputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if input.KeyCode == Enum.KeyCode[Settings.ToggleKeybind] then
        debugPrint(string.format("Toggle key pressed - Current state: %s", tostring(allFeaturesEnabled)), "INPUT")
        if allFeaturesEnabled then
            debugPrint("Disabling all features", "INPUT")
            disableAllFeatures()
        else
            debugPrint("Enabling all features", "INPUT")
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

debugPrint("Script initialization starting", "INIT")
debugPrint(string.format("Bedwars loaded: %s", tostring(bedwarsLoaded)), "INIT")
debugPrint(string.format("Velocity settings - H: %d%%, V: %d%%, Chance: %d%%, TargetCheck: %s", 
    Settings.VelocityHorizontal, Settings.VelocityVertical, Settings.VelocityChance, tostring(Settings.VelocityTargetCheck)), "INIT")

enableAllFeatures()
task.spawn(function()
    local statusMsg = "Script loaded and enabled. Press RightShift to toggle on/off."
    if bedwarsLoaded then
        statusMsg = statusMsg .. " HitFix: " .. (Settings.HitFixEnabled and "ON" or "OFF") .. ", HitBoxes: " .. Settings.HitBoxesMode
    end
    showNotification(statusMsg, 4)
    debugPrint("Script fully initialized and ready", "INIT")
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
        if velocityOld and bedwars.KnockbackUtil then
            bedwars.KnockbackUtil.applyKnockback = velocityOld
        end
        if FastBreakEnabled then
            disableFastBreak()
        end
        if fastBreakLoop then
            task.cancel(fastBreakLoop)
            fastBreakLoop = nil
        end
        if NoFallEnabled then
            disableNoFall()
        end
        for _, conn in pairs(noFallConnections) do
            pcall(function() conn:Disconnect() end)
        end
        table.clear(noFallConnections)
        if NoSlowdownEnabled then
            disableNoSlowdown()
        end
        for ent, part in pairs(hitboxObjects) do
            if part and part.Parent then
                part:Destroy()
            end
        end
        table.clear(hitboxObjects)
        if hitboxSet then
            applySwordHitbox(false)
        end
        for _, conn in pairs(hitboxConnections) do
            pcall(function() conn:Disconnect() end)
        end
        table.clear(hitboxConnections)
    end)
end)
