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

local rayCheck = RaycastParams.new()
rayCheck.FilterType = Enum.RaycastFilterType.Include
rayCheck.FilterDescendantsInstances = {workspace:FindFirstChild('Map')}

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

entitylib.isVulnerable = function(ent)
    return ent.Health > 0 and not ent.Character:FindFirstChildWhichIsA('ForceField')
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
    return workspace:Raycast(origin, (position - origin), ignoreobject)
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

local prediction = {
    SolveTrajectory = function(origin, projectileSpeed, gravity, targetPos, targetVelocity, playerGravity, playerHeight, playerJump, params)
        local eps = 1e-9
        
        local function isZero(d)
            return (d > -eps and d < eps)
        end

        local function cuberoot(x)
            return (x > 0) and math.pow(x, (1 / 3)) or -math.pow(math.abs(x), (1 / 3))
        end

        local function solveQuadric(c0, c1, c2)
            local s0, s1
            local p, q, D
            p = c1 / (2 * c0)
            q = c2 / c0
            D = p * p - q

            if isZero(D) then
                s0 = -p
                return s0
            elseif (D < 0) then
                return
            else
                local sqrt_D = math.sqrt(D)
                s0 = sqrt_D - p
                s1 = -sqrt_D - p
                return s0, s1
            end
        end

        local function solveCubic(c0, c1, c2, c3)
            local s0, s1, s2
            local num, sub
            local A, B, C
            local sq_A, p, q
            local cb_p, D

            if c0 == 0 then
                return solveQuadric(c1, c2, c3)
            end

            A = c1 / c0
            B = c2 / c0
            C = c3 / c0
            sq_A = A * A
            p = (1 / 3) * (-(1 / 3) * sq_A + B)
            q = 0.5 * ((2 / 27) * A * sq_A - (1 / 3) * A * B + C)
            cb_p = p * p * p
            D = q * q + cb_p

            if isZero(D) then
                if isZero(q) then
                    s0 = 0
                    num = 1
                else
                    local u = cuberoot(-q)
                    s0 = 2 * u
                    s1 = -u
                    num = 2
                end
            elseif (D < 0) then
                local phi = (1 / 3) * math.acos(-q / math.sqrt(-cb_p))
                local t = 2 * math.sqrt(-p)
                s0 = t * math.cos(phi)
                s1 = -t * math.cos(phi + math.pi / 3)
                s2 = -t * math.cos(phi - math.pi / 3)
                num = 3
            else
                local sqrt_D = math.sqrt(D)
                local u = cuberoot(sqrt_D - q)
                local v = -cuberoot(sqrt_D + q)
                s0 = u + v
                num = 1
            end

            sub = (1 / 3) * A
            if (num > 0) then s0 = s0 - sub end
            if (num > 1) then s1 = s1 - sub end
            if (num > 2) then s2 = s2 - sub end

            return s0, s1, s2
        end

        local function solveQuartic(c0, c1, c2, c3, c4)
            local s0, s1, s2, s3
            local coeffs = {}
            local z, u, v, sub
            local A, B, C, D
            local sq_A, p, q, r
            local num

            A = c1 / c0
            B = c2 / c0
            C = c3 / c0
            D = c4 / c0

            sq_A = A * A
            p = -0.375 * sq_A + B
            q = 0.125 * sq_A * A - 0.5 * A * B + C
            r = -(3 / 256) * sq_A * sq_A + 0.0625 * sq_A * B - 0.25 * A * C + D

            if isZero(r) then
                coeffs[3] = q
                coeffs[2] = p
                coeffs[1] = 0
                coeffs[0] = 1

                local results = {solveCubic(coeffs[0], coeffs[1], coeffs[2], coeffs[3])}
                num = #results
                s0, s1, s2 = results[1], results[2], results[3]
            else
                coeffs[3] = 0.5 * r * p - 0.125 * q * q
                coeffs[2] = -r
                coeffs[1] = -0.5 * p
                coeffs[0] = 1

                s0, s1, s2 = solveCubic(coeffs[0], coeffs[1], coeffs[2], coeffs[3])
                z = s0

                u = z * z - r
                v = 2 * z - p

                if isZero(u) then
                    u = 0
                elseif (u > 0) then
                    u = math.sqrt(u)
                else
                    return
                end
                if isZero(v) then
                    v = 0
                elseif (v > 0) then
                    v = math.sqrt(v)
                else
                    return
                end

                coeffs[2] = z - u
                coeffs[1] = q < 0 and -v or v
                coeffs[0] = 1

                do
                    local results = {solveQuadric(coeffs[0], coeffs[1], coeffs[2])}
                    num = #results
                    s0, s1 = results[1], results[2]
                end

                coeffs[2] = z + u
                coeffs[1] = q < 0 and v or -v
                coeffs[0] = 1

                if (num == 0) then
                    local results = {solveQuadric(coeffs[0], coeffs[1], coeffs[2])}
                    num = num + #results
                    s0, s1 = results[1], results[2]
                end
                if (num == 1) then
                    local results = {solveQuadric(coeffs[0], coeffs[1], coeffs[2])}
                    num = num + #results
                    s1, s2 = results[1], results[2]
                end
                if (num == 2) then
                    local results = {solveQuadric(coeffs[0], coeffs[1], coeffs[2])}
                    num = num + #results
                    s2, s3 = results[1], results[2]
                end
            end

            sub = 0.25 * A
            if (num > 0) then s0 = s0 - sub end
            if (num > 1) then s1 = s1 - sub end
            if (num > 2) then s2 = s2 - sub end
            if (num > 3) then s3 = s3 - sub end

            return {s3, s2, s1, s0}
        end

        local disp = targetPos - origin
        local p, q, r = targetVelocity.X, targetVelocity.Y, targetVelocity.Z
        local h, j, k = disp.X, disp.Y, disp.Z
        local l = -.5 * gravity

        if math.abs(q) > 0.01 and playerGravity and playerGravity > 0 then
            local estTime = (disp.Magnitude / projectileSpeed)
            local maxIterations = 3
            
            for i = 1, maxIterations do
                q -= (.5 * playerGravity) * estTime
                local velo = targetVelocity * 0.016
                local ray = workspace:Raycast(Vector3.new(targetPos.X, targetPos.Y, targetPos.Z), 
                    Vector3.new(velo.X, (q * estTime) - playerHeight, velo.Z), params)
                
                if ray then
                    local newTarget = ray.Position + Vector3.new(0, playerHeight, 0)
                    local distanceDiff = (targetPos - newTarget).Magnitude
                    estTime -= math.sqrt((distanceDiff * 2) / math.max(playerGravity, 1))
                    targetPos = newTarget
                    j = (targetPos - origin).Y
                    q = 0
                    break
                else
                    break
                end
            end
        end

        local solutions = solveQuartic(
            l*l,
            -2*q*l,
            q*q - 2*j*l - projectileSpeed*projectileSpeed + p*p + r*r,
            2*j*q + 2*h*p + 2*k*r,
            j*j + h*h + k*k
        )
        
        if solutions then
            local posRoots = {}
            for _, v in solutions do
                if v > 0 then
                    table.insert(posRoots, v)
                end
            end
            table.sort(posRoots)

            if posRoots[1] then
                local t = posRoots[1]
                local dx = h + p * t
                local dy = j + q * t - l * t * t
                local dz = k + r * t
                return origin + Vector3.new(dx, dy, dz)
            end
        elseif gravity == 0 then
            local t = (disp.Magnitude / projectileSpeed)
            local dx = h + p * t
            local dy = j + q * t - l * t * t
            local dz = k + r * t
            return origin + Vector3.new(dx, dy, dz)
        end
    end
}

