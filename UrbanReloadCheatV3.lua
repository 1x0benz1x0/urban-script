-- Urban Reload cheat v3 (Rayfield)
-- tabs: Combat, ESP, Teleport

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")

local LP = Players.LocalPlayer

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
    Name = "Urban Reload - Cheat v3",
    LoadingTitle = "Urban Reload",
    LoadingSubtitle = "wz11",
    ConfigurationSaving = { Enabled = true, FolderName = "UrbanReloadCheat", FileName = "ConfigV3" },
    Discord = { Enabled = false },
    KeySystem = false
})

local function notify(title, content)
    pcall(function() Rayfield:Notify({Title=title, Content=content, Duration=4}) end)
end

--// weapon config patch
local function weaponsFolder()
    local w = ReplicatedStorage:FindFirstChild("Weapons")
    return w
end

local function patchWeaponConfig()
    pcall(function()
        local w = weaponsFolder()
        local cfg = w and w:FindFirstChild("Config")
        if cfg then
            local mod = require(cfg)
            if mod and mod.Global then
                setreadonly(mod.Global,false)
                mod.Global.BloomScale = 0
                mod.Global.InfiniteAmmo = true
            end
        end
    end)
end
patchWeaponConfig()

--// state
local spinbot = false
local spinbotHum = nil
local spinSpeed = 10
local spinAngle = 0
local fullbright = false

local LightingDefaults = {
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    FogEnd = Lighting.FogEnd,
    GlobalShadows = Lighting.GlobalShadows,
}

--// helpers
local function getHrp()
    local char = LP.Character
    return char and char:FindFirstChild("HumanoidRootPart") or nil
end

local function applyFullbright(enabled)
    pcall(function()
        if enabled then
            Lighting.Brightness = 2
            Lighting.ClockTime = 12
            Lighting.GlobalShadows = false
            Lighting.Ambient = Color3.fromRGB(180,180,180)
            Lighting.OutdoorAmbient = Color3.fromRGB(180,180,180)
            Lighting.FogEnd = 1e6
        else
            Lighting.Brightness = LightingDefaults.Brightness
            Lighting.ClockTime = LightingDefaults.ClockTime
            Lighting.GlobalShadows = LightingDefaults.GlobalShadows
            Lighting.Ambient = LightingDefaults.Ambient
            Lighting.OutdoorAmbient = LightingDefaults.OutdoorAmbient
            Lighting.FogEnd = LightingDefaults.FogEnd
        end
    end)
end

-- loops: each start gets a token so a stop/start can never leave two copies running
local loopTokens = {}
local function startLoop(key, interval, fn)
    if loopTokens[key] then return end
    local token = {}
    loopTokens[key] = token
    task.spawn(function()
        while loopTokens[key] == token do
            pcall(fn)
            task.wait(interval)
        end
    end)
end
local function stopLoop(key)
    loopTokens[key] = nil
end

--// ESP
local ESP = {
    Enabled = false,
    Players = true,
    Vehicles = false,
    Style = "Highlight",
    ShowName = true,
    ShowHealth = true,
    ShowDistance = true,
    TeamColors = true,
    Tracers = false,
    Boxes = false,
    playerEntries = {},
    vehicleEntries = {},
    gui = nil,
}

local function espGui()
    if ESP.gui and ESP.gui.Parent then return ESP.gui end
    ESP.gui = nil
    local pg = LP:FindFirstChildOfClass("PlayerGui")
    if not pg then return nil end
    local gui = Instance.new("ScreenGui")
    gui.Name = "UrbanReloadESP"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = pg
    ESP.gui = gui
    return gui
end

local function espColor(plr)
    if ESP.TeamColors and plr and plr.Team then
        return plr.Team.TeamColor.Color
    end
    return Color3.fromRGB(255,60,60)
end

