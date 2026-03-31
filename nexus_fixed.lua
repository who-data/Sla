-- ============================================================
-- MM2 Script — x2zu UI  (bugs corrigidos)
-- ============================================================

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local Workspace         = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera
local Mouse       = LocalPlayer:GetMouse()

local function GetChar()  return LocalPlayer.Character end
local function GetHRP()   local c = GetChar(); return c and c:FindFirstChild("HumanoidRootPart") end
local function GetHum()   local c = GetChar(); return c and c:FindFirstChildOfClass("Humanoid") end

-- ============================================================
-- STATE
-- ============================================================
local State = {
    WalkSpeed=16, JumpPower=50, ChangeWalkSpeed=false, ChangeJumpPower=false,
    Noclip=false, Swim=false, Float=false, CameraUnlocked=false, TeleportTool=false,
    StabReachRange=10, StabReach=false, KillAuraRange=10, KillAura=false,
    KnifeSilentAim=false, KSAPrediction="Static",
    GunSilentAim=false, GSAPrediction="Smart", VisibilityCheck=true,
    AutoEquipGun=true, TriggerBot=false, TriggerCondition="Visible",
    FlingTarget=nil, LoopFlingPlayer=false, LoopFlingAll=false,
    AutoGrabGun=false, AutoStealGun=false, PlayersToKill={},
    MuteRadios=false, DestroyCoins=false, DestroyDeadBody=false,
    HideCoins=false, DestroyBarriers=false, NoGUI=false,
    SecondLife=false, HiddenGUIS={},
    ShowMurderer=false, ShowSheriff=false, ShowInnocent=false,
    ShowDead=false, ShowGun=false, ShowFill=true, ShowOutline=true,
    ESPMurderer=false, ESPSheriff=false, ESPInnocent=false, ESPTextSize=14,
    NotifyMurderer=false, NotifyMurdererPerk=false, NotifySheriff=false, NotifyGunDrop=false,
    Disable3DRendering=false,
}

-- TrollState: variáveis do Trolling em tabela separada (evita estourar limite de locals)
local TrollState = {
    AutoBreakGun      = false,
    AntiFling         = false,
    AntiFlingParts    = {},
    MuteOtherRadios   = false,
    DisableBank       = false,
    AntiAFK           = false,
    AntiAFKConn       = nil,
    SpamFakeBomb      = false,
    AutoFakeBombClutch = false,
    MuteCoinsSound    = false,
    _antiFlingConn    = nil,
    _bombClutchConn   = nil,
    -- Auto-actions
    EndRoundWhenDead    = false,
    ServerHopWhenEmpty  = false,
    ServerHopAfter      = 10,   -- min players before hop
    RejoinWhenKicked    = false,
}


local conns = {}
local function Conn(tag, c)
    if conns[tag] then conns[tag]:Disconnect() end
    conns[tag] = c
end

-- ============================================================
-- FLOATING BUTTON HELPERS
-- ============================================================
local CoreGui = game:GetService("CoreGui")

local function AddCorner(inst, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r); c.Parent = inst
    return c
end
local function AddStroke(inst, color, thick)
    local s = Instance.new("UIStroke")
    s.Color = color; s.Thickness = thick
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = inst; return s
end
local function MakeDraggable(frame)
    local dragging, dragInput, dragStart, startPos
    local function startDrag(input)
        dragging = true; dragStart = input.Position; startPos = frame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false end
        end)
    end
    frame.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            startDrag(i)
        end
    end)
    frame.InputChanged:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
            dragInput = i
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and i == dragInput then
            local delta = i.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset+delta.X, startPos.Y.Scale, startPos.Y.Offset+delta.Y)
        end
    end)
end

-- ============================================================
-- INVISIBLE STATE
-- ============================================================
local InvisActive    = false
local InvisFrame, InvisBtn, InvisStroke

-- ============================================================
-- DESYNC STATE
-- ============================================================
local desync_on    = false
local ghostPart    = nil
local desyncChair  = nil
local desyncWeld   = nil
local DesyncFrame, DesyncBtn, DesyncStroke

-- ============================================================
-- SHOOT BUTTON STATE
-- ============================================================
local ShootGui, ShootButton, ShootStroke

-- ============================================================
-- ROLE CACHE — atualizado por evento nativo
-- ============================================================
local RoleCache       = {}
local Gameplay        = { Murderer = nil, Sheriff = nil }
local IsRoundStarted  = false
local IsRoundStarting = false

local function RefreshRoleCache()
    local ok, data = pcall(function()
        return ReplicatedStorage:FindFirstChild("GetPlayerData", true):InvokeServer()
    end)
    if not (ok and data) then return end
    RoleCache = {}
    Gameplay.Murderer = nil
    Gameplay.Sheriff  = nil
    for name, d in pairs(data) do
        if type(d) == "table" and d.Role and d.Role ~= "" then
            RoleCache[name] = d.Role
            if d.Role == "Murderer" then Gameplay.Murderer = Players:FindFirstChild(name) end
            if d.Role == "Sheriff"  then Gameplay.Sheriff  = Players:FindFirstChild(name) end
        end
    end
end

local function GetCachedRole(name)
    return RoleCache[name or LocalPlayer.Name]
end

-- Eventos nativos
pcall(function()
    local rem = ReplicatedStorage:WaitForChild("Remotes", 5)
    if not rem then return end
    local gp = rem:FindFirstChild("Gameplay")
    if not gp then return end
    local rs = gp:FindFirstChild("RoundStart")
    if rs then rs.OnClientEvent:Connect(function()
        IsRoundStarted = true; IsRoundStarting = false
        task.spawn(RefreshRoleCache)
    end) end
    local vs = gp:FindFirstChild("VictoryScreen")
    if vs then vs.OnClientEvent:Connect(function()
        IsRoundStarted = false; IsRoundStarting = false
        RoleCache = {}; Gameplay.Murderer = nil; Gameplay.Sheriff = nil
    end) end
    local pr = gp:FindFirstChild("PreRound")
    if pr then pr.OnClientEvent:Connect(function()
        IsRoundStarting = true; IsRoundStarted = false
        task.spawn(RefreshRoleCache)
    end) end
end)

-- Detecta também via ferramenta (knife/gun) como o e0 faz
Workspace.DescendantAdded:Connect(function(d)
    if d:IsA("Tool") then
        local name = d.Name
        local owner = d:FindFirstAncestorOfClass("Player")
            or Players:GetPlayerFromCharacter(d:FindFirstAncestorOfClass("Model"))
        if not owner then return end
        if name == "Knife" then
            Gameplay.Murderer = owner
            RoleCache[owner.Name] = "Murderer"
        elseif name == "Gun" then
            Gameplay.Sheriff = owner
            RoleCache[owner.Name] = "Sheriff"
        end
    end
end)

task.spawn(function()
    local ok, t = pcall(function()
        return ReplicatedStorage.Remotes.Extras.GetTimer:InvokeServer()
    end)
    t = (ok and type(t) == "number") and t or 0
    IsRoundStarted  = t < 180 and t > 0
    IsRoundStarting = t == 180
    if IsRoundStarted or IsRoundStarting then RefreshRoleCache() end
end)

-- ============================================================
-- GAME HELPERS
-- ============================================================
local function IsAlive(plr)
    plr = plr or LocalPlayer
    local c = plr.Character
    local h = c and c:FindFirstChildOfClass("Humanoid")
    return h and h.Health > 0 or false
end

local function GetMurderer()
    if Gameplay.Murderer and Gameplay.Murderer.Character then return Gameplay.Murderer end
    for name, role in pairs(RoleCache) do
        if role == "Murderer" then
            local p = Players:FindFirstChild(name)
            if p then Gameplay.Murderer = p; return p end
        end
    end
end

local function GetSheriff()
    if Gameplay.Sheriff and Gameplay.Sheriff.Character then return Gameplay.Sheriff end
    for name, role in pairs(RoleCache) do
        if role == "Sheriff" then
            local p = Players:FindFirstChild(name)
            if p then Gameplay.Sheriff = p; return p end
        end
    end
end

local function GetNearestPlayer(range)
    local hrp = GetHRP(); if not hrp then return end
    local best, bd = nil, range or math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and IsAlive(p) and p.Character then
            local r = p.Character:FindFirstChild("HumanoidRootPart")
            if r then
                local d = (hrp.Position - r.Position).Magnitude
                if d < bd then bd = d; best = p end
            end
        end
    end
    return best
end

local function CanSee(p1, p2)
    local c1 = p1 and p1.Character
    local c2 = p2 and p2.Character
    if not (c1 and c2) then return false end
    local r1 = c1:FindFirstChild("HumanoidRootPart")
    local r2 = c2:FindFirstChild("HumanoidRootPart")
    if not (r1 and r2) then return false end
    local rp = RaycastParams.new()
    rp.FilterDescendantsInstances = {c1, c2}
    rp.FilterType = Enum.RaycastFilterType.Exclude
    return not Workspace:Raycast(r1.Position, (r2.Position - r1.Position), rp)
end

-- ============================================================
-- KNIFE — lógica exata do e0: puxa HRP do target para cima da faca + firetouchinterest
-- ============================================================
local function GetKnifeInChar()
    local c = GetChar(); if not c then return end
    for _, t in ipairs(c:GetChildren()) do
        if t:IsA("Tool") and t.Name == "Knife" then return t end
    end
end

local function EquipKnifeFromBackpack()
    local c = GetChar(); if not c then return false end
    local hum = GetHum(); if not hum then return false end
    if GetKnifeInChar() then return true end
    local knife = LocalPlayer.Backpack:FindFirstChild("Knife")
    if knife then
        hum:EquipTool(knife)
        task.wait(0.08)
        return true
    end
    return false
end

-- Stab remoto (igual e0: u25.Knife.Stab:FireServer())
local function DoStab()
    local knife = GetKnifeInChar()
    if knife then
        local stab = knife:FindFirstChild("Stab")
        if stab then pcall(function() stab:FireServer() end) end
    end
end

-- KillPlayer: equipa faca, puxa HRP, HandleTouched + firetouchinterest
local function KillPlayer(name, doStab)
    task.spawn(function()
        local p = Players:FindFirstChild(name)
        if not (p and IsAlive(p) and p.Character) then return end
        if GetCachedRole() ~= "Murderer" then return end
        local role = RoleCache[p.Name]
        if role == "Murderer" or role == "Lobby" then return end
        EquipKnifeFromBackpack()
        local knife = GetKnifeInChar()
        if not knife then return end
        local handle = knife:FindFirstChild("Handle")
        if not handle then return end
        local tHRP = p.Character:FindFirstChild("HumanoidRootPart")
        if not tHRP then return end
        tHRP.CFrame = handle.CFrame
        tHRP.AssemblyLinearVelocity = Vector3.zero
        tHRP.AssemblyAngularVelocity = Vector3.zero
        task.wait(0.05)
        local remote = GetKnifeRemote()
        if remote then pcall(function() remote:FireServer(tHRP) end) end
        if doStab then DoStab() end
        pcall(firetouchinterest, tHRP, handle, 1)
        pcall(firetouchinterest, tHRP, handle, 0)
    end)
end

-- GetKnifeRemote: busca HandleTouched dentro da Knife (README)
local function GetKnifeRemote()
    local c = GetChar()
    local knife = (c and c:FindFirstChild("Knife"))
               or LocalPlayer.Backpack:FindFirstChild("Knife")
    if knife then
        return knife:FindFirstChild("HandleTouched", true)
    end
    return nil
end

-- KillAll: equipa faca, puxa HRP do alvo sobre o Handle, FireServer via HandleTouched + firetouchinterest
local function KillAll()
    task.spawn(function()
        if GetCachedRole() ~= "Murderer" then return end
        EquipKnifeFromBackpack()
        local knife = GetKnifeInChar()
        if not knife then return end
        local handle = knife:FindFirstChild("Handle")
        if not handle then return end
        local remote = GetKnifeRemote()
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and IsAlive(p) and p.Character then
                local role = RoleCache[p.Name]
                if role == "Innocent" or role == "Sheriff" or role == "Hero" then
                    local tHRP = p.Character:FindFirstChild("HumanoidRootPart")
                    if tHRP then
                        tHRP.CFrame = handle.CFrame
                        tHRP.AssemblyLinearVelocity = Vector3.zero
                        tHRP.AssemblyAngularVelocity = Vector3.zero
                        task.wait(0.05)
                        -- Método primário: HandleTouched (README)
                        if remote then
                            pcall(function() remote:FireServer(tHRP) end)
                        end
                        -- Fallback: firetouchinterest
                        pcall(firetouchinterest, tHRP, handle, 1)
                        pcall(firetouchinterest, tHRP, handle, 0)
                        DoStab()
                        task.wait(0.08)
                    end
                end
            end
        end
    end)
end

local function KillSelected(list)
    for _, name in ipairs(list) do KillPlayer(name, true) end
end

-- ============================================================
-- SECOND LIFE (GODMODE) — README: HealthChanged instantâneo
-- ============================================================
local secondLifeConnection = nil

local function ApplySecondLife(state)
    if state then
        local function setupGodmode(character)
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                if secondLifeConnection then secondLifeConnection:Disconnect() end
                secondLifeConnection = humanoid.HealthChanged:Connect(function()
                    if humanoid.Health < humanoid.MaxHealth then
                        humanoid.Health = humanoid.MaxHealth
                    end
                end)
            end
        end
        if LocalPlayer.Character then setupGodmode(LocalPlayer.Character) end
        LocalPlayer.CharacterAdded:Connect(function(character)
            task.wait(0.5)
            setupGodmode(character)
        end)
    else
        if secondLifeConnection then
            secondLifeConnection:Disconnect()
            secondLifeConnection = nil
        end
    end
end

-- ============================================================
-- GUN SA + KNIFE SA — sistema do README
-- Gun  SA : workspace:Raycast hook redireciona direção para murder
-- Knife SA: hookKnifeThrown substitui FireServer do KnifeThrown
--           + Raycast hook para arremesso
-- ============================================================
local closesthitpart  = nil   -- HRP do murder (Gun SA)
local closestKnifePart = nil  -- HRP mais próximo ao centro (Knife SA)
local knifeEquipped   = false
local murder          = nil   -- player com faca (para Knife SA excluir)
local originalKnifeThrown = nil

-- Detecta quem é o murder pelo item Knife no personagem/backpack
local function hasKnife(player)
    if not player or not player.Character then return false end
    for _, item in pairs(player.Backpack:GetChildren()) do
        if item:IsA("Tool") then
            local n = item.Name:lower()
            if n:find("knife") or n:find("fac") or n == "knife" or n == "murder knife" then return true end
        end
    end
    for _, item in pairs(player.Character:GetChildren()) do
        if item:IsA("Tool") then
            local n = item.Name:lower()
            if n:find("knife") or n:find("fac") or n == "knife" or n == "murder knife" then return true end
        end
    end
    return false
