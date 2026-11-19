--[[
	W-Nickz Hub · Cash Generator Edition
	Cash Generator integrado na tab "Cash".
]]

--// Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Library
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/lxte/lates-lib/main/Main.lua"))()
local Window = Library:CreateWindow({
	Title = "W-Nickz Hub",
	Theme = "Dark",
	Size = UDim2.fromOffset(570, 370),
	Transparency = 0.2,
	Blurring = true,
	MinimizeKeybind = Enum.KeyCode.LeftAlt,
})

local Themes = {
	Light = {
		Primary = Color3.fromRGB(232, 232, 232),
		Secondary = Color3.fromRGB(255, 255, 255),
		Component = Color3.fromRGB(245, 245, 245),
		Interactables = Color3.fromRGB(235, 235, 235),
		Tab = Color3.fromRGB(50, 50, 50),
		Title = Color3.fromRGB(0, 0, 0),
		Description = Color3.fromRGB(100, 100, 100),
		Shadow = Color3.fromRGB(255, 255, 255),
		Outline = Color3.fromRGB(210, 210, 210),
		Icon = Color3.fromRGB(100, 100, 100),
	},
	Dark = {
		Primary = Color3.fromRGB(30, 30, 30),
		Secondary = Color3.fromRGB(35, 35, 35),
		Component = Color3.fromRGB(40, 40, 40),
		Interactables = Color3.fromRGB(45, 45, 45),
		Tab = Color3.fromRGB(200, 200, 200),
		Title = Color3.fromRGB(240,240,240),
		Description = Color3.fromRGB(200,200,200),
		Shadow = Color3.fromRGB(0, 0, 0),
		Outline = Color3.fromRGB(40, 40, 40),
		Icon = Color3.fromRGB(220, 220, 220),
	},
	Void = {
		Primary = Color3.fromRGB(15, 15, 15),
		Secondary = Color3.fromRGB(20, 20, 20),
		Component = Color3.fromRGB(25, 25, 25),
		Interactables = Color3.fromRGB(30, 30, 30),
		Tab = Color3.fromRGB(200, 200, 200),
		Title = Color3.fromRGB(240,240,240),
		Description = Color3.fromRGB(200,200,200),
		Shadow = Color3.fromRGB(0, 0, 0),
		Outline = Color3.fromRGB(40, 40, 40),
		Icon = Color3.fromRGB(220, 220, 220),
	},
}

Window:SetTheme(Themes.Dark)

--// Sections
Window:AddTabSection({ Name = "Farming", Order = 1 })
Window:AddTabSection({ Name = "Settings", Order = 2 })

--// ============================================================
--// [MOD] CASH GENERATOR CONFIG (persiste entre toggles)
--// ============================================================
local CashConfig = {
	REWARD_SEA = 1,             -- 1, 2 ou 3
	AutoDetectSea = true,       -- detecta o mar automaticamente
	SHOW_ROUTE_TRACERS = true,
	SHOW_HITBOX_VISUALIZER = true,
	SPEED = 190,
	SPEED_MIN = 250,
	SPEED_MAX = 259.9,
	LOAD_UI = false,            -- false = sem UI interna (usa a do hub)
}

--// [MOD] Detecta o mar atual via Realm
local function detectSea()
	local ok, sea = pcall(function()
		return require(ReplicatedStorage.Util.Realm).getCurrentSeaAsync()
	end)
	if ok and sea then
		if sea == "Sea1" then return 1
		elseif sea == "Sea2" then return 2
		elseif sea == "Sea3" then return 3 end
	end
	return 1
end