local function makeLabel(adornee, offset, width, height, textSize)
    if not adornee then return nil, nil end
    local bb = Instance.new("BillboardGui")
    bb.Name = "UrbanReloadLabel"
    bb.Size = UDim2.new(0,width,0,height)
    bb.StudsOffset = offset
    bb.AlwaysOnTop = true
    bb.Parent = adornee
    local txt = Instance.new("TextLabel")
    txt.Size = UDim2.new(1,0,1,0)
    txt.BackgroundTransparency = 1
    txt.TextColor3 = Color3.new(1,1,1)
    txt.TextStrokeTransparency = 0
    txt.Font = Enum.Font.GothamBold
    txt.TextSize = textSize
    txt.Text = ""
    txt.Parent = bb
    return bb, txt
end

local function makeBoxFrame()
    local gui = espGui()
    if not gui then return nil end
    local f = Instance.new("Frame")
    f.Name = "UrbanReloadBox"
    f.AnchorPoint = Vector2.new(0,0)
    f.BackgroundTransparency = 1
    f.BorderSizePixel = 0
    f.Visible = false
    f.ZIndex = 2
    -- a UIStroke outline scales cleanly; BorderSizePixel stays 1px and washes out
    local stroke = Instance.new("UIStroke")
    stroke.Name = "Outline"
    stroke.Thickness = 1.5
    stroke.Color = Color3.fromRGB(255,60,60)
    stroke.Parent = f
    f.Parent = gui
    return f
end

local function makeTracerFrame()
    local gui = espGui()
    if not gui then return nil end
    local f = Instance.new("Frame")
    f.Name = "UrbanReloadTracer"
    -- centred anchor: a Frame rotates around its centre, so a left-anchored line
    -- sweeps around the wrong pivot and never lands on the target
    f.AnchorPoint = Vector2.new(0.5,0.5)
    f.BorderSizePixel = 0
    f.BackgroundColor3 = Color3.fromRGB(255,60,60)
    f.Visible = false
    f.ZIndex = 3
    f.Parent = gui
    return f
end

local function destroyEntry(entry)
    if not entry then return end
    for _,obj in ipairs(entry.objects or {}) do
        pcall(function() obj:Destroy() end)
    end
    entry.objects = nil
end

local function buildPlayerEntry(plr, char)
    local entry = {char = char, objects = {}}
    if ESP.Style == "Highlight" then
        local h = Instance.new("Highlight")
        h.Name = "UrbanReloadHL"
        h.FillTransparency = 0.5
        h.OutlineColor = Color3.new(1,1,1)
        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        h.Parent = char
        entry.hl = h
        table.insert(entry.objects, h)
    end
    local head = char:FindFirstChild("Head")
    local bb, txt = makeLabel(head, Vector3.new(0,2.6,0), 170, 20, 12)
    entry.labelBg, entry.label = bb, txt
    if bb then table.insert(entry.objects, bb) end
    if ESP.Boxes then
        entry.box = makeBoxFrame()
        if entry.box then table.insert(entry.objects, entry.box) end
    end
    if ESP.Tracers then
        entry.tracer = makeTracerFrame()
        if entry.tracer then table.insert(entry.objects, entry.tracer) end
    end
    ESP.playerEntries[plr] = entry
    return entry
end

local function buildVehicleEntry(model)
    local anchor = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
    if not anchor then return nil end
    local entry = {model = model, anchor = anchor, objects = {}}
    local color = Color3.fromRGB(255,200,0)
    if ESP.Style == "Highlight" then
        local h = Instance.new("Highlight")
        h.Name = "UrbanReloadHL"
        h.FillColor = color
        h.FillTransparency = 0.6
        h.OutlineColor = color
        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        h.Parent = model
        entry.hl = h
        table.insert(entry.objects, h)
    end
    local bb, txt = makeLabel(anchor, Vector3.new(0,3,0), 140, 20, 12)
    entry.labelBg, entry.label = bb, txt
    if bb then table.insert(entry.objects, bb) end
    ESP.vehicleEntries[model] = entry
    return entry
