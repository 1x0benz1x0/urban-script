local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
local LP = Players.LocalPlayer
local previousShutdown = getgenv and getgenv().__UrbanReloadShutdown
if type(previousShutdown) == "function" then
    pcall(previousShutdown)
end
getgenv().__UrbanReloadShutdown = nil
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
local Window = Rayfield:CreateWindow({
    Name = "Urban Reload By benz",
    LoadingTitle = "Urban Reload",
    LoadingSubtitle = "Benz",
    ConfigurationSaving = { Enabled = true, FolderName = "UrbanReloadCheat", FileName = "ConfigV3" },
    Discord = { Enabled = false },
    KeySystem = false
})
local function notify(title, content)
    pcall(function() Rayfield:Notify({Title=title, Content=content, Duration=4}) end)
end
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
local spinbot = false
local spinbotHum = nil
local spinSpeed = 10
local spinAngle = 0
local fullbright = false
local instantReload = false
local rapidFire = false
local rapidFireRPM = 1200
local fullAuto = false
local infAmmo = true
local speedEnabled = false
local speedValue = 45
local infStamina = false
local bhop = false
local autoLoot = false
local autoLootRadius = 60
local autoCollect = false
local collectRadius = 20
local LightingDefaults = {
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    FogEnd = Lighting.FogEnd,
    GlobalShadows = Lighting.GlobalShadows,
}
local function getHrp()
    local char = LP.Character
    return char and char:FindFirstChild("HumanoidRootPart") or nil
end
local weaponDefaults
local function weaponModule(name)
    local w = weaponsFolder()
    local m = w and w:FindFirstChild(name)
    if not m then return nil end
    local ok, mod = pcall(require, m)
    if ok and type(mod) == "table" then return mod end
    return nil
end
local function eachWeapon(fn)
    local mod = weaponModule("WeaponData")
    if not mod then return 0 end
    weaponDefaults = weaponDefaults or {}
    local count = 0
    for name, def in pairs(mod) do
        if type(def) == "table" then
            local fire, ammo = def.Fire, def.Ammo
            if not weaponDefaults[name] then
                weaponDefaults[name] = {
                    mode = type(fire) == "table" and fire.Mode or nil,
                    rpm = type(fire) == "table" and tonumber(fire.RPM) or nil,
                    reload = type(ammo) == "table" and tonumber(ammo.ReloadTime) or nil,
                }
            end
            pcall(fn, name, def, weaponDefaults[name])
            count = count + 1
        end
    end
    return count
end
local reloadDefaults = {}
local lastReloadSweep = 0
local function reloadValue(k)
    if string.find(k, "time") or string.find(k, "duration") or string.find(k, "delay") or string.find(k, "cooldown") then
        return 0
    end
    if string.find(k, "speed") or string.find(k, "mult") or string.find(k, "rate") then
        return 100
    end
    return 0
end
local function patchReloadTable(tbl, depth)
    if type(tbl) ~= "table" then return end
    pcall(setreadonly, tbl, false)
    for k, v in pairs(tbl) do
        if type(k) == "string" then
            local lk = string.lower(k)
            if type(v) == "number" and string.find(lk, "reload") then
                reloadDefaults[tbl] = reloadDefaults[tbl] or {}
                if reloadDefaults[tbl][k] == nil then reloadDefaults[tbl][k] = v end
                local target = reloadValue(lk)
                pcall(function() tbl[k] = target end)
            elseif type(v) == "table" and (depth or 0) < 1
                and (string.find(lk, "ammo") or string.find(lk, "reload")) then
                patchReloadTable(v, (depth or 0) + 1)
            end
        end
    end
end
local function restoreReloadTables()
    for tbl, saved in pairs(reloadDefaults) do
        pcall(setreadonly, tbl, false)
        for k, v in pairs(saved) do
            pcall(function() tbl[k] = v end)
        end
    end
    reloadDefaults = {}
end
local function sweepReloadFromGC()
    if not getgc then return end
    for _, fn in ipairs(getgc(true)) do
        if type(fn) == "function" then
            local ok, ups = pcall(debug.getupvalues, fn)
            if ok and type(ups) == "table" then
                for _, v in pairs(ups) do
                    if type(v) == "table" then
                        local ammo = v.Ammo
                        if type(ammo) == "table" and type(ammo.ReloadTime) == "number" then
                            patchReloadTable(ammo, 1)
                        end
                        if type(v.ReloadTime) == "number" then
                            patchReloadTable(v, 1)
                        end
                    end
                end
            end
        end
    end
end
local function pinToolAmmo()
    local P = Players.LocalPlayer
    local list = {}
    local char = P.Character
    if char then
        for _, t in ipairs(char:GetChildren()) do table.insert(list, t) end
    end
    local bp = P:FindFirstChildOfClass("Backpack")
    if bp then
        for _, t in ipairs(bp:GetChildren()) do table.insert(list, t) end
    end
    for _, t in ipairs(list) do
        if t:IsA("Tool") and t:GetAttribute("Ammo") ~= nil then
            local mag = tonumber(t:GetAttribute("MagSize"))
            if mag and t:GetAttribute("Ammo") ~= mag then
                pcall(function() t:SetAttribute("Ammo", mag) end)
            end
            if t:GetAttribute("ReloadTime") ~= 0 then
                pcall(function() t:SetAttribute("ReloadTime", 0) end)
            end
        end
    end
end
local function restoreToolReload()
    local mod = weaponModule("WeaponData")
    local P = Players.LocalPlayer
    local list = {}
    local char = P.Character
    if char then
        for _, t in ipairs(char:GetChildren()) do table.insert(list, t) end
    end
    local bp = P:FindFirstChildOfClass("Backpack")
    if bp then
        for _, t in ipairs(bp:GetChildren()) do table.insert(list, t) end
    end
    for _, t in ipairs(list) do
        if t:IsA("Tool") then
            local def = mod and mod[t.Name]
            local stock = def and type(def.Ammo) == "table" and tonumber(def.Ammo.ReloadTime)
            if stock then pcall(function() t:SetAttribute("ReloadTime", stock) end) end
        end
    end
end
local function applyInstantReload(on)
    if not on then
        restoreToolReload()
        restoreReloadTables()
        return
    end
    pinToolAmmo()
    eachWeapon(function(name, def, stock)
        if type(def.Ammo) == "table" then
            patchReloadTable(def.Ammo, 1)
        end
    end)
    local cfg = weaponModule("Config")
    if type(cfg) == "table" then
        patchReloadTable(cfg, 0)
        if type(cfg.Global) == "table" then patchReloadTable(cfg.Global, 0) end
    end
    local cs = weaponModule("ClientState")
    if type(cs) == "table" then patchReloadTable(cs, 0) end
    local now = os.clock()
    if now - lastReloadSweep >= 1 then
        lastReloadSweep = now
        pcall(sweepReloadFromGC)
    end
