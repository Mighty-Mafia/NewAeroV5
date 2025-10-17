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

                local results = {solveQuadric(coeffs[0], coeffs[1], coeffs[2])}
                num = #results
                s0, s1 = results[1], results[2]

                coeffs[2] = z + u
                coeffs[1] = q < 0 and v or -v
                coeffs[0] = 1

                if (num == 0) then
                    local results2 = {solveQuadric(coeffs[0], coeffs[1], coeffs[2])}
                    num = num + #results2
                    s0, s1 = results2[1], results2[2]
                end
                if (num == 1) then
                    local results2 = {solveQuadric(coeffs[0], coeffs[1], coeffs[2])}
                    num = num + #results2
                    s1, s2 = results2[1], results2[2]
                end
                if (num == 2) then
                    local results2 = {solveQuadric(coeffs[0], coeffs[1], coeffs[2])}
                    num = num + #results2
                    s2, s3 = results2[1], results2[2]
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
            local origq = q
            for i = 1, 100 do
                q = origq - (.5 * playerGravity) * estTime
                local velo = targetVelocity * 0.016
                local ray = workspace:Raycast(Vector3.new(targetPos.X, targetPos.Y, targetPos.Z), 
                    Vector3.new(velo.X, (q * estTime) - playerHeight, velo.Z), params)
                
                if ray then
                    local newTarget = ray.Position + Vector3.new(0, playerHeight, 0)
                    estTime = estTime - math.sqrt(((targetPos - newTarget).Magnitude * 2) / playerGravity)
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
            posRoots[1] = posRoots[1]

            if posRoots[1] then
                local t = posRoots[1]
                local d = (h + p*t)/t
                local e = (j + q*t - l*t*t)/t
                local f = (k + r*t)/t
                return origin + Vector3.new(d, e, f)
            end
        elseif gravity == 0 then
            local t = (disp.Magnitude / projectileSpeed)
            local d = (h + p*t)/t
            local e = (j + q*t - l*t*t)/t
            local f = (k + r*t)/t
            return origin + Vector3.new(d, e, f)
        end
    end
}

local mainPlayersService = cloneref(game:GetService('Players'))
local mainReplicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local mainRunService = cloneref(game:GetService('RunService'))
local mainInputService = cloneref(game:GetService('UserInputService'))
local mainTweenService = cloneref(game:GetService('TweenService'))
local gameCamera = workspace.CurrentCamera
local collectionService = cloneref(game:GetService('CollectionService'))
local textService = cloneref(game:GetService('TextService'))

repeat task.wait() until game:IsLoaded()

-- Settings (you can change these values)
local Settings = {
    AimAssistAimSpeed = 2.6,
    AimAssistClickAim = true,
    AimAssistDistance = 25,
    AimAssistEnabled = true,
    AimAssistFirstPersonCheck = true,
    AimAssistMaxAngle = 240,
    AimAssistShopCheck = true,
    AimAssistStrafeIncrease = false,
    AimAssistTargetMode = "Distance",
    AimAssistTargetNPCs = false,
    AimAssistTargetPlayers = true,
    AimAssistTargetWalls = false,
    AutoChargeBowEnabled = false,
    AutoClickerBlockCPS = 22,
    AutoClickerCPS = 17,
    AutoClickerEnabled = true,
    AutoClickerMaxBlockCPS = 22,
    AutoClickerMaxCPS = 17,
    AutoClickerPlaceBlocks = true,
    AutoToolEnabled = true,
    DebugMode = true, -- for aero to debug shi
    GUIEnabled = false,
    FastBreakEnabled = true,
    FastBreakSpeed = 0.22,
    HitBoxesDisableKeybind = "X",
    HitBoxesEnableKeybind = "Z",
    HitBoxesEnabled = true,
    HitBoxesExpandAmount = 38,
    HitBoxesMode = "Player", -- "Sword" or "Player"
    HitFixEnabled = true,
    InstantPPEnabled = false,
    KitESPEnabled = true,
    NoFallEnabled = false,
    NoFallMode = "Packet", -- "Packet", "Gravity", "Teleport", "Bounce"
    NoSlowdownEnabled = true,
    ProjectileAimbotEnabled = true,
    ProjectileAimbotFOV = 250,
    ProjectileAimbotKeybind = "Backquote",
    ProjectileAimbotNPCs = false,
    ProjectileAimbotOtherProjectiles = false,
    ProjectileAimbotPlayers = true,
    ProjectileAimbotTargetPart = "RootPart",
    ProjectileAimbotWalls = false,
    StaffDetectorBlacklistClans = true,
    StaffDetectorDebugJoins = false,
    StaffDetectorEnabled = true,
    StaffDetectorLeaveParty = false,
    StaffDetectorMode = "Notify",
    ToggleKeybind = "RightShift",
    UninjectKeybind = "RightAlt",
    VelocityChance = 100,
    VelocityEnabled = true,
    VelocityHorizontal = 78,
    VelocityTargetCheck = false,
    VelocityVertical = 78,
}

pcall(function()
    if mainPlayersService.LocalPlayer.PlayerGui:FindFirstChild("VapeNotifications") then
        mainPlayersService.LocalPlayer.PlayerGui:FindFirstChild("VapeNotifications"):Destroy()
    end
end)

local originalDebugPrint = debugPrint
local joinLogEnabled = true

local function debugPrint(message, level)
    if not Settings.DebugMode and level ~= "PLAYER_JOIN" then return end
    level = level or "INFO"
    local timestamp = os.date("%H:%M:%S")
    
    if message:find("joined the game") or message:find("Player joined:") then
        level = "PLAYER_JOIN"
        print(string.format("[%s] [%s] %s", timestamp, level, message))
        
        if message:find("impossible join") or message:find("Impossible join") then
            showNotification(message:gsub(".*(impossible join.*)", "%1"):gsub(".*(Impossible join.*)", "%1"), 6, "warning")
        end
        return
    end
    
    if Settings.DebugMode then
        print(string.format("[%s] [%s] %s", timestamp, level, message))
    end
end

local joinTracker = {
    playerJoinTimes = {},
    impossibleJoins = {}
}

