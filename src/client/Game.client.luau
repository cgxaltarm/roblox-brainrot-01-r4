-- Brainrot Night Market: client HUD and input.
-- Money top-right, one timer line, one mission line, slim MY BASE panel,
-- MENU / LOCK BASE / COLLECT buttons, 7-tab menu, conveyor strip,
-- pad KLIK hints while carrying, F to slap, click a pad to place.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Catalog = require(ReplicatedStorage:WaitForChild("Catalog"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local StateUpdate = Remotes:WaitForChild("StateUpdate")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local state = {
	cash = 100,
	pile = 0,
	income = 0,
	rebirth = 0,
	missionStep = 1,
	missionText = "",
	baseCount = 0,
	unlockedPads = 4,
	carrying = nil,
	eventName = "Tenang",
	eventLeft = 0,
	lockLeft = 0,
	conveyor = {},
	placed = {},
	top5 = {},
	slapLevel = 1,
	speedLevel = 0,
	totalCollected = 0,
	baseName = "",
}

local function money(n)
	local s = tostring(math.floor(n))
	local out = ""
	while #s > 3 do
		out = "," .. string.sub(s, -3) .. out
		s = string.sub(s, 1, -4)
	end
	return "$" .. s .. out
end

local gui = Instance.new("ScreenGui")
gui.Name = "NightMarketGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local function makeLabel(parent, name, pos, size, text, textSize, color)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Position = pos
	label.Size = size
	label.BackgroundColor3 = Color3.fromRGB(15, 23, 42)
	label.BackgroundTransparency = 0.2
	label.BorderSizePixel = 0
	label.Text = text
	label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	label.TextSize = textSize
	label.Font = Enum.Font.GothamBold
	label.TextScaled = false
	label.Parent = parent
	return label
end

local function makeButton(parent, name, pos, size, text, color)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Position = pos
	button.Size = size
	button.BackgroundColor3 = color or Color3.fromRGB(163, 230, 53)
	button.BorderSizePixel = 0
	button.Text = text
	button.TextColor3 = Color3.fromRGB(15, 23, 42)
	button.TextSize = 18
	button.Font = Enum.Font.GothamBold
	button.Parent = parent
	return button
end

-- Money, top-right (top-left corner stays clear for Roblox menus).
local moneyLabel = makeLabel(gui, "Money", UDim2.new(1, -220, 0, 10), UDim2.fromOffset(210, 44), "$100", 26, Color3.fromRGB(163, 230, 53))
-- Pile, bottom-left: the Roblox player list (People) covers the top-right,
-- so nothing of ours lives there except the money line itself.
local pileLabel = makeLabel(gui, "Pile", UDim2.new(0, 10, 1, -70), UDim2.fromOffset(210, 26), "Pile: $0", 16, Color3.fromRGB(34, 211, 238))
-- One timer line, top-center. The 3D title sign sits low in the world so it never overlaps this.
local timerLabel = makeLabel(gui, "Timer", UDim2.new(0.5, -190, 0, 10), UDim2.fromOffset(380, 30), "Tenang", 18)
local missionLabel = makeLabel(gui, "Mission", UDim2.new(0.5, -260, 0, 44), UDim2.fromOffset(520, 28), "Misi: beli brainrot pertamamu", 16, Color3.fromRGB(255, 210, 60))
-- Slim MY BASE panel, bottom-left above the pile (clear of the People list).
local basePanel = makeLabel(gui, "MyBase", UDim2.new(0, 10, 1, -236), UDim2.fromOffset(210, 156), "MY BASE 0/8", 18)
basePanel.TextYAlignment = Enum.TextYAlignment.Top

-- Three buttons, bottom-right.
local menuButton = makeButton(gui, "MenuBtn", UDim2.new(1, -330, 1, -60), UDim2.fromOffset(100, 48), "MENU")
local lockButton = makeButton(gui, "LockBtn", UDim2.new(1, -220, 1, -60), UDim2.fromOffset(100, 48), "LOCK BASE", Color3.fromRGB(255, 180, 40))
local collectButton = makeButton(gui, "CollectBtn", UDim2.new(1, -110, 1, -60), UDim2.fromOffset(100, 48), "COLLECT", Color3.fromRGB(34, 211, 238))

-- Conveyor strip along the bottom-center: what is for sale right now.
local strip = Instance.new("Frame")
strip.Name = "ConveyorStrip"
strip.AnchorPoint = Vector2.new(0.5, 1)
strip.Position = UDim2.new(0.5, 0, 1, -70)
strip.Size = UDim2.fromOffset(660, 54)
strip.BackgroundTransparency = 1
strip.Parent = gui
local stripSlots = {}
for i = 1, 6 do
	local slot = makeLabel(strip, "Slot" .. tostring(i), UDim2.new(0, (i - 1) * 112, 0, 0), UDim2.fromOffset(106, 50), "-", 13)
	table.insert(stripSlots, slot)
end

-- Carry hint, center-bottom above the strip.
local carryLabel = makeLabel(gui, "CarryHint", UDim2.new(0.5, -260, 1, -130), UDim2.fromOffset(520, 30), "", 16, Color3.fromRGB(163, 230, 53))
carryLabel.Visible = false

-- MENU panel with 7 tabs.
local menuPanel = Instance.new("Frame")
menuPanel.Name = "MenuPanel"
menuPanel.AnchorPoint = Vector2.new(0.5, 0.5)
menuPanel.Position = UDim2.fromScale(0.5, 0.5)
menuPanel.Size = UDim2.fromOffset(560, 420)
menuPanel.BackgroundColor3 = Color3.fromRGB(15, 23, 42)
menuPanel.BorderColor3 = Color3.fromRGB(163, 230, 53)
menuPanel.BorderSizePixel = 3
menuPanel.Visible = false
menuPanel.Parent = gui

local tabNames = { "GEAR", "BUFF", "INDEX", "MISI", "FUSE", "REBIRTH", "TOP 5" }
local tabButtons = {}
local tabFrames = {}
local activeTab = "GEAR"

for i, tabName in ipairs(tabNames) do
	local button = makeButton(menuPanel, "Tab" .. tabName, UDim2.new(0, (i - 1) * 80 + 4, 0, 6), UDim2.fromOffset(76, 36), tabName, Color3.fromRGB(60, 70, 100))
	table.insert(tabButtons, button)
	local frame = Instance.new("ScrollingFrame")
	frame.Name = "TabFrame" .. tabName
	frame.Position = UDim2.new(0, 8, 0, 50)
	frame.Size = UDim2.new(1, -16, 1, -58)
	frame.BackgroundTransparency = 1
	frame.ScrollBarThickness = 6
	frame.CanvasSize = UDim2.new(0, 0, 0, 600)
	frame.Visible = false
	frame.Parent = menuPanel
	tabFrames[tabName] = frame
end

local function showTab(tabName)
	activeTab = tabName
	for name, frame in pairs(tabFrames) do
		frame.Visible = (name == tabName)
	end
	for _, button in ipairs(tabButtons) do
		if button.Text == tabName then
			button.BackgroundColor3 = Color3.fromRGB(163, 230, 53)
		else
			button.BackgroundColor3 = Color3.fromRGB(60, 70, 100)
		end
	end
end

for _, button in ipairs(tabButtons) do
	button.MouseButton1Click:Connect(function()
		showTab(button.Text)
	end)
end

local function clearFrame(frame)
	for _, child in ipairs(frame:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function tabLine(frame, y, text, color)
	local label = Instance.new("TextLabel")
	label.Position = UDim2.new(0, 4, 0, y)
	label.Size = UDim2.new(1, -12, 0, 26)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	label.TextSize = 16
	label.Font = Enum.Font.GothamBold
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = frame
	return label
end

-- GEAR tab: slap power and walk speed, bought with cash.
local gearFrame = tabFrames["GEAR"]
local slapBuy = makeButton(gearFrame, "SlapBuy", UDim2.new(0, 4, 0, 10), UDim2.fromOffset(520, 44), "SLAP POWER Lv1 — $500")
slapBuy.MouseButton1Click:Connect(function()
	Remotes.BuyGear:FireServer("slap")
end)
local speedBuy = makeButton(gearFrame, "SpeedBuy", UDim2.new(0, 4, 0, 64), UDim2.fromOffset(520, 44), "SPEED +2 — $800")
speedBuy.MouseButton1Click:Connect(function()
	Remotes.BuyGear:FireServer("speed")
end)
tabLine(gearFrame, 120, "Slap: lempar rival sampai jatuhin brainrotnya (tombol F).")
tabLine(gearFrame, 150, "Speed: lari lebih cepat pulang ke base saat bawa curian.")
tabLine(gearFrame, 180, "Coins Shop di pasar juga membuka tab ini.")

-- FUSE tab: pick two of your placed pads, fuse into a higher rarity.
local fuseFrame = tabFrames["FUSE"]
local fusePickA = 0
local fusePickB = 0
local fuseLabelA = tabLine(fuseFrame, 10, "Pilih pad pertama: -")
local fuseLabelB = tabLine(fuseFrame, 40, "Pilih pad kedua: -")
local fusePadButtons = {}
for i = 1, 8 do
	local b = makeButton(fuseFrame, "FusePad" .. tostring(i), UDim2.new(0, ((i - 1) % 4) * 132 + 4, 0, 80 + math.floor((i - 1) / 4) * 50), UDim2.fromOffset(124, 42), "Pad " .. tostring(i))
	b.MouseButton1Click:Connect(function()
		if fusePickA == 0 then
			fusePickA = i
			fuseLabelA.Text = "Pilih pad pertama: Pad " .. tostring(i)
		elseif fusePickB == 0 and i ~= fusePickA then
			fusePickB = i
			fuseLabelB.Text = "Pilih pad kedua: Pad " .. tostring(i)
		else
			fusePickA = i
			fusePickB = 0
			fuseLabelA.Text = "Pilih pad pertama: Pad " .. tostring(i)
			fuseLabelB.Text = "Pilih pad kedua: -"
		end
	end)
	table.insert(fusePadButtons, b)
end
local fuseGo = makeButton(fuseFrame, "FuseGo", UDim2.new(0, 4, 0, 190), UDim2.fromOffset(520, 44), "FUSE! (2 brainrot rarity sama -> rarity atas)", Color3.fromRGB(255, 180, 40))
fuseGo.MouseButton1Click:Connect(function()
	if fusePickA > 0 and fusePickB > 0 then
		Remotes.FuseBrainrots:FireServer(fusePickA, fusePickB)
		fusePickA = 0
		fusePickB = 0
		fuseLabelA.Text = "Pilih pad pertama: -"
		fuseLabelB.Text = "Pilih pad kedua: -"
	end
end)
tabLine(fuseFrame, 244, "Fuse Machine di pasar juga membuka tab ini.")

-- REBIRTH tab.
local rebirthFrame = tabFrames["REBIRTH"]
local rebirthInfo = tabLine(rebirthFrame, 10, "Rebirth: 0x — reset cash & base, income x2 selamanya.")
local rebirthGo = makeButton(rebirthFrame, "RebirthGo", UDim2.new(0, 4, 0, 50), UDim2.fromOffset(520, 44), "REBIRTH — $5000", Color3.fromRGB(255, 60, 120))
rebirthGo.MouseButton1Click:Connect(function()
	Remotes.DoRebirth:FireServer()
end)
tabLine(rebirthFrame, 110, "Tiap rebirth membuka +2 pad (maks 8).")
tabLine(rebirthFrame, 140, "Pad terkunci bertuliskan 'opens via rebirth'.")

menuButton.MouseButton1Click:Connect(function()
	menuPanel.Visible = not menuPanel.Visible
	if menuPanel.Visible then
		showTab(activeTab)
	end
end)
lockButton.MouseButton1Click:Connect(function()
	Remotes.LockBase:FireServer()
end)
collectButton.MouseButton1Click:Connect(function()
	Remotes.CollectCash:FireServer()
end)

-- Clicking world signs opens the matching tab: Fuse Machine -> FUSE,
-- Leaderboard board -> TOP 5, Coins Shop -> GEAR.
mouse.Button1Down:Connect(function()
	local target = mouse.Target
	if not target then
		return
	end
	local ancestor = target.Parent
	if ancestor then
		local name = ancestor.Name
		if name == "FuseMachine" or target.Name == "FuseTop" then
			menuPanel.Visible = true
			showTab("FUSE")
			return
		elseif name == "Leaderboard" or target.Name == "BoardFace" then
			menuPanel.Visible = true
			showTab("TOP 5")
			return
		elseif name == "CoinsShop" or target.Name == "CoinsTop" then
			menuPanel.Visible = true
			showTab("GEAR")
			return
		end
	end
	-- Clicking one of your own pads while carrying places the brainrot.
	if state.carrying and state.baseName ~= "" then
		local base = Workspace:FindFirstChild(state.baseName)
		if base and target.Parent == base and string.sub(target.Name, 1, 3) == "Pad" then
			local padIndex = tonumber(string.sub(target.Name, 4))
			if padIndex then
				Remotes.PlaceBrainrot:FireServer(padIndex)
			end
		end
	end
end)

-- F to slap the nearest player.
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.F then
		local myChar = player.Character
		if not myChar then
			return
		end
		local myRoot = myChar:FindFirstChild("HumanoidRootPart")
		if not myRoot then
			return
		end
		local nearest = nil
		local nearestDist = 14
		for _, other in ipairs(Players:GetPlayers()) do
			if other ~= player and other.Character then
				local root = other.Character:FindFirstChild("HumanoidRootPart")
				if root then
					local dist = (root.Position - myRoot.Position).Magnitude
					if dist < nearestDist then
						nearestDist = dist
						nearest = other
					end
				end
			end
		end
		if nearest then
			Remotes.SlapPlayer:FireServer(nearest)
		end
	end
end)

-- KLIK billboards on your own pads while you carry something.
local klikGuis = {}
local function refreshKlik()
	for _, g in ipairs(klikGuis) do
		g:Destroy()
	end
	klikGuis = {}
	if not state.carrying or state.baseName == "" then
		return
	end
	local base = Workspace:FindFirstChild(state.baseName)
	if not base then
		return
	end
	for i = 1, state.unlockedPads do
		local pad = base:FindFirstChild("Pad" .. tostring(i))
		if pad then
			local billboard = Instance.new("BillboardGui")
			billboard.Size = UDim2.fromOffset(90, 34)
			billboard.StudsOffsetWorldSpace = Vector3.new(0, 2, 0)
			billboard.AlwaysOnTop = true
			billboard.Parent = pad
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundColor3 = Color3.fromRGB(163, 230, 53)
			label.TextColor3 = Color3.fromRGB(15, 23, 42)
			label.Text = "KLIK"
			label.TextSize = 22
			label.Font = Enum.Font.GothamBlack
			label.Parent = billboard
			table.insert(klikGuis, billboard)
		end
	end
end

local function refreshTabs()
	-- BUFF tab: multipliers and the live event.
	local buffFrame = tabFrames["BUFF"]
	clearFrame(buffFrame)
	local mult = 1
	for _ = 1, state.rebirth do
		mult = mult * 2
	end
	if mult > 8 then
		mult = 8
	end
	tabLine(buffFrame, 10, "Rebirth multiplier: x" .. tostring(mult) .. " (Rebirth " .. tostring(state.rebirth) .. "x)")
	tabLine(buffFrame, 40, "Event sekarang: " .. state.eventName .. " (" .. tostring(state.eventLeft) .. " dtk)")
	tabLine(buffFrame, 70, "Festival = income 2x. Golden Hour = lebih banyak Golden.")
	tabLine(buffFrame, 100, "Rush Hour = conveyor refresh tiap 6 dtk.")
	tabLine(buffFrame, 130, "Income kamu: " .. money(state.income) .. "/dtk")
	-- INDEX tab: all 30 brainrots.
	local indexFrame = tabFrames["INDEX"]
	clearFrame(indexFrame)
	local y = 10
	for _, char in ipairs(Catalog.CHARACTERS) do
		local color = Catalog.RARITY_COLOR[char.rarity] or Color3.fromRGB(255, 255, 255)
		tabLine(indexFrame, y, char.name .. " — " .. char.rarity .. " — $" .. tostring(char.price) .. " — $" .. tostring(char.income) .. "/dtk", color)
		y += 28
	end
	indexFrame.CanvasSize = UDim2.new(0, 0, 0, y + 10)
	-- MISI tab: 5 chained quests.
	local misiFrame = tabFrames["MISI"]
	clearFrame(misiFrame)
	local missionNames = {
		"Beli brainrot pertamamu (+$100)",
		"Letakkan brainrot di basemu (+$200)",
		"Kumpulkan total $500 (+$300)",
		"Curi dari rival ATAU fuse 2 brainrot (+$500)",
		"Rebirth sekali (+$1000)",
	}
	local y2 = 10
	for i, text in ipairs(missionNames) do
		local mark = "○"
		local color = Color3.fromRGB(255, 255, 255)
		if i < state.missionStep then
			mark = "✓"
			color = Color3.fromRGB(163, 230, 53)
		elseif i == state.missionStep then
			mark = "→"
			color = Color3.fromRGB(255, 210, 60)
		end
		tabLine(misiFrame, y2, mark .. " " .. text, color)
		y2 += 28
	end
	tabLine(misiFrame, y2 + 10, "Total terkumpul: " .. money(state.totalCollected) .. " / $500 (misi 3)")
	-- TOP 5 tab.
	local topFrame = tabFrames["TOP 5"]
	clearFrame(topFrame)
	local y3 = 10
	if #state.top5 == 0 then
		tabLine(topFrame, y3, "Belum ada pemain lain — kamu nomor 1!")
	else
		for i, row in ipairs(state.top5) do
			tabLine(topFrame, y3, tostring(i) .. ". " .. row.name .. " — " .. money(row.cash), Color3.fromRGB(255, 210, 60))
			y3 += 28
		end
	end
	-- REBIRTH info line.
	rebirthInfo.Text = "Rebirth: " .. tostring(state.rebirth) .. "x — multiplier x" .. tostring(mult) .. " — pad terbuka " .. tostring(state.unlockedPads) .. "/8."
	-- GEAR button labels with live prices.
	slapBuy.Text = "SLAP POWER Lv" .. tostring(state.slapLevel) .. " — $" .. tostring(500 * state.slapLevel)
	speedBuy.Text = "SPEED Lv" .. tostring(state.speedLevel) .. " +2 — $" .. tostring(800 * (state.speedLevel + 1))
end

StateUpdate.OnClientEvent:Connect(function(s)
	for key, value in pairs(s) do
		state[key] = value
	end
	moneyLabel.Text = money(state.cash)
	pileLabel.Text = "Pile: " .. money(state.pile) .. "  |  +" .. money(state.income) .. "/dtk"
	if state.eventLeft > 0 then
		timerLabel.Text = state.eventName .. " — " .. tostring(state.eventLeft) .. " dtk"
	else
		timerLabel.Text = "Tenang — event berikutnya segera"
	end
	missionLabel.Text = "MISI " .. state.missionText
	local baseText = "MY BASE " .. tostring(state.baseCount) .. "/" .. tostring(state.unlockedPads)
	if state.lockLeft > 0 then
		baseText = baseText .. "\n🔒 Terkunci " .. tostring(state.lockLeft) .. " dtk"
	else
		baseText = baseText .. "\nLock: $1500 (tombol LOCK BASE)"
	end
	for _, slot in ipairs(state.placed) do
		local char = Catalog.find(slot.id)
		if char then
			baseText = baseText .. "\n• " .. char.name
		end
	end
	basePanel.Text = baseText
	if state.carrying then
		local char = Catalog.find(state.carrying.id)
		if char then
			carryLabel.Visible = true
			carryLabel.Text = "Membawa: " .. char.name .. " — klik pad di basemu (KLIK menyala)!"
		end
	else
		carryLabel.Visible = false
	end
	for i, slotLabel in ipairs(stripSlots) do
		local found = nil
		for _, item in ipairs(state.conveyor) do
			if item.slot == i then
				found = item
				break
			end
		end
		if found then
			local star = Catalog.mutationStar(found.mutation or "None")
			slotLabel.Text = found.name .. " " .. star .. "\n$" .. tostring(found.price) .. " | $" .. tostring(found.income) .. "/dtk"
		else
			slotLabel.Text = "-"
		end
	end
	refreshKlik()
	refreshTabs()
end)

-- Spawn faces the conveyor: keep the camera behind the player on spawn.
player.CharacterAdded:Connect(function(character)
	task.wait(0.5)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid and root then
		Workspace.CurrentCamera.CameraSubject = humanoid
	end
end)

print("Brainrot Night Market client ready.")