--// [MOD] Cash Generator (função que roda quando o toggle liga)
local function RunCashGenerator()
	-- Aplica config atual
	if CashConfig.AutoDetectSea then
		CashConfig.REWARD_SEA = detectSea()
	end
	getgenv().CashGenConfig = CashConfig

	--// ============================================================
	--// INÍCIO DO CASH GENERATOR (adaptado para o hub)
	--// ============================================================
	local CFG = getgenv().CashGenConfig

	local SPEED = CFG.SPEED
	local SPEED_MIN = CFG.SPEED_MIN
	local SPEED_MAX = CFG.SPEED_MAX
	local SPEED_PERIOD = 0.2
	local EFFECTIVE_AVG_SPEED = (SPEED_MAX + SPEED_MIN) * 0.5
	local BOAT_PURCHASE_RANGE = 450
	local BOAT_APPROACH_RANGE = 420
	local MIN_ROOT_Y = 2.0
	local MAX_TRAVEL_SECONDS = 180
	local LOAD_UI = CFG.LOAD_UI
	local SHOW_ROUTE_TRACERS = CFG.SHOW_ROUTE_TRACERS
	local SHOW_HITBOX_VISUALIZER = CFG.SHOW_HITBOX_VISUALIZER
	local REWARD_SEA = CFG.REWARD_SEA
	local ESTIMATED_PICKUP_SECONDS = 0.03
	local LOOKAHEAD_STOPS = 4
	local MAP_OUTLIER_DISTANCE = 10000
	local DISCOVERY_RUN = true
	local DISCOVERY_RADIUS = 200
	local STREAM_TIMEOUT = 2

	local HITBOX_SIZE = Vector3.new(100, 100, 100)
	local HITBOX_HALF_EXTENT = 50

	local RunService = game:GetService("RunService")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local player = Players.LocalPlayer
	while not player do
		task.wait()
		player = Players.LocalPlayer
	end
	print("[Cash Gen] Script started · Sea=" .. REWARD_SEA)

	local function getSinusoidalSpeed(serverTime)
		local mid = (SPEED_MAX + SPEED_MIN) * 0.5
		local amp = (SPEED_MAX - SPEED_MIN) * 0.5
		local omega = (2 * math.pi) / SPEED_PERIOD
		local serverTimeCycle = serverTime % SPEED_PERIOD
		return mid + amp * math.sin(serverTimeCycle * omega)
	end

	local C = {
		Speed = SPEED,
		BoatSpeed = EFFECTIVE_AVG_SPEED,
		MinRootY = MIN_ROOT_Y,
		PollSeconds = 0.05,
		SweepMargin = 5,
		MinimumTouchDepth = 4,
		ArrivalDistance = 4,
		PendingConfirmSeconds = 3,
		CharacterTimeout = 15,
		ChestFailureCooldown = 10,
		MaxChestCooldown = 120,
		MatchRadius = 1,
		ObserveSeconds = 0.5,
		ReplanSeconds = 1,
		SwitchGain = 1.25,
		MinimumCommitSeconds = 1.5,
		FinishDistance = 30,
		BeamWidth = 8,
		BranchWidth = 8,
		PlanBudgetSeconds = 0.0015,
		MapRefreshSeconds = 0.5,
		Debug = true,
	}

	local gradeBySpawnName = {Chest1 = "Silver", Chest2 = "Gold", Chest3 = "Diamond"}
	local chestEconomy = {
		Silver = {respawn = 180, rewards = {{250, 420}, {500, 1000}, {1000, 1695}}},
		Gold = {respawn = 360, rewards = {{600, 1100}, {2300, 3120}, {3875, 5200}}},
		Diamond = {respawn = 720, rewards = {{1500, 3000}, {5000, 7250}, {8000, 12250}}},
	}
	local function gradeOf(record) return gradeBySpawnName[record.name] or "Gold" end
	local function economyOf(record) return chestEconomy[gradeOf(record)] end
	local function respawnOf(record) return record.respawnEstimate or (gradeBySpawnName[record.name] and economyOf(record).respawn) end
	local function enforceAltitudeFloor(position)
		if position.Y >= C.MinRootY then return position end
		return Vector3.new(position.X, C.MinRootY, position.Z)
	end

	local legHistory = {}
	local maxLegHistory = 15
	local avgLegSpeed = 0
	local legHistoryMode = nil
	local measuredMotion = {}

	local function recordLegPerformance(distance, timeTaken, mode)
		if timeTaken <= 0.02 or distance <= 4.0 then return end
		if legHistoryMode ~= mode then
			table.clear(legHistory)
			legHistoryMode = mode
		end
		table.insert(legHistory, {distance = distance, time = timeTaken})
		if #legHistory > maxLegHistory then
			table.remove(legHistory, 1)
		end
		local totalDistance, totalTime = 0, 0
		for _, leg in ipairs(legHistory) do
			totalDistance += leg.distance
			totalTime += leg.time
		end
		avgLegSpeed = totalDistance / totalTime
		measuredMotion[mode] = {speed = avgLegSpeed, samples = #legHistory}
	end

	local Planner = {}
	function Planner.travelSeconds(a, b, speed3D)
		local dist3D = (b - a).Magnitude
		local mode = speed3D == C.Speed and "foot" or "boat"
		local observed = measuredMotion[mode]
		local calibrated = speed3D
		if observed and observed.samples >= 3 then
			calibrated = math.clamp(observed.speed, speed3D * 0.7, speed3D * 1.1)
		end
		return dist3D / calibrated
	end

	function Planner.sweepPath(node, fromPosition, margin)
		local center = enforceAltitudeFloor(node.position)
		local half = node.halfSize or Vector3.new(HITBOX_HALF_EXTENT, HITBOX_HALF_EXTENT, HITBOX_HALF_EXTENT)
		local entryPoint = Vector3.new(
			math.clamp(fromPosition.X, center.X - half.X, center.X + half.X),
			math.clamp(fromPosition.Y, center.Y - half.Y, center.Y + half.Y),
			math.clamp(fromPosition.Z, center.Z - half.Z, center.Z + half.Z))
		local inward = center - entryPoint
		local direction = inward.Magnitude > 0.001 and inward.Unit or Vector3.new(0, 0, -1)
		local exitPoint = entryPoint + direction * (margin + 6)
		local depth = C.MinimumTouchDepth + C.ArrivalDistance
		local inset = Vector3.new(math.min(depth, half.X), math.min(depth, half.Y), math.min(depth, half.Z))
		exitPoint = Vector3.new(
			math.clamp(exitPoint.X, center.X - half.X + inset.X, center.X + half.X - inset.X),
			math.clamp(exitPoint.Y, center.Y - half.Y + inset.Y, center.Y + half.Y - inset.Y),
			math.clamp(exitPoint.Z, center.Z - half.Z + inset.Z, center.Z + half.Z - inset.Z))
		return enforceAltitudeFloor(entryPoint), center, enforceAltitudeFloor(exitPoint)
	end

	function Planner.leg(position, node, startAt, now, options)
		local entry, _, exit = Planner.sweepPath(node, position, options.sweepMargin)
		local travel = options.travelEstimator and options.travelEstimator(position, entry)
			or Planner.travelSeconds(position, entry, options.speed)
		if travel > options.maxTravel then return nil end
		if node.readyAt and node.readyAt > startAt + travel then return nil end
		local sweepSeconds = options.travelEstimator(entry, exit)
		return {seconds = math.max(0.01, travel + sweepSeconds + options.service),
			probability = node.reliability, exitPosition = exit}
	end

	local function better(a, b)
		if math.abs(a.score - b.score) > 1e-9 then return a.score > b.score end
		if math.abs(a.elapsed - b.elapsed) > 1e-9 then return a.elapsed < b.elapsed end
		return a.first.id < b.first.id
	end

	local function keepBest(list, entry, limit)
		local index = #list + 1
		for i, old in ipairs(list) do if better(entry, old) then index = i; break end end
		if index <= limit then
			table.insert(list, index, entry)
			if #list > limit then table.remove(list) end
		end
	end

	function Planner.plan(position, nodes, now, options, forcedFirstId)
		local beam = {{position = position, elapsed = 0, reward = 0, visited = {}, route = {}}}
		local best
		local deadline = options.budget and (os.clock() + options.budget)
		local roots = {}
		for _, node in ipairs(nodes) do
			if not forcedFirstId or node.id == forcedFirstId then
				local leg = Planner.leg(position, node, now, now, options)
				if leg then
					local reward = node.value * leg.probability
					keepBest(roots, {position = leg.exitPosition, first = node, elapsed = leg.seconds,
						reward = reward, score = reward / (leg.seconds + options.smoothing),
						visited = {[node.id] = true}, route = {node}}, options.width)
				end
			end
		end
		if #roots == 0 then return nil end
		beam, best = roots, roots[1]
		for depth = 2, options.depth do
			local expanded = {}
			for _, state in ipairs(beam) do
				if depth > 1 and deadline and os.clock() >= deadline then return best end
				local branches = {}
				local exhausted = false
				for nodeIndex, node in ipairs(nodes) do
					if not state.visited[node.id] and (depth > 1 or not forcedFirstId or node.id == forcedFirstId) then
						local leg = Planner.leg(state.position, node, now + state.elapsed, now, options)
						if leg then
							local elapsed = state.elapsed + leg.seconds
							local reward = state.reward + node.value * leg.probability
							local entry = {
								position = leg.exitPosition, first = state.first or node,
								elapsed = elapsed, reward = reward,
								score = reward / (elapsed + options.smoothing),
								parent = state, node = node,
							}
							keepBest(branches, entry, options.branch)
						end
					end
					if nodeIndex % 16 == 0 and deadline and os.clock() >= deadline then
						exhausted = true
						break
					end
				end
				for _, entry in ipairs(branches) do
					entry.visited = table.clone(entry.parent.visited)
					entry.visited[entry.node.id] = true
					entry.route = table.clone(entry.parent.route)
					table.insert(entry.route, entry.node)
					entry.parent, entry.node = nil, nil
					keepBest(expanded, entry, options.width)
					if not best or better(entry, best) then best = entry end
				end
				if exhausted then return best end
			end
			if #expanded == 0 then break end
			beam = expanded
		end
		return best
	end

	local dealerList, lastDealerScan = {}, -math.huge
	local ownedBoat = nil

	local function rememberDealer(npc)
		if not (npc:IsA("Model") or npc:IsA("BasePart"))
			or not npc.Name:lower():gsub("%s+", ""):find("boatdealer", 1, true) then return end
		local folder = workspace:FindFirstChild("NPCs")
		if not folder or not npc:IsDescendantOf(folder) then return end
		local position = npc:IsA("Model") and npc:GetPivot().Position or npc.Position
		for _, dealer in ipairs(dealerList) do
			if (dealer.position - position).Magnitude <= 5 then
				dealer.instance, dealer.position, dealer.name = npc, position, npc.Name
				return
			end
		end
		table.insert(dealerList, {instance = npc, position = position, name = npc.Name})
	end

	local function scanDealers(force)
		local now = workspace:GetServerTimeNow()
		if not force and now - lastDealerScan < 3 then return end
		lastDealerScan = now
		for i = #dealerList, 1, -1 do
			local dealer = dealerList[i]
			if dealer.instance and not dealer.instance:IsDescendantOf(workspace) then
				dealer.instance = nil
			end
		end
	end

	local function boatSeat(boat)
		if not boat or not boat.Parent then return nil end
		local seat = boat:FindFirstChild("VehicleSeat", true)
		return seat and seat:IsA("VehicleSeat") and seat or nil
	end

	local function boatBelongsToPlayer(boat)
		local seat = boatSeat(boat)
		if seat and seat.Occupant and seat.Occupant.Parent == player.Character then return true end
		local owner = boat:FindFirstChild("Owner", true)
		if not owner or not owner:IsA("ValueBase") then return false end
		local value = owner.Value
		return value == player or value == player.Name or value == player.UserId
			or tostring(value) == tostring(player.UserId)
	end

	local function parts()
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if char and char:IsDescendantOf(workspace) and root and hum and hum.Health > 0 then
			return char, root, hum
		end
	end

	local function getLiveVelocity()
		local char, root, hum = parts()
		if not char or not root then return 0 end
		if hum and hum.SeatPart and hum.SeatPart:IsA("VehicleSeat") then
			local motionPart = hum.SeatPart.AssemblyRootPart or hum.SeatPart
			local vel = motionPart.AssemblyLinearVelocity or motionPart.Velocity
			return vel.Magnitude
		else
			local vel = root.AssemblyLinearVelocity or root.Velocity
			return vel.Magnitude
		end
	end

	local stopped = false
	local connections = {}
	local globalEnvironment = getgenv and getgenv() or _G
	if globalEnvironment.ChestFarmerBoatStop then pcall(globalEnvironment.ChestFarmerBoatStop) end

	local virtualUser = game:GetService("VirtualUser")
	table.insert(connections, player.Idled:Connect(function()
		virtualUser:CaptureController()
		virtualUser:ClickButton2(Vector2.new())
	end))

	local candidates, records = {}, {}
	local chestOriginals = setmetatable({}, {__mode = "k"})
	local currentRouteDestination
	local currentTargetBoxCenter = nil
	local currentTargetRecords = nil
	local currentNextRoutePosition = nil
	local choose, eligible, observeRecord
	local liveNavigation = {plan = nil, nodeCount = 0, planMilliseconds = 0, speed = C.BoatSpeed}
	local discovery = {active = DISCOVERY_RUN, regions = {}, completed = 0, skipped = 0,
		seededRecords = {}, lastSeedScan = -math.huge}
	local streamingJob
	local function requestStream(position)
		if not workspace.StreamingEnabled or stopped then return nil end
		if streamingJob and not streamingJob.done then
			return (streamingJob.position - position).Magnitude <= DISCOVERY_RADIUS and streamingJob or nil
		end
		local job = {position = position, done = false}
		streamingJob = job
		task.spawn(function()
			job.ok = pcall(function() player:RequestStreamAroundAsync(position, STREAM_TIMEOUT) end)
			job.done = true
		end)
		return job
	end
	local lastObserved = -math.huge

	local function log(message)
		if C.Debug then print("[Cash Gen] " .. message) end
	end

	local startingBeli, moneyStarted
	local function readBeli()
		local data = player:FindFirstChild("Data")
		local value = data and data:FindFirstChild("Beli")
		if value and (value:IsA("IntValue") or value:IsA("NumberValue")) then return value.Value end
	end

	local function stop()
		if stopped then return end
		stopped = true
		print("[Cash Gen] Stopping farm...")
	end
	globalEnvironment.ChestFarmerBoatStop = stop

	local function waitCharacter(timeout)
		local deadline = workspace:GetServerTimeNow() + timeout
		repeat
			local char, root, hum = parts()
			if char then return char, root, hum end
			task.wait(C.PollSeconds)
		until stopped or workspace:GetServerTimeNow() >= deadline
	end

	local function available(part)
		return part and part:IsDescendantOf(workspace) and part.CanTouch == true
	end
	local function loadedTrigger(record)
		local trigger = record.spawnPart or record.part
		return trigger and trigger:IsDescendantOf(workspace) and trigger or nil
	end
	local function rememberedReadyAt(record, now)
		local trigger = loadedTrigger(record)
		if trigger then return trigger.CanTouch and now or math.huge end
		if not record.geometry or record.lastCanTouch == nil then return math.huge end
		if record.lastCanTouch then return now end
		return record.readyAt or math.huge
	end
	local function chestStatus(record, now)
		local trigger = loadedTrigger(record)
		if trigger and trigger.CanTouch then return "ready" end
		if not trigger and rememberedReadyAt(record, now) <= now then return "remembered" end
		if record.readyAt and record.readyAt < math.huge and record.readyAt > now then return "predicted" end
		return record.lastCanTouch == nil and "unknown" or "empty"
	end

	local function enforceChestHitbox(part)
		if stopped or not part:IsDescendantOf(workspace) then return end
		pcall(function()
			if part.Size ~= HITBOX_SIZE then part.Size = HITBOX_SIZE end
			if part.CanCollide then part.CanCollide = false end
		end)
	end

	local function track(obj)
		rememberDealer(obj)
		if not obj:IsA("BasePart") or not obj.Name:lower():find("chest", 1, true) then return end
		local visualFolder = workspace:FindFirstChild("ChestModels")
		if visualFolder and obj:IsDescendantOf(visualFolder) then return end
		if not chestOriginals[obj] then
			chestOriginals[obj] = {size = obj.Size, canCollide = obj.CanCollide}
			for _, property in ipairs({"Size", "CanCollide"}) do
				table.insert(connections, obj:GetPropertyChangedSignal(property):Connect(function()
					enforceChestHitbox(obj)
				end))
			end
			table.insert(connections, obj:GetPropertyChangedSignal("CanTouch"):Connect(function()
				if stopped or not obj:IsDescendantOf(workspace) then return end
				local record = candidates[obj]
				if type(record) ~= "table" then return end
				local attempt = record.pendingAttempt
				if not obj.CanTouch and attempt and not attempt.done and attempt.activeBefore and attempt.crossed
					and attempt.touchPart == obj then
					attempt.deactivatedAt = workspace:GetServerTimeNow()
				end
				if observeRecord then observeRecord(record, obj, workspace:GetServerTimeNow()) end
			end))
		end
		enforceChestHitbox(obj)
		if candidates[obj] == nil then candidates[obj] = true end
	end
	table.insert(connections, workspace.DescendantAdded:Connect(track))
	local initialScanComplete = false
	task.spawn(function()
		local pending = {workspace}
		while not stopped and #pending > 0 do
			for _ = 1, 200 do
				local item = table.remove(pending)
				if not item then break end
				track(item)
				for _, child in ipairs(item:GetChildren()) do table.insert(pending, child) end
			end
			task.wait()
		end
		initialScanComplete = not stopped
	end)

	local function markEmpty(record, now, ours)
		if record.state == "empty" and record.emptyAt and now - record.emptyAt < 5 then
			if ours and record.lastLossCounted then
				record.otherLosses = math.max(0, (record.otherLosses or 0) - 1)
				record.lastLossCounted = false
			end
			return
		end
		record.emptyAt = now
		record.readyAt = now + (respawnOf(record) or economyOf(record).respawn)
		record.observationGap = false
		record.state = "empty"
		record.lastLossCounted = not ours
		if not ours then record.otherLosses = (record.otherLosses or 0) + 1 end
	end

	observeRecord = function(record, trigger, now)
		if not trigger or not trigger:IsDescendantOf(workspace) then
			record.loaded, record.observationGap = false, true
			return
		end
		local priorTouch = record.lastCanTouch
		local gap = record.observationGap
		record.spawnPart = trigger
		record.loaded = true
		if not record.geometry or record.geometry.cframe ~= trigger.CFrame or record.geometry.size ~= trigger.Size then
			record.geometry = {cframe = trigger.CFrame, size = trigger.Size}
		end
		record.position, record.lastObservedAt = trigger.Position, now
		if trigger.CanTouch then
			if priorTouch == false and record.emptyAt and not gap then
				local measured = now - record.emptyAt
				local nominal = economyOf(record).respawn
				if measured > nominal * 0.5 and measured < nominal * 1.5 then
					record.respawnEstimate = (record.respawnEstimate or nominal) * 0.8 + measured * 0.2
				end
			end
			record.part, record.state, record.collected = trigger, "ready", false
			record.emptyAt, record.readyAt = nil, now
			record.initiallyEmptyAt = nil
		else
			record.part = nil
			if priorTouch == true then
				local attempt = record.pendingAttempt
				markEmpty(record, now, attempt and attempt.deactivatedAt ~= nil)
			end
			record.state = "empty"
			if not record.emptyAt and not record.initiallyEmptyAt then
				record.initiallyEmptyAt = now
				record.readyAt = now + (respawnOf(record) or economyOf(record).respawn)
			end
		end
		record.lastCanTouch, record.observationGap = trigger.CanTouch, false
	end

	local pendingAttempts = {}
	local startupMissReports = 0
	local lastPickupBalance = readBeli()
	local function beginPending(record, sweepSeconds)
		if record.pendingAttempt then return record.pendingAttempt end
		local now = workspace:GetServerTimeNow()
		local trigger = record.spawnPart or record.part
		if not available(trigger) then return nil end
		local attempt = {record = record, touchPart = trigger, activeBefore = available(trigger) == true,
			expires = now + sweepSeconds + C.PendingConfirmSeconds + 1, crossed = false}
		record.pendingAttempt = attempt
		record.pendingUntil = attempt.expires
		table.insert(pendingAttempts, attempt)
		return attempt
	end

	local function confirmPickup(attempt, now)
		if attempt.done then return end
		attempt.done = true
		local record = attempt.record
		markEmpty(record, now, true)
		record.collected = true
		record.successes = (record.successes or 0) + 1
		record.failures = 0
		record.cooldown = now + 1
	end

	table.insert(connections, RunService.Heartbeat:Connect(function()
		local now, balance = workspace:GetServerTimeNow(), readBeli()
		if balance and lastPickupBalance and balance > lastPickupBalance then
			local gain = balance - lastPickupBalance
			for _, attempt in ipairs(pendingAttempts) do
				if not attempt.done and attempt.crossed and now <= attempt.expires then
					attempt.beliEvidence = (attempt.beliEvidence or 0) + gain
				end
			end
		end
		if balance then lastPickupBalance = balance end
		for i = #pendingAttempts, 1, -1 do
			local attempt = pendingAttempts[i]
			local observedPart = attempt.touchPart
			if not attempt.done and attempt.crossed and attempt.activeBefore and now <= attempt.expires
				and (attempt.beliEvidence or 0) > 0
				and (attempt.deactivatedAt or (observedPart and observedPart:IsDescendantOf(workspace) and observedPart.CanTouch == false)) then
				confirmPickup(attempt, attempt.deactivatedAt or now)
			end
			if attempt.done or now >= attempt.expires then
				local record = attempt.record
				if record.pendingAttempt == attempt then
					record.pendingAttempt, record.pendingUntil = nil, nil
					if not attempt.done and attempt.crossed and attempt.activeBefore
						and observedPart and observedPart:IsDescendantOf(workspace) and observedPart.CanTouch then
						record.misses = (record.misses or 0) + 1
						record.failures = (record.failures or 0) + 1
						record.cooldown = now + math.min(C.MaxChestCooldown, C.ChestFailureCooldown * 2 ^ math.min(record.failures - 1, 4))
					end
				end
				table.remove(pendingAttempts, i)
			end
		end
	end))

	local function refreshChests(force)
		local now = workspace:GetServerTimeNow()
		if not force and now - lastObserved < C.ObserveSeconds then return end
		local observedSeconds = math.min(2, math.max(0, now - lastObserved))
		lastObserved = now
		for _, r in ipairs(records) do r.spawnPart = nil; r.part = nil end
		for part in pairs(candidates) do
			if not part:IsDescendantOf(workspace) then
				candidates[part] = nil
			else
				enforceChestHitbox(part)
				local r = candidates[part]
				if r == true then
					r = nil
					for _, existing in ipairs(records) do
						if existing.name == part.Name and (existing.position - part.Position).Magnitude <= C.MatchRadius then
							r = existing
							break
						end
					end
					if not r then
						r = {id = #records + 1, name = part.Name, position = part.Position,
							cooldown = 0, failures = 0, successes = 0, misses = 0,
							exposure = 0, otherLosses = 0, state = "unknown",
							readyAt = math.huge}
						table.insert(records, r)
					end
					candidates[part] = r
				end
				r.spawnPart = part
				if available(part) then r.part = part end
				r.position = part.Position
			end
		end
		for _, r in ipairs(records) do
			if r.state == "ready" then r.exposure = (r.exposure or 0) + observedSeconds end
			observeRecord(r, r.spawnPart, now)
		end
	end

	local function approachPosition(target, stopRadius)
		local char, root, hum = parts()
		if not char then return false end
		target = enforceAltitudeFloor(target)
		local previousFlight = root:FindFirstChild("ContinuousFlightVelocity")
		local flightWasEnabled = previousFlight and previousFlight.Enabled
		if previousFlight then previousFlight.Enabled = false end
		local attachment = Instance.new("Attachment", root)
		local drive = Instance.new("LinearVelocity", root)
		drive.Attachment0 = attachment
		drive.RelativeTo = Enum.ActuatorRelativeTo.World
		drive.ForceLimitsEnabled = false

		local originals = {}
		local function disableCollision(part)
			if not part:IsA("BasePart") then return end
			if originals[part] == nil then originals[part] = part.CanCollide end
			part.CanCollide = false
		end
		for _, part in ipairs(char:GetDescendants()) do disableCollision(part) end
		local added = char.DescendantAdded:Connect(disableCollision)
		local noclipConn = RunService.PreSimulation:Connect(function()
			for part in pairs(originals) do
				if part.Parent and part.CanCollide then part.CanCollide = false end
			end
		end)

		local estimate = Planner.travelSeconds(root.Position, target, C.Speed)
		local began = workspace:GetServerTimeNow()
		local arrived = false
		while not stopped and player.Character == char and hum.Health > 0 and workspace:GetServerTimeNow() - began <= estimate * 2 + 3 do
			RunService.Heartbeat:Wait()
			local delta = target - root.Position
			if delta.Magnitude <= stopRadius then arrived = true; break end
			drive.VectorVelocity = delta.Unit * C.Speed
		end
		noclipConn:Disconnect()
		added:Disconnect()
		for part, canCollide in pairs(originals) do
			if part.Parent then part.CanCollide = canCollide end
		end
		drive:Destroy()
		attachment:Destroy()
		if previousFlight and previousFlight.Parent then
			previousFlight.Enabled = flightWasEnabled
		end
		return arrived
	end

	local preparedBoat, boatSeatCleanupConnection
	local function prepareDinghySeats(boat)
		if not boat or not boat.Parent or preparedBoat == boat then return end
		if boatSeatCleanupConnection then boatSeatCleanupConnection:Disconnect() end
		preparedBoat = boat
		local function removePassengerSeat(part)
			if part:IsA("Seat") or (part:IsA("VehicleSeat") and part.Name ~= "VehicleSeat") then
				part:Destroy()
			end
		end
		boatSeatCleanupConnection = boat.DescendantAdded:Connect(function(part)
			if not stopped then removePassengerSeat(part) end
		end)
		for _, part in ipairs(boat:GetDescendants()) do removePassengerSeat(part) end
	end

	local function buyDinghy()
		local boats = workspace:FindFirstChild("Boats") or workspace:WaitForChild("Boats", 3)
		local remoteFolder = ReplicatedStorage:FindFirstChild("Remotes")
		local event = remoteFolder and remoteFolder:FindFirstChild("CommF_")
		if not boats or not event then return nil end
		local _, root = parts()
		for _, existing in ipairs(boats:GetChildren()) do
			local seat = boatSeat(existing)
			if seat and root and boatBelongsToPlayer(existing) and (root.Position - seat.Position).Magnitude <= 500 then
				prepareDinghySeats(existing)
				return existing
			end
		end
		local seen = {}
		for _, child in ipairs(boats:GetChildren()) do seen[child] = true end
		local arrivals = {}
		local added = boats.ChildAdded:Connect(function(child) table.insert(arrivals, child) end)
		task.spawn(function() pcall(function() event:InvokeServer("BuyBoat", "Dinghy") end) end)
		local deadline = workspace:GetServerTimeNow() + 8
		local found
		repeat
			for _, boat in ipairs(arrivals) do
				if boat.Parent == boats and not seen[boat] and boatBelongsToPlayer(boat) and boatSeat(boat) then
					found = boat
					break
				end
			end
			if found then break end
			task.wait(0.1)
		until stopped or workspace:GetServerTimeNow() >= deadline
		added:Disconnect()
		if found then prepareDinghySeats(found) end
		return found
	end

	local function boardBoat(boat)
		prepareDinghySeats(boat)
		local char, root, hum = parts()
		local seat = boatSeat(boat)
		if not char or not seat then return false end
		seat:Sit(hum)
		local deadline = workspace:GetServerTimeNow() + 2
		while not stopped and workspace:GetServerTimeNow() < deadline and seat.Occupant ~= hum do task.wait(0.05) end
		return seat.Occupant == hum
	end

	local function getActiveVehicleOrCharacter()
		local char, root, hum = parts()
		if not char then return nil, nil end
		if hum.SeatPart and hum.SeatPart:IsA("VehicleSeat") then
			local boat = hum.SeatPart:FindFirstAncestorOfClass("Model")
			if boat then
				ownedBoat = boat
				prepareDinghySeats(boat)
				local seat = boatSeat(boat)
				if seat and seat.Occupant == hum then return boat, seat end
			end
		end
		if ownedBoat and ownedBoat.Parent then
			prepareDinghySeats(ownedBoat)
			local seat = boatSeat(ownedBoat)
			if seat and (root.Position - seat.Position).Magnitude <= 350 then
				approachPosition(seat.Position + Vector3.new(0, 3, 0), 10)
				if boardBoat(ownedBoat) then return ownedBoat, seat end
			end
		end
		scanDealers(true)
		local nearestDealer, nearestDist = nil, math.huge
		for _, dealer in ipairs(dealerList) do
			local dist = (root.Position - dealer.position).Magnitude
			if dist < nearestDist then nearestDealer, nearestDist = dealer, dist end
		end
		if nearestDealer and nearestDist <= 1200 then
			if (root.Position - nearestDealer.position).Magnitude > BOAT_APPROACH_RANGE then
				approachPosition(nearestDealer.position, BOAT_APPROACH_RANGE)
			end
			local boat = buyDinghy()
			if boat then
				ownedBoat = boat
				local seat = boatSeat(boat)
				if seat then
					approachPosition(seat.Position + Vector3.new(0, 3, 0), 8)
					if boardBoat(boat) then return boat, seat end
				end
			end
		end
		return nil, nil
	end

	local persistentLinearVelocity = nil
	local persistentAttachment = nil
	local persistentNoclipConn = nil
	local noclipChar, noclipBoat = nil, nil
	local noclipOriginals = {}
	local noclipAdded = {}

	local function restoreFlightCollision()
		for _, connection in ipairs(noclipAdded) do connection:Disconnect() end
		table.clear(noclipAdded)
		for part, canCollide in pairs(noclipOriginals) do
			if part.Parent then part.CanCollide = canCollide end
		end
		table.clear(noclipOriginals)
		noclipChar, noclipBoat = nil, nil
	end

	local function setFlightCollisionTargets(char, boat, motionPart)
		if char == noclipChar and boat == noclipBoat then return end
		restoreFlightCollision()
		noclipChar, noclipBoat = char, boat
		local function disable(part)
			if not part:IsA("BasePart") then return end
			if noclipOriginals[part] == nil then noclipOriginals[part] = part.CanCollide end
			part.CanCollide = false
		end
		local function watch(container)
			if not container then return end
			for _, part in ipairs(container:GetDescendants()) do disable(part) end
			table.insert(noclipAdded, container.DescendantAdded:Connect(disable))
		end
		watch(char)
		watch(boat)
		if motionPart then
			disable(motionPart)
			local ok, connected = pcall(function() return motionPart:GetConnectedParts(true) end)
			if ok then for _, part in ipairs(connected) do disable(part) end end
		end
		if not persistentNoclipConn then
			persistentNoclipConn = RunService.PreSimulation:Connect(function()
				for part in pairs(noclipOriginals) do
					if not part.Parent then
						noclipOriginals[part] = nil
					elseif part.CanCollide then
						part.CanCollide = false
					end
				end
			end)
		end
	end

	local activeFlightCommand
	local function applyFlightCommand(command, now)
		local motionPart, lv, dir = command.part, command.constraint, command.direction
		if stopped or not motionPart.Parent or not lv.Parent then return end
		local speed = command.isBoat and math.clamp(getSinusoidalSpeed(now), SPEED_MIN, SPEED_MAX) or C.Speed
		local velocity = dir * speed
		if command.seat and command.seat.Parent then
			command.seat.ThrottleFloat = 0
			command.seat.SteerFloat = 0
		end
		local up = math.abs(dir.Y) > 0.999 and Vector3.new(0, 0, -1) or Vector3.yAxis
		motionPart.CFrame = CFrame.lookAt(motionPart.Position, motionPart.Position + dir, up)
		motionPart.AssemblyAngularVelocity = Vector3.zero
		lv.VectorVelocity = velocity
		motionPart.AssemblyLinearVelocity = velocity
	end
	table.insert(connections, RunService.PreSimulation:Connect(function()
		local command = activeFlightCommand
		if command then
			if command.character ~= player.Character or not command.part.Parent or not command.constraint.Parent then
				activeFlightCommand = nil
				return
			end
			applyFlightCommand(command, workspace:GetServerTimeNow())
		end
	end))

	local function getFlightConstraint(boat, seat)
		local char, root = parts()
		local motionPart = seat and (seat.AssemblyRootPart or seat) or root
		if not motionPart then return nil, nil end
		if not persistentLinearVelocity or persistentLinearVelocity.Parent ~= motionPart then
			if persistentLinearVelocity then persistentLinearVelocity:Destroy() end
			if persistentAttachment then persistentAttachment:Destroy() end
			persistentAttachment = Instance.new("Attachment")
			persistentAttachment.Name = "ContinuousFlightAttachment"
			persistentAttachment.Parent = motionPart
			persistentLinearVelocity = Instance.new("LinearVelocity")
			persistentLinearVelocity.Name = "ContinuousFlightVelocity"
			persistentLinearVelocity.Attachment0 = persistentAttachment
			persistentLinearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
			persistentLinearVelocity.ForceLimitsEnabled = false
			persistentLinearVelocity.MaxForce = math.huge
			persistentLinearVelocity.VectorVelocity = Vector3.zero
			persistentLinearVelocity.Parent = motionPart
		end
		setFlightCollisionTargets(char, boat, motionPart)
		return persistentLinearVelocity, motionPart
	end

	local function pauseFlight()
		activeFlightCommand = nil
		if persistentLinearVelocity and persistentLinearVelocity.Parent then
			persistentLinearVelocity.VectorVelocity = Vector3.zero
			local motionPart = persistentLinearVelocity.Parent
			if motionPart:IsA("BasePart") then
				motionPart.AssemblyLinearVelocity = Vector3.zero
				motionPart.AssemblyAngularVelocity = Vector3.zero
			end
		end
	end

	local function move3D(boat, seat, destination, recordsToArm, guard)
		local char, root, hum = parts()
		if not char then return "interrupted" end
		local lv, motionPart = getFlightConstraint(boat, seat)
		if not lv or not motionPart then return "interrupted" end
		local began = workspace:GetServerTimeNow()
		local startPos = root.Position
		local delta = destination - startPos
		local totalDist = delta.Magnitude
		local function armNearby(position)
			if not recordsToArm then return end
			for _, rec in ipairs(recordsToArm) do
				local trigger = rec.spawnPart or rec.part
				local offset = trigger and trigger.CFrame:PointToObjectSpace(position)
				local half = trigger and trigger.Size * 0.5
				if available(trigger) and math.abs(offset.X) <= half.X + 12
					and math.abs(offset.Y) <= half.Y + 12 and math.abs(offset.Z) <= half.Z + 12 then
					local attempt = beginPending(rec, 0.05)
					if attempt and math.abs(offset.X) <= half.X and math.abs(offset.Y) <= half.Y
						and math.abs(offset.Z) <= half.Z then attempt.crossed = true end
				end
			end
		end
		armNearby(startPos)
		if totalDist <= C.ArrivalDistance then return "arrived" end
		local initialDir = delta.Unit
		local isBoat = (boat ~= nil and seat ~= nil)
		local minSpeed = isBoat and SPEED_MIN or C.Speed
		local timeout = (totalDist / minSpeed) + 3.0
		local outcome = "arrived"
		local movingDistance, movingTime = 0, 0
		local previousPosition, previousTime = motionPart.Position, os.clock()
		local command = {part = motionPart, constraint = lv, direction = initialDir,
			seat = seat, isBoat = isBoat, character = char}
		local function drive(dir, now)
			command.direction = dir
			activeFlightCommand = command
			applyFlightCommand(command, now)
		end
		drive(initialDir, began)
		while not stopped and player.Character == char and hum.Health > 0 do
			RunService.Heartbeat:Wait()
			local frameTime = os.clock()
			local framePosition = motionPart.Position
			movingDistance += (framePosition - previousPosition).Magnitude
			movingTime += frameTime - previousTime
			previousPosition, previousTime = framePosition, frameTime
			if isBoat and seat.Occupant ~= hum then
				seat:Sit(hum)
				if seat.Occupant ~= hum then outcome = "interrupted"; break end
			end
			local now = workspace:GetServerTimeNow()
			if now - began > timeout then outcome = "timeout"; break end
			local currentPos = root.Position
			local currentDelta = destination - currentPos
			local currentDist = currentDelta.Magnitude
			armNearby(currentPos)
			if guard then
				local decision = guard(now, currentPos, currentDist)
				if decision then outcome = decision; break end
			end
			local passed = (currentPos - startPos):Dot(initialDir) >= totalDist
			if currentDist <= C.ArrivalDistance or passed then
				outcome = "arrived"
				break
			end
			drive(initialDir, now)
		end
		if stopped or player.Character ~= char or hum.Health <= 0 then
			outcome = "interrupted"
		end
		if outcome == "arrived" then
			recordLegPerformance(movingDistance, movingTime, isBoat and "boat" or "foot")
		elseif outcome == "timeout" or outcome == "interrupted" then
			pauseFlight()
		end
		return outcome
	end

	local function flyThroughTarget(boat, seat, node)
		local char, root = parts()
		if not char then return "interrupted" end
		local recordsList = node.records
		local entryPoint, centerPoint, exitPoint = Planner.sweepPath(node, root.Position, C.SweepMargin)
		currentTargetBoxCenter, currentTargetRecords = centerPoint, recordsList
		local function finish(outcome)
			currentRouteDestination, currentTargetBoxCenter = nil, nil
			currentTargetRecords, currentNextRoutePosition = nil, nil
			return outcome
		end
		local function hasActive()
			for _, record in ipairs(recordsList) do
				if available(record.spawnPart or record.part) then return true end
			end
			return false
		end
		local function hasMissing()
			for _, record in ipairs(recordsList) do if not loadedTrigger(record) then return true end end
			return false
		end
		local function hasPotential(now, seconds)
			for _, record in ipairs(recordsList) do
				if rememberedReadyAt(record, now) <= now + seconds then return true end
			end
			return false
		end
		local approachSeconds = Planner.travelSeconds(root.Position, entryPoint, liveNavigation.speed)
		if not hasPotential(workspace:GetServerTimeNow(), approachSeconds) then return finish("unavailable") end
		local verificationJob
		local began, lastReplan = workspace:GetServerTimeNow(), workspace:GetServerTimeNow()
		local function guard(now, position, remaining)
			if not hasPotential(now, Planner.travelSeconds(position, entryPoint, liveNavigation.speed)) then return "unavailable" end
			if hasMissing() and not verificationJob and remaining <= liveNavigation.speed * STREAM_TIMEOUT + DISCOVERY_RADIUS then
				verificationJob = requestStream(centerPoint)
			end
			if remaining <= C.FinishDistance or now - began < C.MinimumCommitSeconds
				or now - lastReplan < C.ReplanSeconds then return end
			for _, record in ipairs(recordsList) do
				if record.pendingAttempt then return end
			end
			lastReplan = now
			refreshChests()
			local _, currentRoot = parts()
			if not currentRoot then return "interrupted" end
			local best = choose(currentRoot, nil, liveNavigation.speed)
			if not best then return "unavailable" end
			local sameTarget = best.first.id == node.id
			local retained = sameTarget and best or choose(currentRoot, node.record, liveNavigation.speed)
			if not sameTarget and (not retained or best.score > retained.score * C.SwitchGain) then
				return "reroute"
			end
			if retained then
				liveNavigation.plan = retained
				currentNextRoutePosition = retained.route[2] and retained.route[2].position or nil
			end
		end
		currentRouteDestination = entryPoint
		local approach = move3D(boat, seat, entryPoint, recordsList, guard)
		if approach ~= "arrived" then return finish(approach) end
		refreshChests(true)
		if not hasActive() and hasMissing() then
			if workspace.StreamingEnabled then
				verificationJob = verificationJob or requestStream(centerPoint)
				pauseFlight()
				local deadline = workspace:GetServerTimeNow() + STREAM_TIMEOUT
				while not stopped and not hasActive() and workspace:GetServerTimeNow() < deadline do
					RunService.Heartbeat:Wait()
					refreshChests()
					local allLoaded = true
					for _, record in ipairs(recordsList) do if not loadedTrigger(record) then allLoaded = false; break end end
					if allLoaded then break end
					if not verificationJob then verificationJob = requestStream(centerPoint) end
				end
				refreshChests(true)
			end
		end
		if stopped then return finish("interrupted") end
		if not hasActive() then
			for _, record in ipairs(recordsList) do
				if not loadedTrigger(record) then record.cooldown = workspace:GetServerTimeNow() + C.ChestFailureCooldown end
			end
			return finish("unavailable")
		end
		currentRouteDestination = exitPoint
		return finish(move3D(boat, seat, exitPoint, recordsList))
	end

	eligible = function(record, now)
		local pending = record.pendingAttempt
		return rememberedReadyAt(record, now) < math.huge
			and not (pending and not pending.done)
			and now >= (record.cooldown or 0)
	end

	local function triggerBounds(record)
		local geometry = record.geometry
		if geometry.low then return geometry.low, geometry.high end
		local half = geometry.size * 0.5
		local rotation = geometry.cframe
		local right, up, look = rotation.RightVector, rotation.UpVector, rotation.LookVector
		local radius = math.min(
			half.X / (math.abs(right.X) + math.abs(right.Y) + math.abs(right.Z)),
			half.Y / (math.abs(up.X) + math.abs(up.Y) + math.abs(up.Z)),
			half.Z / (math.abs(look.X) + math.abs(look.Y) + math.abs(look.Z)))
		local extent = Vector3.new(radius, radius, radius)
		local low, high = rotation.Position - extent, rotation.Position + extent
		low = Vector3.new(low.X, math.max(low.Y, C.MinRootY), low.Z)
		geometry.low, geometry.high = low, high
		return low, high
	end
	local function overlapBounds(aLow, aHigh, bLow, bHigh)
		local low = Vector3.new(math.max(aLow.X, bLow.X), math.max(aLow.Y, bLow.Y), math.max(aLow.Z, bLow.Z))
		local high = Vector3.new(math.min(aHigh.X, bHigh.X), math.min(aHigh.Y, bHigh.Y), math.min(aHigh.Z, bHigh.Z))
		return low, high
	end
	local function buildFusedClusters(rawNodes)
		local nodes, used = {}, {}
		for index, anchor in ipairs(rawNodes) do
			if used[index] then continue end
			local group, low, high = {anchor.record}, anchor.low, anchor.high
			local value, expected, readyAt = anchor.value, anchor.value * anchor.reliability, anchor.readyAt
			used[index] = true
			for other = index + 1, #rawNodes do
				if used[other] then continue end
				local candidate = rawNodes[other]
				if anchor.inferred ~= candidate.inferred or math.abs(readyAt - candidate.readyAt) > 3 then continue end
				if candidate.low.X > high.X - 4 or candidate.high.X < low.X + 4
					or candidate.low.Y > high.Y - 4 or candidate.high.Y < low.Y + 4
					or candidate.low.Z > high.Z - 4 or candidate.high.Z < low.Z + 4 then continue end
				local nextLow, nextHigh = overlapBounds(low, high, candidate.low, candidate.high)
				local span = nextHigh - nextLow
				if math.min(span.X, span.Y, span.Z) >= 4 then
					low, high = nextLow, nextHigh
					value += candidate.value
					expected += candidate.value * candidate.reliability
					readyAt = math.max(readyAt, candidate.readyAt)
					table.insert(group, candidate.record)
					used[other] = true
				end
			end
			table.insert(nodes, {id = anchor.record.id, record = anchor.record, records = group,
				position = (low + high) * 0.5, halfSize = (high - low) * 0.5,
				value = value, reliability = expected / value,
				readyAt = readyAt, inferred = anchor.inferred,
				isCluster = #group > 1, clusterCount = #group})
		end
		return nodes
	end
	local function snapshotNodes(now)
		local raw = {}
		for _, record in ipairs(records) do
			if not eligible(record, now) then continue end
			local low, high = triggerBounds(record)
			if high.Y <= low.Y then continue end
			local reward = economyOf(record).rewards[REWARD_SEA]
			local inferred = loadedTrigger(record) == nil
			table.insert(raw, {record = record, low = low, high = high, value = (reward[1] + reward[2]) * 0.5,
				readyAt = rememberedReadyAt(record, now), inferred = inferred,
				reliability = math.clamp((record.successes + 8) / (record.successes + record.misses + 8), 0.3, 1)
					* (inferred and 0.85 or 1)})
		end
		return buildFusedClusters(raw)
	end
	local function plannerOptions(speed)
		return {speed = speed, maxTravel = MAX_TRAVEL_SECONDS,
			travelEstimator = function(from, dest) return Planner.travelSeconds(from, dest, speed) end,
			service = ESTIMATED_PICKUP_SECONDS, sweepMargin = C.SweepMargin,
			depth = LOOKAHEAD_STOPS, width = C.BeamWidth, branch = C.BranchWidth,
			smoothing = 5, budget = C.PlanBudgetSeconds}
	end
	choose = function(root, forcedRecord, currentSpeed)
		local now, began = workspace:GetServerTimeNow(), os.clock()
		local nodes = snapshotNodes(now)
		local plan = Planner.plan(root.Position, nodes, now, plannerOptions(currentSpeed or C.BoatSpeed),
			forcedRecord and forcedRecord.id)
		if plan then plan.node, plan.record = plan.first, plan.first.record end
		if not forcedRecord then
			liveNavigation.plan = plan
			liveNavigation.nodeCount, liveNavigation.planMilliseconds = #nodes, (os.clock() - began) * 1000
		end
		return plan
	end

	local function addDiscoveryRegion(record)
		local position = enforceAltitudeFloor(record.position)
		for _, region in ipairs(discovery.regions) do
			if (region.position - position).Magnitude <= DISCOVERY_RADIUS then return end
		end
		table.insert(discovery.regions, {position = position, name = record.name, record = record, visits = 0})
	end
	local function collectDiscoverySeeds(force)
		if not discovery.active then return end
		local now = os.clock()
		if not force and now - discovery.lastSeedScan < 1 then return end
		discovery.lastSeedScan = now
		for _, record in ipairs(records) do
			if not discovery.seededRecords[record.id] then
				discovery.seededRecords[record.id] = true
				addDiscoveryRegion(record)
			end
		end
	end
	local function discoveryNode(region)
		if region.record.geometry then
			local low, high = triggerBounds(region.record)
			return {position = (low + high) * 0.5, halfSize = (high - low) * 0.5}
		end
		return {position = region.position}
	end
	local function chooseDiscovery(root, speed)
		collectDiscoverySeeds(true)
		local nearest, distance
		for _, region in ipairs(discovery.regions) do
			local trigger = loadedTrigger(region.record)
			if not region.visited and trigger and not trigger.CanTouch then
				region.visited = true
				discovery.completed += 1
			end
			if not region.visited then
				local entry = Planner.sweepPath(discoveryNode(region), root.Position, C.SweepMargin)
				local candidate = Planner.travelSeconds(root.Position, entry, speed)
				if candidate <= MAX_TRAVEL_SECONDS and (not distance or candidate < distance) then
					nearest, distance = region, candidate
				end
			end
		end
		if not nearest then
			for _, region in ipairs(discovery.regions) do
				if not region.visited then region.visited = true; discovery.skipped += 1 end
			end
			discovery.active = false
			log(string.format("Discovery complete: %d areas sampled, %d chest locations remembered", discovery.completed, #records))
		end
		return nearest
	end
	local function discoverArea(boat, seat, region)
		local _, root = parts()
		if not root then return "interrupted" end
		local entryPoint, centerPoint, exitPoint = Planner.sweepPath(discoveryNode(region), root.Position, C.SweepMargin)
		local nearRecords = {}
		for _, record in ipairs(records) do
			if (record.position - region.position).Magnitude <= DISCOVERY_RADIUS then table.insert(nearRecords, record) end
		end
		liveNavigation.plan = nil
		currentRouteDestination, currentTargetRecords = entryPoint, nearRecords
		currentTargetBoxCenter, currentNextRoutePosition = centerPoint, nil
		local job
		local knownRecordCount = #records
		local function streamGuard(_, _, remaining)
			refreshChests()
			local trigger = loadedTrigger(region.record)
			if trigger and not trigger.CanTouch then return "unavailable" end
			for index = knownRecordCount + 1, #records do
				local record = records[index]
				if (record.position - region.position).Magnitude <= DISCOVERY_RADIUS then
					table.insert(nearRecords, record)
				end
			end
			knownRecordCount = #records
			if not job and remaining <= liveNavigation.speed * STREAM_TIMEOUT + DISCOVERY_RADIUS then
				job = requestStream(region.position)
			end
		end
		local outcome = move3D(boat, seat, entryPoint, nearRecords, streamGuard)
		if outcome == "arrived" then
			if workspace.StreamingEnabled and not loadedTrigger(region.record) and (not job or not job.done) then
				job = job or requestStream(region.position)
				pauseFlight()
				local deadline = workspace:GetServerTimeNow() + STREAM_TIMEOUT
				repeat
					RunService.Heartbeat:Wait()
					refreshChests()
					if not job then job = requestStream(region.position) end
				until stopped or loadedTrigger(region.record) or (job and job.done) or workspace:GetServerTimeNow() >= deadline
			end
			refreshChests(true)
			collectDiscoverySeeds(true)
			if available(loadedTrigger(region.record)) then
				currentRouteDestination = exitPoint
				outcome = move3D(boat, seat, exitPoint, nearRecords)
			end
			if outcome == "arrived" then
				region.visited = true
				discovery.completed += 1
			elseif outcome == "timeout" then
				region.visits += 1
				if region.visits >= 2 then region.visited = true; discovery.skipped += 1 end
			end
		elseif outcome == "timeout" then
			region.visits += 1
			if region.visits >= 2 then region.visited = true; discovery.skipped += 1 end
		end
		currentRouteDestination, currentTargetBoxCenter = nil, nil
		currentTargetRecords, currentNextRoutePosition = nil, nil
		return outcome
	end

	-- MAIN LOOP
	local farmFrame = 0
	table.insert(connections, RunService.Heartbeat:Connect(function() farmFrame += 1 end))
	task.spawn(function()
		local ok, err = xpcall(function()
			local startupDeadline = os.clock() + C.CharacterTimeout
			while not stopped and (not initialScanComplete or not game:IsLoaded()) and os.clock() < startupDeadline do
				RunService.Heartbeat:Wait()
			end
			if stopped then return end
			refreshChests(true)
			local startupBalance = readBeli()
			if startupBalance then
				lastPickupBalance = startupBalance
				if startingBeli == nil then
					startingBeli, moneyStarted = startupBalance, workspace:GetServerTimeNow()
				end
			end
			local lastPlanningFrame = -1
			while not stopped do
				if farmFrame == lastPlanningFrame then RunService.Heartbeat:Wait() end
				if stopped then break end
				lastPlanningFrame = farmFrame
				scanDealers()
				refreshChests()
				local _, root = waitCharacter(C.CharacterTimeout)
				if stopped then break end
				if not root then task.wait(0.5); continue end
				local boat, seat = getActiveVehicleOrCharacter()
				local currentSpeed = boat and C.BoatSpeed or C.Speed
				liveNavigation.speed = currentSpeed
				if discovery.active then
					local region = chooseDiscovery(root, currentSpeed)
					if region then
						discoverArea(boat, seat, region)
						continue
					end
				end
				local plan = choose(root, nil, currentSpeed)
				if not plan then
					liveNavigation.plan = nil
					currentRouteDestination, currentTargetBoxCenter = nil, nil
					currentTargetRecords, currentNextRoutePosition = nil, nil
					pauseFlight()
					task.wait(C.PollSeconds)
					continue
				end
				local node = plan.node
				currentNextRoutePosition = plan.route and plan.route[2] and plan.route[2].position or nil
				local outcome = flyThroughTarget(boat, seat, node)
				if outcome ~= "arrived" and outcome ~= "unavailable" and outcome ~= "interrupted" and outcome ~= "reroute" then
					for _, record in ipairs(node.records or {node.record}) do
						record.failures = (record.failures or 0) + 1
						record.cooldown = workspace:GetServerTimeNow() + 10
					end
				end
			end
		end, debug.traceback)

		stopped = true
		pauseFlight()
		if boatSeatCleanupConnection then boatSeatCleanupConnection:Disconnect() end
		preparedBoat = nil
		if persistentNoclipConn then persistentNoclipConn:Disconnect() end
		restoreFlightCollision()
		if persistentLinearVelocity then persistentLinearVelocity:Destroy() end
		if persistentAttachment then persistentAttachment:Destroy() end
		for _, conn in ipairs(connections) do conn:Disconnect() end
		for part, original in pairs(chestOriginals) do
			if part.Parent then
				pcall(function()
					part.Size = original.size
					part.CanCollide = original.canCollide
				end)
			end
		end
		if not ok then warn("[Cash Gen] " .. tostring(err)) end
		if globalEnvironment.ChestFarmerBoatStop == stop then globalEnvironment.ChestFarmerBoatStop = nil end
	end)
end

--// ============================================================
--// TAB "CASH"
--// ============================================================
local Cash = Window:AddTab({
	Title = "Cash",
	Section = "Farming",
	Icon = "rbxassetid://11963373994",
})

Window:AddParagraph({
	Title = "Cash Generator",
	Description = "Farm automático de baús (Chest1/2/3). Usa Dinghy para voar até os baús, prioriza clusters e respeita respawn.",
	Tab = Cash,
})

Window:AddSection({ Name = "Controle", Tab = Cash })

local cashToggle
cashToggle = Window:AddToggle({
	Title = "Enable Chest Farm",
	Description = "Ligar/desligar o farm de baús",
	Default = false,
	Tab = Cash,
	Callback = function(Boolean)
		if Boolean then
			task.spawn(RunCashGenerator)
			Window:Notify({
				Title = "Cash Gen",
				Description = "Farm iniciado · Sea " .. tostring(CashConfig.REWARD_SEA),
				Duration = 4,
			})
		else
			if getgenv().ChestFarmerBoatStop then
				pcall(getgenv().ChestFarmerBoatStop)
			end
			Window:Notify({
				Title = "Cash Gen",
				Description = "Farm parado.",
				Duration = 4,
			})
		end
	end,
})

Window:AddButton({
	Title = "Force Stop",
	Description = "Para o farm imediatamente",
	Tab = Cash,
	Callback = function()
		if getgenv().ChestFarmerBoatStop then
			pcall(getgenv().ChestFarmerBoatStop)
		end
		if cashToggle and cashToggle.Set then
			pcall(function() cashToggle:Set(false) end)
		end
		Window:Notify({ Title = "Cash Gen", Description = "Forçado a parar.", Duration = 3 })
	end,
})

Window:AddSection({ Name = "Configurações", Tab = Cash })

Window:AddDropdown({
	Title = "Reward Sea",
	Description = "Qual mar você está (afeta cálculo de valor e respawn)",
	Tab = Cash,
	Default = "Auto Detect",
	Options = {
		["Auto Detect"] = "auto",
		["Sea 1"] = "1",
		["Sea 2"] = "2",
		["Sea 3"] = "3",
	},
	Callback = function(Value)
		if Value == "auto" then
			CashConfig.AutoDetectSea = true
			CashConfig.REWARD_SEA = detectSea()
		else
			CashConfig.AutoDetectSea = false
			CashConfig.REWARD_SEA = tonumber(Value) or 1
		end
	end,
})

Window:AddToggle({
	Title = "Show Route Tracers",
	Description = "Linhas coloridas entre você e os destinos",
	Default = true,
	Tab = Cash,
	Callback = function(Boolean)
		CashConfig.SHOW_ROUTE_TRACERS = Boolean
	end,
})

Window:AddToggle({
	Title = "Show Hitbox Visualizer",
	Description = "Desenha os cubos 100x100x100 dos baús",
	Default = true,
	Tab = Cash,
	Callback = function(Boolean)
		CashConfig.SHOW_HITBOX_VISUALIZER = Boolean
	end,
})

Window:AddSlider({
	Title = "Foot Speed",
	Description = "Velocidade a pé (studs/s)",
	MinValue = 100,
	MaxValue = 400,
	Default = 190,
	Tab = Cash,
	Callback = function(Amount)
		CashConfig.SPEED = Amount
	end,
})

Window:AddSlider({
	Title = "Boat Speed Min",
	Description = "Velocidade mínima do barco (studs/s)",
	MinValue = 150,
	MaxValue = 350,
	Default = 250,
	Tab = Cash,
	Callback = function(Amount)
		CashConfig.SPEED_MIN = Amount
	end,
})

Window:AddSlider({
	Title = "Boat Speed Max",
	Description = "Velocidade máxima do barco (studs/s)",
	MinValue = 150,
	MaxValue = 400,
	Default = 259.9,
	AllowDecimals = true,
	Tab = Cash,
	Callback = function(Amount)
		CashConfig.SPEED_MAX = Amount
	end,
})

--// ============================================================
--// TAB "SETTINGS"
--// ============================================================
local Settings = Window:AddTab({
	Title = "Settings",
	Section = "Settings",
	Icon = "rbxassetid://11293977610",
})

Window:AddKeybind({
	Title = "Minimize Keybind",
	Description = "Tecla para minimizar a UI",
	Tab = Settings,
	Callback = function(Key)
		Window:SetSetting("Keybind", Key)
	end,
})

Window:AddDropdown({
	Title = "Set Theme",
	Description = "Tema do hub",
	Tab = Settings,
	Options = {
		["Light Mode"] = "Light",
		["Dark Mode"] = "Dark",
		["Extra Dark"] = "Void",
	},
	Callback = function(Theme)
		Window:SetTheme(Themes[Theme])
	end,
})

Window:AddToggle({
	Title = "UI Blur",
	Description = "Blur no fundo (precisa de graphics 8+)",
	Default = true,
	Tab = Settings,
	Callback = function(Boolean)
		Window:SetSetting("Blur", Boolean)
	end,
})

Window:AddSlider({
	Title = "UI Transparency",
	Description = "Transparência da UI",
	Default = 0.2,
	AllowDecimals = true,
	MinValue = 0,
	MaxValue = 1,
	Tab = Settings,
	Callback = function(Amount)
		Window:SetSetting("Transparency", Amount)
	end,
})

Window:Notify({
	Title = "W-Nickz Hub",
	Description = "Pressione Left Alt para minimizar. Cash Gen está na tab Cash.",
	Duration = 8,
})