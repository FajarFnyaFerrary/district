--[[
    WindUI Remote Event Spy Example
    Script untuk monitor dan display semua Remote Event/Function calls
    dengan search bar dan example script generation
]]

local cloneref = (cloneref or clonereference or function(instance)
	return instance
end)

local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local RunService = cloneref(game:GetService("RunService"))

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
			WindUI =
				loadstring(game:HttpGet("https://raw.githubusercontent.com/FajarFnyaFerrary/district/main/dist/main.lua"))()
		end
	end
end

local Window = WindUI:CreateWindow({
	Title = "Remote Event Spy",
	Author = "by .ftgs",
	Icon = "solar:bug-bold",
	Theme = "Dark",
	NewElements = true,
	Transparent = true,
	ToggleKey = Enum.KeyCode.F,
	Acrylic = true,
})

-- ==================== SPY CONFIGURATION ====================
local SpyConfig = {
	MaxLogs = 100,
	ShowArguments = true,
	FilterRemotes = {
		Include = {}, -- Jika kosong, track semua. Isi dengan nama remote untuk filter spesifik
		Exclude = {}, -- Remote yang ingin diexclude
	},
	Colors = {
		RemoteEvent = Color3.fromRGB(0, 200, 100),
		RemoteFunction = Color3.fromRGB(100, 150, 255),
		FireServer = Color3.fromRGB(255, 200, 0),
		InvokeServer = Color3.fromRGB(255, 100, 100),
	},
}

-- ==================== DATA STRUCTURE ====================
local SpyData = {
	Logs = {}, -- Menyimpan semua log
	RemotesCaught = {}, -- Menyimpan remote yang tertangkap
	IsSpying = true,
	ScrollPosition = 0,
	SearchQuery = "",
	SelectedLog = nil,
}

-- ==================== UTILITY FUNCTIONS ====================
local function getArgumentString(args)
	if not args or #args == 0 then
		return "No Arguments"
	end

	local argStrings = {}
	for i, arg in ipairs(args) do
		local argType = typeof(arg)
		local argStr

		if argType == "string" then
			argStr = '"' .. tostring(arg):sub(1, 50) .. '"'
		elseif argType == "number" then
			argStr = tostring(arg)
		elseif argType == "boolean" then
			argStr = tostring(arg)
		elseif argType == "Instance" then
			argStr = arg.ClassName .. ": " .. arg.Name
		elseif argType == "table" then
			argStr = "Table (" .. #arg .. " items)"
		else
			argStr = argType
		end

		table.insert(argStrings, argStr)
	end

	return table.concat(argStrings, ", ")
end

local function argumentToLua(arg)
	local argType = typeof(arg)

	if argType == "string" then
		return '"' .. tostring(arg):gsub('"', '\\"') .. '"'
	elseif argType == "number" then
		return tostring(arg)
	elseif argType == "boolean" then
		return tostring(arg)
	elseif argType == "Instance" then
		return 'game:FindFirstChild("' .. arg.Name .. '")'
	elseif argType == "table" then
		local parts = {}
		for i, v in ipairs(arg) do
			table.insert(parts, argumentToLua(v))
		end
		return "{" .. table.concat(parts, ", ") .. "}"
	else
		return "nil"
	end
end

local function generateExampleScript(log)
	local remotePath = log.RemoteName

	local script = '--[[ Generated from Remote Event Spy ]]\n'
	script = script .. 'local remote = game:FindService("ReplicatedStorage"):FindFirstChild("' .. string.match(remotePath, "[^/]+$") .. '")\n'
	script = script .. 'if remote then\n'

	if log.RemoteType == "RemoteEvent" then
		script = script .. '\tremote:FireServer('
		if log.Arguments and #log.Arguments > 0 then
			local argParts = {}
			for _, arg in ipairs(log.Arguments) do
				table.insert(argParts, argumentToLua(arg))
			end
			script = script .. table.concat(argParts, ", ")
		end
		script = script .. ')\n'
	else
		script = script .. '\tlocal result = remote:InvokeServer('
		if log.Arguments and #log.Arguments > 0 then
			local argParts = {}
			for _, arg in ipairs(log.Arguments) do
				table.insert(argParts, argumentToLua(arg))
			end
			script = script .. table.concat(argParts, ", ")
		end
		script = script .. ')\n'
		script = script .. '\tprint("Result:", result)\n'
	end

	script = script .. 'else\n'
	script = script .. '\tprint("Remote not found")\n'
	script = script .. 'end\n'

	return script