end

task.spawn(function()
    while true do
        task.wait(1)
        local found = nil
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and hasKnife(p) then found = p; break end
        end
        murder = found
    end
end)

-- Retorna HRP do murder para Gun SA
local function getGunTarget()
    if not State.GunSilentAim then return nil end
    local myRole = GetCachedRole()
    if myRole ~= "Sheriff" and myRole ~= "Hero" then return nil end
    local m = GetMurderer()
    if not (m and m.Character) then return nil end
    local hrp = m.Character:FindFirstChild("HumanoidRootPart")
    local hum = m.Character:FindFirstChildOfClass("Humanoid")
    if hrp and hum and hum.Health > 0 then return hrp end
    return nil
end

local function getdirection(origin, position)
    return (position - origin).Unit
end

-- Retorna HRP mais próximo ao centro da tela para Knife SA (exclui murder)
local function getclosestplayer()
    if not State.KnifeSilentAim then return nil end
    if not knifeEquipped then return nil end
    local vp = Camera.ViewportSize
    local center = Vector2.new(vp.X/2, vp.Y/2)
    local best, bd = nil, math.huge
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p ~= murder and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            if hrp and hum and hum.Health > 0 then
                local sp, on = Camera:WorldToViewportPoint(hrp.Position)
                if on then
                    local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                    if d < bd then bd = d; best = hrp end
                end
            end
        end
    end
    return best
end

-- hookKnifeThrown: substitui FireServer do KnifeThrown para redirecionar ao alvo
local function hookKnifeThrown()
    local character = LocalPlayer.Character
    if not character then return end
    local knifeTool = character:FindFirstChild("Knife") or LocalPlayer.Backpack:FindFirstChild("Knife")
    if not knifeTool then return end
    local knifeEvents = knifeTool:FindFirstChild("Events")
    if not knifeEvents then return end
    local knifeThrownEvent = knifeEvents:FindFirstChild("KnifeThrown")
    if not knifeThrownEvent then return end
    if not originalKnifeThrown then originalKnifeThrown = knifeThrownEvent.FireServer end
    knifeThrownEvent.FireServer = function(self, ...)
        local args = {...}
        if closestKnifePart and knifeEquipped and State.KnifeSilentAim then
            local targetPos = closestKnifePart.Position
            local characterPos = character:GetPivot().Position
            local direction = (targetPos - characterPos).Unit
            local newCFrame = CFrame.new(characterPos, characterPos + direction)
            if #args >= 1 then args[1] = newCFrame end
        end
        return originalKnifeThrown(self, unpack(args))
    end
end

-- Heartbeat: atualiza closesthitpart, closestKnifePart, knifeEquipped
RunService.Heartbeat:Connect(function()
    closesthitpart   = getGunTarget()
    closestKnifePart = getclosestplayer()
    knifeEquipped    = hasKnife(LocalPlayer)
end)

-- CharacterAdded: reconecta hookKnifeThrown e atualiza knifeEquipped
LocalPlayer.CharacterAdded:Connect(function(character)
    character.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            local n = child.Name:lower()
            if n:find("knife") or n:find("fac") or n == "knife" then
                knifeEquipped = true
                hookKnifeThrown()
            end
        end
    end)
    character.ChildRemoved:Connect(function(child)
        if child:IsA("Tool") then
            local n = child.Name:lower()
            if n:find("knife") or n:find("fac") or n == "knife" then
                knifeEquipped = false
            end
        end
    end)
    task.wait(0.5)
    hookKnifeThrown()
end)

-- hookmetamethod: workspace:Raycast redirect — Gun SA e Knife SA
local oldnamecall
oldnamecall = hookmetamethod(game, "__namecall", function(...)
    local method    = getnamecallmethod()
    local arguments = {...}
    local self      = arguments[1]

    -- Gun Silent Aim: redireciona direção do Raycast para o HRP do murder
    if self == workspace and not checkcaller() and method == "Raycast" and State.GunSilentAim then
        local hitpart = closesthitpart
        if hitpart then
            local origin    = arguments[2]
            local direction = getdirection(origin, hitpart.Position) * 1000
            arguments[3]    = direction
            return oldnamecall(unpack(arguments))
        end
    end

    -- Knife Silent Aim: redireciona direção do Raycast para o HRP mais próximo
    if self == workspace and not checkcaller() and method == "Raycast" and State.KnifeSilentAim and knifeEquipped then
        local hitpart = closestKnifePart
        if hitpart then
            local origin    = arguments[2]
            local direction = getdirection(origin, hitpart.Position) * 1000
            arguments[3]    = direction
            return oldnamecall(unpack(arguments))
        end
    end

    return oldnamecall(...)
end)

-- ============================================================
-- GUN / SHOOT
-- ============================================================
local function SilentAimResolver()
    local m = GetMurderer()
    if not (m and m.Character) then return nil end
    local torso = m.Character:FindFirstChild("UpperTorso") or m.Character:FindFirstChild("HumanoidRootPart")
    if not torso then return nil end
    local pos = torso.Position
    local vel = torso.AssemblyLinearVelocity
    if State.GSAPrediction == "Smart" and vel.Magnitude > 0 then
        local hum = m.Character:FindFirstChildOfClass("Humanoid")
        local mv  = hum and hum.MoveDirection or Vector3.zero
        local adj = vel.Unit * (torso.Velocity.Magnitude / 17) + mv
        adj = Vector3.new(adj.X, math.clamp(adj.Y, -2, 2.5), adj.Z)
        pos = pos + adj
    elseif State.GSAPrediction == "Stable" then
        pos = pos + vel * 0.1
    end
    return pos
end

local function EquipGun()
    local c = GetChar(); if not c then return nil end
    for _, t in ipairs(c:GetChildren()) do
        if t:IsA("Tool") and t.Name == "Gun" then return t end
    end
    local gun = LocalPlayer.Backpack:FindFirstChild("Gun")
    if gun and State.AutoEquipGun then
        local hum = GetHum()
        if hum then hum:EquipTool(gun); task.wait(0.05) end
        return GetChar() and GetChar():FindFirstChild("Gun")
    end
end

-- ShootGun: gun.Shoot:FireServer(CFrame origin, CFrame dest) — exato do README
-- O hook do Raycast já redireciona o tiro quando GunSilentAim está ativo
local function ShootGun(targetPos)
    if not targetPos then return end
    task.spawn(function()
        local c = GetChar(); if not c then return end
        local gun = c:FindFirstChild("Gun")
        if not gun then gun = EquipGun() end
        if not gun then return end
        local shoot = gun:FindFirstChild("Shoot")
        if not shoot then return end
        local args = {CFrame.new(Camera.CFrame.Position, targetPos), CFrame.new(targetPos)}
        pcall(function() shoot:FireServer(unpack(args)) end)
    end)
end

-- ShootMurderer: segue o murderer em tempo real 5 studs atrás via Heartbeat,
-- atira assim que tiver gun equipada, depois volta à posição original.
local _shootMurderBusy = false
local function ShootMurderer()
    if _shootMurderBusy then return end
    task.spawn(function()
        _shootMurderBusy = true
        local m = GetMurderer()
        if not (m and m.Character) then _shootMurderBusy = false; return end

        local myHRP = GetHRP(); if not myHRP then _shootMurderBusy = false; return end
        local gun = GetChar() and GetChar():FindFirstChild("Gun")
        if not gun then gun = EquipGun() end
        if not gun then _shootMurderBusy = false; return end

        local origCF = myHRP.CFrame
        local followActive = true

        -- Heartbeat: posiciona 5 studs atrás do murderer em tempo real
        local followConn = RunService.Heartbeat:Connect(function()
            if not followActive then return end
            local mChar = m and m.Character
            local mHRP  = mChar and mChar:FindFirstChild("HumanoidRootPart")
            if not mHRP or not myHRP or not myHRP.Parent then
                followActive = false; return
            end
            -- 5 studs na direção oposta ao LookVector do murderer
            local behind = mHRP.CFrame * CFrame.new(0, 0, 5)
            myHRP.CFrame = behind
        end)

        -- Segue por até 1.5s tentando travar o tiro
        local deadline = tick() + 1.5
        local shot = false
        while tick() < deadline and followActive do
            local mChar = m and m.Character
            local mHRP  = mChar and mChar:FindFirstChild("HumanoidRootPart")
            if mHRP and myHRP and myHRP.Parent then
                local dist = (myHRP.Position - mHRP.Position).Magnitude
                if dist <= 8 then
                    ShootGun(SilentAimResolver())
                    shot = true
                    break
                end
            end
            task.wait(0.05)
        end

        -- Se não conseguiu chegar perto, atira mesmo assim
        if not shot then ShootGun(SilentAimResolver()) end

        followActive = false
        followConn:Disconnect()
        task.wait(0.15)

        -- Volta à posição original
        if myHRP and myHRP.Parent then myHRP.CFrame = origCF end
        _shootMurderBusy = false
    end)
end

-- ============================================================
-- GUN DROP
-- ============================================================
local function FindGunDrop()
    for _, d in ipairs(Workspace:GetDescendants()) do
        if d.Name == "GunDrop" and d:IsA("BasePart") then return d end
    end
end

local function GrabGun()
    local hrp = GetHRP(); if not hrp then return end
    local drop = FindGunDrop(); if not drop then return end
    task.wait(0.1)
    pcall(firetouchinterest, hrp, drop, 0)
    pcall(firetouchinterest, hrp, drop, 1)
end

-- ============================================================
-- FLING — lógica exata do e0 (SFBasePart + BodyVelocity)
-- ============================================================
local _IsFlinging = false

local function Fling(targetPlayer)
    if not (targetPlayer and targetPlayer.Character) then return end
    pcall(function()
        local tChar = targetPlayer.Character
        local tHum  = tChar:FindFirstChildOfClass("Humanoid")
        local tHRP  = tHum and tHum.RootPart
        local tHead = tChar:FindFirstChild("Head")
        local tAcc  = tChar:FindFirstChildOfClass("Accessory")
        local tHnd  = tAcc and tAcc:FindFirstChild("Handle")

        local myChar = GetChar(); if not myChar then return end
        local myHum  = GetHum(); if not myHum then return end
        local myHRP  = GetHRP(); if not myHRP then return end

        -- Salva posição original (exato como e0)
        if myHRP.Velocity.Magnitude < 50 then
            getgenv()._FlingOldPos = myHRP.CFrame
        end

        local oldFPDH = Workspace.FallenPartsDestroyHeight
        local oldCamSubj = Camera.CameraSubject

        -- Aponta câmera
        Camera.CameraSubject = tHead or tHum or myHum

        -- BodyVelocity como e0
        local bv = Instance.new("BodyVelocity")
        bv.Name     = "EpixVel"
        bv.Parent   = myHRP
        bv.Velocity  = Vector3.new(9e8, 9e8, 9e8)
        bv.MaxForce  = Vector3.new(1/0, 1/0, 1/0)
        myHum:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
        Workspace.FallenPartsDestroyHeight = 0/0

        -- FPos: posiciona meu HRP sobre a parte alvo + aplica velocidade
        local function FPos(part, offset, angle)
            local cf = CFrame.new(part.Position) * offset * angle
            myHRP.CFrame = cf
            myChar:SetPrimaryPartCFrame(cf)
            myHRP.Velocity    = Vector3.new(9e7, 9e8, 9e7)
            myHRP.RotVelocity = Vector3.new(9e8, 9e8, 9e8)
        end

        -- SFBasePart: loop de fling até velocidade alta ou timeout
        local function SFBasePart(part)
            local startT = tick()
            local timeout = 2
            local ang = 0
            while myHRP and tHum do
                local vel = part.Velocity.Magnitude
                if vel >= 50 then
                    FPos(part, CFrame.new(0, 1.5, tHum.WalkSpeed),           CFrame.Angles(math.rad(90),0,0)); task.wait()
                    FPos(part, CFrame.new(0,-1.5,-tHum.WalkSpeed),           CFrame.Angles(0,0,0));            task.wait()
                    FPos(part, CFrame.new(0, 1.5, tHum.WalkSpeed),           CFrame.Angles(math.rad(90),0,0)); task.wait()
                    FPos(part, CFrame.new(0, 1.5, tHRP and tHRP.Velocity.Magnitude/1.25 or 1), CFrame.Angles(math.rad(90),0,0)); task.wait()
                    FPos(part, CFrame.new(0,-1.5,-(tHRP and tHRP.Velocity.Magnitude/1.25 or 1)), CFrame.Angles(0,0,0));          task.wait()
                    FPos(part, CFrame.new(0,-1.5,0), CFrame.Angles(math.rad(90),0,0));   task.wait()
                    FPos(part, CFrame.new(0,-1.5,0), CFrame.Angles(0,0,0));               task.wait()
                    FPos(part, CFrame.new(0,-1.5,0), CFrame.Angles(math.rad(-90),0,0));  task.wait()
                    FPos(part, CFrame.new(0,-1.5,0), CFrame.Angles(0,0,0));               task.wait()
                else
                    ang = ang + 100
                    local md = tHum.MoveDirection
                    local s  = vel / 1.25
                    FPos(part, CFrame.new(0,1.5,0)     + md*s, CFrame.Angles(math.rad(ang),0,0)); task.wait()
                    FPos(part, CFrame.new(0,-1.5,0)    + md*s, CFrame.Angles(math.rad(ang),0,0)); task.wait()
                    FPos(part, CFrame.new(2.25,1.5,-2.25) + md*s, CFrame.Angles(math.rad(ang),0,0)); task.wait()
                    FPos(part, CFrame.new(-2.25,-1.5,2.25) + md*s, CFrame.Angles(math.rad(ang),0,0)); task.wait()
                    FPos(part, CFrame.new(0,1.5,0)  + md, CFrame.Angles(math.rad(ang),0,0)); task.wait()
                    FPos(part, CFrame.new(0,-1.5,0) + md, CFrame.Angles(math.rad(ang),0,0)); task.wait()
                end
                -- break conditions
                if part.Velocity.Magnitude > 500
                    or part.Parent ~= tChar
                    or tHum.Sit
                    or myHum.Health <= 0
                    or tick() > startT + timeout then
                    break
                end
            end
        end

        -- Escolhe parte alvo (exato como e0)
        local target = tHRP or tHead or tHnd
        if target then SFBasePart(target) end

        bv:Destroy()
        myHum:SetStateEnabled(Enum.HumanoidStateType.Seated, true)

        -- Protege de morte durante retorno
        myHum.BreakJointsOnDeath = false
        myHum.Health = myHum.MaxHealth

        -- Volta câmera
        Camera.CameraSubject = myHum

        -- Volta posição (exato como e0)
        local oldPos = getgenv()._FlingOldPos
        if oldPos then
            local attempts = 0
            repeat
                attempts = attempts + 1
                local cf = oldPos * CFrame.new(0, 0.5, 0)
                myHRP.CFrame = cf
                myChar:SetPrimaryPartCFrame(cf)
                myHum:ChangeState(Enum.HumanoidStateType.GettingUp)
                myHum.Health = myHum.MaxHealth
                for _, p in ipairs(myChar:GetChildren()) do
                    if p:IsA("BasePart") then
                        p.Velocity = Vector3.zero
                        p.RotVelocity = Vector3.zero
                    end
                end
                task.wait()
            until (myHRP.Position - oldPos.p).Magnitude < 25 or attempts > 30
        end

        myHum.BreakJointsOnDeath = true
        Workspace.FallenPartsDestroyHeight = oldFPDH
        Camera.CameraSubject = oldCamSubj
    end)
