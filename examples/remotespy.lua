--[[
    Remote Event Spy & Real-Time Executor
    Dibuat menggunakan WindUI Library
]]

local cloneref = (cloneref or clonereference or function(instance) return instance end)
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local RunService = cloneref(game:GetService("RunService"))

-- Inisialisasi WindUI (Sama persis dengan file referensi)
local WindUI
do
    local ok, result = pcall(function() return require("./src/Init") end)
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

-- ==========================================
-- UI SETUP
-- ==========================================
local Window = WindUI:CreateWindow({
    Title = "Remote Spy & Executor",
    Author = "by AI Assistant",
    Icon = "solar:monitor-bold",
    Theme = "Dark",
    NewElements = true,
    Transparent = true,
    ToggleKey = Enum.KeyCode.RightShift,
    Acrylic = true,
})

-- Variabel untuk menyimpan state
local SpyEnabled = true
local LogLimit = 50
local Logs = {}
local CurrentScriptText = "print('Hello from Executor!')"

-- ==========================================
-- TAB 1: LIVE MONITOR (REMOTE SPY)
-- ==========================================
local SpyTab = Window:Tab({
    Title = "Live Monitor",
    Icon = "solar:monitor-bold",
})

SpyTab:Section({
    Title = "Remote Event Spy",
    Desc = "Memonitor pemanggilan FireServer dan InvokeServer secara real-time.",
})

local MonitorBox = SpyTab:Textbox({
    Title = "Live Log Output",
    Default = "Menunggu aktivitas remote...\n",
    MultiLine = true,
    ReadOnly = true,
    ResetOnFocus = false,
})

SpyTab:Space({ Columns = 1 })

SpyTab:Toggle({
    Title = "Aktifkan Spy",
    Desc = "Mulai atau hentikan monitoring remote event.",
    Value = SpyEnabled,
    Callback = function(v)
        SpyEnabled = v
        WindUI:Notify({
            Title = "Spy Status",
            Content = v and "Monitoring Dihidupkan" or "Monitoring Dimatikan",
        })
    end,
})

SpyTab:Button({
    Title = "Bersihkan Log",
    Icon = "solar:trash-bin-trash-bold",
    Callback = function()
        Logs = {}
        MonitorBox:SetText("Log dibersihkan.\nMenunggu aktivitas remote...\n")
    end,
})

-- ==========================================
-- TAB 2: SCRIPT EXECUTOR
-- ==========================================
local ExecTab = Window:Tab({
    Title = "Executor",
    Icon = "solar:code-bold",
})

ExecTab:Section({
    Title = "Real-Time Script Executor",
    Desc = "Tulis atau generate script, lalu eksekusi secara langsung.",
})

local ScriptBox = ExecTab:Textbox({
    Title = "Script Input (Lua)",
    Default = CurrentScriptText,
    MultiLine = true,
    Callback = function(text)
        CurrentScriptText = text
    end,
})

ExecTab:Space({ Columns = 1 })

ExecTab:Button({
    Title = "Execute Script",
    Icon = "solar:play-bold",
    Callback = function()
        if not CurrentScriptText or CurrentScriptText == "" then
            WindUI:Notify({ Title = "Error", Content = "Script tidak boleh kosong!" })
            return
        end
        
        local func, err = loadstring(CurrentScriptText)
        if func then
            local success, execErr = pcall(func)
            if success then
                WindUI:Notify({ Title = "Success", Content = "Script berhasil dieksekusi!" })
            else
                WindUI:Notify({ Title = "Runtime Error", Content = tostring(execErr) })
            end
        else
            WindUI:Notify({ Title = "Syntax Error", Content = tostring(err) })
        end
    end,
})

ExecTab:Space({ Columns = 0.5 })

ExecTab:Section({
    Title = "Generate Example Code",
    Desc = "Pilih contoh script untuk dimasukkan ke editor.",
})

local ExampleScripts = {
    ["Print All Remotes"] = "for _, obj in pairs(game:GetDescendants()) do\n    if obj:IsA('RemoteEvent') or obj:IsA('RemoteFunction') then\n        print('Found:', obj:GetFullName())\n    end\nend",
    ["Fire Remote Example"] = "local remote = game:GetService('ReplicatedStorage'):FindFirstChild('RemoteEvent')\nif remote then\n    remote:FireServer('Test Payload')\n    print('Remote Fired!')\nelse\n    warn('Remote not found!')\nend",
    ["Hook Remote Example"] = "local remote = game:GetService('ReplicatedStorage'):FindFirstChild('RemoteEvent')\nif remote then\n    local oldFire\n    oldFire = hookfunction(remote.FireServer, function(self, ...)\n        print('Intercepted FireServer:', ...)\n        return oldFire(self, ...)\n    end)\nend",
}

local ExampleNames = {}
for name, _ in pairs(ExampleScripts) do
    table.insert(ExampleNames, name)
end

ExecTab:Dropdown({
    Title = "Pilih Contoh Script",
    Values = ExampleNames,
    Callback = function(selectedName)
        if ExampleScripts[selectedName] then
            CurrentScriptText = ExampleScripts[selectedName]
            ScriptBox:SetText(CurrentScriptText)
            WindUI:Notify({ Title = "Generated", Content = "Contoh script '" .. selectedName .. "' dimuat." })
        end
    end,
})

-- ==========================================
-- TAB 3: SETTINGS
-- ==========================================
local SettingsTab = Window:Tab({
    Title = "Settings",
    Icon = "solar:settings-bold",
})

SettingsTab:Section({
    Title = "Pengaturan Spy",
    Desc = "Konfigurasi batas dan format log.",
})

SettingsTab:Slider({
    Title = "Batas Log Maksimal",
    Step = 10,
    Value = { Min = 10, Max = 200, Default = 50 },
    Callback = function(value)
        LogLimit = value
    end,
})

-- ==========================================
-- REMOTE SPY LOGIC (HOOKMETAMETHOD)
-- ==========================================
local function AddToLog(message)
    table.insert(Logs, 1, message)
    if #Logs > LogLimit then
        table.remove(Logs)
    end
    
    local displayText = table.concat(Logs, "\n")
    -- Update UI Textbox
    if MonitorBox and MonitorBox.SetText then
        MonitorBox:SetText(displayText)
    elseif MonitorBox and MonitorBox.SetValue then
        MonitorBox.SetValue(displayText)
    end
end

-- Cek apakah environment exploit mendukung hookmetamethod
if hookmetamethod and getnamecallmethod then
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        
        if SpyEnabled and (method == "FireServer" or method == "InvokeServer") then
            local args = {...}
            local argStr = ""
            
            -- Format arguments menjadi string
            for i, v in ipairs(args) do
                local valStr = typeof(v) == "table" and "{...}" or tostring(v)
                argStr = argStr .. valStr .. (i < #args and ", " or "")
            end
            
            local logMsg = string.format("[%s] %s:%s(%s)", os.date("%H:%M:%S"), self:GetFullName(), method, argStr)
            AddToLog(logMsg)
        end
        
        return oldNamecall(self, ...)
    end)
else
    -- Fallback jika dijalankan di environment tanpa exploit (misal: Roblox Studio)
    warn("[Remote Spy] hookmetamethod tidak tersedia. Spy dinonaktifkan.")
    AddToLog("[System] hookmetamethod tidak terdeteksi. Pastikan Anda menggunakan executor yang mendukung.")
end

-- Notifikasi awal
WindUI:Notify({
    Title = "System Ready",
    Content = "Remote Spy & Executor berhasil dimuat!",
})