end

local function shouldTrackRemote(remoteName)
	-- Check include filter
	if #SpyConfig.FilterRemotes.Include > 0 then
		local found = false
		for _, name in ipairs(SpyConfig.FilterRemotes.Include) do
			if string.find(remoteName, name, 1, true) then
				found = true
				break
			end
		end
		if not found then
			return false
		end
	end

	-- Check exclude filter
	for _, name in ipairs(SpyConfig.FilterRemotes.Exclude) do
		if string.find(remoteName, name, 1, true) then
			return false
		end
	end

	return true
end

local function addLog(remoteType, remoteName, method, arguments)
	if not shouldTrackRemote(remoteName) then
		return
	end

	local logEntry = {
		Timestamp = os.time(),
		RemoteType = remoteType,
		RemoteName = remoteName,
		Method = method,
		Arguments = arguments,
		ArgumentString = getArgumentString(arguments),
	}

	table.insert(SpyData.Logs, 1, logEntry) -- Insert di awal untuk newest first

	-- Batasi maksimal logs
	if #SpyData.Logs > SpyConfig.MaxLogs then
		table.remove(SpyData.Logs, SpyConfig.MaxLogs + 1)
	end

	-- Track remote yang tertangkap
	if not SpyData.RemotesCaught[remoteName] then
		SpyData.RemotesCaught[remoteName] = {
			Type = remoteType,
			CallCount = 0,
			LastCalled = os.time(),
		}
	end

	SpyData.RemotesCaught[remoteName].CallCount = SpyData.RemotesCaught[remoteName].CallCount + 1
	SpyData.RemotesCaught[remoteName].LastCalled = os.time()
end

local function getFilteredLogs()
	if SpyData.SearchQuery == "" then
		return SpyData.Logs
	end

	local filtered = {}
	local query = SpyData.SearchQuery:lower()

	for _, log in ipairs(SpyData.Logs) do
		if string.find(log.RemoteName:lower(), query, 1, true) or
			string.find(log.ArgumentString:lower(), query, 1, true) or
			string.find(log.Method:lower(), query, 1, true) then
			table.insert(filtered, log)
		end
	end

	return filtered
end

local function hookRemotes(parent)
	if not parent then
		return
	end

	for _, child in pairs(parent:GetChildren()) do
		if child:IsA("RemoteEvent") then
			local originalFireServer = child.FireServer
			local remoteName = child:GetFullName()

			if not SpyData.RemotesCaught[remoteName] or
				(SpyData.RemotesCaught[remoteName] and SpyData.RemotesCaught[remoteName].Type ~= "RemoteEvent") then

				child.FireServer = function(self, ...)
					local args = { ... }
					addLog("RemoteEvent", remoteName, "FireServer", args)
					return originalFireServer(self, ...)
				end
			end
		elseif child:IsA("RemoteFunction") then
			local originalInvokeServer = child.InvokeServer
			local remoteName = child:GetFullName()

			if not SpyData.RemotesCaught[remoteName] or
				(SpyData.RemotesCaught[remoteName] and SpyData.RemotesCaught[remoteName].Type ~= "RemoteFunction") then

				child.InvokeServer = function(self, ...)
					local args = { ... }
					addLog("RemoteFunction", remoteName, "InvokeServer", args)
					return originalInvokeServer(self, ...)
				end
			end
		end

		-- Recursive hook untuk nested remotes
		hookRemotes(child)
	end