end
local function applyRapidFire(on)
    eachWeapon(function(name, def, stock)
        if type(def.Fire) == "table" then
            setreadonly(def.Fire, false)
            def.Fire.RPM = on and rapidFireRPM or (stock.rpm or def.Fire.RPM)
        end
    end)
end
local function applyFullAuto(on)
    eachWeapon(function(name, def, stock)
        if type(def.Fire) == "table" and stock.mode then
            setreadonly(def.Fire, false)
            def.Fire.Mode = on and "Auto" or stock.mode
        end
    end)
end
local function applyInfiniteAmmo(on)
    pcall(function()
        local mod = weaponModule("Config")
        local g = mod and mod.Global
        if g then
            setreadonly(g, false)
            g.InfiniteAmmo = on
        end
    end)
end
local function reapplyWeaponTuning()
    applyInstantReload(instantReload)
    applyRapidFire(rapidFire)
    applyFullAuto(fullAuto)
    applyInfiniteAmmo(infAmmo)
end
local LOOT_TAG = "GroundLoot"
local CASH_BAGS = { CashBag500K = 200000, CashBag1M = 500000, CashBag3M = 800000, CashBag5M = 1200000 }
local function liveHum()
    local char = LP.Character
    return char and char:FindFirstChildOfClass("Humanoid") or nil
end
local function lootHandle(tool)
    local handle = tool and tool:FindFirstChild("Handle")
    if handle and handle:IsA("BasePart") then return handle end
    return nil
end
local function lootItem(tool)
    return tool:GetAttribute("Item") or tool:GetAttribute("Weapon") or tool:GetAttribute("Melee") or tool.Name
end
local function isMoneyLoot(tool)
    local item = lootItem(tool)
    if type(item) ~= "string" then return false end
    if CASH_BAGS[item] then return true end
    return string.find(string.lower(item), "cash") ~= nil
end
local function lootValue(tool)
    local item = lootItem(tool)
    if type(item) == "string" then return CASH_BAGS[item] end
    return nil
end
local function nearestLoot(radius, moneyOnly)
    local hrp = getHrp()
    if not hrp then return nil end
    local best, bestDist = nil, radius
    for _, tool in ipairs(CollectionService:GetTagged(LOOT_TAG)) do
        local handle = tool.Parent and lootHandle(tool)
        if handle and (not moneyOnly or isMoneyLoot(tool)) then
            local d = (handle.Position - hrp.Position).Magnitude
            if d < bestDist then
                bestDist = d
                best = handle.Position
            end
        end
    end
    return best
end
local atmCache, atmCachedAt = {}, 0
local function scanATMs()
    local now = os.clock()
    if now - atmCachedAt < 5 then return atmCache end
    atmCachedAt = now
    local found, seen = {}, {}
    for _, d in ipairs(Workspace:GetDescendants()) do
        if d:IsA("ProximityPrompt") and string.find(string.lower(d.Name), "atm") then
            local model = d:FindFirstAncestorOfClass("Model")
            if model and not seen[model] then
                seen[model] = true
                table.insert(found, model)
            end
        end
    end
    if #found == 0 then
        for _, d in ipairs(Workspace:GetDescendants()) do
            if d:IsA("Model") and string.find(string.lower(d.Name), "atm") and not seen[d] then
                seen[d] = true
                table.insert(found, d)
            end
        end
    end
    atmCache = found
    return atmCache
end
local function atmAnchor(model)
    return model.PrimaryPart
        or model:FindFirstChildWhichIsA("MeshPart", true)
        or model:FindFirstChildWhichIsA("BasePart", true)
end
local function doAutoLoot()
    local hrp = getHrp()
    if not hrp then return end
    local pos = nearestLoot(autoLootRadius, false)
    if not pos then
        local best, bestDist = nil, autoLootRadius
        for _, atm in ipairs(scanATMs()) do
            local anchor = atmAnchor(atm)
            if anchor then
                local d = (anchor.Position - hrp.Position).Magnitude
                if d < bestDist then
                    bestDist = d
                    best = anchor.Position
                end
            end
        end
        pos = best
    end
    if pos then
        hrp.CFrame = CFrame.new(pos + Vector3.new(0, 2, 0))
    end
end
local function doAutoCollect()
    local hrp = getHrp()
    if not hrp then return end
    for _, atm in ipairs(scanATMs()) do
        local anchor = atmAnchor(atm)
        if anchor and (anchor.Position - hrp.Position).Magnitude <= collectRadius then
            for _, d in ipairs(atm:GetDescendants()) do
                if d:IsA("ProximityPrompt") then
                    pcall(function()
                        d:InputHoldBegin()
                        d:InputHoldEnd()
                    end)
                end
            end
        end
    end
    for _, tool in ipairs(CollectionService:GetTagged(LOOT_TAG)) do
        local handle = tool.Parent and lootHandle(tool)
        if handle and (handle.Position - hrp.Position).Magnitude <= collectRadius then
            for _, prompt in ipairs(handle:GetChildren()) do
                if prompt:IsA("ProximityPrompt") then
                    pcall(function()
                        prompt:InputHoldBegin()
                        prompt:InputHoldEnd()
                    end)
                end
            end
        end
    end
end
local staminaDefaults = {}
local function staminaKey(k)
    k = string.lower(k)
    return string.find(k, "stam") or string.find(k, "fatigue")
end
local function gatherStaminaTables()
    local list = {}
    for _, name in ipairs({ "Config", "MeleeData", "ClientState" }) do
        local mod = weaponModule(name)
        if not mod then
            local inst = ReplicatedStorage:FindFirstChild(name, true)
            if inst and inst:IsA("ModuleScript") then
                local ok, m = pcall(require, inst)
                if ok and type(m) == "table" then mod = m end
            end
        end
        if type(mod) == "table" then
            table.insert(list, mod)
            if type(mod.Global) == "table" then table.insert(list, mod.Global) end
        end
    end
    return list
