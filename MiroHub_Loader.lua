--[[
    MIRO HUB ARTIC - Key Loader
    Halaman pertama = sistem key. Key benar -> script utama (Rayfield Gen2) dijalankan.

    Cara pakai (executor):
        loadstring(game:HttpGet("URL_RAW_FILE_LOADER_INI"))()

    Script utama (file Hub lengkap Anda) diambil dari:
      1) CONFIG.MainURL  (link raw GitHub / Pastebin raw / dll), atau
      2) file lokal CONFIG.MainFile di folder workspace executor (fallback)
]]

local CONFIG = {
    Key      = "141202",
    MainURL  = "https://raw.githubusercontent.com/Mirohub14/AntarticaHub/refs/heads/main/MiroHub_Main.lua"
    MainFile = "MiroHub_Main.lua",
    MaxTry   = 5,
    SaveKey  = true,
    KeyFile  = "MiroHub_Key.txt",
}

local Players          = game:GetService("Players")
local UIS              = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local CoreGui          = game:GetService("CoreGui")
local env              = (getgenv and getgenv()) or _G

if env.MiroKeyGui then pcall(function() env.MiroKeyGui:Destroy() end) end

local LP = Players.LocalPlayer

local function guiParent()
    if gethui then
        local ok, h = pcall(gethui)
        if ok and h then return h end
    end
    local ok = pcall(function() return CoreGui.Name end)
    if ok then return CoreGui end
    return LP:WaitForChild("PlayerGui")
end

local function new(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props or {}) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end

---------------------------------------------------------------- muat script utama
local function loadMain()
    local src
    if type(CONFIG.MainURL) == "string" and CONFIG.MainURL:match("^https?://") then
        local ok, res = pcall(function() return game:HttpGet(CONFIG.MainURL) end)
        if ok and type(res) == "string" and #res > 0 then src = res end
    end
    if not src and readfile and isfile and isfile(CONFIG.MainFile) then
        local ok, res = pcall(readfile, CONFIG.MainFile)
        if ok then src = res end
    end
    if not src then
        return false, "Script utama tidak ditemukan. Isi CONFIG.MainURL atau simpan file " .. CONFIG.MainFile
    end
    local fn, err = loadstring(src)
    if not fn then return false, "Gagal compile: " .. tostring(err) end
    local ok, err2 = pcall(fn)
    if not ok then return false, "Error saat menjalankan: " .. tostring(err2) end
    return true
end

---------------------------------------------------------------- GUI
local COL = {
    bg = Color3.fromRGB(16, 22, 38), panel = Color3.fromRGB(24, 33, 56),
    accent = Color3.fromRGB(41, 121, 255), text = Color3.fromRGB(232, 238, 252),
    dim = Color3.fromRGB(139, 154, 192), ok = Color3.fromRGB(46, 160, 110), bad = Color3.fromRGB(214, 72, 80),
}

local sg = new("ScreenGui", { Name = "MiroKeyGui", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999 })
pcall(function() if syn and syn.protect_gui then syn.protect_gui(sg) end end)
sg.Parent = guiParent()
env.MiroKeyGui = sg

local frame = new("Frame", {
    Size = UDim2.fromOffset(340, 210), Position = UDim2.new(0.5, -170, 0.5, -105),
    BackgroundColor3 = COL.bg, BorderSizePixel = 0,
}, sg)
new("UICorner", { CornerRadius = UDim.new(0, 12) }, frame)
new("UIStroke", { Color = COL.accent, Thickness = 1.5 }, frame)

new("TextLabel", {
    Size = UDim2.new(1, -50, 0, 34), Position = UDim2.fromOffset(16, 10), BackgroundTransparency = 1,
    Text = "MIRO HUB ARTIC", Font = Enum.Font.GothamBold, TextSize = 20, TextColor3 = COL.text,
    TextXAlignment = Enum.TextXAlignment.Left,
}, frame)
new("TextLabel", {
    Size = UDim2.new(1, -32, 0, 18), Position = UDim2.fromOffset(16, 40), BackgroundTransparency = 1,
    Text = "Masukkan key untuk membuka script", Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = COL.dim,
    TextXAlignment = Enum.TextXAlignment.Left,
}, frame)

local close = new("TextButton", {
    Size = UDim2.fromOffset(28, 28), Position = UDim2.new(1, -40, 0, 12), BackgroundColor3 = COL.panel,
    Text = "X", Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = COL.text, AutoButtonColor = true,
}, frame)
new("UICorner", { CornerRadius = UDim.new(0, 8) }, close)

local box = new("TextBox", {
    Size = UDim2.new(1, -32, 0, 40), Position = UDim2.fromOffset(16, 70), BackgroundColor3 = COL.panel,
    Text = "", PlaceholderText = "Key...", PlaceholderColor3 = COL.dim, TextColor3 = COL.text,
    Font = Enum.Font.Gotham, TextSize = 16, ClearTextOnFocus = false,
}, frame)
new("UICorner", { CornerRadius = UDim.new(0, 8) }, box)

local btn = new("TextButton", {
    Size = UDim2.new(1, -32, 0, 40), Position = UDim2.fromOffset(16, 120), BackgroundColor3 = COL.accent,
    Text = "Verifikasi", Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = Color3.new(1, 1, 1),
}, frame)
new("UICorner", { CornerRadius = UDim.new(0, 8) }, btn)

local status = new("TextLabel", {
    Size = UDim2.new(1, -32, 0, 34), Position = UDim2.fromOffset(16, 166), BackgroundTransparency = 1,
    Text = "", Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = COL.dim, TextWrapped = true,
}, frame)

local function setStatus(t, c) status.Text = t status.TextColor3 = c or COL.dim end

-- drag
do
    local dragging, startPos, startInput
    frame.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging, startInput, startPos = true, i.Position, frame.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - startInput
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

-- isi otomatis key tersimpan
if CONFIG.SaveKey and isfile and readfile then
    pcall(function()
        if isfile(CONFIG.KeyFile) then box.Text = readfile(CONFIG.KeyFile):gsub("%s+", "") end
    end)
end

local tries, busy = 0, false

local function verify()
    if busy then return end
    local input = box.Text:gsub("^%s+", ""):gsub("%s+$", "")
    if input == "" then setStatus("Isi key dulu.", COL.bad) return end

    if input ~= CONFIG.Key then
        tries += 1
        setStatus(("Key salah (%d/%d)."):format(tries, CONFIG.MaxTry), COL.bad)
        if tries >= CONFIG.MaxTry then
            busy = true
            setStatus("Terlalu banyak percobaan. GUI ditutup.", COL.bad)
            task.wait(1.5)
            sg:Destroy()
        end
        return
    end

    busy = true
    setStatus("Key benar. Memuat script utama...", COL.ok)
    if CONFIG.SaveKey and writefile then pcall(writefile, CONFIG.KeyFile, input) end
    task.wait(0.4)

    local ok, err = loadMain()
    if ok then
        sg:Destroy()
    else
        busy = false
        setStatus(err, COL.bad)
    end
end

btn.MouseButton1Click:Connect(verify)
box.FocusLost:Connect(function(enter) if enter then verify() end end)
close.MouseButton1Click:Connect(function() sg:Destroy() end)