local function trackPlayerJoin(plr)
    local joinTime = tick()
    joinTracker.playerJoinTimes[plr.UserId] = joinTime
    
    debugPrint(string.format("PLAYER JOIN EVENT: %s (UserId: %d) joined at %s", 
        plr.Name, plr.UserId, os.date("%H:%M:%S", joinTime)), "PLAYER_JOIN")
    
    task.delay(2, function()
        if plr and plr.Parent then
            local isSpectator = plr:GetAttribute('Spectator')
            local hasTeam = plr:GetAttribute('Team')
            local friends = mainPlayersService:GetFriendsAsync(plr.UserId)
            local hasFriendInGame = false
            
            for _, existingPlr in pairs(mainPlayersService:GetPlayers()) do
                if existingPlr ~= plr and existingPlr:IsFriendsWith(plr.UserId) then
                    hasFriendInGame = true
                    break
                end
            end
            
            local impossibleJoin = isSpectator and not hasTeam and not hasFriendInGame
            if impossibleJoin then
                joinTracker.impossibleJoins[plr.UserId] = true
                debugPrint(string.format("IMPOSSIBLE JOIN DETECTED: %s (UserId: %d) - Spectator: %s, Team: %s, FriendInGame: %s", 
                    plr.Name, plr.UserId, tostring(isSpectator), tostring(hasTeam), tostring(hasFriendInGame)), "PLAYER_JOIN")
                
                if Settings.StaffDetectorDebugJoins then
                    showNotification("Staff Detector", string.format("Impossible join: %s", plr.Name), 5, "warning")
                end
            else
                debugPrint(string.format("NORMAL JOIN: %s (UserId: %d) - Spectator: %s, Team: %s, FriendInGame: %s", 
                    plr.Name, plr.UserId, tostring(isSpectator), tostring(hasTeam), tostring(hasFriendInGame)), "PLAYER_JOIN")
                
                if Settings.StaffDetectorDebugJoins then
                    showNotification("Player Join", string.format("Normal join: %s", plr.Name), 3, "normal")
                end
            end
        end
    end)
end

local function enhanceStaffDetector()
    for _, plr in pairs(mainPlayersService:GetPlayers()) do
        trackPlayerJoin(plr)
    end
    
    mainPlayersService.PlayerAdded:Connect(trackPlayerJoin)
end

pcall(function()
    if mainPlayersService.LocalPlayer.PlayerGui:FindFirstChild("VapeNotifications") then
        mainPlayersService.LocalPlayer.PlayerGui:FindFirstChild("VapeNotifications"):Destroy()
    end
end)

local NotificationGui = Instance.new("ScreenGui")
NotificationGui.Name = "VapeNotifications" 
NotificationGui.Parent = mainPlayersService.LocalPlayer.PlayerGui
NotificationGui.ResetOnSpawn = false
NotificationGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local notifications = Instance.new('Folder')
notifications.Name = 'Notifications'
notifications.Parent = NotificationGui

local fontsize = Instance.new('GetTextBoundsParams')
fontsize.Width = math.huge

local uipallet = {
    Main = Color3.fromRGB(26, 25, 26),
    Text = Color3.fromRGB(200, 200, 200),
    Font = Font.fromEnum(Enum.Font.Arial),
    FontSemiBold = Font.fromEnum(Enum.Font.Arial, Enum.FontWeight.SemiBold),
    Tween = TweenInfo.new(0.16, Enum.EasingStyle.Linear)
}

local scale = Instance.new('UIScale')
scale.Scale = math.max(NotificationGui.AbsoluteSize.X / 1920, 0.6)
scale.Parent = NotificationGui

NotificationGui:GetPropertyChangedSignal('AbsoluteSize'):Connect(function()
    scale.Scale = math.max(NotificationGui.AbsoluteSize.X / 1920, 0.6)
end)

notifications.ChildRemoved:Connect(function()
    for i, v in notifications:GetChildren() do
        mainTweenService:Create(v, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {
            Position = UDim2.new(1, 0, 1, -(29 + (78 * i)))
        }):Play()
    end
end)

local function getfontsize(text, size, font)
    fontsize.Text = text
    fontsize.Size = size
    if typeof(font) == 'Font' then
        fontsize.Font = font
    end
    return textService:GetTextBoundsAsync(fontsize)
end

local function removeTags(str)
    str = str:gsub('<br%s*/>', '\n')
    return str:gsub('<[^<>]->', '')
end

addCleanupFunction(function()
    if NotificationGui and NotificationGui.Parent then
        NotificationGui:Destroy()
    end
end)

local function showNotification(title, text, duration, type)
    if not Settings.GUIEnabled then return end
    
    task.delay(0, function()
        local i = #notifications:GetChildren() + 1
        
        local notification = Instance.new('Frame')
        notification.Name = 'Notification'
        notification.Size = UDim2.fromOffset(math.max(getfontsize(removeTags(text), 14, uipallet.Font).X + 60, 250), 75)
        notification.Position = UDim2.new(1, 0, 1, -(20 + (78 * i)))
        notification.ZIndex = 5
        notification.BackgroundColor3 = uipallet.Main
        notification.BackgroundTransparency = 0.1
        notification.BorderSizePixel = 0
        notification.Parent = notifications
        
        local uicorner = Instance.new('UICorner')
        uicorner.CornerRadius = UDim.new(0, 5)
        uicorner.Parent = notification
        
        local blur = Instance.new('ImageLabel')
        blur.Name = 'Blur'
        blur.Size = UDim2.new(1, 89, 1, 52)
        blur.Position = UDim2.fromOffset(-48, -31)
        blur.BackgroundTransparency = 1
        blur.ScaleType = Enum.ScaleType.Slice
        blur.SliceCenter = Rect.new(52, 31, 261, 502)
        blur.Visible = true
        blur.Parent = notification
        
        local titlelabel = Instance.new('TextLabel')
        titlelabel.Name = 'Title'
        titlelabel.Size = UDim2.new(1, -20, 0, 20)
        titlelabel.Position = UDim2.fromOffset(10, 16)
        titlelabel.ZIndex = 6
        titlelabel.BackgroundTransparency = 1
        titlelabel.Text = title
        titlelabel.TextXAlignment = Enum.TextXAlignment.Left
        titlelabel.TextYAlignment = Enum.TextYAlignment.Top
        titlelabel.TextColor3 = type == 'staff' and Color3.fromRGB(255, 120, 120) or 
                               type == 'warning' and Color3.fromRGB(255, 180, 50) or 
                               Color3.fromRGB(220, 220, 220)
        titlelabel.TextSize = 14
        titlelabel.RichText = true
        titlelabel.FontFace = uipallet.FontSemiBold
        titlelabel.TextStrokeTransparency = 0.5
        titlelabel.TextStrokeColor3 = Color3.new(0, 0, 0)
        titlelabel.Parent = notification
        
        local textlabel = Instance.new('TextLabel')
        textlabel.Name = 'Text'
        textlabel.Size = UDim2.new(1, -20, 1, -40)
        textlabel.Position = UDim2.fromOffset(10, 36)
        textlabel.ZIndex = 6
        textlabel.BackgroundTransparency = 1
        textlabel.Text = text
        textlabel.TextXAlignment = Enum.TextXAlignment.Left
        textlabel.TextYAlignment = Enum.TextYAlignment.Top
        textlabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        textlabel.TextTransparency = 0
        textlabel.TextSize = 12
        textlabel.RichText = true
        textlabel.FontFace = uipallet.Font
        textlabel.TextWrapped = true
        textlabel.TextStrokeTransparency = 0.7
        textlabel.TextStrokeColor3 = Color3.new(0, 0, 0)
        textlabel.Parent = notification
        
        local progress = Instance.new('Frame')
        progress.Name = 'Progress'
        progress.Size = UDim2.new(1, -13, 0, 2)
        progress.Position = UDim2.new(0, 3, 1, -4)
        progress.ZIndex = 6
        progress.BackgroundColor3 = 
            type == 'staff' and Color3.fromRGB(250, 50, 56)
            or type == 'warning' and Color3.fromRGB(236, 129, 43)
            or Color3.fromRGB(180, 180, 180)
        progress.BorderSizePixel = 0
        progress.Parent = notification
        
        local progressCorner = Instance.new('UICorner')
        progressCorner.CornerRadius = UDim.new(0, 2)
        progressCorner.Parent = progress
        
        local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad)
        local slideInTween = mainTweenService:Create(notification, tweenInfo, {
            AnchorPoint = Vector2.new(1, 0)
        })
        slideInTween:Play()
        
        local progressTween = mainTweenService:Create(progress, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
            Size = UDim2.fromOffset(0, 2)
        })
        progressTween:Play()
        
        task.delay(duration, function()
            local slideOutTween = mainTweenService:Create(notification, tweenInfo, {
                AnchorPoint = Vector2.new(0, 0)
            })
            slideOutTween:Play()
            
            task.wait(0.3)
            notification:ClearAllChildren()
            notification:Destroy()
        end)
    end)
