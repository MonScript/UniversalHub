local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local env = (getgenv and getgenv()) or _G
if type(env.MonUniversalConnections) == "table" then
    for _, conn in ipairs(env.MonUniversalConnections) do
        pcall(function()
            conn:Disconnect()
        end)
    end
end
env.MonUniversalConnections = {}

local function trackConn(conn)
    if conn then
        table.insert(env.MonUniversalConnections, conn)
    end
    return conn
end

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    LocalPlayer = Players.LocalPlayer
end

local CONFIG_DIR = "MonUniversalHub"
local CONFIG_FILE = CONFIG_DIR .. "/UniversalConfig.json"

local DefaultConfig = {
    WalkSpeedEnabled = false,
    WalkSpeedValue = 28,
    JumpPowerEnabled = false,
    JumpPowerValue = 75,
    InfiniteJump = false,
    FlyEnabled = false,
    FlySpeed = 60,

    PlayerESP = false,
    FullBright = false,
    NoClip = false,
    RemoveFog = false,

    CtrlClickTP = false,
    WaypointESP = true,
    SavedPositions = {},

    AntiAFK = true,
    HotkeyEnabled = true,
    ShowFloatingIcon = true,
    ToggleKey = "M",
    MenuVisible = true
}

local Config = {}
for k, v in pairs(DefaultConfig) do
    if type(v) == "table" then
        Config[k] = {}
    else
        Config[k] = v
    end
end

local function ensureFolder()
    if isfolder and makefolder then
        pcall(function()
            if not isfolder(CONFIG_DIR) then
                makefolder(CONFIG_DIR)
            end
        end)
    end
end

local function saveConfig()
    ensureFolder()
    pcall(function()
        if writefile then
            writefile(CONFIG_FILE, HttpService:JSONEncode(Config))
        end
    end)
end

local function loadConfig()
    ensureFolder()
    pcall(function()
        if isfile and readfile and isfile(CONFIG_FILE) then
            local raw = readfile(CONFIG_FILE)
            local decoded = HttpService:JSONDecode(raw)
            if type(decoded) == "table" then
                for k, v in pairs(DefaultConfig) do
                    if decoded[k] ~= nil and type(decoded[k]) == type(v) then
                        Config[k] = decoded[k]
                    end
                end
            end
        end
    end)
    if type(Config.SavedPositions) ~= "table" then
        Config.SavedPositions = {}
    end
end

loadConfig()

local DefaultWalkSpeed = 16
local DefaultJumpPower = 50
local wasSpeedEnabled = Config.WalkSpeedEnabled
local wasJumpEnabled = Config.JumpPowerEnabled

local function captureHumanoidDefaults(hum)
    if not hum then return end
    if not Config.WalkSpeedEnabled and hum.WalkSpeed > 0 then
        DefaultWalkSpeed = hum.WalkSpeed
    end
    if hum.UseJumpPower then
        if not Config.JumpPowerEnabled and hum.JumpPower > 0 then
            DefaultJumpPower = hum.JumpPower
        end
    else
        if not Config.JumpPowerEnabled and hum.JumpHeight > 0 then
            DefaultJumpPower = hum.JumpHeight
        end
    end
end

local function restoreWalkSpeed()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        pcall(function()
            hum.WalkSpeed = DefaultWalkSpeed or 16
        end)
    end
end

local function restoreJumpPower()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        pcall(function()
            if hum.UseJumpPower then
                hum.JumpPower = DefaultJumpPower or 50
            else
                hum.JumpHeight = DefaultJumpPower or 7.2
            end
        end)
    end
end

local OriginalLighting = {
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    GlobalShadows = Lighting.GlobalShadows,
    Ambient = Lighting.Ambient,
    FogEnd = Lighting.FogEnd,
    FogStart = Lighting.FogStart
}

local SavedAtmospheres = {}

local function applyFullBright(enabled)
    pcall(function()
        if enabled then
            Lighting.Brightness = 2
            Lighting.ClockTime = 14
            Lighting.GlobalShadows = false
            Lighting.Ambient = Color3.fromRGB(205, 205, 205)
        else
            Lighting.Brightness = OriginalLighting.Brightness
            Lighting.ClockTime = OriginalLighting.ClockTime
            Lighting.GlobalShadows = OriginalLighting.GlobalShadows
            Lighting.Ambient = OriginalLighting.Ambient
        end
    end)
end

local function applyRemoveFog(enabled)
    pcall(function()
        if enabled then
            Lighting.FogStart = 100000
            Lighting.FogEnd = 100000
            for _, obj in ipairs(Lighting:GetDescendants()) do
                if obj:IsA("Atmosphere") then
                    if SavedAtmospheres[obj] == nil then
                        SavedAtmospheres[obj] = obj.Density
                    end
                    obj.Density = 0
                end
            end
        else
            Lighting.FogStart = OriginalLighting.FogStart
            Lighting.FogEnd = OriginalLighting.FogEnd
            for obj, origDensity in pairs(SavedAtmospheres) do
                if obj and obj.Parent then
                    obj.Density = origDensity
                end
            end
            SavedAtmospheres = {}
        end
    end)
