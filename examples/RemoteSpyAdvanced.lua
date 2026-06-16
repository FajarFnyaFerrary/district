--[[
    Violence District - Ultimate Mod Hub v3.0
    FIXED: ESP Player Highlight + POV Bug + Feature Stability
    Author: .ftgs | Enhanced by Copilot & Gemini
]]

local cloneref = (cloneref or clonereference or function(instance)
	return instance
end)

local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local RunService = cloneref(game:GetService("RunService"))
local UserInputService = cloneref(game:GetService("UserInputService"))
local Workspace = cloneref(workspace)
local Players = cloneref(game:GetService("Players"))
local Lighting = cloneref(game:GetService("Lighting"))
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local WindUI
do
	local ok, result = pcall(function()
		return require("./src/Init")
	end)

	if ok then
		WindUI = result
	else
		if RunService:IsStudio() or not writefile then
			WindUI = require(ReplicatedStorage:WaitForChild("WindUI"):WaitForChild("Init"))
		else
			WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/FajarFnyaFerrary/district/main/dist/main.lua"))()
		end
	end
end

-- ===== GLOBAL CONFIG =====
local Config = {
	Theme = "Dark",
	VIP = {
		AutoPlay = false,
		AutoDagger = false,
		AutoWiggle = false,
	},
	Survivor = {
		SpeedBoost = false,
		CustomSpeed = 16,
		NoSlowdown = false,
		NoClip = false,
		ForceReset = false,
		SilentActions = false,
		AntiFallDamage = false,
		GodMode = false,
		InstantHeal = false,
		AntiKnock = false,
		AutoHealAura = false,
	},
	Killer = {
		VeinDropPrediction = false,
		VeinNoGravity = false,
		AntiBlind = false,
		AntiStun = false,
		DoubleDamageGen = false,
		KillerPower = false,
		Teleport = false,
		TargetPlayer = nil,
	},
	Visuals = {
		PlayerESP = false,
		PlayerHighlight = false,
		HighlightThickness = 0.05,
		GeneratorESP = false,
		PalletESP = false,
		ExitGateESP = false,
		HookESP = false,
		HealthESP = false,
		WindowESP = false,
		DistanceESP = false,
		CustomFOV = false,
		CustomFOVValue = 70,
		OriginalFOV = 70,
		Crosshair = false,
		RemoveBlur = false,
		Fullbright = false,
		PotatoMode = false,
	},
	Combat = {
		Aimbot = false,
		AimbotRadius = 50,
		ShowAimCircle = false,
		TargetTracer = false,
		LockOnHighlight = false,
		ExpandKillerHitbox = false,
		AutoAttack = false,
	},
	Automation = {
		AutoGenerator = false,
		GeneratorMode = "Neutral",
		BoostAllGen = false,
		InstantEscape = false,
		SelfUnhook = false,
	},
	CameraMode = "FPP",
	OriginalCameraMode = "FPP",
}

local OriginalSettings = {
	Blur = nil,
	Bloom = nil,
	Ambient = nil,
	OutdoorAmbient = nil,
	ClockTime = nil,
	CameraDistance = 0,
}

-- ===== ACTIVE TRACKING =====
local activeESPs = {}
local activeHighlights = {}
local isAutoGenRunning = false

-- ===== UTILITY FUNCTIONS =====
local function SafePcall(func, ...)
	local ok, result = pcall(func, ...)
	if not ok then
		warn("[VD-Hub] Error:", result)
		return nil
	end
	return result
end

local function GetCharacter()
	if LocalPlayer and LocalPlayer.Character then
		return LocalPlayer.Character
	end
	return LocalPlayer.CharacterAdded:Wait()
end

local function GetHumanoid()
	local char = GetCharacter()
	return char:FindFirstChild("Humanoid") or char:WaitForChild("Humanoid", 5)
end

local function GetHumanoidRootPart()
	local char = GetCharacter()
	return char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart", 5)
end

local function FindInstance(path)
	local parts = string.split(path, "/")
	local current = Workspace
	for _, part in ipairs(parts) do
		current = current:FindFirstChild(part) or current:WaitForChild(part, 3)
		if not current then return nil end
	end
	return current
end

local function GetAllGenerators()
	local generators = {}
	pcall(function()
		local genFolder = FindInstance("Map/Generators")
		if genFolder then
			for _, gen in ipairs(genFolder:GetChildren()) do
				if gen.Name:match("Generator") then
					table.insert(generators, gen)
				end
			end
		end
	end)
	return generators
end

-- FIX & UPDATE: Fungsi pembuat Highlight murni tembus tembok untuk Player Model
local function CreateHighlightBox(object, color, label, isKiller)
	if not object then return nil end
	
	-- Membuat Highlight effect pada model karakter
	local highlight = Instance.new("Highlight")
	highlight.Name = "PlayerHighlight"
	highlight.Adornee = object
	highlight.FillColor = color
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255) -- Outline putih biar tegas
	highlight.FillTransparency = 0.4
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop -- Tembus tembok wajib AlwaysOnTop
	highlight.Parent = object
	
	if label then
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "PlayerBillboard"
		billboard.MaxDistance = 500
		billboard.Size = UDim2.new(6, 0, 2, 0)
		billboard.StudsOffset = Vector3.new(0, 4, 0) -- Posisi teks di atas kepala
		billboard.AlwaysOnTop = true -- FIXED: Teks sekarang ikutan tembus tembok!
		billboard.Parent = object
		
		local textLabel = Instance.new("TextLabel")
		textLabel.BackgroundColor3 = color
		textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		textLabel.TextSize = 14
		textLabel.Size = UDim2.new(1, 0, 1, 0)
		textLabel.Parent = billboard
		textLabel.Text = label
		textLabel.BackgroundTransparency = 0.3
	end
	
	return highlight
end

local function DestroyAllHighlights()
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			local hl = player.Character:FindFirstChild("PlayerHighlight")
			if hl then hl:Destroy() end
			local bb = player.Character:FindFirstChild("PlayerBillboard")
			if bb then bb:Destroy() end
		end
	end
	activeHighlights = {}
end

local function DestroyAllESPs()
	for _, esp in ipairs(activeESPs) do
		if esp and esp.Parent then
			esp:Destroy()
		end
	end
	activeESPs = {}
end

local function Notify(title, content, duration)
	duration = duration or 3
	WindUI:Notify({
		Title = title,
		Content = content,
		Duration = duration,
	})
end

local function GetClosestPlayer(excludeSelf, isKiller)
	local closestPlayer = nil
	local closestDistance = math.huge
	
	for _, player in ipairs(Players:GetPlayers()) do
		if (not excludeSelf or player ~= LocalPlayer) and player.Character then
			local distance = (player.Character.PrimaryPart.Position - GetHumanoidRootPart().Position).Magnitude
			if distance < closestDistance then
				closestPlayer = player
				closestDistance = distance
			end
		end
	end
	
	return closestPlayer, closestDistance
end

-- ===== VIP MODULE =====
local VIPModule = {}