end

NotificationGui:GetPropertyChangedSignal('AbsoluteSize'):Connect(function()
    scale.Scale = math.max(NotificationGui.AbsoluteSize.X / 1920, 0.6)
end)

notifications.ChildRemoved:Connect(function()
    for i, v in notifications:GetChildren() do
        mainTweenService:Create(v, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {
            Position = UDim2.new(1, 0, 1, -(29 + (78 * i)))
        }):Play()
    end
end)

local staffNotifs = {}
local staffNotificationContainer = nil

local function initStaffNotificationContainer()
    if not staffNotificationContainer then
        staffNotificationContainer = Instance.new("Frame")
        staffNotificationContainer.Name = "StaffNotificationContainer"
        staffNotificationContainer.Size = UDim2.new(0, 300, 1, 0)
        staffNotificationContainer.Position = UDim2.new(1, -320, 0, 20)
        staffNotificationContainer.BackgroundTransparency = 1
        staffNotificationContainer.Parent = NotificationGui
        
        local layout = Instance.new("UIListLayout")
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.VerticalAlignment = Enum.VerticalAlignment.Top
        layout.Padding = UDim.new(0, 8)
        layout.Parent = staffNotificationContainer
    end
end

local function createStaffNotification(message, duration, alertType)
    alertType = alertType or "warning"
    local notifType = alertType == "critical" and "staff" or alertType
    showNotification("STAFF ALERT", message, duration or 8, notifType)
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
    local hasSword = itemMeta and itemMeta.sword ~= nil
    
    return hasSword
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



local function updateStore(new, old)
    if new.Bedwars ~= old.Bedwars then
        store.equippedKit = new.Bedwars.kit ~= 'none' and new.Bedwars.kit or ''
    end

    if new.Game ~= old.Game then
        store.matchState = new.Game.matchState
        store.queueType = new.Game.queueType or 'bedwars_test'
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

        if newinv.inventory.hand ~= oldinv.inventory.hand then
            local currentHand, toolType = newinv.inventory.hand, ''
            if currentHand then
                local handData = bedwars.ItemMeta[currentHand.itemType]
                if handData then
                    toolType = handData.sword and 'sword' or handData.block and 'block' or currentHand.itemType:find('bow') and 'bow' or ''
                end
            end

            store.hand = {
                tool = currentHand and currentHand.tool,
                amount = currentHand and currentHand.amount or 0,
                toolType = toolType
            }
            
            debugPrint("Store hand updated - toolType: " .. toolType .. ", itemType: " .. (currentHand and currentHand.itemType or "none"), "DEBUG")
        end
    end
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

        pcall(function()
            bedwars.AppController = knit.Controllers.AppController or require(mainReplicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out.client.controllers['app-controller']).AppController
            bedwars.UILayers = require(mainReplicatedStorage['rbxts_include']['node_modules']['@easy-games']['game-core'].out).UILayers
            bedwars.BlockPlacementController = knit.Controllers.BlockPlacementController
            bedwars.BlockCpsController = knit.Controllers.BlockCpsController
            debugPrint("Additional bedwars components loaded for AutoClicker", "SUCCESS")
        end)

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