end

applyFullBright(Config.FullBright)
applyRemoveFog(Config.RemoveFog)

pcall(function()
    trackConn(LocalPlayer.Idled:Connect(function()
        if Config.AntiAFK then
            local VirtualUser = game:GetService("VirtualUser")
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end
    end))
end)

trackConn(UserInputService.JumpRequest:Connect(function()
    if Config.InfiniteJump then
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end))

local GuiParent = CoreGui
pcall(function()
    if gethui then
        GuiParent = gethui()
    end
end)

local oldGui = GuiParent:FindFirstChild("MonUniversalHubGui")
if oldGui then
    oldGui:Destroy()
end

local oldEspFolder = GuiParent:FindFirstChild("MonUniversalESP")
if oldEspFolder then
    oldEspFolder:Destroy()
end

local EspFolder = Instance.new("Folder")
EspFolder.Name = "MonUniversalESP"
pcall(function()
    EspFolder.Parent = GuiParent
end)
if not EspFolder.Parent then
    EspFolder.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

local WaypointFolder = Workspace:FindFirstChild("MonUniversalWaypoints")
if WaypointFolder then
    WaypointFolder:Destroy()
end
WaypointFolder = Instance.new("Folder")
WaypointFolder.Name = "MonUniversalWaypoints"
WaypointFolder.Parent = Workspace

local EspObjects = {}
local WaypointVisuals = {}

local function clearPlayerESP()
    for plr, data in pairs(EspObjects) do
        if data.Highlight then pcall(function() data.Highlight:Destroy() end) end
        if data.Billboard then pcall(function() data.Billboard:Destroy() end) end
        EspObjects[plr] = nil
    end
end

local function clearWaypointESP()
    for idx, data in pairs(WaypointVisuals) do
        if data.Part then pcall(function() data.Part:Destroy() end) end
        if data.Billboard then pcall(function() data.Billboard:Destroy() end) end
        WaypointVisuals[idx] = nil
    end
    for _, child in ipairs(WaypointFolder:GetChildren()) do
        pcall(function() child:Destroy() end)
    end
end

local WAYPOINT_COLORS = {
    Color3.fromRGB(0, 225, 255),
    Color3.fromRGB(0, 255, 150),
    Color3.fromRGB(255, 195, 40),
    Color3.fromRGB(215, 110, 255),
    Color3.fromRGB(255, 95, 120)
}