end
local function patchStaminaTable(tbl, depth, seen)
    if type(tbl) ~= "table" or seen[tbl] then return end
    seen[tbl] = true
    pcall(setreadonly, tbl, false)
    for k, v in pairs(tbl) do
        if type(k) == "string" then
            if type(v) == "number" and staminaKey(k) then
                local lk = string.lower(k)
                local lethal = string.find(lk, "dmg") or string.find(lk, "damage")
                if not lethal then
                    staminaDefaults[tbl] = staminaDefaults[tbl] or {}
                    if staminaDefaults[tbl][k] == nil then staminaDefaults[tbl][k] = v end
                    pcall(function() tbl[k] = 99999 end)
                end
            elseif type(v) == "table" and (depth or 0) < 2 then
                patchStaminaTable(v, (depth or 0) + 1, seen)
            end
        end
    end
end
local function stompStamina()
    local seen = {}
    for _, tbl in ipairs(gatherStaminaTables()) do
        pcall(patchStaminaTable, tbl, 0, seen)
    end
    local targets = { LP }
    local char = LP.Character
    if char then table.insert(targets, char) end
    local hum = liveHum()
    if hum then table.insert(targets, hum) end
    for _, obj in ipairs(targets) do
        for key, value in pairs(obj:GetAttributes()) do
            if type(value) == "number" and staminaKey(key) then
                pcall(function() obj:SetAttribute(key, 99999) end)
            end
        end
        for _, child in ipairs(obj:GetChildren()) do
            if child:IsA("ValueBase") and staminaKey(child.Name) then
                pcall(function() child.Value = 99999 end)
            end
        end
    end
end
local function restoreStamina()
    for tbl, saved in pairs(staminaDefaults) do
        pcall(setreadonly, tbl, false)
        for k, v in pairs(saved) do
            pcall(function() tbl[k] = v end)
        end
    end
    staminaDefaults = {}
end
local speedOriginal, speedDefaults
local function speedGlobal()
    local mod = weaponModule("Config")
    return mod and type(mod.Global) == "table" and mod.Global or nil
end
local function applySpeed()
    local g = speedGlobal()
    if g then
        if not speedDefaults then
            speedDefaults = { walk = tonumber(g.WalkSpeed), sprint = tonumber(g.SprintSpeed) }
        end
        pcall(function()
            setreadonly(g, false)
            if speedEnabled then
                g.WalkSpeed = speedValue
                if type(g.SprintSpeed) == "number" then g.SprintSpeed = speedValue + 8 end
            else
                if speedDefaults.walk then g.WalkSpeed = speedDefaults.walk end
                if speedDefaults.sprint then g.SprintSpeed = speedDefaults.sprint end
            end
        end)
        if not speedEnabled then speedDefaults = nil end
    end
    local hum = liveHum()
    if not hum then return end
    if speedEnabled then
        if not speedOriginal then speedOriginal = hum.WalkSpeed end
        pcall(function() hum.WalkSpeed = speedValue end)
    else
        pcall(function() hum.WalkSpeed = speedOriginal or 16 end)
        speedOriginal = nil
    end
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
    Money = false,
    moneyEntries = {},
    atmEntries = {},
    AI = false,
    aiEntries = {},
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
local buildAIEntry, updateAIEntry
local aiCache, aiCachedAt = {}, 0
local function playerCharSet()
    local set = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Character then set[plr.Character] = true end
    end
    return set
end
local function aiCharacters()
    local now = os.clock()
    if now - aiCachedAt < 2 then return aiCache end
    aiCachedAt = now
    local owned = playerCharSet()
    local out, seen = {}, {}
    for _, d in ipairs(Workspace:GetDescendants()) do
        if d:IsA("Model") and not owned[d] and not seen[d] then
            local hum = d:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                seen[d] = true
                table.insert(out, d)
            end
        end
    end
    aiCache = out
    return aiCache
end
local function aiAnchor(model)
    return model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
end
local farmEnabled = false
local farmRadius = 250
local farmCache, farmCachedAt = {}, 0
local function isZombieModel(model)
    if not model then return false end
    local hum = model:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    local function mention(s)
        return type(s) == "string" and string.find(string.lower(s), "zombie", 1, true) ~= nil
    end
    if mention(model.Name) or mention(hum.DisplayName) then return true end
    local parent = model.Parent
    if parent and mention(parent.Name) then return true end
    for _, d in ipairs(model:GetDescendants()) do
        if mention(d.Name) and (d:IsA("Model") or d:IsA("ProximityPrompt")) then return true end
        if d:IsA("ProximityPrompt") and (mention(d.ObjectText) or mention(d.ActionText)) then return true end
    end
    return false
end
local function zombieAlive(model)
    local hum = model and model:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    local ok, state = pcall(function() return hum:GetState() end)
    if not ok then return true end
    if state == Enum.HumanoidStateType.Dead or state == Enum.HumanoidStateType.Physics then
        return false
    end
    return true
end
local function farmZombies()
    local now = os.clock()
    if now - farmCachedAt < 1 then return farmCache end
    farmCachedAt = now
    local out = {}
    for _, d in ipairs(Workspace:GetDescendants()) do
        if d:IsA("Model") and d.Parent and isZombieModel(d) then table.insert(out, d) end
    end
    farmCache = out
    return farmCache
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
local function buildATMEntry(model)
    local anchor = atmAnchor(model)
    if not anchor then return nil end
    local entry = { model = model, anchor = anchor, objects = {} }
    local h = Instance.new("Highlight")
    h.Name = "UrbanReloadHL"
    h.FillColor = Color3.fromRGB(0,200,90)
    h.FillTransparency = 0.5
    h.OutlineColor = Color3.fromRGB(120,255,160)
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    h.Parent = model
    entry.hl = h
    table.insert(entry.objects, h)
    local bb, txt = makeLabel(anchor, Vector3.new(0,3,0), 140, 20, 12)
    entry.labelBg, entry.label = bb, txt
    if bb then table.insert(entry.objects, bb) end
    ESP.atmEntries[model] = entry
    return entry
end
local function updateATMEntry(entry)
    local model, anchor = entry.model, entry.anchor
    if not model or not model.Parent or not anchor or not anchor.Parent then return false end
    if entry.label then
        local parts = { "ATM" }
        local myHrp = getHrp()
        if ESP.ShowDistance and myHrp then
            table.insert(parts, math.floor((anchor.Position-myHrp.Position).Magnitude) .. "m")
        end
        entry.label.Text = table.concat(parts, " | ")
        entry.label.TextColor3 = Color3.fromRGB(120,255,160)
    end
    return true