local function getPingCompensation()
    local ping = 0
    pcall(function()
        local stats = game:GetService("Stats")
        ping = stats.Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    
    if ping < 50 then
        return 1.0  
    elseif ping < 100 then
        return 1.2  
    elseif ping < 200 then
        return 1.5  
    else
        return 2.0
    end
end

local function hookClientGet()
    if not bedwars.Client or OldGet then return end
    
    OldGet = bedwars.Client.Get
    bedwars.Client.Get = function(self, remoteName)
        local call = OldGet(self, remoteName)
        
        if remoteName == (remotes and remotes.AttackEntity or "AttackEntity") then
            return {
                instance = call.instance,
                SendToServer = function(_, attackTable, ...)
                    if attackTable and attackTable.validate and HitFixEnabled then
                        local selfpos = attackTable.validate.selfPosition and attackTable.validate.selfPosition.value
                        local targetpos = attackTable.validate.targetPosition and attackTable.validate.targetPosition.value
                        
                        if selfpos and targetpos then
                            store.attackReach = ((selfpos - targetpos).Magnitude * 100) // 1 / 100
                            store.attackReachUpdate = tick() + 1
                            
                            local distance = (selfpos - targetpos).Magnitude
                            local pingCompensation = 0
                            
                            pcall(function()
                                local stats = game:GetService("Stats")
                                local ping = stats.Network.ServerStatsItem["Data Ping"]:GetValue()
                                pingCompensation = math.min(ping / 1000 * 50, 8) 
                            end)
                            
                            local adjustmentDistance = math.max(distance - 12, 0) + pingCompensation
                            
                            if adjustmentDistance > 0 then
                                attackTable.validate.raycast = attackTable.validate.raycast or {}
                                local direction = CFrame.lookAt(selfpos, targetpos).LookVector
                                attackTable.validate.selfPosition.value = selfpos + (direction * adjustmentDistance)
                                
                                if pingCompensation > 2 then
                                    attackTable.validate.targetPosition.value = targetpos - (direction * math.min(pingCompensation * 0.3, 2))
                                end
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
local REACH_DISTANCE = 17
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
                    local pingMultiplier = getPingCompensation()
                    local additionalReach = 2 * pingMultiplier
                    bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = 18 + math.min(additionalReach, 6) 
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

local autoHitboxEnabled = false
local lastSwordState = false
local hitboxCheckConnection = nil

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
        end)
    end
end

local function removeHitbox(ent)
    if hitboxObjects[ent] then
        hitboxObjects[ent]:Destroy()
        hitboxObjects[ent] = nil
    end
end

local function applySwordHitbox(enabled)
    if not bedwarsLoaded or not bedwars or not bedwars.SwordController then
        return false
    end
    
    if not bedwars.SwordController.swingSwordInRegion then
        return false
    end
    
    local success, errorMsg = pcall(function()
        if enabled then
            debug.setconstant(bedwars.SwordController.swingSwordInRegion, 6, (Settings.HitBoxesExpandAmount / 3))
            hitboxSet = true
        else
            debug.setconstant(bedwars.SwordController.swingSwordInRegion, 6, 3.8)
            hitboxSet = nil
        end
    end)
    
    return success
end

local function updatePlayerHitboxes()
    for ent, part in pairs(hitboxObjects) do
        if part and part.Parent then
            part.Size = Vector3.new(3, 6, 3) + Vector3.one * (Settings.HitBoxesExpandAmount / 5)
        end
    end
end

local function enableHitboxes()
    if not entitylib.Running then
        entitylib.start()
    end
    
    if Settings.HitBoxesMode == 'Sword' then
        local success = applySwordHitbox(true)
        if success then
            HitBoxesEnabled = true
            if hasSwordEquipped() then
                showNotification("HitBoxes", "HitBoxes enabled (Sword detected)", 2, "normal")
            else
                showNotification("HitBoxes", "HitBoxes enabled", 2, "normal")
            end
            return true
        else
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
        return true
    end
end

local function disableHitboxes()
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
    end
    
    for _, conn in pairs(hitboxConnections) do
        pcall(function() conn:Disconnect() end)
    end
    hitboxConnections = {}
    
    HitBoxesEnabled = false
    return true
end

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
                    showNotification("Auto HitBox", "HitBoxes auto-enabled (Sword equipped)", 2, "normal")
                end
            else
                if HitBoxesEnabled then
                    disableHitboxes()
                    showNotification("Auto HitBox", "HitBoxes auto-disabled (No sword)", 2, "normal")
                end
            end
            lastSwordState = hasSword
        end
    end)
    
    lastSwordState = hasSwordEquipped()
    
    if lastSwordState and not HitBoxesEnabled then
        enableHitboxes()
        showNotification("Auto HitBox", "HitBoxes auto-enabled (Sword equipped)", 2, "normal")
    elseif not lastSwordState and HitBoxesEnabled then
        disableHitboxes()
        showNotification("Auto HitBox", "HitBoxes auto-disabled (No sword)", 2, "normal")
    end
end

local function enableAutoHitbox()
    if autoHitboxEnabled then return end
    autoHitboxEnabled = true
    showNotification("Auto HitBox", "Auto HitBox system enabled", 2, "normal")
    setupAutoHitboxToggle()
end

local function disableAutoHitbox()
    if not autoHitboxEnabled then return end
    autoHitboxEnabled = false
    if hitboxCheckConnection then
        hitboxCheckConnection:Disconnect()
        hitboxCheckConnection = nil
    end
end

local function updateHitboxSettings()
    if HitBoxesEnabled then
        if Settings.HitBoxesMode == 'Sword' and hitboxSet then
            applySwordHitbox(true) 
        elseif Settings.HitBoxesMode == 'Player' then
            updatePlayerHitboxes()
        end
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
    if not bedwarsLoaded then
        return false
    end
    
    if not bedwars.KnockbackUtil then
        return false
    end
    
    local success = pcall(function()
        if not velocityOld then
            velocityOld = bedwars.KnockbackUtil.applyKnockback
        end
        
        bedwars.KnockbackUtil.applyKnockback = function(root, mass, dir, knockback, ...)
            local chanceRoll = rand:NextNumber(0, 100)
            
            if chanceRoll > Velocity.Chance.Value then 
                return velocityOld(root, mass, dir, knockback, ...)
            end
            
            local check = (not Velocity.TargetCheck.Enabled) or entityPosition({
                Range = 50,
                Part = 'RootPart',
                Players = true
            })

            if check then
                knockback = knockback or {}
                local originalH = knockback.horizontal or 1
                local originalV = knockback.vertical or 1
                
                if Velocity.Horizontal.Value == 0 and Velocity.Vertical.Value == 0 then 
                    return 
                end
                
                knockback.horizontal = originalH * (Velocity.Horizontal.Value / 100)
                knockback.vertical = originalV * (Velocity.Vertical.Value / 100)
            end
            
            return velocityOld(root, mass, dir, knockback, ...)
        end
        
        Velocity.Enabled = true
        debugPrint("Velocity enabled", "VELOCITY")
    end)
    
    return success
end

local function disableVelocity()
    if not bedwarsLoaded then
        return false
    end
    
    if not bedwars.KnockbackUtil then
        return false
    end
    
    local success = pcall(function()
        if velocityOld then
            bedwars.KnockbackUtil.applyKnockback = velocityOld
            velocityOld = nil
            Velocity.Enabled = false
            debugPrint("Velocity disabled and restored to original", "VELOCITY")
        else
            debugPrint("Velocity: No original function found to restore", "VELOCITY")
        end
    end)
    
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
        else
            return false
        end
    end)
    
    return success
end

local function disableFastBreak()
    if not FastBreakEnabled then return false end
    
    FastBreakEnabled = false
    
    if fastBreakLoop then
        task.cancel(fastBreakLoop)
        fastBreakLoop = nil
    end
    
    local success = pcall(function()
        if bedwars.BlockBreakController and bedwars.BlockBreakController.blockBreaker and bedwars.BlockBreakController.blockBreaker.setCooldown then
            bedwars.BlockBreakController.blockBreaker:setCooldown(0.3)
        end
    end)
    
    return success
end

local AimAssistEnabled = false
local aimAssistConnection = nil

local AutoClickerEnabled = false
local autoClickerThread = nil
local autoClickerConnections = {}
local rand = Random.new()

