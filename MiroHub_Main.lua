--[[
    MIRO HUB ARTIC  -  Antarctica Expedition (Roblox)
    GUI: Rayfield Gen2 resmi (SiriusSoftwareLtd)  ->  https://docs.sirius.menu/rayfield-gen2
    Loader stabil : loadstring(game:HttpGet("https://sirius.menu/gen2"))()

    Logika fitur Hub + Route Recorder/Replay (v3.1) dipertahankan; yang diganti hanya lapisan GUI.

    STRUKTUR FILE
      1. Library Initialization
      2. Window Configuration
      3. Theme Configuration
      4. Tab Creation
      5. Feature Functions        (Hub + modul Route; logika asli)
      6. GUI Components           (elemen Rayfield per tab)
      7. Callback Connections     (callback -> fungsi asli, ada di dalam elemen)
      8. Notification System
      9. Configuration Saving
     10. Initialization
]]

--==================================================================================================
-- 1. LIBRARY INITIALIZATION
--==================================================================================================
local Players         = game:GetService("Players")
local RunService      = game:GetService("RunService")
local UIS             = game:GetService("UserInputService")
local Lighting        = game:GetService("Lighting")
local HttpService     = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local VirtualUser     = game:GetService("VirtualUser")
local GuiService      = game:GetService("GuiService")
local PPS             = game:GetService("ProximityPromptService")
local StarterGui      = game:GetService("StarterGui")
local CoreGui         = game:GetService("CoreGui")

local LP  = Players.LocalPlayer
local env = (getgenv and getgenv()) or _G

-- bersihkan instance lama (Hub lama maupun Route Recorder standalone)
if env.AntarcticaHubLoaded and env.AntarcticaHubUnload then pcall(env.AntarcticaHubUnload) end
if env.__RouteReplayCleanup then pcall(env.__RouteReplayCleanup) end

local alive = true
local conns = {}