end

local function clearESP()
    for plr,e in pairs(ESP.playerEntries) do
        destroyEntry(e)
        ESP.playerEntries[plr] = nil
    end
    for model,e in pairs(ESP.vehicleEntries) do
        destroyEntry(e)
        ESP.vehicleEntries[model] = nil
    end
    if ESP.gui then
        pcall(function() ESP.gui:Destroy() end)
        ESP.gui = nil
    end
end

local function refreshESP()
    clearESP()
    if not ESP.Enabled then return end
    if ESP.Players then
        for _,plr in ipairs(Players:GetPlayers()) do
            local char = plr.Character
            if plr ~= LP and char and char.Parent and char:FindFirstChild("HumanoidRootPart") then
                buildPlayerEntry(plr, char)
            end
        end
    end
    if ESP.Vehicles then
        for _,model in ipairs(CollectionService:GetTagged("Vehicle")) do
            pcall(function() buildVehicleEntry(model) end)
        end
    end
end

-- keep the ESP in sync without rebuilding it every frame
local function reconcileESP()
    if not ESP.Enabled then return end
    if ESP.Players then
        for _,plr in ipairs(Players:GetPlayers()) do
            if plr ~= LP then
                local char = plr.Character
                local entry = ESP.playerEntries[plr]
                local ready = char and char.Parent and char:FindFirstChild("HumanoidRootPart")
                if ready then
                    if entry and entry.char ~= char then
                        destroyEntry(entry)
                        ESP.playerEntries[plr] = nil
                        entry = nil
                    end
                    if not entry then buildPlayerEntry(plr, char) end
                elseif entry then
                    destroyEntry(entry)
                    ESP.playerEntries[plr] = nil
                end
            end
        end
    end
    for plr,entry in pairs(ESP.playerEntries) do
        if plr == LP or not plr.Parent or (ESP.Players and entry.char ~= plr.Character) then
            destroyEntry(entry)
            ESP.playerEntries[plr] = nil
        end
    end
    if ESP.Vehicles then
        for _,model in ipairs(CollectionService:GetTagged("Vehicle")) do
            if not ESP.vehicleEntries[model] and model.Parent then
                pcall(function() buildVehicleEntry(model) end)
            end
        end
    end
    for model,entry in pairs(ESP.vehicleEntries) do
        if not model.Parent or not ESP.Vehicles then
            destroyEntry(entry)
            ESP.vehicleEntries[model] = nil
        end
    end
end

-- Projects the eight corners of an oriented box and returns its screen rect. Corners
-- behind the camera are dropped, and a target that is only partly on screen still gets a
-- box, which the old head/HumanoidRootPart guess could not do.
local function projectBox(cam, cf, size)
    local minX, minY, maxX, maxY
    for i = 0, 7 do
        local sx = (i % 2 == 0) and -0.5 or 0.5
        local sy = (math.floor(i / 2) % 2 == 0) and -0.5 or 0.5
        local sz = (math.floor(i / 4) % 2 == 0) and -0.5 or 0.5
        local corner = cf * Vector3.new(sx * size.X, sy * size.Y, sz * size.Z)
        -- WorldToViewportPoint returns (Vector3, onScreen) - only two values. The depth
        -- is the Z of that vector; reading a third return gives nil and the comparison
        -- below would error on every frame, which is exactly what killed boxes/tracers.
        local screen = cam:WorldToViewportPoint(corner)
        if screen.Z > 0 then
            local x, y = screen.X, screen.Y
            if not minX or x < minX then minX = x end
            if not maxX or x > maxX then maxX = x end
            if not minY or y < minY then minY = y end
            if not maxY or y > maxY then maxY = y end
        end
    end
    if not minX then return nil end
    return minX, minY, maxX - minX, maxY - minY
end