local strafingPatterns = {}
local movementHistory = {}

local function predictStrafingMovement(targetPlayer, targetPart, projSpeed, gravity, origin)
    if not targetPlayer or not targetPlayer.Character or not targetPart then 
        return targetPart and targetPart.Position or Vector3.zero
    end
    
    local playerId = targetPlayer.UserId
    local currentPos = targetPart.Position
    local currentVel = targetPart.Velocity
    
    if not movementHistory[playerId] then
        movementHistory[playerId] = {
            positions = {},
            velocities = {},
            timestamps = {},
            pattern = "linear",
            lastDirectionChange = 0,
            strafeIntensity = 0
        }
    end
    
    local history = movementHistory[playerId]
    local currentTime = tick()
    
    table.insert(history.positions, currentPos)
    table.insert(history.velocities, currentVel)
    table.insert(history.timestamps, currentTime)
    
    while #history.timestamps > 0 and currentTime - history.timestamps[1] > 1.0 do
        table.remove(history.positions, 1)
        table.remove(history.velocities, 1)
        table.remove(history.timestamps, 1)
    end
    
    local distance = (currentPos - origin).Magnitude
    local timeToTarget = distance / projSpeed
    
    local basePrediction = currentPos + (currentVel * timeToTarget * 0.35)
    
    if #history.positions < 3 then
        return basePrediction
    end
    
    local directionChanges = 0
    local avgSpeed = 0
    local horizontalMovement = Vector3.zero
    
    for i = 2, #history.velocities do
        local prevVel = history.velocities[i-1]
        local currVel = history.velocities[i]
        
        local prevHorizontal = Vector3.new(prevVel.X, 0, prevVel.Z)
        local currHorizontal = Vector3.new(currVel.X, 0, currVel.Z)
        
        if prevHorizontal.Magnitude > 2 and currHorizontal.Magnitude > 2 then
            avgSpeed = avgSpeed + currHorizontal.Magnitude
            
            local dot = prevHorizontal.Unit:Dot(currHorizontal.Unit)
            if dot < 0.7 then 
                directionChanges = directionChanges + 1
                history.lastDirectionChange = currentTime
            end
            
            horizontalMovement = horizontalMovement + currHorizontal
        end
    end
    
    if #history.velocities > 1 then
        avgSpeed = avgSpeed / (#history.velocities - 1)
    end
    
    if directionChanges >= 2 and avgSpeed > 4 then
        history.pattern = "strafing"
        history.strafeIntensity = math.min(avgSpeed / 10, 1.0)
        
        local horizontalDirection = horizontalMovement.Unit
        local strafePrediction = horizontalDirection * (avgSpeed * timeToTarget * 0.25 * history.strafeIntensity)
        
        return currentPos + strafePrediction + (currentVel * timeToTarget * 0.15)
    
    elseif math.abs(currentVel.Y) > 8 then
        history.pattern = "jumping"
        
        local jumpFactor = 0.4
        local maxJumpHeight = 12
        
        local jumpPrediction = currentPos + (currentVel * timeToTarget * jumpFactor)
        
        if jumpPrediction.Y - currentPos.Y > maxJumpHeight then
            jumpPrediction = Vector3.new(
                jumpPrediction.X,
                currentPos.Y + maxJumpHeight,
                jumpPrediction.Z
            )
        end
        
        return jumpPrediction
    
    else
        history.pattern = "linear"
        history.strafeIntensity = 0
    end
    
    return currentPos + (currentVel * timeToTarget * 0.45)
end

local function smoothAim(currentCFrame, targetPosition, smoothnessFactor, maxAngleChange)
    smoothnessFactor = math.clamp(smoothnessFactor or 0.35, 0.2, 0.5)
    maxAngleChange = maxAngleChange or math.rad(6)
    
    local currentLook = currentCFrame.LookVector
    local targetDirection = (targetPosition - currentCFrame.Position).Unit
    
    local dot = currentLook:Dot(targetDirection)
    local angle = math.acos(math.clamp(dot, -1, 1))
    
    if angle < math.rad(2) then
        return CFrame.new(currentCFrame.Position, targetPosition)
    end
    
    local limitedAngle = math.min(angle, maxAngleChange)
    local smoothAngle = limitedAngle * smoothnessFactor
    
    local axis = currentLook:Cross(targetDirection)
    if axis.Magnitude > 0 then
        axis = axis.Unit
        local smoothRotation = CFrame.fromAxisAngle(axis, smoothAngle)
        local newLook = smoothRotation * currentLook
        
        return CFrame.new(currentCFrame.Position, currentCFrame.Position + newLook)
    end
    
    return CFrame.new(currentCFrame.Position, targetPosition)
end

local mainPlayersService = cloneref(game:GetService('Players'))
local mainReplicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local mainRunService = cloneref(game:GetService('RunService'))
local mainInputService = cloneref(game:GetService('UserInputService'))
local mainTweenService = cloneref(game:GetService('TweenService'))
local gameCamera = workspace.CurrentCamera
local collectionService = cloneref(game:GetService('CollectionService'))

repeat task.wait() until game:IsLoaded()

-- Settings (you can change these values)
local Settings = {
    ToggleKeybind = "RightShift",
    HitBoxesMode = "Player", -- "Sword" or "Player"
    HitBoxesExpandAmount = 80, 
    HitBoxesEnabled = true, 
    HitBoxesEnableKeybind = "Z",  
    HitBoxesDisableKeybind = "X", 
    HitFixEnabled = true,
    InstantPPEnabled = true,
    AutoChargeBowEnabled = false,
    AutoToolEnabled = true,
    VelocityEnabled = true,
    VelocityHorizontal = 85,
    VelocityVertical = 85,
    VelocityChance = 100,
    VelocityTargetCheck = false,
    FastBreakEnabled = true,
    FastBreakSpeed = 0.21,
    NoFallEnabled = true,
    NoFallMode = "Packet", -- "Packet", "Gravity", "Teleport", "Bounce"
    NoSlowdownEnabled = true,
    KitESPEnabled = true,
    ProjectileAimbotEnabled = true,
    ProjectileAimbotKeybind = "Backquote", 
    ProjectileAimbotFOV = 250,
    ProjectileAimbotTargetPart = "RootPart", 
    ProjectileAimbotOtherProjectiles = false,
    ProjectileAimbotPlayers = true,
    ProjectileAimbotWalls = false,
    ProjectileAimbotNPCs = false,
    GUIEnabled = false,
    UninjectKeybind = "RightAlt",
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
    if not Settings.GUIEnabled then return end  
    duration = duration or 2.2 

    if currentNotification and currentNotification.Parent then
        currentNotification:Destroy()
        currentNotification = nil
    end

    local notification = Instance.new("Frame")
    notification.Size = UDim2.new(0, 300, 0, 55) 
    notification.Position = UDim2.new(0.5, -150, 0, -80)
    notification.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    notification.BorderSizePixel = 0
    notification.AnchorPoint = Vector2.new(0.5, 0)
    notification.Parent = NotificationGui
    currentNotification = notification

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = notification

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(100, 180, 255)
    stroke.Thickness = 1.6
    stroke.Parent = notification

    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, -20, 1, -10)
    textLabel.Position = UDim2.new(0, 10, 0, 5)
    textLabel.BackgroundTransparency = 1
    textLabel.TextColor3 = Color3.new(1, 1, 1)
    textLabel.Font = Enum.Font.GothamMedium
    textLabel.TextSize = 15
    textLabel.Text = message
    textLabel.TextWrapped = true
    textLabel.TextXAlignment = Enum.TextXAlignment.Left
    textLabel.Parent = notification

    local tweenIn = mainTweenService:Create(notification, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {Position = UDim2.new(0.5, -150, 0, 20)})
    tweenIn:Play()

    task.spawn(function()
        task.wait(duration)
        if currentNotification == notification then
            local tweenOut = mainTweenService:Create(notification, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                {Position = UDim2.new(0.5, -150, 0, -80)})
            tweenOut:Play()
            tweenOut.Completed:Wait()
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
    tools = {},
    equippedKit = ''
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

local function hasSwordEquipped()
    if not store.inventory or not store.inventory.hotbar then 
        return false 
    end
    
    local hotbarSlot = store.inventory.hotbarSlot
    if not hotbarSlot or not store.inventory.hotbar[hotbarSlot + 1] then 
        return false 
    end
    
    local currentItem = store.inventory.hotbar[hotbarSlot + 1].item
    if not currentItem then 
        return false 
    end
    
    local itemMeta = bedwars.ItemMeta[currentItem.itemType]
    return itemMeta and itemMeta.sword ~= nil
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

local function entityMouse(options)
    options = options or {}
    local mouseLocation = options.MouseOrigin or getMousePosition()
    local sortingTable = {}
    
    if not entitylib.isAlive then 
        return nil 
    end
    
    for _, v in entitylib.List do
        if not options.Players and v.Player then continue end
        if not options.NPCs and v.NPC then continue end
        if not v.Targetable then continue end
        
        local targetPart = v[options.Part or 'RootPart']
        if not targetPart then continue end
        
        local position, vis = gameCamera:WorldToViewportPoint(targetPart.Position)
        if not vis then continue end
        
        local mag = (mouseLocation - Vector2.new(position.x, position.y)).Magnitude
        if mag > (options.Range or 1000) then continue end
        
        if entitylib.isVulnerable(v) then
            table.insert(sortingTable, {
                Entity = v,
                Magnitude = mag,
                Position = position
            })
        end
    end

    table.sort(sortingTable, options.Sort or function(a, b)
        return a.Magnitude < b.Magnitude
    end)

    for _, v in sortingTable do
        if options.Wallcheck then
            if entitylib.Wallcheck(options.Origin or entitylib.character.HumanoidRootPart.Position, v.Entity[options.Part or 'RootPart'].Position, options.Wallcheck) then 
                continue 
            end
        end
        
        table.clear(options)
        table.clear(sortingTable)
        return v.Entity
    end
    
    table.clear(sortingTable)
    table.clear(options)
    return nil
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
        pcall(function()
            local projectileMetaFunc = debug.getupvalue(knit.Controllers.ProjectileController.launchProjectileWithValues, 2)
            if projectileMetaFunc then
                bedwars.ProjectileMeta = debug.getupvalue(projectileMetaFunc, 1)
                debugPrint("ProjectileMeta loaded successfully", "DEBUG")
            end
        end)

        if bedwars.ProjectileMeta then
            debug.setmetatable({}, {
                __index = function(self, key)
                    if key == "getProjectileMeta" then
                        return function()
                            return bedwars.ProjectileMeta
                        end
                    end
                end
            })
        end
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
                if new.Bedwars ~= old.Bedwars then
                    store.equippedKit = new.Bedwars.kit ~= 'none' and new.Bedwars.kit or ''
                end
                
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
local KitESPEnabled = false
local KitESPReference = {}
local KitESPFolder = Instance.new('Folder')

local espgui = Instance.new("ScreenGui", mainPlayersService.LocalPlayer.PlayerGui)
espgui.ResetOnSpawn = false
espgui.Name = "VapeKitESPGui"
KitESPFolder.Parent = espgui

local function getIcon(item)
    local Icons = {
        ["alchemist_ingedients"] = "rbxassetid://9134545166",
        ["wild_flower"] = "rbxassetid://9134545166",
        ["bee"] = "rbxassetid://7343272839",
        ["treeOrb"] = "rbxassetid://11003449842",
        ["natures_essence_1"] = "rbxassetid://11003449842",
        ["ghost"] = "rbxassetid://9866757805",
        ["ghost_orb"] = "rbxassetid://9866757805",
        ["hidden-metal"] = "rbxassetid://6850537969",
        ["iron"] = "rbxassetid://6850537969",
        ["SheepModel"] = "rbxassetid://7861268963",
        ["purple_hay_bale"] = "rbxassetid://7861268963",
        ["alchemy_crystal"] = "rbxassetid://9134545166",
        ["stars"] = "rbxassetid://9866757805",
        ["crit_star"] = "rbxassetid://9866757805"
    }
    return Icons[item] or "rbxassetid://9866757805"
end

local function addBlur(parent)
    local blur = Instance.new('ImageLabel')
    blur.Name = 'Blur'
    blur.Size = UDim2.new(1, 89, 1, 52)
    blur.Position = UDim2.fromOffset(-48, -31)
    blur.BackgroundTransparency = 1
    blur.Image = 'rbxassetid://8560915132'
    blur.ScaleType = Enum.ScaleType.Slice
    blur.SliceCenter = Rect.new(52, 31, 261, 502)
    blur.Parent = parent
    return blur
end

local function KitESPAdded(v, icon)
    if not Settings.KitESPEnabled then return end
    
    local billboard = Instance.new('BillboardGui')
    billboard.Parent = KitESPFolder
    billboard.Name = icon
    billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
    billboard.Size = UDim2.fromOffset(36, 36)
    billboard.AlwaysOnTop = true
    billboard.ClipsDescendants = false
    billboard.Adornee = v
    local blur = addBlur(billboard)
    blur.Visible = true
    local image = Instance.new('ImageLabel')
    image.Size = UDim2.fromOffset(36, 36)
    image.Position = UDim2.fromScale(0.5, 0.5)
    image.AnchorPoint = Vector2.new(0.5, 0.5)
    image.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    image.BackgroundTransparency = 0.5
    image.BorderSizePixel = 0
    image.Image = getIcon(icon)
    image.Parent = billboard
    local uicorner = Instance.new('UICorner')
    uicorner.CornerRadius = UDim.new(0, 4)
    uicorner.Parent = image
    KitESPReference[v] = billboard
end

local function KitESPRemoved(v)
    if KitESPReference[v] then
        KitESPReference[v]:Destroy()
        KitESPReference[v] = nil
    end
end

local ESPKits = {
    alchemist = {'alchemist_ingedients', 'wild_flower'},
    beekeeper = {'bee', 'bee'},
    bigman = {'treeOrb', 'natures_essence_1'},
    ghost_catcher = {'ghost', 'ghost_orb'},
    metal_detector = {'hidden-metal', 'iron'},
    sheep_herder = {'SheepModel', 'purple_hay_bale'},
    sorcerer = {'alchemy_crystal', 'wild_flower'},
    star_collector = {'stars', 'crit_star'}
}

local kitESPConnections = {}

local function addKitESP(tag, icon)
    if not Settings.KitESPEnabled then return end
    
    local addedConnection = collectionService:GetInstanceAddedSignal(tag):Connect(function(v)
        if v.PrimaryPart then
            KitESPAdded(v.PrimaryPart, icon)
        end
    end)
    
    local removedConnection = collectionService:GetInstanceRemovedSignal(tag):Connect(function(v)
        if v.PrimaryPart then
            KitESPRemoved(v.PrimaryPart)
        end
    end)
    
    table.insert(kitESPConnections, addedConnection)
    table.insert(kitESPConnections, removedConnection)
    
    for _, v in collectionService:GetTagged(tag) do
        if v.PrimaryPart then
            KitESPAdded(v.PrimaryPart, icon)
        end
    end
end

local function enableKitESP()
    if KitESPEnabled or not Settings.KitESPEnabled then return end
    
    local kit = ESPKits[store.equippedKit]
    if kit then
        addKitESP(kit[1], kit[2])
        KitESPEnabled = true
        debugPrint("KitESP enabled for kit: " .. store.equippedKit, "DEBUG")
    end
end

local function disableKitESP()
    if not KitESPEnabled then return end
    
    for _, conn in pairs(kitESPConnections) do
        pcall(function() conn:Disconnect() end)
    end
    kitESPConnections = {}
    
    KitESPFolder:ClearAllChildren()
    table.clear(KitESPReference)
    
    KitESPEnabled = false
    debugPrint("KitESP disabled", "DEBUG")
end

local function recreateKitESP()
    disableKitESP()
    if Settings.KitESPEnabled and store.equippedKit ~= '' then
        enableKitESP()
    end
end

addCleanupFunction(function()
    if espgui and espgui.Parent then
        espgui:Destroy()
    end
    disableKitESP()
end)

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
    if not bedwars.Client then 
        debugPrint("hookClientGet() failed: bedwars.Client not available", "HITFIX")
        return false
    end
    
    if OldGet then 
        debugPrint("hookClientGet() skipped: Already hooked", "HITFIX")
        return true  -- Already hooked, return success
    end
    
    OldGet = bedwars.Client.Get
    bedwars.Client.Get = function(self, remoteName)
        local call = OldGet(self, remoteName)
        
        if remoteName == (remotes and remotes.AttackEntity or "AttackEntity") then
            debugPrint("Intercepted AttackEntity remote: " .. tostring(remoteName), "HITFIX")
            return {
                instance = call.instance,
                SendToServer = function(_, attackTable, ...)
                    if attackTable and attackTable.validate then
                        local selfpos = attackTable.validate.selfPosition and attackTable.validate.selfPosition.value
                        local targetpos = attackTable.validate.targetPosition and attackTable.validate.targetPosition.value
                        
                        if selfpos and targetpos then
                            local distance = (selfpos - targetpos).Magnitude
                            store.attackReach = math.floor(distance * 100) / 100
                            store.attackReachUpdate = tick() + 1
                            
                            if HitFixEnabled then
                                -- More sophisticated position adjustment
                                attackTable.validate.raycast = attackTable.validate.raycast or {}
                                local direction = (targetpos - selfpos).Unit
                                local adjustedDistance = math.max(distance - 14.2, 0)
                                attackTable.validate.selfPosition.value = selfpos + (direction * adjustedDistance)
                                
                                debugPrint(string.format("Adjusted attack position - Original: %.2f, Adjusted: %.2f", 
                                    distance, adjustedDistance), "HITFIX")
                            end
                        end
                    end
                    return call:SendToServer(attackTable, ...)
                end
            }
        end
        
        return call
    end
    debugPrint("Client Get hook installed successfully", "HITFIX")
    return true
end

local originalReachDistance = nil
local REACH_DISTANCE = 18
local remotes = {}

local function setupHitFix()
    if not bedwarsLoaded or not swordController then 
        debugPrint("setupHitFix() failed: bedwars not loaded or SwordController missing", "HITFIX")
        return false 
    end

    if not bedwars.SwordController.swingSwordInRegion then
        debugPrint("setupHitFix() failed: swingSwordInRegion function not found", "HITFIX")
        return false
    end

    local successCount = 0
    local totalAttempts = 0

    -- 1. Function Hooking (More comprehensive)
    local function applyFunctionHook(enabled)
        totalAttempts = totalAttempts + 1
        local functionsToHook = {"swingSwordAtMouse", "swingSwordInRegion", "attackEntity", "sendServerRequest"}
        
        for _, funcName in ipairs(functionsToHook) do
            if swordController[funcName] and type(swordController[funcName]) == "function" then
                if enabled then
                    if not originalFunctions[funcName] then
                        originalFunctions[funcName] = swordController[funcName]
                        swordController[funcName] = function(self, ...)
                            local args = {...}
                            for i, arg in ipairs(args) do
                                if type(arg) == "table" and arg.validate then
                                    -- Remove validation for better consistency
                                    args[i].validate = nil
                                    debugPrint("Removed validation from " .. funcName, "HITFIX")
                                end
                            end
                            return originalFunctions[funcName](self, unpack(args))
                        end
                        debugPrint("Hooked function: " .. funcName, "HITFIX")
                        successCount = successCount + 1
                    end
                else
                    if originalFunctions[funcName] then
                        swordController[funcName] = originalFunctions[funcName]
                        originalFunctions[funcName] = nil
                        debugPrint("Restored function: " .. funcName, "HITFIX")
                    end
                end
            end
        end
        return true
    end

    -- 2. Improved Debug Patch (More reliable)
    local function applyDebugPatch(enabled)
        totalAttempts = totalAttempts + 1
        local success = pcall(function()
            if swordController and swordController.swingSwordAtMouse then
                local constants = debug.getconstants(swordController.swingSwordAtMouse)
                for i, constant in ipairs(constants) do
                    if tostring(constant) == "Raycast" then
                        debug.setconstant(swordController.swingSwordAtMouse, i, enabled and 'raycast' or 'Raycast')
                        debugPrint("Modified constant at index " .. i .. " from 'Raycast' to 'raycast'", "HITFIX")
                        successCount = successCount + 1
                        break
                    end
                end

                -- Update query utility reference
                local upvalues = debug.getupvalues(swordController.swingSwordAtMouse)
                for i, upvalue in ipairs(upvalues) do
                    if type(upvalue) == "table" and upvalue.blockCast then
                        debug.setupvalue(swordController.swingSwordAtMouse, i, enabled and bedwars.QueryUtil or workspace)
                        debugPrint("Updated query utility reference", "HITFIX")
                        successCount = successCount + 1
                        break
                    end
                end
            end
        end)
        return success
    end

    -- 3. Smart Reach Adjustment (Less aggressive)
    local function applyReach(enabled)
        totalAttempts = totalAttempts + 1
        local success = pcall(function()
            if bedwars and bedwars.CombatConstant then
                if enabled then
                    if originalReachDistance == nil then
                        originalReachDistance = bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE
                        debugPrint("Original reach distance: " .. tostring(originalReachDistance), "HITFIX")
                    end
                    
                    -- More subtle reach increase to avoid detection
                    local newReach = originalReachDistance + 1.8  -- Reduced from +2 to +1.8
                    bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = newReach
                    debugPrint("Increased reach to: " .. tostring(newReach), "HITFIX")
                else
                    if originalReachDistance ~= nil then
                        bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = originalReachDistance
                        debugPrint("Restored original reach: " .. tostring(originalReachDistance), "HITFIX")
                    end
                end
                successCount = successCount + 1
                return true
            end
            return false
        end)
        return success
    end

    -- 4. Additional validation removal
    local function removeAdditionalValidation()
        totalAttempts = totalAttempts + 1
        local success = pcall(function()
            -- Look for validation functions in various places
            local validationTargets = {
                swordController,
                bedwars.SwordController,
                getmetatable(swordController).__index
            }
            
            for _, target in ipairs(validationTargets) do
                if target and target.validateAttack then
                    local originalValidate = target.validateAttack
                    target.validateAttack = function(...)
                        debugPrint("Bypassed attack validation", "HITFIX")
                        return true  -- Always return true to bypass validation
                    end
                    successCount = successCount + 1
                    break
                end
            end
        end)
        return success
    end

    -- Execute all methods
    local results = {
        applyFunctionHook(HitFixEnabled),
        applyDebugPatch(HitFixEnabled),
        applyReach(HitFixEnabled)
    }
    
    -- Only attempt validation removal if hitfix is enabled
    if HitFixEnabled then
        table.insert(results, removeAdditionalValidation())
    end

    -- Calculate success rate
    local successRate = successCount / totalAttempts * 100
    debugPrint(string.format("HitFix setup complete - Success: %d/%d (%.1f%%)", 
        successCount, totalAttempts, successRate), "HITFIX")

    -- Enable client-side hit validation bypass (only if not already hooked)
    if HitFixEnabled and successRate > 50 and not OldGet then
        pcall(function()
            local hookResult = hookClientGet()
            debugPrint("Client Get hook result: " .. tostring(hookResult), "HITFIX")
            if hookResult then
                successCount = successCount + 1
                totalAttempts = totalAttempts + 1
            end
        end)
    end

    return successRate > 50
end

local function enableHitFix()
    debugPrint("enableHitFix() called - Current state: " .. tostring(HitFixEnabled), "HITFIX")
    if not bedwarsLoaded then 
        debugPrint("enableHitFix() failed: bedwars not loaded", "HITFIX")
        return false 
    end
    HitFixEnabled = true
    local success = setupHitFix()
    debugPrint("enableHitFix() completed - Success: " .. tostring(success), "HITFIX")
    return success
end

local function disableHitFix()
    debugPrint("disableHitFix() called - Current state: " .. tostring(HitFixEnabled), "HITFIX")
    if not bedwarsLoaded then 
        debugPrint("disableHitFix() failed: bedwars not loaded", "HITFIX")
        return false 
    end
    HitFixEnabled = false
    local success = setupHitFix()
    debugPrint("disableHitFix() completed - Success: " .. tostring(success), "HITFIX")
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

local autoHitboxEnabled = false
local lastSwordState = false
local hitboxCheckConnection = nil
local storeChangedConnection = nil

local FastBreakEnabled = false

local ProjectileAimbotEnabled = false
local oldCalculateImportantLaunchValues = nil
local ProjectileAimbotSettings = {
    FOV = Settings.ProjectileAimbotFOV,
    TargetPart = Settings.ProjectileAimbotTargetPart,
    OtherProjectiles = Settings.ProjectileAimbotOtherProjectiles,
    Players = Settings.ProjectileAimbotPlayers,
    Walls = Settings.ProjectileAimbotWalls,
    NPCs = Settings.ProjectileAimbotNPCs
}

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
            showNotification("HitBoxes enabled (Sword detected)", 2)
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
        showNotification("HitBoxes enabled", 2)
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
    showNotification("HitBoxes disabled (No sword)", 2)
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

local strafingPatterns = {}
local function predictStrafingMovement(targetPlayer, targetPart, projSpeed, gravity)
    if not targetPlayer or not targetPlayer.Character or not targetPart then 
        return targetPart and targetPart.Position or Vector3.zero
    end
    
    local playerId = targetPlayer.UserId
    local currentPos = targetPart.Position
    local currentVel = targetPart.Velocity
    
    if not strafingPatterns[playerId] then
        strafingPatterns[playerId] = {
            lastPositions = {},
            lastUpdate = tick(),
            pattern = "none",
            directionChanges = 0,
            strafeDirection = 1,
            strafeTimer = 0,
            strafePattern = {}
        }
    end
    
    local patternData = strafingPatterns[playerId]
    local currentTime = tick()
    
    table.insert(patternData.lastPositions, {
        position = currentPos,
        velocity = currentVel,
        time = currentTime
    })
    
    while #patternData.lastPositions > 0 and currentTime - patternData.lastPositions[1].time > 1.5 do
        table.remove(patternData.lastPositions, 1)
    end
    
    local localPos = entitylib.isAlive and entitylib.character.RootPart.Position or currentPos
    local timeToTarget = (currentPos - localPos).Magnitude / projSpeed
    
    local basePrediction = currentPos + (currentVel * timeToTarget * 0.35)
    
    if #patternData.lastPositions < 3 then
        return basePrediction
    end
    
    local recentDirectionChanges = 0
    local avgHorizontalSpeed = 0
    local horizontalMovements = {}
    local verticalMovements = {}
    
    for i = 2, #patternData.lastPositions do
        local prev = patternData.lastPositions[i-1]
        local curr = patternData.lastPositions[i]
        local timeDiff = curr.time - prev.time
        
        if timeDiff > 0 then
            local prevHorizontal = Vector3.new(prev.velocity.X, 0, prev.velocity.Z)
            local currHorizontal = Vector3.new(curr.velocity.X, 0, curr.velocity.Z)
            
            if currHorizontal.Magnitude > 2 then
                avgHorizontalSpeed = avgHorizontalSpeed + currHorizontal.Magnitude
                
                if prevHorizontal.Magnitude > 2 then
                    local dot = prevHorizontal.Unit:Dot(currHorizontal.Unit)
                    if dot < 0.7 then 
                        recentDirectionChanges = recentDirectionChanges + 1
                    end
                end
                
                if currHorizontal.X ~= 0 then
                    local direction = currHorizontal.X > 0 and 1 or -1
                    table.insert(horizontalMovements, {
                        direction = direction,
                        magnitude = math.abs(currHorizontal.X),
                        time = curr.time
                    })
                end
            end
            
            if math.abs(curr.velocity.Y) > 5 then
                table.insert(verticalMovements, {
                    velocityY = curr.velocity.Y,
                    time = curr.time
                })
            end
        end
    end
    
    if #patternData.lastPositions > 1 then
        avgHorizontalSpeed = avgHorizontalSpeed / (#patternData.lastPositions - 1)
    end
    
    if recentDirectionChanges >= 2 and avgHorizontalSpeed > 4 then
        patternData.pattern = "strafing"
        patternData.directionChanges = recentDirectionChanges
        
        if #horizontalMovements >= 2 then
            local lastMovement = horizontalMovements[#horizontalMovements]
            local prevMovement = horizontalMovements[#horizontalMovements - 1]
            
            local strafeDurations = {}
            for i = 2, #horizontalMovements do
                if horizontalMovements[i].direction ~= horizontalMovements[i-1].direction then
                    local duration = horizontalMovements[i].time - horizontalMovements[i-1].time
                    table.insert(strafeDurations, duration)
                end
            end
            
            if #strafeDurations > 0 then
                local avgStrafeDuration = 0
                for _, dur in ipairs(strafeDurations) do
                    avgStrafeDuration = avgStrafeDuration + dur
                end
                avgStrafeDuration = avgStrafeDuration / #strafeDurations
                
                local timeSinceLastChange = currentTime - horizontalMovements[#horizontalMovements].time
                local predictedChangeTime = avgStrafeDuration - timeSinceLastChange
                
                if predictedChangeTime < timeToTarget and predictedChangeTime > 0 then
                    patternData.strafeDirection = -patternData.strafeDirection
                    local predictedOffset = Vector3.new(patternData.strafeDirection * avgHorizontalSpeed * 0.6, 0, 0)
                    return currentPos + (predictedOffset * timeToTarget * 0.5)
                end
            end
        end
        
        local strafePrediction = currentVel.Unit * (avgHorizontalSpeed * timeToTarget * 0.3)
        return currentPos + strafePrediction
        
    elseif #verticalMovements > 1 and math.abs(currentVel.Y) > 5 then
        patternData.pattern = "jumping"
        
        local jumpFactor = 0.6 
        local jumpPrediction = currentPos + (currentVel * timeToTarget * jumpFactor)
        
        local maxJumpHeight = 10 
        if jumpPrediction.Y - currentPos.Y > maxJumpHeight then
            jumpPrediction = Vector3.new(
                jumpPrediction.X,
                currentPos.Y + maxJumpHeight,
                jumpPrediction.Z
            )
        end
        
        return jumpPrediction
        
    else
        patternData.pattern = "linear"
    end
    
    if patternData.pattern == "linear" and currentVel.Magnitude > 3 then
        return currentPos + (currentVel * timeToTarget * 0.45)
    end
    
    return basePrediction
end

local function smoothAim(currentCFrame, targetPosition, smoothnessFactor, maxAngleChange)
    smoothnessFactor = math.clamp(smoothnessFactor or 0.4, 0.2, 0.6) 
    maxAngleChange = maxAngleChange or math.rad(8) 
    
    local currentLook = currentCFrame.LookVector
    local targetDirection = (targetPosition - currentCFrame.Position).Unit
    
    local dot = currentLook:Dot(targetDirection)
    local angle = math.acos(math.clamp(dot, -1, 1))
    
    if angle < math.rad(1) then
        return CFrame.new(currentCFrame.Position, targetPosition)
    end
    
    local limitedAngle = math.min(angle, maxAngleChange)
    
    local smoothAngle = limitedAngle * smoothnessFactor
    
    local axis = currentLook:Cross(targetDirection)
    if axis.Magnitude > 0 then
        axis = axis.Unit
        
        local smoothRotation = CFrame.fromAxisAngle(axis, smoothAngle)
        local newLook = smoothRotation * currentLook
        
        return CFrame.new(currentCFrame.Position, currentCFrame.Position + newLook)
    end
    
    return CFrame.new(currentCFrame.Position, targetPosition)
end

local function enableProjectileAimbot()
    if ProjectileAimbotEnabled or not bedwarsLoaded or not bedwars.ProjectileController then
        debugPrint("enableProjectileAimbot() failed: prerequisites not met", "ERROR")
        return false
    end

    debugPrint("enableProjectileAimbot() called", "DEBUG")

    local success = pcall(function()
        if not oldCalculateImportantLaunchValues then
            oldCalculateImportantLaunchValues = bedwars.ProjectileController.calculateImportantLaunchValues
            debugPrint("Stored original calculateImportantLaunchValues function", "DEBUG")
        end

        bedwars.ProjectileController.calculateImportantLaunchValues = function(...)
            local self, projmeta, worldmeta, origin, shootpos = ...
            
            local rayCheck = RaycastParams.new()
            rayCheck.FilterType = Enum.RaycastFilterType.Include
            rayCheck.FilterDescendantsInstances = {workspace:FindFirstChild('Map') or workspace}
            
            local plr = entityMouse({
                Part = ProjectileAimbotSettings.TargetPart,
                Range = ProjectileAimbotSettings.FOV,
                Players = ProjectileAimbotSettings.Players,
                NPCs = ProjectileAimbotSettings.NPCs,
                Wallcheck = ProjectileAimbotSettings.Walls and rayCheck or nil,
                Origin = entitylib.isAlive and (shootpos or entitylib.character.RootPart.Position) or Vector3.zero
            })

            if plr and plr.Character and plr[ProjectileAimbotSettings.TargetPart] then
                local pos = shootpos or (self.getLaunchPosition and self:getLaunchPosition(origin) or origin)
                if not pos then
                    return oldCalculateImportantLaunchValues(...)
                end

                if (not ProjectileAimbotSettings.OtherProjectiles) and not projmeta.projectile:find('arrow') then
                    return oldCalculateImportantLaunchValues(...)
                end

                local meta = projmeta:getProjectileMeta() or {}
                local lifetime = (worldmeta and meta.predictionLifetimeSec or meta.lifetimeSec or 3)
                local gravity = (meta.gravitationalAcceleration or 196.2) * projmeta.gravityMultiplier
                local projSpeed = (meta.launchVelocity or 100)
                local offsetpos = pos + (projmeta.projectile == 'owl_projectile' and Vector3.zero or projmeta.fromPositionOffset)
                
                local playerGravity = workspace.Gravity
                local balloons = plr.Character and plr.Character:GetAttribute('InflatedBalloons')
                
                if balloons and balloons > 0 then
                    local gravityMultiplier = 1
                    if balloons >= 4 then
                        gravityMultiplier = 0.8  
                    elseif balloons >= 3 then
                        gravityMultiplier = 0.85
                    else
                        gravityMultiplier = 0.9
                    end
                    playerGravity = workspace.Gravity * gravityMultiplier
                end

                if plr.Player and plr.Player:GetAttribute('IsOwlTarget') then
                    for _, owl in collectionService:GetTagged('Owl') do
                        if owl:GetAttribute('Target') == plr.Player.UserId and owl:GetAttribute('Status') == 2 then
                            playerGravity = 0
                            break
                        end
                    end
                end

                if plr.Character and plr.Character.PrimaryPart and plr.Character.PrimaryPart:FindFirstChild('rbxassetid://8200754399') then
                    playerGravity = 6
                end

                local rawLook = CFrame.new(offsetpos, plr[ProjectileAimbotSettings.TargetPart].Position)
                
                local predictedPosition
                local success, err = pcall(function()
                    predictedPosition = predictStrafingMovement(
                        plr.Player, 
                        plr[ProjectileAimbotSettings.TargetPart], 
                        projSpeed, 
                        gravity,
                        offsetpos
                    )
                end)

                if not success or not predictedPosition then
                    local timeToTarget = (plr[ProjectileAimbotSettings.TargetPart].Position - offsetpos).Magnitude / projSpeed
                    predictedPosition = plr[ProjectileAimbotSettings.TargetPart].Position + 
                                       (plr[ProjectileAimbotSettings.TargetPart].Velocity * timeToTarget * 0.3)
                end

                local newlook = smoothAim(rawLook, predictedPosition, 0.35, math.rad(5))
                
                if projmeta.projectile ~= 'owl_projectile' then
                    newlook = newlook * CFrame.new(
                        bedwars.BowConstantsTable.RelX or 0,
                        bedwars.BowConstantsTable.RelY or 0,
                        bedwars.BowConstantsTable.RelZ or 0
                    )
                end

                local targetVelocity = projmeta.projectile == 'telepearl' and Vector3.zero or plr[ProjectileAimbotSettings.TargetPart].Velocity

                local calc = prediction.SolveTrajectory(
                    newlook.p, 
                    projSpeed, 
                    gravity, 
                    predictedPosition, 
                    targetVelocity, 
                    playerGravity, 
                    plr.HipHeight, 
                    plr.Jumping and 42.6 or nil,
                    rayCheck
                )
                
                if calc then
                    debugPrint("Enhanced projectile aimbot target acquired! Pattern: " .. 
                              (movementHistory[plr.Player.UserId] and movementHistory[plr.Player.UserId].pattern or "unknown"), 
                              "PROJECTILE")
                    
                    local finalDirection = (calc - newlook.p).Unit
                    local angleFromHorizontal = math.acos(math.clamp(finalDirection:Dot(Vector3.new(0, 1, 0)), -1, 1))
                    
                    if angleFromHorizontal > math.rad(5) and angleFromHorizontal < math.rad(175) then
                        return {
                            initialVelocity = finalDirection * projSpeed,
                            positionFrom = offsetpos,
                            deltaT = lifetime,
                            gravitationalAcceleration = gravity,
                            drawDurationSeconds = 5
                        }
                    else
                        debugPrint("Prediction resulted in extreme angle, using fallback", "PROJECTILE")
                    end
                end
            end

            return oldCalculateImportantLaunchValues(...)
        end

        ProjectileAimbotEnabled = true
        debugPrint("Enhanced projectile aimbot enabled successfully", "SUCCESS")
    end)

    if not success then
        debugPrint("enableProjectileAimbot() failed: " .. tostring(success), "ERROR")
    end

    return success
end

local function disableProjectileAimbot()
    if not ProjectileAimbotEnabled or not bedwarsLoaded or not bedwars.ProjectileController then 
        debugPrint("disableProjectileAimbot() failed: prerequisites not met", "ERROR")
        return false 
    end

    debugPrint("disableProjectileAimbot() called", "DEBUG")
    
    local success = pcall(function()
        if oldCalculateImportantLaunchValues then
            bedwars.ProjectileController.calculateImportantLaunchValues = oldCalculateImportantLaunchValues
            oldCalculateImportantLaunchValues = nil
            ProjectileAimbotEnabled = false
            debugPrint("Projectile aimbot disabled successfully", "SUCCESS")
        else
            debugPrint("No original function stored to restore", "ERROR")
        end
    end)
    
    if not success then
        debugPrint("disableProjectileAimbot() failed", "ERROR")
    end
    
    return success
end

local autoHitboxEnabled = false
local lastSwordState = false
local hitboxCheckConnection = nil

local function setupAutoHitboxToggle()
    if hitboxCheckConnection then
        hitboxCheckConnection:Disconnect()
        hitboxCheckConnection = nil
    end
    
    hitboxCheckConnection = mainRunService.Heartbeat:Connect(function()
        if not Settings.HitBoxesEnabled or not autoHitboxEnabled then 
            return 
        end
        
        local hasSword = hasSwordEquipped()
        
        if hasSword ~= lastSwordState then
            if hasSword then
                if not HitBoxesEnabled then
                    enableHitboxes()
                end
            else
                if HitBoxesEnabled then
                    disableHitboxes()
                end
            end
            lastSwordState = hasSword
        end
    end)
    
    lastSwordState = hasSwordEquipped()
    if lastSwordState and not HitBoxesEnabled then
        enableHitboxes()
    elseif not lastSwordState and HitBoxesEnabled then
        disableHitboxes()
    end
end

local function enableAutoHitbox()
    if autoHitboxEnabled then return end
    autoHitboxEnabled = true
    setupAutoHitboxToggle()
    debugPrint("Auto hitbox toggle enabled", "HITBOX")
end

local function disableAutoHitbox()
    if not autoHitboxEnabled then return end
    autoHitboxEnabled = false
    if hitboxCheckConnection then
        hitboxCheckConnection:Disconnect()
        hitboxCheckConnection = nil
    end
    if storeChangedConnection then
        storeChangedConnection:Disconnect()
        storeChangedConnection = nil
    end
    debugPrint("Auto hitbox toggle disabled", "HITBOX")
end

local UserInputService = game:GetService("UserInputService")
local allFeaturesEnabled = true

local function enableAllFeatures()
    ProjectileAimbotSettings.FOV = Settings.ProjectileAimbotFOV
    ProjectileAimbotSettings.TargetPart = Settings.ProjectileAimbotTargetPart
    ProjectileAimbotSettings.OtherProjectiles = Settings.ProjectileAimbotOtherProjectiles
    ProjectileAimbotSettings.Players = Settings.ProjectileAimbotPlayers
    ProjectileAimbotSettings.Walls = Settings.ProjectileAimbotWalls
    ProjectileAimbotSettings.NPCs = Settings.ProjectileAimbotNPCs
    
    if Settings.ProjectileAimbotEnabled then
        enableProjectileAimbot()
    end
    
    if Settings.KitESPEnabled then
        recreateKitESP()
    end
    if Settings.InstantPPEnabled then
        enableInstantPP()
    end
    
    if Settings.HitBoxesEnabled then
        enableAutoHitbox()
    end
    
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
    disableKitESP()
    disableProjectileAimbot()
    disableInstantPP()
    
    disableAutoHitbox()
    if HitBoxesEnabled then
        disableHitboxes()
    end
    
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

    elseif input.KeyCode == Enum.KeyCode[Settings.HitBoxesEnableKeybind] then
        if not HitBoxesEnabled then
            debugPrint("HitBoxes enable key pressed - Enabling hitboxes", "INPUT")
            enableHitboxes()
            task.spawn(function()
                showNotification("HitBoxes enabled", 2)
            end)
        end

    elseif input.KeyCode == Enum.KeyCode[Settings.HitBoxesDisableKeybind] then
        if HitBoxesEnabled then
            debugPrint("HitBoxes disable key pressed - Disabling hitboxes", "INPUT")
            disableHitboxes()
            task.spawn(function()
                showNotification("HitBoxes disabled", 2)
            end)
        end

    elseif input.KeyCode == Enum.KeyCode[Settings.ProjectileAimbotKeybind] then
        if ProjectileAimbotEnabled then
            debugPrint("ProjectileAimbot key pressed - Disabling projectile aimbot", "INPUT")
            disableProjectileAimbot()
            task.spawn(function()
                showNotification("Projectile Aimbot disabled", 2)
            end)
        else
            debugPrint("ProjectileAimbot key pressed - Enabling projectile aimbot", "INPUT")
            enableProjectileAimbot()
            task.spawn(function()
                showNotification("Projectile Aimbot enabled", 2)
            end)
        end

    elseif input.KeyCode == Enum.KeyCode[Settings.UninjectKeybind] then
        if getgenv().VapeScriptInstances then
            for _, cleanup in pairs(getgenv().VapeScriptInstances) do
                pcall(cleanup)
            end
            getgenv().VapeScriptInstances = nil
        end

        pcall(function()
            if NotificationGui then NotificationGui:Destroy() end
        end)

        if mainInputConnection then
            mainInputConnection:Disconnect()
        end

        pcall(function() entitylib.kill() end)
        pcall(function() script:Destroy() end)
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
    debugPrint("Script fully initialized and ready", "INIT")
end)

addCleanupFunction(function()
    disableAllFeatures()
    disableAutoHitbox()
    table.clear(strafingPatterns)
    table.clear(movementHistory)
    pcall(function()
        if originalFunctions then
            for funcName, original in pairs(originalFunctions) do
                if swordController and swordController[funcName] then
                    swordController[funcName] = original
                end
            end
        end
        if oldCalculateImportantLaunchValues and bedwars and bedwars.ProjectileController then
            pcall(function()
                bedwars.ProjectileController.calculateImportantLaunchValues = oldCalculateImportantLaunchValues
            end)
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