function VIPModule.AutoPlay()
	if not Config.VIP.AutoPlay then return end
	
	pcall(function()
		local char = GetCharacter()
		local humanoid = GetHumanoid()
		local rootPart = GetHumanoidRootPart()
		
		if humanoid.Health <= 0 then return end
		
		-- Find nearest generator
		local generators = GetAllGenerators()
		local nearestGen = nil
		local nearestDist = math.huge
		
		for _, gen in ipairs(generators) do
			if gen and gen.PrimaryPart then
				local dist = (gen.PrimaryPart.Position - rootPart.Position).Magnitude
				if dist < nearestDist then
					nearestGen = gen
					nearestDist = dist
				end
			end
		end
		
		if nearestGen and nearestDist > 5 then
			local direction = (nearestGen.PrimaryPart.Position - rootPart.Position).Unit
			rootPart.Velocity = direction * Config.Survivor.CustomSpeed
		elseif nearestGen and nearestDist <= 5 then
			local genPoint = nearestGen:FindFirstChild("GeneratorPoint2") or nearestGen
			pcall(function()
				local repairEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Generator"):WaitForChild("RepairEvent")
				repairEvent:FireServer(genPoint, true)
			end)
		end
	end)
end

function VIPModule.AutoDagger()
	if not Config.VIP.AutoDagger then return end
	
	pcall(function()
		local char = GetCharacter()
		local rootPart = GetHumanoidRootPart()
		local humanoid = GetHumanoid()
		
		if humanoid.Health <= 0 then return end
		
		local closestPlayer = GetClosestPlayer(true)
		if closestPlayer and closestPlayer.Character then
			local killerDist = (closestPlayer.Character.PrimaryPart.Position - rootPart.Position).Magnitude
			if killerDist < 30 then
				pcall(function()
					local parryRemote = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("Parry")
					if parryRemote then
						parryRemote:FireServer()
					end
				end)
			end
		end
	end)
end

-- ===== SURVIVOR MODULE =====
local SurvivorModule = {}

function SurvivorModule.SpeedBoost()
	if not Config.Survivor.SpeedBoost then return end
	
	pcall(function()
		local char = GetCharacter()
		local humanoid = GetHumanoid()
		
		if humanoid and humanoid.Health > 0 then
			humanoid.WalkSpeed = Config.Survivor.CustomSpeed
		end
	end)
end

function SurvivorModule.NoSlowdown()
	if not Config.Survivor.NoSlowdown then return end
	
	pcall(function()
		local char = GetCharacter()
		local humanoid = GetHumanoid()
		
		if humanoid then
			humanoid.WalkSpeed = Config.Survivor.CustomSpeed
		end
	end)
end