local AutoClicker = {
    Enabled = Settings.AutoClickerEnabled
}
local CPS = {
    GetRandomValue = function()
        return rand:NextNumber(Settings.AutoClickerCPS, Settings.AutoClickerMaxCPS)
    end
}
local BlockCPS = {
    GetRandomValue = function()
        return rand:NextNumber(Settings.AutoClickerBlockCPS, Settings.AutoClickerMaxBlockCPS)
    end
}

local sortmethods = {
    Damage = function(a, b)
        return a.Health < b.Health
    end,
    Distance = function(a, b)
        return (a.RootPart.Position - entitylib.character.RootPart.Position).Magnitude < 
               (b.RootPart.Position - entitylib.character.RootPart.Position).Magnitude
    end,
    Angle = function(a, b)
        local selfrootpos = entitylib.character.RootPart.Position
        local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
        local angle = math.acos(localfacing:Dot(((a.RootPart.Position - selfrootpos) * Vector3.new(1, 0, 1)).Unit))
        local angle2 = math.acos(localfacing:Dot(((b.RootPart.Position - selfrootpos) * Vector3.new(1, 0, 1)).Unit))
        return angle < angle2
    end
}

local function isFirstPerson()
    if not (lplr.Character and lplr.Character:FindFirstChild("Head")) then return nil end
    return (lplr.Character.Head.Position - gameCamera.CFrame.Position).Magnitude < 2
end

local function enableAimAssist()
    if AimAssistEnabled or not bedwarsLoaded then return false end
    
    local success = pcall(function()
        AimAssistEnabled = true
        
        aimAssistConnection = mainRunService.Heartbeat:Connect(function(dt)
            if not entitylib.isAlive then return end
            
            if store and store.hand and store.hand.toolType == 'block' then
                return
            end
            
            if not (store and store.hand and store.hand.toolType == 'sword') then
                return
            end
            
            if Settings.AimAssistFirstPersonCheck then
                if not isFirstPerson() then 
                    return 
                end
            end
            
            if Settings.AimAssistShopCheck then
                local isShop = lplr:FindFirstChild("PlayerGui") and lplr:FindFirstChild("PlayerGui"):FindFirstChild("ItemShop") or nil
                if isShop then 
                    return 
                end
            end
            
            if Settings.AimAssistClickAim then
                local timeSinceLastSwing = tick() - (bedwars.SwordController.lastSwing or 0)
                if timeSinceLastSwing > 0.4 then 
                    return 
                end
            end
            
            local target = nil
            local targetsList = {}
            
            for _, entity in pairs(entitylib.List) do
                if not entity.Targetable then continue end
                if not Settings.AimAssistTargetPlayers and entity.Player then continue end
                if not Settings.AimAssistTargetNPCs and entity.NPC then continue end
                if not entitylib.isVulnerable(entity) then continue end
                
                local distance = (entity.RootPart.Position - entitylib.character.RootPart.Position).Magnitude
                if distance > Settings.AimAssistDistance then continue end
                
                if Settings.AimAssistTargetWalls then
                    local raycastParams = RaycastParams.new()
                    raycastParams.FilterDescendantsInstances = {lplr.Character, entity.Character}
                    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
                    
                    local ray = workspace:Raycast(
                        entitylib.character.RootPart.Position,
                        (entity.RootPart.Position - entitylib.character.RootPart.Position),
                        raycastParams
                    )
                    
                    if ray and ray.Instance and not ray.Instance:IsDescendantOf(entity.Character) then
                        continue
                    end
                end
                
                table.insert(targetsList, entity)
            end
            
            if Settings.AimAssistTargetMode == "Damage" then
                table.sort(targetsList, sortmethods.Damage)
            elseif Settings.AimAssistTargetMode == "Angle" then
                table.sort(targetsList, sortmethods.Angle)
            else
                table.sort(targetsList, sortmethods.Distance)
            end
            
            if #targetsList > 0 then
                target = targetsList[1]
            end
            
            if target then
                local delta = (target.RootPart.Position - entitylib.character.RootPart.Position)
                local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
                local angle = math.acos(localfacing:Dot((delta * Vector3.new(1, 0, 1)).Unit))
                
                if angle >= (math.rad(Settings.AimAssistMaxAngle) / 2) then 
                    return 
                end
                
                local aimSpeed = Settings.AimAssistAimSpeed
                if Settings.AimAssistStrafeIncrease and (mainInputService:IsKeyDown(Enum.KeyCode.A) or mainInputService:IsKeyDown(Enum.KeyCode.D)) then
                    aimSpeed = aimSpeed + 10
                end
                
                gameCamera.CFrame = gameCamera.CFrame:Lerp(
                    CFrame.lookAt(gameCamera.CFrame.p, target.RootPart.Position), 
                    aimSpeed * dt
                )
            end
            
            table.clear(targetsList)
        end)
    end)
    
    return success
end

local function disableAimAssist()
    if not AimAssistEnabled then return false end
    
    AimAssistEnabled = false
    
    if aimAssistConnection then
        aimAssistConnection:Disconnect()
        aimAssistConnection = nil
    end
    
    return true
end

local function enableAutoClicker()
    if AutoClickerEnabled or not bedwarsLoaded then return false end
    
    local Thread = nil
    
    local function AutoClick()
        if Thread then
            task.cancel(Thread)
        end

        Thread = task.delay(1 / 7, function()
            repeat
                if not bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then
                    local blockPlacer = bedwars.BlockPlacementController.blockPlacer
                    if store.hand.toolType == 'block' and blockPlacer then
                        if (workspace:GetServerTimeNow() - bedwars.BlockCpsController.lastPlaceTimestamp) >= ((1 / 12) * 0.5) then
                            local mouseinfo = blockPlacer.clientManager:getBlockSelector():getMouseInfo(0)
                            if mouseinfo and mouseinfo.placementPosition == mouseinfo.placementPosition then
                                task.spawn(blockPlacer.placeBlock, blockPlacer, mouseinfo.placementPosition)
                            end
                        end
                    elseif store.hand.toolType == 'sword' then
                        bedwars.SwordController:swingSwordAtMouse()
                    end
                end

                task.wait(1 / (store.hand.toolType == 'block' and BlockCPS or CPS).GetRandomValue())
            until not AutoClickerEnabled
        end)
    end
    
    local success = pcall(function()
        table.insert(autoClickerConnections, mainInputService.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                AutoClick()
            end
        end))

        table.insert(autoClickerConnections, mainInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 and Thread then
                task.cancel(Thread)
                Thread = nil
            end
        end))

        if mainInputService.TouchEnabled then
            pcall(function()
                table.insert(autoClickerConnections, lplr.PlayerGui.MobileUI['2'].MouseButton1Down:Connect(AutoClick))
                table.insert(autoClickerConnections, lplr.PlayerGui.MobileUI['2'].MouseButton1Up:Connect(function()
                    if Thread then
                        task.cancel(Thread)
                        Thread = nil
                    end
                end))
            end)
        end
        
        AutoClickerEnabled = true
    end)
    
    return success