end

-- ==================== WINDOW UI ====================
local Tab1 = Window:Tab({
	Title = "Live Monitor",
	Icon = "solar:eye-bold",
})

local Tab2 = Window:Tab({
	Title = "Statistics",
	Icon = "solar:chart-2-bold",
})

local Tab3 = Window:Tab({
	Title = "Settings",
	Icon = "solar:settings-bold",
})

local Tab4 = Window:Tab({
	Title = "Script Details",
	Icon = "solar:code-bold",
})

Tab1:Select()

-- ==================== TAB 1: LIVE MONITOR ====================
Tab1:Section({
	Title = "Search & Filter",
	Desc = "Cari remote events berdasarkan nama atau arguments",
})

Tab1:Space({ Columns = 1 })

local SearchInput = Tab1:TextInput({
	Title = "Search Remote",
	PlaceHolder = "Ketik nama remote atau argument...",
	Value = "",
	Callback = function(value)
		SpyData.SearchQuery = value
	end,
})

Tab1:Space({ Columns = 1 })

Tab1:Section({
	Title = "Live Remote Calls",
	Desc = "Monitor semua remote event/function yang dipanggil",
})

Tab1:Space({ Columns = 1 })

local Group1 = Tab1:Group()

Group1:Toggle({
	Title = "Enable Spy",
	Value = true,
	Callback = function(value)
		SpyData.IsSpying = value
		if value then
			WindUI:Notify({
				Title = "Spy Enabled",
				Content = "Remote event monitoring aktif",
			})
		else
			WindUI:Notify({
				Title = "Spy Disabled",
				Content = "Remote event monitoring dimatikan",
			})
		end
	end,
})

Group1:Space({ Columns = 0.5 })

Group1:Button({
	Title = "Clear Logs",
	Icon = "solar:trash-bin-trash-bold",
	Callback = function()
		SpyData.Logs = {}
		SpyData.SelectedLog = nil
		WindUI:Notify({
			Title = "Cleared",
			Content = "Semua logs telah dihapus",
		})
	end,
})

Tab1:Space({ Columns = 1 })

Tab1:Section({
	Title = "Logs",
	Desc = "Klik untuk melihat example script",
})

local LogButtonsHolder = {}
local LogContainer = Tab1:Group()