end
local function buildMoneyEntry(tool)
    local handle = lootHandle(tool)
    if not handle then return nil end
    local entry = { tool = tool, handle = handle, objects = {} }
    local h = Instance.new("Highlight")
    h.Name = "UrbanReloadHL"
    h.FillColor = Color3.fromRGB(255,200,0)
    h.FillTransparency = 0.45
    h.OutlineColor = Color3.fromRGB(255,230,90)
    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    h.Parent = handle
    entry.hl = h
    table.insert(entry.objects, h)
    local bb, txt = makeLabel(handle, Vector3.new(0,1.8,0), 170, 20, 12)
    entry.labelBg, entry.label = bb, txt
    if bb then table.insert(entry.objects, bb) end
    ESP.moneyEntries[tool] = entry
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
    for tool,e in pairs(ESP.moneyEntries) do
        destroyEntry(e)
        ESP.moneyEntries[tool] = nil
    end
    for model,e in pairs(ESP.atmEntries) do
        destroyEntry(e)
        ESP.atmEntries[model] = nil
    end
    for model,e in pairs(ESP.aiEntries) do
        destroyEntry(e)
        ESP.aiEntries[model] = nil
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
    if ESP.AI then
        for _,model in ipairs(aiCharacters()) do
            if model.Parent then
                pcall(buildAIEntry, model)
            end
        end
    end
    if ESP.Money then
        for _,tool in ipairs(CollectionService:GetTagged(LOOT_TAG)) do
            if tool.Parent and isMoneyLoot(tool) then
                pcall(function() buildMoneyEntry(tool) end)
            end
        end
        for _,model in ipairs(scanATMs()) do
            if model.Parent then
                pcall(function() buildATMEntry(model) end)
            end
        end
    end
end
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
    if ESP.Money then
        for _,tool in ipairs(CollectionService:GetTagged(LOOT_TAG)) do
            if tool.Parent and isMoneyLoot(tool) and not ESP.moneyEntries[tool] then
                pcall(function() buildMoneyEntry(tool) end)
            end
        end
        for _,model in ipairs(scanATMs()) do
            if model.Parent and not ESP.atmEntries[model] then
                pcall(function() buildATMEntry(model) end)
            end
        end
    end
    for tool,entry in pairs(ESP.moneyEntries) do
        if not tool.Parent or not ESP.Money then
            destroyEntry(entry)
            ESP.moneyEntries[tool] = nil
        end
    end
    for model,entry in pairs(ESP.atmEntries) do
        if not model.Parent or not ESP.Money then
            destroyEntry(entry)
            ESP.atmEntries[model] = nil
        end
    end
end
local function projectBox(cam, cf, size)
    local minX, minY, maxX, maxY
    for i = 0, 7 do
        local sx = (i % 2 == 0) and -0.5 or 0.5
        local sy = (math.floor(i / 2) % 2 == 0) and -0.5 or 0.5
        local sz = (math.floor(i / 4) % 2 == 0) and -0.5 or 0.5
        local corner = cf * Vector3.new(sx * size.X, sy * size.Y, sz * size.Z)
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
function buildAIEntry(model)
    local anchor = aiAnchor(model)
    if not anchor then return nil end
    local entry = { model = model, anchor = anchor, objects = {} }
    local color = Color3.fromRGB(255,150,0)
    if ESP.Style == "Highlight" then
        local h = Instance.new("Highlight")
        h.Name = "UrbanReloadHL"
        h.FillColor = color
        h.FillTransparency = 0.55
        h.OutlineColor = color
        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        h.Parent = model
        entry.hl = h
        table.insert(entry.objects, h)
    end
    local bb, txt = makeLabel(anchor, Vector3.new(0,2.6,0), 170, 20, 12)
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
    ESP.aiEntries[model] = entry
    return entry
end
function updateAIEntry(entry)
    local model = entry.model
    if not model or not model.Parent then return false end
    local anchor = entry.anchor
    if not anchor or not anchor.Parent then
        anchor = aiAnchor(model)
        entry.anchor = anchor
        if not anchor then return false end
        if entry.labelBg then entry.labelBg.Parent = anchor end
    end
    local hum = model:FindFirstChildOfClass("Humanoid")
    local color = Color3.fromRGB(255,150,0)
    if entry.hl then
        entry.hl.FillColor = color
        entry.hl.OutlineColor = color
    end
    local cam = Workspace.CurrentCamera
    local myHrp = getHrp()
    local boxX, boxY, boxW, boxH
    if cam and entry.box then
        if not entry.boxSize or (os.clock() - (entry.boxAt or 0)) > 0.25 then
            local minV, maxV = characterBox(model)
            if minV then
                entry.boxSize = maxV - minV
                entry.boxOffset = (minV + maxV) * 0.5 - anchor.Position
            end
            entry.boxAt = os.clock()
        end
        local center = anchor.Position + (entry.boxOffset or Vector3.zero)
        local size = entry.boxSize or Vector3.new(2.2, 5.2, 1.2)
        boxX, boxY, boxW, boxH = projectBox(cam, CFrame.new(center) * anchor.CFrame.Rotation, size)
    end
    if entry.label then
        local parts = {}
        if ESP.ShowName then table.insert(parts, model.Name) end
        if ESP.ShowHealth and hum then table.insert(parts, math.floor(hum.Health) .. " hp") end
        if ESP.ShowDistance and myHrp then
            table.insert(parts, math.floor((anchor.Position-myHrp.Position).Magnitude) .. "m")
        end
        entry.label.Text = table.concat(parts, " | ")
        entry.label.TextColor3 = color
    end
    if entry.box then
        if boxX then
            entry.box.Visible = true
            entry.box.Position = UDim2.fromOffset(boxX, boxY)
            entry.box.Size = UDim2.fromOffset(math.max(boxW,4), math.max(boxH,4))
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
                entry.tracer.Position = UDim2.fromOffset((startX+endX)*0.5, (startY+endY)*0.5)
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
local function reconcileAI()
    if not ESP.AI then
        for model, entry in pairs(ESP.aiEntries) do
            destroyEntry(entry)
            ESP.aiEntries[model] = nil
        end
        return
    end
    local live = {}
    for _, model in ipairs(aiCharacters()) do
        live[model] = true
        if not ESP.aiEntries[model] then
            pcall(buildAIEntry, model)
        end
    end
    for model, entry in pairs(ESP.aiEntries) do
        if not live[model] or not model.Parent then
            destroyEntry(entry)
            ESP.aiEntries[model] = nil
        end
    end
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
local function updateMoneyEntry(entry)
    local tool = entry.tool
    local handle = entry.handle
    if not tool or not tool.Parent or not handle or not handle.Parent then return false end
    if entry.label then
        local value = lootValue(tool)
        local parts = { value and ("$" .. tostring(value)) or tostring(lootItem(tool)) }
        local myHrp = getHrp()
        if ESP.ShowDistance and myHrp then
            table.insert(parts, math.floor((handle.Position-myHrp.Position).Magnitude) .. "m")
        end
        entry.label.Text = table.concat(parts, " | ")
        entry.label.TextColor3 = Color3.fromRGB(255,210,60)
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
    for _,entry in pairs(ESP.moneyEntries) do
        local ok, err = pcall(updateMoneyEntry, entry)
        if not ok then reportEspError(err) end
    end
    for _,entry in pairs(ESP.atmEntries) do
        local ok, err = pcall(updateATMEntry, entry)
        if not ok then reportEspError(err) end
    end
    for _,entry in pairs(ESP.aiEntries) do
        local ok, err = pcall(updateAIEntry, entry)
        if not ok then reportEspError(err) end
    end