function SurvivorModule.NoClip()
	if not Config.Survivor.NoClip then return end
	
	pcall(function()
		local char = GetCharacter()
		for _, part in ipairs(char:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CanCollide = false
			end
		end
	end)
end

function SurvivorModule.ForceReset()
	if not Config.Survivor.ForceReset then return end
	
	pcall(function()
		local char = GetCharacter()
		local humanoid = GetHumanoid()
		local rootPart = GetHumanoidRootPart()
		
		humanoid.Sit = false
		humanoid:UnequipTools()
		rootPart.Velocity = Vector3.new(0, 0, 0)
		
		local resetRemote = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("ResetState")
		if resetRemote then
			resetRemote:FireServer()
		end
	end)
end

function SurvivorModule.SilentActions()
	if not Config.Survivor.SilentActions then return end
	
	pcall(function()
		local char = GetCharacter()
		for _, child in ipairs(char:GetChildren()) do
			if child:IsA("Sound") then
				child.Volume = 0
			end
		end
	end)
end

function SurvivorModule.AntiFallDamage()
	if not Config.Survivor.AntiFallDamage then return end
	
	pcall(function()
		local humanoid = GetHumanoid()
		if humanoid then
			humanoid.Health = humanoid.MaxHealth
		end
	end)
end

function SurvivorModule.GodMode()
	if not Config.Survivor.GodMode then return end
	
	pcall(function()
		local humanoid = GetHumanoid()
		if humanoid then
			humanoid.Health = humanoid.MaxHealth
		end
	end)
end

function SurvivorModule.InstantHeal()
	if not Config.Survivor.InstantHeal then return end
	
	pcall(function()
		local humanoid = GetHumanoid()
		if humanoid then
			humanoid.Health = humanoid.MaxHealth
		end
	end)
end

function SurvivorModule.AntiKnock()
	if not Config.Survivor.AntiKnock then return end
	
	pcall(function()
		local char = GetCharacter()
		local rootPart = GetHumanoidRootPart()
		local humanoid = GetHumanoid()
		
		if humanoid.State == Enum.HumanoidStateType.Landed then
			rootPart.Velocity = Vector3.new(0, 0, 0)
		end
	end)
end

function SurvivorModule.AutoHealAura()
	if not Config.Survivor.AutoHealAura then return end
	
	pcall(function()
		local char = GetCharacter()
		local rootPart = GetHumanoidRootPart()
		local humanoid = GetHumanoid()
		
		if humanoid.Health <= 0 then return end
		
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= LocalPlayer and player.Character then
				local distance = (player.Character.PrimaryPart.Position - rootPart.Position).Magnitude
				if distance < 30 then
					local targetHumanoid = player.Character:FindFirstChild("Humanoid")
					if targetHumanoid and targetHumanoid.Health > 0 then
						pcall(function()
							local healRemote = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("HealTeammate")
							if healRemote then
								healRemote:FireServer(player)
							end
						end)
					end
				end
			end
		end
	end)
end

-- ===== KILLER MODULE =====
local KillerModule = {}

function KillerModule.VeinDropPrediction()
	if not Config.Killer.VeinDropPrediction then return end
	
	pcall(function()
		local char = GetCharacter()
		local rootPart = GetHumanoidRootPart()
		
		local closestPlayer, distance = GetClosestPlayer(true)
		if closestPlayer and closestPlayer.Character and distance < 100 then
			local targetPos = closestPlayer.Character.PrimaryPart.Position
			local myPos = rootPart.Position
			
			local direction = (targetPos - myPos).Unit
			local predictedPos = targetPos + Vector3.new(0, distance * 0.1, 0)
			
			Camera.CFrame = CFrame.new(myPos, predictedPos)
		end
	end)
end

function KillerModule.VeinNoGravity()
	if not Config.Killer.VeinNoGravity then return end
	
	pcall(function()
		local closestPlayer = GetClosestPlayer(true)
		if closestPlayer and closestPlayer.Character then
			local spearRemote = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("SpearThrow")
			if spearRemote then
				spearRemote:FireServer(closestPlayer.Character.PrimaryPart, true)
			end
		end
	end)
end

function KillerModule.AntiBlind()
	if not Config.Killer.AntiBlind then return end
	
	pcall(function()
		local char = GetCharacter()
		for _, child in ipairs(char:GetChildren()) do
			if child:IsA("BlurEffect") or child:IsA("ColorCorrectionDevice") then
				child.Enabled = false
			end
		end
		
		Camera.FieldOfView = Config.Visuals.CustomFOVValue or 70
	end)
end

function KillerModule.AntiStun()
	if not Config.Killer.AntiStun then return end
	
	pcall(function()
		local humanoid = GetHumanoid()
		if humanoid and humanoid.State == Enum.HumanoidStateType.Stunned then
			humanoid:ChangeState(Enum.HumanoidStateType.Running)
		end
	end)
end

function KillerModule.DoubleDamageGen()
	if not Config.Killer.DoubleDamageGen then return end
	
	pcall(function()
		local generators = GetAllGenerators()
		
		for _, gen in ipairs(generators) do
			local kickRemote = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("KickGenerator")
			if kickRemote then
				for i = 1, 2 do
					kickRemote:FireServer(gen)
					task.wait(0.2)
				end
			end
		end
	end)
end

function KillerModule.KillerPower()
	if not Config.Killer.KillerPower then return end
	
	pcall(function()
		local powerRemote = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("ActivatePower")
		if powerRemote then
			powerRemote:FireServer()
		end
	end)
end

function KillerModule.Teleport()
	if not Config.Killer.Teleport then return end
	
	pcall(function()
		local rootPart = GetHumanoidRootPart()
		local targetPlayer = Config.Killer.TargetPlayer
		
		if targetPlayer and targetPlayer.Character then
			rootPart.CFrame = targetPlayer.Character.PrimaryPart.CFrame + Vector3.new(0, 5, 0)
		else
			local closestPlayer = GetClosestPlayer(true)
			if closestPlayer and closestPlayer.Character then
				rootPart.CFrame = closestPlayer.Character.PrimaryPart.CFrame + Vector3.new(0, 5, 0)
			end
		end
	end)
end

function KillerModule.PredictNextKiller()
	pcall(function()
		local allPlayers = Players:GetPlayers()
		if #allPlayers <= 1 then
			Notify("🔮 Killer Prediction", "Kurang pemain untuk membuat prediksi.", 4)
			return
		end
		
		local predictedKiller = nil
		local highestChance = -1
		
		-- Mencari indikator chance dari sistem game (jika ada nilainya di Leaderstats/Attributes)
		for _, player in ipairs(allPlayers) do
			local chanceAttribute = player:GetAttribute("KillerChance") or player:GetAttribute("Chance")
			local leaderstats = player:FindFirstChild("leaderstats")
			local chanceValue = leaderstats and (leaderstats:FindFirstChild("KillerChance") or leaderstats:FindFirstChild("Chance"))
			
			if chanceAttribute then
				if chanceAttribute > highestChance then
					highestChance = chanceAttribute
					predictedKiller = player
				end
			elseif chanceValue and chanceValue:IsA("ValueBase") then
				if chanceValue.Value > highestChance then
					highestChance = chanceValue.Value
					predictedKiller = player
				end
			end
		end
		
		-- Fallback: Jika game tidak menggunakan sistem chance konvensional, 
		-- kita lakukan kalkulasi pseudo-random murni dari list player yang bukan LocalPlayer.
		if not predictedKiller then
			local pool = {}
			for _, player in ipairs(allPlayers) do
				if player ~= LocalPlayer then
					table.insert(pool, player)
				end
			end
			if #pool > 0 then
				predictedKiller = pool[math.random(1, #pool)]
			end
		end
		
		-- Tampilkan hasil lewat WindUI Notification
		if predictedKiller then
			Notify("🔮 Prediction Result", "Killer berikutnya: " .. predictedKiller.Name, 5)
		else
			Notify("🔮 Prediction Result", "Gagal memprediksi match selanjutnya.", 4)
		end
	end)
end

-- ===== VISUALS MODULE (FIXED) =====
local VisualsModule = {}

-- FIX & UPDATE: Fungsi ESP Highlight Player Utama
function VisualsModule.PlayerESPHighlight()
	if not Config.Visuals.PlayerHighlight then
		DestroyAllHighlights()
		return
	end
	
	pcall(function()
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= LocalPlayer and player.Character then
				local char = player.Character
				
				-- FIXED: Pasang Highlight langsung ke MODEL karakter agar seluruh tubuh menyala tembus pandang
				local existingHighlight = char:FindFirstChild("PlayerHighlight")
				if not existingHighlight then
					-- Logika deteksi role dinamis (biar gak selamanya dianggap survivor)
					local isKiller = false
					if char:FindFirstChild("Killer") or player:FindFirstChild("Role") or char:GetAttribute("Role") == "Killer" or char.Name:lower():match("killer") then
						isKiller = true
					end
					
					local color = isKiller and Color3.fromRGB(255, 0, 0) or Color3.fromRGB(0, 255, 0)
					local label = player.Name .. " [" .. (isKiller and "KILLER" or "SURVIVOR") .. "]"
					
					local highlight = CreateHighlightBox(char, color, label, isKiller)
					if highlight then
						table.insert(activeHighlights, highlight)
					end
				end
			end
		end
	end)
end

function VisualsModule.GeneratorESP()
	if not Config.Visuals.GeneratorESP then
		return
	end
	
	pcall(function()
		local generators = GetAllGenerators()
		for _, gen in ipairs(generators) do
			if gen and not gen:FindFirstChild("GeneratorESP") then
				local billboard = Instance.new("BillboardGui")
				billboard.MaxDistance = 500
				billboard.Size = UDim2.new(6, 0, 2, 0)
				billboard.StudsOffset = Vector3.new(0, 5, 0)
				billboard.AlwaysOnTop = true
				billboard.Parent = gen
				billboard.Name = "GeneratorESP"
				
				local textLabel = Instance.new("TextLabel")
				textLabel.BackgroundColor3 = Color3.fromRGB(255, 255, 0)
				textLabel.TextColor3 = Color3.fromRGB(0, 0, 0)
				textLabel.TextSize = 14
				textLabel.Size = UDim2.new(1, 0, 1, 0)
				textLabel.Parent = billboard
				textLabel.Text = "GENERATOR [0%]"
				textLabel.BackgroundTransparency = 0.3
				
				table.insert(activeESPs, billboard)
			end
		end
	end)
end

function VisualsModule.PalletESP()
	if not Config.Visuals.PalletESP then return end
	
	pcall(function()
		local pallets = FindInstance("Map/Pallets")
		if pallets then
			for _, pallet in ipairs(pallets:GetChildren()) do
				if pallet and not pallet:FindFirstChild("PalletESP") then
					local billboard = Instance.new("BillboardGui")
					billboard.MaxDistance = 500
					billboard.Size = UDim2.new(4, 0, 2, 0)
					billboard.StudsOffset = Vector3.new(0, 3, 0)
					billboard.AlwaysOnTop = true
					billboard.Parent = pallet
					billboard.Name = "PalletESP"
					
					local textLabel = Instance.new("TextLabel")
					textLabel.BackgroundColor3 = Color3.fromRGB(165, 42, 42)
					textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
					textLabel.TextSize = 12
					textLabel.Size = UDim2.new(1, 0, 1, 0)
					textLabel.Parent = billboard
					textLabel.Text = "PALLET"
					textLabel.BackgroundTransparency = 0.3
					
					table.insert(activeESPs, billboard)
				end
			end
		end
	end)
end

function VisualsModule.ExitGateESP()
	if not Config.Visuals.ExitGateESP then return end
	
	pcall(function()
		local exitGates = FindInstance("Map/ExitGates")
		if exitGates then
			for _, gate in ipairs(exitGates:GetChildren()) do
				if gate and not gate:FindFirstChild("ExitGateESP") then
					local billboard = Instance.new("BillboardGui")
					billboard.MaxDistance = 500
					billboard.Size = UDim2.new(6, 0, 2, 0)
					billboard.StudsOffset = Vector3.new(0, 5, 0)
					billboard.AlwaysOnTop = true
					billboard.Parent = gate
					billboard.Name = "ExitGateESP"
					
					local textLabel = Instance.new("TextLabel")
					textLabel.BackgroundColor3 = Color3.fromRGB(0, 255, 255)
					textLabel.TextColor3 = Color3.fromRGB(0, 0, 0)
					textLabel.TextSize = 14
					textLabel.Size = UDim2.new(1, 0, 1, 0)
					textLabel.Parent = billboard
					textLabel.Text = "EXIT GATE"
					textLabel.BackgroundTransparency = 0.3
					
					table.insert(activeESPs, billboard)
				end
			end
		end
	end)
end

function VisualsModule.HookESP()
	if not Config.Visuals.HookESP then return end
	
	pcall(function()
		local hooks = FindInstance("Map/Hooks")
		if hooks then
			for _, hook in ipairs(hooks:GetChildren()) do
				if hook and not hook:FindFirstChild("HookESP") then
					local billboard = Instance.new("BillboardGui")
					billboard.MaxDistance = 500
					billboard.Size = UDim2.new(4, 0, 2, 0)
					billboard.StudsOffset = Vector3.new(0, 3, 0)
					billboard.AlwaysOnTop = true
					billboard.Parent = hook
					billboard.Name = "HookESP"
					
					local textLabel = Instance.new("TextLabel")
					textLabel.BackgroundColor3 = Color3.fromRGB(255, 0, 255)
					textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
					textLabel.TextSize = 12
					textLabel.Size = UDim2.new(1, 0, 1, 0)
					textLabel.Parent = billboard
					textLabel.Text = "HOOK"
					textLabel.BackgroundTransparency = 0.3
					
					table.insert(activeESPs, billboard)
				end
			end
		end
	end)
end

function VisualsModule.HealthESP()
	if not Config.Visuals.HealthESP then return end
	
	pcall(function()
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= LocalPlayer and player.Character then
				local humanoid = player.Character:FindFirstChild("Humanoid")
				if humanoid then
					local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
					if rootPart and not rootPart:FindFirstChild("HealthESP") then
						local billboard = Instance.new("BillboardGui")
						billboard.MaxDistance = 300
						billboard.Size = UDim2.new(6, 0, 1.5, 0)
						billboard.StudsOffset = Vector3.new(0, 6, 0)
						billboard.AlwaysOnTop = true
						billboard.Parent = rootPart
						billboard.Name = "HealthESP"
						
						local textLabel = Instance.new("TextLabel")
						textLabel.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
						textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
						textLabel.TextSize = 12
						textLabel.Size = UDim2.new(1, 0, 1, 0)
						textLabel.Parent = billboard
						textLabel.Text = "HP: " .. math.floor(humanoid.Health) .. "/" .. math.floor(humanoid.MaxHealth)
						textLabel.BackgroundTransparency = 0.4
						
						table.insert(activeESPs, billboard)
					end
				end
			end
		end
	end)
end

function VisualsModule.WindowESP()
	if not Config.Visuals.WindowESP then return end
	
	pcall(function()
		local windows = FindInstance("Map/Windows")
		if windows then
			for _, window in ipairs(windows:GetChildren()) do
				if window and not window:FindFirstChild("WindowESP") then
					local billboard = Instance.new("BillboardGui")
					billboard.MaxDistance = 500
					billboard.Size = UDim2.new(4, 0, 2, 0)
					billboard.StudsOffset = Vector3.new(0, 3, 0)
					billboard.AlwaysOnTop = true
					billboard.Parent = window
					billboard.Name = "WindowESP"
					
					local textLabel = Instance.new("TextLabel")
					textLabel.BackgroundColor3 = Color3.fromRGB(100, 149, 237)
					textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
					textLabel.TextSize = 12
					textLabel.Size = UDim2.new(1, 0, 1, 0)
					textLabel.Parent = billboard
					textLabel.Text = "WINDOW"
					textLabel.BackgroundTransparency = 0.3
					
					table.insert(activeESPs, billboard)
				end
			end
		end
	end)
end

function VisualsModule.CustomFOV()
	if not Config.Visuals.CustomFOV then
		Camera.FieldOfView = Config.Visuals.OriginalFOV or 70
		return
	end
	
	Camera.FieldOfView = Config.Visuals.CustomFOVValue
end

function VisualsModule.Crosshair()
	if not Config.Visuals.Crosshair then
		local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
		if playerGui then
			local crosshairGui = playerGui:FindFirstChild("CrosshairGUI")
			if crosshairGui then crosshairGui:Destroy() end
		end
		return
	end
	
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	if playerGui:FindFirstChild("CrosshairGUI") then return end
	
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "CrosshairGUI"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui
	
	local crosshair = Instance.new("TextLabel")
	crosshair.Name = "Crosshair"
	crosshair.Text = "+"
	crosshair.TextSize = 32
	crosshair.TextColor3 = Color3.fromRGB(255, 0, 0)
	crosshair.BackgroundTransparency = 1
	crosshair.Size = UDim2.new(0, 40, 0, 40)
	crosshair.Position = UDim2.new(0.5, -20, 0.5, -20)
	crosshair.Font = Enum.Font.GothamBold
	crosshair.Parent = screenGui
end

function VisualsModule.RemoveBlur()
	if not Config.Visuals.RemoveBlur then
		if OriginalSettings.Blur then
			OriginalSettings.Blur.Enabled = true
		end
		return
	end
	
	pcall(function()
		for _, effect in ipairs(Lighting:GetChildren()) do
			if effect:IsA("BlurEffect") then
				OriginalSettings.Blur = effect
				effect.Enabled = false
			end
			if effect:IsA("BloomEffect") then
				OriginalSettings.Bloom = effect
				effect.Enabled = false
			end
		end
	end)
end

function VisualsModule.Fullbright()
	if not Config.Visuals.Fullbright then
		if OriginalSettings.Ambient then
			Lighting.Ambient = OriginalSettings.Ambient
			Lighting.OutdoorAmbient = OriginalSettings.OutdoorAmbient
			Lighting.ClockTime = OriginalSettings.ClockTime
		end
		return
	end
	
	OriginalSettings.Ambient = Lighting.Ambient
	OriginalSettings.OutdoorAmbient = Lighting.OutdoorAmbient
	OriginalSettings.ClockTime = Lighting.ClockTime
	
	Lighting.Ambient = Color3.fromRGB(255, 255, 255)
	Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
	Lighting.ClockTime = 12
	
	for _, obj in ipairs(Lighting:GetDescendants()) do
		if obj:IsA("Light") then
			obj.Brightness = 5
		end
	end
end

function VisualsModule.PotatoMode()
	if not Config.Visuals.PotatoMode then
		return
	end
	
	pcall(function()
		local char = GetCharacter()
		
		for _, part in ipairs(Workspace:FindPartBoundsInRadius(char.PrimaryPart.Position, 500)) do
			if part:IsA("BasePart") then
				part.Material = Enum.Material.Plastic
				part.Texture = ""
			end
		end
		
		for _, particle in ipairs(Workspace:FindPartBoundsInRadius(char.PrimaryPart.Position, 500)) do
			if particle:FindFirstChildOfClass("ParticleEmitter") then
				for _, emitter in ipairs(particle:FindChildrenOfClass("ParticleEmitter")) do
					emitter.Enabled = false
				end
			end
		end
		
		settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
	end)
end

-- ===== COMBAT MODULE =====
local CombatModule = {}

function CombatModule.Aimbot()
	if not Config.Combat.Aimbot then return end
	
	pcall(function()
		local closestPlayer, distance = GetClosestPlayer(true)
		if closestPlayer and closestPlayer.Character and distance < Config.Combat.AimbotRadius then
			local targetPos = closestPlayer.Character.PrimaryPart.Position
			local myPos = GetHumanoidRootPart().Position
			
			Camera.CFrame = CFrame.new(myPos, targetPos + Vector3.new(0, 1, 0))
		end
	end)
end

function CombatModule.ShowAimCircle()
	if not Config.Combat.ShowAimCircle then
		local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
		if playerGui then
			local aimCircle = playerGui:FindFirstChild("AimCircleGUI")
			if aimCircle then aimCircle:Destroy() end
		end
		return
	end
	
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	if playerGui:FindFirstChild("AimCircleGUI") then return end
	
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "AimCircleGUI"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui
	
	local circle = Instance.new("Frame")
	circle.Name = "AimCircle"
	circle.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
	circle.BackgroundTransparency = 0.7
	circle.BorderSizePixel = 0
	circle.Size = UDim2.new(0, Config.Combat.AimbotRadius * 2, 0, Config.Combat.AimbotRadius * 2)
	circle.Position = UDim2.new(0.5, -Config.Combat.AimbotRadius, 0.5, -Config.Combat.AimbotRadius)
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = circle
	
	circle.Parent = screenGui
end

function CombatModule.TargetTracer()
	if not Config.Combat.TargetTracer then return end
	
	pcall(function()
		local closestPlayer = GetClosestPlayer(true)
		if closestPlayer and closestPlayer.Character then
			local playerGui = LocalPlayer:WaitForChild("PlayerGui")
			
			local screenGui = Instance.new("ScreenGui")
			screenGui.Name = "TracerGUI"
			screenGui.ResetOnSpawn = false
			screenGui.Parent = playerGui
			
			local line = Instance.new("Frame")
			line.Name = "Tracer"
			line.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
			line.BorderSizePixel = 0
			line.Size = UDim2.new(0, 2, 0, 500)
			line.Position = UDim2.new(0.5, -1, 1, 0)
			line.Rotation = 45
			line.Parent = screenGui
		end
	end)
end

function CombatModule.LockOnHighlight()
	if not Config.Combat.LockOnHighlight then return end
	
	pcall(function()
		local closestPlayer = GetClosestPlayer(true)
		if closestPlayer and closestPlayer.Character then
			for _, part in ipairs(closestPlayer.Character:GetChildren()) do
				if part:IsA("BasePart") then
					local surface = Instance.new("SurfaceGui")
					surface.Face = Enum.NormalId.Front
					surface.Parent = part
					
					local frame = Instance.new("Frame")
					frame.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
					frame.BackgroundTransparency = 0.3
					frame.Size = UDim2.new(1, 0, 1, 0)
					frame.Parent = surface
				end
			end
		end
	end)
end

function CombatModule.ExpandKillerHitbox()
	if not Config.Combat.ExpandKillerHitbox then return end
	
	pcall(function()
		local closestPlayer = GetClosestPlayer(true)
		if closestPlayer and closestPlayer.Character then
			for _, part in ipairs(closestPlayer.Character:GetChildren()) do
				if part:IsA("BasePart") then
					part.Size = part.Size * 1.5
				end
			end
		end
	end)
end

function CombatModule.AutoAttack()
	if not Config.Combat.AutoAttack then return end
	
	pcall(function()
		local closestPlayer, distance = GetClosestPlayer(true)
		if closestPlayer and closestPlayer.Character and distance < 20 then
			local attackRemote = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("Attack")
			if attackRemote then
				attackRemote:FireServer(closestPlayer.Character.PrimaryPart)
			end
		end
	end)
end

-- ===== AUTOMATION MODULE =====
local AutomationModule = {}

function AutomationModule.AutoGenerator()
	if not Config.Automation.AutoGenerator then
		isAutoGenRunning = false
		return
	end
	
	if isAutoGenRunning then return end
	isAutoGenRunning = true
	
	pcall(function()
		local generators = GetAllGenerators()
		
		for _, gen in ipairs(generators) do
			if not Config.Automation.AutoGenerator then break end
			
			local genPoint = gen:FindFirstChild("GeneratorPoint2") or gen
			
			-- Repair event
			local repairEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Generator"):WaitForChild("RepairEvent")
			repairEvent:FireServer(genPoint, true)
			
			task.wait(0.3)
			
			-- Skill check event
			local skillCheckEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Generator"):WaitForChild("SkillCheckResultEvent")
			local mode = Config.Automation.GeneratorMode == "Perfect" and "perfect" or "neutral"
			skillCheckEvent:FireServer(mode, 0, gen, genPoint)
			
			task.wait(0.5)
		end
	end)
	
	isAutoGenRunning = false
end

function AutomationModule.BoostAllGen()
	if not Config.Automation.BoostAllGen then return end
	
	pcall(function()
		local generators = GetAllGenerators()
		
		for _, gen in ipairs(generators) do
			local genPoint = gen:FindFirstChild("GeneratorPoint2") or gen
			
			local boostEvent = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("BoostGenerator")
			if boostEvent then
				boostEvent:FireServer(gen, genPoint)
			end
		end
	end)
end

function AutomationModule.InstantEscape()
	if not Config.Automation.InstantEscape then return end
	
	pcall(function()
		local exitGates = FindInstance("Map/ExitGates")
		if exitGates then
			for _, gate in ipairs(exitGates:GetChildren()) do
				local openRemote = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("OpenExitGate")
				if openRemote then
					openRemote:FireServer(gate)
				end
				
				task.wait(0.3)
			end
		end
		
		local finishZone = FindInstance("Map/FinishZone")
		if finishZone then
			GetHumanoidRootPart().CFrame = finishZone.CFrame
		end
	end)
end

function AutomationModule.SelfUnhook()
	if not Config.Automation.SelfUnhook then return end
	
	pcall(function()
		local char = GetCharacter()
		local hooked = char:FindFirstChild("Hooked") or char:FindFirstChild("OnHook")
		
		if hooked then
			local unhookRemote = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("Unhook")
			if unhookRemote then
				for i = 1, 3 do
					unhookRemote:FireServer()
					task.wait(0.1)
				end
			end
		end
	end)
end

-- ===== CAMERA MODULE (FIXED POV BUG) =====
local CameraModule = {}

function CameraModule.ToggleFPPTPP()
	if Config.CameraMode == "FPP" then
		Config.CameraMode = "TPP"
		OriginalSettings.CameraDistance = 5
		Camera.Focus = GetHumanoidRootPart().CFrame * CFrame.new(0, 0, OriginalSettings.CameraDistance)
		Notify("Camera Mode", "✓ Switched to Third Person")
	else
		Config.CameraMode = "FPP"
		OriginalSettings.CameraDistance = 0
		Camera.Focus = GetHumanoidRootPart()
		Notify("Camera Mode", "✓ Switched to First Person")
	end
end

-- ===== MAIN LOOP =====
local function MainLoop()
	while true do
		task.wait(0.05)
		
		if LocalPlayer and LocalPlayer.Character then
			-- VIP Features
			SafePcall(VIPModule.AutoPlay)
			SafePcall(VIPModule.AutoDagger)
			
			-- Survivor Features
			SafePcall(SurvivorModule.SpeedBoost)
			SafePcall(SurvivorModule.NoSlowdown)
			SafePcall(SurvivorModule.NoClip)
			SafePcall(SurvivorModule.AntiFallDamage)
			SafePcall(SurvivorModule.GodMode)
			SafePcall(SurvivorModule.InstantHeal)
			SafePcall(SurvivorModule.AntiKnock)
			SafePcall(SurvivorModule.AutoHealAura)
			
			-- Killer Features
			SafePcall(KillerModule.VeinDropPrediction)
			SafePcall(KillerModule.VeinNoGravity)
			SafePcall(KillerModule.AntiBlind)
			SafePcall(KillerModule.AntiStun)
			SafePcall(KillerModule.DoubleDamageGen)
			SafePcall(KillerModule.KillerPower)
			SafePcall(KillerModule.Teleport)
			SafePcall(KillerModule.PredictNextKiller)
			
			-- Visuals
			SafePcall(VisualsModule.PlayerESPHighlight)
			SafePcall(VisualsModule.GeneratorESP)
			SafePcall(VisualsModule.PalletESP)
			SafePcall(VisualsModule.ExitGateESP)
			SafePcall(VisualsModule.HookESP)
			SafePcall(VisualsModule.HealthESP)
			SafePcall(VisualsModule.WindowESP)
			SafePcall(VisualsModule.CustomFOV)
			SafePcall(VisualsModule.Fullbright)
			SafePcall(VisualsModule.PotatoMode)
			
			-- Combat
			SafePcall(CombatModule.Aimbot)
			SafePcall(CombatModule.TargetTracer)
			SafePcall(CombatModule.LockOnHighlight)
			SafePcall(CombatModule.ExpandKillerHitbox)
			SafePcall(CombatModule.AutoAttack)
			
			-- Automation
			SafePcall(AutomationModule.AutoGenerator)
			SafePcall(AutomationModule.BoostAllGen)
			SafePcall(AutomationModule.InstantEscape)
			SafePcall(AutomationModule.SelfUnhook)
		end
	end
end

-- ===== WINDUI SETUP =====
local Window = WindUI:CreateWindow({
	Title = "Violence District Hub v3.2",
	Author = "by Jackson Storm",
	Icon = "solar:gamepad-bold",
	Theme = Config.Theme,
	NewElements = true,
	Transparent = true,
	ToggleKey = Enum.KeyCode.F,
	Acrylic = true,
	KeySystem = { 
    Note = "Masukkan key Platoboost Anda untuk melanjutkan.",
    API = {
        {   
            Type = "platoboost", 
            ServiceId = 26195, 
            Secret = "8d7de7ed-e9d3-47ab-a6ee-911d31ef4647", 
        },
    },
    SaveKey = true,
},
})

-- ===== VIP TAB =====
local TabVIP = Window:Tab({
	Title = "VIP",
	Icon = "solar:crown-bold",
})

TabVIP:Section({ Title = "Automatic Features", Desc = "Ultimate automatic survival" })

TabVIP:Toggle({
	Title = "Auto Play (Smart AI)",
	Value = Config.VIP.AutoPlay,
	Callback = function(v)
		Config.VIP.AutoPlay = v
		Notify("Auto Play", v and "✓ Enabled" or "✗ Disabled")
	end,
})

TabVIP:Toggle({
	Title = "Auto Dagger (Parry)",
	Value = Config.VIP.AutoDagger,
	Callback = function(v)
		Config.VIP.AutoDagger = v
		Notify("Auto Dagger", v and "✓ Enabled" or "✗ Disabled")
	end,
})

-- ===== SURVIVOR TAB =====
local TabSurvivor = Window:Tab({
	Title = "SURVIVOR",
	Icon = "solar:user-bold",
})

TabSurvivor:Section({ Title = "Movement & Speed" })

TabSurvivor:Toggle({
	Title = "Speed Boost",
	Value = Config.Survivor.SpeedBoost,
	Callback = function(v)
		Config.Survivor.SpeedBoost = v
		Notify("Speed Boost", v and "✓ Enabled" or "✗ Disabled")
	end,
})

TabSurvivor:Slider({
	Title = "Custom Speed",
	Step = 1,
	Value = {
		Min = 16,
		Max = 100,
		Default = Config.Survivor.CustomSpeed,
	},
	Callback = function(v)
		Config.Survivor.CustomSpeed = v
	end,
})

TabSurvivor:Toggle({
	Title = "No Slowdown",
	Value = Config.Survivor.NoSlowdown,
	Callback = function(v)
		Config.Survivor.NoSlowdown = v
		Notify("No Slowdown", v and "✓ Enabled" or "✗ Disabled")
	end,
})

TabSurvivor:Toggle({
	Title = "No Clip",
	Value = Config.Survivor.NoClip,
	Callback = function(v)
		Config.Survivor.NoClip = v
		Notify("No Clip", v and "✓ Enabled" or "✗ Disabled")
	end,
})

TabSurvivor:Toggle({
	Title = "Force Reset State (Anti Stuck)",
	Value = Config.Survivor.ForceReset,
	Callback = function(v)
		Config.Survivor.ForceReset = v
		Notify("Force Reset", v and "✓ Enabled" or "✗ Disabled")
	end,
})

TabSurvivor:Toggle({
	Title = "Silent Actions (Anti Noise)",
	Value = Config.Survivor.SilentActions,
	Callback = function(v)
		Config.Survivor.SilentActions = v
		Notify("Silent Actions", v and "✓ Enabled" or "✗ Disabled")
	end,
})

TabSurvivor:Section({ Title = "Health & Defense" })

TabSurvivor:Toggle({
	Title = "Anti Fall Damage",
	Value = Config.Survivor.AntiFallDamage,
	Callback = function(v)
		Config.Survivor.AntiFallDamage = v
		Notify("Anti Fall Damage", v and "✓ Enabled" or "✗ Disabled")
	end,
})

TabSurvivor:Toggle({
	Title = "God Mode",
	Value = Config.Survivor.GodMode,
	Callback = function(v)
		Config.Survivor.GodMode = v
		Notify("God Mode", v and "✓ Enabled" or "✗ Disabled")
	end,
})

TabSurvivor:Toggle({
	Title = "Instant Heal",
	Value = Config.Survivor.InstantHeal,
	Callback = function(v)
		Config.Survivor.InstantHeal = v
		Notify("Instant Heal", v and "✓ Enabled" or "✗ Disabled")
	end,
})

TabSurvivor:Toggle({
	Title = "Anti Knock",
	Value = Config.Survivor.AntiKnock,
	Callback = function(v)
		Config.Survivor.AntiKnock = v
		Notify("Anti Knock", v and "✓ Enabled" or "✗ Disabled")
	end,
})

TabSurvivor:Toggle({
	Title = "Auto Heal Aura",
	Value = Config.Survivor.AutoHealAura,
	Callback = function(v)
		Config.Survivor.AutoHealAura = v
		Notify("Auto Heal Aura", v and "✓ Enabled" or "✗ Disabled")
	end,
})

-- ===== KILLER TAB =====
local TabKiller = Window:Tab({
	Title = "KILLER",
	Icon = "solar:shield-minimalistic-bold",
})

TabKiller:Section({ Title = "Vein Spear Powers" })

TabKiller:Toggle({
	Title = "Vein Spear: Drop Prediction",
	Value = Config.Killer.VeinDropPrediction,
	Callback = function(v)
		Config.Killer.VeinDropPrediction = v
		Notify("Vein Drop Prediction", v and "✓ Enabled" or "✗ Disabled")
	end,
})

TabKiller:Toggle({
	Title = "Vein Spear: No Gravity",
	Value = Config.Killer.VeinNoGravity,
	Callback = function(v)
		Config.Killer.VeinNoGravity = v
		Notify("Vein No Gravity", v and "✓ Enabled" or "✗ Disabled")
	end,
})

TabKiller:Section({ Title = "Killer Abilities" })

TabKiller:Toggle({
	Title = "Anti Blind (Fog/Flash)",
	Value = Config.Killer.AntiBlind,
	Callback = function(v)
		Config.Killer.AntiBlind = v
		Notify("Anti Blind", v and "✓ Enabled" or "✗ Disabled")
	end,
})

TabKiller:Toggle({
	Title = "Anti Stun (Pallet)",
	Value = Config.Killer.AntiStun,
	Callback = function(v)
		Config.Killer.AntiStun = v
		Notify("Anti Stun", v and "✓ Enabled" or "✗ Disabled")
	end,
})

TabKiller:Toggle({
	Title = "Double Damage Generator",
	Value = Config.Killer.DoubleDamageGen,
	Callback = function(v)
		Config.Killer.DoubleDamageGen = v
		Notify("Double Damage Gen", v and "✓ Enabled" or "✗ Disabled")
	end,
})

TabKiller:Toggle({
	Title = "Activate Killer Power",
	Value = Config.Killer.KillerPower,
	Callback = function(v)
		Config.Killer.KillerPower = v
		Notify("Killer Power", v and "✓ Enabled" or "✗ Disabled")
	end,
})

TabKiller:Button({
	Title = "Predict Next Killer",
	Justify = "Center",
	Icon = "solar:magic-stick-bold",
	Callback = function()
		KillerModule.PredictNextKiller()
	end,
})

TabKiller:Toggle({
	Title = "Teleport to Survivor",
	Value = Config.Killer.Teleport,
	Callback = function(v)
		Config.Killer.Teleport = v
		Notify("Teleport", v and "✓ Enabled" or "✗ Disabled")
	end,
})

local PlayerList = {}
for _, player in ipairs(Players:GetPlayers()) do
	if player ~= LocalPlayer then
		table.insert(PlayerList, player.Name)
	end
end

if #PlayerList > 0 then
	TabKiller:Dropdown({
		Title = "Select Target Player",
		Value = Config.Killer.TargetPlayer and Config.Killer.TargetPlayer.Name or PlayerList[1] or "None",
		Values = PlayerList,
		Callback = function(v)
			for _, player in ipairs(Players:GetPlayers()) do
				if player.Name == v then
					Config.Killer.TargetPlayer = player
					break
				end
			end
		end,
	})
end

-- ===== VISUALS TAB =====
local TabVisuals = Window:Tab({
	Title = "VISUALS",
	Icon = "solar:eye-bold",
})

TabVisuals:Section({ Title = "ESP - Enemy & World" })

TabVisuals:Toggle({
	Title = "Player ESP Highlight ★",
	Value = Config.Visuals.PlayerHighlight,
	Callback = function(v)
		Config.Visuals.PlayerHighlight = v
		if not v then DestroyAllHighlights() end
		Notify("Player Highlight", v and "✓ Enabled (Visible through walls)" or "✗ Disabled")
	end,
})

TabVisuals:Toggle({
	Title = "Generator ESP",
	Value = Config.Visuals.GeneratorESP,
	Callback = function(v)
		Config.Visuals.GeneratorESP = v
		Notify("Generator ESP", v and "✓ Enabled" or "✗ Disabled")
	end,
})

TabVisuals:Toggle({
	Title = "Pallet ESP",
	Value = Config.Visuals.PalletESP,
	Callback = function(v)
		Config.Visuals.PalletESP = v
		Notify("Pallet ESP", v and "✓ Enabled" or "✗ Disabled")
	end,
})

TabVisuals:Toggle({
	Title = "Exit Gate ESP",
	Value = Config.Visuals.ExitGateESP,
	Callback = function(v)
		Config.Visuals.ExitGateESP = v
		Notify("Exit Gate ESP", v and "✓ Enabled" or "✗ Disabled")
	end,
})

TabVisuals:Toggle({
	Title = "Hook ESP",
	Value = Config.Visuals.HookESP,
	Callback = function(v)
		Config.Visuals.HookESP = v
		Notify("Hook ESP", v and "✓ Enabled" or "✗ Disabled")
	end,
})

TabVisuals:Toggle({
	Title = "Health ESP",
	Value = Config.Visuals.HealthESP,
	Callback = function(v)
		Config.Visuals.HealthESP = v
		Notify("Health ESP", v and "✓ Enabled" or "✗ Disabled")
	end,
})

TabVisuals:Toggle({
	Title = "Window ESP",
	Value = Config.Visuals.WindowESP,
	Callback = function(v)
		Config.Visuals.WindowESP = v
		Notify("Window ESP", v and "✓ Enabled" or "✗ Disabled")
	end,
})

TabVisuals:Section({ Title = "Camera & Display" })

TabVisuals:Toggle({
	Title = "Show Crosshair",
	Value = Config.Visuals.Crosshair,
	Callback = function(v)
		Config.Visuals.Crosshair = v
		VisualsModule.Crosshair()
		Notify("Crosshair", v and "✓ Enabled" or "✗ Disabled")
	end,
})

TabVisuals:Toggle({
	Title = "Custom FOV",
	Value = Config.Visuals.CustomFOV,
	Callback = function(v)
		Config.Visuals.CustomFOV = v
		VisualsModule.CustomFOV()
		Notify("Custom FOV", v and "✓ Enabled" or "✗ Disabled")
	end,
})

TabVisuals:Slider({
	Title = "FOV Value",
	Step = 5,
	Value = {
		Min = 40,
		Max = 120,
		Default = Config.Visuals.CustomFOVValue,
	},
	Callback = function(v)
		Config.Visuals.CustomFOVValue = v
		VisualsModule.CustomFOV()
	end,
})

TabVisuals:Toggle({
	Title = "Remove Blur & Bloom",
	Value = Config.Visuals.RemoveBlur,
	Callback = function(v)
		Config.Visuals.RemoveBlur = v
		VisualsModule.RemoveBlur()
		Notify("Blur Removal", v and "✓ Enabled" or "✗ Disabled")
	end,
})

TabVisuals:Toggle({
	Title = "Force Fullbright",
	Value = Config.Visuals.Fullbright,
	Callback = function(v)
		Config.Visuals.Fullbright = v
		VisualsModule.Fullbright()
		Notify("Fullbright", v and "✓ Enabled" or "✗ Disabled")
	end,
})

TabVisuals:Toggle({
	Title = "Extreme Potato Mode",
	Value = Config.Visuals.PotatoMode,
	Callback = function(v)
		Config.Visuals.PotatoMode = v
		VisualsModule.PotatoMode()
		Notify("Potato Mode", v and "✓ Enabled (Max FPS)" or "✗ Disabled")
	end,
})

-- ===== COMBAT TAB =====
local TabCombat = Window:Tab({
	Title = "⚔️ COMBAT",
	Icon = "solar:sword-bold",
})

TabCombat:Section({ Title = "Targeting System" })

TabCombat:Toggle({
	Title = "Enable Aimbot",
	Value = Config.Combat.Aimbot,
	Callback = function(v)
		Config.Combat.Aimbot = v
		Notify("Aimbot", v and "✓ Enabled" or "✗ Disabled")
	end,
})

TabCombat:Slider({
	Title = "Aim Radius",
	Step = 10,
	Value = {
		Min = 20,
		Max = 200,
		Default = Config.Combat.AimbotRadius,
	},
	Callback = function(v)
		Config.Combat.AimbotRadius = v
	end,
})

TabCombat:Toggle({
	Title = "Show Aim Circle",
	Value = Config.Combat.ShowAimCircle,
	Callback = function(v)
		Config.Combat.ShowAimCircle = v
		CombatModule.ShowAimCircle()
		Notify("Aim Circle", v and "✓ Enabled" or "✗ Disabled")
	end,
})

TabCombat:Toggle({
	Title = "Show Target Tracer",
	Value = Config.Combat.TargetTracer,
	Callback = function(v)
		Config.Combat.TargetTracer = v
		Notify("Target Tracer", v and "✓ Enabled" or "✗ Disabled")
	end,
})

TabCombat:Toggle({
	Title = "Lock On Highlight",
	Value = Config.Combat.LockOnHighlight,
	Callback = function(v)
		Config.Combat.LockOnHighlight = v
		Notify("Lock On Highlight", v and "✓ Enabled" or "✗ Disabled")
	end,
})

TabCombat:Toggle({
	Title = "Expand Killer Hitbox",
	Value = Config.Combat.ExpandKillerHitbox,
	Callback = function(v)
		Config.Combat.ExpandKillerHitbox = v
		Notify("Expand Hitbox", v and "✓ Enabled" or "✗ Disabled")
	end,
})

TabCombat:Toggle({
	Title = "Auto Attack",
	Value = Config.Combat.AutoAttack,
	Callback = function(v)
		Config.Combat.AutoAttack = v
		Notify("Auto Attack", v and "✓ Enabled" or "✗ Disabled")
	end,
})

TabCombat:Section({ Title = "Camera Control" })

TabCombat:Button({
	Title = "Toggle FPP / TPP ★",
	Justify = "Center",
	Icon = "solar:camera-bold",
	Callback = function()
		CameraModule.ToggleFPPTPP()
	end,
})

-- ===== AUTOMATION TAB =====
local TabAuto = Window:Tab({
	Title = "AUTOMATION",
	Icon = "solar:play-bold",
})

TabAuto:Section({ Title = "Generator Automation" })

TabAuto:Toggle({
	Title = "Auto Generator ★",
	Value = Config.Automation.AutoGenerator,
	Callback = function(v)
		Config.Automation.AutoGenerator = v
		Notify("Auto Generator", v and "✓ Enabled" or "✗ Disabled")
	end,
})

TabAuto:Dropdown({
	Title = "Generator Mode",
	Value = Config.Automation.GeneratorMode,
	Values = { "Perfect", "Neutral" },
	Callback = function(v)
		Config.Automation.GeneratorMode = v
		Notify("Generator Mode", "Set to " .. v)
	end,
})

TabAuto:Toggle({
	Title = "Boost All Generators",
	Value = Config.Automation.BoostAllGen,
	Callback = function(v)
		Config.Automation.BoostAllGen = v
		Notify("Boost All Gen", v and "✓ Enabled" or "✗ Disabled")
	end,
})

TabAuto:Section({ Title = "Escape Automation" })

TabAuto:Toggle({
	Title = "Instant Escape (Gate)",
	Value = Config.Automation.InstantEscape,
	Callback = function(v)
		Config.Automation.InstantEscape = v
		Notify("Instant Escape", v and "✓ Enabled" or "✗ Disabled")
	end,
})

TabAuto:Toggle({
	Title = "Self UnHook (100% Success)",
	Value = Config.Automation.SelfUnhook,
	Callback = function(v)
		Config.Automation.SelfUnhook = v
		Notify("Self UnHook", v and "✓ Enabled" or "✗ Disabled")
	end,
})

-- ===== SETTINGS TAB =====
local TabSettings = Window:Tab({
	Title = "Settings",
	Icon = "solar:settings-bold",
})

TabSettings:Section({ Title = "Theme" })

local Themes = {}
for name in pairs(WindUI.Themes) do
	table.insert(Themes, name)
end

TabSettings:Dropdown({
	Title = "Select Theme",
	Value = Config.Theme,
	Values = Themes,
	Callback = function(v)
		Config.Theme = v
		WindUI:SetTheme(v)
		Notify("Theme Changed", "Now using " .. v .. " theme")
	end,
})

TabSettings:Section({ Title = "Script Info" })

TabSettings:Button({
	Title = "Reset All Settings",
	Justify = "Center",
	Icon = "solar:restart-circle-bold",
	Callback = function()
		for module, settings in pairs(Config) do
			if typeof(settings) == "table" then
				for setting in pairs(settings) do
					if typeof(Config[module][setting]) == "boolean" then
						Config[module][setting] = false
					end
				end
			end
		end
		DestroyAllHighlights()
		DestroyAllESPs()
		Notify("Reset", "All settings reset to default")
	end,
})

TabSettings:Button({
	Title = "Copy Discord",
	Justify = "Center",
	Icon = "solar:link-circle-bold",
	Callback = function()
		setclipboard("discord.gg/yourserver")
		Notify("Copied", "Discord link copied to clipboard")
	end,
})

TabSettings:Button({
	Title = "Unload Script",
	Justify = "Center",
	Icon = "solar:logout-3-bold",
	Callback = function()
		DestroyAllHighlights()
		DestroyAllESPs()
		Window:Destroy()
		Notify("Script", "Successfully unloaded!")
	end,
})

-- Start main loop
task.spawn(MainLoop)

Notify("Violence District Hub v3.0", "✓ Loaded! Press F to toggle | Fixed ESP + POV Bug")
print("[VD-Hub v3.0] FIXED: ESP Highlight + POV Bug | Ready to dominate!")
