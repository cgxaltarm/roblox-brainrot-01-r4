-- Brainrot Night Market: server authority for the whole game loop.
-- Buy -> carry -> place -> earn -> collect, plus steal, slap, lock, fuse,
-- rebirth, 5 chained missions, timed events and DataStore saves.
-- The client only asks; every price, distance and ownership check lives here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local Workspace = game:GetService("Workspace")

local Catalog = require(ReplicatedStorage:WaitForChild("Catalog"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local BuyBrainrot = Remotes:WaitForChild("BuyBrainrot")
local PlaceBrainrot = Remotes:WaitForChild("PlaceBrainrot")
local CollectCash = Remotes:WaitForChild("CollectCash")
local LockBase = Remotes:WaitForChild("LockBase")
local FuseBrainrots = Remotes:WaitForChild("FuseBrainrots")
local DoRebirth = Remotes:WaitForChild("DoRebirth")
local SlapPlayer = Remotes:WaitForChild("SlapPlayer")
local StealBrainrot = Remotes:WaitForChild("StealBrainrot")
local BuyGear = Remotes:WaitForChild("BuyGear")
local PickupDrop = Remotes:WaitForChild("PickupDrop")
local StateUpdate = Remotes:WaitForChild("StateUpdate")

local STORE = nil
pcall(function()
	STORE = DataStoreService:GetDataStore("BrainrotNightMarketR4")
end)

local START_CASH = 100
local LOCK_COST = 1500
local LOCK_SECONDS = 120
local REBIRTH_COST = 5000
local BASE_PADS = 8
local CONVEYOR_SLOTS = 6
local BASE_UNLOCK_START = 4

local MISSION_TEXT = {
	"1/5: Beli brainrot pertamamu di conveyor",
	"2/5: Letakkan brainrot di basemu",
	"3/5: Kumpulkan total $500",
	"4/5: Curi dari rival ATAU fuse 2 brainrot",
	"5/5: Rebirth sekali",
	"SELESAI: Semua misi tamat! Kamu legenda pasar!",
}
local MISSION_BONUS = { 100, 200, 300, 500, 1000 }

local EVENT_CYCLE = { "Rush Hour", "Golden Hour", "Festival" }
local EVENT_SECONDS = { ["Rush Hour"] = 30, ["Golden Hour"] = 45, Festival = 60 }

local data = {}
local basesTaken = {}
local conveyor = {}
local conveyorOrder = {}
local currentEvent = "Tenang"
local eventEndsAt = 0
local nextEventAt = os.time() + 75
local eventIndex = 0
local dropModels = {}

local function now()
	return os.time()
end

local function rebirthMult(rebirths)
	local m = 1
	for _ = 1, rebirths do
		m = m * 2
	end
	if m > 8 then
		m = 8
	end
	return m
end

local function festivalMult()
	if currentEvent == "Festival" and now() < eventEndsAt then
		return 2
	end
	return 1
end

local function goldenBoost()
	return currentEvent == "Golden Hour" and now() < eventEndsAt
end

local function conveyorInterval()
	if currentEvent == "Rush Hour" and now() < eventEndsAt then
		return 6
	end
	return 8
end

local function newPlayerData()
	return {
		cash = START_CASH,
		pile = 0,
		rebirth = 0,
		placed = {},
		carrying = nil,
		pendingCarry = nil,
		missionStep = 1,
		totalCollected = 0,
		lockUntil = 0,
		slapLevel = 1,
		speedLevel = 0,
		baseName = "",
		fused = 0,
		stolen = 0,
	}
end

local function loadData(player)
	local d = newPlayerData()
	if STORE then
		local ok, saved = pcall(function()
			return STORE:GetAsync("player_" .. player.UserId)
		end)
		if ok and type(saved) == "table" then
			if type(saved.cash) == "number" then
				d.cash = saved.cash
			end
			if type(saved.rebirth) == "number" then
				d.rebirth = saved.rebirth
			end
			if type(saved.placed) == "table" then
				d.placed = saved.placed
			end
			if type(saved.missionStep) == "number" then
				d.missionStep = saved.missionStep
			end
			if type(saved.totalCollected) == "number" then
				d.totalCollected = saved.totalCollected
			end
			if type(saved.slapLevel) == "number" then
				d.slapLevel = saved.slapLevel
			end
			if type(saved.speedLevel) == "number" then
				d.speedLevel = saved.speedLevel
			end
		end
	end
	return d
end

local function saveData(player)
	local d = data[player]
	if not d or not STORE then
		return
	end
	local snapshot = {
		cash = d.cash,
		rebirth = d.rebirth,
		placed = d.placed,
		missionStep = d.missionStep,
		totalCollected = d.totalCollected,
		slapLevel = d.slapLevel,
		speedLevel = d.speedLevel,
	}
	pcall(function()
		STORE:SetAsync("player_" .. player.UserId, snapshot)
	end)
end

local function unlockedPads(d)
	local n = BASE_UNLOCK_START + d.rebirth * 2
	if n > BASE_PADS then
		n = BASE_PADS
	end
	return n
end

local function incomePerSecond(player)
	local d = data[player]
	if not d then
		return 0
	end
	local total = 0
	for _, slot in pairs(d.placed) do
		local char = Catalog.find(slot.id)
		if char then
			total += char.income * Catalog.mutationMult(slot.mutation or "None")
		end
	end
	return math.floor(total * rebirthMult(d.rebirth) * festivalMult())
end

-- Build the floating 3D model for one brainrot. Used on the conveyor,
-- on base pads, as a carried pet and as a dropped pickup.
local function buildBrainrotModel(char, mutation, priceText)
	local model = Instance.new("Model")
	model.Name = char.id
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(2.2, 2.2, 2.2)
	body.Color = char.color
	body.Material = Enum.Material.SmoothPlastic
	body.Anchored = true
	body.CanCollide = false
	body.Parent = model
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1.4, 1.2, 1.4)
	head.Color = char.color
	head.Material = Enum.Material.SmoothPlastic
	head.Anchored = true
	head.CanCollide = false
	head.Position = Vector3.new(0, 1.7, 0)
	head.Parent = model
	local eyeL = Instance.new("Part")
	eyeL.Name = "EyeL"
	eyeL.Size = Vector3.new(0.3, 0.4, 0.2)
	eyeL.Color = Color3.fromRGB(20, 20, 20)
	eyeL.Anchored = true
	eyeL.CanCollide = false
	eyeL.Position = Vector3.new(-0.35, 1.8, 0.75)
	eyeL.Parent = model
	local eyeR = eyeL:Clone()
	eyeR.Name = "EyeR"
	eyeR.Position = Vector3.new(0.35, 1.8, 0.75)
	eyeR.Parent = model
	model.PrimaryPart = body
	local gui = Instance.new("BillboardGui")
	gui.Name = "Card"
	gui.Size = UDim2.fromOffset(140, 56)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3.4, 0)
	gui.AlwaysOnTop = true
	gui.Parent = body
	local label = Instance.new("TextLabel")
	label.Name = "CardText"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(15, 23, 42)
	label.BackgroundTransparency = 0.15
	label.BorderSizePixel = 0
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	local star = Catalog.mutationStar(mutation or "None")
	local mut = ""
	if (mutation or "None") ~= "None" then
		mut = " " .. star .. " " .. mutation
	end
	label.Text = char.name .. mut .. "\n" .. char.rarity .. " | $" .. tostring(priceText or char.price) .. " | $" .. tostring(char.income) .. "/dtk"
	label.Parent = gui
	return model