local function rebuildWaypointESP()
    clearWaypointESP()
    if not Config.WaypointESP then
        return
    end

    for idx, entry in ipairs(Config.SavedPositions) do
        local color = WAYPOINT_COLORS[((idx - 1) % #WAYPOINT_COLORS) + 1]
        local pos = Vector3.new(entry.X or 0, entry.Y or 0, entry.Z or 0)

        local markerPart = Instance.new("Part")
        markerPart.Name = "WaypointCube_" .. tostring(idx)
        markerPart.Size = Vector3.new(3.2, 3.2, 3.2)
        markerPart.Position = pos
        markerPart.Anchored = true
        markerPart.CanCollide = false
        markerPart.CanQuery = false
        markerPart.CanTouch = false
        markerPart.CastShadow = false
        markerPart.Material = Enum.Material.Neon
        markerPart.Color = color
        markerPart.Transparency = 0.45
        markerPart.Parent = WaypointFolder

        local selBox = Instance.new("SelectionBox")
        selBox.Adornee = markerPart
        selBox.Color3 = color
        selBox.LineThickness = 0.06
        selBox.SurfaceTransparency = 0.75
        selBox.SurfaceColor3 = color
        selBox.Parent = markerPart

        local hl = Instance.new("Highlight")
        hl.Adornee = markerPart
        hl.FillColor = color
        hl.OutlineColor = Color3.new(1, 1, 1)
        hl.FillTransparency = 0.5
        hl.OutlineTransparency = 0
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Parent = markerPart

        local bb = Instance.new("BillboardGui")
        bb.Name = "WaypointTag_" .. tostring(idx)
        bb.Adornee = markerPart
        bb.Size = UDim2.new(0, 200, 0, 44)
        bb.StudsOffset = Vector3.new(0, 2.8, 0)
        bb.AlwaysOnTop = true
        bb.Parent = EspFolder

        local lbl = Instance.new("TextLabel")
        lbl.Name = "TagLabel"
        lbl.Size = UDim2.new(1, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.TextColor3 = color
        lbl.TextStrokeTransparency = 0
        lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        lbl.Font = Enum.Font.GothamBlack
        lbl.TextSize = 12
        lbl.Text = tostring(entry.Name or ("Spot #" .. idx))
        lbl.Parent = bb

        WaypointVisuals[idx] = {
            Part = markerPart,
            Billboard = bb,
            Label = lbl,
            Name = tostring(entry.Name or ("Spot #" .. idx)),
            Position = pos
        }
    end
end

local function updateWaypointDistances()
    if not Config.WaypointESP then return end
    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")

    for _, data in pairs(WaypointVisuals) do
        if data.Label and data.Label.Parent then
            if myRoot then
                local dist = math.floor((myRoot.Position - data.Position).Magnitude)
                data.Label.Text = string.format("[TP] %s\n(%dm)", data.Name, dist)
            else
                data.Label.Text = string.format("[TP] %s", data.Name)
            end
        end
    end
end

local function createOrUpdateESPForPlayer(plr)
    if plr == LocalPlayer or not Config.PlayerESP then
        if EspObjects[plr] then
            if EspObjects[plr].Highlight then pcall(function() EspObjects[plr].Highlight:Destroy() end) end
            if EspObjects[plr].Billboard then pcall(function() EspObjects[plr].Billboard:Destroy() end) end
            EspObjects[plr] = nil
        end
        return
    end

    local char = plr.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local head = char and char:FindFirstChild("Head")
    if not char or not root or not head then
        return
    end

    if not EspObjects[plr] then
        EspObjects[plr] = {}
    end

    local entry = EspObjects[plr]

    if not entry.Highlight or not entry.Highlight.Parent then
        local hl = Instance.new("Highlight")
        hl.Name = plr.Name .. "_ESP"
        hl.Adornee = char
        hl.FillColor = Color3.fromRGB(255, 75, 95)
        hl.OutlineColor = Color3.fromRGB(255, 225, 85)
        hl.FillTransparency = 0.55
        hl.OutlineTransparency = 0
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Parent = EspFolder
        entry.Highlight = hl
    end

    if not entry.Billboard or not entry.Billboard.Parent then
        local bb = Instance.new("BillboardGui")
        bb.Name = plr.Name .. "_Tag"
        bb.Adornee = head
        bb.Size = UDim2.new(0, 170, 0, 36)
        bb.StudsOffset = Vector3.new(0, 2.8, 0)
        bb.AlwaysOnTop = true
        bb.Parent = EspFolder

        local lbl = Instance.new("TextLabel")
        lbl.Name = "InfoLabel"
        lbl.Size = UDim2.new(1, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
        lbl.TextStrokeTransparency = 0
        lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 11
        lbl.Parent = bb

        entry.Billboard = bb
        entry.Label = lbl
    end

    if entry.Label then
        local myChar = LocalPlayer.Character
        local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
        local distText = ""
        if myRoot then
            local dist = math.floor((myRoot.Position - root.Position).Magnitude)
            distText = string.format(" [%dm]", dist)
        end
        entry.Label.Text = plr.DisplayName .. distText
    end
end

trackConn(Players.PlayerRemoving:Connect(function(plr)
    if EspObjects[plr] then
        if EspObjects[plr].Highlight then pcall(function() EspObjects[plr].Highlight:Destroy() end) end
        if EspObjects[plr].Billboard then pcall(function() EspObjects[plr].Billboard:Destroy() end) end
        EspObjects[plr] = nil
    end
end))

local flyBodyGyro = nil
local flyBodyVelocity = nil

local function stopFly()
    if flyBodyGyro then pcall(function() flyBodyGyro:Destroy() end) flyBodyGyro = nil end
    if flyBodyVelocity then pcall(function() flyBodyVelocity:Destroy() end) flyBodyVelocity = nil end
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        pcall(function() hum.PlatformStand = false end)
    end
end

local function ensureFlyObjects(root)
    if not flyBodyGyro or not flyBodyGyro.Parent then
        flyBodyGyro = Instance.new("BodyGyro")
        flyBodyGyro.P = 9e4
        flyBodyGyro.maxTorque = Vector3.new(9e9, 9e9, 9e9)
        flyBodyGyro.cframe = root.CFrame
        flyBodyGyro.Parent = root
    end
    if not flyBodyVelocity or not flyBodyVelocity.Parent then
        flyBodyVelocity = Instance.new("BodyVelocity")
        flyBodyVelocity.velocity = Vector3.new(0, 0, 0)
        flyBodyVelocity.maxForce = Vector3.new(9e9, 9e9, 9e9)
        flyBodyVelocity.Parent = root
    end
end

local mouse = LocalPlayer:GetMouse()
trackConn(mouse.Button1Down:Connect(function()
    if not Config.CtrlClickTP then return end
    if UserInputService:GetFocusedTextBox() then return end

    local isCtrlHeld = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
    if not isCtrlHeld then return end

    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if mouse and mouse.Hit and root then
        pcall(function()
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end)
        root.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0, 3, 0))
    end
end))

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MonUniversalHubGui"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function()
    screenGui.Parent = GuiParent
end)
if not screenGui.Parent then
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

local BG = Color3.fromRGB(11, 14, 26)
local CARD = Color3.fromRGB(20, 26, 46)
local SUBCARD = Color3.fromRGB(14, 19, 34)
local ACCENT = Color3.fromRGB(0, 195, 255)
local TEXT_MAIN = Color3.fromRGB(240, 246, 255)
local TEXT_DIM = Color3.fromRGB(145, 162, 195)

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 620, 0, 450)
mainFrame.Position = UDim2.new(0.5, -310, 0.15, 0)
mainFrame.BackgroundColor3 = BG
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Visible = Config.MenuVisible
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 8)
mainCorner.Parent = mainFrame

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = ACCENT
mainStroke.Thickness = 1.5
mainStroke.Transparency = 0.25
mainStroke.Parent = mainFrame

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 42)
header.BackgroundColor3 = CARD
header.BorderSizePixel = 0
header.Parent = mainFrame