-- World-space bounds of the character, cached briefly: the real numbers are only needed
-- to size the box, and walking animation makes them jitter frame to frame.
local function characterBox(char)
    local minV = Vector3.new(math.huge, math.huge, math.huge)
    local maxV = Vector3.new(-math.huge, -math.huge, -math.huge)
    local found = false
    for _, part in ipairs(char:GetChildren()) do
        if part:IsA("BasePart") then
            local p, half = part.Position, part.Size * 0.5
            minV = Vector3.new(math.min(minV.X, p.X - half.X), math.min(minV.Y, p.Y - half.Y), math.min(minV.Z, p.Z - half.Z))
            maxV = Vector3.new(math.max(maxV.X, p.X + half.X), math.max(maxV.Y, p.Y + half.Y), math.max(maxV.Z, p.Z + half.Z))
            found = true
        end
    end
    if not found then return nil end
    return minV, maxV
end

local function updatePlayerEntry(entry, plr)
    local char = entry.char
    if not char or not char.Parent then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local head = char:FindFirstChild("Head")
    if not hrp or not head then return false end

    local color = espColor(plr)
    if entry.hl then
        entry.hl.FillColor = color
        entry.hl.OutlineColor = Color3.new(1,1,1)
    end

    local cam = Workspace.CurrentCamera
    local myHrp = getHrp()
    local boxX, boxY, boxW, boxH
    if cam then
        -- Cache only the SIZE and the small vertical offset, never the centre: caching the
        -- centre made the box trail the player by up to half a second. The centre is rebuilt
        -- from the live root position every frame, so the box tracks the body exactly.
        if not entry.boxSize or (os.clock() - (entry.boxAt or 0)) > 0.25 then
            local minV, maxV = characterBox(char)
            if minV then
                entry.boxSize = maxV - minV
                entry.boxOffset = (minV + maxV) * 0.5 - hrp.Position
            end
            entry.boxAt = os.clock()
        end
        local center = hrp.Position + (entry.boxOffset or Vector3.zero)
        local size = entry.boxSize or Vector3.new(2.2, 5.2, 1.2)
        boxX, boxY, boxW, boxH = projectBox(cam, CFrame.new(center) * hrp.CFrame.Rotation, size)
    end

    if entry.label then
        local parts = {}
        if ESP.ShowName then table.insert(parts, plr.Name) end
        if ESP.ShowHealth and hum then table.insert(parts, math.floor(hum.Health) .. " hp") end
        if ESP.ShowDistance and myHrp then
            table.insert(parts, math.floor((hrp.Position-myHrp.Position).Magnitude) .. "m")
        end
        entry.label.Text = table.concat(parts, " | ")
        entry.label.TextColor3 = color
    end

    if entry.box then
        if boxX then
            entry.box.Visible = true
            entry.box.Position = UDim2.fromOffset(boxX, boxY)
            entry.box.Size = UDim2.fromOffset(math.max(boxW, 4), math.max(boxH, 4))
            local stroke = entry.box:FindFirstChild("Outline")
            if stroke then stroke.Color = color end
        else
            entry.box.Visible = false
        end
    end

    if entry.tracer then
        if boxX and cam then
            local vp = cam.ViewportSize
            local startX, startY = vp.X * 0.5, vp.Y
            local endX, endY = boxX + boxW * 0.5, boxY + boxH
            local dx, dy = endX - startX, endY - startY
            local length = math.sqrt(dx*dx + dy*dy)
            if length > 2 then
                entry.tracer.Visible = true
                -- draw centre-to-centre so the rotation pivots on the line itself
                entry.tracer.Position = UDim2.fromOffset((startX + endX) * 0.5, (startY + endY) * 0.5)
                entry.tracer.Size = UDim2.fromOffset(length, 1.5)
                entry.tracer.Rotation = math.deg(math.atan2(dy, dx))
                entry.tracer.BackgroundColor3 = color
            else
                entry.tracer.Visible = false
            end
        else
            entry.tracer.Visible = false
        end
    end
    return true
end