end)
task.spawn(function()
    while true do
        if ESP.Enabled then pcall(reconcileESP) end
        if ESP.Enabled then pcall(reconcileAI) end
        task.wait(1)
    end
end)
local aimbotEnabled = false
local aimbotFOV = 150
local aimbotRMB = false
local aimbotVisibleCheck = true
local function aimPart(plr)
    local char = plr.Character
    if not char then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return nil end
    return char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
end
local seesFrom
local function cameraSees(part)
    local cam = Workspace.CurrentCamera
    local myHrp = getHrp()
    local origin = (cam and cam.CFrame.Position) or (myHrp and myHrp.Position) or Vector3.zero
    return seesFrom(origin, part.Position, part.Parent, part)
end
local function isVisible(part)
    if not aimbotVisibleCheck then return true end
    return cameraSees(part)
end
local function aimPartForChar(char)
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return nil end
    return char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
end
local function getClosestEnemy(fov)
    local cam = Workspace.CurrentCamera
    if not cam then return nil end
    local center = Vector2.new(cam.ViewportSize.X/2, cam.ViewportSize.Y/2)
    local best, bestDist = nil, fov or aimbotFOV
    local function consider(part)
        if not part then return end
        local pos, onScreen = cam:WorldToViewportPoint(part.Position)
        if not onScreen then return end
        local d = (Vector2.new(pos.X,pos.Y)-center).Magnitude
        if d < bestDist and isVisible(part) then
            bestDist = d
            best = part
        end
    end
    for _,plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP then consider(aimPart(plr)) end
    end
    if farmEnabled then
        for _,model in ipairs(farmZombies()) do
            if zombieAlive(model) then consider(aimPartForChar(model)) end
        end
    elseif ESP.AI then
        for _,model in ipairs(aiCharacters()) do
            consider(aimPartForChar(model))
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
    local viewport = cam.ViewportSize
    if viewport.Y <= 0 then return end
    local pixelsPerRadian = (viewport.Y / 2) / math.tan(math.rad(cam.FieldOfView) / 2)
    local rel = cam.CFrame:PointToObjectSpace(part.Position)
    if rel.Z > -0.5 then return end 
    local yaw = math.atan2(rel.X, -rel.Z)
    local pitch = math.atan2(rel.Y, math.sqrt(rel.X*rel.X + rel.Z*rel.Z))
    local dx = math.round(yaw * pixelsPerRadian)
    local dy = math.round(-pitch * pixelsPerRadian)
    if dx == 0 and dy == 0 then return end
    local ok = pcall(function() mousemoverel(dx, dy) end)
    if not ok and not mouseMoverelWarned then
        mouseMoverelWarned = true
        notify("Aimbot", "mousemoverel is unavailable in this executor")
    end
end)
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
local silentFov, silentCircleEnabled = 90, false
RunService.RenderStepped:Connect(function()
    local cam = Workspace.CurrentCamera
    local radius
    if fovCircleEnabled then
        radius = aimbotFOV
    elseif silentCircleEnabled and cam then
        local vpY = cam.ViewportSize.Y
        if vpY > 0 then
            local focal = (vpY / 2) / math.tan(math.rad(cam.FieldOfView) / 2)
            radius = math.tan(math.rad(math.min(silentFov, 89))) * focal
        end
    end
    if not radius then
        if fovCircleGui then destroyFovCircle() end
        return
    end
    if not cam then return end
    local frame = ensureFovCircle()
    if not frame then return end
    local vp = cam.ViewportSize
    if vp.Y <= 0 then return end
    local diameter = math.max(radius * 2, 2)
    frame.Size = UDim2.fromOffset(diameter, diameter)
    frame.Position = UDim2.fromOffset(vp.X/2, vp.Y/2)
end)
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
local CombatTab = Window:CreateTab("Combat", 4483362458)
local RageTab = Window:CreateTab("Rage", 4483362458)
local EspTab = Window:CreateTab("ESP", 4483362458)
local TpTab = Window:CreateTab("Teleport", 4483362458)
local MoveTab = Window:CreateTab("Movement", 4483362458)
local silentAim = false
local silentPart = "Head"
local silentRMB = false 
local silentRMBHeld = false 
local silentVisibleCheck = true
local silentHookInstalled = false
local currentCam = Workspace.CurrentCamera
RunService.Heartbeat:Connect(function()
    currentCam = Workspace.CurrentCamera
    if silentRMB then
        silentRMBHeld = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
    end
end)
local hitboxTableAt, hitboxTableCache = 0, nil
local function hitboxTable()
    local now = os.clock()
    if hitboxTableCache and now - hitboxTableAt < 1 then return hitboxTableCache end
    hitboxTableAt = now
    hitboxTableCache = nil
    local w = weaponsFolder()
    local mod = w and w:FindFirstChild("ClientHitboxes")
    if not mod then return nil end
    local ok, tbl = pcall(require, mod)
    if ok and type(tbl) == "table" then hitboxTableCache = tbl end
    return hitboxTableCache
end
local hitCacheTime, aimParts, hitboxOwners = 0, {}, {}
local rayParams, rayFilter
local function rebuildHitCaches()
    local now = os.clock()
    if now - hitCacheTime < 0.25 then return end
    hitCacheTime = now
    aimParts, hitboxOwners = {}, {}
    local tbl = hitboxTable()
    if tbl and type(tbl.parts) == "table" then
        for _, entry in pairs(tbl.parts) do
            if type(entry) == "table" and entry.char then
                local part = typeof(entry.box) == "Instance" and entry.box
                if not part and type(entry.name) == "string" then
                    part = entry.char:FindFirstChild(entry.name)
                end
                if typeof(part) == "Instance" then
                    hitboxOwners[part] = entry.char
                    local set = aimParts[entry.char]
                    if not set then
                        set = {}
                        aimParts[entry.char] = set
                    end
                    if entry.name == silentPart then set.main = part end
                    set.fallback = set.fallback or part
                end
            end
        end
    end
    rayFilter = {}
    if LP.Character then table.insert(rayFilter, LP.Character) end
    for box in pairs(hitboxOwners) do table.insert(rayFilter, box) end
    if rayParams then
        rayParams.FilterDescendantsInstances = rayFilter
    else
        rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        rayParams.FilterDescendantsInstances = rayFilter
    end
