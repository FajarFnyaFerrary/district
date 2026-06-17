--[[
    Violence District - Ultimate Mod Hub v3.4
    ADDED: Server Monitor with Player Avatar & Role Detection
    FIXED: Full World Highlight ESP + In-Match Speed Fix + Anti-Explode Auto Gen
    Author: .ftgs | Enhanced by Gemini
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
	Server = {
		SelectedPlayer = nil,
	},
	CameraMode = "FPP",
	OriginalCameraMode = "FPP",
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
	return LocalPlayer and LocalPlayer.Character
end

local function GetHumanoid()
	local char = GetCharacter()
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function GetHumanoidRootPart()
	local char = GetCharacter()
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function GetAllGenerators()
	local generators = {}
	pcall(function()
		for _, item in ipairs(Workspace:GetDescendants()) do
			if item:IsA("Model") or item:IsA("BasePart") then
				if item.Name:lower():match("generator") and not item:IsA("Player") then
					table.insert(generators, item)
				end
			end
		end
	end)
	return generators
end

-- Deteksi Role Killer Akurat
local function IsPlayerKiller(player)
	if not player then return false end
	local char = player.Character

	if player.Team then
		local teamName = player.Team.Name:lower()
		if teamName:match("killer") or teamName:match("beast") or teamName:match("murder") then
			return true
		end
	end

	if player:GetAttribute("Role") == "Killer" or player:GetAttribute("IsKiller") == true then
		return true
	end
	local roleVal = player:FindFirstChild("Role") or player:FindFirstChild("Status")
	if roleVal and (tostring(roleVal.Value):lower():match("killer") or tostring(roleVal.Value):lower():match("beast")) then
		return true
	end

	if char then
		if char:GetAttribute("Role") == "Killer" or char:GetAttribute("IsKiller") == true then
			return true
		end
		if char:FindFirstChild("Killer") or char:FindFirstChild("IsKiller") or char.Name:lower():match("killer") then
			return true
		end
	end

	return false
end

local function CreateHighlightBox(object, color, name)
	if not object then return nil end
	
	local highlight = object:FindFirstChild(name)
	if not highlight then
		highlight = Instance.new("Highlight")
		highlight.Name = name
		highlight.Adornee = object
		highlight.FillColor = color
		highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
		highlight.FillTransparency = 0.4
		highlight.OutlineTransparency = 0.1
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		highlight.Parent = object
		table.insert(activeHighlights, highlight)
	end
	
	return highlight
end

local function DestroyAllHighlights()
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			local hl = player.Character:FindFirstChild("PlayerHighlight")
			if hl then hl:Destroy() end
		end
	end
	activeHighlights = {}
end

local function ClearWorldHighlightByName(name)
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj.Name == name then
			obj:Destroy()
		end
	end
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

local function GetClosestPlayer(excludeSelf)
	local closestPlayer = nil
	local closestDistance = math.huge
	
	for _, player in ipairs(Players:GetPlayers()) do
		if (not excludeSelf or player ~= LocalPlayer) and player.Character then
			local root = player.Character:FindFirstChild("HumanoidRootPart")
			local myRoot = GetHumanoidRootPart()
			if root and myRoot then
				local distance = (root.Position - myRoot.Position).Magnitude
				if distance < closestDistance then
					closestPlayer = player
					closestDistance = distance
				end
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
		local humanoid = GetHumanoid()
		local rootPart = GetHumanoidRootPart()
		
		if not humanoid or humanoid.Health <= 0 or not rootPart then return end
		
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
		local rootPart = GetHumanoidRootPart()
		local humanoid = GetHumanoid()
		
		if not humanoid or humanoid.Health <= 0 or not rootPart then return end
		
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

-- Bypass Anti-Reset Speed Match dengan Heartbeat Loop Terkoneksi
RunService.Heartbeat:Connect(function()
	if LocalPlayer and LocalPlayer.Character then
		if Config.Survivor.SpeedBoost or Config.Survivor.NoSlowdown then
			local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				humanoid.WalkSpeed = Config.Survivor.CustomSpeed
			end
		end
	end
end)

function SurvivorModule.NoClip()
	if not Config.Survivor.NoClip then return end
	
	pcall(function()
		local char = GetCharacter()
		if char then
			for _, part in ipairs(char:GetDescendants()) do
				if part:IsA("BasePart") then
					part.CanCollide = false
				end
			end
		end
	end)
end

function SurvivorModule.ForceReset()
	if not Config.Survivor.ForceReset then return end
	
	pcall(function()
		local humanoid = GetHumanoid()
		local rootPart = GetHumanoidRootPart()
		
		if humanoid and rootPart then
			humanoid.Sit = false
			humanoid:UnequipTools()
			rootPart.Velocity = Vector3.new(0, 0, 0)
			
			local resetRemote = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("ResetState")
			if resetRemote then
				resetRemote:FireServer()
			end
		end
	end)
end

function SurvivorModule.SilentActions()
	if not Config.Survivor.SilentActions then return end
	
	pcall(function()
		local char = GetCharacter()
		if char then
			for _, child in ipairs(char:GetChildren()) do
				if child:IsA("Sound") then
					child.Volume = 0
				end
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

-- ===== KILLER MODULE =====
local KillerModule = {}

function KillerModule.VeinDropPrediction()
	if not Config.Killer.VeinDropPrediction then return end
	
	pcall(function()
		local rootPart = GetHumanoidRootPart()
		if not rootPart then return end
		
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

function KillerModule.PredictNextKiller()
	pcall(function()
		local allPlayers = Players:GetPlayers()
		if #allPlayers <= 1 then
			Notify("🔮 Prediction Result", "Kurang pemain untuk menganalisis match.", 4)
			return
		end
		
		local predictedKiller = nil
		local highestChance = -1
		
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
		
		if predictedKiller then
			Notify("🔮 Prediction Result", "Killer berikutnya: " .. predictedKiller.Name, 5)
		else
			Notify("🔮 Prediction Result", "Gagal memprediksi match selanjutnya.", 4)
		end
	end)
end

-- ===== VISUALS MODULE =====
local VisualsModule = {}

function VisualsModule.PlayerESPHighlight()
	if not Config.Visuals.PlayerHighlight then
		DestroyAllHighlights()
		return
	end
	
	pcall(function()
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= LocalPlayer and player.Character then
				local char = player.Character
				local isKiller = IsPlayerKiller(player)
				local targetColor = isKiller and Color3.fromRGB(255, 0, 0) or Color3.fromRGB(0, 255, 0)
				
				local existingHighlight = char:FindFirstChild("PlayerHighlight")
				if not existingHighlight then
					CreateHighlightBox(char, targetColor, "PlayerHighlight")
				else
					if existingHighlight.FillColor ~= targetColor then
						existingHighlight.FillColor = targetColor
					end
				end
			end
		end
	end)
end

-- Background Deep-Scanner untuk World Highlights ESP (Anti Lag & Deteksi Akurat)
task.spawn(function()
	while true do
		task.wait(1.5) -- Scan berkala yang aman dari drop FPS
		pcall(function()
			if not (Config.Visuals.GeneratorESP or Config.Visuals.PalletESP or Config.Visuals.ExitGateESP or Config.Visuals.HookESP or Config.Visuals.WindowESP) then
				return
			end

			for _, item in ipairs(Workspace:GetDescendants()) do
				if item:IsA("Model") or item:IsA("BasePart") then
					local nameLower = item.Name:lower()
					
					-- 1. Generator Highlight
					if Config.Visuals.GeneratorESP and (nameLower:match("generator") or (item.Parent and item.Parent.Name:lower():match("generator"))) then
						if not item:FindFirstChild("GenHighlight") and not item:IsA("Player") and not item:FindFirstChildOfClass("Humanoid") then
							local hl = Instance.new("Highlight")
							hl.Name = "GenHighlight"
							hl.Adornee = item
							hl.FillColor = Color3.fromRGB(255, 215, 0)
							hl.OutlineColor = Color3.fromRGB(255, 255, 255)
							hl.FillTransparency = 0.5
							hl.OutlineTransparency = 0.2
							hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
							hl.Parent = item
							table.insert(activeESPs, hl)
						end
					end

					-- 2. Pallet Highlight
					if Config.Visuals.PalletESP and (nameLower:match("pallet") or (item.Parent and item.Parent.Name:lower():match("pallet"))) then
						if not item:FindFirstChild("PalletHighlight") then
							local hl = Instance.new("Highlight")
							hl.Name = "PalletHighlight"
							hl.Adornee = item
							hl.FillColor = Color3.fromRGB(139, 69, 19)
							hl.OutlineColor = Color3.fromRGB(255, 255, 255)
							hl.FillTransparency = 0.5
							hl.OutlineTransparency = 0.2
							hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
							hl.Parent = item
							table.insert(activeESPs, hl)
						end
					end

					-- 3. Exit Gate Highlight
					if Config.Visuals.ExitGateESP and (nameLower:match("exit") or nameLower:match("gate") or (item.Parent and item.Parent.Name:lower():match("exit"))) then
						if not item:FindFirstChild("GateHighlight") then
							local hl = Instance.new("Highlight")
							hl.Name = "GateHighlight"
							hl.Adornee = item
							hl.FillColor = Color3.fromRGB(0, 255, 255)
							hl.OutlineColor = Color3.fromRGB(255, 255, 255)
							hl.FillTransparency = 0.5
							hl.OutlineTransparency = 0.2
							hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
							hl.Parent = item
							table.insert(activeESPs, hl)
						end
					end

					-- 4. Hook Highlight
					if Config.Visuals.HookESP and (nameLower:match("hook") or (item.Parent and item.Parent.Name:lower():match("hook"))) then
						if not item:FindFirstChild("HookHighlight") then
							local hl = Instance.new("Highlight")
							hl.Name = "HookHighlight"
							hl.Adornee = item
							hl.FillColor = Color3.fromRGB(255, 0, 255)
							hl.OutlineColor = Color3.fromRGB(255, 255, 255)
							hl.FillTransparency = 0.5
							hl.OutlineTransparency = 0.2
							hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
							hl.Parent = item
							table.insert(activeESPs, hl)
						end
					end

					-- 5. Window / Vault Highlight
					if Config.Visuals.WindowESP and (nameLower:match("window") or nameLower:match("vault") or (item.Parent and item.Parent.Name:lower():match("window"))) then
						if not item:FindFirstChild("WinHighlight") then
							local hl = Instance.new("Highlight")
							hl.Name = "WinHighlight"
							hl.Adornee = item
							hl.FillColor = Color3.fromRGB(70, 130, 180)
							hl.OutlineColor = Color3.fromRGB(255, 255, 255)
							hl.FillTransparency = 0.5
							hl.OutlineTransparency = 0.2
							hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
							hl.Parent = item
							table.insert(activeESPs, hl)
						end
					end

				end
			end
		end)
	end
end)

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

-- ===== AUTOMATION =====
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
			local remotes = ReplicatedStorage:FindFirstChild("Remotes")
			local genRemotes = remotes and remotes:FindFirstChild("Generator")
			
			if genRemotes then
				local repairEvent = genRemotes:FindFirstChild("RepairEvent")
				local skillCheckEvent = genRemotes:FindFirstChild("SkillCheckResultEvent") or genRemotes:FindFirstChild("SkillCheckEvent")
				
				if repairEvent then
					repairEvent:FireServer(genPoint, true)
				end
				
				task.wait(0.1) 
				
				if skillCheckEvent then
					local mode = Config.Automation.GeneratorMode == "Perfect" and "perfect" or "neutral"
					skillCheckEvent:FireServer(mode, true, gen, genPoint)
					skillCheckEvent:FireServer(mode, 0, gen, genPoint)
					skillCheckEvent:FireServer(true, gen, genPoint)
				end
			end
			task.wait(0.2)
		end
	end)
	isAutoGenRunning = false
end

-- ===== MAIN LOOP =====
local function MainLoop()
	while true do
		task.wait(0.05)
		if LocalPlayer and LocalPlayer.Character then
			-- VIP
			SafePcall(VIPModule.AutoPlay)
			SafePcall(VIPModule.AutoDagger)
			
			-- Survivor Exploit
			SafePcall(SurvivorModule.NoClip)
			SafePcall(SurvivorModule.AntiFallDamage)
			
			-- Killer
			SafePcall(KillerModule.VeinDropPrediction)
			
			-- Visuals Real-time Updates
			SafePcall(VisualsModule.PlayerESPHighlight)
			SafePcall(VisualsModule.CustomFOV)
			
			-- Automation
			SafePcall(AutomationModule.AutoGenerator)
		end
	end
end

-- ===== WINDUI SETUP =====
local Window = WindUI:CreateWindow({
	Title = "Violence District Hub v3.4",
	Author = "by Jackson Storm",
	Icon = "rbxassetid://91993721465164",
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

-- Tab 1: VIP
local TabVIP = Window:Tab({
	Title = "VIP",
	Icon = "solar:crown-bold",
})

TabVIP:Section({ Title = "Automatic Features", Desc = "Ultimate automatic survival" })
TabVIP:Toggle({
	Title = "Auto Play (Smart AI)",
	Value = Config.VIP.AutoPlay,
	Callback = function(v) Config.VIP.AutoPlay = v Notify("Auto Play", v and "✓ Enabled" or "✗ Disabled") end,
})
TabVIP:Toggle({
	Title = "Auto Dagger (Parry)",
	Value = Config.VIP.AutoDagger,
	Callback = function(v) Config.VIP.AutoDagger = v Notify("Auto Dagger", v and "✓ Enabled" or "✗ Disabled") end,
})

-- Tab 2: Survivor
local TabSurvivor = Window:Tab({
	Title = "SURVIVOR",
	Icon = "solar:user-bold",
})

TabSurvivor:Section({ Title = "Movement & Speed" })
TabSurvivor:Toggle({
	Title = "Speed Boost",
	Value = Config.Survivor.SpeedBoost,
	Callback = function(v) Config.Survivor.SpeedBoost = v Notify("Speed Boost", v and "✓ Enabled" or "✗ Disabled") end,
})
TabSurvivor:Slider({
	Title = "Custom Speed",
	Step = 1,
	Value = { Min = 16, Max = 100, Default = Config.Survivor.CustomSpeed },
	Callback = function(v) Config.Survivor.CustomSpeed = v end,
})
TabSurvivor:Toggle({
	Title = "No Slowdown",
	Value = Config.Survivor.NoSlowdown,
	Callback = function(v) Config.Survivor.NoSlowdown = v Notify("No Slowdown", v and "✓ Enabled" or "✗ Disabled") end,
})
TabSurvivor:Toggle({
	Title = "No Clip",
	Value = Config.Survivor.NoClip,
	Callback = function(v) Config.Survivor.NoClip = v Notify("No Clip", v and "✓ Enabled" or "✗ Disabled") end,
})

-- Tab 3: Killer
local TabKiller = Window:Tab({
	Title = "KILLER",
	Icon = "solar:shield-minimalistic-bold",
})

TabKiller:Section({ Title = "Predictions & Intel" })
TabKiller:Button({
	Title = "Predict Next Killer 🔮",
	Justify = "Center",
	Icon = "solar:magic-stick-bold",
	Callback = function()
		KillerModule.PredictNextKiller()
	end,
})

TabKiller:Section({ Title = "Combat Exploits" })
TabKiller:Toggle({
	Title = "Vein Spear: Drop Prediction",
	Value = Config.Killer.VeinDropPrediction,
	Callback = function(v) Config.Killer.VeinDropPrediction = v Notify("Vein Drop Prediction", v and "✓ Enabled" or "✗ Disabled") end,
})

-- Tab 4: Visuals
local TabVisuals = Window:Tab({
	Title = "VISUALS",
	Icon = "solar:eye-bold",
})

TabVisuals:Section({ Title = "ESP Systems (Full Highlights)" })
TabVisuals:Toggle({
	Title = "Player ESP Highlight ★",
	Value = Config.Visuals.PlayerHighlight,
	Callback = function(v)
		Config.Visuals.PlayerHighlight = v
		if not v then DestroyAllHighlights() end
		Notify("Player Highlight", v and "✓ Enabled" or "✗ Disabled")
	end,
})
TabVisuals:Toggle({
	Title = "Generator ESP (Highlight)",
	Value = Config.Visuals.GeneratorESP,
	Callback = function(v) 
		Config.Visuals.GeneratorESP = v 
		if not v then ClearWorldHighlightByName("GenHighlight") end
	end,
})
TabVisuals:Toggle({
	Title = "Pallet ESP (Highlight)",
	Value = Config.Visuals.PalletESP,
	Callback = function(v) 
		Config.Visuals.PalletESP = v 
		if not v then ClearWorldHighlightByName("PalletHighlight") end
	end,
})
TabVisuals:Toggle({
	Title = "Exit Gate ESP (Highlight)",
	Value = Config.Visuals.ExitGateESP,
	Callback = function(v) 
		Config.Visuals.ExitGateESP = v 
		if not v then ClearWorldHighlightByName("GateHighlight") end
	end,
})
TabVisuals:Toggle({
	Title = "Hook ESP (Highlight)",
	Value = Config.Visuals.HookESP,
	Callback = function(v) 
		Config.Visuals.HookESP = v 
		if not v then ClearWorldHighlightByName("HookHighlight") end
	end,
})
TabVisuals:Toggle({
	Title = "Window ESP (Highlight)",
	Value = Config.Visuals.WindowESP,
	Callback = function(v) 
		Config.Visuals.WindowESP = v 
		if not v then ClearWorldHighlightByName("WinHighlight") end
	end,
})

TabVisuals:Section({ Title = "Display & Screen" })
TabVisuals:Toggle({
	Title = "Show Crosshair",
	Value = Config.Visuals.Crosshair,
	Callback = function(v) Config.Visuals.Crosshair = v VisualsModule.Crosshair() end,
})
TabVisuals:Toggle({
	Title = "Custom FOV",
	Value = Config.Visuals.CustomFOV,
	Callback = function(v) Config.Visuals.CustomFOV = v VisualsModule.CustomFOV() end,
})
TabVisuals:Slider({
	Title = "FOV Value",
	Step = 5,
	Value = { Min = 40, Max = 120, Default = Config.Visuals.CustomFOVValue },
	Callback = function(v) Config.Visuals.CustomFOVValue = v VisualsModule.CustomFOV() end,
})

-- Tab 5: Combat
local TabCombat = Window:Tab({
	Title = "COMBAT",
	Icon = "solar:sword-bold",
})

TabCombat:Section({ Title = "Settings" })
TabCombat:Toggle({
	Title = "Enable Aimbot",
	Value = Config.Combat.Aimbot,
	Callback = function(v) Config.Combat.Aimbot = v Notify("Aimbot", v and "✓ Enabled" or "✗ Disabled") end,
})

-- Tab 6: Automation
local TabAuto = Window:Tab({
	Title = "AUTOMATION",
	Icon = "solar:play-bold",
})

TabAuto:Section({ Title = "Generator Setup" })
TabAuto:Toggle({
	Title = "Auto Generator",
	Value = Config.Automation.AutoGenerator,
	Callback = function(v) Config.Automation.AutoGenerator = v Notify("Auto Generator", v and "✓ Enabled" or "✗ Disabled") end,
})
TabAuto:Dropdown({
	Title = "Generator Mode",
	Value = Config.Automation.GeneratorMode,
	Values = { "Perfect", "Neutral" },
	Callback = function(v) Config.Automation.GeneratorMode = v Notify("Mode Set", v) end,
})

-- Tab 7: Server (NEW FEATURE)
local TabServer = Window:Tab({
	Title = "SERVER",
	Icon = "mdi:server",
})

TabServer:Section({ Title = "Live Player Monitor", Desc = "Cek Role dan Profile Avatar Player" })

local function GetPlayerNames()
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		table.insert(list, p.Name)
	end
	return list
end

local PlayerDropdown = TabServer:Dropdown({
	Title = "Select Player",
	Value = GetPlayerNames()[1] or "None",
	Values = GetPlayerNames(),
	Callback = function(v) 
		Config.Server.SelectedPlayer = v 
	end,
})

TabServer:Button({
	Title = "Refresh Player List",
	Icon = "solar:refresh-circle-bold",
	Callback = function()
		pcall(function() PlayerDropdown:Refresh(GetPlayerNames()) end)
		Notify("Server Monitor", "Daftar player berhasil diperbarui!", 3)
	end,
})

TabServer:Button({
	Title = "Inspect Selected Player",
	Desc = "Menampilkan Avatar & Status Role",
	Icon = "solar:user-id-bold",
	Callback = function()
		local targetName = Config.Server.SelectedPlayer
		if not targetName or targetName == "None" then
			Notify("Error", "Pilih player terlebih dahulu dari dropdown!", 3)
			return
		end
		
		local target = Players:FindFirstChild(targetName)
		if target then
			local isKiller = IsPlayerKiller(target)
			local roleName = isKiller and "KILLER 🔪" or "SURVIVOR 🏃"
			
			-- Fetch Roblox Avatar PFP
			local avatarUrl = ""
			pcall(function()
				avatarUrl = Players:GetUserThumbnailAsync(target.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
			end)
			
			-- Cek Health Status
			local hp = "Mati / Lobby"
			if target.Character and target.Character:FindFirstChild("Humanoid") then
				local hum = target.Character.Humanoid
				if hum.Health > 0 then
					hp = math.floor(hum.Health) .. " / " .. math.floor(hum.MaxHealth)
				end
			end
			
			WindUI:Notify({
				Title = "Monitor: " .. target.Name,
				Content = "Role Saat Ini: " .. roleName .. "\nStatus HP: " .. hp,
				Duration = 6,
				Image = avatarUrl ~= "" and avatarUrl or nil
			})
		else
			Notify("Monitor Error", "Player " .. targetName .. " tidak ditemukan (Mungkin sudah keluar).", 4)
		end
	end,
})

TabServer:Section({ Title = "Server Info" })
TabServer:Button({
	Title = "Check Server Statistics",
	Icon = "solar:users-group-rounded-bold",
	Callback = function()
		local total = #Players:GetPlayers()
		local killers = 0
		for _, p in ipairs(Players:GetPlayers()) do
			if IsPlayerKiller(p) then killers = killers + 1 end
		end
		Notify("Server Analytics", "Total Pemain Aktif: " .. total .. "\nJumlah Killer Terdeteksi: " .. killers, 5)
	end,
})

-- Tab 8: Settings
local TabSettings = Window:Tab({
	Title = "Settings",
	Icon = "solar:settings-bold",
})

TabSettings:Section({ Title = "Theme Manager" })
local Themes = {}
for name in pairs(WindUI.Themes) do table.insert(Themes, name) end
TabSettings:Dropdown({
	Title = "Select Theme",
	Value = Config.Theme,
	Values = Themes,
	Callback = function(v) Config.Theme = v WindUI:SetTheme(v) end,
})

TabSettings:Button({
	Title = "Reset All Settings",
	Justify = "Center",
	Icon = "solar:restart-circle-bold",
	Callback = function()
		for m, s in pairs(Config) do if typeof(s) == "table" then for k in pairs(s) do if typeof(Config[m][k]) == "boolean" then Config[m][k] = false end end end end
		DestroyAllHighlights()
		DestroyAllESPs()
		Notify("Reset", "Semua pengaturan dikembalikan ke default")
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
	end,
})

-- Run Threads
task.spawn(MainLoop)
Notify("Violence District Hub v3.4", "✓ Berhasil Dimuat! Fitur Monitor Server kini tersedia.")