local function updateVehicleEntry(entry)
    local model = entry.model
    if not model or not model.Parent then return false end
    if entry.label then
        local parts = {model.Name}
        local myHrp = getHrp()
        if ESP.ShowDistance and myHrp and entry.anchor and entry.anchor.Parent then
            table.insert(parts, math.floor((entry.anchor.Position-myHrp.Position).Magnitude) .. "m")
        end
        entry.label.Text = table.concat(parts, " ")
        entry.label.TextColor3 = Color3.fromRGB(255,200,0)
    end
    return true
end

local espErrorShown = false
local function reportEspError(err)
    if espErrorShown then return end
    espErrorShown = true
    print("[UrbanReload] ESP update error: " .. tostring(err))
end

RunService.RenderStepped:Connect(function()
    if not ESP.Enabled then return end
    for plr,entry in pairs(ESP.playerEntries) do
        local ok, err = pcall(updatePlayerEntry, entry, plr)
        if not ok then reportEspError(err) end
    end
    for _,entry in pairs(ESP.vehicleEntries) do
        local ok, err = pcall(updateVehicleEntry, entry)
        if not ok then reportEspError(err) end
    end
end)

task.spawn(function()
    while true do
        if ESP.Enabled then pcall(reconcileESP) end
        task.wait(1)
    end
end)

--// Aimbot
local aimbotEnabled = false
local aimbotFOV = 150
local aimbotRMB = false
local aimbotVisibleCheck = true

-- the aim point is the head, so the crosshair ends up on the head instead of the chest
local function aimPart(plr)
    local char = plr.Character
    if not char then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return nil end
    return char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
end

-- raycast from the camera (where shots really start) to the part, ignoring only your
-- own character, so hats and other enemy parts do not count as walls
local function cameraSees(part)
    local cam = Workspace.CurrentCamera
    local myHrp = getHrp()
    local origin = (cam and cam.CFrame.Position) or (myHrp and myHrp.Position) or Vector3.zero
    local params = RaycastParams.new()
    local ignore = {}
    if LP.Character then table.insert(ignore, LP.Character) end
    params.FilterDescendantsInstances = ignore
    params.FilterType = Enum.RaycastFilterType.Exclude
    local res = Workspace:Raycast(origin, part.Position - origin, params)
    if res then
        return res.Instance == part or res.Instance:IsDescendantOf(part.Parent)
    end
    return true
end

local function isVisible(part)
    if not aimbotVisibleCheck then return true end
    return cameraSees(part)
end

local function getClosestEnemy(fov)
    local cam = Workspace.CurrentCamera
    if not cam then return nil end
    local center = Vector2.new(cam.ViewportSize.X/2, cam.ViewportSize.Y/2)
    local best, bestDist = nil, fov or aimbotFOV
    for _,plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP then
            local part = aimPart(plr)
            if part then
                local pos, onScreen = cam:WorldToViewportPoint(part.Position)
                if onScreen then
                    local d = (Vector2.new(pos.X,pos.Y)-center).Magnitude
                    if d < bestDist and isVisible(part) then
                        bestDist = d
                        best = part
                    end
                end
            end
        end
    end
    return best
end

local mouseMoverelWarned = false
RunService:BindToRenderStep("UrbanAimbot2", Enum.RenderPriority.Camera.Value + 1, function()
    if not aimbotEnabled then return end
    if aimbotRMB and not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then return end
    local part = getClosestEnemy()
    if not part then return end
    local cam = Workspace.CurrentCamera
    if not cam then return end

    -- Turn the camera-to-head angle into mouse pixels. Pixels per radian depends on the
    -- camera FOV, and unlike the old screen-offset math this does not assume the cursor
    -- sits at the screen centre, so it converges onto the head instead of drifting.
    local viewport = cam.ViewportSize
    if viewport.Y <= 0 then return end
    local pixelsPerRadian = (viewport.Y / 2) / math.tan(math.rad(cam.FieldOfView) / 2)
    local rel = cam.CFrame:PointToObjectSpace(part.Position)
    if rel.Z > -0.5 then return end -- head is behind the camera plane
    local yaw = math.atan2(rel.X, -rel.Z)
    local pitch = math.atan2(rel.Y, math.sqrt(rel.X*rel.X + rel.Z*rel.Z))
    local dx = math.round(yaw * pixelsPerRadian)
    local dy = math.round(-pitch * pixelsPerRadian)
    if dx == 0 and dy == 0 then return end
    -- executors want integers here; floats either error or truncate silently
    local ok = pcall(function() mousemoverel(dx, dy) end)
    if not ok and not mouseMoverelWarned then
        mouseMoverelWarned = true
        notify("Aimbot", "mousemoverel is unavailable in this executor")
    end
end)