end

local function disableAutoClicker()
    if not AutoClickerEnabled then return false end
    
    AutoClickerEnabled = false
    
    if autoClickerThread then
        task.cancel(autoClickerThread)
        autoClickerThread = nil
    end
    
    for _, conn in pairs(autoClickerConnections) do
        pcall(function() conn:Disconnect() end)
    end
    autoClickerConnections = {}
    
    return true
end

local function enableNoFall()
    if NoFallEnabled or not bedwarsLoaded then return false end
    
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
                            end
                        end
                    end)
                    if not groundHit then
                        pcall(function()
                            if knit and knit.Controllers and knit.Controllers.FallDamageController then
                                groundHit = knit.Controllers.FallDamageController.KnitStart
                            end
                        end)
                    end
                    if groundHit then break end
                    task.wait(0.1)
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
                            else
                                rayParams.FilterDescendantsInstances = {lplr.Character, gameCamera}
                                rayParams.CollisionGroup = root.CollisionGroup

                                local rootSize = root.Size.Y / 2 + entitylib.character.HipHeight
                                if Settings.NoFallMode == 'Teleport' then
                                    local ray = workspace:Blockcast(root.CFrame, Vector3.new(3, 3, 3), Vector3.new(0, -1000, 0), rayParams)
                                    if ray then
                                        root.CFrame -= Vector3.new(0, root.Position.Y - (ray.Position.Y + rootSize), 0)
                                    end
                                else 
                                    local ray = workspace:Blockcast(root.CFrame, Vector3.new(3, 3, 3), Vector3.new(0, (tracked * 0.1) - rootSize, 0), rayParams)
                                    if ray then
                                        tracked = 0
                                        root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, -80, root.AssemblyLinearVelocity.Z)
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
    end)
    
    return success
end

local function disableNoFall()
    if not NoFallEnabled then return false end
    
    NoFallEnabled = false
    
    for _, conn in pairs(noFallConnections) do
        pcall(function() conn:Disconnect() end)
    end
    noFallConnections = {}
    
    return true
end

local function enableNoSlowdown()
    if NoSlowdownEnabled or not bedwarsLoaded then return false end
    
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
            else
                return false
            end
        else
            return false
        end
    end)
    
    return success
end

local function disableNoSlowdown()
    if not NoSlowdownEnabled or not bedwarsLoaded then return false end
    
    local success = pcall(function()
        if bedwars.SprintController and oldSlowdown then
            local modifier = bedwars.SprintController:getMovementStatusModifier()
            if modifier then
                modifier.addModifier = oldSlowdown
                oldSlowdown = nil
                NoSlowdownEnabled = false
            end
        end
    end)
    
    return success
end

local movementHistory = {}

local function predictStrafingMovement(targetPlayer, targetPart, projSpeed, gravity, origin)
    if not targetPlayer or not targetPlayer.Character or not targetPart then 
        return targetPart and targetPart.Position or Vector3.zero
    end
    
    local currentPos = targetPart.Position
    local currentVel = targetPart.Velocity
    local distance = (currentPos - origin).Magnitude
    
    local baseTimeToTarget = distance / projSpeed
    local velocityMagnitude = Vector3.new(currentVel.X, 0, currentVel.Z).Magnitude
    local verticalVel = currentVel.Y
    
    local timeMultiplier = 1.0
    if distance > 80 then
        timeMultiplier = 0.95
    elseif distance > 50 then
        timeMultiplier = 0.98
    elseif distance < 20 then
        timeMultiplier = 1.08
    end
    
    local timeToTarget = baseTimeToTarget * timeMultiplier
    
    local horizontalPredictionStrength = 0.80
    if distance > 70 then
        horizontalPredictionStrength = 0.70
    elseif distance > 40 then
        horizontalPredictionStrength = 0.75
    elseif distance < 25 then
        horizontalPredictionStrength = 0.88
    end
    
    local horizontalVel = Vector3.new(currentVel.X, 0, currentVel.Z)
    local predictedHorizontal = horizontalVel * timeToTarget * horizontalPredictionStrength
    
    local verticalPrediction = 0
    local isJumping = verticalVel > 10
    local isFalling = verticalVel < -15
    local isPeaking = math.abs(verticalVel) < 3 and verticalVel < 1
    
    if isFalling then
        verticalPrediction = verticalVel * timeToTarget * 0.32
    elseif isJumping then
        verticalPrediction = verticalVel * timeToTarget * 0.28
    elseif isPeaking then
        verticalPrediction = -2 * timeToTarget
    else
        verticalPrediction = verticalVel * timeToTarget * 0.25
    end
    
    local finalPosition = currentPos + predictedHorizontal + Vector3.new(0, verticalPrediction, 0)
    
    return finalPosition
end

local function smoothAim(currentCFrame, targetPosition, distance)
    local smoothnessFactor = 0.85
    
    if distance > 70 then
        smoothnessFactor = 0.75
    elseif distance > 40 then
        smoothnessFactor = 0.80
    elseif distance < 20 then
        smoothnessFactor = 0.92
    end
    
    return currentCFrame:Lerp(CFrame.new(currentCFrame.Position, targetPosition), smoothnessFactor)
end

local function enableProjectileAimbot()
    if ProjectileAimbotEnabled or not bedwarsLoaded or not bedwars.ProjectileController then
        return false
    end

    local success = pcall(function()
        if not oldCalculateImportantLaunchValues then
            oldCalculateImportantLaunchValues = bedwars.ProjectileController.calculateImportantLaunchValues
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
                    local gravityMultiplier = 1 - (balloons * 0.05)
                    playerGravity = workspace.Gravity * math.max(gravityMultiplier, 0.7)
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
                local distance = (plr[ProjectileAimbotSettings.TargetPart].Position - offsetpos).Magnitude
                
                local predictedPosition = predictStrafingMovement(
                    plr.Player, 
                    plr[ProjectileAimbotSettings.TargetPart], 
                    projSpeed, 
                    gravity,
                    offsetpos
                )

                local newlook = smoothAim(rawLook, predictedPosition, distance)

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
                    plr.Jumping and 50 or nil,
                    rayCheck
                )

                if calc then
                    local finalDirection = (calc - newlook.p).Unit
                    local angleFromHorizontal = math.acos(math.clamp(finalDirection:Dot(Vector3.new(0, 1, 0)), -1, 1))
                    
                    local minAngle = math.rad(1)
                    local maxAngle = math.rad(179)
                    
                    if angleFromHorizontal > minAngle and angleFromHorizontal < maxAngle then
                        return {
                            initialVelocity = finalDirection * projSpeed,
                            positionFrom = offsetpos,
                            deltaT = lifetime,
                            gravitationalAcceleration = gravity,
                            drawDurationSeconds = 5
                        }
                    end
                end
            end

            return oldCalculateImportantLaunchValues(...)
        end

        ProjectileAimbotEnabled = true
    end)

    return success
