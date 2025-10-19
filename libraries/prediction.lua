local module = {}

local movementHistory = {}

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
	if num > 0 then s0 = s0 - sub end
	if num > 1 then s1 = s1 - sub end
	if num > 2 then s2 = s2 - sub end

	return s0, s1, s2
end

function module.solveQuartic(c0, c1, c2, c3, c4)
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

function module.SolveTrajectory(origin, projectileSpeed, gravity, targetPos, targetVelocity, playerGravity, playerHeight, playerJump, params)
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

	local solutions = module.solveQuartic(
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

function module.predictStrafingMovement(targetPlayer, targetPart, projSpeed, gravity, origin)
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

function module.smoothAim(currentCFrame, targetPosition, distance)
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

module.movementHistory = movementHistory

return module