local headerCorner = Instance.new("UICorner")
headerCorner.CornerRadius = UDim.new(0, 8)
headerCorner.Parent = header

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(0, 175, 1, 0)
titleLabel.Position = UDim2.new(0, 14, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "MON UNIVERSAL HUB"
titleLabel.TextColor3 = TEXT_MAIN
titleLabel.Font = Enum.Font.GothamBlack
titleLabel.TextSize = 13
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = header

local tabRow = Instance.new("Frame")
tabRow.Size = UDim2.new(0, 396, 0, 28)
tabRow.Position = UDim2.new(1, -438, 0.5, -14)
tabRow.BackgroundTransparency = 1
tabRow.Parent = header

local function makeTabBtn(text, xPos, width)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, width, 1, 0)
    b.Position = UDim2.new(0, xPos, 0, 0)
    b.BackgroundColor3 = SUBCARD
    b.Text = text
    b.TextColor3 = TEXT_MAIN
    b.Font = Enum.Font.GothamBold
    b.TextSize = 10
    b.AutoButtonColor = false
    b.Parent = tabRow

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 5)
    c.Parent = b

    local s = Instance.new("UIStroke")
    s.Color = ACCENT
    s.Thickness = 1
    s.Transparency = 0.5
    s.Parent = b
    return b
end

local tabPlayerBtn = makeTabBtn("1. PLAYER", 0, 90)
local tabMapBtn = makeTabBtn("2. MAP", 96, 84)
local tabTeleportBtn = makeTabBtn("3. TELEPORT", 186, 102)
local tabMiscBtn = makeTabBtn("4. MISC", 294, 102)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 28, 0, 28)
closeBtn.Position = UDim2.new(1, -36, 0.5, -14)
closeBtn.BackgroundColor3 = Color3.fromRGB(165, 45, 55)
closeBtn.Text = "X"
closeBtn.TextColor3 = TEXT_MAIN
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 12
closeBtn.Parent = header

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 5)
closeCorner.Parent = closeBtn

local function createPageFrame()
    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, -20, 1, -54)
    page.Position = UDim2.new(0, 10, 0, 48)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 3
    page.ScrollBarImageColor3 = ACCENT
    page.CanvasSize = UDim2.new(0, 0, 0, 0)
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.Visible = false
    page.Parent = mainFrame

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 7)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = page

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 2)
    pad.PaddingBottom = UDim.new(0, 8)
    pad.PaddingRight = UDim.new(0, 4)
    pad.Parent = page

    return page
end

local pagePlayer = createPageFrame()
local pageMap = createPageFrame()
local pageTeleport = createPageFrame()
local pageMisc = createPageFrame()

local function selectTab(tabName)
    pagePlayer.Visible = (tabName == "player")
    pageMap.Visible = (tabName == "map")
    pageTeleport.Visible = (tabName == "teleport")
    pageMisc.Visible = (tabName == "misc")

    tabPlayerBtn.BackgroundColor3 = (tabName == "player") and Color3.fromRGB(0, 130, 190) or SUBCARD
    tabMapBtn.BackgroundColor3 = (tabName == "map") and Color3.fromRGB(0, 130, 190) or SUBCARD
    tabTeleportBtn.BackgroundColor3 = (tabName == "teleport") and Color3.fromRGB(0, 130, 190) or SUBCARD
    tabMiscBtn.BackgroundColor3 = (tabName == "misc") and Color3.fromRGB(0, 130, 190) or SUBCARD
end

tabPlayerBtn.MouseButton1Click:Connect(function() selectTab("player") end)
tabMapBtn.MouseButton1Click:Connect(function() selectTab("map") end)
tabTeleportBtn.MouseButton1Click:Connect(function() selectTab("teleport") end)
tabMiscBtn.MouseButton1Click:Connect(function() selectTab("misc") end)