end

local function disableProjectileAimbot()
    if not ProjectileAimbotEnabled or not bedwarsLoaded or not bedwars.ProjectileController then 
        return false 
    end
    
    local success = pcall(function()
        if oldCalculateImportantLaunchValues then
            bedwars.ProjectileController.calculateImportantLaunchValues = oldCalculateImportantLaunchValues
            oldCalculateImportantLaunchValues = nil
            ProjectileAimbotEnabled = false
        end
    end)
    
    return success
end

local UserInputService = game:GetService("UserInputService")
local allFeaturesEnabled = true

local StaffDetector = {
    Enabled = false,
    blacklistedClans = {'gg', 'gg2', 'DV', 'DV2'},
    blacklistedUserIds = {1502104539, 3826146717, 4531785383, 1049767300, 4926350670, 653085195, 184655415, 2752307430, 5087196317, 5744061325, 1536265275},
    joinedPlayers = {},
    connections = {}
}

local function getPlayerRank(plr, groupId)
    local success, result = pcall(function()
        return plr:GetRankInGroup(groupId)
    end)
    if not success then
        debugPrint("StaffDetector: Failed to get rank for " .. plr.Name .. " - " .. tostring(result), "STAFFDETECTOR")
    end
    return success and result or 0
end

local function staffDetected(plr, checkType)
    debugPrint(string.format("StaffDetector: %s detected (%s) - UserId: %d", plr.Name, checkType, plr.UserId), "STAFFDETECTOR")
    
    local alertLevel = "critical"
    if checkType:find("clan") then
        alertLevel = "alert"
    elseif checkType:find("impossible") then
        alertLevel = "warning"
    end
    
    createStaffNotification(
        "STAFF DETECTED (" .. checkType .. "): " .. plr.Name .. " (" .. plr.UserId .. ")",
        10,
        alertLevel
    )
    
    if Settings.StaffDetectorLeaveParty and bedwars and bedwars.PartyController then
        pcall(function()
            bedwars.PartyController:leaveParty()
            debugPrint("StaffDetector: Left party due to staff detection", "STAFFDETECTOR")
        end)
    end
    
    if Settings.StaffDetectorMode == "Notify" then
        return
    end
end

local function checkFriendsList(plr)
    local friendList = {}
    local success, pages = pcall(function()
        return mainPlayersService:GetFriendsAsync(plr.UserId)
    end)
    
    if not success then return friendList end
    
    for _ = 1, 3 do 
        for _, friend in pairs(pages:GetCurrentPage()) do
            table.insert(friendList, friend.Id)
        end
        if pages.IsFinished then break end
        pcall(function() pages:AdvanceToNextPageAsync() end)
    end
    
    return friendList
end

local function checkImpossibleJoin(plr, connection)
    if not plr:GetAttribute('Team') and plr:GetAttribute('Spectator') then
        if connection then
            connection:Disconnect()
        end
        
        local friendList = checkFriendsList(plr)
        local joinedFromFriend = nil
        
        for _, friendId in ipairs(friendList) do
            if StaffDetector.joinedPlayers[friendId] then
                joinedFromFriend = StaffDetector.joinedPlayers[friendId]
                break
            end
        end
        
        if not joinedFromFriend then
            staffDetected(plr, 'impossible_join')
            return true
        else
            debugPrint(string.format("StaffDetector: Spectator %s joined from %s", plr.Name, joinedFromFriend), "STAFFDETECTOR")
            if Settings.StaffDetectorDebugJoins then
                createStaffNotification(
                    string.format("Spectator %s joined from %s", plr.Name, joinedFromFriend),
                    5,
                    "warning"
                )
            end
        end
    end
    return false
end

local function onPlayerAdded(plr)
    StaffDetector.joinedPlayers[plr.UserId] = plr.Name
    
    trackPlayerJoin(plr)
    
    if Settings.StaffDetectorDebugJoins then
        debugPrint(string.format("StaffDetector tracking: %s (UserId: %d)", plr.Name, plr.UserId), "STAFFDETECTOR")
    end
    
    if plr == lplr then return end
    
    if table.find(StaffDetector.blacklistedUserIds, plr.UserId) then
        staffDetected(plr, 'blacklisted_user')
        return
    end
    
    local staffRank = getPlayerRank(plr, 5774246)
    if staffRank >= 100 then
        staffDetected(plr, 'staff_role')
        return
    end
    
    local connection
    connection = plr:GetAttributeChangedSignal('Spectator'):Connect(function()
        if checkImpossibleJoin(plr, connection) then
            return
        end
    end)
    
    table.insert(StaffDetector.connections, connection)
    
    if checkImpossibleJoin(plr, connection) then
        return
    end
    
    if not plr:GetAttribute('ClanTag') then
        local clanConnection
        clanConnection = plr:GetAttributeChangedSignal('ClanTag'):Connect(function()
            if clanConnection then
                clanConnection:Disconnect()
            end
            if Settings.StaffDetectorBlacklistClans and table.find(StaffDetector.blacklistedClans, plr:GetAttribute('ClanTag')) then
                staffDetected(plr, 'blacklisted_clan_' .. (plr:GetAttribute('ClanTag') or 'unknown'):lower())
            end
        end)
        table.insert(StaffDetector.connections, clanConnection)
    else
        if Settings.StaffDetectorBlacklistClans and table.find(StaffDetector.blacklistedClans, plr:GetAttribute('ClanTag')) then
            staffDetected(plr, 'blacklisted_clan_' .. (plr:GetAttribute('ClanTag') or 'unknown'):lower())
        end
    end
end

local function onPlayerRemoving(plr)
    StaffDetector.joinedPlayers[plr.UserId] = nil
end