--// FOV circle
-- Drawn in viewport space, the same space the aimbot measures its pixel FOV in, so the
-- ring is exactly the radius in which it will pick a target.
local fovCircleEnabled = false
local fovCircleGui, fovCircleFrame

local function destroyFovCircle()
    if fovCircleGui then
        pcall(function() fovCircleGui:Destroy() end)
    end
    fovCircleGui = nil
    fovCircleFrame = nil
end

local function ensureFovCircle()
    if fovCircleGui and fovCircleGui.Parent and fovCircleFrame then
        return fovCircleFrame
    end
    destroyFovCircle()
    local pg = LP:FindFirstChildOfClass("PlayerGui")
    if not pg then return nil end
    local gui = Instance.new("ScreenGui")
    gui.Name = "UrbanReloadFOV"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 10
    gui.Parent = pg
    local frame = Instance.new("Frame")
    frame.Name = "FOVCircle"
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.BackgroundTransparency = 1
    frame.BorderSizePixel = 0
    frame.ZIndex = 5
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = frame
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1.5
    stroke.Color = Color3.fromRGB(255,255,255)
    stroke.Transparency = 0.25
    stroke.Parent = frame
    frame.Parent = gui
    fovCircleGui = gui
    fovCircleFrame = frame
    return frame
end

RunService.RenderStepped:Connect(function()
    if not fovCircleEnabled then
        if fovCircleGui then destroyFovCircle() end
        return
    end
    local cam = Workspace.CurrentCamera
    if not cam then return end
    local frame = ensureFovCircle()
    if not frame then return end
    local vp = cam.ViewportSize
    if vp.Y <= 0 then return end
    local diameter = math.max(aimbotFOV * 2, 2)
    frame.Size = UDim2.fromOffset(diameter, diameter)
    frame.Position = UDim2.fromOffset(vp.X/2, vp.Y/2)
end)

--// spinbot
RunService.RenderStepped:Connect(function(dt)
    if not spinbot then
        if spinbotHum then
            pcall(function() spinbotHum.AutoRotate = true end)
            spinbotHum = nil
        end
        return
    end
    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hrp and hum then
        if spinbotHum ~= hum then
            if spinbotHum then pcall(function() spinbotHum.AutoRotate = true end) end
            spinbotHum = hum
            hum.AutoRotate = false
        end
        spinAngle = (spinAngle + spinSpeed * 60 * dt) % 360
        local pos = hrp.Position
        local vel = hrp.AssemblyLinearVelocity
        hrp.CFrame = CFrame.new(pos) * CFrame.Angles(0, math.rad(spinAngle), 0)
        hrp.AssemblyLinearVelocity = vel
    end
end)

--// Tabs
local CombatTab = Window:CreateTab("Combat", 4483362458)
local EspTab = Window:CreateTab("ESP", 4483362458)
local TpTab = Window:CreateTab("Teleport", 4483362458)