local function addSectionHeader(parent, order, text)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 0, 22)
    lbl.LayoutOrder = order
    lbl.BackgroundTransparency = 1
    lbl.Text = "  " .. text
    lbl.TextColor3 = ACCENT
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = parent
end

local function addToggleRow(parent, order, labelStr, keyName, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 36)
    row.LayoutOrder = order
    row.BackgroundColor3 = CARD
    row.BorderSizePixel = 0
    row.Parent = parent

    local rc = Instance.new("UICorner")
    rc.CornerRadius = UDim.new(0, 6)
    rc.Parent = row

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -80, 1, 0)
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelStr
    lbl.TextColor3 = TEXT_MAIN
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 56, 0, 24)
    btn.Position = UDim2.new(1, -66, 0.5, -12)
    btn.TextColor3 = TEXT_MAIN
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 10
    btn.Parent = row

    local bc = Instance.new("UICorner")
    bc.CornerRadius = UDim.new(0, 5)
    bc.Parent = btn

    local function refresh()
        local on = Config[keyName] == true
        btn.Text = on and "ON" or "OFF"
        btn.BackgroundColor3 = on and Color3.fromRGB(0, 175, 105) or Color3.fromRGB(155, 45, 55)
    end

    refresh()

    btn.MouseButton1Click:Connect(function()
        Config[keyName] = not (Config[keyName] == true)
        refresh()
        saveConfig()
        if callback then
            callback(Config[keyName])
        end
    end)
end

local function addInputRow(parent, order, labelStr, keyName, placeholderText)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 36)
    row.LayoutOrder = order
    row.BackgroundColor3 = CARD
    row.BorderSizePixel = 0
    row.Parent = parent

    local rc = Instance.new("UICorner")
    rc.CornerRadius = UDim.new(0, 6)
    rc.Parent = row

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.60, -10, 1, 0)
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelStr
    lbl.TextColor3 = TEXT_MAIN
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0.36, -10, 0, 24)
    box.Position = UDim2.new(0.62, 0, 0.5, -12)
    box.BackgroundColor3 = SUBCARD
    box.Text = tostring(Config[keyName] or "")
    box.PlaceholderText = placeholderText or ""
    box.PlaceholderColor3 = TEXT_DIM
    box.TextColor3 = TEXT_MAIN
    box.Font = Enum.Font.GothamSemibold
    box.TextSize = 11
    box.ClearTextOnFocus = false
    box.Parent = row

    local bc = Instance.new("UICorner")
    bc.CornerRadius = UDim.new(0, 5)
    bc.Parent = box

    local bs = Instance.new("UIStroke")
    bs.Color = Color3.fromRGB(45, 65, 100)
    bs.Thickness = 1
    bs.Parent = box

    box.FocusLost:Connect(function()
        local num = tonumber(box.Text)
        if num and num > 0 then
            Config[keyName] = num
            box.Text = tostring(num)
            saveConfig()
        else
            box.Text = tostring(Config[keyName])
        end
    end)
end

local function addActionRow(parent, order, labelStr, btnText, btnColor, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 36)
    row.LayoutOrder = order
    row.BackgroundColor3 = CARD
    row.BorderSizePixel = 0
    row.Parent = parent

    local rc = Instance.new("UICorner")
    rc.CornerRadius = UDim.new(0, 6)
    rc.Parent = row

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0.62, -10, 1, 0)
    lbl.Position = UDim2.new(0, 12, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelStr
    lbl.TextColor3 = TEXT_MAIN
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.34, -10, 0, 24)
    btn.Position = UDim2.new(0.64, 0, 0.5, -12)
    btn.BackgroundColor3 = btnColor
    btn.Text = btnText
    btn.TextColor3 = TEXT_MAIN
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 10
    btn.Parent = row

    local bc = Instance.new("UICorner")
    bc.CornerRadius = UDim.new(0, 5)
    bc.Parent = btn

    btn.MouseButton1Click:Connect(callback)
    return btn, lbl
end

addSectionHeader(pagePlayer, 1, "MOVEMENT & FLIGHT")
addToggleRow(pagePlayer, 2, "Speed (ON = Apply Value, OFF = Default)", "WalkSpeedEnabled", function(enabled)
    if not enabled then
        restoreWalkSpeed()
    end
end)
addInputRow(pagePlayer, 3, "Speed Value", "WalkSpeedValue", "28")

addToggleRow(pagePlayer, 4, "Jump (ON = Apply Value, OFF = Default)", "JumpPowerEnabled", function(enabled)
    if not enabled then
        restoreJumpPower()
    end
end)
addInputRow(pagePlayer, 5, "Jump Value", "JumpPowerValue", "75")
addToggleRow(pagePlayer, 6, "Infinite Jump", "InfiniteJump", nil)