local function enableStaffDetector()
    if StaffDetector.Enabled then return end
    
    debugPrint("StaffDetector: Enabling...", "STAFFDETECTOR")
    
    table.clear(StaffDetector.joinedPlayers)
    for _, conn in pairs(StaffDetector.connections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(StaffDetector.connections)
    
    table.insert(StaffDetector.connections, mainPlayersService.PlayerAdded:Connect(onPlayerAdded))
    table.insert(StaffDetector.connections, mainPlayersService.PlayerRemoving:Connect(onPlayerRemoving))
    
    for _, plr in pairs(mainPlayersService:GetPlayers()) do
        task.spawn(onPlayerAdded, plr)
    end
    
    StaffDetector.Enabled = true
    debugPrint("StaffDetector: Enabled successfully", "STAFFDETECTOR")
    createStaffNotification("Staff Detector Enabled", 3, "warning")
end

local function disableStaffDetector()
    if not StaffDetector.Enabled then return end
    
    debugPrint("StaffDetector: Disabling...", "STAFFDETECTOR")
    
    for _, conn in pairs(StaffDetector.connections) do
        pcall(function() conn:Disconnect() end)
    end
    table.clear(StaffDetector.connections)
    table.clear(StaffDetector.joinedPlayers)
    
    StaffDetector.Enabled = false
    debugPrint("StaffDetector: Disabled", "STAFFDETECTOR")
end


local function enableAllFeatures()
    debugPrint("Enabling all features", "FEATURES")
    
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
    if Settings.AimAssistEnabled then
        enableAimAssist()
    end
    if Settings.AutoClickerEnabled then
        enableAutoClicker()
    end
    if Settings.StaffDetectorEnabled then
        enableStaffDetector()
    end
    allFeaturesEnabled = true
    debugPrint("All features enabled", "FEATURES")
end

local function disableAllFeatures()
    debugPrint("Disabling all features", "FEATURES")
    
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
    disableAimAssist()
    disableAutoClicker()
    disableStaffDetector()
    
    allFeaturesEnabled = false
    debugPrint("All features disabled", "FEATURES")
    
    task.spawn(function()
        showNotification("Script Status", "Script disabled. Press RightShift to re-enable.", 3, "normal")
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
                showNotification("Script Status", "Script enabled. Press RightShift to disable.", 3, "normal")
            end)
        end

    elseif input.KeyCode == Enum.KeyCode[Settings.HitBoxesEnableKeybind] then
        if not HitBoxesEnabled then
            debugPrint("HitBoxes enable key pressed - Enabling hitboxes", "INPUT")
            enableHitboxes()
            task.spawn(function()
                showNotification("HitBoxes", "HitBoxes enabled", 2, "normal")
            end)
        end

    elseif input.KeyCode == Enum.KeyCode[Settings.HitBoxesDisableKeybind] then
        if HitBoxesEnabled then
            debugPrint("HitBoxes disable key pressed - Disabling hitboxes", "INPUT")
            disableHitboxes()
            task.spawn(function()
                showNotification("HitBoxes", "HitBoxes disabled", 2, "normal")
            end)
        end

    elseif input.KeyCode == Enum.KeyCode[Settings.ProjectileAimbotKeybind] then
        if ProjectileAimbotEnabled then
            debugPrint("ProjectileAimbot key pressed - Disabling projectile aimbot", "INPUT")
            disableProjectileAimbot()
            task.spawn(function()
                showNotification("Projectile Aimbot", "Projectile Aimbot disabled", 2, "normal")
            end)
        else
            debugPrint("ProjectileAimbot key pressed - Enabling projectile aimbot", "INPUT")
            enableProjectileAimbot()
            task.spawn(function()
                showNotification("Projectile Aimbot", "Projectile Aimbot enabled", 2, "normal")
            end)
        end

    elseif input.KeyCode == Enum.KeyCode[Settings.UninjectKeybind] then
        debugPrint("Uninject key pressed - Running full cleanup", "UNINJECT")
        
        disableAllFeatures()
        
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
        
        debugPrint("Script fully uninjected", "UNINJECT")
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
    showNotification("Script Loaded", statusMsg, 4, "normal")
    debugPrint("Script fully initialized and ready", "INIT")
end)

addCleanupFunction(function()
    debugPrint("Running full cleanup", "CLEANUP")
    
    if NotificationGui and NotificationGui.Parent then
        NotificationGui:Destroy()
    end
    table.clear(staffNotifs)
    
    disableAllFeatures()
    
    table.clear(movementHistory)
    
    pcall(function()
        if originalFunctions then
            for funcName, original in pairs(originalFunctions) do
                if swordController and swordController[funcName] then
                    swordController[funcName] = original
                end
            end
            table.clear(originalFunctions)
        end
        if oldCalculateImportantLaunchValues and bedwars and bedwars.ProjectileController then
            pcall(function()
                bedwars.ProjectileController.calculateImportantLaunchValues = oldCalculateImportantLaunchValues
                oldCalculateImportantLaunchValues = nil
            end)
        end
        if originalReachDistance ~= nil and bedwars and bedwars.CombatConstant then
            bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = originalReachDistance
            originalReachDistance = nil
        end
        if OldGet and bedwars.Client then
            bedwars.Client.Get = OldGet
            OldGet = nil
        end
        if oldHitBlock and bedwars.BlockBreaker then
            bedwars.BlockBreaker.hitBlock = oldHitBlock
            oldHitBlock = nil
        end
        if velocityOld and bedwars.KnockbackUtil then
            bedwars.KnockbackUtil.applyKnockback = velocityOld
            velocityOld = nil
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
        if AimAssistEnabled then
            disableAimAssist()
        end
        if aimAssistConnection then
            aimAssistConnection:Disconnect()
            aimAssistConnection = nil
        end
        for ent, part in pairs(hitboxObjects) do
            if part and part.Parent then
                part:Destroy()
            end
        end
        table.clear(hitboxObjects)
        if hitboxSet then
            applySwordHitbox(false)
            hitboxSet = nil
        end
        for _, conn in pairs(hitboxConnections) do
            pcall(function() conn:Disconnect() end)
        end
        table.clear(hitboxConnections)
        
        if sprintConnection then
            sprintConnection:Disconnect()
            sprintConnection = nil
        end
        if hitboxCheckConnection then
            hitboxCheckConnection:Disconnect()
            hitboxCheckConnection = nil
        end
        for _, conn in pairs(autoToolConnections) do
            pcall(function() conn:Disconnect() end)
        end
        table.clear(autoToolConnections)
        for _, conn in pairs(autoClickerConnections) do
            pcall(function() conn:Disconnect() end)
        end
        table.clear(autoClickerConnections)
        for _, conn in pairs(kitESPConnections) do
            pcall(function() conn:Disconnect() end)
        end
        table.clear(kitESPConnections)
        for _, conn in pairs(StaffDetector.connections) do
            pcall(function() conn:Disconnect() end)
        end
        table.clear(StaffDetector.connections)
        if InstantPPConnection then
            InstantPPConnection:Disconnect()
            InstantPPConnection = nil
        end
    end)
    
    debugPrint("Full cleanup completed", "CLEANUP")
end)