end

local function clearConveyorSlot(i)
	local slot = conveyor[i]
	if slot and slot.model then
		slot.model:Destroy()
	end
	conveyor[i] = nil
end

local function weightedPick()
	local roll = math.random()
	if roll < 0.55 then
		local pool = Catalog.byRarity("Common")
		return pool[math.random(1, #pool)]
	elseif roll < 0.80 then
		local pool = Catalog.byRarity("Rare")
		return pool[math.random(1, #pool)]
	elseif roll < 0.92 then
		local pool = Catalog.byRarity("Epic")
		return pool[math.random(1, #pool)]
	elseif roll < 0.98 then
		local pool = Catalog.byRarity("Legendary")
		return pool[math.random(1, #pool)]
	else
		local pool = Catalog.byRarity("Mythic")
		return pool[math.random(1, #pool)]
	end
end

local function conveyorHasCheap()
	for i = 1, CONVEYOR_SLOTS do
		local s = conveyor[i]
		if s then
			local c = Catalog.find(s.id)
			if c and c.price <= 100 then
				return true
			end
		end
	end
	return false
end

local function spawnIntoSlot(i, forceCheap)
	local char
	if forceCheap then
		local cheap = Catalog.cheapOnes()
		char = cheap[math.random(1, #cheap)]
	else
		char = weightedPick()
	end
	local mutation = Catalog.rollMutation(goldenBoost())
	local belt = Workspace:FindFirstChild("Conveyor")
	local slotPad = nil
	if belt then
		slotPad = belt:FindFirstChild("Slot" .. tostring(i))
	end
	clearConveyorSlot(i)
	local model = buildBrainrotModel(char, mutation, char.price)
	if slotPad then
		model:PivotTo(slotPad.CFrame * CFrame.new(0, 1.6, 0))
	else
		model:PivotTo(CFrame.new(-15 + (i - 1) * 6, 3.6, -20))
	end
	model.Parent = Workspace
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "BELI $" .. tostring(char.price)
	prompt.ObjectText = char.name
	prompt.HoldDuration = 0.8
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = model.PrimaryPart
	prompt.Triggered:Connect(function(player)
		buyBrainrot(player, i)
	end)
	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance = 20
	click.Parent = model.PrimaryPart
	click.MouseClick:Connect(function(player)
		buyBrainrot(player, i)
	end)
	conveyor[i] = { id = char.id, mutation = mutation, model = model }
	table.insert(conveyorOrder, i)
end

local function refillConveyor()
	for i = 1, CONVEYOR_SLOTS do
		if not conveyor[i] then
			local forceCheap = (i == 1 and not conveyorHasCheap())
			spawnIntoSlot(i, forceCheap)
		end
	end
	if not conveyorHasCheap() then
		spawnIntoSlot(1, true)
	end
end

-- Replace the OLDEST slot, so a rare pity pull is never eaten by the refresh.
local function refreshOldestSlot()
	local oldest = nil
	for _, i in ipairs(conveyorOrder) do
		if conveyor[i] then
			oldest = i
			break
		end
	end
	if not oldest then
		refillConveyor()
		return
	end
	table.remove(conveyorOrder, 1)
	local forceCheap = false
	clearConveyorSlot(oldest)
	if not conveyorHasCheap() then
		forceCheap = true
	end
	spawnIntoSlot(oldest, forceCheap)
end

local function advanceMission(player, trigger)
	local d = data[player]
	if not d then
		return
	end
	local step = d.missionStep
	if step > 5 then
		return
	end
	local done = false
	if step == 1 and trigger == "buy" then
		done = true
	elseif step == 2 and trigger == "place" then
		done = true
	elseif step == 3 and trigger == "collect" and d.totalCollected >= 500 then
		done = true
	elseif step == 4 and (trigger == "steal" or trigger == "fuse") then
		done = true
	elseif step == 5 and trigger == "rebirth" then
		done = true
	end
	if done then
		d.cash += MISSION_BONUS[step]
		d.missionStep = step + 1
	end
end

local function attachCarry(player, brainrot)
	local d = data[player]
	if not d then
		return
	end
	d.carrying = brainrot
	local character = player.Character
	if not character then
		return
	end
	local old = character:FindFirstChild("CarryPart")
	if old then
		old:Destroy()
	end
	local char = Catalog.find(brainrot.id)
	if not char then
		return
	end
	local part = Instance.new("Part")
	part.Name = "CarryPart"
	part.Size = Vector3.new(1.6, 1.6, 1.6)
	part.Color = char.color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = false
	part.CanCollide = false
	part.Parent = character
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = part
	local head = character:FindFirstChild("Head")
	if head then
		weld.Part1 = head
		part.CFrame = head.CFrame * CFrame.new(0, 1.6, 0)
	end
	weld.Parent = part
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = 16 + (d.speedLevel or 0) * 2
	end
end

local function detachCarry(player)
	local d = data[player]
	if d then
		d.carrying = nil
	end
	local character = player.Character
	if character then
		local old = character:FindFirstChild("CarryPart")
		if old then
			old:Destroy()
		end
	end
end

function buyBrainrot(player, slotIndex)
	local d = data[player]
	if not d or d.carrying then
		return
	end
	local slot = conveyor[slotIndex]
	if not slot then
		return
	end
	local char = Catalog.find(slot.id)
	if not char or d.cash < char.price then
		return
	end
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		local belt = Workspace:FindFirstChild("Conveyor")
		if belt then
			local pad = belt:FindFirstChild("Slot" .. tostring(slotIndex))
			if pad and (root.Position - pad.Position).Magnitude > 30 then
				return
			end
		end
	end
	d.cash -= char.price
	local bought = { id = slot.id, mutation = slot.mutation }
	clearConveyorSlot(slotIndex)
	for idx, v in ipairs(conveyorOrder) do
		if v == slotIndex then
			table.remove(conveyorOrder, idx)
			break
		end
	end
	attachCarry(player, bought)
	advanceMission(player, "buy")
	task.spawn(function()
		task.wait(1)
		spawnIntoSlot(slotIndex, false)
		if not conveyorHasCheap() then
			spawnIntoSlot(1, true)
		end
	end)
end

local function baseFolder(player)
	local d = data[player]
	if not d then
		return nil
	end
	return Workspace:FindFirstChild(d.baseName)
end

local function padPart(player, padIndex)
	local folder = baseFolder(player)
	if not folder then
		return nil
	end
	return folder:FindFirstChild("Pad" .. tostring(padIndex))
end

local function clearPadModel(player, padIndex)
	local pad = padPart(player, padIndex)
	if not pad then
		return
	end
	for _, child in ipairs(pad:GetChildren()) do
		if child:IsA("Model") then
			child:Destroy()
		end
	end
end

local function clearAllPadModels(player)
	for i = 1, BASE_PADS do
		clearPadModel(player, i)
	end
end

local function placeBrainrot(player, padIndex)
	local d = data[player]
	if not d or not d.carrying then
		return
	end
	if padIndex < 1 or padIndex > unlockedPads(d) then
		return
	end
	if d.placed[padIndex] then
		return
	end
	local pad = padPart(player, padIndex)
	if not pad then
		return
	end
	local character = player.Character
	if character then
		local root = character:FindFirstChild("HumanoidRootPart")
		if root and (root.Position - pad.Position).Magnitude > 25 then
			return
		end
	end
	local brainrot = d.carrying
	local char = Catalog.find(brainrot.id)
	if not char then
		return
	end
	d.placed[padIndex] = { id = brainrot.id, mutation = brainrot.mutation }
	detachCarry(player)
	local model = buildBrainrotModel(char, brainrot.mutation, char.price)
	model:PivotTo(pad.CFrame * CFrame.new(0, 1.6, 0))
	model.Parent = pad
	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance = 25
	click.Parent = model.PrimaryPart
	click.MouseClick:Connect(function(clicker)
		if clicker ~= player then
			stealBrainrot(clicker, player, padIndex)
		end
	end)
	advanceMission(player, "place")
end

local function collectCash(player)
	local d = data[player]
	if not d or d.pile <= 0 then
		return
	end
	d.cash += d.pile
	d.totalCollected += d.pile
	d.pile = 0
	advanceMission(player, "collect")
end

local function lockBase(player)
	local d = data[player]
	if not d or d.cash < LOCK_COST then
		return
	end
	if now() < d.lockUntil then
		return
	end
	d.cash -= LOCK_COST
	d.lockUntil = now() + LOCK_SECONDS
end

local function fuseBrainrots(player, padA, padB)
	local d = data[player]
	if not d or not padA or not padB or padA == padB then
		return
	end
	local a = d.placed[padA]
	local b = d.placed[padB]
	if not a or not b then
		return
	end
	local charA = Catalog.find(a.id)
	local charB = Catalog.find(b.id)
	if not charA or not charB or charA.rarity ~= charB.rarity then
		return
	end
	local order = { "Common", "Rare", "Epic", "Legendary", "Mythic" }
	local nextRarity = charA.rarity
	for i, r in ipairs(order) do
		if r == charA.rarity and i < #order then
			nextRarity = order[i + 1]
			break
		end
	end
	local pool = Catalog.byRarity(nextRarity)
	local picked = pool[math.random(1, #pool)]
	clearPadModel(player, padA)
	clearPadModel(player, padB)
	d.placed[padA] = { id = picked.id, mutation = Catalog.rollMutation(goldenBoost()) }
	d.placed[padB] = nil
	local pad = padPart(player, padA)
	if pad then
		local model = buildBrainrotModel(picked, d.placed[padA].mutation, picked.price)
		model:PivotTo(pad.CFrame * CFrame.new(0, 1.6, 0))
		model.Parent = pad
		local click = Instance.new("ClickDetector")
		click.MaxActivationDistance = 25
		click.Parent = model.PrimaryPart
		click.MouseClick:Connect(function(clicker)
			if clicker ~= player then
				stealBrainrot(clicker, player, padA)
			end
		end)
	end
	d.fused += 1
	advanceMission(player, "fuse")
end

local function doRebirth(player)
	local d = data[player]
	if not d or d.cash < REBIRTH_COST then
		return
	end
	d.cash = START_CASH
	d.pile = 0
	d.rebirth += 1
	clearAllPadModels(player)
	d.placed = {}
	detachCarry(player)
	advanceMission(player, "rebirth")
end

function stealBrainrot(stealer, victim, padIndex)
	local sd = data[stealer]
	local vd = data[victim]
	if not sd or not vd or stealer == victim or sd.carrying then
		return
	end
	if now() < vd.lockUntil then
		return
	end
	local slot = vd.placed[padIndex]
	if not slot then
		return
	end
	local pad = nil
	local folder = Workspace:FindFirstChild(vd.baseName)
	if folder then
		pad = folder:FindFirstChild("Pad" .. tostring(padIndex))
	end
	local character = stealer.Character
	if character and pad then
		local root = character:FindFirstChild("HumanoidRootPart")
		if root and (root.Position - pad.Position).Magnitude > 15 then
			return
		end
	end
	vd.placed[padIndex] = nil
	clearPadModel(victim, padIndex)
	attachCarry(stealer, slot)
	sd.stolen += 1
	advanceMission(stealer, "steal")
end

local function dropCarry(player)
	local d = data[player]
	if not d or not d.carrying then
		return
	end
	local brainrot = d.carrying
	detachCarry(player)
	local character = player.Character
	local pos = Vector3.new(0, 3, 0)
	if character then
		local root = character:FindFirstChild("HumanoidRootPart")
		if root then
			pos = root.Position + Vector3.new(0, 1, 0)
		end
	end
	local char = Catalog.find(brainrot.id)
	if not char then
		return
	end
	local model = buildBrainrotModel(char, brainrot.mutation, char.price)
	model:PivotTo(CFrame.new(pos))
	model.Parent = Workspace
	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance = 20
	click.Parent = model.PrimaryPart
	click.MouseClick:Connect(function(clicker)
		pickupDrop(clicker, model)
	end)
	table.insert(dropModels, { model = model, brainrot = brainrot, born = now() })
end

function pickupDrop(player, model)
	local d = data[player]
	if not d or d.carrying then
		return
	end
	for i, drop in ipairs(dropModels) do
		if drop.model == model then
			attachCarry(player, drop.brainrot)
			model:Destroy()
			table.remove(dropModels, i)
			return
		end
	end
end

local function slapPlayer(attacker, victim)
	local ad = data[attacker]
	local vd = data[victim]
	if not ad or not vd or attacker == victim then
		return
	end
	local aChar = attacker.Character
	local vChar = victim.Character
	if not aChar or not vChar then
		return
	end
	local aRoot = aChar:FindFirstChild("HumanoidRootPart")
	local vRoot = vChar:FindFirstChild("HumanoidRootPart")
	if not aRoot or not vRoot then
		return
	end
	local reach = 8 + (ad.slapLevel or 1) * 2
	if (aRoot.Position - vRoot.Position).Magnitude > reach then
		return
	end
	local vHumanoid = vChar:FindFirstChildOfClass("Humanoid")
	if vHumanoid then
		local dir = (vRoot.Position - aRoot.Position).Unit
		vRoot.AssemblyLinearVelocity = dir * 30 + Vector3.new(0, 18, 0)
	end
	if vd.carrying then
		dropCarry(victim)
	end
end

local function buyGear(player, gearName)
	local d = data[player]
	if not d then
		return
	end
	if gearName == "slap" then
		local cost = 500 * (d.slapLevel or 1)
		if d.cash >= cost then
			d.cash -= cost
			d.slapLevel = (d.slapLevel or 1) + 1
		end
	elseif gearName == "speed" then
		local cost = 800 * ((d.speedLevel or 0) + 1)
		if d.cash >= cost then
			d.cash -= cost
			d.speedLevel = (d.speedLevel or 0) + 1
			local character = player.Character
			if character then
				local humanoid = character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					humanoid.WalkSpeed = 16 + d.speedLevel * 2
				end
			end
		end
	end
end

BuyBrainrot.OnServerEvent:Connect(function(player, slotIndex)
	buyBrainrot(player, slotIndex)
end)
PlaceBrainrot.OnServerEvent:Connect(function(player, padIndex)
	placeBrainrot(player, tonumber(padIndex) or 0)
end)
CollectCash.OnServerEvent:Connect(function(player)
	collectCash(player)
end)
LockBase.OnServerEvent:Connect(function(player)
	lockBase(player)
end)
FuseBrainrots.OnServerEvent:Connect(function(player, padA, padB)
	fuseBrainrots(player, tonumber(padA) or 0, tonumber(padB) or 0)
end)
DoRebirth.OnServerEvent:Connect(function(player)
	doRebirth(player)
end)
SlapPlayer.OnServerEvent:Connect(function(player, victim)
	if typeof(victim) == "Instance" and victim:IsA("Player") then
		slapPlayer(player, victim)
	end
end)
StealBrainrot.OnServerEvent:Connect(function(player, victim, padIndex)
	if typeof(victim) == "Instance" and victim:IsA("Player") then
		stealBrainrot(player, victim, tonumber(padIndex) or 0)
	end
end)
BuyGear.OnServerEvent:Connect(function(player, gearName)
	buyGear(player, gearName)
end)
PickupDrop.OnServerEvent:Connect(function(player, model)
	if typeof(model) == "Instance" then
		pickupDrop(player, model)
	end
end)

-- World labels: 3D title, fuse sign, base name plates, leaderboard board.
local function addSurfaceText(part, text, size, color)
	if not part then
		return
	end
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.AlwaysOnTop = false
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.Parent = gui
end

task.spawn(function()
	task.wait(1)
	local title = Workspace:FindFirstChild("TitleSign")
	addSurfaceText(title, "BRAINROT NIGHT MARKET", 40, Color3.fromRGB(163, 230, 53))
	local fuse = Workspace:FindFirstChild("FuseMachine")
	if fuse then
		local top = fuse:FindFirstChild("FuseTop")
		addSurfaceText(top, "FUSE MACHINE", 30, Color3.fromRGB(255, 210, 60))
	end
	local board = Workspace:FindFirstChild("Leaderboard")
	if board then
		local face = board:FindFirstChild("BoardFace")
		addSurfaceText(face, "TOP 5", 30, Color3.fromRGB(255, 255, 255))
	end
end)

local function topFive()
	local rows = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local d = data[player]
		if d then
			table.insert(rows, { name = player.DisplayName, cash = d.cash })
		end
	end
	table.sort(rows, function(a, b)
		return a.cash > b.cash
	end)
	while #rows > 5 do
		table.remove(rows)
	end
	return rows
end

local function sendState(player)
	local d = data[player]
	if not d then
		return
	end
	local conveyorList = {}
	for i = 1, CONVEYOR_SLOTS do
		local s = conveyor[i]
		if s then
			local c = Catalog.find(s.id)
			if c then
				table.insert(conveyorList, {
					slot = i,
					id = s.id,
					name = c.name,
					rarity = c.rarity,
					price = c.price,
					income = c.income,
					mutation = s.mutation,
				})
			end
		end
	end
	local placedList = {}
	for i = 1, BASE_PADS do
		local slot = d.placed[i]
		if slot then
			local c = Catalog.find(slot.id)
			if c then
				table.insert(placedList, { pad = i, id = slot.id, name = c.name, mutation = slot.mutation })
			end
		end
	end
	local eventLeft = 0
	if now() < eventEndsAt then
		eventLeft = eventEndsAt - now()
	end
	local lockLeft = 0
	if now() < d.lockUntil then
		lockLeft = d.lockUntil - now()
	end
	StateUpdate:FireClient(player, {
		cash = d.cash,
		pile = d.pile,
		income = incomePerSecond(player),
		rebirth = d.rebirth,
		missionStep = d.missionStep,
		missionText = MISSION_TEXT[math.min(d.missionStep, 6)],
		baseCount = #placedList,
		unlockedPads = unlockedPads(d),
		carrying = d.carrying,
		eventName = currentEvent,
		eventLeft = eventLeft,
		lockLeft = lockLeft,
		conveyor = conveyorList,
		placed = placedList,
		top5 = topFive(),
		slapLevel = d.slapLevel,
		speedLevel = d.speedLevel,
		totalCollected = d.totalCollected,
		baseName = d.baseName,
	})
end

local function assignBase(player)
	local taken = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local d = data[p]
		if d and d.baseName ~= "" then
			taken[d.baseName] = true
		end
	end
	for i = 1, 4 do
		local name = "Base" .. tostring(i)
		if not taken[name] then
			return name
		end
	end
	return "Base1"
end

local function restorePlacedModels(player)
	local d = data[player]
	if not d then
		return
	end
	for padIndex, slot in pairs(d.placed) do
		local char = Catalog.find(slot.id)
		local pad = padPart(player, padIndex)
		if char and pad then
			local model = buildBrainrotModel(char, slot.mutation, char.price)
			model:PivotTo(pad.CFrame * CFrame.new(0, 1.6, 0))
			model.Parent = pad
			local click = Instance.new("ClickDetector")
			click.MaxActivationDistance = 25
			click.Parent = model.PrimaryPart
			click.MouseClick:Connect(function(clicker)
				if clicker ~= player then
					stealBrainrot(clicker, player, padIndex)
				end
			end)
		end
	end
end

Players.PlayerAdded:Connect(function(player)
	data[player] = loadData(player)
	data[player].baseName = assignBase(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player
	local cashValue = Instance.new("IntValue")
	cashValue.Name = "Cash"
	cashValue.Value = data[player].cash
	cashValue.Parent = leaderstats
	local rebirthValue = Instance.new("IntValue")
	rebirthValue.Name = "Rebirth"
	rebirthValue.Value = data[player].rebirth
	rebirthValue.Parent = leaderstats
	local base = Workspace:FindFirstChild(data[player].baseName)
	if base then
		local sign = base:FindFirstChild("BaseSign")
		if sign then
			addSurfaceText(sign, player.DisplayName .. " BASE", 30, Color3.fromRGB(163, 230, 53))
		end
	end
	player.CharacterAdded:Connect(function(character)
		task.wait(0.5)
		local d = data[player]
		if not d then
			return
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.WalkSpeed = 16 + (d.speedLevel or 0) * 2
		end
		-- Dying while carrying returns the brainrot to your hands on respawn.
		if d.pendingCarry then
			local carry = d.pendingCarry
			d.pendingCarry = nil
			attachCarry(player, carry)
		elseif d.carrying then
			attachCarry(player, d.carrying)
		end
		local hum = character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.Died:Connect(function()
				local dd = data[player]
				if dd and dd.carrying then
					dd.pendingCarry = dd.carrying
					dd.carrying = nil
				end
			end)
		end
	end)
	task.spawn(function()
		task.wait(1)
		restorePlacedModels(player)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	saveData(player)
	clearAllPadModels(player)
	data[player] = nil
end)

-- Income tick: placed brainrots fill the pile every second.
task.spawn(function()
	while true do
		task.wait(1)
		for _, player in ipairs(Players:GetPlayers()) do
			local d = data[player]
			if d then
				d.pile += incomePerSecond(player)
				local leaderstats = player:FindFirstChild("leaderstats")
				if leaderstats then
					local cashValue = leaderstats:FindFirstChild("Cash")
					if cashValue then
						cashValue.Value = d.cash
					end
					local rebirthValue = leaderstats:FindFirstChild("Rebirth")
					if rebirthValue then
						rebirthValue.Value = d.rebirth
					end
				end
				sendState(player)
			end
		end
		for i = #dropModels, 1, -1 do
			if now() - dropModels[i].born > 120 then
				dropModels[i].model:Destroy()
				table.remove(dropModels, i)
			end
		end
	end
end)

-- Conveyor refresh: replace the oldest slot on a timer.
task.spawn(function()
	while true do
		task.wait(conveyorInterval())
		refreshOldestSlot()
	end
end)

-- Timed events rotate: Rush Hour, Golden Hour, Festival.
task.spawn(function()
	while true do
		task.wait(1)
		if now() >= eventEndsAt and now() >= nextEventAt then
			eventIndex = (eventIndex % #EVENT_CYCLE) + 1
			currentEvent = EVENT_CYCLE[eventIndex]
			eventEndsAt = now() + EVENT_SECONDS[currentEvent]
			nextEventAt = eventEndsAt + 75
		elseif now() >= eventEndsAt and currentEvent ~= "Tenang" then
			currentEvent = "Tenang"
		end
	end
end)

-- Autosave every minute.
task.spawn(function()
	while true do
		task.wait(60)
		for _, player in ipairs(Players:GetPlayers()) do
			saveData(player)
		end
	end
end)

refillConveyor()
print("Brainrot Night Market server ready: 30 brainrots, 4 bases, conveyor live.")