end

local function FlingKill(target)
    if target == "All" then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and IsAlive(p) then
                Fling(p)
            end
        end
    else
        local plr = type(target) == "string" and Players:FindFirstChild(target) or target
        if plr and plr ~= LocalPlayer then Fling(plr) end
    end
end

-- ============================================================
-- BAG FULL — exato do e0
-- ============================================================
local function IsCoinBagFull()
    local ok, v = pcall(function()
        local mg = LocalPlayer.PlayerGui.MainGUI
        if mg.Game:FindFirstChild("CoinBags") then
            return mg.Game.CoinBags.Container.Coin.Full.Visible
        else
            return mg.Lobby.Dock.CoinBags.Container.Coin.FullBagIcon.Visible
        end
    end)
    return ok and v or false
end

local function IsBeachBallBagFull()
    local ok, v = pcall(function()
        local mg = LocalPlayer.PlayerGui.MainGUI
        if mg.Game:FindFirstChild("CoinBags") then
            return mg.Game.CoinBags.Container.BeachBall.Full.Visible
        else
            return mg.Lobby.Dock.CoinBags.Container.BeachBall.FullBagIcon.Visible
        end
    end)
    return ok and v or false
end

local function IsBagFull(coinType)
    coinType = coinType or "Both"
    if coinType == "Coin"      then return IsCoinBagFull()
    elseif coinType == "BeachBall" then return IsBeachBallBagFull()
    else
        local c = IsCoinBagFull()
        if c then return IsBeachBallBagFull() end
        return false
    end
end