end
seesFrom = function(origin, pos, char, part, visibleCheck)
    if visibleCheck == nil then visibleCheck = aimbotVisibleCheck end
    if not visibleCheck then return true end
    rebuildHitCaches()
    local hit = Workspace:Raycast(origin, pos - origin, rayParams)
    if not hit then return true end
    local inst = hit.Instance
    if part and inst == part then return true end
    if typeof(char) == "Instance" and inst:IsDescendantOf(char) then return true end
    return hitboxOwners[inst] == char
end
local function charAimPart(char)
    rebuildHitCaches()
    local set = aimParts[char]
    if set then
        local part = set.main or set.fallback
        if part and part.Parent then return part.Position end
    end
    local part = char:FindFirstChild(silentPart)
        or char:FindFirstChild("Head")
        or char:FindFirstChild("HumanoidRootPart")
    return part and part.Position or nil
end
local function aimOrigin()
    local char = LP.Character
    if not char then return nil end
    local pos = charAimPart(char)
    if pos then return pos end
    local hrp = getHrp()
    return hrp and (hrp.Position + Vector3.new(0, 1.5, 0)) or nil
end
local function silentAimVisible(char, origin, pos)
    return seesFrom(origin, pos, char, nil, silentVisibleCheck)
end
local aimCacheTime, aimCachePos, aimCacheOrigin = 0, nil, nil
local function silentAimTarget()
    local now = os.clock()
    if now - aimCacheTime < 0.05 then return aimCachePos, aimCacheOrigin end
    aimCacheTime = now
    aimCachePos, aimCacheOrigin = nil, nil
    local cam = Workspace.CurrentCamera
    local origin = aimOrigin()
    if not cam or not origin then return nil end
    local look = cam.CFrame.LookVector
    local candidates = {}
    local function consider(char)
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then return end
        local pos = charAimPart(char)
        if not pos then return end
        local dir = pos - origin
        if dir.Magnitude <= 1 then return end
        local angle = math.deg(math.acos(math.clamp(look:Dot(dir.Unit), -1, 1)))
        if angle <= silentFov then
            table.insert(candidates, { angle = angle, char = char, pos = pos })
        end
    end
    if not farmEnabled then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LP then consider(plr.Character) end
        end
    end
    if farmEnabled then
        for _, model in ipairs(farmZombies()) do
            if zombieAlive(model) then consider(model) end
        end
    elseif ESP.AI then
        for _, model in ipairs(aiCharacters()) do
            consider(model)
        end
    end
    table.sort(candidates, function(a, b) return a.angle < b.angle end)
    for _, c in ipairs(candidates) do
        if silentAimVisible(c.char, origin, c.pos) then
            aimCachePos, aimCacheOrigin = c.pos, origin
            return c.pos, origin
        end
    end
    return nil
end
local function installSilentAim()
    if silentHookInstalled then return end
    if type(hookmetamethod) ~= "function" or type(getnamecallmethod) ~= "function" then
        notify("Silent Aim", "This executor cannot hook namecall")
        return
    end
    silentHookInstalled = true
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local fire = remotes and remotes:FindFirstChild("Fire")
    local old
    old = hookmetamethod(game, "__namecall", function(self, ...)
        if silentAim and (not silentRMB or silentRMBHeld) and (self == fire or self == currentCam) then
            local method = getnamecallmethod()
            if method == "ViewportPointToRay" then
                local pos = silentAimTarget()
                if pos then
                    local cam = currentCam
                    local o = cam.CFrame.Position
                    local d = pos - o
                    if d.Magnitude > 0.1 then return Ray.new(o, d.Unit) end
                end
            elseif fire and method == "FireServer" and self == fire then
                local args = table.pack(...)
                local pos, origin = silentAimTarget()
                if pos and origin and args.n == 13 then
                    local d = pos - origin
                    if d.Magnitude > 0.1 then
                        d = d.Unit
                        args[1] = origin
                        args[2] = d
                        args[11] = origin
                        args[12] = d
                        args[13] = pos
                        return old(self, table.unpack(args, 1, 13))
                    end
                end
            end
        end
        return old(self, ...)
    end)
end
local aimbotToggle, rmbToggle, reloadToggle, ammoToggle, silentToggle, visToggle, lootToggle, collectToggle
local farmSaved = {}
local function syncToggle(toggleObj, want)
    if toggleObj and type(toggleObj.Set) == "function" then
        pcall(toggleObj.Set, toggleObj, want)
    end
end
local function pressPrompt(prompt)
    if type(fireproximityprompt) == "function" and pcall(fireproximityprompt, prompt) then
        return
    end
    pcall(function()
        prompt:InputHoldBegin()
        prompt:InputHoldEnd()
    end)
end
local function farmInteract(model)
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("ProximityPrompt") and d.Enabled then
            pressPrompt(d)
        end
    end
end
local function farmMouse(button, down)
    local cam = Workspace.CurrentCamera
    local vp = (cam and cam.ViewportSize) or Vector2.new(400, 400)
    return pcall(function()
        game:GetService("VirtualInputManager"):SendMouseButtonEvent(vp.X/2, vp.Y/2, button, down, game, 1)
    end)
end
local function farmFire()
    if not farmMouse(0, true) then
        if type(mouse1click) == "function" then pcall(mouse1click) end
        return
    end
    task.wait(0.03)
    farmMouse(0, false)
    task.wait(0.03)
    farmMouse(0, true)
end
local function farmPressE()
    if type(keypress) == "function" then
        pcall(keypress, Enum.KeyCode.E)
        pcall(keyrelease or keypress, Enum.KeyCode.E)
        return
    end
    pcall(function()
        local vim = game:GetService("VirtualInputManager")
        vim:SendKeyEvent(true, Enum.KeyCode.E, false, false)
        vim:SendKeyEvent(false, Enum.KeyCode.E, false, false)
    end)
end
local function farmVisibleTarget()
    local origin = aimOrigin()
    if not origin then return nil end
    for _, model in ipairs(farmZombies()) do
        if zombieAlive(model) then
            local part = model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart")
            if part then
                local pos = part.Position
                if (pos - origin).Magnitude <= farmRadius and silentAimVisible(model, origin, pos) then
                    return part
                end
            end
        end
    end
    return nil