addToggleRow(pagePlayer, 7, "Fly (WASD + Space/Ctrl)", "FlyEnabled", function(enabled)
    if not enabled then
        stopFly()
    end
end)
addInputRow(pagePlayer, 8, "Fly Speed", "FlySpeed", "60")

addSectionHeader(pageMap, 1, "WORLD & VISUALS")
addToggleRow(pageMap, 2, "Player ESP (Highlight + Name + Distance)", "PlayerESP", function(enabled)
    if not enabled then
        clearPlayerESP()
    end
end)
addToggleRow(pageMap, 3, "Fullbright", "FullBright", applyFullBright)
addToggleRow(pageMap, 4, "NoClip", "NoClip", nil)
addToggleRow(pageMap, 5, "Remove Fog", "RemoveFog", applyRemoveFog)

addSectionHeader(pageTeleport, 1, "QUICK TELEPORT & WAYPOINT ESP")
addToggleRow(pageTeleport, 2, "Teleport Click (Hold Ctrl + Left Click)", "CtrlClickTP", nil)
addToggleRow(pageTeleport, 3, "Teleport ESP (3D Marker + Name)", "WaypointESP", function()
    rebuildWaypointESP()
end)

addSectionHeader(pageTeleport, 4, "SAVED LOCATIONS")

local createPosCard = Instance.new("Frame")
createPosCard.Size = UDim2.new(1, 0, 0, 42)
createPosCard.LayoutOrder = 5
createPosCard.BackgroundColor3 = CARD
createPosCard.BorderSizePixel = 0
createPosCard.Parent = pageTeleport

local cpcCorner = Instance.new("UICorner")
cpcCorner.CornerRadius = UDim.new(0, 6)
cpcCorner.Parent = createPosCard

local posNameInput = Instance.new("TextBox")
posNameInput.Size = UDim2.new(0.66, -12, 0, 28)
posNameInput.Position = UDim2.new(0, 10, 0.5, -14)
posNameInput.BackgroundColor3 = SUBCARD
posNameInput.Text = ""
posNameInput.PlaceholderText = "Location name (e.g. home 1)..."
posNameInput.PlaceholderColor3 = TEXT_DIM
posNameInput.TextColor3 = TEXT_MAIN
posNameInput.Font = Enum.Font.Gotham
posNameInput.TextSize = 11
posNameInput.ClearTextOnFocus = false
posNameInput.Parent = createPosCard

local pniCorner = Instance.new("UICorner")
pniCorner.CornerRadius = UDim.new(0, 5)
pniCorner.Parent = posNameInput

local pniStroke = Instance.new("UIStroke")
pniStroke.Color = Color3.fromRGB(45, 65, 100)
pniStroke.Thickness = 1
pniStroke.Parent = posNameInput

local savePosBtn = Instance.new("TextButton")
savePosBtn.Size = UDim2.new(0.32, -8, 0, 28)
savePosBtn.Position = UDim2.new(0.68, 0, 0.5, -14)
savePosBtn.BackgroundColor3 = Color3.fromRGB(0, 165, 115)
savePosBtn.Text = "+ SAVE POS"
savePosBtn.TextColor3 = TEXT_MAIN
savePosBtn.Font = Enum.Font.GothamBold
savePosBtn.TextSize = 10
savePosBtn.Parent = createPosCard

local spbCorner = Instance.new("UICorner")
spbCorner.CornerRadius = UDim.new(0, 5)
spbCorner.Parent = savePosBtn

local savedListFrame = Instance.new("Frame")
savedListFrame.Size = UDim2.new(1, 0, 0, 0)
savedListFrame.AutomaticSize = Enum.AutomaticSize.Y
savedListFrame.LayoutOrder = 6
savedListFrame.BackgroundTransparency = 1
savedListFrame.Parent = pageTeleport

local savedListLayout = Instance.new("UIListLayout")
savedListLayout.Padding = UDim.new(0, 5)
savedListLayout.SortOrder = Enum.SortOrder.LayoutOrder
savedListLayout.Parent = savedListFrame

local function teleportToCoords(x, y, z)
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root then
        pcall(function()
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end)
        root.CFrame = CFrame.new(Vector3.new(x, y + 1.5, z))
    end
end