-- ============================================================
-- TELEPORT
-- ============================================================
local function TeleportTo(loc, playerName)
    local hrp = GetHRP(); if not hrp then return end
    if loc == "Lobby" then
        -- Usa spawns do lobby se disponível
        local lobby = Workspace:FindFirstChild("Lobby", true)
        if lobby then
            local spawns = lobby:FindFirstChild("Spawns")
            local pts    = spawns and spawns:GetChildren()
            if pts and #pts > 0 then
                hrp.CFrame = CFrame.new(pts[math.random(#pts)].Position)
                return
            end
        end
        hrp.CFrame = CFrame.new(0, 10, 0)
    elseif loc == "Map" then
        for _, o in ipairs(Workspace:GetDescendants()) do
            if o:IsA("Model") and (o.Name == "CoinContainer" or o.Name == "CoinAreas") then
                local map = o.Parent
                local spawns = map:FindFirstChild("Spawns")
                local pts    = spawns and spawns:GetChildren()
                if pts and #pts > 0 then
                    hrp.CFrame = CFrame.new(pts[math.random(#pts)].Position)
                end
                break
            end
        end
    elseif loc == "Murderer" then
        local m = GetMurderer()
        if m and m.Character and m.Character:FindFirstChild("HumanoidRootPart") then
            hrp.CFrame = CFrame.new(m.Character.HumanoidRootPart.Position + Vector3.new(0,3,0))
        end
    elseif loc == "Sheriff" then
        local s = GetSheriff()
        if s and s.Character and s.Character:FindFirstChild("HumanoidRootPart") then
            hrp.CFrame = CFrame.new(s.Character.HumanoidRootPart.Position + Vector3.new(0,3,0))
        end
    elseif loc == "Player" and playerName then
        local p = Players:FindFirstChild(playerName)
        if p and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            hrp.CFrame = CFrame.new(p.Character.HumanoidRootPart.Position + Vector3.new(0,3,0))
        end
    end
end

-- ============================================================
-- VISUAL / ESP
-- ============================================================
local _espDrawings = {}
local _espRenderConn = nil

local function _createTextESP(player, color, size, sideText)
    if _espDrawings[player] then _espDrawings[player].Drawing:Remove() end
    local t = Drawing.new("Text")
    t.Size=size or 14; t.Center=true; t.Outline=false; t.Color=color
    t.Transparency=1; t.Font=Drawing.Fonts.UI; t.Visible=false
    _espDrawings[player] = {Drawing=t, SideText=sideText, Color=color, Size=size or 14}
end

local function _removeTextESP(player)
    if _espDrawings[player] then
        _espDrawings[player].Drawing:Remove()
        _espDrawings[player] = nil
    end
end

local function _updateAllESP()
    for plr, data in pairs(_espDrawings) do
        local char = plr.Character
        if char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Head") and plr ~= LocalPlayer then
            local sp, onScreen = Camera:WorldToViewportPoint(char.Head.Position)
            if onScreen then
                local myHRP = GetHRP()
                local dist = myHRP and math.floor((char.HumanoidRootPart.Position - myHRP.Position).Magnitude) or 0
                data.Drawing.Position = Vector2.new(sp.X, sp.Y - 25)
                data.Drawing.Text = "("..dist..") "..plr.Name..(data.SideText and (" ["..data.SideText.."]") or "")
                data.Drawing.Visible = true
            else
                data.Drawing.Visible = false
            end
        elseif data then data.Drawing.Visible = false end
    end
end

local function _refreshESP()
    for plr in pairs(_espDrawings) do _removeTextESP(plr) end
    local roles = RoleCache
    local murder, sheriff = GetMurderer(), GetSheriff()
    if State.ESPMurderer and murder and murder ~= LocalPlayer then
        _createTextESP(murder, Color3.fromRGB(200,0,0), State.ESPTextSize, roles[murder.Name] and roles[murder.Name])
    end
    if State.ESPSheriff and sheriff and sheriff ~= LocalPlayer then
        _createTextESP(sheriff, Color3.fromRGB(0,100,200), State.ESPTextSize)
    end
    if State.ESPInnocent then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p ~= murder and p ~= sheriff and IsAlive(p) then
                _createTextESP(p, Color3.fromRGB(0,200,0), State.ESPTextSize)
            end
        end
    end
    if State.ESPMurderer or State.ESPSheriff or State.ESPInnocent then
        if not _espRenderConn then
            _espRenderConn = RunService.RenderStepped:Connect(_updateAllESP)
        end
    else
        if _espRenderConn then _espRenderConn:Disconnect(); _espRenderConn = nil end
    end
end

local function _applyHighlight(char, color)
    if not char then return end
    local h = char:FindFirstChildOfClass("Highlight")
    if not h then h = Instance.new("Highlight", char) end
    h.FillColor = color; h.OutlineColor = color
    h.FillTransparency    = State.ShowFill    and 0.5 or 1
    h.OutlineTransparency = State.ShowOutline and 0   or 1
end

local function _removeHighlight(char)
    if not char then return end
    local h = char:FindFirstChildOfClass("Highlight")
    if h then h:Destroy() end
end

local function _refreshChams()
    local murder, sheriff = GetMurderer(), GetSheriff()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local char = p.Character
            local alive = IsAlive(p)
            if not alive and State.ShowDead then
                _applyHighlight(char, Color3.fromRGB(128,128,128))
            elseif p == murder and State.ShowMurderer then
                _applyHighlight(char, Color3.fromRGB(200,0,0))
            elseif p == sheriff and State.ShowSheriff then
                _applyHighlight(char, Color3.fromRGB(0,100,200))
            elseif alive and p ~= murder and p ~= sheriff and State.ShowInnocent then
                _applyHighlight(char, Color3.fromRGB(0,200,0))
            else
                _removeHighlight(char)
            end
        end
    end
    -- Gun drop
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj.Name == "GunDrop" and obj:IsA("BasePart") then
            local h = obj:FindFirstChildOfClass("Highlight")
            if State.ShowGun then
                if not h then h = Instance.new("Highlight", obj) end
                h.OutlineColor = Color3.fromRGB(0,200,0)
                h.FillTransparency = 1
                h.OutlineTransparency = State.ShowOutline and 0 or 1
            elseif h then h:Destroy() end
        end
    end
end

-- Chams loop
local _lastChamsT = 0
RunService.Heartbeat:Connect(function()
    if not (State.ShowMurderer or State.ShowSheriff or State.ShowInnocent or State.ShowDead or State.ShowGun) then return end
    local t = tick()
    if t - _lastChamsT >= 1.5 then _lastChamsT = t; _refreshChams() end
end)

-- Notificações
local _lastNotifT = 0
RunService.Heartbeat:Connect(function()
    local t = tick()
    if t - _lastNotifT < 6 then return end
    if not (State.NotifyMurderer or State.NotifySheriff) then return end
    _lastNotifT = t
    local murder = GetMurderer()
    local sheriff = GetSheriff()
    if State.NotifyMurderer and murder then
        local perk = RoleCache[murder.Name]
        Window:Notify({ Title = "MURDERER", Desc = murder.Name..(State.NotifyMurdererPerk and perk and " ["..perk.."]" or ""), Time = 4 })
    end
    if State.NotifySheriff and sheriff then
        Window:Notify({ Title = "SHERIFF", Desc = sheriff.Name, Time = 4 })
    end
end)

Workspace.DescendantAdded:Connect(function(obj)
    if State.NotifyGunDrop and obj.Name == "GunDrop" and obj:IsA("BasePart") then
        Window:Notify({ Title = "GUN DROP", Desc = "Uma gun apareceu!", Time = 3 })
    end
end)

-- ============================================================
-- HEARTBEAT — movement, noclip, etc
-- ============================================================
local _gravity = nil

RunService.Heartbeat:Connect(function()
    if State.Noclip then
        local c = GetChar()
        if c then
            for _, p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = false end
            end
        end
    end
    if State.Float then
        local hrp = GetHRP()
        if hrp then hrp.Velocity = Vector3.new(hrp.Velocity.X, 0, hrp.Velocity.Z) end
    end
    local hum = GetHum()
    if hum then
        if State.ChangeWalkSpeed then hum.WalkSpeed = State.WalkSpeed end
        if State.ChangeJumpPower  then hum.JumpPower  = State.JumpPower end
    end
    if State.StabReach and GetCachedRole() == "Murderer" then
        if GetKnifeInChar() then
            local near = GetNearestPlayer(State.StabReachRange)
            if near then KillPlayer(near.Name, false) end
        end
    end
    if State.KillAura and GetCachedRole() == "Murderer" then
        local near = GetNearestPlayer(State.KillAuraRange)
        if near then KillPlayer(near.Name, true) end
    end
    if State.TriggerBot then
        local role = GetCachedRole()
        if role == "Sheriff" or role == "Hero" then
            local murder = GetMurderer()
            if murder then
                local ok = State.TriggerCondition == "Always" or CanSee(LocalPlayer, murder)
                if ok then ShootGun(SilentAimResolver()) end
            end
        end
    end
    if State.AutoGrabGun and FindGunDrop() then GrabGun() end
    if State.AutoStealGun and FindGunDrop() then
        -- steal gun: fling sheriff
        local sheriff = GetSheriff()
        if sheriff then task.spawn(function() FlingKill(sheriff); task.wait(0.5); GrabGun() end) end
    end
end)

-- ============================================================
-- FARM STATE
-- ============================================================
local FarmState = {
    CoinFarm=false, CoinFarmEnabled=false, CoinType="Both",
    TweenSpeed=20, AutoFarmDelay=0, InstantTpIfTooFar=200,
    TriesBeforeSkip=400, TweenUnder=true,
    ToDoWhenDone="Wait", AutoFarmMode="Normal",
    XPFarm=false, XPFarmEnabled=false,
    ToDoWhenMurderer="Kill All", ToDoWhenSheriff="Shoot Murderer", ToDoWhenInnocent="Wait",
    LAPFarm=false, CollectCoin=true, CollectGun=false,
    AutoSpamJump=false, LegitKillAll=false, LegitShootMurderer=false,
    CoinAura=false, CoinAuraDistance=10,
    AutoUnbox=false, BoxToOpen="MysteryBox1", AutoPrestige=false,
    CoinsPart={}, CoinAdded=nil, CoinRemoved=nil,
    TweenActive=false, LastCoin=nil, SkipCount=0,
    Map=nil, FarmChoice="Coin", StartTime=0,
}

local function FindMap()
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("Model") and (v.Name == "CoinContainer" or v.Name == "CoinAreas") then
            FarmState.Map = v.Parent; return
        end
    end
end

local function CoinsInformationInit(enable)
    if enable then
        FindMap()
        FarmState.CoinsPart = {}
        local container = FarmState.Map and FarmState.Map:FindFirstChild("CoinContainer")
        if not container then container = Workspace:FindFirstChild("CoinContainer", true) end
        if not container then return end
        for _, c in ipairs(container:GetChildren()) do
            if c:IsA("BasePart") then
                local id = c:GetAttribute("CoinID") or (c.Name:lower():find("beach") and "BeachBall" or "Coin")
                table.insert(FarmState.CoinsPart, {Coin=c, Position=c.Position, CoinID=id})
            end
        end
        if FarmState.CoinAdded   then FarmState.CoinAdded:Disconnect() end
        if FarmState.CoinRemoved then FarmState.CoinRemoved:Disconnect() end
        FarmState.CoinAdded = container.ChildAdded:Connect(function(c)
            if c:IsA("BasePart") then
                local id = c:GetAttribute("CoinID") or (c.Name:lower():find("beach") and "BeachBall" or "Coin")
                table.insert(FarmState.CoinsPart, {Coin=c, Position=c.Position, CoinID=id})
            end
        end)
        FarmState.CoinRemoved = container.ChildRemoved:Connect(function(c)
            for i, e in ipairs(FarmState.CoinsPart) do
                if e.Coin == c then table.remove(FarmState.CoinsPart, i); break end
            end
        end)
    else
        if FarmState.CoinAdded   then FarmState.CoinAdded:Disconnect();   FarmState.CoinAdded   = nil end
        if FarmState.CoinRemoved then FarmState.CoinRemoved:Disconnect(); FarmState.CoinRemoved  = nil end
        FarmState.CoinsPart = {}
    end
end

-- TweenToClosestCoin — exato como e0
local function TweenToClosestCoin()
    if not IsRoundStarted then return end
    local hrp = GetHRP(); if not hrp then return end
    local pos = hrp.Position
    local best, bestDist = nil, math.huge

    for _, entry in ipairs(FarmState.CoinsPart) do
        local coin = entry.Coin
        if not (coin and coin.Parent) then continue end
        local id = entry.CoinID
        local typeOk = FarmState.CoinType == "Both"
            or (FarmState.CoinType == "Coin" and id == "Coin")
            or (FarmState.CoinType == "BeachBall" and id == "BeachBall")
        -- Respeita bag cheia por tipo (exato como e0)
        if FarmState.CoinType == "Both" then
            if IsCoinBagFull() and id == "Coin" then coin:Destroy(); continue end
            if IsBeachBallBagFull() and id == "BeachBall" then coin:Destroy(); continue end
        end
        if typeOk and not coin:GetAttribute("Collected") then
            local d = (coin.Position - pos).Magnitude
            if d < bestDist then bestDist = d; best = coin end
        end
    end

    if not best then return end

    -- skip stuck
    if best == FarmState.LastCoin then
        FarmState.SkipCount = FarmState.SkipCount + 1
        if FarmState.SkipCount > FarmState.TriesBeforeSkip then
            best:Destroy(); FarmState.SkipCount = 0; return
        end
    else
        FarmState.SkipCount = 0; FarmState.LastCoin = best
    end

    if bestDist > FarmState.InstantTpIfTooFar then
        hrp.CFrame = CFrame.new(best.Position); return
    end

    -- Humanoid:MoveTo + Tween (como e0)
    local hum = GetHum()
    if hum then hum:MoveTo(best.Position) end

    local target = FarmState.TweenUnder and (best.Position - Vector3.new(0,5,0)) or best.Position
    local dist   = (target - hrp.Position).Magnitude
    local speed  = FarmState.AutoFarmMode == "Safe" and math.random(12,16) or FarmState.TweenSpeed

    FarmState.TweenActive = true
    local tw = TweenService:Create(hrp, TweenInfo.new(dist/speed, Enum.EasingStyle.Linear), {CFrame=CFrame.new(target)})
    local ok = pcall(function() tw:Play(); tw.Completed:Wait() end)
    FarmState.TweenActive = false

    if ok then
        pcall(firetouchinterest, hrp, best, 0)
        pcall(firetouchinterest, hrp, best, 1)
    end
end

local function EndRound()
    -- Tenta fling no murderer; se não tiver murderer, morre como fallback
    local murder = GetMurderer()
    if murder and murder.Character and murder.Character:FindFirstChild("HumanoidRootPart") then
        task.spawn(function() FlingKill(murder) end)
    else
        local hum = GetHum(); if hum then hum.Health = 0 end
    end
end

local function GetLevel() return LocalPlayer:GetAttribute("Level") or 0 end

local function Unbox(boxName)
    pcall(function()
        ReplicatedStorage.Remotes.Shop.OpenCrate:InvokeServer(boxName, "MysteryBox", "Coins")
    end)
end

local function Prestige()
    pcall(function() ReplicatedStorage.Remotes.Inventory.Prestige:FireServer() end)
end

-- ============================================================
-- FLOATING SHOOT BUTTON
-- ============================================================
if CoreGui:FindFirstChild("NexusShootGui") then CoreGui.NexusShootGui:Destroy() end
ShootGui = Instance.new("ScreenGui")
ShootGui.Name="NexusShootGui"; ShootGui.Parent=CoreGui
ShootGui.Enabled=false; ShootGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
ShootGui.IgnoreGuiInset=true; ShootGui.ResetOnSpawn=false

ShootButton = Instance.new("TextButton")
ShootButton.Parent=ShootGui
ShootButton.BackgroundColor3=Color3.fromRGB(12,12,18)
ShootButton.BackgroundTransparency=0.45
ShootButton.Position=UDim2.new(0.65,0,0.58,0)
ShootButton.Size=UDim2.new(0,200,0,72)
ShootButton.Font=Enum.Font.GothamBold
ShootButton.Text="NEXUS AIM"; ShootButton.TextColor3=Color3.fromRGB(0,170,255)
ShootButton.TextSize=22; ShootButton.AutoButtonColor=false; ShootButton.TextStrokeTransparency=0.7
AddCorner(ShootButton, 10)
ShootStroke = AddStroke(ShootButton, Color3.fromRGB(0,170,255), 2)
MakeDraggable(ShootButton)

task.spawn(function()
    while ShootGui do
        if ShootGui.Enabled then
            ShootStroke.Color = Color3.fromRGB(0,170,255):Lerp(Color3.fromRGB(255,255,255), 0.5+0.5*math.sin(tick()*math.pi))
        end
        task.wait(0.03)
    end
end)

ShootButton.MouseButton1Click:Connect(function()
    local murder = GetMurderer()
    if not murder then
        ShootButton.Text = "NO TARGET"
        ShootStroke.Color = Color3.fromRGB(255,80,80)
        task.delay(0.5, function() ShootButton.Text = "NEXUS AIM"; ShootStroke.Color = Color3.fromRGB(0,170,255) end)
        return
    end
    -- Equipa a gun se necessário, depois atira direto sem teleportar
    local gun = GetChar() and GetChar():FindFirstChild("Gun")
    if not gun then gun = EquipGun() end
    if not gun then
        ShootButton.Text = "NO GUN"
        ShootStroke.Color = Color3.fromRGB(255,80,80)
        task.delay(0.5, function() ShootButton.Text = "NEXUS AIM"; ShootStroke.Color = Color3.fromRGB(0,170,255) end)
        return
    end
    ShootButton.Text = "FIRING..."
    ShootStroke.Color = Color3.fromRGB(255,160,0)
    ShootGun(SilentAimResolver())
    task.delay(0.3, function() ShootButton.Text = "NEXUS AIM"; ShootStroke.Color = Color3.fromRGB(0,170,255) end)
end)

-- ============================================================
-- FLOATING INVISIBLE BUTTON
-- ============================================================
if CoreGui:FindFirstChild("NexusInvisGui") then CoreGui.NexusInvisGui:Destroy() end
local InvisGui = Instance.new("ScreenGui")
InvisGui.Name="NexusInvisGui"; InvisGui.Parent=CoreGui
InvisGui.IgnoreGuiInset=true; InvisGui.ResetOnSpawn=false

InvisFrame = Instance.new("Frame"); InvisFrame.Parent=InvisGui
InvisFrame.Size=UDim2.new(0,90,0,32); InvisFrame.Position=UDim2.new(0.01,0,0.55,0)
InvisFrame.BackgroundColor3=Color3.fromRGB(12,12,18); InvisFrame.BackgroundTransparency=0.45
InvisFrame.Visible=false; InvisFrame.BorderSizePixel=0
AddCorner(InvisFrame, 6); InvisStroke = AddStroke(InvisFrame, Color3.fromRGB(140,50,255), 1.5)

InvisBtn = Instance.new("TextButton"); InvisBtn.Parent=InvisFrame
InvisBtn.Size=UDim2.new(1,0,1,0); InvisBtn.BackgroundTransparency=1
InvisBtn.Text="INVISIBLE"; InvisBtn.TextColor3=Color3.fromRGB(140,50,255)
InvisBtn.Font=Enum.Font.GothamBlack; InvisBtn.TextSize=11; InvisBtn.AutoButtonColor=true
MakeDraggable(InvisFrame)

local function ToggleInvis()
    InvisActive = not InvisActive
    if InvisActive then
        InvisBtn.Text="ACTIVE"; InvisBtn.TextColor3=Color3.fromRGB(0,255,150)
        InvisStroke.Color=Color3.fromRGB(0,255,150)
        local c = GetChar()
        if c then
            for _, v in pairs(c:GetDescendants()) do
                if v:IsA("BasePart") and v.Transparency==0 then v.Transparency=0.5 end
            end
        end
    else
        InvisBtn.Text="INVISIBLE"; InvisBtn.TextColor3=Color3.fromRGB(140,50,255)
        InvisStroke.Color=Color3.fromRGB(140,50,255)
        local c = GetChar()
        if c then
            for _, v in pairs(c:GetDescendants()) do
                if v:IsA("BasePart") and v.Transparency==0.5 then v.Transparency=0 end
            end
        end
    end
end
InvisBtn.MouseButton1Click:Connect(ToggleInvis)

-- Invisible loop: desloca Root -200000Y por 1 frame, câmera fica no lugar via CameraOffset
RunService.Heartbeat:Connect(function()
    if not InvisActive then return end
    local Char = GetChar(); if not Char then return end
    local Root = Char:FindFirstChild("HumanoidRootPart")
    local Hum  = Char:FindFirstChildOfClass("Humanoid")
    if not Root or not Hum then return end
    local oldCF     = Root.CFrame
    local oldCamOff = Hum.CameraOffset
    Root.CFrame = oldCF * CFrame.new(0,-200000,0)
    Hum.CameraOffset = (oldCF*CFrame.new(0,-200000,0)):ToObjectSpace(CFrame.new(oldCF.Position)).Position
    RunService.RenderStepped:Wait()
    Root.CFrame = oldCF; Hum.CameraOffset = oldCamOff
end)

-- ============================================================
-- FLOATING DESYNC BUTTON
-- ============================================================
if CoreGui:FindFirstChild("NexusDesyncGui") then CoreGui.NexusDesyncGui:Destroy() end
local DesyncGui = Instance.new("ScreenGui")
DesyncGui.Name="NexusDesyncGui"; DesyncGui.Parent=CoreGui
DesyncGui.IgnoreGuiInset=true; DesyncGui.ResetOnSpawn=false

DesyncFrame = Instance.new("Frame"); DesyncFrame.Parent=DesyncGui
DesyncFrame.Size=UDim2.new(0,90,0,32); DesyncFrame.Position=UDim2.new(0.01,0,0.61,0)
DesyncFrame.BackgroundColor3=Color3.fromRGB(12,12,18); DesyncFrame.BackgroundTransparency=0.45
DesyncFrame.Visible=false; DesyncFrame.BorderSizePixel=0
AddCorner(DesyncFrame, 6); DesyncStroke = AddStroke(DesyncFrame, Color3.fromRGB(140,50,255), 1.5)

DesyncBtn = Instance.new("TextButton"); DesyncBtn.Parent=DesyncFrame
DesyncBtn.Size=UDim2.new(1,0,1,0); DesyncBtn.BackgroundTransparency=1
DesyncBtn.Text="DESYNC"; DesyncBtn.TextColor3=Color3.fromRGB(140,50,255)
DesyncBtn.Font=Enum.Font.GothamBlack; DesyncBtn.TextSize=11; DesyncBtn.AutoButtonColor=true
MakeDraggable(DesyncFrame)

local function _setCharTransparency(character, t)
    for _, p in pairs(character:GetDescendants()) do
        if (p:IsA("BasePart") or p:IsA("Decal")) and p.Name~="HumanoidRootPart" then p.Transparency=t end
    end
end
local function _setHRPTransparency(character, t)
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if hrp and hrp:IsA("BasePart") then hrp.Transparency=t end
end

local function ToggleDesync()
    desync_on = not desync_on
    local character = GetChar()
    if not character then return end
    if desync_on then
        local origCF = character.HumanoidRootPart.CFrame
        desyncChair = Instance.new("Seat", Workspace)
        desyncChair.Anchored=false; desyncChair.CanCollide=false
        desyncChair.Name="NexusDesyncChair"; desyncChair.Transparency=1; desyncChair.CFrame=origCF
        local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
        if torso then
            desyncWeld = Instance.new("Weld", desyncChair)
            desyncWeld.Part0=desyncChair; desyncWeld.Part1=torso
        end
        _setCharTransparency(character, 0); _setHRPTransparency(character, 1)
        if ghostPart then ghostPart:Destroy() end
        ghostPart = Instance.new("Part"); ghostPart.Name="NexusDesyncGhost"
        ghostPart.Size=Vector3.new(4,6,4); ghostPart.Shape=Enum.PartType.Cylinder
        ghostPart.CFrame=origCF*CFrame.Angles(0,0,math.rad(90)); ghostPart.Anchored=true
        ghostPart.CanCollide=false; ghostPart.Material=Enum.Material.ForceField
        ghostPart.Color=Color3.fromRGB(140,50,255); ghostPart.Transparency=0
        ghostPart.CastShadow=false; ghostPart.Parent=Workspace
        DesyncBtn.Text="ACTIVE"; DesyncBtn.TextColor3=Color3.fromRGB(0,255,150)
        DesyncStroke.Color=Color3.fromRGB(0,255,150)
    else
        if desyncChair then desyncChair:Destroy(); desyncChair=nil end
        if ghostPart   then ghostPart:Destroy();   ghostPart=nil end
        desyncWeld=nil
        _setCharTransparency(character, 0); _setHRPTransparency(character, 1)
        DesyncBtn.Text="DESYNC"; DesyncBtn.TextColor3=Color3.fromRGB(140,50,255)
        DesyncStroke.Color=Color3.fromRGB(140,50,255)
    end
end
DesyncBtn.MouseButton1Click:Connect(ToggleDesync)

-- Reset desync/invis on respawn
LocalPlayer.CharacterAdded:Connect(function(character)
    task.wait(0.5)
    local dc = Workspace:FindFirstChild("NexusDesyncChair"); if dc then dc:Destroy() end
    if ghostPart then ghostPart:Destroy(); ghostPart=nil end
    desync_on=false; desyncWeld=nil
    if DesyncBtn then DesyncBtn.Text="DESYNC"; DesyncBtn.TextColor3=Color3.fromRGB(140,50,255) end
    if DesyncStroke then DesyncStroke.Color=Color3.fromRGB(140,50,255) end
    _setCharTransparency(character, 0); _setHRPTransparency(character, 1)
    InvisActive=false
    if InvisBtn then InvisBtn.Text="INVISIBLE"; InvisBtn.TextColor3=Color3.fromRGB(140,50,255) end
    if InvisStroke then InvisStroke.Color=Color3.fromRGB(140,50,255) end
    -- Limpa secondLife ao respawnar (ApplySecondLife reconecta via seu próprio CharacterAdded)
    if secondLifeConnection then secondLifeConnection:Disconnect(); secondLifeConnection=nil end

    -- End Round When Dead: se morreu durante a rodada, tenta encerrar
    if TrollState.EndRoundWhenDead and IsRoundStarted then
        task.spawn(function()
            task.wait(0.3)
            EndRound()
        end)
    end
end)

-- Server Hop When Empty: monitora PlayerRemoving
Players.PlayerRemoving:Connect(function()
    if not TrollState.ServerHopWhenEmpty then return end
    task.wait(1)
    local count = #Players:GetPlayers()
    if count <= TrollState.ServerHopAfter then
        task.spawn(ServerHop)
    end
end)

-- Rejoin When Kicked: detecta teleport falho
pcall(function()
    game:GetService("TeleportService").TeleportInitFailed:Connect(function()
        if TrollState.RejoinWhenKicked then
            task.wait(2)
            task.spawn(Rejoin)
        end
    end)
end)
-- Fallback kick detection via LocalPlayer.AncestryChanged
LocalPlayer.AncestryChanged:Connect(function()
    if TrollState.RejoinWhenKicked and not LocalPlayer.Parent then
        -- Player foi kickado
        -- Não podemos rejoin de dentro do mesmo contexto neste ponto,
        -- mas logamos para que o executor consiga reexecutar se suportado
        pcall(function()
            game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
        end)
    end
end)

-- ============================================================
-- UI LOAD
-- ============================================================
local Library = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/x2zu/OPEN-SOURCE-UI-ROBLOX/refs/heads/main/X2ZU%20UI%20ROBLOX%20OPEN%20SOURCE/DummyUI.lua"
))()

Window = Library:Window({
    Title="MM2 Hub", Desc="Murder Mystery 2", Icon=105059922903197, Theme="Dark",
    Config={Keybind=Enum.KeyCode.RightControl, Size=UDim2.new(0,520,0,420)},
    CloseUIButton={Enabled=true, Text="Close"},
})

-- ============================================================
-- TAB: MAIN
-- ============================================================
local Main = Window:Tab({Title="Main", Icon="house"})

Main:Section({Title="Player"})
Main:Slider({Title="Walk Speed",   Min=1, Max=200, Rounding=0, Value=16,  Callback=function(v) State.WalkSpeed=v end})
Main:Toggle({Title="Change Walk Speed", Value=false, Callback=function(v) State.ChangeWalkSpeed=v end})
Main:Slider({Title="Jump Power",   Min=1, Max=300, Rounding=0, Value=50,  Callback=function(v) State.JumpPower=v end})
Main:Toggle({Title="Change Jump Power", Value=false, Callback=function(v) State.ChangeJumpPower=v end})
Main:Toggle({Title="Noclip",           Value=false, Callback=function(v) State.Noclip=v end})
Main:Toggle({Title="Float",            Value=false, Callback=function(v) State.Float=v end})
Main:Toggle({Title="Swim (Zero Gravity)", Value=false, Callback=function(v)
    State.Swim = v
    if v then _gravity=Workspace.Gravity; Workspace.Gravity=0
        local h=GetHum(); if h then h:ChangeState(Enum.HumanoidStateType.Swimming) end
    else if _gravity then Workspace.Gravity=_gravity end
        local h=GetHum(); if h then h:ChangeState(Enum.HumanoidStateType.GettingUp) end
    end
end})
Main:Toggle({Title="Unlock Camera", Value=false, Callback=function(v) LocalPlayer.CameraMaxZoomDistance=v and 100000 or 15 end})
Main:Toggle({Title="Camera Noclip", Value=false, Callback=function(v)
    LocalPlayer.DevCameraOcclusionMode = v and "Invisicam" or "Zoom"
end})

Main:Section({Title="Teleport"})
Main:Toggle({Title="Teleport Tool", Value=false, Callback=function(v)
    State.TeleportTool=v
    if v then
        local t=Instance.new("Tool"); t.RequiresHandle=false; t.Name="TP_Tool"; t.Parent=LocalPlayer.Backpack
        t.Activated:Connect(function() local h=GetHRP(); if h then h.CFrame=CFrame.new(Mouse.Hit.Position+Vector3.new(0,3,0)) end end)
    else
        local t=LocalPlayer.Backpack:FindFirstChild("TP_Tool") or (GetChar() and GetChar():FindFirstChild("TP_Tool"))
        if t then t:Destroy() end
    end
end})
Main:Dropdown({Title="Teleport To", List={"Map","Murderer","Sheriff","Lobby"}, Value="Map", Callback=function(v) TeleportTo(v) end})
local playerList = {}
for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer then table.insert(playerList, p.Name) end end
Players.PlayerAdded:Connect(function(p) table.insert(playerList, p.Name) end)
Main:Dropdown({Title="Teleport To Player", List=playerList, Value=playerList[1] or "", Callback=function(v) TeleportTo("Player",v) end})

Main:Section({Title="Misc"})
Main:Toggle({Title="Second Life (Godmode)", Desc="Vida volta ao máximo instantaneamente", Value=false, Callback=function(v)
    State.SecondLife = v
    ApplySecondLife(v)
end})

Main:Section({Title="Invisible"})
Main:Toggle({Title="Show Invisible Button", Desc="Displays the floating Invisible button", Value=false, Callback=function(v)
    InvisFrame.Visible = v
end})
Main:Button({Title="Toggle Invisible", Desc="Shifts your char below the map each frame — others can't see you", Callback=function()
    ToggleInvis()
end})

Main:Section({Title="Desync"})
Main:Toggle({Title="Show Desync Button", Desc="Displays the floating Desync button", Value=false, Callback=function(v)
    DesyncFrame.Visible = v
end})
Main:Button({Title="Toggle Desync", Desc="Creates a fake server position ghost while you move freely", Callback=function()
    ToggleDesync()
end})
Main:Toggle({Title="No GUI", Value=false, Callback=function(v)
    State.NoGUI=v
    local pg=LocalPlayer:FindFirstChildWhichIsA("PlayerGui"); if not pg then return end
    if v then
        for _,g in ipairs(pg:GetChildren()) do if g.Enabled then g.Enabled=false; table.insert(State.HiddenGUIS,g) end end
    else
        for _,g in ipairs(State.HiddenGUIS) do pcall(function() g.Enabled=true end) end
        State.HiddenGUIS={}
    end
end})
Main:Toggle({Title="Destroy Barriers", Value=false, Callback=function(v)
    if v then for _,o in ipairs(Workspace:GetDescendants()) do
        if o.Name=="GlitchProof" or o.Name=="InvisWalls" then pcall(function() o:Destroy() end) end
    end end
end})
Main:Toggle({Title="Destroy Coins", Value=false, Callback=function(v)
    State.DestroyCoins=v
    if v then for _,o in ipairs(Workspace:GetDescendants()) do
        if o.Name=="Coin_Server" and o:IsA("BasePart") then pcall(function() o:Destroy() end) end
    end end
end})
Main:Toggle({Title="Hide Coins", Value=false, Callback=function(v)
    State.HideCoins=v
    for _,o in ipairs(Workspace:GetDescendants()) do
        if o.Name=="Coin_Server" and o:IsA("BasePart") then
            local vis=o:FindFirstChild("CoinVisual")
            if vis then for _,p in ipairs(vis:GetDescendants()) do
                if p:IsA("BasePart") or p:IsA("Decal") then p.LocalTransparencyModifier=v and 1 or 0 end
            end end
        end
    end
end})
Main:Toggle({Title="Destroy Dead Body", Value=false, Callback=function(v)
    State.DestroyDeadBody=v
    if v then for _,o in ipairs(Workspace:GetChildren()) do
        if o:IsA("Model") and o.Name=="Raggy" then pcall(function() o:Destroy() end) end
    end end
end})
Main:Toggle({Title="Mute Other Radios", Value=false, Callback=function(v)
    State.MuteRadios=v
    for _,p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local radio=p.Character:FindFirstChild("Radio")
            if radio then local snd=radio:FindFirstChildOfClass("Sound"); if snd then snd.Volume=v and 0 or 0.5 end end
        end
    end
end})
Window:Line()

-- ============================================================
-- TAB: COMBAT
-- ============================================================
local Combat = Window:Tab({Title="Combat", Icon="swords"})

Combat:Section({Title="Murderer"})
Combat:Dropdown({Title="Players To Kill", List=playerList, Value=playerList[1] or "", Callback=function(v) State.PlayersToKill={v} end})
Combat:Button({Title="Kill Selected", Callback=function() KillSelected(State.PlayersToKill) end})
Combat:Button({Title="Kill All", Callback=function() KillAll() end})
Combat:Slider({Title="Stab Reach Range", Min=1, Max=60, Rounding=0, Value=10, Callback=function(v) State.StabReachRange=v end})
Combat:Toggle({Title="Stab Reach", Value=false, Callback=function(v) State.StabReach=v end})
Combat:Slider({Title="Kill Aura Range", Min=1, Max=60, Rounding=0, Value=10, Callback=function(v) State.KillAuraRange=v end})
Combat:Toggle({Title="Kill Aura", Value=false, Callback=function(v) State.KillAura=v end})
Combat:Dropdown({Title="Knife SA Prediction", List={"Off","Static","Dynamic"}, Value="Static", Callback=function(v) State.KSAPrediction=v end})
Combat:Toggle({Title="Knife Silent Aim", Value=false, Callback=function(v) State.KnifeSilentAim=v end})

Combat:Section({Title="Sheriff / Hero"})
Combat:Button({Title="Shoot Murderer", Callback=function() ShootMurderer() end})
Combat:Toggle({Title="Show Aim Button", Desc="Shows the floating NEXUS AIM button on screen", Value=false, Callback=function(v)
    ShootGui.Enabled = v
end})
Combat:Dropdown({Title="Gun SA Prediction", List={"Off","Stable","Smart"}, Value="Smart", Callback=function(v) State.GSAPrediction=v end})
Combat:Toggle({Title="Visibility Check", Value=true, Callback=function(v) State.VisibilityCheck=v end})
Combat:Toggle({Title="Gun Silent Aim", Value=false, Callback=function(v)
    if not hookmetamethod then Window:Notify({Title="Erro",Desc="Executor não suporta hookmetamethod.",Time=3}); return end
    State.GunSilentAim=v
end})
Combat:Toggle({Title="Auto Equip Gun", Value=true, Callback=function(v) State.AutoEquipGun=v end})
Combat:Dropdown({Title="Trigger Condition", List={"Visible","Always"}, Value="Visible", Callback=function(v) State.TriggerCondition=v end})
Combat:Toggle({Title="Trigger Bot", Value=false, Callback=function(v) State.TriggerBot=v end})

Combat:Section({Title="Innocent"})
Combat:Dropdown({Title="Fling Target", List=playerList, Value=playerList[1] or "", Callback=function(v) State.FlingTarget=v end})
Combat:Toggle({Title="Loop Fling Player", Value=false, Callback=function(v)
    State.LoopFlingPlayer=v; _IsFlinging=v
    if v then task.spawn(function()
        while State.LoopFlingPlayer do FlingKill(State.FlingTarget); task.wait(1) end
    end) end
end})
Combat:Toggle({Title="Fling All Players", Value=false, Callback=function(v)
    State.LoopFlingAll=v; _IsFlinging=v
    if v then task.spawn(function()
        while State.LoopFlingAll do FlingKill("All"); task.wait(1) end
    end) end
end})
Combat:Button({Title="Grab Gun", Callback=function() GrabGun() end})
Combat:Toggle({Title="Auto Grab Gun", Value=false, Callback=function(v)
    State.AutoGrabGun=v
    if v then
        Conn("autoGrab", Workspace.DescendantAdded:Connect(function(obj)
            if obj.Name=="GunDrop" and obj:IsA("BasePart") and State.AutoGrabGun then task.wait(0.1); GrabGun() end
        end))
    end
end})
Combat:Button({Title="Steal Gun", Callback=function()
    local s=GetSheriff(); if s then FlingKill(s); task.wait(0.5); GrabGun() end
end})
Window:Line()

-- ============================================================
-- TAB: VISUAL
-- ============================================================
local Visual = Window:Tab({Title="Visual", Icon="eye"})

Visual:Section({Title="CHAMS (Highlight)"})
Visual:Toggle({Title="Show Murderer", Value=false, Callback=function(v) State.ShowMurderer=v; _refreshChams() end})
Visual:Toggle({Title="Show Sheriff",  Value=false, Callback=function(v) State.ShowSheriff=v;  _refreshChams() end})
Visual:Toggle({Title="Show Innocent", Value=false, Callback=function(v) State.ShowInnocent=v; _refreshChams() end})
Visual:Toggle({Title="Show Dead",     Value=false, Callback=function(v) State.ShowDead=v;     _refreshChams() end})
Visual:Toggle({Title="Show Gun Drop", Value=false, Callback=function(v) State.ShowGun=v;      _refreshChams() end})
Visual:Toggle({Title="Show Fill",     Value=true,  Callback=function(v) State.ShowFill=v;     _refreshChams() end})
Visual:Toggle({Title="Show Outline",  Value=true,  Callback=function(v) State.ShowOutline=v;  _refreshChams() end})

Visual:Section({Title="TEXT ESP"})
Visual:Toggle({Title="ESP Murderer", Value=false, Callback=function(v) State.ESPMurderer=v; _refreshESP() end})
Visual:Toggle({Title="ESP Sheriff",  Value=false, Callback=function(v) State.ESPSheriff=v;  _refreshESP() end})
Visual:Toggle({Title="ESP Innocent", Value=false, Callback=function(v) State.ESPInnocent=v; _refreshESP() end})
Visual:Slider({Title="ESP Text Size", Min=8, Max=30, Rounding=0, Value=14, Callback=function(v) State.ESPTextSize=v; _refreshESP() end})

Visual:Section({Title="NOTIFICAÇÕES"})
Visual:Toggle({Title="Notify Murderer",      Value=false, Callback=function(v) State.NotifyMurderer=v end})
Visual:Toggle({Title="Notify Murderer Perk", Value=false, Callback=function(v) State.NotifyMurdererPerk=v end})
Visual:Toggle({Title="Notify Sheriff",       Value=false, Callback=function(v) State.NotifySheriff=v end})
Visual:Toggle({Title="Notify Gun Drop",      Value=false, Callback=function(v) State.NotifyGunDrop=v end})

Visual:Section({Title="ROUND INFORMATION"})
-- Parágrafo dinâmico: atualiza a cada 2s com estado da rodada
local _roundInfoPara = Visual:Textbox({
    Title           = "Round Info",
    Placeholder     = "Aguardando rodada...",
    Value           = "Aguardando rodada...",
    ClearTextOnFocus = false,
    Callback        = function() end,
})
task.spawn(function()
    while true do
        task.wait(2)
        if _roundInfoPara then
            local murder  = GetMurderer()
            local sheriff = GetSheriff()
            local gunDrop = FindGunDrop()
            local status  = IsRoundStarted and "Em andamento" or (IsRoundStarting and "Iniciando..." or "Lobby")
            local info = "Status: "..status
            if murder  then info = info.."\nMurderer: "..murder.Name end
            if sheriff then info = info.."\nSheriff: "..sheriff.Name end
            info = info.."\nGun Drop: "..(gunDrop and "SIM" or "não")
            pcall(function() _roundInfoPara:SetValue(info) end)
        end
    end
end)

Visual:Section({Title="PERFORMANCE"})
Visual:Toggle({
    Title    = "Disable 3D Rendering",
    Desc     = "Desativa renderização 3D — melhora FPS extremo",
    Value    = false,
    Callback = function(v)
        State.Disable3DRendering = v
        pcall(function() RunService:Set3dRenderingEnabled(not v) end)
    end,
})

Window:Line()

-- ============================================================
-- TAB: FARM
-- ============================================================
local Farm = Window:Tab({Title="Farm", Icon="coins"})
Window:Line()

Farm:Section({Title="Auto Farm"})
Farm:Dropdown({Title="Farm Mode", List={"Coin","XP","Legit Auto Player"}, Value="Coin", Callback=function(v) FarmState.FarmChoice=v end})

-- ======= COIN FARM =======
Farm:Section({Title="Coin Farm"})
Farm:Toggle({Title="Coin Farm", Desc="Tween até cada moeda automaticamente", Value=false, Callback=function(on)
    FarmState.CoinFarm=on
    if on then
        FarmState.CoinFarmEnabled=true
        State.Noclip=true; State.Float=true
        FarmState.StartTime=os.time()
        FindMap()
        if IsRoundStarted then CoinsInformationInit(true) end
        task.spawn(function()
            while FarmState.CoinFarm do
                local hrp=GetHRP()
                if hrp then
                    if IsRoundStarted and IsAlive() then
                        -- Bag full exato como e0
                        local bagFull
                        if FarmState.CoinType == "Coin" then bagFull=IsCoinBagFull()
                        elseif FarmState.CoinType == "BeachBall" then bagFull=IsBeachBallBagFull()
                        else
                            local c=IsCoinBagFull()
                            bagFull = c and IsBeachBallBagFull()
                        end
                        if bagFull then
                            hrp.CFrame=CFrame.new(0,100,0)
                            if FarmState.ToDoWhenDone=="Reset" then
                                local h=GetHum(); if h then h.Health=0 end
                            elseif FarmState.ToDoWhenDone=="End Round" then EndRound() end
                        else
                            task.spawn(TweenToClosestCoin)
                        end
                    else
                        hrp.CFrame=CFrame.new(0,100,0)
                    end
                end
                task.wait(FarmState.AutoFarmDelay>0 and FarmState.AutoFarmDelay or 0.1)
            end
            CoinsInformationInit(false)
            TeleportTo("Lobby")
            State.Noclip=false; State.Float=false
            FarmState.CoinFarmEnabled=false
        end)
    end
end})
Farm:Dropdown({Title="Coin Type", List={"Both","Coin","BeachBall"}, Value="Both", Callback=function(v) FarmState.CoinType=v end})
Farm:Slider({Title="Tween Speed", Min=10, Max=25, Rounding=0, Value=20, Callback=function(v) FarmState.TweenSpeed=v end})
Farm:Slider({Title="Delay (s)", Min=0, Max=3, Rounding=1, Value=0, Callback=function(v) FarmState.AutoFarmDelay=v end})
Farm:Slider({Title="Instant TP se dist > X", Min=50, Max=500, Rounding=0, Value=200, Callback=function(v) FarmState.InstantTpIfTooFar=v end})
Farm:Slider({Title="Tries Before Skip", Min=100, Max=600, Rounding=0, Value=400, Callback=function(v) FarmState.TriesBeforeSkip=v end})
Farm:Toggle({Title="Tween Under", Desc="Desative se crashar", Value=true, Callback=function(v) FarmState.TweenUnder=v end})
Farm:Dropdown({Title="Quando bag cheia", List={"Wait","Reset","End Round"}, Value="Wait", Callback=function(v) FarmState.ToDoWhenDone=v end})
Farm:Dropdown({Title="Modo", List={"Normal","Safe"}, Value="Normal", Callback=function(v) FarmState.AutoFarmMode=v end})

-- ======= XP FARM =======
Farm:Section({Title="XP Farm"})
Farm:Toggle({Title="XP Farm", Desc="Flutua e age por role — mata/atira exato como e0", Value=false, Callback=function(on)
    FarmState.XPFarm=on
    if on then
        State.Noclip=true; State.Float=true
        FarmState.StartTime=os.time()
        task.spawn(RefreshRoleCache)
        task.spawn(function()
            while FarmState.XPFarm do
                local hrp=GetHRP()
                if hrp then hrp.CFrame=CFrame.new(0,100,0) end
                if IsRoundStarted and IsAlive() then
                    local role=GetCachedRole()
                    if role=="Murderer" then
                        if FarmState.ToDoWhenMurderer=="Kill All" then
                            -- KillAll exato do e0: equipa faca, puxa HRP + firetouchinterest
                            KillAll()
                        elseif FarmState.ToDoWhenMurderer=="Reset" then
                            local h=GetHum(); if h then h.Health=0 end
                        end
                    elseif role=="Sheriff" or role=="Hero" then
                        if FarmState.ToDoWhenSheriff=="Shoot Murderer" then
                            -- ShootMurderer exato do e0: TP 5st atrás + atira + volta
                            ShootMurderer()
                        elseif FarmState.ToDoWhenSheriff=="Reset" then
                            local h=GetHum(); if h then h.Health=0 end
                        end
                    elseif role=="Innocent" then
                        if FarmState.ToDoWhenInnocent=="Steal Gun" then
                            local s=GetSheriff()
                            if s then FlingKill(s); task.wait(0.5); GrabGun() end
                        elseif FarmState.ToDoWhenInnocent=="Reset" then
                            local h=GetHum(); if h then h.Health=0 end
                        end
                    end
                end
                task.wait(3)
            end
            TeleportTo("Lobby")
            State.Noclip=false; State.Float=false
        end)
    end
end})
Farm:Dropdown({Title="Como Murderer",     List={"Kill All","Reset"},                  Value="Kill All",       Callback=function(v) FarmState.ToDoWhenMurderer=v end})
Farm:Dropdown({Title="Como Sheriff/Hero", List={"Shoot Murderer","Reset"},            Value="Shoot Murderer", Callback=function(v) FarmState.ToDoWhenSheriff=v  end})
Farm:Dropdown({Title="Como Innocent",     List={"Steal Gun","Wait","Reset"},          Value="Wait",           Callback=function(v) FarmState.ToDoWhenInnocent=v  end})

-- ======= LEGIT AUTO PLAYER =======
Farm:Section({Title="Legit Auto Player"})
Farm:Toggle({Title="Legit Auto Player", Desc="Anda até moedas + age por role", Value=false, Callback=function(on)
    FarmState.LAPFarm=on
    if on then
        FarmState.StartTime=os.time()
        -- Loop principal: coleta coin/gun
        task.spawn(function()
            while FarmState.LAPFarm do
                if IsRoundStarted and IsAlive() then
                    if FarmState.CollectGun and FindGunDrop() then GrabGun() end
                    if FarmState.CollectCoin and not IsBagFull(FarmState.CoinType) then
                        task.spawn(TweenToClosestCoin)
                    end
                end
                task.wait(0.5)
            end
        end)
        -- Loop spam jump
        task.spawn(function()
            while FarmState.LAPFarm do
                if FarmState.AutoSpamJump then
                    local murderPlr=GetMurderer()
                    local hrp=GetHRP()
                    if murderPlr and murderPlr.Character and hrp then
                        local mhrp=murderPlr.Character:FindFirstChild("HumanoidRootPart")
                        if mhrp and (hrp.Position-mhrp.Position).Magnitude < 20 then
                            local h=GetHum(); if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
                        end
                    end
                end
                task.wait(1)
            end
        end)
    end
end})
Farm:Toggle({Title="Collect Coin",   Value=true,  Callback=function(v) FarmState.CollectCoin=v end})
Farm:Toggle({Title="Collect Gun",    Value=false, Callback=function(v) FarmState.CollectGun=v  end})
Farm:Toggle({Title="Spam Jump perto do Murderer", Value=false, Callback=function(v) FarmState.AutoSpamJump=v end})
Farm:Toggle({Title="Auto Kill All (Murderer)",   Value=false, Callback=function(v) FarmState.LegitKillAll=v  end})
Farm:Toggle({Title="Auto Shoot Murderer (Sheriff)", Value=false, Callback=function(v) FarmState.LegitShootMurderer=v end})

-- Heartbeat LAP kill/shoot
local _lapKillDB=false; local _lapShootDB=false
RunService.Heartbeat:Connect(function()
    if not FarmState.LAPFarm or not IsRoundStarted then return end
    if FarmState.LegitKillAll and not _lapKillDB and GetCachedRole()=="Murderer" then
        if GetKnifeInChar() then
            local near=GetNearestPlayer(15)
            if near then
                _lapKillDB=true
                task.spawn(function() KillPlayer(near.Name,true); task.wait(0.5); _lapKillDB=false end)
            end
        end
    end
    if FarmState.LegitShootMurderer and not _lapShootDB then
        local role=GetCachedRole()
        if role=="Sheriff" or role=="Hero" then
            _lapShootDB=true
            task.spawn(function() ShootMurderer(); task.wait(1); _lapShootDB=false end)
        end
    end
end)

-- ======= HELPER =======
Farm:Section({Title="Helper"})
Farm:Slider({Title="Coin Aura Distance", Min=3, Max=20, Rounding=0, Value=10, Callback=function(v) FarmState.CoinAuraDistance=v end})
Farm:Toggle({Title="Coin Aura", Value=false, Callback=function(on)
    FarmState.CoinAura=on
    if on then task.spawn(function()
        while FarmState.CoinAura do
            local hrp=GetHRP()
            if hrp and IsRoundStarted then
                for _,e in ipairs(FarmState.CoinsPart) do
                    local c=e.Coin
                    if c and c.Parent and (hrp.Position-c.Position).Magnitude<=FarmState.CoinAuraDistance then
                        pcall(firetouchinterest,hrp,c,0); pcall(firetouchinterest,hrp,c,1)
                    end
                end
            end
            task.wait()
        end
    end) end
end})
Farm:Dropdown({Title="Box para Auto Unbox", List={"MysteryBox1","MysteryBox2","KnifeBox1","KnifeBox2","KnifeBox3","KnifeBox4","GunBox1","GunBox2","GunBox3"}, Value="MysteryBox1", Callback=function(v) FarmState.BoxToOpen=v end})
Farm:Toggle({Title="Auto Unbox", Value=false, Callback=function(on)
    FarmState.AutoUnbox=on
    if on then task.spawn(function()
        while FarmState.AutoUnbox do
            if (LocalPlayer:GetAttribute("Coins") or 0) >= 1000 then Unbox(FarmState.BoxToOpen) end
            task.wait(1)
        end
    end) end
end})
Farm:Toggle({Title="Auto Prestige", Value=false, Callback=function(on)
    FarmState.AutoPrestige=on
    if on then task.spawn(function()
        while FarmState.AutoPrestige do
            local lvl=GetLevel(); local p=LocalPlayer:GetAttribute("Prestige") or 0
            if lvl>=100 and p<10 then Prestige() end
            task.wait(5)
        end
    end) end
end})

-- ============================================================
-- LOOP BACKGROUND — sincroniza round state e coins
-- ============================================================
task.spawn(function()
    while true do
        task.wait(3)
        -- Fallback round state se eventos não chegaram
        if not IsRoundStarted and not IsRoundStarting then
            local ok,t=pcall(function() return ReplicatedStorage.Remotes.Extras.GetTimer:InvokeServer() end)
            t=(ok and type(t)=="number") and t or 0
            IsRoundStarted=t<180 and t>0; IsRoundStarting=t==180
        end
        -- Inicia tracking de coins quando necessário
        if IsRoundStarted and (FarmState.CoinFarm or FarmState.LAPFarm or FarmState.CoinAura) then
            if not FarmState.CoinAdded then FindMap(); CoinsInformationInit(true) end
        end
        if not IsRoundStarted and FarmState.CoinAdded then CoinsInformationInit(false) end
        -- Limpa dead body se ativado
        if State.DestroyDeadBody then
            for _,o in ipairs(Workspace:GetChildren()) do
                if o:IsA("Model") and o.Name=="Raggy" then pcall(function() o:Destroy() end) end
            end
        end
    end
end)


-- ============================================================
-- TROLL / MISC — funções de suporte
-- ============================================================

-- Break Gun: dispara o remote ShootGun do sheriff com args inválidos pra quebrar a gun
local function BreakGun()
    pcall(function()
        local sheriff = GetSheriff()
        if not sheriff then return end
        local gun = (sheriff.Backpack and sheriff.Backpack:FindFirstChild("Gun"))
               or  (sheriff.Character and sheriff.Character:FindFirstChild("Gun"))
        if not gun then return end
        local remote = gun:FindFirstChild("KnifeServer") and gun.KnifeServer:FindFirstChild("ShootGun")
        if remote then remote:InvokeServer(1, 0, "AH2") end
    end)
end

-- Muta rádios de outros players
local function MuteOtherRadios(on)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            for _, part in ipairs(p.Character:GetDescendants()) do
                if part:IsA("Part") and part.Name == "Radio" then
                    local snd = part:FindFirstChildOfClass("Sound")
                    if snd then snd.Volume = on and 0 or 0.5 end
                end
            end
        end
    end
end

-- Disable Bank Scanner: remove CanTouch do sensor do mapa Bank
local function SetBankScanner(disabled)
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj.Name == "Sensor" and obj:IsA("BasePart") then
            pcall(function() obj.CanTouch = not disabled end)
        end
    end
end

-- Anti Fling: desativa CanCollide de todos os outros players
local function StartAntiFling()
    if TrollState._antiFlingConn then
        TrollState._antiFlingConn:Disconnect()
        TrollState._antiFlingConn = nil
    end
    -- Restaura partes antigas
    for part, _ in pairs(TrollState.AntiFlingParts) do
        pcall(function() part.CanCollide = true end)
    end
    TrollState.AntiFlingParts = {}
    if not TrollState.AntiFling then return end
    TrollState._antiFlingConn = RunService.Heartbeat:Connect(function()
        if not TrollState.AntiFling then return end
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                for _, part in ipairs(p.Character:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide then
                        part.CanCollide = false
                        TrollState.AntiFlingParts[part] = true
                    end
                end
            end
        end
    end)
end

-- Rejoin
local function Rejoin()
    local ts = game:GetService("TeleportService")
    local placeId = game.PlaceId
    local jobId   = game.JobId
    pcall(function()
        if #Players:GetPlayers() > 1 then
            ts:TeleportToPlaceInstance(placeId, jobId, LocalPlayer)
        else
            ts:Teleport(placeId, LocalPlayer)
        end
    end)
end

-- Server Hop
local function ServerHop()
    local ts = game:GetService("TeleportService")
    local HttpService = game:GetService("HttpService")
    local placeId = game.PlaceId
    pcall(function()
        local data = HttpService:JSONDecode(game:HttpGet(
            "https://games.roblox.com/v1/games/"..placeId.."/servers/Public?sortOrder=Asc&limit=100"
        ))
        for _, srv in ipairs(data.data or {}) do
            if srv.id ~= game.JobId and srv.playing < srv.maxPlayers then
                ts:TeleportToPlaceInstance(placeId, srv.id, LocalPlayer)
                return
            end
        end
        -- fallback sem job específico
        ts:Teleport(placeId, LocalPlayer)
    end)
end

-- Anti AFK
local function SetAntiAFK(on)
    if TrollState.AntiAFKConn then
        TrollState.AntiAFKConn:Disconnect()
        TrollState.AntiAFKConn = nil
    end
    if on then
        local VirtualUser = game:GetService("VirtualUser")
        TrollState.AntiAFKConn = Players.LocalPlayer.Idled:Connect(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end
end

-- Spam Fake Bomb
local function StartSpamFakeBomb()
    task.spawn(function()
        while TrollState.SpamFakeBomb do
            pcall(function()
                local char = LocalPlayer.Character
                if not char then return end
                local bp   = LocalPlayer.Backpack
                local bomb = bp:FindFirstChild("FakeBomb") or char:FindFirstChild("FakeBomb")
                if not bomb then
                    ReplicatedStorage.Remotes.Extras.ReplicateToy:InvokeServer("FakeBomb")
                    bomb = bp:WaitForChild("FakeBomb", 3)
                end
                if not bomb then return end
                if bomb.Parent ~= char then bomb.Parent = char end
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local remote = bomb:FindFirstChild("Remote")
                    if remote then remote:FireServer(hrp.CFrame * CFrame.new(0,-3,0), 50) end
                end
                task.wait(0.3)
                if bomb.Parent == char then bomb.Parent = bp end
            end)
            task.wait(22)  -- cooldown do FakeBomb
        end
    end)
end

-- Heartbeat do AntiFling integrado (já usando RunService.Heartbeat acima com conn separada)

-- ============================================================
-- MISC / TROLLING LOGIC (portado do e0)
-- ============================================================

-- Auto Fake Bomb Clutch: usa FakeBomb embaixo do player ao saltar (e0 AutoFakeBombClutch)
local function SetAutoFakeBombClutch(on)
    if TrollState._bombClutchConn then
        TrollState._bombClutchConn:Disconnect()
        TrollState._bombClutchConn = nil
    end
    if not on then return end
    TrollState._bombClutchConn = RunService.Heartbeat:Connect(function()
        if not TrollState.AutoFakeBombClutch then return end
        if not IsRoundStarted then return end
        local char = LocalPlayer.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        -- só ativa quando estiver saltando
        if hum:GetState() ~= Enum.HumanoidStateType.Jumping and
           hum:GetState() ~= Enum.HumanoidStateType.Freefall then return end
        pcall(function()
            local bp  = LocalPlayer.Backpack
            local bomb = bp:FindFirstChild("FakeBomb") or char:FindFirstChild("FakeBomb")
            if not bomb then
                ReplicatedStorage.Remotes.Extras.ReplicateToy:InvokeServer("FakeBomb")
                bomb = bp:WaitForChild("FakeBomb", 2)
            end
            if not bomb then return end
            if bomb.Parent ~= char then bomb.Parent = char end
            local remote = bomb:FindFirstChild("Remote")
            if remote then
                remote:FireServer(hrp.CFrame * CFrame.new(0, -3, 0), 50)
            end
            task.wait(0.5)
            if bomb and bomb.Parent == char then bomb.Parent = bp end
        end)
    end)
end

-- Mute Coins Sound (e0 MuteCoinsSound)
local function SetMuteCoinsSound(on)
    TrollState.MuteCoinsSound = on
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Sound") and (obj.Name == "CoinSound" or obj.Name == "BeachBallSound") then
            pcall(function() obj.Volume = on and 0 or 0.2 end)
        end
    end
    if on then
        Conn("muteCoinsSnd", Workspace.DescendantAdded:Connect(function(obj)
            if TrollState.MuteCoinsSound and obj:IsA("Sound") and
               (obj.Name == "CoinSound" or obj.Name == "BeachBallSound") then
                pcall(function() obj.Volume = 0 end)
            end
        end))
    else
        if conns.muteCoinsSnd then conns.muteCoinsSnd:Disconnect(); conns.muteCoinsSnd = nil end
    end
end

-- Hide Coins visually (e0 HideCoins) — só esconde o visual, não destrói
local function SetHideCoins(on)
    State.HideCoins = on
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj.Name == "Coin_Server" and obj:IsA("BasePart") then
            local cv = obj:FindFirstChild("CoinVisual")
            if cv then
                for _, p in ipairs(cv:GetDescendants()) do
                    if p:IsA("BasePart") or p:IsA("Decal") then
                        pcall(function() p.Transparency = on and 1 or 0 end)
                    end
                end
                pcall(function() cv.Transparency = on and 1 or 0 end)
            end
        end
    end
    if on then
        Conn("hideCoins", Workspace.DescendantAdded:Connect(function(obj)
            if State.HideCoins and obj.Name == "Coin_Server" and obj:IsA("BasePart") then
                task.wait(0.05)
                local cv = obj:FindFirstChild("CoinVisual")
                if cv then
                    for _, p in ipairs(cv:GetDescendants()) do
                        if p:IsA("BasePart") or p:IsA("Decal") then
                            pcall(function() p.Transparency = 1 end)
                        end
                    end
                    pcall(function() cv.Transparency = 1 end)
                end
            end
        end))
    else
        if conns.hideCoins then conns.hideCoins:Disconnect(); conns.hideCoins = nil end
    end
end

-- ============================================================
-- TROLL TAB — UI
-- ============================================================
local Troll = Window:Tab({Title="Trolling", Icon="skull"})
Window:Line()

Troll:Section({Title="Server"})

Troll:Button({
    Title    = "Rejoin",
    Desc     = "Reconecta ao servidor atual",
    Callback = function() Rejoin() end,
})
Troll:Button({
    Title    = "Server Hop",
    Desc     = "Vai para outro servidor",
    Callback = function() ServerHop() end,
})
Troll:Toggle({
    Title    = "Rejoin When Kicked",
    Desc     = "Tenta reconectar automaticamente se for kickado",
    Value    = false,
    Callback = function(v) TrollState.RejoinWhenKicked = v end,
})
Troll:Toggle({
    Title    = "Server Hop When Empty",
    Desc     = "Vai para outro servidor quando sobrar poucos players",
    Value    = false,
    Callback = function(v) TrollState.ServerHopWhenEmpty = v end,
})
Troll:Slider({
    Title    = "Hop When Players ≤ X",
    Min      = 1, Max = 10, Rounding = 0, Value = 3,
    Callback = function(v) TrollState.ServerHopAfter = v end,
})
Troll:Toggle({
    Title    = "End Round When Dead",
    Desc     = "Ao morrer tenta encerrar a rodada (fling no murderer)",
    Value    = false,
    Callback = function(v) TrollState.EndRoundWhenDead = v end,
})
Troll:Button({
    Title    = "End Round",
    Desc     = "Flings the murderer to end the round; if you're the murderer, kills all instead",
    Callback = function()
        local role = GetCachedRole()
        if role == "Murderer" then
            KillAll()
        else
            -- Flinga o murderer diretamente — sem morrer primeiro
            local murder = GetMurderer()
            if murder and murder.Character and murder.Character:FindFirstChild("HumanoidRootPart") then
                FlingKill(murder)
            else
                -- Sem murderer encontrado: morre como fallback
                local hum = GetHum()
                if hum then hum.Health = 0 end
            end
        end
    end,
})
Troll:Toggle({
    Title    = "Anti AFK",
    Desc     = "Evita ser kickado por AFK",
    Value    = false,
    Callback = function(v)
        TrollState.AntiAFK = v
        SetAntiAFK(v)
    end,
})

Troll:Section({Title="Gun"})

Troll:Button({
    Title    = "Break Gun",
    Desc     = "Quebra a gun do Sheriff via remote",
    Callback = function() BreakGun() end,
})
Troll:Toggle({
    Title    = "Auto Break Gun",
    Desc     = "Quebra a gun do Sheriff em loop",
    Value    = false,
    Callback = function(v)
        TrollState.AutoBreakGun = v
        if v then
            task.spawn(function()
                while TrollState.AutoBreakGun do
                    if IsRoundStarted and GetSheriff() then BreakGun() end
                    task.wait(1)
                end
            end)
        end
    end,
})

Troll:Section({Title="Players"})

Troll:Toggle({
    Title    = "Anti Fling",
    Desc     = "Desativa CanCollide dos outros players",
    Value    = false,
    Callback = function(v)
        TrollState.AntiFling = v
        StartAntiFling()
    end,
})
Troll:Toggle({
    Title    = "Mute Other Radios",
    Desc     = "Silencia os rádios de todos os outros",
    Value    = false,
    Callback = function(v)
        TrollState.MuteOtherRadios = v
        MuteOtherRadios(v)
    end,
})

Troll:Section({Title="Map"})

Troll:Toggle({
    Title    = "Disable Bank Scanner",
    Desc     = "Remove CanTouch do sensor do mapa Bank",
    Value    = false,
    Callback = function(v)
        TrollState.DisableBank = v
        SetBankScanner(v)
    end,
})
Troll:Toggle({
    Title    = "Destroy Barriers",
    Desc     = "Destroi GlitchProof/InvisWalls do mapa",
    Value    = false,
    Callback = function(v)
        State.DestroyBarriers = v
        if v then
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj.Name == "GlitchProof" or obj.Name == "InvisWalls" then
                    pcall(function() obj:Destroy() end)
                end
            end
        end
    end,
})

Troll:Section({Title="Fun"})

Troll:Toggle({
    Title    = "Spam Fake Bomb",
    Desc     = "Usa FakeBomb repetidamente (precisa ter o toy)",
    Value    = false,
    Callback = function(v)
        TrollState.SpamFakeBomb = v
        if v then StartSpamFakeBomb() end
    end,
})
Troll:Toggle({
    Title    = "Auto Fake Bomb Clutch",
    Desc     = "Detona FakeBomb embaixo de você ao saltar",
    Value    = false,
    Callback = function(v)
        TrollState.AutoFakeBombClutch = v
        SetAutoFakeBombClutch(v)
    end,
})

Troll:Section({Title = "Coins"})

Troll:Toggle({
    Title    = "Mute Coins Sound",
    Desc     = "Silencia o som das moedas",
    Value    = false,
    Callback = function(v) SetMuteCoinsSound(v) end,
})
Troll:Toggle({
    Title    = "Hide Coins",
    Desc     = "Esconde o visual das moedas (não destrói)",
    Value    = false,
    Callback = function(v) SetHideCoins(v) end,
})
Troll:Toggle({
    Title    = "Destroy Coins",
    Desc     = "Destrói todas as moedas do mapa",
    Value    = false,
    Callback = function(v)
        State.DestroyCoins = v
        if v then
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj.Name == "Coin_Server" and obj:IsA("BasePart") then
                    pcall(function() obj:Destroy() end)
                end
            end
        end
    end,
})

-- ============================================================
-- WHITELIST — jogadores excluídos de KillAll / FlingAll
-- ============================================================
local Whitelist = {}  -- set: Whitelist[name] = true

local function IsWhitelisted(name)
    return Whitelist[name] == true
end

local function WhitelistAdd(name)
    if name and name ~= "" then Whitelist[name] = true end
end

local function WhitelistRemove(name)
    Whitelist[name] = nil
end

-- Patch KillAll para respeitar whitelist
local _origKillAll = KillAll
KillAll = function()
    task.spawn(function()
        if GetCachedRole() ~= "Murderer" then return end
        EquipKnifeFromBackpack()
        local knife = GetKnifeInChar()
        if not knife then return end
        local handle = knife:FindFirstChild("Handle")
        if not handle then return end
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and IsAlive(p) and p.Character and not IsWhitelisted(p.Name) then
                local role = RoleCache[p.Name]
                if role == "Innocent" or role == "Sheriff" or role == "Hero" then
                    local tHRP = p.Character:FindFirstChild("HumanoidRootPart")
                    if tHRP then
                        tHRP.CFrame = handle.CFrame
                        tHRP.AssemblyLinearVelocity = Vector3.zero
                        tHRP.AssemblyAngularVelocity = Vector3.zero
                        task.wait(0.05); DoStab()
                        pcall(firetouchinterest, tHRP, handle, 1)
                        pcall(firetouchinterest, tHRP, handle, 0)
                        task.wait(0.1)
                    end
                end
            end
        end
    end)
end

-- Patch FlingKill para respeitar whitelist
local _origFlingKill = FlingKill
FlingKill = function(target)
    if target == "All" then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and IsAlive(p) and not IsWhitelisted(p.Name) then
                Fling(p)
            end
        end
    else
        local plr = type(target) == "string" and Players:FindFirstChild(target) or target
        if plr and plr ~= LocalPlayer and not IsWhitelisted(plr.Name) then Fling(plr) end
    end
end

-- ============================================================
-- SPECTATE PLAYER — exato do e0
-- ============================================================
local function SpectatePlayer(mode, playerName)
    pcall(function()
        if mode == "Stop" then
            Camera.CameraSubject = GetHum()
        elseif mode == "Murderer" then
            local m = GetMurderer()
            if m and m.Character then
                Camera.CameraSubject = m.Character:FindFirstChildOfClass("Humanoid")
            end
        elseif mode == "Sheriff" then
            local s = GetSheriff()
            if s and s.Character then
                Camera.CameraSubject = s.Character:FindFirstChildOfClass("Humanoid")
            end
        elseif mode == "Player" and playerName then
            local p = Players:FindFirstChild(playerName)
            if p and p.Character then
                Camera.CameraSubject = p.Character:FindFirstChildOfClass("Humanoid")
            end
        end
    end)
end

-- ============================================================
-- TRADE — exato do e0 (SendRequest / AcceptTrade / DeclineTrade)
-- ============================================================
local function SendTradeRequest(playerName)
    pcall(function()
        local p = Players:FindFirstChild(playerName)
        if not p then return end
        ReplicatedStorage:WaitForChild("Trade"):WaitForChild("SendRequest"):FireServer(p)
    end)
end

local function AcceptTrade()
    pcall(function()
        ReplicatedStorage:WaitForChild("Trade"):WaitForChild("AcceptTrade"):FireServer(game.PlaceId * 2)
    end)
end

local function DeclineTrade()
    pcall(function()
        ReplicatedStorage:WaitForChild("Trade"):WaitForChild("DeclineTrade"):FireServer()
    end)
end

-- Auto Accept: escuta incoming trade requests
local _autoAcceptTradeConn = nil
local function SetAutoAcceptTrade(on)
    if _autoAcceptTradeConn then _autoAcceptTradeConn:Disconnect(); _autoAcceptTradeConn = nil end
    if not on then return end
    -- Escuta UpdateTrade OnClientEvent — quando status vira "StartTrade" aceita
    pcall(function()
        local updateEv = ReplicatedStorage:WaitForChild("Trade", 3)
            and ReplicatedStorage.Trade:FindFirstChild("UpdateTrade")
        if not updateEv then return end
        _autoAcceptTradeConn = updateEv.OnClientEvent:Connect(function(status)
            if status == "StartTrade" or status == "RequestReceived" then
                task.wait(0.2)
                AcceptTrade()
            end
        end)
    end)
end

-- ============================================================
-- TAG PLAYER — Spray no UpperTorso do alvo (exato do e0)
-- ============================================================
local TAG_ID = 11675568048  -- default tag ID do e0

local function SprayOnPlayer(playerName, tagId)
    pcall(function()
        local p = Players:FindFirstChild(playerName)
        if not p or not p.Character then return end
        local torso = p.Character:FindFirstChild("UpperTorso")
            or p.Character:FindFirstChild("Torso")
        if not torso then return end

        -- Equipa SprayPaint do backpack ou pede via ReplicateToy
        local hum  = GetHum()
        local char = GetChar()
        if not (hum and char) then return end

        local spray = char:FindFirstChild("SprayPaint")
            or LocalPlayer.Backpack:FindFirstChild("SprayPaint")
        local fromRepl = false
        if not spray then
            pcall(function()
                ReplicatedStorage.Remotes.Extras.ReplicateToy:InvokeServer("SprayPaint")
            end)
            task.wait(0.3)
            spray = LocalPlayer.Backpack:FindFirstChild("SprayPaint")
            fromRepl = true
        end
        if not spray then return end

        -- Move para char se necessário
        local wasInBP = spray.Parent == LocalPlayer.Backpack
        if wasInBP then spray.Parent = char end

        local remote = spray:FindFirstChild("Remote")
        if remote then
            local offset = Vector3.new(0, 0, 3)
            local sprayPos = CFrame.new(torso.Position + offset)
            pcall(function()
                remote:FireServer(tagId or TAG_ID, Enum.NormalId.Front, 5, torso, sprayPos)
            end)
        end

        if wasInBP and spray.Parent == char then spray.Parent = LocalPlayer.Backpack end
    end)
end

-- ============================================================
-- VIEW GEMS / COINS DE OUTRO PLAYER — GetFullInventory do e0
-- ============================================================
local function GetPlayerInventory(playerName)
    local ok, data = pcall(function()
        return ReplicatedStorage.Remotes.Extras.GetFullInventory:InvokeServer(playerName)
    end)
    if ok and data then
        return data.Coins or 0, data.Gems or 0
    end
    return 0, 0
end

-- ============================================================
-- ANTI AUDIO SPAM — bloca sons acima do volume threshold
-- ============================================================
local _antiAudioConn = nil
local AUDIO_VOL_THRESHOLD = 0.8

local function SetAntiAudioSpam(on)
    if _antiAudioConn then _antiAudioConn:Disconnect(); _antiAudioConn = nil end
    if not on then return end

    -- Silencia sons já existentes acima do threshold
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Sound") and obj.Volume > AUDIO_VOL_THRESHOLD then
            pcall(function()
                -- Só silencia sons que não são do LocalPlayer
                local owner = obj:FindFirstAncestorWhichIsA("Player")
                if not owner or owner ~= LocalPlayer then
                    obj.Volume = 0
                end
            end)
        end
    end

    -- Monitora novos sons
    _antiAudioConn = Workspace.DescendantAdded:Connect(function(obj)
        if obj:IsA("Sound") and obj.Volume > AUDIO_VOL_THRESHOLD then
            task.wait()  -- espera o som ser parented completamente
            pcall(function()
                local owner = obj:FindFirstAncestorWhichIsA("Player")
                if not owner or owner ~= LocalPlayer then
                    obj.Volume = 0
                end
            end)
        end
    end)
end

-- ============================================================
-- AUTO VOTE MAP — clica no botão da GUI de votação
-- ============================================================
local _autoVoteMapName = ""
local _autoVoteConn = nil

local function TryVoteMap(mapName)
    pcall(function()
        local pg = LocalPlayer:FindFirstChildWhichIsA("PlayerGui")
        if not pg then return end
        -- Procura qualquer frame/gui de votação com botão que contenha o nome do mapa
        for _, gui in ipairs(pg:GetDescendants()) do
            if (gui:IsA("TextButton") or gui:IsA("ImageButton")) then
                local txt = gui.Name .. " " .. (gui:IsA("TextButton") and gui.Text or "")
                if txt:lower():find(mapName:lower()) then
                    pcall(function()
                        -- Simula clique via RemoteEvent de votação se existir
                        local voteRemote = ReplicatedStorage.Remotes:FindFirstChild("VoteMap")
                            or ReplicatedStorage.Remotes:FindFirstChild("ChooseMap")
                            or ReplicatedStorage.Remotes:FindFirstChild("Vote")
                        if voteRemote then
                            voteRemote:FireServer(mapName)
                        else
                            -- Fallback: fire mouse click no botão
                            local ms = game:GetService("VirtualInputManager")
                            local pos = gui.AbsolutePosition + gui.AbsoluteSize/2
                            ms:SendMouseButtonEvent(pos.X, pos.Y, 0, true, game, 0)
                            task.wait(0.05)
                            ms:SendMouseButtonEvent(pos.X, pos.Y, 0, false, game, 0)
                        end
                    end)
                    return
                end
            end
        end
    end)
end

local function SetAutoVoteMap(on, mapName)
    if _autoVoteConn then _autoVoteConn:Disconnect(); _autoVoteConn = nil end
    if not on or not mapName or mapName == "" then return end
    _autoVoteMapName = mapName

    -- Vota imediatamente se já há GUI de votação
    TryVoteMap(mapName)

    -- Escuta quando a GUI de votação aparecer
    _autoVoteConn = LocalPlayer.PlayerGui.ChildAdded:Connect(function(child)
        task.wait(0.5)
        TryVoteMap(_autoVoteMapName)
    end)
end

-- ============================================================
-- TAB: SOCIAL (Whitelist, Trade, Spectate, Tag, View, Vote)
-- ============================================================
local Social = Window:Tab({Title="Social", Icon="users"})
Window:Line()

-- ---- WHITELIST ----
Social:Section({Title="Whitelist"})

local _wlSelected = ""
Social:Dropdown({
    Title    = "Jogador",
    List     = playerList,
    Value    = playerList[1] or "",
    Callback = function(v) _wlSelected = v end,
})
Social:Button({
    Title    = "Adicionar à Whitelist",
    Desc     = "Protege esse player de KillAll e FlingAll",
    Callback = function()
        if _wlSelected == "" then return end
        WhitelistAdd(_wlSelected)
        Window:Notify({Title="Whitelist", Desc=_wlSelected.." adicionado.", Time=3})
    end,
})
Social:Button({
    Title    = "Remover da Whitelist",
    Callback = function()
        if _wlSelected == "" then return end
        WhitelistRemove(_wlSelected)
        Window:Notify({Title="Whitelist", Desc=_wlSelected.." removido.", Time=3})
    end,
})
Social:Toggle({
    Title    = "Whitelist Murderer (auto)",
    Desc     = "Adiciona o Murderer atual automaticamente",
    Value    = false,
    Callback = function(v)
        if v then
            -- adiciona murderer atual e escuta próximos rounds
            local m = GetMurderer()
            if m then WhitelistAdd(m.Name) end
            Conn("wlMurder", ReplicatedStorage:WaitForChild("Remotes",5) and
                ReplicatedStorage.Remotes:FindFirstChild("Gameplay") and
                ReplicatedStorage.Remotes.Gameplay:FindFirstChild("RoundStart") and
                ReplicatedStorage.Remotes.Gameplay.RoundStart.OnClientEvent:Connect(function()
                    task.wait(1)
                    local mu = GetMurderer()
                    if mu then WhitelistAdd(mu.Name) end
                end) or nil)
        else
            if conns["wlMurder"] then conns["wlMurder"]:Disconnect(); conns["wlMurder"]=nil end
        end
    end,
})

-- ---- SPECTATE ----
Social:Section({Title="Spectate"})

local _specTarget = playerList[1] or ""
Social:Dropdown({
    Title    = "Spectate Target",
    List     = playerList,
    Value    = playerList[1] or "",
    Callback = function(v) _specTarget = v end,
})
Social:Button({Title="Spectate Player",   Callback=function() SpectatePlayer("Player",   _specTarget) end})
Social:Button({Title="Spectate Murderer", Callback=function() SpectatePlayer("Murderer") end})
Social:Button({Title="Spectate Sheriff",  Callback=function() SpectatePlayer("Sheriff")  end})
Social:Button({Title="Parar Spectate",    Callback=function() SpectatePlayer("Stop")     end})

-- ---- TRADE ----
Social:Section({Title="Trade"})

local _tradeTarget = playerList[1] or ""
Social:Dropdown({
    Title    = "Trade Target",
    List     = playerList,
    Value    = playerList[1] or "",
    Callback = function(v) _tradeTarget = v end,
})
Social:Button({
    Title    = "Enviar Trade Request",
    Callback = function()
        if _tradeTarget == "" then return end
        SendTradeRequest(_tradeTarget)
        Window:Notify({Title="Trade", Desc="Request enviado para ".._tradeTarget, Time=3})
    end,
})
Social:Button({Title="Aceitar Trade",  Callback=function() AcceptTrade()  end})
Social:Button({Title="Recusar Trade",  Callback=function() DeclineTrade() end})
Social:Toggle({
    Title    = "Auto Aceitar Trades",
    Desc     = "Aceita automaticamente qualquer trade recebido",
    Value    = false,
    Callback = function(v) SetAutoAcceptTrade(v) end,
})

-- ---- TAG PLAYER ----
Social:Section({Title="Tag Player"})

local _tagTarget = playerList[1] or ""
local _tagIdInput = tostring(TAG_ID)
Social:Dropdown({
    Title    = "Tag Target",
    List     = playerList,
    Value    = playerList[1] or "",
    Callback = function(v) _tagTarget = v end,
})
Social:Textbox({
    Title       = "Tag ID (Decal)",
    Desc        = "ID do decal para o spray",
    Placeholder = tostring(TAG_ID),
    Value       = tostring(TAG_ID),
    ClearTextOnFocus = false,
    Callback    = function(v)
        local n = tonumber(v)
        if n then TAG_ID = n; _tagIdInput = v end
    end,
})
Social:Button({
    Title    = "Tag Player",
    Desc     = "Spray no UpperTorso do jogador",
    Callback = function()
        if _tagTarget == "" then return end
        SprayOnPlayer(_tagTarget, TAG_ID)
        Window:Notify({Title="Tag", Desc="Tagged: ".._tagTarget, Time=2})
    end,
})

-- ---- VIEW GEMS / COINS ----
Social:Section({Title="View Player Info"})

local _viewTarget = playerList[1] or ""
Social:Dropdown({
    Title    = "View Target",
    List     = playerList,
    Value    = playerList[1] or "",
    Callback = function(v) _viewTarget = v end,
})
Social:Button({
    Title    = "Ver Coins / Gems",
    Desc     = "Consulta o inventário do jogador",
    Callback = function()
        if _viewTarget == "" then return end
        local coins, gems = GetPlayerInventory(_viewTarget)
        Window:Notify({
            Title = _viewTarget,
            Desc  = "Coins: "..tostring(coins).."  |  Gems: "..tostring(gems),
            Time  = 6,
        })
    end,
})

-- ---- ANTI AUDIO SPAM ----
Social:Section({Title="Anti Audio Spam"})

Social:Slider({
    Title    = "Volume Threshold",
    Desc     = "Sons acima desse valor são silenciados",
    Min      = 0.1, Max = 1.0, Rounding = 1, Value = 0.8,
    Callback = function(v) AUDIO_VOL_THRESHOLD = v end,
})
Social:Toggle({
    Title    = "Anti Audio Spam",
    Desc     = "Silencia sons muito altos de outros jogadores",
    Value    = false,
    Callback = function(v) SetAntiAudioSpam(v) end,
})

-- ---- AUTO VOTE MAP ----
Social:Section({Title="Auto Vote Map"})

local _voteMapName = ""
local _autoVoteOn  = false
Social:Textbox({
    Title       = "Nome do Mapa",
    Placeholder = "ex: Mansion, Station...",
    Value       = "",
    ClearTextOnFocus = false,
    Callback    = function(v) _voteMapName = v end,
})
Social:Toggle({
    Title    = "Auto Vote Map",
    Desc     = "Vota automaticamente no mapa escolhido",
    Value    = false,
    Callback = function(v)
        _autoVoteOn = v
        SetAutoVoteMap(v, _voteMapName)
    end,
})
Social:Button({
    Title    = "Votar Agora",
    Desc     = "Força o voto imediatamente",
    Callback = function()
        if _voteMapName == "" then
            Window:Notify({Title="Vote", Desc="Digite o nome do mapa primeiro.", Time=3})
            return
        end
        TryVoteMap(_voteMapName)
        Window:Notify({Title="Vote", Desc="Votando em: ".._voteMapName, Time=3})
    end,
})

Window:Notify({Title="MM2 Hub", Desc="Carregado! RCtrl para abrir.", Time=4})