end
local function doAutoFarm()
    local hrp = getHrp()
    if not hrp then return end
    if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
        farmRMB(true)
    end
    local inReach = false
    for _, model in ipairs(farmZombies()) do
        local anchor = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Head") or model.PrimaryPart
        if anchor and (anchor.Position - hrp.Position).Magnitude <= farmRadius then
            inReach = true
            farmInteract(model)
        end
    end
    if inReach then farmPressE() end
    if farmVisibleTarget() then farmFire() end
end
local function farmRMB(down)
    if farmMouse(1, down) then return end
    if down then
        if type(mouse2press) == "function" then pcall(mouse2press) end
    elseif type(mouse2release) == "function" then
        pcall(mouse2release)
    end
end
local function applyFarmSupport(on)
    aimbotEnabled = on and false or farmSaved.aimbot
    silentAim = on and true or farmSaved.silent
    if silentAim then installSilentAim() end
    aimbotVisibleCheck = on and true or farmSaved.visible
    instantReload = on and true or farmSaved.reload
    infAmmo = on and true or farmSaved.ammo
    reapplyWeaponTuning()
    if instantReload then startLoop("WeaponTune", 0.5, reapplyWeaponTuning) end
    farmRMB(on)
    farmMouse(0, on)
    autoLoot = on and true or farmSaved.loot
    autoCollect = on and true or farmSaved.collect
    if autoLoot then startLoop("AutoLoot", 0.35, doAutoLoot) else stopLoop("AutoLoot") end
    if autoCollect then startLoop("AutoCollect", 0.3, doAutoCollect) else stopLoop("AutoCollect") end
    syncToggle(lootToggle, autoLoot)
    syncToggle(collectToggle, autoCollect)
    syncToggle(aimbotToggle, aimbotEnabled)
    syncToggle(silentToggle, silentAim)
    syncToggle(visToggle, aimbotVisibleCheck)
    syncToggle(reloadToggle, instantReload)
    syncToggle(ammoToggle, infAmmo)
end
local function startFarm()
    farmSaved = {
        aimbot = aimbotEnabled,
        silent = silentAim,
        visible = aimbotVisibleCheck,
        reload = instantReload,
        ammo = infAmmo,
        loot = autoLoot,
        collect = autoCollect,
    }
    applyFarmSupport(true)
    startLoop("AutoFarm", 0.15, doAutoFarm)
end
local function stopFarm()
    stopLoop("AutoFarm")
    applyFarmSupport(false)
end
CombatTab:CreateSection("Aimbot")
aimbotToggle = CombatTab:CreateToggle({Name="Aimbot",CurrentValue=false,Flag="Aimbot",Callback=function(v) aimbotEnabled=v end})
CombatTab:CreateSlider({Name="Aimbot FOV",Range={30,400},Increment=5,Suffix="px",CurrentValue=150,Flag="AimbotFOV",Callback=function(v) aimbotFOV=v end})
CombatTab:CreateToggle({Name="FOV Circle",CurrentValue=false,Flag="FOVCircle",Callback=function(v) fovCircleEnabled=v end})
rmbToggle = CombatTab:CreateToggle({Name="Aim on RMB",CurrentValue=false,Flag="AimbotRMB",Callback=function(v) aimbotRMB=v end})
visToggle = CombatTab:CreateToggle({Name="Visible Check",CurrentValue=true,Flag="AimbotVis",Callback=function(v) aimbotVisibleCheck=v end})
CombatTab:CreateSection("Weapon")
reloadToggle = CombatTab:CreateToggle({Name="Instant Reload",CurrentValue=false,Flag="InstantReload",Callback=function(v)
    instantReload=v
    reapplyWeaponTuning()
    startLoop("WeaponTune",0.5,reapplyWeaponTuning)
end})
CombatTab:CreateToggle({Name="Rapid Fire",CurrentValue=false,Flag="RapidFire",Callback=function(v)
    rapidFire=v
    reapplyWeaponTuning()
    startLoop("WeaponTune",0.5,reapplyWeaponTuning)
end})
CombatTab:CreateSlider({Name="Rapid Fire RPM",Range={200,2000},Increment=25,Suffix="rpm",CurrentValue=1200,Flag="RapidFireRPM",Callback=function(v)
    rapidFireRPM=v
    if rapidFire then reapplyWeaponTuning() end
end})
CombatTab:CreateToggle({Name="Full Auto",CurrentValue=false,Flag="FullAuto",Callback=function(v)
    fullAuto=v
    reapplyWeaponTuning()
    startLoop("WeaponTune",0.5,reapplyWeaponTuning)
end})
ammoToggle = CombatTab:CreateToggle({Name="Inf Ammo",CurrentValue=true,Flag="InfAmmo",Callback=function(v)
    infAmmo=v
    applyInfiniteAmmo(v)
end})
local recoilTables, bloomTables = {}, {}
local gcSwept, gcTool = false, nil
local function sweepWeaponTables()
    recoilTables, bloomTables = {}, {}
    if getgc then
        for _, fn in ipairs(getgc(true)) do
            if type(fn) == "function" then
                local ok, ups = pcall(debug.getupvalues, fn)
                if ok and type(ups) == "table" then
                    for _, tbl in pairs(ups) do
                        if type(tbl) == "table" then
                            local recoil, bloom
                            pcall(function()
                                if type(tbl.Recoil) == "table" and type(tbl.Recoil.Up) == "number" then recoil = tbl.Recoil end
                                if type(tbl.Bloom) == "table" and type(tbl.Bloom.Max) == "number" then bloom = tbl.Bloom end
                            end)
                            if recoil then table.insert(recoilTables, { owner = tbl, cfg = recoil }) end
                            if bloom then table.insert(bloomTables, { owner = tbl, cfg = bloom }) end
                        end
                    end
                end
            end
        end
    end
    gcSwept = true
end
local function zeroRecoil()
    for _, e in ipairs(recoilTables) do
        pcall(function()
            setreadonly(e.owner, false)
            setreadonly(e.cfg, false)
            e.cfg.Up = 0
            e.cfg.Side = 0
            e.cfg.Return = 0
        end)
    end
end
local function zeroBloom()
    for _, e in ipairs(bloomTables) do
        pcall(function()
            setreadonly(e.owner, false)
            setreadonly(e.cfg, false)
            e.cfg.Max = 0
            e.cfg.Aim = 0
            e.cfg.Hip = 0
            e.cfg.Move = 0
            e.cfg.Air = 0
            e.cfg.PerShot = 0
        end)
    end