local function rebuildSavedPositionsList()
    for _, child in ipairs(savedListFrame:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextLabel") then
            child:Destroy()
        end
    end

    if #Config.SavedPositions == 0 then
        local emptyLbl = Instance.new("TextLabel")
        emptyLbl.Size = UDim2.new(1, 0, 0, 32)
        emptyLbl.BackgroundColor3 = SUBCARD
        emptyLbl.Text = "No saved positions yet. Enter a name and click '+ SAVE POS'."
        emptyLbl.TextColor3 = TEXT_DIM
        emptyLbl.Font = Enum.Font.Gotham
        emptyLbl.TextSize = 10
        emptyLbl.Parent = savedListFrame

        local ec = Instance.new("UICorner")
        ec.CornerRadius = UDim.new(0, 5)
        ec.Parent = emptyLbl
        rebuildWaypointESP()
        return
    end

    for idx, entry in ipairs(Config.SavedPositions) do
        local itemRow = Instance.new("Frame")
        itemRow.Size = UDim2.new(1, 0, 0, 36)
        itemRow.LayoutOrder = idx
        itemRow.BackgroundColor3 = CARD
        itemRow.BorderSizePixel = 0
        itemRow.Parent = savedListFrame

        local irc = Instance.new("UICorner")
        irc.CornerRadius = UDim.new(0, 6)
        irc.Parent = itemRow

        local colorBadge = Instance.new("Frame")
        colorBadge.Size = UDim2.new(0, 8, 0, 20)
        colorBadge.Position = UDim2.new(0, 6, 0.5, -10)
        colorBadge.BackgroundColor3 = WAYPOINT_COLORS[((idx - 1) % #WAYPOINT_COLORS) + 1]
        colorBadge.BorderSizePixel = 0
        colorBadge.Parent = itemRow

        local cbc = Instance.new("UICorner")
        cbc.CornerRadius = UDim.new(0, 3)
        cbc.Parent = colorBadge

        local infoLbl = Instance.new("TextLabel")
        infoLbl.Size = UDim2.new(1, -165, 1, 0)
        infoLbl.Position = UDim2.new(0, 20, 0, 0)
        infoLbl.BackgroundTransparency = 1
        infoLbl.Text = string.format("%d. %s  (%.0f, %.0f, %.0f)", idx, entry.Name or "Spot", entry.X or 0, entry.Y or 0, entry.Z or 0)
        infoLbl.TextColor3 = TEXT_MAIN
        infoLbl.Font = Enum.Font.GothamSemibold
        infoLbl.TextSize = 11
        infoLbl.TextXAlignment = Enum.TextXAlignment.Left
        infoLbl.TextTruncate = Enum.TextTruncate.AtEnd
        infoLbl.Parent = itemRow

        local tpBtn = Instance.new("TextButton")
        tpBtn.Size = UDim2.new(0, 74, 0, 24)
        tpBtn.Position = UDim2.new(1, -142, 0.5, -12)
        tpBtn.BackgroundColor3 = Color3.fromRGB(45, 115, 220)
        tpBtn.Text = "TELEPORT"
        tpBtn.TextColor3 = TEXT_MAIN
        tpBtn.Font = Enum.Font.GothamBold
        tpBtn.TextSize = 10
        tpBtn.Parent = itemRow

        local tpc = Instance.new("UICorner")
        tpc.CornerRadius = UDim.new(0, 5)
        tpc.Parent = tpBtn

        local delBtn = Instance.new("TextButton")
        delBtn.Size = UDim2.new(0, 54, 0, 24)
        delBtn.Position = UDim2.new(1, -62, 0.5, -12)
        delBtn.BackgroundColor3 = Color3.fromRGB(165, 50, 60)
        delBtn.Text = "DELETE"
        delBtn.TextColor3 = TEXT_MAIN
        delBtn.Font = Enum.Font.GothamBold
        delBtn.TextSize = 10
        delBtn.Parent = itemRow

        local dc = Instance.new("UICorner")
        dc.CornerRadius = UDim.new(0, 5)
        dc.Parent = delBtn

        tpBtn.MouseButton1Click:Connect(function()
            teleportToCoords(entry.X, entry.Y, entry.Z)
        end)

        delBtn.MouseButton1Click:Connect(function()
            table.remove(Config.SavedPositions, idx)
            saveConfig()
            rebuildSavedPositionsList()
        end)
    end

    rebuildWaypointESP()
end

savePosBtn.MouseButton1Click:Connect(function()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local pos = root.Position
    local customName = posNameInput.Text:match("^%s*(.-)%s*$")
    if customName == "" then
        customName = "Spot #" .. tostring(#Config.SavedPositions + 1)
    end

    table.insert(Config.SavedPositions, {
        Name = customName,
        X = math.floor(pos.X * 10) / 10,
        Y = math.floor(pos.Y * 10) / 10,
        Z = math.floor(pos.Z * 10) / 10
    })

    posNameInput.Text = ""
    saveConfig()
    rebuildSavedPositionsList()
end)

rebuildSavedPositionsList()

local floatBtn = Instance.new("TextButton")
floatBtn.Size = UDim2.new(0, 44, 0, 44)
floatBtn.Position = UDim2.new(0.02, 0, 0.45, 0)
floatBtn.BackgroundColor3 = BG
floatBtn.Text = "M"
floatBtn.TextColor3 = ACCENT
floatBtn.Font = Enum.Font.GothamBlack
floatBtn.TextSize = 16
floatBtn.Active = true
floatBtn.Draggable = true
floatBtn.Visible = Config.ShowFloatingIcon == true
floatBtn.Parent = screenGui

local floatCorner = Instance.new("UICorner")
floatCorner.CornerRadius = UDim.new(1, 0)
floatCorner.Parent = floatBtn

local floatStroke = Instance.new("UIStroke")
floatStroke.Color = ACCENT
floatStroke.Thickness = 1.5
floatStroke.Parent = floatBtn

addSectionHeader(pageMisc, 1, "UTILITIES & UI CONTROLS")
addToggleRow(pageMisc, 2, "Anti AFK", "AntiAFK", nil)

addActionRow(pageMisc, 3, "Respawn Character", "RESPAWN", Color3.fromRGB(165, 95, 35), function()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.Health = 0
    end
end)

addToggleRow(pageMisc, 4, "UI Toggle Hotkey (Enable/Disable Keybind)", "HotkeyEnabled", nil)

addToggleRow(pageMisc, 5, "Show Floating Icon (M Button)", "ShowFloatingIcon", function(enabled)
    floatBtn.Visible = enabled
end)

local awaitingKeyBind = false
local _, keyBindLbl = addActionRow(pageMisc, 6, "Current Hotkey: " .. tostring(Config.ToggleKey or "M"), "CHANGE KEY", Color3.fromRGB(55, 90, 195), function()
    awaitingKeyBind = true
    keyBindLbl.Text = "Press any key..."
end)

local function toggleMenu()
    mainFrame.Visible = not mainFrame.Visible
    Config.MenuVisible = mainFrame.Visible
    saveConfig()
end

closeBtn.MouseButton1Click:Connect(toggleMenu)
floatBtn.MouseButton1Click:Connect(toggleMenu)

trackConn(UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if awaitingKeyBind then
        if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode ~= Enum.KeyCode.Unknown then
            Config.ToggleKey = input.KeyCode.Name
            awaitingKeyBind = false
            keyBindLbl.Text = "Current Hotkey: " .. Config.ToggleKey
            saveConfig()
        end
        return
    end

    if UserInputService:GetFocusedTextBox() then
        return
    end

    if Config.HotkeyEnabled == true and input.UserInputType == Enum.UserInputType.Keyboard then
        local targetKeyCode = Enum.KeyCode[tostring(Config.ToggleKey)]
        if (targetKeyCode and input.KeyCode == targetKeyCode) or input.KeyCode.Name == tostring(Config.ToggleKey) then
            toggleMenu()
        end
    end
end))

selectTab("player")

trackConn(LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.3)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        captureHumanoidDefaults(hum)
    end
end))

do
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        captureHumanoidDefaults(hum)
    end
end

trackConn(RunService.Stepped:Connect(function()
    local char = LocalPlayer.Character
    if not char then return end

    if Config.NoClip or Config.FlyEnabled then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        if Config.WalkSpeedEnabled then
            hum.WalkSpeed = tonumber(Config.WalkSpeedValue) or 16
            wasSpeedEnabled = true
        elseif wasSpeedEnabled then
            wasSpeedEnabled = false
            hum.WalkSpeed = DefaultWalkSpeed or 16
        end

        if Config.JumpPowerEnabled then
            hum.UseJumpPower = true
            hum.JumpPower = tonumber(Config.JumpPowerValue) or 50
            wasJumpEnabled = true
        elseif wasJumpEnabled then
            wasJumpEnabled = false
            if hum.UseJumpPower then
                hum.JumpPower = DefaultJumpPower or 50
            else
                hum.JumpHeight = DefaultJumpPower or 7.2
            end
        end
    end
end))

trackConn(RunService.RenderStepped:Connect(function()
    if Config.FlyEnabled then
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local cam = Workspace.CurrentCamera
        if root and hum and cam then
            hum.PlatformStand = true
            ensureFlyObjects(root)

            local moveDir = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then
                moveDir = moveDir + cam.CFrame.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then
                moveDir = moveDir - cam.CFrame.LookVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then
                moveDir = moveDir - cam.CFrame.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then
                moveDir = moveDir + cam.CFrame.RightVector
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                moveDir = moveDir + Vector3.new(0, 1, 0)
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.C) then
                moveDir = moveDir - Vector3.new(0, 1, 0)
            end

            local speed = tonumber(Config.FlySpeed) or 60
            if moveDir.Magnitude > 0 then
                flyBodyVelocity.velocity = moveDir.Unit * speed
            else
                flyBodyVelocity.velocity = Vector3.zero
            end
            flyBodyGyro.cframe = cam.CFrame
        end
    else
        if flyBodyGyro or flyBodyVelocity then
            stopFly()
        end
    end

    if Config.PlayerESP then
        for _, plr in ipairs(Players:GetPlayers()) do
            pcall(function()
                createOrUpdateESPForPlayer(plr)
            end)
        end
    end

    if Config.WaypointESP then
        updateWaypointDistances()
    end
end))