local function updateLogDisplay()
	-- Clear previous buttons
	LogButtonsHolder = {}

	local filteredLogs = getFilteredLogs()

	if #filteredLogs == 0 then
		local emptyText = Tab1:Paragraph({
			Title = "No Logs",
			Content = "Belum ada remote calls yang tertangkap atau hasil search kosong",
		})
		return
	end

	for i = 1, math.min(20, #filteredLogs) do
		local log = filteredLogs[i]
		local timeStr = os.date("%H:%M:%S", log.Timestamp)
		local icon = log.RemoteType == "RemoteEvent" and "🔴" or "🔵"

		local buttonText = icon
			.. " ["
			.. timeStr
			.. "] "
			.. log.Method
			.. "\n"
			.. log.RemoteName:sub(1, 60)
			.. "\n"
			.. log.ArgumentString:sub(1, 70)

		LogButtonsHolder[i] = LogContainer:Button({
			Title = buttonText,
			Justify = "Left",
			Size = "Small",
			Callback = function()
				SpyData.SelectedLog = log
				Tab4:Select()
			end,
		})
	end

	-- Update header dengan jumlah results
	Tab1:Section({
		Title = "Results: " .. #filteredLogs .. " / " .. #SpyData.Logs,
		Desc = "Klik salah satu untuk lihat example script",
	})
end

-- Update logs secara real-time
local lastUpdateTime = 0
RunService.RenderStepped:Connect(function()
	if os.time() - lastUpdateTime < 0.5 then
		return
	end
	lastUpdateTime = os.time()

	if not SpyData.IsSpying then
		return
	end

	updateLogDisplay()
end)

-- ==================== TAB 2: STATISTICS ====================
Tab2:Section({
	Title = "Remote Statistics",
	Desc = "Statistik remote events yang tertangkap",
})

Tab2:Space({ Columns = 1 })

local StatsText = Tab2:Paragraph({
	Title = "Statistics",
	Content = "Loading...",
})

RunService.RenderStepped:Connect(function()
	if os.time() - lastUpdateTime < 1 then
		return
	end

	local statsContent = "📊 Total Remote Calls: " .. #SpyData.Logs .. "\n"
	local uniqueCount = 0
	for _ in pairs(SpyData.RemotesCaught) do
		uniqueCount = uniqueCount + 1
	end
	statsContent = statsContent .. "🎯 Unique Remotes: " .. uniqueCount .. "\n\n"

	statsContent = statsContent .. "Top Called Remotes:\n"

	local sortedRemotes = {}
	for name, data in pairs(SpyData.RemotesCaught) do
		table.insert(sortedRemotes, { name = name, count = data.CallCount, type = data.Type })
	end

	table.sort(sortedRemotes, function(a, b)
		return a.count > b.count
	end)

	for i = 1, math.min(10, #sortedRemotes) do
		local remote = sortedRemotes[i]
		local icon = remote.type == "RemoteEvent" and "🔴" or "🔵"
		statsContent = statsContent
			.. icon
			.. " "
			.. remote.name:sub(1, 50)
			.. " - "
			.. remote.count
			.. " calls\n"
	end

	StatsText:SetContent(statsContent)
end)

-- ==================== TAB 3: SETTINGS ====================
Tab3:Section({
	Title = "Filter Settings",
	Desc = "Customize remote spy behavior",
})

Tab3:Space({ Columns = 1 })

Tab3:Paragraph({
	Title = "Include Filter",
	Content = "Jika kosong = track semua. Contoh: GetPullRequestData",
})

Tab3:Space({ Columns = 1 })

Tab3:Paragraph({
	Title = "Exclude Filter",
	Content = "Ketik nama remote untuk diabaikan",
})

Tab3:Space({ Columns = 1 })

local MaxLogsSlider = Tab3:Slider({
	Step = 10,
	Value = {
		Min = 10,
		Max = 500,
		Default = SpyConfig.MaxLogs,
	},
	Callback = function(value)
		SpyConfig.MaxLogs = value
	end,
})

Tab3:Space({ Columns = 2 })

local Group3 = Tab3:Group()

Group3:Button({
	Title = "Re-hook Remotes",
	Icon = "solar:refresh-bold",
	Callback = function()
		hookRemotes(ReplicatedStorage)
		hookRemotes(game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui"))
		WindUI:Notify({
			Title = "Re-hooked",
			Content = "Semua remotes telah di-re-hook",
		})
	end,
})

Group3:Space({ Columns = 0.5 })

Group3:Button({
	Title = "Hook Workspace",
	Icon = "solar:settings-minimalistic-bold",
	Callback = function()
		hookRemotes(workspace)
		WindUI:Notify({
			Title = "Hooked",
			Content = "Workspace remotes telah di-hook",
		})
	end,
})

-- ==================== TAB 4: SCRIPT DETAILS ====================
Tab4:Section({
	Title = "Remote Details",
	Desc = "Lihat dan copy example script dari remote yang dipilih",
})

Tab4:Space({ Columns = 1 })

local ScriptDetailsText = Tab4:Paragraph({
	Title = "No Remote Selected",
	Content = "Pilih remote dari Live Monitor tab untuk melihat details dan example script",
})

local ScriptCodeText = Tab4:Paragraph({
	Title = "Example Script",
	Content = "Generated script akan muncul di sini",
})

local Group4 = Tab4:Group()

Group4:Button({
	Title = "Copy Script",
	Icon = "solar:copy-bold",
	Size = "Small",
	Callback = function()
		if not SpyData.SelectedLog then
			WindUI:Notify({
				Title = "Error",
				Content = "Belum ada remote yang dipilih",
			})
			return
		end

		local script = generateExampleScript(SpyData.SelectedLog)

		-- Copy to clipboard (requires setclipboard)
		if setclipboard then
			setclipboard(script)
			WindUI:Notify({
				Title = "Copied!",
				Content = "Script telah dicopy ke clipboard",
			})
		else
			WindUI:Notify({
				Title = "Error",
				Content = "setclipboard tidak tersedia",
			})
		end
	end,
})

Group4:Space({ Columns = 0.5 })

Group4:Button({
	Title = "Run Script",
	Icon = "solar:play-bold",
	Size = "Small",
	Callback = function()
		if not SpyData.SelectedLog then
			WindUI:Notify({
				Title = "Error",
				Content = "Belum ada remote yang dipilih",
			})
			return
		end

		local script = generateExampleScript(SpyData.SelectedLog)

		-- Run the script
		local success, result = pcall(function()
			return loadstring(script)()
		end)

		if success then
			WindUI:Notify({
				Title = "Executed",
				Content = "Script telah dijalankan",
			})
		else
			WindUI:Notify({
				Title = "Error",
				Content = "Gagal menjalankan script: " .. tostring(result),
			})
		end
	end,
})

Group4:Space({ Columns = 0.5 })

Group4:Button({
	Title = "Load as String",
	Icon = "solar:download-square-bold",
	Size = "Small",
	Callback = function()
		if not SpyData.SelectedLog then
			WindUI:Notify({
				Title = "Error",
				Content = "Belum ada remote yang dipilih",
			})
			return
		end

		local script = generateExampleScript(SpyData.SelectedLog)

		-- Try to load the script and store result
		local func, err = loadstring(script)
		if func then
			_G.LastGeneratedScript = func
			WindUI:Notify({
				Title = "Loaded",
				Content = "Script loaded di _G.LastGeneratedScript",
			})
		else
			WindUI:Notify({
				Title = "Error",
				Content = "Gagal load script: " .. tostring(err),
			})
		end
	end,
})

-- Update script details display
RunService.RenderStepped:Connect(function()
	if not SpyData.SelectedLog then
		return
	end

	local log = SpyData.SelectedLog
	local details = "📋 Remote Information\n"
	details = details .. "━━━━━━━━━━━━━━━━━━━━━\n"
	details = details .. "Type: " .. log.RemoteType .. "\n"
	details = details .. "Method: " .. log.Method .. "\n"
	details = details .. "Time: " .. os.date("%Y-%m-%d %H:%M:%S", log.Timestamp) .. "\n"
	details = details .. "Full Path: " .. log.RemoteName .. "\n\n"
	details = details .. "Arguments Count: " .. (log.Arguments and #log.Arguments or 0) .. "\n"
	details = details .. "Arguments: " .. log.ArgumentString

	ScriptDetailsText:SetContent(details)

	local generatedScript = generateExampleScript(log)
	ScriptCodeText:SetContent("```lua\n" .. generatedScript .. "\n```")
end)

-- ==================== INITIALIZATION ====================
-- Hook semua remotes saat startup
task.wait(1)
hookRemotes(ReplicatedStorage)

-- Hook remotes yang baru dibuat
local function monitorNewRemotes(parent)
	parent.ChildAdded:Connect(function(child)
		if child:IsA("RemoteEvent") or child:IsA("RemoteFunction") then
			hookRemotes(parent)
		end
	end)
end

monitorNewRemotes(ReplicatedStorage)

if game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui") then
	monitorNewRemotes(game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui"))
end

WindUI:Notify({
	Title = "Remote Spy Active",
	Content = "Monitoring remote events/functions",
})