end
local function refreshWeaponTableCache()
    local char = LP.Character
    local tool = char and char:FindFirstChildOfClass("Tool")
    if not gcSwept or tool ~= gcTool then
        gcTool = tool
        sweepWeaponTables()
    end
end
CombatTab:CreateToggle({Name="No Recoil",CurrentValue=false,Flag="NoRecoil",Callback=function(v)
    if v then
        refreshWeaponTableCache()
        zeroRecoil()
        startLoop("NoRecoil",0.75,function()
            refreshWeaponTableCache()
            zeroRecoil()
            patchWeaponConfig()
        end)
    else
        stopLoop("NoRecoil")
    end
end})
CombatTab:CreateToggle({Name="No Spread",CurrentValue=false,Flag="NoSpread",Callback=function(v)
    if v then
        refreshWeaponTableCache()
        zeroBloom()
        startLoop("NoSpread",0.75,function()
            refreshWeaponTableCache()
            zeroBloom()
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
RageTab:CreateSection("Silent Aim")
silentToggle = RageTab:CreateToggle({Name="Silent Aim",CurrentValue=false,Flag="SilentAim",Callback=function(v)
    silentAim=v
    if v then installSilentAim() end
end})
RageTab:CreateSlider({Name="Rage FOV",Range={5,180},Increment=5,Suffix="deg",CurrentValue=90,Flag="SilentFOV",Callback=function(v)
    silentFov=v
end})
RageTab:CreateToggle({Name="FOV Circle",CurrentValue=false,Flag="RageFOVCircle",Callback=function(v) silentCircleEnabled=v end})
RageTab:CreateToggle({Name="Aim on RMB",CurrentValue=false,Flag="SilentRMB",Callback=function(v) silentRMB=v end})
RageTab:CreateToggle({Name="Visible Check",CurrentValue=true,Flag="SilentVis",Callback=function(v) silentVisibleCheck=v end})
RageTab:CreateDropdown({Name="Hit Part",Options={"Head","HumanoidRootPart","UpperTorso","LowerTorso"},CurrentOption={"Head"},MultipleOptions=false,Flag="SilentPart",Callback=function(v)
    silentPart = (type(v)=="table" and v[1]) or v
end})
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
EspTab:CreateToggle({Name="AIs",CurrentValue=false,Flag="ESP AIs",Callback=function(v)
    ESP.AI=v
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
EspTab:CreateSection("Loot")
EspTab:CreateToggle({Name="ATM ESP",CurrentValue=false,Flag="ESP Money",Callback=function(v)
    ESP.Money=v
    if ESP.Enabled then refreshESP() end
end})
lootToggle = EspTab:CreateToggle({Name="Auto Loot",CurrentValue=false,Flag="AutoLoot",Callback=function(v)
    autoLoot=v
    if v then startLoop("AutoLoot",0.35,doAutoLoot) else stopLoop("AutoLoot") end
end})
EspTab:CreateSlider({Name="Loot Radius",Range={10,300},Increment=5,Suffix="m",CurrentValue=60,Flag="LootRadius",Callback=function(v)
    autoLootRadius=v
end})
collectToggle = EspTab:CreateToggle({Name="Auto Collect",CurrentValue=false,Flag="AutoCollect",Callback=function(v)
    autoCollect=v
    if v then startLoop("AutoCollect",0.3,doAutoCollect) else stopLoop("AutoCollect") end
end})
EspTab:CreateSlider({Name="Collect Radius",Range={5,40},Increment=1,Suffix="m",CurrentValue=20,Flag="CollectRadius",Callback=function(v)
    collectRadius=v
end})
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
MoveTab:CreateSection("Movement")
MoveTab:CreateToggle({Name="Speed",CurrentValue=false,Flag="Speed",Callback=function(v)
    speedEnabled=v
    if v then
        startLoop("Speed",0.2,applySpeed)
    else
        stopLoop("Speed")
        applySpeed()
    end
end})
MoveTab:CreateSlider({Name="Speed Value",Range={16,200},Increment=2,Suffix="ws",CurrentValue=45,Flag="SpeedValue",Callback=function(v)
    speedValue=v
    if speedEnabled then applySpeed() end
end})
MoveTab:CreateToggle({Name="Inf Stamina",CurrentValue=false,Flag="InfStamina",Callback=function(v)
    infStamina=v
    if v then
        startLoop("Stamina",0.25,stompStamina)
    else
        stopLoop("Stamina")
        restoreStamina()
    end
end})
MoveTab:CreateToggle({Name="Bunny Hop",CurrentValue=false,Flag="BunnyHop",Callback=function(v)
    bhop=v
    if v then
        startLoop("Bhop",0.05,function()
            local h = liveHum()
            if h then h.Jump = true end
        end)
    else
        stopLoop("Bhop")
    end
end})
UserInputService.JumpRequest:Connect(function()
    if not bhop then return end
    local h = liveHum()
    if h then h.Jump = true end
end)
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
local function shutdown()
    aimbotEnabled = false
    silentAim = false
    spinbot = false
    farmEnabled = false
    bhop = false
    for key in pairs(loopTokens) do loopTokens[key] = nil end
    ESP.Enabled = false
    ESP.AI = false
    pcall(function()
        for _, list in ipairs({ ESP.playerEntries, ESP.vehicleEntries, ESP.aiEntries, ESP.moneyEntries, ESP.atmEntries }) do
            for key, entry in pairs(list) do
                pcall(destroyEntry, entry)
                list[key] = nil
            end
        end
    end)
    pcall(destroyFovCircle)
    pcall(function() RunService:UnbindFromRenderStep("UrbanAimbot2") end)
    pcall(farmRMB, false)
    pcall(farmMouse, 0, false)
    instantReload = false
    rapidFire = false
    fullAuto = false
    infAmmo = false
    speedEnabled = false
    pcall(reapplyWeaponTuning)
    pcall(applySpeed)
    pcall(restoreStamina)
    pcall(function()
        local pg = LP:FindFirstChildOfClass("PlayerGui")
        if not pg then return end
        for _, name in ipairs({ "UrbanReloadESP", "UrbanReloadFOV" }) do
            local gui = pg:FindFirstChild(name)
            if gui then gui:Destroy() end
        end
    end)
    pcall(function()
        local host = (gethui and gethui()) or LP:FindFirstChildOfClass("PlayerGui")
        local sg = host and host:FindFirstChild("Rayfield")
        if sg then sg:Destroy() end
    end)
end
getgenv().__UrbanReloadShutdown = shutdown
print("[UrbanReload] v3 loaded - tabs: Combat, Rage, ESP, Teleport, Movement")
notify("Loaded v3", "Urban Reload cheat ready.")