-- Combat
CombatTab:CreateSection("Aimbot")
CombatTab:CreateToggle({Name="Aimbot",CurrentValue=false,Flag="Aimbot",Callback=function(v) aimbotEnabled=v end})
CombatTab:CreateSlider({Name="Aimbot FOV",Range={30,400},Increment=5,Suffix="px",CurrentValue=150,Flag="AimbotFOV",Callback=function(v) aimbotFOV=v end})
CombatTab:CreateToggle({Name="FOV Circle",CurrentValue=false,Flag="FOVCircle",Callback=function(v) fovCircleEnabled=v end})
CombatTab:CreateToggle({Name="Aim on RMB",CurrentValue=false,Flag="AimbotRMB",Callback=function(v) aimbotRMB=v end})
CombatTab:CreateToggle({Name="Visible Check",CurrentValue=true,Flag="AimbotVis",Callback=function(v) aimbotVisibleCheck=v end})
CombatTab:CreateSection("Weapon")
CombatTab:CreateToggle({Name="No Recoil",CurrentValue=false,Flag="NoRecoil",Callback=function(v)
    if v then
        startLoop("NoRecoil",0.2,function()
            if getgc then
                for _,fn in ipairs(getgc(true)) do
                    if type(fn) == "function" then
                        local ok, ups = pcall(debug.getupvalues, fn)
                        if ok and ups then
                            for _,tbl in pairs(ups) do
                                local isWeapon = false
                                pcall(function()
                                    if type(tbl) == "table" and type(tbl.Recoil) == "table" and type(tbl.Recoil.Up) == "number" then
                                        isWeapon = true
                                    end
                                end)
                                if isWeapon then
                                    pcall(function()
                                        setreadonly(tbl,false)
                                        setreadonly(tbl.Recoil,false)
                                        tbl.Recoil.Up = 0
                                        tbl.Recoil.Side = 0
                                        tbl.Recoil.Return = 0
                                    end)
                                end
                            end
                        end
                    end
                end
            end
            patchWeaponConfig()
        end)
    else
        stopLoop("NoRecoil")
    end
end})
CombatTab:CreateToggle({Name="No Spread",CurrentValue=false,Flag="NoSpread",Callback=function(v)
    if v then
        startLoop("NoSpread",0.2,function()
            if getgc then
                for _,fn in ipairs(getgc(true)) do
                    if type(fn) == "function" then
                        local ok, ups = pcall(debug.getupvalues, fn)
                        if ok and ups then
                            for _,tbl in pairs(ups) do
                                local isWeapon = false
                                pcall(function()
                                    if type(tbl) == "table" and type(tbl.Bloom) == "table" and type(tbl.Bloom.Max) == "number" then
                                        isWeapon = true
                                    end
                                end)
                                if isWeapon then
                                    pcall(function()
                                        setreadonly(tbl,false)
                                        setreadonly(tbl.Bloom,false)
                                        tbl.Bloom.Max = 0
                                        tbl.Bloom.Aim = 0
                                        tbl.Bloom.Hip = 0
                                        tbl.Bloom.Move = 0
                                        tbl.Bloom.Air = 0
                                        tbl.Bloom.PerShot = 0
                                    end)
                                end
                            end
                        end
                    end
                end
            end
            patchWeaponConfig()
            pcall(function()
                local w = weaponsFolder()
                local cs = w and w:FindFirstChild("ClientState")
                if cs then
                    local mod = require(cs)
                    setreadonly(mod,false)
                    mod.SpreadMultiplier = 0
                    mod.Spread = 0
                    mod.SpreadRest = 0
                end
            end)
        end)
    else
        stopLoop("NoSpread")
    end
end})
CombatTab:CreateSection("Antihit")
CombatTab:CreateToggle({Name="Spinbot",CurrentValue=false,Flag="Spinbot",Callback=function(v) spinbot=v end})
CombatTab:CreateSlider({Name="Spin Speed",Range={1,50},Increment=1,Suffix="spd",CurrentValue=10,Flag="SpinSpeed",Callback=function(v) spinSpeed=v end})