local function bind(signal, fn)
    local c = signal:Connect(fn)
    conns[#conns + 1] = c
    return c
end

-- notifikasi bawaan Roblox (dipakai sampai window Rayfield siap, dan sebagai cadangan)
local function notify(text)
    pcall(function()
        StarterGui:SetCore("SendNotification", { Title = "MIRO HUB ARTIC", Text = tostring(text), Duration = 3 })
    end)
end

local function has(str, list)
    str = str:lower()
    for _, k in ipairs(list) do
        if str:find(k, 1, true) then return true end
    end
    return false
end

local function hum()
    local c = LP.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function hrp()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

-- humanoid + root + karakter, hanya bila karakter hidup
local function getChar()
    local ch = LP.Character
    if not ch then return end
    local h = ch:FindFirstChildOfClass("Humanoid")
    local r = ch:FindFirstChild("HumanoidRootPart")
    if h and r and h.Health > 0 then return h, r, ch end
end

local function getGuiParent()
    if gethui then
        local ok, h = pcall(gethui)
        if ok and h then return h end
    end
    local ok, cg = pcall(function() return CoreGui end)
    if ok and cg then
        local f = Instance.new("Folder")
        local ok2 = pcall(function() f.Parent = cg end)
        f:Destroy()
        if ok2 then return cg end
    end
    return LP:WaitForChild("PlayerGui")
end
local GUI_PARENT = getGuiParent()     -- dipakai ESP (Highlight / Billboard)

local function new(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props or {}) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end

-- warna status (dipakai modul Route untuk menandai jenis pesan; bukan bagian tema Rayfield)
local C = {
    ok = Color3.fromRGB(46, 160, 110), warn = Color3.fromRGB(214, 150, 40),
    bad = Color3.fromRGB(214, 72, 80), text = Color3.fromRGB(232, 238, 252),
    accent = Color3.fromRGB(41, 121, 255), dim = Color3.fromRGB(139, 154, 192),
}

-- modul Route dibuat belakangan; Hub hanya perlu tahu apakah replay sedang berjalan
local Route

-- handle elemen GUI yang perlu disinkronkan dari fungsi fitur (diisi di bagian 6)
local GUIH = {}

-- Rayfield Gen2 resmi (stable)
local okLib, Rayfield = pcall(function()
    return loadstring(game:HttpGet("https://sirius.menu/gen2"))()
end)
if not okLib or type(Rayfield) ~= "table" then
    warn("[MIRO HUB] Gagal memuat Rayfield Gen2: " .. tostring(Rayfield))
    notify("Gagal memuat Rayfield Gen2 (cek koneksi / executor HttpGet)")
    return
end

--==================================================================================================
-- 2. WINDOW CONFIGURATION   (edit di sini)
--==================================================================================================
local Config = {
    Name      = "MIRO HUB ARTIC",
    Subtitle  = "Antarctica Expedition  |  v3.1",
    ToggleKey = Enum.KeyCode.RightControl,     -- tampil / sembunyi (bisa diubah di tab Tampilan)

    Save = {                                   -- lihat bagian 9
        autoSave = true, autoLoad = true,
        fileName = "AntarcticaHub", customFolder = "AntarcticaHub",
    },

    -- Rayfield Gen2 tidak punya set ikon berdasarkan nama: ikon = asset id angka.
    -- Id di bawah adalah ikon bawaan Gen2 (dari dokumentasi). Ganti dengan asset id ikon Anda sendiri.
    Icons = {
        Window = 80387863064905,   -- Rayfield
        Generic = 93364949241311,  -- contoh id dari dokumentasi
        Check = 125626312718314, Search = 100604009889706, Settings = 129180860773723, Configs = 125823673784681,
    },
}
local IC = Config.Icons
local TabIcons = {
    Main = IC.Generic, Boost = IC.Check, Teleport = IC.Search, Auto = IC.Configs, ESP = IC.Search,
    Proteksi = IC.Check, Misc = IC.Settings, Replay = IC.Generic, Rekam = IC.Configs,
    ["Opsi Rute"] = IC.Settings, Tampilan = IC.Settings,
}

--==================================================================================================
-- 3. THEME CONFIGURATION   (Cobalt Blue)
--    Tema bawaan Gen2: "default" "cobalt" "ember" "amethyst" "frost" "rose".
--    Set UseCustomTheme = true untuk memakai tabel CustomTheme (hanya key yang diisi yang berubah).
--==================================================================================================
local Theme = {
    Name = "cobalt",
    UseCustomTheme = false,
    CustomTheme = {
        AccentColor = Color3.fromRGB(41, 121, 255),
        AccentStroke = Color3.fromRGB(0, 71, 171),
        SliderProgress = ColorSequence.new(Color3.fromRGB(0, 71, 171), Color3.fromRGB(41, 121, 255)),
        TabBackground = ColorSequence.new(Color3.fromRGB(24, 132, 246), Color3.fromRGB(12, 108, 230)),
        TabStroke = ColorSequence.new(Color3.fromRGB(96, 176, 255), Color3.fromRGB(40, 132, 246)),
    },
}

-- deteksi ScreenGui milik Rayfield (agar perekam klik GUI tidak ikut merekam klik pada menu ini)
local ownGuis = {}
local function snapshotGuis()
    local set = {}
    for _, root in ipairs({ GUI_PARENT, LP:FindFirstChild("PlayerGui"), CoreGui }) do
        if root then
            pcall(function()
                for _, c in ipairs(root:GetChildren()) do set[c] = true end
            end)
        end
    end
    return set
end

local function isOwnGui(o)
    if typeof(o) ~= "Instance" then return false end
    local sg = o:IsA("ScreenGui") and o or o:FindFirstAncestorWhichIsA("ScreenGui")
    if not sg then return false end
    if ownGuis[sg] then return true end
    return sg.Name:lower():find("rayfield", 1, true) ~= nil
end

local guisBefore = snapshotGuis()
local okWin, window = pcall(function()
    return Rayfield:CreateWindow({
        name = Config.Name,
        subtitle = Config.Subtitle,
        icon = IC.Window,
        sidebarLayout = true,
        theme = Theme.UseCustomTheme and Theme.CustomTheme or Theme.Name,
        showName = Config.Name,
        showIcon = IC.Window,
        configuration = Config.Save,
    })
end)
if not okWin or not window then
    warn("[MIRO HUB] CreateWindow gagal: " .. tostring(window))
    notify("Gagal membuat window Rayfield Gen2")
    return
end
for g in pairs(snapshotGuis()) do
    if not guisBefore[g] and g:IsA("ScreenGui") then ownGuis[g] = true end
end

--==================================================================================================
-- 4. TAB CREATION
--==================================================================================================
window:CreateSection({ name = "HUB" })
local pMain  = window:CreateTab({ name = "Main",     icon = TabIcons.Main })
local pBoost = window:CreateTab({ name = "Boost",    icon = TabIcons.Boost })
local pTP    = window:CreateTab({ name = "Teleport", icon = TabIcons.Teleport })
local pAuto  = window:CreateTab({ name = "Auto",     icon = TabIcons.Auto })
local pESP   = window:CreateTab({ name = "ESP",      icon = TabIcons.ESP })
local pProt  = window:CreateTab({ name = "Proteksi", icon = TabIcons.Proteksi })
local pMisc  = window:CreateTab({ name = "Misc",     icon = TabIcons.Misc })
window:CreateSection({ name = "RUTE" })
local pRepl  = window:CreateTab({ name = "Replay",   icon = TabIcons.Replay })
local pRek   = window:CreateTab({ name = "Rekam",    icon = TabIcons.Rekam })
local pOpsi  = window:CreateTab({ name = "Opsi Rute", icon = TabIcons["Opsi Rute"] })
window:CreateSection({ name = "PENGATURAN" })
local pUI    = window:CreateTab({ name = "Tampilan", icon = TabIcons.Tampilan })

---------------------------------------------------------------- pembantu elemen (tipis, hanya membungkus API Gen2)
local GUI = {}

-- toggle terhubung ke tbl[key]; cb(value) opsional. noSave = true -> tidak disimpan ke konfigurasi
function GUI.toggle(tab, name, tbl, key, cb, flag, noSave, desc)
    return tab:CreateToggle({
        name = name, description = desc, flag = flag, forgetState = noSave and true or nil,
        value = tbl[key] and true or false,
        callback = function(v)
            tbl[key] = v and true or false
            if cb then cb(v) end
        end,
    })
end

-- input angka; cb(number) hanya dipanggil bila teks valid
function GUI.num(tab, name, default, cb, flag, desc)
    return tab:CreateInput({
        name = name, description = desc, flag = flag, numeric = true, value = tostring(default),
        callback = function(text)
            local n = tonumber(text)
            if n and cb then cb(n) end
        end,
    })
end

--==================================================================================================
-- 5. FEATURE FUNCTIONS
--==================================================================================================
------------------------------------------------------------------ 5a. MODUL HUB (logika asli)
local Cfg = {
    antiAFK = true,
    speedOn = false, speed = 32,
    jumpOn = false, jump = 90,
    infJump = false, noclip = false, fly = false, flySpeed = 60,
    clickTP = false, tpSpeed = 120, useTween = true,
    autoSummit = false, summitDelay = 1.5,
    espPlayers = false, espCP = false, fullbright = false,
    modKick = false, modRank = 200, modHop = false,
    antiPause = false,
}

---------------------------------------------------------------- teleport
local function tpTo(cf, instant)
    local r = hrp()
    if not r then return end
    if instant or not Cfg.useTween then
        r.CFrame = cf
        r.AssemblyLinearVelocity = Vector3.zero
        return
    end
    local dur = math.max((r.Position - cf.Position).Magnitude / Cfg.tpSpeed, 0.05)
    local t0, start = os.clock(), r.CFrame
    while true do
        local a = math.min((os.clock() - t0) / dur, 1)
        r = hrp()
        if not r then return end
        r.CFrame = start:Lerp(cf, a)
        r.AssemblyLinearVelocity = Vector3.zero
        if a >= 1 then break end
        RunService.Heartbeat:Wait()
    end
end

---------------------------------------------------------------- boost
local B = {
    speed  = { name = "Kecepatan",       on = false, secs = 180, value = 40,  kw = { "speed", "kecepatan", "sprint" } },
    jump   = { name = "Loncat",          on = false, secs = 180, value = 100, kw = { "jump", "loncat", "lompat" } },
    tight  = { name = "Tightrope",       on = false, secs = 180, kw = { "tightrope", "tight", "balance", "rope" } },
    fall   = { name = "Fall Resistance", on = false, secs = 180, kw = { "fall", "resist", "landing" } },
    aval   = { name = "Avalanche",       on = false, secs = 180, kw = { "avalanche", "longsor", "snowslide", "rockfall" } },
    invinc = { name = "Invincibility",   on = false, secs = 180, kw = { "invinc", "godmode", "immune", "shield" } },
}
local ORDER   = { "speed", "jump", "tight", "fall", "aval", "invinc" }
local TIME_KW = { "time", "timer", "duration", "remain", "left", "expire", "sisa", "countdown", "cooldown" }

local BS = { master = false, freeze = false, inf = false, sync = false, secs = 180 }

local active     = {}
local frozenLeft = {}
local refs       = {}
local lastPin    = 0

local function isOn(key)
    if not B[key].on then return false end
    if BS.master and BS.inf then return true end
    return (active[key] or 0) > os.clock()
end

local function addRef(key, kind, obj, attr, isBool, path)
    refs[#refs + 1] = { key = key, kind = kind, obj = obj, attr = attr, isBool = isBool, path = path }
end

local function scanBoostValues()
    table.clear(refs)
    local roots = { LP }
    if LP.Character then roots[#roots + 1] = LP.Character end
    local pg = LP:FindFirstChild("PlayerGui")
    if pg then roots[#roots + 1] = pg end

    for _, root in ipairs(roots) do
        local list = root:GetDescendants()
        list[#list + 1] = root
        for _, inst in ipairs(list) do
            for name, val in pairs(inst:GetAttributes()) do
                local full = inst.Name .. "." .. name
                for _, key in ipairs(ORDER) do
                    if has(full, B[key].kw) then
                        if type(val) == "boolean" then
                            addRef(key, "attr", inst, name, true, inst:GetFullName() .. "@" .. name)
                        elseif type(val) == "number" and has(full, TIME_KW) then
                            addRef(key, "attr", inst, name, false, inst:GetFullName() .. "@" .. name)
                        end
                    end
                end
            end
            if inst:IsA("NumberValue") or inst:IsA("IntValue") or inst:IsA("BoolValue") then
                local full = (inst.Parent and inst.Parent.Name or "") .. "." .. inst.Name
                for _, key in ipairs(ORDER) do
                    if has(full, B[key].kw) then
                        if inst:IsA("BoolValue") then
                            addRef(key, "val", inst, nil, true, inst:GetFullName())
                        elseif has(full, TIME_KW) then
                            addRef(key, "val", inst, nil, false, inst:GetFullName())
                        end
                    end
                end
            end
        end
    end
    for _, r in ipairs(refs) do
        print("[AntarcticaHub] boost ref (" .. r.key .. "): " .. r.path)
    end
    return #refs
end

local function pinKey(key)
    for _, r in ipairs(refs) do
        if r.key == key and r.obj and r.obj.Parent then
            local v = r.isBool and true or (BS.inf and 99999 or B[key].secs)
            pcall(function()
                if r.kind == "attr" then r.obj:SetAttribute(r.attr, v) else r.obj.Value = v end
            end)
        end
    end
end

local function setStates(h, enabled)
    pcall(function()
        h:SetStateEnabled(Enum.HumanoidStateType.FallingDown, enabled)
        h:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, enabled)
    end)
end

local prev = {}
local avalParts, lastAval = {}, 0

bind(RunService.Heartbeat, function()
    local h, r = hum(), hrp()
    if not h or not r then return end

    local replaying = Route and Route.isPlaying()

    if not replaying then
        if isOn("speed") then
            h.WalkSpeed = B.speed.value
            prev.speed = true
        elseif Cfg.speedOn then
            h.WalkSpeed = Cfg.speed
            prev.speed = false
        elseif prev.speed then
            h.WalkSpeed = 16
            prev.speed = false
        end

        if isOn("jump") then
            h.UseJumpPower = true
            h.JumpPower = B.jump.value
            prev.jump = true
        elseif Cfg.jumpOn then
            h.UseJumpPower = true
            h.JumpPower = Cfg.jump
            prev.jump = false
        elseif prev.jump then
            h.JumpPower = 50
            prev.jump = false
        end
    end

    local fall, aval = isOn("fall"), isOn("aval")
    if fall or aval then
        if not prev.states then setStates(h, false) prev.states = true end
    elseif prev.states then
        setStates(h, true)
        prev.states = false
    end
    if fall then
        local v = r.AssemblyLinearVelocity
        if v.Y < -55 then r.AssemblyLinearVelocity = Vector3.new(v.X, -55, v.Z) end
    end

    if isOn("tight") and not Cfg.fly then
        local look = r.CFrame.LookVector
        local flat = Vector3.new(look.X, 0, look.Z)
        if flat.Magnitude > 0.01 then
            r.CFrame = CFrame.lookAt(r.Position, r.Position + flat)
            r.AssemblyAngularVelocity = Vector3.zero
        end
    end

    if aval and os.clock() - lastAval > 10 then
        lastAval = os.clock()
        table.clear(avalParts)
        for _, o in ipairs(workspace:GetDescendants()) do
            if o:IsA("BasePart") and has(o.Name, B.aval.kw) then avalParts[#avalParts + 1] = o end
        end
    end
    if aval then
        for _, p in ipairs(avalParts) do
            if p.Parent then pcall(function() p.CanTouch = false end) end
        end
    end

    if isOn("invinc") then
        if h.Health > 0 and h.Health < h.MaxHealth then h.Health = h.MaxHealth end
        if not prev.inv then
            pcall(function() h:SetStateEnabled(Enum.HumanoidStateType.Dead, false) end)
            prev.inv = true
        end
    elseif prev.inv then
        pcall(function() h:SetStateEnabled(Enum.HumanoidStateType.Dead, true) end)
        prev.inv = false
    end

    if BS.freeze then
        local now = os.clock()
        for key, left in pairs(frozenLeft) do
            if B[key].on then active[key] = now + left end
        end
    end
    if (BS.freeze or BS.inf) and os.clock() - lastPin > 0.25 then
        lastPin = os.clock()
        for _, key in ipairs(ORDER) do
            if isOn(key) then pinKey(key) end
        end
    end
end)

local function activateSelected()
    local n, now = 0, os.clock()
    for _, key in ipairs(ORDER) do
        if B[key].on then
            active[key] = now + B[key].secs
            if BS.freeze then frozenLeft[key] = B[key].secs end
            pinKey(key)
            n += 1
        end
    end
    return n
end

local function stopBoosts()
    table.clear(active)
    table.clear(frozenLeft)
end

local GAME_TXT = {
    speed = { "kecepatan" }, jump = { "loncat", "lompat" }, tight = { "tightrope" },
    fall = { "fall resistance" }, aval = { "avalanche" }, invinc = { "invincibility" },
    freeze = { "freeze all selected boosts" }, inf = { "inf boosts" },
}

local function gameTap(texts)
    if not BS.sync or not texts then return end
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg or not (firesignal or getconnections) then return end
    local want = {}
    for _, t in ipairs(texts) do want[t] = true end
    for _, d in ipairs(pg:GetDescendants()) do
        if (d:IsA("TextLabel") or d:IsA("TextButton")) and not isOwnGui(d) then
            local t = d.Text:lower():gsub("^%s+", ""):gsub("%s+$", "")
            if want[t] then
                local btn
                if d:IsA("GuiButton") then
                    btn = d
                elseif d.Parent and d.Parent:IsA("GuiButton") then
                    btn = d.Parent
                elseif d.Parent then
                    for _, c in ipairs(d.Parent:GetChildren()) do
                        if c:IsA("GuiButton") then btn = c break end
                    end
                end
                if btn then
                    for _, sig in ipairs({ "MouseButton1Down", "MouseButton1Click", "Activated", "MouseButton1Up" }) do
                        local ok, s = pcall(function() return btn[sig] end)
                        if ok and s then
                            if firesignal then
                                pcall(firesignal, s)
                            else
                                pcall(function()
                                    for _, c in ipairs(getconnections(s)) do pcall(function() c:Fire() end) end
                                end)
                            end
                        end
                    end
                    print("[AntarcticaHub] klik UI game: " .. btn:GetFullName())
                    return
                end
            end
        end
    end
end

---------------------------------------------------------------- gerak (infinite jump, noclip, fly, click TP)
bind(UIS.JumpRequest, function()
    if Cfg.infJump then
        local h = hum()
        if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

bind(RunService.Stepped, function()
    local ch = LP.Character
    if Cfg.noclip and ch then
        for _, p in ipairs(ch:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end
end)

local flyBV, flyBG
local function setFly(on)
    Cfg.fly = on
    if flyBV then flyBV:Destroy() flyBV = nil end
    if flyBG then flyBG:Destroy() flyBG = nil end
    local r, h = hrp(), hum()
    if on and r and h then
        flyBV = new("BodyVelocity", { MaxForce = Vector3.new(1e9, 1e9, 1e9), Velocity = Vector3.zero }, r)
        flyBG = new("BodyGyro", { MaxTorque = Vector3.new(1e9, 1e9, 1e9), P = 9e4, CFrame = r.CFrame }, r)
        h.PlatformStand = true
    elseif h then
        h.PlatformStand = false
    end
end

bind(RunService.RenderStepped, function()
    if not Cfg.fly or not flyBV or not hrp() then return end
    local cf = workspace.CurrentCamera.CFrame
    local d = Vector3.zero
    if UIS:IsKeyDown(Enum.KeyCode.W) then d += cf.LookVector end
    if UIS:IsKeyDown(Enum.KeyCode.S) then d -= cf.LookVector end
    if UIS:IsKeyDown(Enum.KeyCode.A) then d -= cf.RightVector end
    if UIS:IsKeyDown(Enum.KeyCode.D) then d += cf.RightVector end
    if UIS:IsKeyDown(Enum.KeyCode.Space) then d += Vector3.yAxis end
    if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then d -= Vector3.yAxis end
    flyBV.Velocity = d.Magnitude > 0 and d.Unit * Cfg.flySpeed or Vector3.zero
    flyBG.CFrame = cf
end)

bind(LP.CharacterAdded, function()
    Cfg.fly = false
    flyBV, flyBG = nil, nil
    if GUIH.fly then pcall(function() GUIH.fly:Set(false, true) end) end   -- samakan toggle GUI dengan status asli
    table.clear(prev)
    task.delay(3, function() if alive then scanBoostValues() end end)
end)

bind(UIS.InputBegan, function(i, gp)
    if gp or not Cfg.clickTP then return end
    if i.UserInputType == Enum.UserInputType.MouseButton1 and UIS:IsKeyDown(Enum.KeyCode.LeftControl) then
        local m = LP:GetMouse()
        if m.Hit then tpTo(CFrame.new(m.Hit.Position + Vector3.new(0, 4, 0)), true) end
    end
end)

bind(LP.Idled, function()
    if Cfg.antiAFK then
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.zero)
    end
end)

---------------------------------------------------------------- checkpoint & auto summit
local CP_KEYWORDS = { "checkpoint", "camp", "summit", "finish", "puncak", "base", "cp" }
local savedSlots = {}
local scanned = {}

local function scanCheckpoints()
    table.clear(scanned)
    local seen = {}
    local ch = LP.Character
    for _, o in ipairs(workspace:GetDescendants()) do
        if o:IsA("BasePart") and not (ch and o:IsDescendantOf(ch)) then
            local n = o.Name:lower()
            for _, k in ipairs(CP_KEYWORDS) do
                if n:find(k, 1, true) then
                    local p = o.Position
                    local key = math.floor(p.X) .. "," .. math.floor(p.Y) .. "," .. math.floor(p.Z)
                    if not seen[key] then
                        seen[key] = true
                        scanned[#scanned + 1] = { name = o.Name, part = o }
                    end
                    break
                end
            end
        end
    end
    table.sort(scanned, function(a, b) return a.part.Position.Y < b.part.Position.Y end)
    return #scanned
end

local summitThread
local function runAutoSummit()
    if summitThread then return end
    summitThread = task.spawn(function()
        if #scanned == 0 then scanCheckpoints() end
        for _, w in ipairs(scanned) do
            if not Cfg.autoSummit or not alive then break end
            if w.part and w.part.Parent then
                tpTo(w.part.CFrame + Vector3.new(0, 5, 0))
                task.wait(Cfg.summitDelay)
            end
        end
        Cfg.autoSummit = false
        summitThread = nil
        if GUIH.summit then pcall(function() GUIH.summit:Set(false, true) end) end
        notify("Auto Summit selesai/berhenti")
    end)
end

---------------------------------------------------------------- ESP
local espObjs = {}

local function clearESP(tag)
    for k, v in pairs(espObjs) do
        if v.tag == tag then
            for _, o in ipairs(v.objs) do pcall(function() o:Destroy() end) end
            espObjs[k] = nil
        end
    end
end

local function addESP(target, text, color, tag)
    if espObjs[target] then return end
    local hl = new("Highlight", {
        FillColor = color, OutlineColor = color, FillTransparency = 0.6, Adornee = target,
    }, GUI_PARENT)
    local bb = new("BillboardGui", {
        Size = UDim2.fromOffset(120, 20), AlwaysOnTop = true, StudsOffset = Vector3.new(0, 3, 0),
        Adornee = target:IsA("Model") and (target:FindFirstChild("Head") or target.PrimaryPart) or target,
    }, GUI_PARENT)
    new("TextLabel", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, TextColor3 = color, TextStrokeTransparency = 0,
        TextScaled = true, Text = text, Font = Enum.Font.GothamBold,
    }, bb)
    espObjs[target] = { tag = tag, objs = { hl, bb } }
end

local function refreshESP()
    clearESP("players")
    clearESP("cp")
    if Cfg.espPlayers then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP and p.Character then
                addESP(p.Character, p.DisplayName, Color3.fromRGB(255, 80, 80), "players")
            end
        end
    end
    if Cfg.espCP then
        scanCheckpoints()
        for _, w in ipairs(scanned) do
            addESP(w.part, w.name, Color3.fromRGB(80, 200, 255), "cp")
        end
    end
end

---------------------------------------------------------------- proteksi
local modNames = {}
local ROLE_KW = { "mod", "admin", "staff", "owner", "dev", "founder", "helper", "support" }

local function serverHop()
    local ok, res = pcall(function()
        return HttpService:JSONDecode(game:HttpGet(
            "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
    end)
    if ok and res and res.data then
        for _, s in ipairs(res.data) do
            if s.id ~= game.JobId and s.playing < s.maxPlayers then
                return TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LP)
            end
        end
    end
    notify("Server lain tidak ditemukan")
end

local function isModerator(p)
    if p == LP then return false end
    if modNames[p.Name:lower()] or modNames[p.DisplayName:lower()] then return true end
    if game.CreatorType == Enum.CreatorType.Group then
        local ok, rank = pcall(function() return p:GetRankInGroup(game.CreatorId) end)
        if ok and rank >= Cfg.modRank then return true end
        local ok2, role = pcall(function() return p:GetRoleInGroup(game.CreatorId) end)
        if ok2 and has(role, ROLE_KW) then return true end
    elseif p.UserId == game.CreatorId then
        return true
    end
    return false
end

local function checkPlayer(p)
    if not Cfg.modKick or not alive then return end
    task.spawn(function()
        if isModerator(p) then
            if Cfg.modHop then
                notify("Moderator " .. p.Name .. " masuk, pindah server")
                serverHop()
            else
                LP:Kick("Moderator terdeteksi: " .. p.Name)
            end
        end
    end)
end

bind(Players.PlayerAdded, function(p)
    checkPlayer(p)
    p.CharacterAdded:Connect(function()
        task.wait(1)
        if Cfg.espPlayers then refreshESP() end
    end)
end)

local function antiPauseTick()
    pcall(function() workspace.GameplayPaused = false end)
    pcall(function() if sethiddenproperty then sethiddenproperty(workspace, "GameplayPaused", false) end end)
    local r = hrp()
    if r then pcall(function() LP.ReplicationFocus = r end) end
    local pg = LP:FindFirstChild("PlayerGui")
    if pg then
        for _, g in ipairs(pg:GetDescendants()) do
            if g.Name:lower():find("pause", 1, true) and not isOwnGui(g) then
                pcall(function()
                    if g:IsA("ScreenGui") then g.Enabled = false
                    elseif g:IsA("GuiObject") then g.Visible = false end
                end)
            end
        end
    end
end

pcall(function()
    bind(workspace:GetPropertyChangedSignal("GameplayPaused"), function()
        if Cfg.antiPause then antiPauseTick() end
    end)
end)

task.spawn(function()
    while alive do
        if Cfg.antiPause then antiPauseTick() end
        task.wait(0.5)
    end
end)

---------------------------------------------------------------- misc
local function setFullbright(on)
    if on then
        Lighting.Brightness, Lighting.ClockTime = 3, 14
        Lighting.FogEnd, Lighting.GlobalShadows = 1e9, false
        Lighting.Ambient = Color3.new(1, 1, 1)
    else
        Lighting.Brightness, Lighting.GlobalShadows = 2, true
        Lighting.Ambient = Color3.fromRGB(70, 70, 70)
    end
end

local function fpsBoost()
    for _, o in ipairs(workspace:GetDescendants()) do
        if o:IsA("ParticleEmitter") or o:IsA("Trail") or o:IsA("Smoke") or o:IsA("Fire") then
            o.Enabled = false
        elseif o:IsA("BasePart") then
            o.Material = Enum.Material.SmoothPlastic
        end
    end
    pcall(function() settings().Rendering.QualityLevel = 1 end)
    notify("FPS boost aktif")
end

------------------------------------------------------------------ 5b. MODUL ROUTE  (Route Recorder + Replay v3.1)
--    Logika perekam/pemutar tidak diubah. Yang berubah hanya GUI-nya (elemen Rayfield Gen2).
--    ctx = { pages = { replay, rekam, opsi } (Tab Rayfield), isOwnGui = fn, GUI = pembantu elemen }
--==================================================================================================
local function createRoute(ctx)
    local isOwnGui, GUI = ctx.isOwnGui, ctx.GUI

    local VIM
    pcall(function() VIM = game:GetService("VirtualInputManager") end)
    if VIM and not pcall(function() return VIM.SendKeyEvent end) then VIM = nil end

    local rconns = {}
    local function track(c) rconns[#rconns + 1] = c return c end

    ------------------------------------------------------------ state
    local S = {
        loaded = false, n = 0, fileName = "",
        t = {}, px = {}, py = {}, pz = {}, vx = {}, vy = {}, vz = {}, mx = {}, my = {}, mz = {},
        jmp = {}, tool = {}, st = {}, stNames = {}, swimIdx = 0, seatIdx = 0, js = {}, jg = {}, jp = 1,
        cx = {}, cy = {}, cz = {}, ox = {}, oy = {}, oz = {}, mpx = {}, mpy = {},
        ws = {}, jpv = {}, jpm = {}, sy = {}, thr = {}, sv = {},
        ev_t = {}, ev_k = {}, ev_d = {}, ep = 1, heldRec = {},
        act = {}, ap = 1, def = {}, promptHit = setmetatable({}, { __mode = "k" }), missed = 0,
        hasCam = false, hasInput = false, useInput = false, prevSpace = false, al = 0,
        toolNames = {}, hip0 = 2,

        playing = false, paused = false, loading = false,
        T = 0, idx = 1, lastTool = -1, holdUntil = 0,
        lastErr = 0, errSince = 0,
        waitingRespawn = false, loops = 0, gateRel = 0, vehHold = 0,

        inputMode = true, useCamera = true, useMouse = false, useTool = true,
        autoResume = true, verify = true, loop = false, showRoute = false,
        correction = true, steer = true, syncTime = true, jumpGate = true, softLock = true, matchSpeed = true,

        snapDist = 12, jumpTol = 0.6, jumpTimeout = 1.5, holdT = 0,
        pendingJump = false, pendingUntil = 0, jumpHoldUntil = 0, prevJmp = false,
        stuckSec = 3, speed = 1, loopDelay = 3, loopMax = 0, settle = 1.5, startMax = 120,
        pull = 10, vehSnap = 15,
    }

    local R = {
        active = false, paused = false, n = 0, T = 0, interval = 0, hip = 2, dist = 0,
        t = {}, px = {}, py = {}, pz = {}, vx = {}, vy = {}, vz = {}, mx = {}, my = {}, mz = {},
        cx = {}, cy = {}, cz = {}, ox = {}, oy = {}, oz = {}, mpx = {}, mpy = {},
        ev_t = {}, ev_k = {}, ev_d = {}, evn = 0,
        rx = {}, ry = {}, rz = {}, jmp = {}, ws = {}, st = {}, tool = {}, jpv = {}, jpm = {}, sy = {},
        thr = {}, sv = {},
        toolNames = {}, toolIdx = {}, toolJson = {}, stNames = {}, stIdx = {},
        acts = {}, actRem = {}, noisy = {}, rate = {}, guiHeld = {},
        holdUntil = 0, jumpSeen = false, saving = false, saved = true, discardWarn = false,
    }

    local W, NB = {}, {}            -- W = handle elemen Rayfield, NB = handle input angka
    local U = {}
    local A = { alive = true, guiHold = 0, guiPos = {}, lastSeat = nil }
    local lblStatus, lastStatus

    ------------------------------------------------------------ util dasar
    local function fmt(sec)
        sec = math.max(0, math.floor(sec))
        return string.format("%d:%02d:%02d", sec // 3600, (sec % 3600) // 60, sec % 60)
    end

    local function num(v, d)
        if type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge then return v end
        return d
    end

    -- status: teks pada elemen Text Rayfield; jenis pesan ditandai prefiks (Text tidak punya warna)
    local function status(msg, color)
        if not lblStatus then return end
        local tag = (color == C.bad and "[X] ") or (color == C.warn and "[!] ") or (color == C.ok and "[OK] ") or ""
        local txt = tag .. tostring(msg)
        if txt ~= lastStatus then
            lastStatus = txt
            pcall(function() lblStatus:Set(txt) end)
        end
    end

    -- nilai teks elemen Input (string); "" bila elemen belum dibuat
    local function nbv(key)
        local h = NB[key]
        return h and tostring(h.value) or ""
    end

    -- sinkron toggle GUI dengan status internal (tanpa memicu callback)
    local function setPauseUI(on)     if W.pauseT    then pcall(function() W.pauseT:Set(on, true) end) end end
    local function setRecUI(on)       if W.recT      then pcall(function() W.recT:Set(on, true) end) end end
    local function setRecPauseUI(on)  if W.recPauseT then pcall(function() W.recPauseT:Set(on, true) end) end end

    local function teleport(root, x, y, z, yaw)
        local rot = yaw and CFrame.Angles(0, yaw, 0) or root.CFrame.Rotation
        root.CFrame = CFrame.new(x, y, z) * rot
        root.AssemblyLinearVelocity = Vector3.zero
        root.AssemblyAngularVelocity = Vector3.zero
    end

    local BLOCK = {
        Escape = true, Slash = true, Tab = true, Backquote = true, Return = true, KeypadEnter = true,
        F9 = true, F10 = true, F11 = true, F12 = true, Unknown = true,
    }

    local VKMAP = {
        Space = 0x20, LeftShift = 0xA0, RightShift = 0xA1, LeftControl = 0xA2, RightControl = 0xA3,
        LeftAlt = 0xA4, RightAlt = 0xA5, Left = 0x25, Up = 0x26, Right = 0x27, Down = 0x28,
        Zero = 0x30, One = 0x31, Two = 0x32, Three = 0x33, Four = 0x34,
        Five = 0x35, Six = 0x36, Seven = 0x37, Eight = 0x38, Nine = 0x39,
    }
    local function vkOf(name)
        if VKMAP[name] then return VKMAP[name] end
        if #name == 1 then
            local b = name:byte()
            if b >= 65 and b <= 90 then return b end
        end
    end

    local keyDown, mouseDown = {}, {}
    local lastMousePx = { 0, 0 }

    local function sendKey(name, down)
        if (keyDown[name] or false) == down then return end
        local ok, kc = pcall(function() return Enum.KeyCode[name] end)
        if not ok or not kc then return end
        keyDown[name] = down or nil
        if VIM then
            pcall(function() VIM:SendKeyEvent(down, kc, false, game) end)
        elseif keypress and keyrelease then
            local vk = vkOf(name)
            if vk then pcall(down and keypress or keyrelease, vk) end
        end
    end

    local function sendMouseBtn(name, down, px, py)
        if not VIM then return end
        if (mouseDown[name] or false) == down then return end
        mouseDown[name] = down or nil
        lastMousePx = { px, py }
        local idx = (name == "MouseButton1" and 0) or (name == "MouseButton2" and 1) or 2
        pcall(function() VIM:SendMouseButtonEvent(px, py, idx, down, game, 0) end)
    end

    local function releaseAllKeys()
        local ks = {}
        for k in pairs(keyDown) do ks[#ks + 1] = k end
        for _, k in ipairs(ks) do sendKey(k, false) end
        local ms = {}
        for k in pairs(mouseDown) do ms[#ms + 1] = k end
        for _, k in ipairs(ms) do sendMouseBtn(k, false, lastMousePx[1], lastMousePx[2]) end
    end

    local function mousePx(a)
        local cam = workspace.CurrentCamera
        local vs = cam and cam.ViewportSize or Vector2.new(1, 1)
        return (S.mpx[a] or 0.5) * vs.X, (S.mpy[a] or 0.5) * vs.Y
    end

    local function adler32(s, onProgress)
        local a, b = 1, 0
        local len, CH, byte = #s, 2048, string.byte
        local pos, n = 1, 0
        while pos <= len do
            local e = math.min(pos + CH - 1, len)
            local t = { byte(s, pos, e) }
            for i = 1, #t do
                a += t[i]
                b += a
            end
            a %= 65521
            b %= 65521
            pos = e + 1
            n += 1
            if n % 120 == 0 then
                if onProgress then onProgress(pos / len) end
                task.wait()
            end
        end
        return b * 65536 + a
    end

    ------------------------------------------------------------ marker rute 3D
    local REC_COLOR = Color3.fromRGB(80, 200, 255)
    local MARK = {
        start = Color3.fromRGB(60, 220, 100), finish = Color3.fromRGB(230, 60, 60),
        jump = Color3.fromRGB(255, 220, 60), gui = Color3.fromRGB(230, 90, 230),
        prompt = Color3.fromRGB(255, 150, 40), seat = Color3.fromRGB(150, 110, 255),
        remote = Color3.fromRGB(255, 255, 255),
    }

    local Viz = {
        folder = nil, gen = 0, count = 0, tol = 0.25, yOff = -2.8, building = false,
        A = nil, buf = {}, cur = nil, pend = {}, tail = nil, ghost = nil,
    }

    function Viz.clear()
        Viz.gen += 1
        if Viz.folder then pcall(function() Viz.folder:Destroy() end) end
        Viz.folder, Viz.count, Viz.building = nil, 0, false
        Viz.A, Viz.buf, Viz.cur, Viz.pend, Viz.tail, Viz.ghost = nil, {}, nil, {}, nil, nil
    end

    local function vFolder()
        if Viz.folder and Viz.folder.Parent then return Viz.folder end
        Viz.folder = new("Folder", { Name = "RouteViz" }, workspace)
        return Viz.folder
    end

    local function vPart(size, cf, color, shape)
        local p = new("Part", {
            Anchored = true, CanCollide = false, CanTouch = false, CanQuery = false, CastShadow = false,
            Material = Enum.Material.Neon, Color = color, Transparency = 0.15, Size = size, CFrame = cf,
        })
        if shape then p.Shape = shape end
        p.Parent = vFolder()
        return p
    end

    local function lookCF(a, b)
        local d = b - a
        local m = d.Magnitude
        if m > 1e-6 and math.abs(d.Y) / m > 0.9999 then
            return CFrame.lookAt(a, b, Vector3.xAxis)
        end
        return CFrame.lookAt(a, b)
    end

    function Viz.seg(a, b, color)
        local len = (b - a).Magnitude
        if len < 0.02 then return end
        vPart(Vector3.new(0.3, 0.3, len), lookCF(a, b) * CFrame.new(0, 0, -len / 2), color)
        Viz.count += 1
        if Viz.count > 12000 then Viz.tol = math.max(Viz.tol, 0.8) end
    end

    function Viz.dot(pos, color, size)
        vPart(Vector3.new(size, size, size), CFrame.new(pos), color, Enum.PartType.Ball)
    end

    function Viz.mark(pos, kind)
        Viz.dot(pos, MARK[kind] or MARK.remote, kind == "jump" and 1.3 or 1.8)
    end

    local function ptSegDist(p, a, b)
        local ab = b - a
        local l2 = ab:Dot(ab)
        if l2 < 1e-9 then return (p - a).Magnitude end
        local tt = math.clamp((p - a):Dot(ab) / l2, 0, 1)
        return (p - (a + ab * tt)).Magnitude
    end

    function Viz.feed(p, color)
        if not Viz.A then
            Viz.A, Viz.buf, Viz.cur = p, {}, p
            return
        end
        local buf = Viz.buf
        buf[#buf + 1] = p
        Viz.cur = p
        local ok = (#buf < 80) and ((p - Viz.A).Magnitude < 60)
        if ok then
            for i = 1, #buf - 1 do
                if ptSegDist(buf[i], Viz.A, p) > Viz.tol then ok = false break end
            end
        end
        if not ok then
            if #buf >= 2 then
                local prevPt = buf[#buf - 1]
                Viz.seg(Viz.A, prevPt, color)
                Viz.A = prevPt
                Viz.buf = { p }
            else
                Viz.seg(Viz.A, p, color)
                Viz.A = p
                Viz.buf = {}
            end
        end
    end

    function Viz.flush(color)
        if Viz.A and Viz.cur and Viz.cur ~= Viz.A then
            Viz.seg(Viz.A, Viz.cur, color)
            Viz.A, Viz.buf = Viz.cur, {}
        end
    end

    function Viz.updateTail(p)
        local from = Viz.A
        if not from then return end
        local len = (p - from).Magnitude
        if len < 0.02 then
            if Viz.tail and Viz.tail.Parent then Viz.tail.Transparency = 1 end
            return
        end
        if not (Viz.tail and Viz.tail.Parent) then
            Viz.tail = vPart(Vector3.new(0.3, 0.3, len), CFrame.new(), REC_COLOR)
        end
        Viz.tail.Transparency = 0.15
        Viz.tail.Size = Vector3.new(0.3, 0.3, len)
        Viz.tail.CFrame = lookCF(from, p) * CFrame.new(0, 0, -len / 2)
    end

    function Viz.append(x, y, z)
        local p = Vector3.new(x, y + Viz.yOff, z)
        if Viz.building then
            if #Viz.pend < 40000 then Viz.pend[#Viz.pend + 1] = p end
            return
        end
        Viz.feed(p, REC_COLOR)
        Viz.updateTail(p)
    end

    function Viz.ghostAt(x, y, z)
        if not (Viz.ghost and Viz.ghost.Parent) then
            Viz.ghost = vPart(Vector3.new(2.2, 2.2, 2.2), CFrame.new(), Color3.new(1, 1, 1), Enum.PartType.Ball)
            Viz.ghost.Transparency = 0.4
        end
        Viz.ghost.CFrame = CFrame.new(x, y + Viz.yOff, z)
    end

    function Viz.build(px, py, pz, n, hip, uniform, jlist, acts)
        Viz.clear()
        local gen = Viz.gen
        Viz.building = true
        Viz.yOff = -((hip or 2) + 1.0) + 0.2
        local yo = Viz.yOff
        task.spawn(function()
            if n < 2 then Viz.building = false return end
            Viz.dot(Vector3.new(px[1], py[1] + yo, pz[1]), MARK.start, 3)
            local color = REC_COLOR
            for k = 1, n do
                color = uniform and REC_COLOR or Color3.fromHSV(0.33 * (1 - k / n), 1, 1)
                Viz.feed(Vector3.new(px[k], py[k] + yo, pz[k]), color)
                if k % 1500 == 0 then
                    task.wait()
                    if Viz.gen ~= gen then return end
                end
            end
            Viz.flush(color)
            if not uniform then
                Viz.dot(Vector3.new(px[n], py[n] + yo, pz[n]), MARK.finish, 3)
            end
            if jlist then
                for i, k in ipairs(jlist) do
                    if px[k] then Viz.mark(Vector3.new(px[k], py[k] + yo, pz[k]), "jump") end
                    if i % 300 == 0 then
                        task.wait()
                        if Viz.gen ~= gen then return end
                    end
                end
            end
            if acts then
                for _, a in ipairs(acts) do
                    if a.cx and a.cy and a.cz then
                        Viz.mark(Vector3.new(a.cx, a.cy + yo, a.cz), a.type)
                    end
                end
            end
            if Viz.gen ~= gen then return end
            Viz.building = false
            local pend = Viz.pend
            Viz.pend = {}
            for _, p in ipairs(pend) do Viz.feed(p, REC_COLOR) end
            if uniform and Viz.cur then Viz.updateTail(Viz.cur) end
        end)
    end

    ------------------------------------------------------------ U : path, serialisasi, kendaraan
    function U.recJumps()
        local out = {}
        for k = 1, R.n do
            if R.jmp[k] and (k == 1 or not R.jmp[k - 1]) then out[#out + 1] = k end
        end
        return out
    end

    local function refreshViz()
        Viz.clear()
        if not S.showRoute then return end
        Viz.tol = math.clamp(tonumber(nbv("vtol")) or 0.25, 0.05, 2)
        if R.active and R.n > 1 then
            Viz.build(R.px, R.py, R.pz, R.n, R.hip, true, U.recJumps(), R.acts)
        elseif S.loaded then
            Viz.build(S.px, S.py, S.pz, S.n, S.hip0, false, S.js, S.act)
        elseif R.n > 1 then
            Viz.build(R.px, R.py, R.pz, R.n, R.hip, true, U.recJumps(), R.acts)
        else
            status("Belum ada rute untuk ditampilkan (muat file atau mulai rekam).", C.warn)
        end
    end

    function U.instPath(inst, root)
        root = root or game
        local rev, cur, guard = {}, inst, 0
        while cur and cur ~= root and guard < 80 do
            guard += 1
            local par, nth = cur.Parent, 1
            if par then
                for _, sib in ipairs(par:GetChildren()) do
                    if sib == cur then break end
                    if sib.Name == cur.Name then nth += 1 end
                end
            end
            rev[#rev + 1] = { cur.Name, nth }
            cur = par
        end
        if cur ~= root then return nil end
        local out = {}
        for i = #rev, 1, -1 do out[#out + 1] = rev[i] end
        return out
    end

    function U.resolvePath(p, root)
        local cur = root or game
        if type(p) ~= "table" or not cur then return nil end
        for _, e in ipairs(p) do
            local name, nth = e[1], e[2] or 1
            local found, c = nil, 0
            for _, ch in ipairs(cur:GetChildren()) do
                if ch.Name == name then
                    c += 1
                    if c == nth then found = ch break end
                end
            end
            if not found then found = cur:FindFirstChild(name) end
            if not found then return nil end
            cur = found
        end
        return cur
    end

    function U.ser(v, d)
        d = d or 0
        local tv = typeof(v)
        if v == nil then return { ["$"] = "nil" }
        elseif tv == "number" then
            if v ~= v then return { ["$"] = "num", v = "nan" } end
            if v == math.huge then return { ["$"] = "num", v = "inf" } end
            if v == -math.huge then return { ["$"] = "num", v = "-inf" } end
            return v
        elseif tv == "string" or tv == "boolean" then return v
        elseif tv == "Vector3" then return { ["$"] = "v3", x = num(v.X, 0), y = num(v.Y, 0), z = num(v.Z, 0) }
        elseif tv == "Vector2" then return { ["$"] = "v2", x = num(v.X, 0), y = num(v.Y, 0) }
        elseif tv == "CFrame" then
            local c = { v:GetComponents() }
            for i = 1, #c do c[i] = num(c[i], 0) end
            return { ["$"] = "cf", c = c }
        elseif tv == "Color3" then return { ["$"] = "c3", r = v.R, g = v.G, b = v.B }
        elseif tv == "EnumItem" then return { ["$"] = "enum", e = tostring(v.EnumType), n = v.Name }
        elseif tv == "Instance" then
            local ch = LP.Character
            if v == LP then return { ["$"] = "lp" } end
            if ch and v == ch then return { ["$"] = "ch" } end
            if ch and v:IsDescendantOf(ch) then return { ["$"] = "chi", p = U.instPath(v, ch) } end
            if v:IsDescendantOf(LP) then return { ["$"] = "lpi", p = U.instPath(v, LP) } end
            return { ["$"] = "inst", p = U.instPath(v) }
        elseif tv == "table" then
            if d > 6 then return { ["$"] = "nil" } end
            local ks, cnt = {}, 0
            for k, val in pairs(v) do
                cnt += 1
                if cnt > 300 then break end
                ks[#ks + 1] = { U.ser(k, d + 1), U.ser(val, d + 1) }
            end
            return { ["$"] = "t", k = ks }
        end
        return { ["$"] = "nil" }
    end

    function U.deser(v)
        if type(v) ~= "table" then return v end
        local tag = v["$"]
        if tag == "nil" then return nil
        elseif tag == "num" then
            if v.v == "nan" then return 0 / 0 end
            return v.v == "inf" and math.huge or -math.huge
        elseif tag == "v3" then return Vector3.new(v.x, v.y, v.z)
        elseif tag == "v2" then return Vector2.new(v.x, v.y)
        elseif tag == "cf" then return CFrame.new(table.unpack(v.c))
        elseif tag == "c3" then return Color3.new(v.r, v.g, v.b)
        elseif tag == "enum" then
            local ok, r = pcall(function() return Enum[tostring(v.e):gsub("^Enum%.", "")][v.n] end)
            return ok and r or nil
        elseif tag == "lp" then return LP
        elseif tag == "ch" then return LP.Character
        elseif tag == "chi" then return U.resolvePath(v.p, LP.Character)
        elseif tag == "lpi" then return U.resolvePath(v.p, LP)
        elseif tag == "inst" then return U.resolvePath(v.p)
        elseif tag == "t" then
            local t = {}
            for _, kv in ipairs(v.k or {}) do
                local k = U.deser(kv[1])
                if k ~= nil then t[k] = U.deser(kv[2]) end
            end
            return t
        end
        return nil
    end

    function U.guiVisible(o)
        local cur = o
        while cur do
            if cur:IsA("GuiObject") then
                if not cur.Visible then return false end
            elseif cur:IsA("ScreenGui") then
                return cur.Enabled and o.AbsoluteSize.X > 0 and o.AbsoluteSize.Y > 0
            end
            cur = cur.Parent
        end
        return o.AbsoluteSize.X > 0 and o.AbsoluteSize.Y > 0
    end

    function U.guiCenter(o)
        local p, s = o.AbsolutePosition, o.AbsoluteSize
        local sg = o:FindFirstAncestorWhichIsA("ScreenGui")
        local inset = (sg and sg.IgnoreGuiInset) and 0 or GuiService:GetGuiInset().Y
        return p.X + s.X / 2, p.Y + s.Y / 2 + inset
    end

    function U.canFire()
        return (firesignal ~= nil) or (getconnections ~= nil)
    end

    function U.fireGui(el, sigs)
        if not U.canFire() then return false end
        for _, sig in ipairs(sigs) do
            local ok, signal = pcall(function() return el[sig] end)
            if ok and signal then
                if firesignal then
                    pcall(firesignal, signal)
                else
                    pcall(function()
                        for _, c in ipairs(getconnections(signal)) do
                            pcall(function() c:Fire() end)
                        end
                    end)
                end
            end
        end
        return true
    end

    function U.yawOf(cf)
        local _, y = cf:ToOrientation()
        return y
    end

    function U.wrap(a) return (a + math.pi) % (2 * math.pi) - math.pi end

    function U.pivotVehicle(seat, dx, dy, dz, dyaw)
        local m = seat:FindFirstAncestorOfClass("Model")
        if m then
            while m.Parent and m.Parent:IsA("Model") do m = m.Parent end
        end
        local target = m or seat
        local piv = target:GetPivot()
        local sp = seat.Position
        local rot = CFrame.Angles(0, dyaw or 0, 0)
        local newSp = sp + Vector3.new(dx, dy, dz)
        target:PivotTo(CFrame.new(newSp) * rot * CFrame.new(-sp) * piv)
        pcall(function() seat.AssemblyLinearVelocity = rot * seat.AssemblyLinearVelocity end)
    end

    function U.onRemote(self, m, ...)
        if not (R.active and not R.paused) then return end
        if os.clock() < R.holdUntil then return end
        if typeof(self) ~= "Instance" then return end
        local args = table.pack(...)
        local full = self:GetFullName()
        if full:find("DefaultChatSystemChatEvents", 1, true) or full:find("RobloxReplicatedStorage", 1, true) then return end
        local now = os.clock()
        local rt = R.rate[self]
        if not rt or now - rt[2] > 1 then
            rt = { 0, now }
            R.rate[self] = rt
        end
        rt[1] += 1
        if rt[1] > 8 then R.noisy[self] = true end
        local path = U.instPath(self)
        if not path then return end
        local sa = {}
        for i = 1, args.n do sa[i] = U.ser(args[i]) end
        A.rec({ type = "remote", m = m, path = path, nm = self.Name, n = args.n, args = sa }, self)
    end

    ------------------------------------------------------------ A : rekam & replay aksi game
    function A.rec(a, remote)
        if not (R.active and not R.paused) then return end
        local _, root = getChar()
        if root then
            local p = root.Position
            a.cx, a.cy, a.cz = num(p.X, 0), num(p.Y, 0), num(p.Z, 0)
        end
        a.t = R.T
        R.acts[#R.acts + 1] = a
        if remote then R.actRem[a] = remote end
        if S.showRoute and a.cx and not Viz.building then
            Viz.mark(Vector3.new(a.cx, a.cy + Viz.yOff, a.cz), a.type)
        end
    end

    -- klik GUI game (tombol di PlayerGui). Klik pada menu Rayfield sendiri diabaikan (isOwnGui).
    function A.recGui(inp, down, bname)
        local pg = LP:FindFirstChild("PlayerGui")
        if not pg then return end
        local pos = inp.Position
        if down then
            local okL, list = pcall(function() return pg:GetGuiObjectsAtPosition(pos.X, pos.Y) end)
            if not okL then return end
            local target
            for _, o in ipairs(list) do
                if not isOwnGui(o) and o:IsA("GuiButton") then target = o break end
            end
            if not target then
                for _, o in ipairs(list) do
                    if not isOwnGui(o) and o.Active then target = o break end
                end
            end
            if not target then return end
            local path = U.instPath(target, pg)
            if not path then return end
            local txt
            pcall(function() txt = target.Text end)
            local cam = workspace.CurrentCamera
            local vs = cam and cam.ViewportSize or Vector2.new(1, 1)
            local a = {
                type = "gui", d = 1, b = bname, p = path, cls = target.ClassName,
                nx = pos.X / math.max(vs.X, 1), ny = pos.Y / math.max(vs.Y, 1),
            }
            if type(txt) == "string" and txt ~= "" then a.txt = txt:sub(1, 60) end
            R.guiHeld[bname] = a
            A.rec(a)
        else
            local h = R.guiHeld[bname]
            if not h then return end
            R.guiHeld[bname] = nil
            A.rec({ type = "gui", d = 0, b = bname, p = h.p, cls = h.cls, nx = h.nx, ny = h.ny, txt = h.txt })
        end
    end

    function A.onPrompt(prompt)
        local par, pp = prompt.Parent, nil
        if par then
            if par:IsA("BasePart") then pp = par.Position
            elseif par:IsA("Attachment") then pp = par.WorldPosition end
        end
        A.rec({
            type = "prompt", p = U.instPath(prompt), nm = prompt.Name, at = prompt.ActionText, ob = prompt.ObjectText,
            hold = num(prompt.HoldDuration, 0), key = prompt.KeyboardKeyCode.Name,
            px = pp and num(pp.X, 0), py = pp and num(pp.Y, 0), pz = pp and num(pp.Z, 0),
        })
    end

    function A.watchChar(ch)
        task.spawn(function()
            local h = ch:WaitForChild("Humanoid", 10)
            if not h then return end
            h:GetPropertyChangedSignal("SeatPart"):Connect(function()
                if not A.alive then return end
                local seat = h.SeatPart
                if seat then A.lastSeat = seat end
                if not (R.active and not R.paused) then return end
                local sp = seat or A.lastSeat
                if not sp or not sp.Parent then return end
                local pos = sp.Position
                A.rec({
                    type = "seat", sit = seat ~= nil, p = U.instPath(sp), cls = sp.ClassName, nm = sp.Name,
                    sx = num(pos.X, 0), sy = num(pos.Y, 0), sz = num(pos.Z, 0),
                })
            end)
        end)
    end

    function A.installHook()
        if env.__RR_hooked then return true end
        if not (hookmetamethod and getnamecallmethod and setnamecallmethod) then return false end
        local old
        local function handler(self, ...)
            local m = getnamecallmethod()
            if m == "FireServer" or m == "InvokeServer" then
                local h = env.__RR_onRemote
                if h and not (checkcaller and checkcaller()) then
                    pcall(h, self, m, ...)
                    pcall(setnamecallmethod, m)
                end
            end
            return old(self, ...)
        end
        local ok, res = pcall(function()
            return hookmetamethod(game, "__namecall", newcclosure and newcclosure(handler) or handler)
        end)
        if ok and res then
            old = res
            env.__RR_hooked = true
            return true
        end
        return false
    end

    ---- replay aksi
    function A.findGui(a)
        local pg = LP:FindFirstChild("PlayerGui")
        if not pg then return end
        if a._el and a._el.Parent then return a._el end
        local el = a.p and U.resolvePath(a.p, pg)
        if el and el:IsA("GuiObject") and el.ClassName == a.cls then
            a._el = el
            return el
        end
        if os.clock() - (a._scan or 0) < 0.5 then return end
        a._scan = os.clock()
        local last = a.p and a.p[#a.p]
        local nm = last and last[1]
        if nm then
            for _, d in ipairs(pg:GetDescendants()) do
                if d.Name == nm and d.ClassName == a.cls and U.guiVisible(d) then
                    local ok, tx = pcall(function() return d.Text end)
                    if (not a.txt) or (ok and tx == a.txt) then
                        a._el = d
                        return d
                    end
                end
            end
        end
    end

    function A.runGui(a)
        local name = a.b or "MouseButton1"
        local t0 = os.clock()
        local downSigs, upSigs
        if name == "MouseButton2" then
            downSigs, upSigs = { "MouseButton2Down", "MouseButton2Click" }, { "MouseButton2Up" }
        else
            downSigs, upSigs = { "MouseButton1Down", "MouseButton1Click", "Activated" }, { "MouseButton1Up" }
        end

        if a.d == 0 then
            S.def[#S.def + 1] = function(now)
                local pp = A.guiPos[name]
                if pp then
                    if pp.mode == "vim" then
                        sendMouseBtn(name, false, pp[1], pp[2])
                        A.guiHold = math.max(0, A.guiHold - 1)
                    elseif pp.el then
                        U.fireGui(pp.el, upSigs)
                    end
                    A.guiPos[name] = nil
                    return true
                end
                return now - t0 > 3.5
            end
            return
        end

        S.def[#S.def + 1] = function(now)
            local el = A.findGui(a)
            local visible = el and U.guiVisible(el)
            if visible and el:IsA("GuiButton") and U.canFire() then
                U.fireGui(el, downSigs)
                A.guiPos[name] = { 0, 0, mode = "sig", el = el }
                return true
            end
            if not visible and now - t0 < 2.5 then return false end
            if VIM then
                local x, y
                if visible then
                    x, y = U.guiCenter(el)
                else
                    local cam = workspace.CurrentCamera
                    local vs = cam and cam.ViewportSize or Vector2.new(1, 1)
                    x, y = (a.nx or 0.5) * vs.X, (a.ny or 0.5) * vs.Y + GuiService:GetGuiInset().Y
                end
                pcall(function() VIM:SendMouseMoveEvent(x, y, game) end)
                sendMouseBtn(name, true, x, y)
                A.guiPos[name] = { x, y, mode = "vim" }
                A.guiHold += 1
            end
            return true
        end
    end

    function A.findPrompt(a)
        local p = a.p and U.resolvePath(a.p)
        if p and p:IsA("ProximityPrompt") then return p end
        if a.px then
            local ok, parts = pcall(function()
                return workspace:GetPartBoundsInRadius(Vector3.new(a.px, a.py or 0, a.pz or 0), 15)
            end)
            if ok then
                for _, part in ipairs(parts) do
                    for _, c in ipairs(part:GetChildren()) do
                        if c:IsA("ProximityPrompt") and c.Name == a.nm and (not a.at or c.ActionText == a.at) then
                            return c
                        end
                    end
                end
            end
        end
    end

    function A.runPrompt(a)
        local t0 = os.clock()
        local since = t0 - (num(a.hold, 0) + 1.2)
        S.def[#S.def + 1] = function(now)
            if S.useInput and now - t0 < 0.7 then return false end
            local pr = A.findPrompt(a)
            if not pr then return now - t0 > 2.5 end
            if S.useInput and (S.promptHit[pr] or 0) >= since then return true end
            if fireproximityprompt then pcall(fireproximityprompt, pr) end
            return true
        end
    end

    function A.runRemote(a)
        if type(a.path) ~= "table" then return end
        local r = U.resolvePath(a.path)
        if not (r and (r:IsA("RemoteEvent") or r:IsA("RemoteFunction"))) then
            S.missed += 1
            return
        end
        local n = math.floor(num(a.n, 0))
        local args = {}
        for i = 1, n do args[i] = U.deser(a.args and a.args[i]) end
        task.spawn(function()
            if a.m == "InvokeServer" and r:IsA("RemoteFunction") then
                pcall(function() r:InvokeServer(table.unpack(args, 1, n)) end)
            elseif r:IsA("RemoteEvent") then
                pcall(function() r:FireServer(table.unpack(args, 1, n)) end)
            end
        end)
    end

    function A.findSeat(a, h)
        local s = a.p and U.resolvePath(a.p)
        if s and (s:IsA("Seat") or s:IsA("VehicleSeat")) and (not s.Occupant or s.Occupant == h) then return s end
        if a.sx then
            local ok, parts = pcall(function()
                return workspace:GetPartBoundsInRadius(Vector3.new(a.sx, a.sy or 0, a.sz or 0), 80)
            end)
            if ok then
                local best, bd = nil, math.huge
                for _, part in ipairs(parts) do
                    if (part:IsA("Seat") or part:IsA("VehicleSeat")) and part.Name == a.nm
                        and part.ClassName == a.cls and not part.Occupant then
                        local d = (part.Position - Vector3.new(a.sx, a.sy or 0, a.sz or 0)).Magnitude
                        if d < bd then best, bd = part, d end
                    end
                end
                return best
            end
        end
    end

    function A.forceSit(h, root, seat)
        root.CFrame = seat.CFrame * CFrame.new(0, seat.Size.Y / 2 + h.HipHeight + root.Size.Y / 2 + 0.3, 0)
        root.AssemblyLinearVelocity = Vector3.zero
        if firetouchinterest then
            pcall(function()
                firetouchinterest(root, seat, 0)
                firetouchinterest(root, seat, 1)
            end)
        end
    end

    function A.runSeat(a)
        local t0, lastTry = os.clock(), 0
        S.def[#S.def + 1] = function(now, h, root)
            if now - t0 < 0.8 then return false end
            if a.sit then
                if h.SeatPart then return true end
                if now - lastTry > 0.4 then
                    lastTry = now
                    local seat = A.findSeat(a, h)
                    if seat then A.forceSit(h, root, seat) end
                end
                return now - t0 > 4
            else
                if not h.SeatPart then return true end
                if now - lastTry > 0.5 then
                    lastTry = now
                    h.Sit = false
                    h.Jump = true
                    pcall(function() h:ChangeState(Enum.HumanoidStateType.Jumping) end)
                end
                return now - t0 > 3
            end
        end
    end

    function A.run(a)
        local ty = a.type
        if ty == "gui" then A.runGui(a)
        elseif ty == "prompt" then A.runPrompt(a)
        elseif ty == "remote" then A.runRemote(a)
        elseif ty == "seat" then A.runSeat(a) end
    end

    ------------------------------------------------------------ opsi (membaca nilai dari input Rayfield)
    local function readOptions()
        local function nv(key, def, lo, hi) return math.clamp(tonumber(nbv(key)) or def, lo, hi) end
        S.speed       = nv("speed", 1, 0.5, 1.5)
        S.snapDist    = nv("snap", 12, 3, 200)
        S.pull        = nv("pull", 10, 0, 40)
        S.jumpTol     = nv("jumpTol", 0.6, 0.2, 5)
        S.jumpTimeout = nv("jumpTO", 1.5, 0.3, 10)
        S.vehSnap     = nv("vehSnap", 15, 5, 300)
        S.loopDelay   = nv("loopDelay", 3, 0, 120)
        S.loopMax     = math.max(0, math.floor(tonumber(nbv("loopMax")) or 0))
        Viz.tol       = nv("vtol", 0.25, 0.05, 2)
    end

    ------------------------------------------------------------ daftar file
    local function listJson()
        local out = {}
        if not listfiles then return out end
        local ok, files = pcall(listfiles, "")
        if not ok or type(files) ~= "table" then ok, files = pcall(listfiles, ".") end
        if not ok or type(files) ~= "table" then return out end
        for _, p in ipairs(files) do
            local name = tostring(p):match("[^/\\]+$")
            if name and name:lower():match("%.json$") then out[#out + 1] = name end
        end
        table.sort(out)
        return out
    end

    ------------------------------------------------------------ routeproof (MC61|size|adler32)
    local function findProof(name)
        local base = name:gsub("%.json$", "")
        local sp = base:gsub("_", " ")
        local cands = {
            base .. "_routeproof.txt", base .. ".routeproof.txt",
            sp .. ".routeproof.txt", sp .. "_routeproof.txt",
        }
        for _, c in ipairs(cands) do
            local ok, ex = pcall(isfile, c)
            if ok and ex then
                local ok2, txt = pcall(readfile, c)
                if ok2 then return c, txt end
            end
        end
    end

    ------------------------------------------------------------ muat + validasi + compact
    local function loadFile(name)
        if S.loading then return end
        if S.playing then status("Stop replay dulu sebelum memuat file.", C.warn) return end
        if not (readfile and isfile) then
            status("Executor tidak mendukung readfile/isfile.", C.bad)
            return
        end
        name = (name or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if name == "" then status("Isi nama file dulu.", C.warn) return end
        if not isfile(name) and isfile(name .. ".json") then name = name .. ".json" end
        if not isfile(name) then status("File tidak ditemukan di workspace: " .. name, C.bad) return end

        S.loading = true
        task.spawn(function()
            local ok, err = pcall(function()
                status("Membaca file...", C.text)
                task.wait()
                local content = readfile(name)

                if S.verify then
                    local pname, ptxt = findProof(name)
                    if pname then
                        local tag, size, hex = tostring(ptxt):match("^%s*([^|]+)|(%d+)|(%x+)%s*$")
                        if not tag then
                            status("Format " .. pname .. " tidak dikenali, verifikasi dilewati.", C.warn)
                            task.wait(1)
                        else
                            if tonumber(size) ~= #content then
                                error(("Ukuran file tidak cocok routeproof (file %d, proof %s)"):format(#content, size))
                            end
                            local sum = adler32(content, function(p)
                                status(("Verifikasi adler32... %d%%"):format(p * 100), C.text)
                            end)
                            if string.format("%08x", sum) ~= hex:lower() then
                                error(("Adler32 tidak cocok (file %08x, proof %s)"):format(sum, hex:lower()))
                            end
                        end
                    else
                        status("routeproof tidak ditemukan, verifikasi dilewati.", C.warn)
                        task.wait(1)
                    end
                end

                status(("Decode JSON (%.1f MB)... bisa lag beberapa detik"):format(#content / 1048576), C.text)
                task.wait(0.1)
                local data = HttpService:JSONDecode(content)
                content = nil

                if type(data) ~= "table" or #data < 2 then error("Format JSON bukan rekaman rute yang dikenal.") end
                local first = data[1]
                local startIdx = (type(first) == "table" and first.position) and 1 or 2
                if type(data[startIdx]) ~= "table" or not data[startIdx].position then
                    error("Format JSON bukan rekaman rute yang dikenal.")
                end

                local t, px, py, pz, mx, mz, jmp, tool = {}, {}, {}, {}, {}, {}, {}, {}
                local toolNames, toolIdx = {}, {}
                local my, vx, vz, st = {}, {}, {}, {}
                local vyA, thrA, svA = {}, {}, {}
                local cx, cy, cz, ox, oy, oz, mpx, mpy = {}, {}, {}, {}, {}, {}, {}, {}
                local wsA, jpv, jpm, syA = {}, {}, {}, {}
                local hasCam = false
                local stNames, stIdx = {}, {}
                local m, bad, missingTime = 0, 0, false
                local total = #data
                for k = startIdx, total do
                    local f = data[k]
                    local p = type(f) == "table" and f.position
                    local x, y, z = p and num(p.x), p and num(p.y), p and num(p.z)
                    if x and y and z then
                        m += 1
                        local md = type(f.moveDirection) == "table" and f.moveDirection or {}
                        local tm = num(f.time)
                        if not tm then missingTime = true end
                        t[m] = tm or 0
                        px[m], py[m], pz[m] = x, y, z
                        mx[m], mz[m] = num(md.x, 0), num(md.z, 0)
                        my[m] = num(md.y, 0)
                        local vel = type(f.velocity) == "table" and f.velocity or {}
                        vx[m], vz[m] = num(vel.x, 0), num(vel.z, 0)
                        vyA[m] = num(vel.y, 0)
                        thrA[m] = num(f.thr, false)
                        svA[m] = num(f.sv, false)
                        local sn = type(f.state) == "string" and f.state or "?"
                        if not stIdx[sn] then
                            stNames[#stNames + 1] = sn
                            stIdx[sn] = #stNames
                        end
                        st[m] = stIdx[sn]
                        local cm = type(f.camera) == "table" and f.camera or nil
                        if cm then
                            local co = type(f.camOffset) == "table" and f.camOffset or {}
                            cx[m], cy[m], cz[m] = num(cm.x, 0), num(cm.y, 0), num(cm.z, 0)
                            ox[m], oy[m], oz[m] = num(co.x, 0), num(co.y, 0), num(co.z, 0)
                            hasCam = true
                        else
                            cx[m], cy[m], cz[m], ox[m], oy[m], oz[m] = 0, 0, 0, 0, 0, 0
                        end
                        local ms = type(f.mouse) == "table" and f.mouse or {}
                        mpx[m], mpy[m] = num(ms.x, 0.5), num(ms.y, 0.5)
                        jmp[m] = f.jumping and true or false
                        wsA[m] = num(f.walkSpeed, 0)
                        jpv[m] = num(f.jumpPower, 0)
                        jpm[m] = (f.jumpMode == 1)
                        syA[m] = num(f.seatYaw, false)
                        local tn = type(f.tool) == "string" and f.tool or nil
                        if tn then
                            if not toolIdx[tn] then
                                toolNames[#toolNames + 1] = tn
                                toolIdx[tn] = #toolNames
                            end
                            tool[m] = toolIdx[tn]
                        else
                            tool[m] = 0
                        end
                    else
                        bad += 1
                    end
                    if k % 4000 == 0 then
                        status(("Memproses frame %d / %d"):format(k, total), C.text)
                        task.wait()
                    end
                end
                if m < 2 then error("Frame valid kurang dari 2.") end
                S.hip0 = num(type(first) == "table" and first.hipHeight, 2)
                data = nil

                local tShift = 0
                if missingTime or t[m] <= t[1] then
                    for k = 1, m do t[k] = (k - 1) / 60 end
                else
                    local t0 = t[1]
                    tShift = t0
                    t[1] = 0
                    for k = 2, m do
                        local v = t[k] - t0
                        t[k] = (v > t[k - 1]) and v or t[k - 1]
                    end
                end

                local function noGate(i)
                    local nm = stNames[st[i]]
                    return nm == "Swimming" or nm == "Climbing" or nm == "Seated"
                end
                local js, lastStartT = {}, -math.huge
                for k = 1, m do
                    local isStart = (jmp[k] and (k == 1 or not jmp[k - 1]))
                        or (stNames[st[k]] == "Jumping" and (k == 1 or st[k - 1] ~= st[k]))
                    if isStart and not noGate(k) and (k == 1 or not noGate(k - 1)) and t[k] - lastStartT > 0.35 then
                        js[#js + 1] = k
                        lastStartT = t[k]
                    end
                end

                local evT, evK, evD = {}, {}, {}
                local hdrInputs = type(first) == "table" and first.inputs
                local hasInput = type(hdrInputs) == "table"
                if hasInput then
                    for _, e in ipairs(hdrInputs) do
                        if type(e) == "table" then
                            local et, ek, ed = num(e[1]), e[2], e[3]
                            if et and type(ek) == "string" and (ed == 0 or ed == 1) then
                                evT[#evT + 1] = math.max(math.max(0, et - tShift), evT[#evT] or 0)
                                evK[#evK + 1] = ek
                                evD[#evD + 1] = ed
                            end
                        end
                    end
                end

                local jg = {}
                do
                    local p = 1
                    for q, k in ipairs(js) do
                        local g = t[k] - 1e-4
                        local lo = t[k] - 0.4
                        while evT[p] and evT[p] < lo do p += 1 end
                        local e, best = p, nil
                        while evT[e] and evT[e] <= t[k] + 0.03 do
                            if evK[e] == "Space" and evD[e] == 1 then best = evT[e] end
                            e += 1
                        end
                        if best then g = math.min(g, best - 1e-3) end
                        jg[q] = g
                    end
                end

                local act = {}
                local hdrActs = type(first) == "table" and first.actions
                if type(hdrActs) == "table" then
                    for _, a in ipairs(hdrActs) do
                        if type(a) == "table" and type(a.type) == "string" and num(a.t) then
                            a.t = math.max(0, a.t - tShift)
                            a._i = #act + 1
                            act[#act + 1] = a
                        end
                    end
                    table.sort(act, function(x, y)
                        if x.t ~= y.t then return x.t < y.t end
                        return x._i < y._i
                    end)
                end

                S.t, S.px, S.py, S.pz, S.mx, S.mz, S.jmp, S.tool = t, px, py, pz, mx, mz, jmp, tool
                S.cx, S.cy, S.cz, S.ox, S.oy, S.oz, S.mpx, S.mpy = cx, cy, cz, ox, oy, oz, mpx, mpy
                S.ws, S.jpv, S.jpm, S.sy = wsA, jpv, jpm, syA
                S.vy, S.thr, S.sv = vyA, thrA, svA
                S.hasCam, S.hasInput = hasCam, hasInput
                S.ev_t, S.ev_k, S.ev_d, S.ep = evT, evK, evD, 1
                S.my, S.vx, S.vz, S.st, S.stNames, S.js, S.jg = my, vx, vz, st, stNames, js, jg
                S.act, S.ap = act, 1
                S.swimIdx = stIdx["Swimming"] or 0
                S.seatIdx = stIdx["Seated"] or 0
                S.toolNames, S.n, S.loaded, S.fileName = toolNames, m, true, name
                S.T, S.idx, S.jp = 0, 1, 1
                pcall(collectgarbage, "collect")
                status(("Siap: %s\n%d frame • %s • %d lompat • %d input • %d aksi%s"):format(name, m, fmt(t[m]), #js, #evT, #act,
                    bad > 0 and (" • " .. bad .. " frame rusak dibuang") or ""), C.ok)
            end)
            S.loading = false
            if not ok then
                S.loaded = false
                status("Gagal: " .. tostring(err), C.bad)
            elseif S.showRoute and not R.active then
                refreshViz()
            end
        end)
    end

    ------------------------------------------------------------ playback
    local function bsearch(T)
        local lo, hi = 1, S.n
        while lo < hi do
            local mid = (lo + hi + 1) // 2
            if S.t[mid] <= T then lo = mid else hi = mid - 1 end
        end
        return lo
    end

    local function nearestFrame(root)
        local p = root.Position
        local best, bd = 1, math.huge
        local px, py, pz = S.px, S.py, S.pz
        for i = 1, S.n do
            local dx, dy, dz = px[i] - p.X, py[i] - p.Y, pz[i] - p.Z
            local d = dx * dx + dy * dy + dz * dz
            if d < bd then bd, best = d, i end
        end
        return best, math.sqrt(bd)
    end

    local stepConn
    local controlsOff = false
    local CAM_NAME = "RouteReplayCam"
    local camBound = false

    local function setControls(enabled)
        local ok, controls = pcall(function()
            local pm = LP:FindFirstChild("PlayerScripts") and LP.PlayerScripts:FindFirstChild("PlayerModule")
            return pm and require(pm):GetControls()
        end)
        if not ok or not controls then return end
        if enabled and controlsOff then
            pcall(function() controls:Enable() end)
            controlsOff = false
        elseif not enabled and not controlsOff then
            pcall(function() controls:Disable() end)
            controlsOff = true
        end
    end

    local function unbindStep()
        if stepConn then
            pcall(function() stepConn:Disconnect() end)
            stepConn = nil
        end
        if camBound then
            pcall(function() RunService:UnbindFromRenderStep(CAM_NAME) end)
            camBound = false
        end
        releaseAllKeys()
        A.guiHold, A.guiPos = 0, {}
    end

    local function applyTool(h, ch, ti)
        if ti == S.lastTool then return end
        S.lastTool = ti
        if not S.useTool then return end
        if ti == 0 then
            pcall(function() h:UnequipTools() end)
        else
            local name = S.toolNames[ti]
            local tl = ch:FindFirstChild(name) or (LP:FindFirstChild("Backpack") and LP.Backpack:FindFirstChild(name))
            if tl and tl:IsA("Tool") and tl.Parent ~= ch then
                pcall(function() h:EquipTool(tl) end)
            end
        end
    end

    local function finish(msg, color)
        S.playing, S.paused, S.waitingRespawn = false, false, false
        S.holdUntil = 0
        S.def = {}
        unbindStep()
        setControls(true)
        local h = getChar()
        if h then h:Move(Vector3.zero, false) h.Jump = false end
        setPauseUI(false)
        if Viz.ghost then pcall(function() Viz.ghost:Destroy() end) Viz.ghost = nil end
        status(msg, color or C.text)
    end

    local function applyInputEvent(i)
        local name, down = S.ev_k[i], S.ev_d[i] == 1
        if name:sub(1, 11) == "MouseButton" then
            if S.useMouse and VIM then
                local px, py = mousePx(math.clamp(S.idx, 1, math.max(S.n, 1)))
                sendMouseBtn(name, down, px, py)
            end
            return
        end
        S.heldRec[name] = down or nil
    end

    local function syncKeys()
        for name in pairs(S.heldRec) do
            if name ~= "Space" then sendKey(name, true) end
        end
        local pressed = {}
        for name in pairs(keyDown) do pressed[#pressed + 1] = name end
        for _, name in ipairs(pressed) do
            if name ~= "Space" and not S.heldRec[name] then sendKey(name, false) end
        end
    end

    local function seekInput(T)
        releaseAllKeys()
        S.heldRec = {}
        S.prevSpace = false
        local i, evT = 1, S.ev_t
        while evT[i] and evT[i] <= T do
            local name = S.ev_k[i]
            if name:sub(1, 11) ~= "MouseButton" then S.heldRec[name] = (S.ev_d[i] == 1) or nil end
            i += 1
        end
        S.ep = i
    end

    local function seekAct(T)
        local p = 1
        while S.act[p] and S.act[p].t <= T - 1e-6 do p += 1 end
        S.ap = p
        S.def = {}
        A.guiHold, A.guiPos = 0, {}
    end

    local function seekJump(idx)
        local p, js = 1, S.js
        while js[p] and js[p] <= idx do p += 1 end
        S.jp = p
        S.holdT, S.pendingJump, S.jumpHoldUntil, S.prevJmp, S.gateRel = 0, false, 0, false, 0
        seekInput(S.T)
        seekAct(S.T)
    end

    local function beginLoopRespawn()
        S.loops += 1
        if S.loopMax > 0 and S.loops >= S.loopMax then
            finish(("Selesai: %d loop tuntas."):format(S.loops), C.ok)
            return
        end
        S.waitingRespawn = true
        S.holdUntil = math.huge
        releaseAllKeys()
        local hum0 = getChar()
        if hum0 then hum0:Move(Vector3.zero, false) hum0.Jump = false end
        local oldCh = LP.Character
        status(("Loop %d selesai. Respawn dalam %.0f dtk..."):format(S.loops, S.loopDelay), C.warn)

        task.spawn(function()
            task.wait(S.loopDelay)
            if not S.playing then return end
            local h0 = getChar()
            if h0 then pcall(function() h0.Health = 0 end) end
            if oldCh and LP.Character == oldCh then pcall(function() oldCh:BreakJoints() end) end

            status("Menunggu respawn...", C.warn)
            local t0 = os.clock()
            local nh
            while os.clock() - t0 < 45 do
                task.wait(0.25)
                if not S.playing then return end
                local c = LP.Character
                if c and c ~= oldCh then
                    nh = getChar()
                    if nh then break end
                end
            end
            if not nh then finish("Respawn gagal / timeout. Loop dihentikan.", C.bad) return end

            task.wait(S.settle)
            if not S.playing then return end
            local h, root = getChar()
            if not h then finish("Karakter tidak siap setelah respawn.", C.bad) return end

            local yOff = h.HipHeight - S.hip0
            local dx = root.Position.X - S.px[1]
            local dy = root.Position.Y - (S.py[1] + yOff)
            local dz = root.Position.Z - S.pz[1]
            local d = math.sqrt(dx * dx + dy * dy + dz * dz)
            if d > S.startMax then
                finish(("Titik respawn %.0f studs dari awal rute. Loop dihentikan."):format(d), C.warn)
                return
            end

            S.T, S.idx, S.lastTool = 0, 1, -1
            S.lastErr, S.errSince = 0, 0
            seekJump(1)
            S.waitingRespawn = false
            S.holdUntil = 0
            status(("Loop ke-%d dimulai."):format(S.loops + 1), C.ok)
        end)
    end

    local function applyJumpStats(h, v, usePower)
        if usePower then
            if not h.UseJumpPower then h.UseJumpPower = true end
            if math.abs(h.JumpPower - v) > 0.05 then h.JumpPower = v end
        else
            if h.UseJumpPower then h.UseJumpPower = false end
            if math.abs(h.JumpHeight - v) > 0.05 then h.JumpHeight = v end
        end
    end

    local function alignJump(root, ex, ez, vxr, vzr)
        local p = root.Position
        root.CFrame = CFrame.new(ex, p.Y, ez) * root.CFrame.Rotation
        local v = root.AssemblyLinearVelocity
        root.AssemblyLinearVelocity = Vector3.new(vxr, v.Y, vzr)
    end

    local function step(dt)
        if not S.playing or S.paused then return end
        local now = os.clock()
        if now < S.holdUntil then return end

        local h, root, ch = getChar()
        if not h then S.dbg = "karakter tidak ditemukan / mati" return end

        local n, t = S.n, S.t
        local pos = root.Position
        local stateName = h:GetState().Name
        local inWater = stateName == "Swimming"
        local curSeat = h.SeatPart

        local adv = dt * S.speed
        if S.syncTime and S.lastErr > 2 and not curSeat then
            adv *= math.clamp(1 - (S.lastErr - 2) / 8, 0.1, 1)
        end
        local newT = S.T + adv

        local holding = false
        local hux, huz, hdx, hdz, halong = 0, 0, 0, 0, 0
        local jf = S.js[S.jp]
        local gT = jf and (S.jg[S.jp] or t[jf]) or 0
        if S.jumpGate and jf and not curSeat and S.gateRel ~= S.jp and newT >= gT then
            local gi = bsearch(gT)
            local gx, gz = S.mx[gi], S.mz[gi]
            local mg = math.sqrt(gx * gx + gz * gz)
            if mg < 0.1 then
                gx, gz = S.vx[gi], S.vz[gi]
                mg = math.sqrt(gx * gx + gz * gz)
            end
            hdx, hdz = S.px[gi] - pos.X, S.pz[gi] - pos.Z
            local arrived
            if mg > 0.1 then
                hux, huz = gx / mg, gz / mg
                halong = hdx * hux + hdz * huz
                local lat = hdx * huz - hdz * hux
                arrived = halong <= S.jumpTol and math.abs(lat) <= S.jumpTol * 3
            else
                arrived = hdx * hdx + hdz * hdz <= S.jumpTol * S.jumpTol
            end
            S.holdT += dt
            if arrived or inWater or S.holdT > S.jumpTimeout then
                S.holdT = 0
                S.gateRel = S.jp
            else
                newT = math.max(S.T, gT)
                holding = true
            end
        else
            S.holdT = 0
        end

        S.T = newT
        local jumpAny = false
        while S.idx < n and t[S.idx + 1] <= S.T do
            S.idx += 1
            if S.jmp[S.idx] then jumpAny = true end
        end
        while S.js[S.jp] and S.js[S.jp] <= S.idx do S.jp += 1 end

        if S.useInput then
            local evT = S.ev_t
            while evT[S.ep] and evT[S.ep] <= S.T do
                applyInputEvent(S.ep)
                S.ep += 1
            end
        end

        local acts = S.act
        while acts[S.ap] and acts[S.ap].t <= S.T do
            local a0 = acts[S.ap]
            S.ap += 1
            pcall(A.run, a0)
        end
        if #S.def > 0 then
            for i = #S.def, 1, -1 do
                local okd, done = pcall(S.def[i], now, h, root)
                if not okd or done then table.remove(S.def, i) end
            end
        end

        if S.idx >= n and S.T >= t[n] then
            if S.loop then
                beginLoopRespawn()
            else
                finish("Selesai: rute sudah habis diputar.", C.ok)
            end
            return
        end

        local a = S.idx
        local b = math.min(a + 1, n)
        local span = t[b] - t[a]
        local al = (span > 1e-6) and math.clamp((S.T - t[a]) / span, 0, 1) or 0
        S.al = al
        local yOff = h.HipHeight - S.hip0
        local ex = S.px[a] + (S.px[b] - S.px[a]) * al
        local ey = S.py[a] + (S.py[b] - S.py[a]) * al + yOff
        local ez = S.pz[a] + (S.pz[b] - S.pz[a]) * al

        local seated = curSeat ~= nil
        local seatedRec = S.seatIdx ~= 0 and S.st[a] == S.seatIdx

        if S.matchSpeed then
            local w = S.ws[a]
            if w and w > 0 and math.abs(h.WalkSpeed - w) > 0.05 then h.WalkSpeed = w end
            local jv = S.jpv[a]
            if jv and jv > 0 and not seated then applyJumpStats(h, jv, S.jpm[a]) end
        end

        if seated and S.thr[a] and curSeat:IsA("VehicleSeat") then
            local thr, sv = S.thr[a], S.sv[a] or 0
            local okT = pcall(function()
                curSeat.ThrottleFloat = thr
                curSeat.SteerFloat = sv
            end)
            if not okT then
                pcall(function()
                    curSeat.Throttle = math.round(thr)
                    curSeat.Steer = math.round(sv)
                end)
            end
        end

        local errx, erz = ex - pos.X, ez - pos.Z
        local erry = ey - pos.Y
        local errH = math.sqrt(errx * errx + erz * erz)
        local errV = math.abs(erry)

        if S.correction then
            if seated then
                S.errSince = 0
                if seatedRec then
                    local d3 = math.sqrt(errx * errx + erry * erry + erz * erz)
                    if d3 > S.vehSnap then
                        if now > S.vehHold then
                            local dyaw = 0
                            local ry = S.sy[a]
                            if ry then
                                dyaw = U.wrap(ry - U.yawOf(curSeat.CFrame))
                                if math.abs(dyaw) < 0.35 then dyaw = 0 end
                            end
                            U.pivotVehicle(curSeat, errx, erry, erz, dyaw)
                            S.vehHold = now + 0.6
                            errx, erry, erz, errH, errV = 0, 0, 0, 0, 0
                        end
                    elseif S.softLock then
                        local ry = S.sy[a]
                        if ry then
                            local dyaw = U.wrap(ry - U.yawOf(curSeat.CFrame))
                            if math.abs(dyaw) > 0.04 then
                                U.pivotVehicle(curSeat, 0, 0, 0, dyaw * math.clamp(dt * 6, 0, 1))
                            end
                        end
                        local v = curSeat.AssemblyLinearVelocity
                        local k = math.clamp(S.pull * 0.4, 0, 12)
                        local tx = (S.vx[a] or 0) + errx * k
                        local tz = (S.vz[a] or 0) + erz * k
                        local bl = math.clamp(dt * 10, 0, 1)
                        curSeat.AssemblyLinearVelocity = Vector3.new(v.X + (tx - v.X) * bl, v.Y, v.Z + (tz - v.Z) * bl)
                    end
                end
            else
                local snap = false
                if errH > S.snapDist or errV > math.max(40, S.snapDist * 2) then
                    snap = true
                elseif errH > 3 and not holding then
                    S.errSince += dt
                    if S.errSince > S.stuckSec then snap = true end
                else
                    S.errSince = 0
                end
                if snap then
                    teleport(root, ex, ey, ez)
                    errx, erz, errH, erry, errV = 0, 0, 0, 0, 0
                    S.errSince = 0
                elseif S.softLock and not seatedRec and errH > 0.3 and S.pull > 0 then
                    local maxStep = math.max(0.2, h.WalkSpeed * dt * 1.25)
                    local stp = math.min(errH, maxStep, errH * S.pull * dt)
                    local vyStep = 0
                    if inWater and errV > 0.4 then
                        vyStep = math.sign(erry) * math.min(errV, maxStep, errV * S.pull * dt)
                    end
                    root.CFrame = root.CFrame + Vector3.new(errx / errH * stp, vyStep, erz / errH * stp)
                    errx, erz = errx * (1 - stp / errH), erz * (1 - stp / errH)
                    errH = math.sqrt(errx * errx + erz * erz)
                end
            end
        end
        S.lastErr = errH

        if S.showRoute then Viz.ghostAt(ex, ey, ez) end

        local swim = inWater or (S.swimIdx ~= 0 and S.st[a] == S.swimIdx)
        local jumpFlag = S.jmp[a]
        local dx, dy, dz = 0, 0, 0

        if S.useInput then
            syncKeys()
            local recSpace = S.heldRec["Space"] == true
            local effSpace = recSpace
            if swim or seated then
                S.pendingJump = false
            else
                if recSpace and not S.prevSpace then
                    S.pendingJump, S.pendingUntil = true, now + 0.35
                    if S.softLock and errH <= 3 then alignJump(root, ex, ez, S.vx[a], S.vz[a]) end
                end
                if S.pendingJump then
                    if now > S.pendingUntil or stateName == "Jumping" then
                        S.pendingJump = false
                    else
                        effSpace = true
                    end
                end
            end
            S.prevSpace = recSpace
            sendKey("Space", effSpace)
            jumpFlag = effSpace
        else
            dx, dz = S.mx[a], S.mz[a]
            if swim then dy = S.my[a] end

            if holding and not swim then
                if (hux ~= 0 or huz ~= 0) and halong > S.jumpTol then
                    local lx, lz = hdx - halong * hux, hdz - halong * huz
                    dx, dz = hux + lx * 0.6, huz + lz * 0.6
                else
                    dx, dz = hdx * 0.6, hdz * 0.6
                end
                dy = 0
            elseif S.steer then
                if swim then
                    if math.sqrt(errx * errx + erry * erry + erz * erz) > 1 then
                        dx += errx * 0.3
                        dy += erry * 0.3
                        dz += erz * 0.3
                    end
                elseif errH > 1 then
                    dx += errx * 0.25
                    dz += erz * 0.25
                end
            end
            local mag = math.sqrt(dx * dx + dy * dy + dz * dz)
            if mag > 1 then dx, dy, dz = dx / mag, dy / mag, dz / mag end
            h:Move(Vector3.new(dx, dy, dz), false)

            local jumpNow = jumpAny or (S.jmp[a] and not S.prevJmp)
            S.prevJmp = S.jmp[a]
            if swim or seated then
                S.pendingJump = false
                h.Jump = jumpFlag
            else
                if jumpNow then
                    S.pendingJump, S.pendingUntil = true, now + 0.35
                    if S.softLock and errH <= 3 then alignJump(root, ex, ez, S.vx[a], S.vz[a]) end
                end
                if S.pendingJump then
                    if now > S.pendingUntil then
                        S.pendingJump = false
                    else
                        jumpFlag = true
                        if h.FloorMaterial ~= Enum.Material.Air then
                            pcall(function() h:ChangeState(Enum.HumanoidStateType.Jumping) end)
                            S.pendingJump = false
                            S.jumpHoldUntil = now + 0.12
                        end
                    end
                end
                if now < S.jumpHoldUntil then jumpFlag = true end
                h.Jump = jumpFlag
            end
        end

        applyTool(h, ch, S.tool[a])
        S.dbg = string.format("[%s] %s%s%s  selisih %.2f studs%s",
            S.useInput and "input" or "move", stateName, holding and " (tunggu titik lompat)" or "",
            seated and " [kendaraan]" or "", errH, S.missed > 0 and ("  remote hilang: " .. S.missed) or "")
    end

    local function camStep()
        if not (S.playing and not S.paused and S.useCamera and S.hasCam and not S.waitingRespawn) then return end
        if os.clock() < S.holdUntil then return end
        local cam = workspace.CurrentCamera
        local _, root = getChar()
        if not (cam and root) then return end
        local a = math.clamp(S.idx, 1, S.n)
        local b = math.min(a + 1, S.n)
        local al = S.al or 0
        local look = Vector3.new(
            S.cx[a] + (S.cx[b] - S.cx[a]) * al,
            S.cy[a] + (S.cy[b] - S.cy[a]) * al,
            S.cz[a] + (S.cz[b] - S.cz[a]) * al)
        if look.Magnitude < 0.01 then return end
        local off = Vector3.new(
            S.ox[a] + (S.ox[b] - S.ox[a]) * al,
            S.oy[a] + (S.oy[b] - S.oy[a]) * al,
            S.oz[a] + (S.oz[b] - S.oz[a]) * al)
        local cp = root.Position + off
        cam.CFrame = CFrame.lookAt(cp, cp + look.Unit)
    end

    local function startPlay(T0, teleportToStart)
        if R.active then status("Hentikan rekaman dulu.", C.warn) return end
        if not S.loaded then status("Muat file dulu.", C.warn) return end
        local h, root = getChar()
        if not h then status("Karakter belum siap.", C.warn) return end
        readOptions()
        unbindStep()

        S.T = math.clamp(T0, 0, S.t[S.n])
        S.idx = bsearch(S.T)
        seekJump(S.idx)
        S.lastTool, S.holdUntil = -1, 0
        S.lastErr, S.errSince = 0, 0
        S.waitingRespawn, S.loops, S.missed = false, 0, 0
        S.paused = false
        S.playing = true
        setPauseUI(false)

        if teleportToStart and S.correction then
            teleport(root, S.px[S.idx], S.py[S.idx] + (h.HipHeight - S.hip0), S.pz[S.idx])
        end
        -- lepas fokus kotak teks agar tombol rekaman tidak tertahan di TextBox menu
        local tbx = UIS:GetFocusedTextBox()
        if tbx then pcall(function() tbx:ReleaseFocus() end) end
        S.useInput = S.inputMode and S.hasInput and (VIM ~= nil or (keypress ~= nil and keyrelease ~= nil))
        setControls(S.useInput)
        local ev = RunService.PreSimulation or RunService.Heartbeat
        stepConn = ev:Connect(step)
        if S.useCamera and S.hasCam then
            RunService:BindToRenderStep(CAM_NAME, Enum.RenderPriority.Camera.Value + 1, camStep)
            camBound = true
        end
        if S.showRoute and not Viz.folder then refreshViz() end
        local noteTxt = ""
        if S.inputMode and not S.useInput then
            noteTxt = S.hasInput and "  (backend input tidak ada)" or "  (file tanpa data input)"
        end
        status(("Memutar dari %s ... [%s%s]%s"):format(fmt(S.T), S.useInput and "input asli" or "Humanoid:Move",
            (S.useCamera and S.hasCam) and " + kamera" or "", noteTxt), C.ok)
    end

    -- aksi tombol replay (dipanggil dari callback elemen Rayfield)
    local function actStart()
        startPlay(tonumber(nbv("startT")) or 0, true)
    end

    local function actNearest()
        if not S.loaded then status("Muat file dulu.", C.warn) return end
        local h, root = getChar()
        if not h then status("Karakter belum siap.", C.warn) return end
        local i, dist = nearestFrame(root)
        if dist > 200 then
            status(("Terlalu jauh dari rute (%.0f studs). Dekati rute atau pakai 'Mulai Awal'."):format(dist), C.warn)
            return
        end
        startPlay(S.t[i], false)
    end

    local function actPause(on)
        if not S.playing then setPauseUI(false) return end
        S.paused = on
        if S.paused then
            local h = getChar()
            if h then h:Move(Vector3.zero, false) end
            releaseAllKeys()
            setControls(true)
            status("Dijeda.", C.warn)
        else
            setControls(S.useInput)
            status("Memutar...", C.ok)
        end
    end

    local function actStop()
        if S.playing then finish("Dihentikan.", C.warn) end
    end

    track(PPS.PromptTriggered:Connect(function(prompt, plr)
        if plr ~= LP then return end
        S.promptHit[prompt] = os.clock()
        A.onPrompt(prompt)
    end))

    ------------------------------------------------------------ perekam
    local function intern(list, idx, name)
        if not idx[name] then
            list[#list + 1] = name
            idx[name] = #list
        end
        return idx[name]
    end

    local function resetRec()
        for _, k in ipairs({ "t", "px", "py", "pz", "vx", "vy", "vz", "mx", "my", "mz", "cx", "cy", "cz", "ox", "oy", "oz",
            "mpx", "mpy", "ev_t", "ev_k", "ev_d", "rx", "ry", "rz", "jmp", "ws", "st", "tool", "jpv", "jpm", "sy", "thr", "sv",
            "acts", "guiHeld" }) do
            R[k] = {}
        end
        R.actRem = setmetatable({}, { __mode = "k" })
        R.rate = setmetatable({}, { __mode = "k" })
        R.noisy = setmetatable({}, { __mode = "k" })
        R.toolNames, R.toolIdx, R.toolJson, R.stNames, R.stIdx = {}, {}, {}, {}, {}
        R.n, R.T, R.dist, R.evn = 0, 0, 0, 0
        R.holdUntil, R.jumpSeen = 0, false
    end

    local function recStep(dt)
        if not R.active or R.paused then return end
        if os.clock() < R.holdUntil then return end
        local h, root, ch = getChar()
        if not h then return end

        if R.n == 0 then R.T = 0 else R.T += dt end
        if R.n > 0 and (R.T - R.t[R.n]) < R.interval - 0.0025 then return end

        local cf = root.CFrame
        local p = cf.Position
        if p.X ~= p.X or p.Y ~= p.Y or p.Z ~= p.Z then return end
        local v = root.AssemblyLinearVelocity
        local md = h.MoveDirection
        local rx, ry, rz = cf:ToOrientation()

        local n = R.n + 1
        R.n = n
        R.t[n] = R.T
        R.px[n], R.py[n], R.pz[n] = p.X, p.Y, p.Z
        R.vx[n], R.vy[n], R.vz[n] = v.X, v.Y, v.Z
        R.mx[n], R.mz[n] = md.X, md.Z
        R.my[n] = md.Y
        do
            local cam = workspace.CurrentCamera
            if cam then
                local ccf = cam.CFrame
                local lv = ccf.LookVector
                local off = ccf.Position - p
                R.cx[n], R.cy[n], R.cz[n] = lv.X, lv.Y, lv.Z
                R.ox[n], R.oy[n], R.oz[n] = off.X, off.Y, off.Z
                local ml = UIS:GetMouseLocation()
                local vs = cam.ViewportSize
                R.mpx[n], R.mpy[n] = ml.X / math.max(vs.X, 1), ml.Y / math.max(vs.Y, 1)
            else
                R.cx[n], R.cy[n], R.cz[n], R.ox[n], R.oy[n], R.oz[n] = 0, 0, 0, 0, 0, 0
                R.mpx[n], R.mpy[n] = 0.5, 0.5
            end
        end
        R.rx[n], R.ry[n], R.rz[n] = rx, ry, rz
        R.jmp[n] = (R.jumpSeen or h.Jump) and true or false
        R.jumpSeen = false
        R.ws[n] = h.WalkSpeed
        local usePower = h.UseJumpPower
        R.jpv[n] = usePower and h.JumpPower or h.JumpHeight
        R.jpm[n] = usePower and true or false
        local seat = h.SeatPart
        R.sy[n] = seat and U.yawOf(seat.CFrame) or false

        local thr, sv = false, false
        if seat and seat:IsA("VehicleSeat") then
            local okv, a1, a2 = pcall(function() return seat.ThrottleFloat, seat.SteerFloat end)
            if okv and type(a1) == "number" and type(a2) == "number" then
                thr, sv = a1, a2
            else
                thr, sv = seat.Throttle, seat.Steer
            end
        end
        R.thr[n], R.sv[n] = thr, sv

        R.st[n] = intern(R.stNames, R.stIdx, h:GetState().Name)

        local tl = ch:FindFirstChildOfClass("Tool")
        if tl then
            local before = #R.toolNames
            local ti = intern(R.toolNames, R.toolIdx, tl.Name)
            if #R.toolNames > before then R.toolJson[ti] = HttpService:JSONEncode(tl.Name) end
            R.tool[n] = ti
        else
            R.tool[n] = 0
        end

        if n > 1 then
            local dx, dy, dz = p.X - R.px[n - 1], p.Y - R.py[n - 1], p.Z - R.pz[n - 1]
            R.dist += math.sqrt(dx * dx + dy * dy + dz * dz)
        end
        if S.showRoute then
            Viz.append(p.X, p.Y, p.Z)
            if R.jmp[n] and (n == 1 or not R.jmp[n - 1]) and not Viz.building then
                Viz.mark(Vector3.new(p.X, p.Y + Viz.yOff, p.Z), "jump")
            end
        end
    end
    track(RunService.Heartbeat:Connect(recStep))

    track(UIS.JumpRequest:Connect(function()
        if R.active then R.jumpSeen = true end
    end))

    local function addEv(tm, name, d)
        local i = R.evn + 1
        R.evn = i
        R.ev_t[i], R.ev_k[i], R.ev_d[i] = tm, name, d
    end

    local function onInput(inp, gpe, down)
        if not R.active or R.paused then return end
        if UIS:GetFocusedTextBox() then return end
        local ut = inp.UserInputType
        local name
        if ut == Enum.UserInputType.Keyboard then
            name = inp.KeyCode.Name
            if BLOCK[name] then return end
        elseif ut == Enum.UserInputType.MouseButton1 or ut == Enum.UserInputType.MouseButton2
            or ut == Enum.UserInputType.MouseButton3 then
            if not down and R.guiHeld[ut.Name] then
                A.recGui(inp, false, ut.Name)
                return
            end
            if gpe then
                if down then A.recGui(inp, true, ut.Name) end
                return
            end
            name = ut.Name
        else
            return
        end
        addEv(R.T, name, down and 1 or 0)
    end
    track(UIS.InputBegan:Connect(function(i, g) onInput(i, g, true) end))
    track(UIS.InputEnded:Connect(function(i, g) onInput(i, g, false) end))

    local function reconcileHeld(T0)
        local phys = {}
        if not UIS:GetFocusedTextBox() then
            for _, inp in ipairs(UIS:GetKeysPressed()) do
                local nm = inp.KeyCode.Name
                if not BLOCK[nm] then phys[nm] = true end
            end
        end
        for _, b in ipairs({ "MouseButton1", "MouseButton2", "MouseButton3" }) do
            if UIS:IsMouseButtonPressed(Enum.UserInputType[b]) then phys[b] = true end
        end
        local hist = {}
        for i = 1, R.evn do hist[R.ev_k[i]] = (R.ev_d[i] == 1) or nil end
        for k in pairs(hist) do
            if not phys[k] then addEv(T0, k, 0) end
        end
        for k in pairs(phys) do
            if not hist[k] then addEv(T0, k, 1) end
        end
    end

    -- mengembalikan true bila rekaman benar-benar dimulai (dipakai untuk menyelaraskan toggle GUI)
    local function startRec()
        if S.playing then status("Hentikan replay dulu.", C.warn) return false end
        local h = getChar()
        if not h then status("Karakter belum siap.", C.warn) return false end
        if R.n > 1 and not R.saved and not R.discardWarn then
            R.discardWarn = true
            status("Rekaman sebelumnya BELUM disimpan! Aktifkan 'Rekam' lagi untuk menimpa.", C.warn)
            return false
        end
        R.discardWarn = false
        resetRec()
        R.hip = h.HipHeight
        R.interval = math.clamp(tonumber(nbv("interval")) or 0, 0, 0.2)
        R.active, R.paused, R.saved = true, false, false
        reconcileHeld(0)
        local hooked = A.installHook()
        setRecUI(true)
        setRecPauseUI(false)
        Viz.clear()
        Viz.yOff = -(R.hip + 1.0) + 0.2
        Viz.tol = math.clamp(tonumber(nbv("vtol")) or 0.25, 0.05, 2)
        local extra = hooked and "" or "  (hook remote tidak tersedia di executor ini)"
        status("Merekam semua (gerak, kendaraan, GUI, prompt, remote, duduk). Undo jika tersangkut." .. extra, C.bad)
        return true
    end

    local function stopRec()
        if not R.active then return end
        R.active, R.paused = false, false
        setRecUI(false)
        setRecPauseUI(false)
        status(("Rekaman berhenti: %d frame • %s • %d aksi. Klik Simpan."):format(R.n, fmt(R.n > 0 and R.t[R.n] or 0), #R.acts), C.ok)
    end

    local function actRecPause(on)
        if not R.active then setRecPauseUI(false) return end
        R.paused = on
        if not R.paused then
            R.holdUntil = os.clock() + 0.1
            reconcileHeld(R.T)
        end
        status(R.paused and "Rekaman dijeda." or "Merekam...", R.paused and C.warn or C.bad)
    end

    local function rewindTo(targetTime)
        local h, root = getChar()
        if not h then status("Karakter belum siap untuk undo.", C.warn) return end
        local k = R.n
        while k > 1 and R.t[k] > targetTime do k -= 1 end
        R.n = k
        R.T = R.t[k]
        R.jumpSeen = false
        R.dist = 0
        while R.evn > 0 and R.ev_t[R.evn] > R.T do R.evn -= 1 end
        while #R.acts > 0 and R.acts[#R.acts].t > R.T do R.acts[#R.acts] = nil end
        R.guiHeld = {}
        reconcileHeld(R.T)
        for i = 2, k do
            local dx, dy, dz = R.px[i] - R.px[i - 1], R.py[i] - R.py[i - 1], R.pz[i] - R.pz[i - 1]
            R.dist += math.sqrt(dx * dx + dy * dy + dz * dz)
        end

        R.holdUntil = os.clock() + 1
        local seat = h.SeatPart
        local wasSeated = R.stNames[R.st[k]] == "Seated"
        if seat and wasSeated then
            local p = root.Position
            local dyaw = 0
            if R.sy[k] then dyaw = U.wrap(R.sy[k] - U.yawOf(seat.CFrame)) end
            U.pivotVehicle(seat, R.px[k] - p.X, R.py[k] - p.Y, R.pz[k] - p.Z, dyaw)
        else
            if seat then
                h.Sit = false
                pcall(function() h:ChangeState(Enum.HumanoidStateType.Jumping) end)
                task.wait(0.2)
            end
            teleport(root, R.px[k], R.py[k], R.pz[k], R.ry[k])
        end
        h:Move(Vector3.zero, false)
        R.holdUntil = os.clock() + 0.3
        R.saved = false
        if S.showRoute then Viz.build(R.px, R.py, R.pz, R.n, R.hip, true, U.recJumps(), R.acts) end
        status(("Undo: kembali ke %s (frame %d)."):format(fmt(R.T), k), C.warn)
    end

    local function actUndo()
        if R.n < 2 then status("Belum ada rekaman untuk di-undo.", C.warn) return end
        local sec = math.clamp(tonumber(nbv("undoSec")) or 2, 0.1, 120)
        rewindTo(R.t[R.n] - sec)
    end

    local function actUndoJump()
        if R.n < 2 then status("Belum ada rekaman untuk di-undo.", C.warn) return end
        local j
        for k = R.n, 2, -1 do
            if R.jmp[k] and not R.jmp[k - 1] then j = k break end
        end
        if j and (R.t[R.n] - R.t[j]) <= 30 then
            rewindTo(R.t[j] - 0.4)
        else
            rewindTo(R.t[R.n] - math.clamp(tonumber(nbv("undoSec")) or 2, 0.1, 120))
        end
    end

    ------------------------------------------------------------ simpan
    local function frameJson(k)
        local tl = R.tool[k]
        local extra = ""
        if R.sy[k] then extra = extra .. string.format(',"seatYaw":%.4f', R.sy[k]) end
        if type(R.thr[k]) == "number" and type(R.sv[k]) == "number" then
            extra = extra .. string.format(',"thr":%.3f,"sv":%.3f', R.thr[k], R.sv[k])
        end
        if tl ~= 0 and R.toolJson[tl] then extra = extra .. ',"tool":' .. R.toolJson[tl] end
        return string.format(
            '{"position":{"x":%.4f,"y":%.4f,"z":%.4f},"velocity":{"x":%.3f,"y":%.3f,"z":%.3f},' ..
            '"moveDirection":{"x":%.4f,"y":%.4f,"z":%.4f},"rotation":{"x":%.3f,"y":%.3f,"z":%.3f},' ..
            '"camera":{"x":%.4f,"y":%.4f,"z":%.4f},"camOffset":{"x":%.3f,"y":%.3f,"z":%.3f},"mouse":{"x":%.4f,"y":%.4f},' ..
            '"time":%.4f,"jumping":%s,"walkSpeed":%.2f,"jumpPower":%.2f,"jumpMode":%d,"state":"%s"%s}',
            R.px[k], R.py[k], R.pz[k], R.vx[k], R.vy[k], R.vz[k], R.mx[k], R.my[k], R.mz[k],
            math.deg(R.rx[k]), math.deg(R.ry[k]), math.deg(R.rz[k]),
            R.cx[k], R.cy[k], R.cz[k], R.ox[k], R.oy[k], R.oz[k], R.mpx[k], R.mpy[k],
            R.t[k], R.jmp[k] and "true" or "false", R.ws[k], num(R.jpv[k], 0), R.jpm[k] and 1 or 0,
            R.stNames[R.st[k]] or "Running", extra)
    end

    local function saveRec()
        if R.saving then return end
        if R.n < 2 then status("Rekaman kosong, tidak ada yang disimpan.", C.warn) return end
        if not writefile then status("Executor tidak mendukung writefile.", C.bad) return end
        if R.active then stopRec() end
        R.saving = true
        task.spawn(function()
            local ok, err = pcall(function()
                local rawName = (W.recName and tostring(W.recName.value)) or ""
                local name = rawName:gsub("^%s+", ""):gsub("%s+$", ""):gsub("[\\/:*?\"<>|]", "_")
                if name == "" then name = "REC_" .. os.date("%Y%m%d_%H%M%S") end
                if not name:lower():match("%.json$") then name = name .. ".json" end

                local n = R.n
                local evParts, evBuf = {}, {}
                for i = 1, R.evn do
                    evBuf[#evBuf + 1] = string.format('[%.4f,"%s",%d]', R.ev_t[i], R.ev_k[i], R.ev_d[i])
                    if i % 2000 == 0 then
                        evParts[#evParts + 1] = table.concat(evBuf, ",")
                        evBuf = {}
                    end
                end
                if #evBuf > 0 then evParts[#evParts + 1] = table.concat(evBuf, ",") end

                local outActs = {}
                for _, a in ipairs(R.acts) do
                    local rm = R.actRem[a]
                    if not (a.type == "remote" and rm and R.noisy[rm]) then outActs[#outActs + 1] = a end
                end
                local okJ, actsJson = pcall(function() return HttpService:JSONEncode(outActs) end)
                local dropped = ""
                if not okJ then
                    local safe = {}
                    for _, a in ipairs(outActs) do
                        if a.type ~= "remote" then safe[#safe + 1] = a end
                    end
                    outActs = safe
                    actsJson = HttpService:JSONEncode(safe)
                    dropped = " (aksi remote dibuang: argumen tidak bisa disimpan)"
                end

                local chunks = { string.format('[{"hipHeight":%.4f,"routeEngine":"RouteRec4","inputs":[%s],"actions":%s}',
                    R.hip, table.concat(evParts, ","), actsJson) }
                local buf = {}
                for k = 1, n do
                    buf[#buf + 1] = "," .. frameJson(k)
                    if k % 3000 == 0 then
                        chunks[#chunks + 1] = table.concat(buf)
                        buf = {}
                        status(("Menyusun JSON... %d / %d"):format(k, n), C.text)
                        task.wait()
                    end
                end
                buf[#buf + 1] = "]"
                chunks[#chunks + 1] = table.concat(buf)
                local json = table.concat(chunks)
                chunks, buf = nil, nil

                status(("Menulis %s (%.1f MB)..."):format(name, #json / 1048576), C.text)
                task.wait()
                writefile(name, json)

                local sum = adler32(json, function(p) status(("Membuat routeproof... %d%%"):format(p * 100), C.text) end)
                local proof = ("MC61|%d|%08x"):format(#json, sum)
                writefile(name:gsub("%.json$", "") .. "_routeproof.txt", proof)

                R.saved = true
                if W.fileInput then W.fileInput:Set(name, true) end
                if W.fileDrop then pcall(function() W.fileDrop:Refresh(listJson()) end) end
                status(("Tersimpan: %s (%d frame, %d aksi)%s. Memuat ulang..."):format(name, n, #outActs, dropped), C.ok)
                task.wait(0.2)
            end)
            R.saving = false
            if not ok then
                status("Gagal menyimpan: " .. tostring(err), C.bad)
            else
                loadFile(W.fileInput and tostring(W.fileInput.value) or "")
            end
        end)
    end

    ------------------------------------------------------------ GUI Rayfield: tab REPLAY
    -- (dibuat setelah semua fungsi di atas terdefinisi, jadi callback bisa langsung memanggilnya)
    do
        local defaultFile = "AFK_NORMAL.json"
        for _, f in ipairs(listJson()) do
            if f:lower() == "afk_normal.json" then defaultFile = f break end
        end

        local pgR = ctx.pages.replay
        pgR:CreateSection({ name = "File rute" })
        W.fileInput = pgR:CreateInput({
            name = "Nama file .json", flag = "Route_FileName", value = defaultFile, placeholder = "nama file .json",
            description = "Ketik manual atau pilih dari daftar di bawah.",
        })
        W.fileDrop = pgR:CreateDropdown({
            name = "Pilih dari workspace", flag = "Route_FilePick", forgetState = true,
            options = listJson(), placeholder = "(pilih file)",
            callback = function(sel)
                if type(sel) == "table" then sel = sel[1] end
                if sel and sel ~= "" and W.fileInput then W.fileInput:Set(sel, true) end
            end,
        })
        do
            local row = pgR:CreateGroup()
            row:CreateButton({ name = "Muat", callback = function() loadFile(tostring(W.fileInput.value)) end })
            row:CreateButton({ name = "Segarkan daftar", callback = function()
                W.fileDrop:Refresh(listJson())
                if #W.fileDrop.value == 0 then
                    status("Daftar file diperbarui (kosong bila tidak ada .json terdeteksi).", C.dim)
                end
            end })
        end

        pgR:CreateSection({ name = "Status" })
        lblStatus = pgR:CreateText({ name = "Status", text = "Pilih file .json lalu klik Muat, atau mulai rekam rute baru." })
        W.lblProg = pgR:CreateText({ name = "Progres", text = "0 / 0" })

        pgR:CreateSection({ name = "Kontrol" })
        do
            local row = pgR:CreateGroup()
            row:CreateButton({ name = "Mulai Awal", callback = actStart })
            row:CreateButton({ name = "Lanjut Terdekat", callback = actNearest })
        end
        W.pauseT = pgR:CreateToggle({
            name = "Pause", flag = "Route_Pause", forgetState = true, value = false,
            callback = actPause,
        })
        pgR:CreateButton({ name = "Stop", callback = actStop })

        NB.startT = GUI.num(pgR, "Mulai dari detik", 0, nil, "Route_StartT")
        NB.speed  = GUI.num(pgR, "Kecepatan (0.5-1.5)", 1, nil, "Route_Speed")
        GUI.toggle(pgR, "Loop: respawn lalu ulang", S, "loop", nil, "Route_Loop")
        GUI.toggle(pgR, "Tampilkan rute 3D", S, "showRoute", function() refreshViz() end, "Route_ShowRoute", true)
        pgR:CreateText({ text = "Kursor mouse tetap bebas saat replay. Hindari menekan tombol gerak (WASD/Space) selama replay. Titik putih = posisi yang diharapkan di rute." })

        ---------------------------------------------------------- tab REKAM
        local pgK = ctx.pages.rekam
        pgK:CreateSection({ name = "Perekam" })
        W.recName = pgK:CreateInput({
            name = "Nama file rekaman", flag = "Route_RecName", forgetState = true, value = "",
            placeholder = "kosong = otomatis",
        })
        W.recT = pgK:CreateToggle({
            name = "Rekam", description = "Merekam gerak, lompat, input, GUI, prompt, remote, kendaraan.",
            flag = "Route_Rec", forgetState = true, value = false,
            callback = function(on)
                if on then
                    if not startRec() then setRecUI(false) end
                else
                    stopRec()
                end
            end,
        })
        W.recPauseT = pgK:CreateToggle({
            name = "Pause Rekam", flag = "Route_RecPause", forgetState = true, value = false,
            callback = actRecPause,
        })
        do
            local row = pgK:CreateGroup()
            row:CreateButton({ name = "Undo (detik)", callback = actUndo })
            row:CreateButton({ name = "Undo Lompatan", callback = actUndoJump })
        end
        pgK:CreateButton({ name = "Simpan JSON + routeproof", callback = saveRec })
        W.lblRec = pgK:CreateText({ name = "Rekaman", text = "Belum ada." })
        NB.undoSec  = GUI.num(pgK, "Undo mundur (detik)", 2, nil, "Route_UndoSec")
        NB.interval = GUI.num(pgK, "Interval sampel (0 = tiap frame)", 0, nil, "Route_Interval")
        pgK:CreateText({ text = "Saat Rekam diaktifkan, SEMUA ikut tersimpan otomatis: gerak, lompat, berenang, keyboard, kamera, mouse, klik GUI (pilih/beli), prompt/interaksi E, remote (beli boost, spawn kendaraan), duduk/turun kendaraan, serta throttle & steer kapal/mobil. Tersangkut? Undo, karakter (atau kendaraan) kembali ke posisi sebelumnya." })

        ---------------------------------------------------------- tab OPSI RUTE
        local pgO = ctx.pages.opsi
        pgO:CreateSection({ name = "Replay" })
        GUI.toggle(pgO, "Input asli (keyboard)", S, "inputMode", nil, "Route_inputMode")
        GUI.toggle(pgO, "Arah kamera", S, "useCamera", nil, "Route_useCamera")
        GUI.toggle(pgO, "Klik dunia (gerakkan kursor)", S, "useMouse", nil, "Route_useMouse")
        GUI.toggle(pgO, "Equip tool", S, "useTool", nil, "Route_useTool")
        GUI.toggle(pgO, "Auto-lanjut respawn", S, "autoResume", nil, "Route_autoResume")
        GUI.toggle(pgO, "Verifikasi routeproof", S, "verify", nil, "Route_verify")
        pgO:CreateSection({ name = "Presisi posisi" })
        GUI.toggle(pgO, "Koreksi / anti-tersangkut", S, "correction", nil, "Route_correction")
        GUI.toggle(pgO, "Steering (mode Move)", S, "steer", nil, "Route_steer")
        GUI.toggle(pgO, "Sinkron waktu", S, "syncTime", nil, "Route_syncTime")
        GUI.toggle(pgO, "Gerbang lompat", S, "jumpGate", nil, "Route_jumpGate")
        GUI.toggle(pgO, "Kunci halus (jalan & kendaraan)", S, "softLock", nil, "Route_softLock")
        GUI.toggle(pgO, "Samakan speed/jump", S, "matchSpeed", nil, "Route_matchSpeed")
        pgO:CreateSection({ name = "Lanjutan" })
        NB.snap      = GUI.num(pgO, "Jarak teleport koreksi (stud)", 12, nil, "Route_snap")
        NB.pull      = GUI.num(pgO, "Kekuatan kunci halus", 10, nil, "Route_pull")
        NB.jumpTol   = GUI.num(pgO, "Toleransi titik lompat", 0.6, nil, "Route_jumpTol")
        NB.jumpTO    = GUI.num(pgO, "Maks. tunggu lompat (dtk)", 1.5, nil, "Route_jumpTO")
        NB.vehSnap   = GUI.num(pgO, "Snap kendaraan (stud)", 15, nil, "Route_vehSnap")
        NB.loopDelay = GUI.num(pgO, "Jeda sebelum respawn (dtk)", 3, nil, "Route_loopDelay")
        NB.loopMax   = GUI.num(pgO, "Jumlah loop (0 = tak hingga)", 0, nil, "Route_loopMax")
        NB.vtol      = GUI.num(pgO, "Toleransi marker (stud)", 0.25, nil, "Route_vtol")

        local backendName = VIM and "VirtualInputManager"
            or ((keypress and keyrelease) and "keypress/keyrelease" or "TIDAK ADA (fallback Humanoid:Move)")
        local hook = (hookmetamethod and getnamecallmethod and setnamecallmethod) and "tersedia"
            or "TIDAK ADA (remote tidak bisa direkam)"
        local guiBackend = U.canFire() and "firesignal/getconnections (kursor bebas)"
            or (VIM and "klik virtual (kursor bergerak sesaat)" or "TIDAK ADA")
        pgO:CreateText({
            name = "Backend executor",
            text = "Backend input: " .. backendName .. "\nKlik GUI replay: " .. guiBackend .. "\nHook remote: " .. hook ..
                "\nfireproximityprompt: " .. (fireproximityprompt and "ada" or "tidak ada"),
        })
    end

    ------------------------------------------------------------ label progres
    task.spawn(function()
        local lastProg, lastRec
        while A.alive do
            if S.loaded and S.n > 0 and W.lblProg then
                local p = math.clamp(S.T / math.max(S.t[S.n], 1), 0, 1)
                local filled = math.floor(p * 20 + 0.5)
                local txt = ("[%s%s]\nframe %d / %d  •  %s / %s  (%.1f%%)%s"):format(
                    string.rep("#", filled), string.rep("-", 20 - filled), S.idx, S.n, fmt(S.T), fmt(S.t[S.n]), p * 100,
                    S.loop and ("  •  loop " .. (S.loops + 1)) or "")
                if S.playing and S.dbg then txt = txt .. "\n" .. S.dbg end
                if txt ~= lastProg then
                    lastProg = txt
                    pcall(function() W.lblProg:Set(txt) end)
                end
            end
            if (R.n > 0 or R.active) and W.lblRec then
                local nRem = 0
                for _, a in ipairs(R.acts) do
                    if a.type == "remote" then nRem += 1 end
                end
                local txt = ("%s  %d frame • %s • %.0f studs\n%d input • %d aksi (%d remote)%s"):format(
                    R.active and (R.paused and "DIJEDA" or "MEREKAM") or "BERHENTI",
                    R.n, fmt(R.n > 0 and R.t[R.n] or 0), R.dist, R.evn, #R.acts, nRem,
                    R.saved and "" or "  (belum disimpan)")
                if txt ~= lastRec then
                    lastRec = txt
                    pcall(function() W.lblRec:Set(txt) end)
                end
            end
            task.wait(0.25)
        end
    end)

    ------------------------------------------------------------ respawn
    track(LP.CharacterAdded:Connect(function(newCh)
        A.watchChar(newCh)

        if R.active and not R.paused then
            R.paused = true
            setRecPauseUI(true)
            status("Karakter respawn, rekaman DIJEDA. Klik Undo untuk kembali ke posisi terakhir, lalu matikan 'Pause Rekam'.", C.warn)
        end

        if S.waitingRespawn then return end
        if not (S.playing and S.autoResume and S.loaded) then return end
        status("Karakter respawn, menyiapkan lanjut...", C.warn)
        S.holdUntil = math.huge
        releaseAllKeys()
        task.wait(2)
        local h, root
        for _ = 1, 40 do
            h, root = getChar()
            if h then break end
            task.wait(0.25)
        end
        if not S.playing then return end
        if not h then S.holdUntil = 0 return end
        local i, dist = nearestFrame(root)
        if dist > 200 then
            finish(("Respawn terlalu jauh dari rute (%.0f studs). Dihentikan."):format(dist), C.warn)
            return
        end
        S.T, S.idx, S.lastTool, S.holdUntil = S.t[i], i, -1, 0
        S.lastErr, S.errSince = 0, 0
        seekJump(i)
        status(("Lanjut setelah respawn dari %s"):format(fmt(S.T)), C.ok)
    end))
    if LP.Character then A.watchChar(LP.Character) end

    ------------------------------------------------------------ cleanup & inisialisasi
    local function cleanup()
        A.alive = false
        env.__RR_onRemote = nil
        unbindStep()
        setControls(true)
        S.playing = false
        R.active = false
        Viz.clear()
        for _, c in ipairs(rconns) do pcall(function() c:Disconnect() end) end
        local h = getChar()
        if h then pcall(function() h:Move(Vector3.zero, false) end) end
    end
    env.__RR_onRemote = function(self, m, ...) return U.onRemote(self, m, ...) end

    resetRec()

    return {
        cleanup = cleanup,
        isPlaying = function() return S.playing end,
    }
end

--==================================================================================================
-- 8. NOTIFICATION SYSTEM
--    Semua notify() di fitur Hub/Route tampil sebagai kartu notifikasi Rayfield (window:Notify).
--    Cadangan: notifikasi bawaan Roblox bila Notify gagal.
--==================================================================================================
do
    local nativeNotify = notify
    notify = function(text)
        local ok = pcall(function()
            window:Notify({ title = Config.Name, content = tostring(text), duration = 3 })
        end)
        if not ok then nativeNotify(text) end
    end
end

--==================================================================================================
-- 6 & 7. GUI COMPONENTS + CALLBACK CONNECTIONS
--    Setiap elemen Rayfield memegang callback yang langsung memanggil fungsi asli di bagian 5.
--    Toggle yang berbahaya / bergantung karakter diberi forgetState = true (tidak ikut autoLoad).
--==================================================================================================

---------------------------------------------------------------- Main
pMain:CreateSection({ name = "Local Player" })
GUI.toggle(pMain, "Anti AFK", Cfg, "antiAFK", nil, "Main_AntiAFK")
GUI.toggle(pMain, "Speed Hack", Cfg, "speedOn", function(on)
    if not on and hum() then hum().WalkSpeed = 16 end
end, "Main_SpeedOn")
GUI.num(pMain, "Speed", Cfg.speed, function(n) Cfg.speed = n end, "Main_Speed")
GUI.toggle(pMain, "Jump Power", Cfg, "jumpOn", function(on)
    if not on and hum() then hum().JumpPower = 50 end
end, "Main_JumpOn")
GUI.num(pMain, "Jump", Cfg.jump, function(n) Cfg.jump = n end, "Main_Jump")
GUI.toggle(pMain, "Infinite Jump", Cfg, "infJump", nil, "Main_InfJump")
GUI.toggle(pMain, "Noclip", Cfg, "noclip", nil, "Main_Noclip")
GUIH.fly = GUI.toggle(pMain, "Fly (WASD/Space/Shift)", Cfg, "fly", setFly, "Main_Fly", true)
GUI.num(pMain, "Fly Speed", Cfg.flySpeed, function(n) Cfg.flySpeed = n end, "Main_FlySpeed")

---------------------------------------------------------------- Boost (meniru UI boost di game)
pBoost:CreateSection({ name = "Boosts" })

GUIH.master = GUI.toggle(pBoost, "Aktifkan boost terpilih", BS, "master", function(on)
    if on then
        local n = activateSelected()
        if n == 0 then
            BS.master = false
            GUIH.master:Set(false, true)
            notify("Pilih minimal satu boost dulu")
            return
        end
        if #refs == 0 then scanBoostValues() end
        notify(n .. " boost aktif")
    else
        stopBoosts()
        notify("Boost dihentikan")
    end
end, "Boost_Master", true)

for _, key in ipairs(ORDER) do
    local b = B[key]
    GUI.toggle(pBoost, b.name, b, "on", function(on)
        gameTap(GAME_TXT[key])
        if on and BS.master then
            active[key] = os.clock() + b.secs
            if BS.freeze then frozenLeft[key] = b.secs end
            pinKey(key)
        elseif not on then
            active[key] = nil
            frozenLeft[key] = nil
        end
    end, "Boost_" .. key)
end

GUIH.freeze = GUI.toggle(pBoost, "Freeze All Selected Boosts", BS, "freeze", function(on)
    if on then
        local n, now = 0, os.clock()
        for _, key in ipairs(ORDER) do
            if B[key].on and (active[key] or 0) > now then
                frozenLeft[key] = active[key] - now
                n += 1
            end
        end
        if n == 0 then
            BS.freeze = false
            GUIH.freeze:Set(false, true)
            notify("Aktifkan boost dulu, baru freeze")
        else
            if #refs == 0 then scanBoostValues() end
            gameTap(GAME_TXT.freeze)
            notify("Timer boost dibekukan")
        end
    else
        table.clear(frozenLeft)
        gameTap(GAME_TXT.freeze)
        notify("Freeze dimatikan")
    end
end, "Boost_Freeze", true)

pBoost:CreateSlider({
    name = "Change Boosts Time", flag = "Boost_Secs", range = { 5, 180 }, increment = 1, value = BS.secs, suffix = " dtk",
    callback = function(v)
        BS.secs = v
        for _, b in pairs(B) do b.secs = v end
        local now = os.clock()
        for _, key in ipairs(ORDER) do
            if B[key].on and (active[key] or 0) > now then
                if BS.freeze then frozenLeft[key] = v else active[key] = now + v end
                pinKey(key)
            end
        end
    end,
})

GUIH.inf = GUI.toggle(pBoost, "Inf Boosts", BS, "inf", function(on)
    if on then
        if #refs == 0 then scanBoostValues() end
    elseif BS.master then
        local now = os.clock()
        for _, key in ipairs(ORDER) do
            if B[key].on then active[key] = now + B[key].secs end
        end
    end
    gameTap(GAME_TXT.inf)
    notify(on and "Boost tanpa batas waktu" or "Inf Boosts dimatikan")
end, "Boost_Inf", true)

pBoost:CreateSection({ name = "Lanjutan" })
GUI.toggle(pBoost, "Sinkron ke UI boost game (klik otomatis)", BS, "sync", nil, "Boost_Sync")
pBoost:CreateButton({ name = "Scan nilai boost milik game", callback = function()
    notify(scanBoostValues() .. " nilai boost ditemukan (lihat console F9)")
end })
local boostStatus = pBoost:CreateText({ name = "Status", text = "-" })
pBoost:CreateText({ text = "Efek boost berjalan di sisi klien (speed, lompat, anti-ragdoll, tegak di tali, anti avalanche, HP penuh) dan timer boost milik game ikut dikunci. Sinkron UI game bersifat opsional: klik otomatis tombol asli di UI game berdasarkan teksnya." })

task.spawn(function()
    local lastTxt
    while alive do
        local lines, any = {}, false
        local now = os.clock()
        for _, key in ipairs(ORDER) do
            if isOn(key) then
                any = true
                local txt
                if BS.inf then
                    txt = "INF"
                elseif BS.freeze and frozenLeft[key] then
                    txt = "BEKU " .. math.ceil(frozenLeft[key]) .. " dtk"
                else
                    txt = math.ceil(math.max((active[key] or now) - now, 0)) .. " dtk"
                end
                lines[#lines + 1] = B[key].name .. ": " .. txt
            end
        end
        if BS.master and not any then
            BS.master = false
            GUIH.master:Set(false, true)
            stopBoosts()
            notify("Waktu boost habis")
        end
        local out = #lines > 0 and table.concat(lines, " | ") or "tidak ada boost aktif"
        if out ~= lastTxt then
            lastTxt = out
            pcall(function() boostStatus:Set(out) end)
        end
        task.wait(0.5)
    end
end)

---------------------------------------------------------------- Teleport
pTP:CreateSection({ name = "Pengaturan" })
GUI.toggle(pTP, "Teleport halus (tween)", Cfg, "useTween", nil, "TP_Tween")
GUI.num(pTP, "Kecepatan TP", Cfg.tpSpeed, function(n) Cfg.tpSpeed = n end, "TP_Speed")
GUI.toggle(pTP, "Ctrl + Klik = TP", Cfg, "clickTP", nil, "TP_ClickTP")

-- Catatan: Gen2 menambah elemen baru di akhir tab, jadi daftar dinamis (slot / checkpoint)
-- memakai Dropdown + Add/Refresh, bukan tombol yang dibuat satu per satu.
pTP:CreateSection({ name = "Slot posisi" })
local slotDrop = pTP:CreateDropdown({
    name = "Slot tersimpan", flag = "TP_SlotPick", forgetState = true, options = {}, placeholder = "(belum ada slot)",
})
pTP:CreateButton({ name = "Simpan posisi sekarang sebagai slot", callback = function()
    local r = hrp()
    if r then
        savedSlots[#savedSlots + 1] = r.CFrame
        local i = #savedSlots
        slotDrop:Add("Slot " .. i)
        notify("Slot " .. i .. " disimpan")
    end
end })
pTP:CreateButton({ name = "TP ke slot terpilih", callback = function()
    local sel = slotDrop.value[1]
    local i = sel and tonumber(sel:match("%d+"))
    if i and savedSlots[i] then tpTo(savedSlots[i]) else notify("Pilih slot dulu") end
end })

pTP:CreateSection({ name = "Checkpoint terdeteksi" })
local cpDrop = pTP:CreateDropdown({
    name = "Checkpoint", flag = "TP_CPPick", forgetState = true, options = {}, placeholder = "(scan dulu)",
})
pTP:CreateButton({ name = "Scan checkpoint / camp / summit", callback = function()
    local n = scanCheckpoints()
    local opts = {}
    for i, w in ipairs(scanned) do
        opts[i] = i .. ". " .. w.name .. " (Y " .. math.floor(w.part.Position.Y) .. ")"
    end
    cpDrop:Refresh(opts)
    notify(n .. " titik ditemukan")
end })
pTP:CreateButton({ name = "TP ke checkpoint terpilih", callback = function()
    local sel = cpDrop.value[1]
    local i = sel and tonumber(sel:match("^(%d+)%."))
    local w = i and scanned[i]
    if w and w.part.Parent then
        tpTo(w.part.CFrame + Vector3.new(0, 5, 0))
    else
        notify("Pilih checkpoint dulu (scan ulang bila daftar kedaluwarsa)")
    end
end })

---------------------------------------------------------------- Auto
pAuto:CreateSection({ name = "Auto Summit" })
GUIH.summit = GUI.toggle(pAuto, "Auto Summit (urut dari bawah)", Cfg, "autoSummit", function(on)
    if on then runAutoSummit() end
end, "Auto_Summit", true)
GUI.num(pAuto, "Jeda tiap titik (detik)", Cfg.summitDelay, function(n) Cfg.summitDelay = n end, "Auto_SummitDelay")
pAuto:CreateButton({ name = "Teleport ke titik tertinggi", callback = function()
    if #scanned == 0 then scanCheckpoints() end
    local w = scanned[#scanned]
    if w then tpTo(w.part.CFrame + Vector3.new(0, 5, 0)) else notify("Belum ada checkpoint") end
end })

---------------------------------------------------------------- ESP
pESP:CreateSection({ name = "Visual" })
GUI.toggle(pESP, "ESP Pemain", Cfg, "espPlayers", refreshESP, "ESP_Players")
GUI.toggle(pESP, "ESP Checkpoint", Cfg, "espCP", refreshESP, "ESP_CP")
GUI.toggle(pESP, "Fullbright", Cfg, "fullbright", setFullbright, "ESP_Fullbright")

---------------------------------------------------------------- Proteksi
pProt:CreateSection({ name = "Moderator" })
GUI.toggle(pProt, "Kick jika moderator masuk", Cfg, "modKick", function(on)
    if on then
        for _, p in ipairs(Players:GetPlayers()) do checkPlayer(p) end
    end
end, "Prot_ModKick")
GUI.toggle(pProt, "Pindah server (bukan kick)", Cfg, "modHop", nil, "Prot_ModHop")
GUI.num(pProt, "Min. rank grup", Cfg.modRank, function(n) Cfg.modRank = n end, "Prot_ModRank")
pProt:CreateInput({
    name = "Nama mod (koma)", flag = "Prot_ModNames", value = "", placeholder = "nama1, nama2",
    callback = function(t)
        table.clear(modNames)
        for name in tostring(t):gmatch("[^,%s]+") do modNames[name:lower()] = true end
        if Cfg.modKick then
            for _, p in ipairs(Players:GetPlayers()) do checkPlayer(p) end
        end
    end,
})
pProt:CreateText({ text = "Deteksi: nama di daftar, rank grup pembuat game >= nilai di atas, atau nama role mengandung mod/admin/staff/dev/owner. Tidak ada jaminan semua moderator terdeteksi." })
pProt:CreateSection({ name = "Gameplay" })
GUI.toggle(pProt, "Anti Gameplay Paused", Cfg, "antiPause", nil, "Prot_AntiPause")

---------------------------------------------------------------- Misc
pMisc:CreateSection({ name = "Lainnya" })
pMisc:CreateButton({ name = "FPS Boost", callback = fpsBoost })
pMisc:CreateButton({ name = "Server Hop", callback = serverHop })
pMisc:CreateButton({ name = "Rejoin", callback = function()
    TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LP)
end })
pMisc:CreateButton({ name = "Reset Karakter", callback = function()
    if hum() then hum().Health = 0 end
end })
pMisc:CreateButton({ name = "Copy Posisi (CFrame)", callback = function()
    local r = hrp()
    if r and setclipboard then
        setclipboard(tostring(r.CFrame))
        notify("Disalin")
    end
end })

---------------------------------------------------------------- Route (tab Replay / Rekam / Opsi Rute)
Route = createRoute({
    pages = { replay = pRepl, rekam = pRek, opsi = pOpsi },
    isOwnGui = isOwnGui,
    GUI = GUI,
})

--==================================================================================================
-- 9. CONFIGURATION SAVING
--    Disimpan otomatis oleh Rayfield Gen2 (autoSave/autoLoad di CreateWindow -> Config.Save) ke:
--      Rayfield/Configurations/AntarcticaHub/AntarcticaHub.rfld
--    Tab Pengaturan bawaan Rayfield juga punya bagian "Configurations" (simpan/muat banyak profil).
--==================================================================================================
pUI:CreateSection({ name = "Antarmuka" })
pUI:CreateKeybind({
    name = "Tombol tampil / sembunyi", flag = "Gui_ToggleKey", value = Config.ToggleKey,
    callback = function() window:ToggleHide() end,
    onChanged = function(k)
        if k and k.Name then notify("Tombol GUI: " .. k.Name) end
    end,
})
pUI:CreateDropdown({
    name = "Tema", flag = "Gui_Theme", options = { "default", "cobalt", "ember", "amethyst", "frost", "rose" },
    value = Theme.Name, forgetState = Theme.UseCustomTheme or nil,
    callback = function(sel)
        if type(sel) == "table" then sel = sel[1] end
        if sel then pcall(function() window:ChangeTheme(sel) end) end
    end,
})
pUI:CreateDivider({ text = "Konfigurasi" })
pUI:CreateButton({ name = "Simpan konfigurasi sekarang", callback = function()
    local ok, res = pcall(function() return window:Save() end)
    notify((ok and res) and "Konfigurasi disimpan" or "Gagal menyimpan konfigurasi (executor mendukung writefile?)")
end })
pUI:CreateButton({ name = "Muat konfigurasi", callback = function()
    local ok, res = pcall(function() return window:Load() end)
    notify((ok and res) and "Konfigurasi dimuat" or "Tidak ada konfigurasi tersimpan / gagal memuat")
end })
pUI:CreateDivider({ text = "Uji" })
pUI:CreateButton({ name = "Tes notifikasi", callback = function() notify("Notifikasi berfungsi") end })
pUI:CreateText({ text = "Tema bawaan Gen2 bisa diganti di sini. Tema kustom dan ikon diatur di bagian Window/Theme Configuration pada awal file." })

--==================================================================================================
-- UNLOAD TERPADU
--==================================================================================================
local function unload()
    if not alive then return end
    alive = false
    Cfg.autoSummit = false
    if Route then pcall(Route.cleanup) end
    stopBoosts()
    setFly(false)
    local h = hum()
    if h then
        setStates(h, true)
        pcall(function() h:SetStateEnabled(Enum.HumanoidStateType.Dead, true) end)
        h.WalkSpeed, h.JumpPower = 16, 50
    end
    clearESP("players")
    clearESP("cp")
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    if window and not window.unloaded then pcall(function() window:Unload() end) end
    env.AntarcticaHubLoaded = false
end

pMisc:CreateButton({ name = "Tutup & Hapus Script", callback = unload })

-- bila window ditutup lewat tombol bawaan Rayfield (window.unloaded = true), hentikan juga semua fitur
task.spawn(function()
    while alive do
        if window.unloaded then unload() break end
        task.wait(0.5)
    end
end)

env.AntarcticaHubLoaded = true
env.AntarcticaHubUnload = unload

--==================================================================================================
-- 10. INITIALIZATION
--==================================================================================================
task.spawn(function()
    task.wait(2)
    if alive then scanBoostValues() end
end)
notify("MIRO HUB ARTIC dimuat (Rayfield Gen2)")