-- ESP
EspTab:CreateSection("ESP Settings")
EspTab:CreateToggle({Name="ESP Enabled",CurrentValue=false,Flag="ESP",Callback=function(v)
    ESP.Enabled=v
    refreshESP()
end})
EspTab:CreateToggle({Name="Players",CurrentValue=true,Flag="ESP Players",Callback=function(v)
    ESP.Players=v
    if ESP.Enabled then refreshESP() end
end})
EspTab:CreateToggle({Name="Vehicles",CurrentValue=false,Flag="ESP Vehicles",Callback=function(v)
    ESP.Vehicles=v
    if ESP.Enabled then refreshESP() end
end})
EspTab:CreateDropdown({Name="Style",Options={"Highlight","None"},CurrentOption={"Highlight"},MultipleOptions=false,Flag="ESP Style",Callback=function(v)
    ESP.Style = (type(v)=="table" and v[1]) or v
    if ESP.Enabled then refreshESP() end
end})
EspTab:CreateSection("Look")
EspTab:CreateToggle({Name="Fullbright",CurrentValue=false,Flag="Fullbright",Callback=function(v)
    fullbright=v
    applyFullbright(v)
end})
EspTab:CreateToggle({Name="Team Colors",CurrentValue=true,Flag="ESP Team Colors",Callback=function(v)
    ESP.TeamColors=v
end})
EspTab:CreateToggle({Name="Names",CurrentValue=true,Flag="ESP Names",Callback=function(v) ESP.ShowName=v end})
EspTab:CreateToggle({Name="Health",CurrentValue=true,Flag="ESP Health",Callback=function(v) ESP.ShowHealth=v end})
EspTab:CreateToggle({Name="Distance",CurrentValue=true,Flag="ESP Distance",Callback=function(v) ESP.ShowDistance=v end})
EspTab:CreateToggle({Name="Boxes",CurrentValue=false,Flag="ESP Boxes",Callback=function(v)
    ESP.Boxes=v
    if ESP.Enabled then refreshESP() end
end})
EspTab:CreateToggle({Name="Tracers",CurrentValue=false,Flag="ESP Tracers",Callback=function(v)
    ESP.Tracers=v
    if ESP.Enabled then refreshESP() end
end})

-- Teleport
TpTab:CreateSection("Teleport")
TpTab:CreateButton({Name="Teleport to Nearest Player",Callback=function()
    local best, bestDist = nil, math.huge
    local myHrp = getHrp()
    if not myHrp then return end
    for _,plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and plr.Character then
            local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local d = (hrp.Position-myHrp.Position).Magnitude
                if d < bestDist then bestDist = d; best = hrp end
            end
        end
    end
    if best then myHrp.CFrame = CFrame.new(best.Position + Vector3.new(0,3,0)) end
end})
TpTab:CreateButton({Name="Teleport to Random Player",Callback=function()
    local list = {}
    for _,plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and plr.Character then table.insert(list,plr) end
    end
    if #list == 0 then return end
    local plr = list[math.random(1,#list)]
    local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
    local myHrp = getHrp()
    if hrp and myHrp then myHrp.CFrame = CFrame.new(hrp.Position + Vector3.new(0,3,0)) end
end})

--// respawn: rebuild the ESP against the new character instead of leaving stale entries
LP.CharacterAdded:Connect(function(char)
    spinbotHum = nil
    if ESP.Enabled then refreshESP() end
    local hum = char:WaitForChild("Humanoid", 10)
    if not hum then return end
    pcall(function() hum.AutoRotate = true end)
end)

LP.CharacterRemoving:Connect(function()
    spinbotHum = nil
end)

Players.PlayerRemoving:Connect(function(plr)
    local entry = ESP.playerEntries[plr]
    if entry then
        destroyEntry(entry)
        ESP.playerEntries[plr] = nil
    end
end)

print("[UrbanReload] v3 loaded - tabs: Combat, ESP, Teleport")
notify("Loaded v3", "Urban Reload cheat ready.")
