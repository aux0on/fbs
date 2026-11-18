local table_insert = table.insert
local table_find = table.find
local math_abs = math.abs

local Maid = {}
Maid.__index = Maid

function Maid.new()
    return setmetatable({_tasks = {}, _destroyed = false}, Maid)
end

function Maid:GiveTask(task)
    if self._destroyed then
        self:_cleanupTask(task)
        return
    end
    table_insert(self._tasks, task)
    return task
end

function Maid:GiveTasks(...)
    for _, task in ipairs({...}) do
        self:GiveTask(task)
    end
end

function Maid:_cleanupTask(task)
    local taskType = typeof(task)
    if taskType == "RBXScriptConnection" then
        task:Disconnect()
    elseif taskType == "Instance" then
        task:Destroy()
    elseif taskType == "function" then
        task()
    elseif taskType == "table" and type(task.Destroy) == "function" then
        task:Destroy()
    end
end

function Maid:DoCleaning()
    if self._destroyed then return end
    self._destroyed = true
    for _, task in ipairs(self._tasks) do
        self:_cleanupTask(task)
    end
    self._tasks = {}
end

function Maid:Destroy()
    self:DoCleaning()
end

local RootMaid = Maid.new()

local shared = odh_shared_plugins
task.spawn(function()
    shared.load_from_github_url("/aux0on/CrashHandler/refs/heads/main/Prevention.lua")
end)

if shared.game_name ~= "Murder Mystery 2" and shared.game_name ~= "Murder Mystery Modded" then return end

local Services = {
    Players = game:GetService("Players"),
    ReplicatedStorage = game:GetService("ReplicatedStorage"),
    RunService = game:GetService("RunService"),
    UserInputService = game:GetService("UserInputService"),
    TeleportService = game:GetService("TeleportService"),
    HttpService = game:GetService("HttpService"),
    Lighting = game:GetService("Lighting"),
    MarketplaceService = game:GetService("MarketplaceService"),
    StarterGui = game:GetService("StarterGui"),
    CoreGui = game:GetService("CoreGui"),
    Debris = game:GetService("Debris"),
    VirtualUser = game:GetService("VirtualUser"),
    Stats = game:GetService("Stats"),
    Workspace = game:GetService("Workspace"),
    TweenService = game:GetService("TweenService")
}

local LocalPlayer = Services.Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local PlaceId, JobId = game.PlaceId, game.JobId

local __INSERT = table.insert
local __PCLR = Color3.new
local __RGB = Color3.fromRGB
local __UD2 = UDim2.new
local __UD = UDim.new
local __V2 = Vector2.new

local function getfserv(s)
    local ok, svc = pcall(function() return game:GetService(s) end)
    if ok and svc then return svc end
    ok, svc = pcall(function() return game:FindService(s) end)
    if ok and svc then return svc end
    return game[s]
end

local __RS  = getfserv("RunService")
local __UIS  = getfserv("UserInputService")
local __PLRS = getfserv("Players")
local __TS  = getfserv("TweenService")

local function safe_call(fn, ...)
    if not fn then return end
    local ok, err = pcall(fn, ...)
    if not ok then warn("[FunBomb] " .. tostring(err)) end
end

local function safe_cancel(thread)
    if not thread then return end
    pcall(function() task.cancel(thread) end)
end

local SAVE_FILE = "FB_BP.json"

local function savePositions(data)
    pcall(function()
        if writefile then
            writefile(SAVE_FILE, Services.HttpService:JSONEncode(data))
        end
    end)
end

local function loadPositions()
    local ok, result = pcall(function()
        if readfile and isfile and isfile(SAVE_FILE) then
            return Services.HttpService:JSONDecode(readfile(SAVE_FILE))
        end
    end)
    if ok and type(result) == "table" then return result end
    return {}
end

local savedPositions = loadPositions()

local muteButtonSounds = false
local bombButtonsLocked = false

local BindableButtons = {Buttons = {}, Maids = {}, Count = 0}
local activeStrokes = setmetatable({}, {__mode = "k"})

local bfsToggleActive   = false
local bfmToggleActive   = false
local bfspToggleActive  = false
local bfsLoopMaid       = nil
local bfmLoopMaid       = nil
local bfspLoopMaid      = nil
local trollPlayerLoopMaid = nil

RootMaid:GiveTask(__RS.RenderStepped:Connect(function()
    for stroke, _ in pairs(activeStrokes) do
        if stroke and stroke.Parent then
            stroke.Rotation = (stroke.Rotation + 1) % 360
        end
    end
end))

local function UpdateAllButtonSounds()
    local volume = muteButtonSounds and 0 or 0.5
    for _, btn in pairs(BindableButtons.Buttons) do
        local sound = btn and btn:FindFirstChild("Sound")
        if sound then
            sound.Volume = volume
        end
    end
end

local __SHAPES = {
    [0] = "rbxassetid://86221076925479",
    [1] = "rbxassetid://96242665417546",
    [2] = "rbxassetid://97129189935336",
    [3] = "rbxassetid://76165862027868",
    [4] = "rbxassetid://125868092127496"
}

local __NORMAL_COLOR = ColorSequence.new({
    ColorSequenceKeypoint.new(0,   __PCLR(0.133333, 0.827451, 0.494118)),
    ColorSequenceKeypoint.new(0.6, __PCLR(0.231373, 0.509804, 0.498039)),
    ColorSequenceKeypoint.new(1,   __PCLR(0.501961, 0.501961, 0.501961))
})

local function Bind_GetStorage()
    local parent = gethui and gethui()
    if not parent or typeof(parent) ~= "Instance" then
        parent = __PLRS.LocalPlayer:WaitForChild("PlayerGui", 5)
    end
    if not parent or typeof(parent) ~= "Instance" then
        parent = getfserv("CoreGui")
    end
    if not parent or typeof(parent) ~= "Instance" then
        parent = __PLRS.LocalPlayer:WaitForChild("PlayerGui")
    end

    local sg = parent:FindFirstChild("@bindstorage")
    if not sg then
        sg = Instance.new("ScreenGui")
        sg.Name = "@bindstorage"
        sg.ResetOnSpawn = false
        sg.IgnoreGuiInset = true
        pcall(function() sg.ScreenInsets = Enum.ScreenInsets.None end)
        sg.Parent = parent
    end
    return sg
end

local function GetSafeGuiRoot()
    local success, result = pcall(function() return gethui() end)
    if success and result and typeof(result) == "Instance" then
        return result
    end
    return Services.CoreGui
end

local function Notify(title, text, duration)
    if shared.Notify then
        shared.Notify(text, duration or 2)
    else
        pcall(function()
            Services.StarterGui:SetCore("SendNotification", {Title = title, Text = text, Duration = duration or 2})
        end)
    end
end

local function Bind_MakeDraggable(gui, maid, ripple, sound, clickFunc)
    local dragging, dragInput, dragStart, startPos
    local wasDragged = false

    maid:GiveTask(gui.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragStart = input.Position
            startPos = gui.Position
            dragging = true
            wasDragged = false

            sound:Play()
            local absPos = gui.AbsolutePosition
            ripple.Position = __UD2(0, input.Position.X - absPos.X, 0, input.Position.Y - absPos.Y)
            ripple.Size = __UD2(0, 0, 0, 0)
            ripple.BackgroundTransparency = 0.5
            ripple.Visible = true
            __TS:Create(ripple, TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
                Size = __UD2(0, 45, 0, 45),
                BackgroundTransparency = 1
            }):Play()

            local rel
            rel = __UIS.InputEnded:Connect(function(endInput)
                if endInput.UserInputType == input.UserInputType then
                    dragging = false
                    local totalDelta = endInput.Position - dragStart
                    if totalDelta.Magnitude > 6 then
                        wasDragged = true
                    end

                    if not bombButtonsLocked and wasDragged then
                        savedPositions[gui.Name] = {
                            xs = gui.Position.X.Scale, xo = gui.Position.X.Offset,
                            ys = gui.Position.Y.Scale, yo = gui.Position.Y.Offset
                        }
                        savePositions(savedPositions)
                    elseif not wasDragged then
                        safe_call(clickFunc)
                    end
                    if rel then rel:Disconnect() end
                end
            end)
        end
    end))

    maid:GiveTask(gui.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end))

    maid:GiveTask(__UIS.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            if delta.Magnitude > 5 then
                wasDragged = true
            end

            if not bombButtonsLocked and wasDragged then
                local screen = gui.Parent.AbsoluteSize
                gui.Position = __UD2(startPos.X.Scale + (delta.X / screen.X), 0, startPos.Y.Scale + (delta.Y / screen.Y), 0)
            end
        end
    end))
end

function BindableButtons.AddBButton(id, text, clickFunc)
    if BindableButtons.Buttons[id] then return end

    local buttonMaid = Maid.new()
    local camera = workspace.CurrentCamera
    local screen = camera.ViewportSize
    local buttonSizeY = 0.11
    local widthScale = buttonSizeY * (screen.Y / screen.X)

    local sp = savedPositions[id]
    local xPos, yPos
    if sp then
        xPos = sp.xs
        yPos = sp.ys
    else
        xPos = 0.1 + ((BindableButtons.Count % 8) * (widthScale + 0.005))
        yPos = 0.9 - (math.floor(BindableButtons.Count / 8) * (buttonSizeY + 0.015))
    end

    local ImageButton = Instance.new("ImageButton")
    ImageButton.Name = id
    ImageButton.Size = __UD2(widthScale, 0, buttonSizeY, 0)
    if sp then
        ImageButton.Position = __UD2(sp.xs, sp.xo, sp.ys, sp.yo)
    else
        ImageButton.Position = __UD2(xPos, 0, yPos, 0)
    end
    ImageButton.AnchorPoint = __V2(0.5, 0.5)
    ImageButton.Image = __SHAPES[0]
    ImageButton.BackgroundTransparency = 1
    ImageButton.BorderSizePixel = 0
    ImageButton.ClipsDescendants = false
    ImageButton.AutoButtonColor = false
    ImageButton.Parent = Bind_GetStorage()
    buttonMaid:GiveTask(ImageButton)

    local TextLabel = Instance.new("TextLabel", ImageButton)
    TextLabel.Name = "@Text"
    TextLabel.Size = __UD2(0.8, 0, 0.8, 0)
    TextLabel.Position = __UD2(0.5, 0, 0.5, 0)
    TextLabel.AnchorPoint = __V2(0.5, 0.5)
    TextLabel.BackgroundTransparency = 1
    TextLabel.Font = Enum.Font.Gotham
    TextLabel.Text = text
    TextLabel.TextColor3 = __PCLR(1, 1, 1)
    TextLabel.TextSize = 10
    TextLabel.TextWrapped = true
    TextLabel.ZIndex = 3

    local Aspect = Instance.new("UIAspectRatioConstraint", ImageButton)
    Aspect.AspectRatio = 1
    Aspect.AspectType = Enum.AspectType.ScaleWithParentSize

    local Stroke = Instance.new("UIGradient", ImageButton)
    Stroke.Name = "@Stroke"
    Stroke.Color = __NORMAL_COLOR

    activeStrokes[Stroke] = true
    buttonMaid:GiveTask(function()
        activeStrokes[Stroke] = nil
    end)

    local ripple = Instance.new("Frame")
    ripple.Name = "@ripple"
    ripple.BackgroundColor3 = __RGB(0, 155, 255)
    ripple.BackgroundTransparency = 0.5
    ripple.Size = __UD2(0, 0, 0, 0)
    ripple.AnchorPoint = __V2(0.5, 0.5)
    ripple.Visible = false
    ripple.ZIndex = 2
    ripple.Parent = ImageButton
    Instance.new("UICorner", ripple).CornerRadius = __UD(1, 0)

    local sound = Instance.new("Sound")
    sound.Name = "Sound"
    sound.SoundId = "rbxassetid://3868133279"
    sound.Volume = muteButtonSounds and 0 or 0.5
    sound.Parent = ImageButton

    Bind_MakeDraggable(ImageButton, buttonMaid, ripple, sound, clickFunc)

    BindableButtons.Buttons[id] = ImageButton
    BindableButtons.Maids[id] = buttonMaid
    BindableButtons.Count = BindableButtons.Count + 1
    return ImageButton
end

function BindableButtons.DeleteBButton(id)
    local maid = BindableButtons.Maids[id]
    if maid then
        if not maid._destroyed then
            maid:Destroy()
        end
        BindableButtons.Maids[id] = nil
        BindableButtons.Buttons[id] = nil
    end
end

local __DEFAULT_COLOR = __NORMAL_COLOR

local function SetBindableButtonActive(id, active)
    local btn = BindableButtons.Buttons[id]
    if not btn then return end
    local gradient = btn:FindFirstChild("@Stroke")
    if not gradient then return end
    if active then
        gradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, __PCLR(0.2, 1, 0.4)),
            ColorSequenceKeypoint.new(0.6, __PCLR(0.15, 0.85, 0.35)),
            ColorSequenceKeypoint.new(1, __PCLR(0.1, 0.6, 0.25))
        })
    else
        gradient.Color = __DEFAULT_COLOR
    end
end

local hiddenGui = Instance.new("ScreenGui")
hiddenGui.Name = "HiddenGui"
hiddenGui.ResetOnSpawn = false
hiddenGui.IgnoreGuiInset = true
hiddenGui.Parent = GetSafeGuiRoot()
RootMaid:GiveTask(hiddenGui)

local FB187 = shared.CreateTab("Fun Bomb", "/aux0on/fbicon/refs/heads/main/Untitled163_20260924094437")

local aboutSection = FB187:AddSection("About", "Info")
aboutSection:AddParagraph("Bomb Shi", "Made by @lzzzx & now fully open source <3")

aboutSection:AddToggle("Mute Button SFX", function(bool)
    muteButtonSounds = bool
    UpdateAllButtonSounds()
end)

aboutSection:AddToggle("Lock Bindable Buttons", function(bool)
    bombButtonsLocked = bool
end)

do
    local funBombSection = FB187:AddSection("Bomb Shi", "MM2/MMV")
    local selectedPlayers = {}
    local whitelist = {}
    local bombFlingButtonSize = 0.11
    local grabButtonSize = 0.11
    local flyButtonSize = 0.11
    local bfspButtonSize = 0.11

    local predictionStuds = 0
    local selectedBodyPart = "HumanoidRootPart"
    local bombFlingPowerMultiplier = 1
    local bombFlingDuration = 0.3
    local autoGrabBombEnabled = false
    local grabBindableEnabled = false
    local isGrabbedViaBindable = false
    local trollBombEnabled = false
    local flyOnBombEnabled = false
    local flyBindableEnabled = false
    local isFlyActiveViaBindable = false

    local bombFlingClickEnabled = false
    local bombFlingToolEnabled = false
    local bombFlingAuraEnabled = false
    local bombFlingAuraDist = 15
    local loopBombFlingDelay = 1

    local heldBomb = nil
    local isBombFlinging = false
    local lastMissingBombNotifyTick = 0
    local MISSING_BOMB_NOTIFY_COOLDOWN = 23

    local maids = {
        bombLoopPlr = nil, bombLoopAll = nil, bombFlingClick = nil,
        bombFlingTool = nil, bombFlingAura = nil, funLoop = nil,
        charConn = nil,
        autoSheriff = nil, autoMurderer = nil,
    }
    local buttonToggles = {Sheriff=false, Murderer=false, BFSP=false}

    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    local UserInputService = game:GetService("UserInputService")
    local RunService = game:GetService("RunService")
    local Workspace = game:GetService("Workspace")
    local Camera = Workspace.CurrentCamera

    local playerCache = {}
    local playerCacheDirty = true
    local function refreshPlayerCache()
        playerCache = Players:GetPlayers()
        playerCacheDirty = false
    end
    Players.PlayerAdded:Connect(function() playerCacheDirty = true end)
    Players.PlayerRemoving:Connect(function() playerCacheDirty = true end)
    local function getPlayers()
        if playerCacheDirty then refreshPlayerCache() end
        return playerCache
    end

    local roleCache = {data = nil, tick = 0}
    local function getRoleData()
        local now = tick()
        if roleCache.data and (now - roleCache.tick) < 2 then
            return roleCache.data
        end
        local success, roleData = pcall(function()
            local remote = ReplicatedStorage:FindFirstChild("GetPlayerData", true)
            if remote and remote:IsA("RemoteFunction") then return remote:InvokeServer() end
        end)
        if success and roleData then
            roleCache.data = roleData
            roleCache.tick = now
            return roleData
        end
        return nil
    end

    local toolCache = {}

    local function scanTools(player)
        local hasKnifeResult, hasGunResult = false, false
        local character = player.Character
        local backpack = player:FindFirstChild("Backpack")
        local function checkContainer(container)
            if not container then return end
            for _, tool in ipairs(container:GetChildren()) do
                if tool:IsA("Tool") then
                    local name = tool.Name:lower()
                    if name:find("knife") then hasKnifeResult = true end
                    if name:find("gun") then hasGunResult = true end
                end
            end
        end
        checkContainer(backpack)
        checkContainer(character)
        return hasKnifeResult, hasGunResult
    end

    local function getToolFlags(player)
        local now = tick()
        local cached = toolCache[player]
        if cached and (now - cached.tick) < 1 then
            return cached.hasKnife, cached.hasGun
        end
        local hasKnifeResult, hasGunResult = scanTools(player)
        toolCache[player] = {hasKnife = hasKnifeResult, hasGun = hasGunResult, tick = now}
        return hasKnifeResult, hasGunResult
    end

    Players.PlayerRemoving:Connect(function(p) toolCache[p] = nil end)

    local function isWhitelisted(player)
        return whitelist[player.UserId] == true
    end

    local function hasKnife(player)
        return (getToolFlags(player))
    end

    local function hasGun(player)
        local _, gun = getToolFlags(player)
        return gun
    end

    local function localHasGun()
        local character = LocalPlayer.Character
        if not character then return false end
        for _, tool in ipairs(LocalPlayer.Backpack:GetChildren()) do
            if tool.Name:lower():find("gun") then return true end
        end
        for _, tool in ipairs(character:GetChildren()) do
            if tool.Name:lower():find("gun") then return true end
        end
        return false
    end

    local function findMurderer()
        for _, player in ipairs(getPlayers()) do
            if player ~= LocalPlayer and not isWhitelisted(player) and hasKnife(player) then
                return player
            end
        end
        local roleData = getRoleData()
        if roleData then
            for playerName, data in pairs(roleData) do
                if data.Role == "Murderer" and not data.Killed and not data.Dead then
                    local p = Players:FindFirstChild(playerName)
                    if p and p ~= LocalPlayer and not isWhitelisted(p) then return p end
                end
            end
        end
        return nil
    end

    local function findSheriffWithFallback()
        for _, player in ipairs(getPlayers()) do
            if player ~= LocalPlayer and not isWhitelisted(player) and hasGun(player) then
                return player
            end
        end
        local roleData = getRoleData()
        if roleData then
            for playerName, data in pairs(roleData) do
                if data.Role == "Sheriff" and not data.Killed and not data.Dead then
                    local p = Players:FindFirstChild(playerName)
                    if p and p ~= LocalPlayer and not isWhitelisted(p) then return p end
                end
            end
        end
        return nil
    end

    local function isLocalPlayerRole(roleName)
        local roleData = getRoleData()
        if roleData then
            for playerName, data in pairs(roleData) do
                if playerName == LocalPlayer.Name and data.Role == roleName then return true end
            end
        end
        return false
    end

    local bombCache = {parts = {}, lastScan = 0}
    local BOMB_CACHE_TTL = 0.5

    local function refreshBombCache()
        local parts = {}
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") and not obj.Anchored then
                local name = obj.Name:lower()
                local parent = obj.Parent
                local parentName = parent and parent.Name:lower() or ""

                local isCharacterPart = false
                local checkModel = parent
                while checkModel and checkModel ~= Workspace do
                    if checkModel:FindFirstChildOfClass("Humanoid") or Players:GetPlayerFromCharacter(checkModel) then
                        isCharacterPart = true
                        break
                    end
                    checkModel = checkModel.Parent
                end

                if not isCharacterPart then
                    if name:find("fakebomb") or parentName:find("fakebomb") or name == "handle" then
                        parts[#parts + 1] = obj
                    end
                end
            end
        end
        bombCache.parts = parts
        bombCache.lastScan = tick()
    end

    local function findNearestBomb()
        local now = tick()
        if (now - bombCache.lastScan) > BOMB_CACHE_TTL then
            refreshBombCache()
        end

        local closestPart = nil
        local shortestDistance = math.huge
        local char = LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return nil end

        for _, obj in ipairs(bombCache.parts) do
            if obj and obj.Parent then
                local dist = (obj.Position - root.Position).Magnitude
                if dist < shortestDistance then
                    shortestDistance = dist
                    closestPart = obj
                end
            end
        end
        return closestPart
    end

    local lastBombSearchTick = 0
    local cachedNearestBomb = nil
    local function getCachedNearestBomb()
        local now = tick()
        if now - lastBombSearchTick < 0.3 and cachedNearestBomb and cachedNearestBomb.Parent then
            return cachedNearestBomb
        end
        lastBombSearchTick = now
        cachedNearestBomb = findNearestBomb()
        return cachedNearestBomb
    end

    local function findFakeBombTool()
        local backpack = LocalPlayer:FindFirstChild("Backpack")
        local char = LocalPlayer.Character
        local function search(container)
            if not container then return nil end
            for _, t in ipairs(container:GetChildren()) do
                if t:IsA("Tool") then
                    local n = t.Name:lower()
                    if n:find("fakebomb") or n:find("fake bomb") or n == "fakebomb" then
                        return t
                    end
                end
            end
            return nil
        end
        return search(backpack) or search(char)
    end

    local function ensureBombSpawned()
        local found = findNearestBomb()
        if found then
            heldBomb = found
            return true
        end

        local tool = findFakeBombTool()

        if not tool then
            pcall(function()
                if ReplicatedStorage.Remotes
                    and ReplicatedStorage.Remotes.Extras
                    and ReplicatedStorage.Remotes.Extras.ReplicateToy
                then
                    ReplicatedStorage.Remotes.Extras.ReplicateToy:InvokeServer("FakeBomb")
                end
            end)
            local deadline = tick() + 0.5
            while tick() < deadline do
                tool = findFakeBombTool()
                if tool then break end
                task.wait(0.01)
            end
        end

        if not tool then
            return false
        end

        local char = LocalPlayer.Character
        local backpack = LocalPlayer:FindFirstChild("Backpack")
        if not char or not backpack then return false end

        pcall(function()
            tool.Parent = char
        end)
        RunService.Heartbeat:Wait()

        pcall(function()
            tool:Activate()
        end)
        pcall(function()
            local throwRemote = tool:FindFirstChildWhichIsA("RemoteEvent")
                or tool:FindFirstChildWhichIsA("RemoteFunction")
            if throwRemote then
                throwRemote:FireServer()
            end
        end)
        RunService.Heartbeat:Wait()

        pcall(function()
            tool.Parent = backpack
        end)

        local deadline2 = tick() + 0.5
        while tick() < deadline2 do
            bombCache.lastScan = 0
            local b = findNearestBomb()
            if b then
                heldBomb = b
                return true
            end
            task.wait(0.01)
        end

        return false
    end

    local function isHeldBombValid()
        local ok, valid = pcall(function()
            return heldBomb and heldBomb.Parent and heldBomb.Position.Y > -100
        end)
        return ok and valid
    end

    local function executeBombFling(targetPlayer)
        if not targetPlayer or targetPlayer == LocalPlayer or isWhitelisted(targetPlayer) then return end
        local tChar = targetPlayer.Character
        if not tChar then return end

        local partToTarget = tChar:FindFirstChild("HumanoidRootPart")
            or tChar:FindFirstChild("Torso")
            or tChar:FindFirstChild("Head")
        if not partToTarget then return end

        if not isHeldBombValid() then
            ensureBombSpawned()
        end

        if not isHeldBombValid() then
            local currentTime = tick()
            if (currentTime - lastMissingBombNotifyTick) > MISSING_BOMB_NOTIFY_COOLDOWN then
                Notify("Error", "No FakeBomb found to fling!", 2)
                lastMissingBombNotifyTick = currentTime
            end
            return
        end

        if isBombFlinging then return end
        isBombFlinging = true

        pcall(function()
            heldBomb.Anchored = false
            if heldBomb:GetNetworkOwner() ~= LocalPlayer then
                heldBomb:SetNetworkOwner(LocalPlayer)
            end
        end)

        task.spawn(function()
            local startTime = tick()
            local duration = tonumber(bombFlingDuration) or 0.3
            local power = (tonumber(bombFlingPowerMultiplier) or 1) * 10000
            while tick() - startTime < duration and heldBomb and heldBomb.Parent and partToTarget.Parent do
                pcall(function()
                    local targetVel = partToTarget.AssemblyLinearVelocity or Vector3.zero
                    local horizVel = Vector3.new(targetVel.X, 0, targetVel.Z)
                    local predOffset = Vector3.zero
                    if horizVel.Magnitude > 0.2 then
                        predOffset = horizVel.Unit * (predictionStuds or 0)
                    end
                    local predictedPos = partToTarget.Position + predOffset

                    heldBomb.CFrame = CFrame.new(predictedPos)
                    heldBomb.AssemblyLinearVelocity = Vector3.new(0, power, 0)
                    heldBomb.AssemblyAngularVelocity = Vector3.new(power, power, power)
                end)
                RunService.Heartbeat:Wait()
            end
            isBombFlinging = false
        end)
    end

    maids.charConn = LocalPlayer.CharacterAdded:Connect(function()
        heldBomb = nil
        isBombFlinging = false
        isGrabbedViaBindable = false
        isFlyActiveViaBindable = false
        cachedNearestBomb = nil
        bombCache.lastScan = 0
        SetBindableButtonActive("grab_bomb_btn", false)
        SetBindableButtonActive("fly_bomb_btn", false)
    end)

    maids.funLoop = RunService.Heartbeat:Connect(function()
        if autoGrabBombEnabled and not heldBomb and not isGrabbedViaBindable then
            local b = getCachedNearestBomb()
            if b then
                pcall(function()
                    if b:GetNetworkOwner() ~= LocalPlayer then
                        b:SetNetworkOwner(LocalPlayer)
                    end
                    b.Anchored = false
                end)
                heldBomb = b
            end
        end

        local needsBomb = autoGrabBombEnabled or isGrabbedViaBindable or trollBombEnabled or flyOnBombEnabled or isFlyActiveViaBindable
        if needsBomb and not isBombFlinging then
            if not isHeldBombValid() then
                heldBomb = nil
                local b = getCachedNearestBomb()
                if not b then
                    ensureBombSpawned()
                    b = getCachedNearestBomb()
                end
                if b then
                    pcall(function()
                        if b:GetNetworkOwner() ~= LocalPlayer then
                            b:SetNetworkOwner(LocalPlayer)
                        end
                        b.Anchored = false
                    end)
                    heldBomb = b
                end
            end
        end

        if (autoGrabBombEnabled or isGrabbedViaBindable) and heldBomb and not isBombFlinging then
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if root then
                for _, player in ipairs(getPlayers()) do
                    if player ~= LocalPlayer and not isWhitelisted(player) then
                        local tChar = player.Character
                        local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
                        if tRoot then
                            local dist = (heldBomb.Position - tRoot.Position).Magnitude
                            if dist <= 6 then
                                executeBombFling(player)
                                break
                            end
                        end
                    end
                end
            end
        end

        if isHeldBombValid() then
            if not isBombFlinging then
                if flyOnBombEnabled or isFlyActiveViaBindable then
                    local char = LocalPlayer.Character
                    local root = char and char:FindFirstChild("HumanoidRootPart")
                    if root then
                        pcall(function()
                            heldBomb.AssemblyLinearVelocity = Vector3.zero
                            heldBomb.AssemblyAngularVelocity = Vector3.zero
                            heldBomb.CFrame = root.CFrame - Vector3.new(0, 3.5, 0)
                        end)
                    end
                elseif trollBombEnabled then
                    local targetCFrame = Camera.CFrame * CFrame.new(0, 0, -8)
                    pcall(function()
                        heldBomb.AssemblyLinearVelocity = Vector3.zero
                        heldBomb.AssemblyAngularVelocity = Vector3.zero
                        heldBomb.CFrame = targetCFrame
                    end)
                elseif isGrabbedViaBindable or autoGrabBombEnabled then
                    local targetCFrame = Camera.CFrame * CFrame.new(0, 0, -8)
                    pcall(function()
                        heldBomb.AssemblyLinearVelocity = Vector3.zero
                        heldBomb.AssemblyAngularVelocity = Vector3.zero
                        heldBomb.CFrame = targetCFrame
                    end)
                end
            end
        else
            if not isGrabbedViaBindable and not flyOnBombEnabled and not isFlyActiveViaBindable and not trollBombEnabled then
                heldBomb = nil
            end
        end
    end)

    RootMaid:GiveTask(function()
        for _, m in pairs(maids) do
            if m and not m._destroyed then m:Destroy() end
        end
    end)

    funBombSection:AddToggle("Troll Bomb (Camera Follow)", function(bool)
        trollBombEnabled = bool
        if bool and not heldBomb then
            heldBomb = findNearestBomb()
            if heldBomb then
                pcall(function()
                    if heldBomb:GetNetworkOwner() ~= LocalPlayer then
                        heldBomb:SetNetworkOwner(LocalPlayer)
                    end
                    heldBomb.Anchored = false
                end)
            end
        end
    end)

    funBombSection:AddToggle("Fly on Bomb", function(bool)
        flyOnBombEnabled = bool
        if bool and not heldBomb then
            heldBomb = findNearestBomb()
            if heldBomb then
                pcall(function()
                    if heldBomb:GetNetworkOwner() ~= LocalPlayer then
                        heldBomb:SetNetworkOwner(LocalPlayer)
                    end
                    heldBomb.Anchored = false
                end)
            end
        end
    end)

    funBombSection:AddToggle("Auto Grab Bomb", function(bool)
        autoGrabBombEnabled = bool
    end)

    funBombSection:AddButton("Fling Sheriff", function()
        local target = findSheriffWithFallback()
        if target then
            executeBombFling(target)
        else
            Notify("Error", "No Sheriff Detected", 3)
        end
    end)

    funBombSection:AddButton("Fling Murderer", function()
        local murderer = findMurderer()
        if murderer then
            executeBombFling(murderer)
        else
            Notify("Error", "No Murderer Detected", 3)
        end
    end)

    funBombSection:AddButton("Fling All", function()
        for _, p in ipairs(getPlayers()) do
            if p ~= LocalPlayer and not isWhitelisted(p) then
                executeBombFling(p)
                task.wait(0.2)
            end
        end
    end)

    funBombSection:AddToggle("Loop Bomb Fling All", function(s)
        if maids.bombLoopAll and not maids.bombLoopAll._destroyed then
            maids.bombLoopAll:Destroy()
        end
        maids.bombLoopAll = nil
        if s then
            maids.bombLoopAll = Maid.new()
            local thread = task.spawn(function()
                while true do
                    for _, p in ipairs(getPlayers()) do
                        if p ~= LocalPlayer and not isWhitelisted(p) then
                            executeBombFling(p)
                            task.wait(0.2)
                        end
                    end
                    task.wait(loopBombFlingDelay)
                end
            end)
            maids.bombLoopAll:GiveTask(function() safe_cancel(thread) end)
        end
    end)

    funBombSection:AddPlayerDropdown("Select Players", function(p)
        if p and p ~= LocalPlayer then
            table.insert(selectedPlayers, p)
        end
    end)

    funBombSection:AddButton("Clear Selected Players", function()
        selectedPlayers = {}
    end)

    funBombSection:AddToggle("Loop Bomb Fling Player(s)", function(s)
        if maids.bombLoopPlr and not maids.bombLoopPlr._destroyed then
            maids.bombLoopPlr:Destroy()
        end
        maids.bombLoopPlr = nil
        if s then
            maids.bombLoopPlr = Maid.new()
            local thread = task.spawn(function()
                while true do
                    for _, player in ipairs(selectedPlayers) do
                        if player and player.Parent and not isWhitelisted(player) then
                            executeBombFling(player)
                            task.wait(0.2)
                        end
                    end
                    task.wait(loopBombFlingDelay)
                end
            end)
            maids.bombLoopPlr:GiveTask(function() safe_cancel(thread) end)
        end
    end)

    funBombSection:AddSlider("Fling Power (1 = 10k)", 0.1, 5, 1, function(value)
        bombFlingPowerMultiplier = value
    end)

    funBombSection:AddSlider("Fling Duration", 0.1, 2, 0.3, function(value)
        bombFlingDuration = value
    end)

    funBombSection:AddSlider("Prediction Studs", 0, 20, 0, function(value)
        predictionStuds = value
    end)

    funBombSection:AddSlider("Loop Fling Delay", 0, 10, 1, function(value)
        loopBombFlingDelay = value
    end)

    local function createAutoFunFling(name, findFunc)
        funBombSection:AddToggle("Auto Fling "..name, function(enabled)
            local key = "auto"..name
            if maids[key] and not maids[key]._destroyed then
                maids[key]:Destroy()
            end
            maids[key] = nil
            if enabled then
                maids[key] = Maid.new()
                local flungTargets = {}
                local thread = task.spawn(function()
                    while true do
                        task.wait(1)
                        local target = findFunc()
                        if target and not flungTargets[target.UserId] then
                            executeBombFling(target)
                            flungTargets[target.UserId] = true
                            task.wait(3)
                            flungTargets[target.UserId] = nil
                        end
                    end
                end)
                maids[key]:GiveTask(function() safe_cancel(thread) end)
            end
        end)
    end

    createAutoFunFling("Sheriff", findSheriffWithFallback)
    createAutoFunFling("Murderer", findMurderer)

    funBombSection:AddToggle("Click Fling", function(enabled)
        bombFlingClickEnabled = enabled
        if maids.bombFlingClick and not maids.bombFlingClick._destroyed then
            maids.bombFlingClick:Destroy()
        end
        maids.bombFlingClick = nil
        if enabled then
            maids.bombFlingClick = Maid.new()
            local function onClick(input, processed)
                if processed then return end
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    local mouse = LocalPlayer:GetMouse()
                    local target = mouse.Target
                    if target then
                        local character = target:FindFirstAncestorWhichIsA("Model")
                        if character then
                            local player = Players:GetPlayerFromCharacter(character)
                            if player and player ~= LocalPlayer and not isWhitelisted(player) then
                                executeBombFling(player)
                            end
                        end
                    end
                end
            end
            if UserInputService.TouchEnabled then
                maids.bombFlingClick:GiveTask(UserInputService.TouchTap:Connect(onClick))
            end
            maids.bombFlingClick:GiveTask(UserInputService.InputBegan:Connect(onClick))
        end
    end)

    funBombSection:AddToggle("Tool Fling", function(enabled)
        bombFlingToolEnabled = enabled
        if maids.bombFlingTool and not maids.bombFlingTool._destroyed then
            maids.bombFlingTool:Destroy()
        end
        maids.bombFlingTool = nil
        if enabled then
            maids.bombFlingTool = Maid.new()
            local function giveTool()
                local char = LocalPlayer.Character
                if not char then return end
                local tool = Instance.new("Tool")
                tool.Name = "BombFlingTool"
                tool.RequiresHandle = false
                tool.Parent = LocalPlayer.Backpack
                maids.bombFlingTool:GiveTask(tool)
                maids.bombFlingTool:GiveTask(tool.Activated:Connect(function()
                    local mouse = LocalPlayer:GetMouse()
                    local target = mouse.Target
                    if target then
                        local character = target:FindFirstAncestorWhichIsA("Model")
                        if character then
                            local player = Players:GetPlayerFromCharacter(character)
                            if player and player ~= LocalPlayer and not isWhitelisted(player) then
                                executeBombFling(player)
                            end
                        end
                    end
                end))
            end
            giveTool()
            maids.bombFlingTool:GiveTask(LocalPlayer.CharacterAdded:Connect(function()
                task.wait(0.5)
                if bombFlingToolEnabled then giveTool() end
            end))
        end
    end)

    funBombSection:AddToggle("Fling Aura", function(enabled)
        bombFlingAuraEnabled = enabled
        if maids.bombFlingAura and not maids.bombFlingAura._destroyed then
            maids.bombFlingAura:Destroy()
        end
        maids.bombFlingAura = nil
        if enabled then
            maids.bombFlingAura = Maid.new()
            local thread = task.spawn(function()
                while bombFlingAuraEnabled do
                    task.wait(0.5)
                    local character = LocalPlayer.Character
                    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
                    if rootPart then
                        for _, player in ipairs(getPlayers()) do
                            if player ~= LocalPlayer and not isWhitelisted(player) then
                                local targetChar = player.Character
                                local targetRoot = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
                                if targetRoot and (rootPart.Position - targetRoot.Position).Magnitude <= bombFlingAuraDist then
                                    executeBombFling(player)
                                end
                            end
                        end
                    end
                end
            end)
            maids.bombFlingAura:GiveTask(function() safe_cancel(thread) end)
        end
    end)

    funBombSection:AddSlider("Fling Aura Studs", 5, 50, 15, function(value)
        bombFlingAuraDist = value
    end)

    funBombSection:AddPlayerDropdown("Add to Whitelist", function(p)
        if p and p ~= LocalPlayer then whitelist[p.UserId] = true end
    end)

    funBombSection:AddButton("Clear Whitelist", function()
        whitelist = {}
    end)

    funBombSection:AddToggle("Enable Grab Bomb Bindable Button", function(bool)
        grabBindableEnabled = bool
        if bool then
            BindableButtons.AddBButton("grab_bomb_btn", "GB", function()
                isGrabbedViaBindable = not isGrabbedViaBindable
                SetBindableButtonActive("grab_bomb_btn", isGrabbedViaBindable)
                if isGrabbedViaBindable then
                    heldBomb = findNearestBomb()
                    if heldBomb then
                        pcall(function()
                            if heldBomb:GetNetworkOwner() ~= LocalPlayer then
                                heldBomb:SetNetworkOwner(LocalPlayer)
                            end
                            heldBomb.Anchored = false
                        end)
                    else
                        isGrabbedViaBindable = false
                        SetBindableButtonActive("grab_bomb_btn", false)
                    end
                else
                    heldBomb = nil
                end
            end)
            local btn = BindableButtons.Buttons["grab_bomb_btn"]
            if btn then
                local screen = workspace.CurrentCamera.ViewportSize
                btn.Size = __UD2(grabButtonSize * (screen.Y / screen.X), 0, grabButtonSize, 0)
            end
        else
            BindableButtons.DeleteBButton("grab_bomb_btn")
            isGrabbedViaBindable = false
        end
    end)

    funBombSection:AddSlider("Grab Bomb Button Size", 5, 25, 11, function(value)
        grabButtonSize = value / 100
        local btn = BindableButtons.Buttons["grab_bomb_btn"]
        if btn then
            local screen = workspace.CurrentCamera.ViewportSize
            btn.Size = __UD2(grabButtonSize * (screen.Y / screen.X), 0, grabButtonSize, 0)
        end
    end)

    funBombSection:AddButton("Reset Grab Bomb Button Position", function()
        savedPositions["grab_bomb_btn"] = nil
        savePositions(savedPositions)
        local btn = BindableButtons.Buttons["grab_bomb_btn"]
        if btn then
            btn.Position = __UD2(0.1, 0, 0.9, 0)
        end
        Notify("Info", "Grab Bomb button position reset", 2)
    end)

    funBombSection:AddToggle("Enable Fly Bindable Button", function(bool)
        flyBindableEnabled = bool
        if bool then
            BindableButtons.AddBButton("fly_bomb_btn", "FB", function()
                isFlyActiveViaBindable = not isFlyActiveViaBindable
                SetBindableButtonActive("fly_bomb_btn", isFlyActiveViaBindable)
                if isFlyActiveViaBindable and not heldBomb then
                    heldBomb = findNearestBomb()
                    if heldBomb then
                        pcall(function()
                            if heldBomb:GetNetworkOwner() ~= LocalPlayer then
                                heldBomb:SetNetworkOwner(LocalPlayer)
                            end
                            heldBomb.Anchored = false
                        end)
                    end
                end
            end)
            local btn = BindableButtons.Buttons["fly_bomb_btn"]
            if btn then
                local screen = workspace.CurrentCamera.ViewportSize
                btn.Size = __UD2(flyButtonSize * (screen.Y / screen.X), 0, flyButtonSize, 0)
            end
        else
            BindableButtons.DeleteBButton("fly_bomb_btn")
            isFlyActiveViaBindable = false
        end
    end)

    funBombSection:AddSlider("Fly on Bomb Button Size", 5, 25, 11, function(value)
        flyButtonSize = value / 100
        local btn = BindableButtons.Buttons["fly_bomb_btn"]
        if btn then
            local screen = workspace.CurrentCamera.ViewportSize
            btn.Size = __UD2(flyButtonSize * (screen.Y / screen.X), 0, flyButtonSize, 0)
        end
    end)

    funBombSection:AddButton("Reset Fly on Bomb Button Position", function()
        savedPositions["fly_bomb_btn"] = nil
        savePositions(savedPositions)
        local btn = BindableButtons.Buttons["fly_bomb_btn"]
        if btn then
            btn.Position = __UD2(0.2, 0, 0.9, 0)
        end
        Notify("Info", "Fly on Bomb button position reset", 2)
    end)

    funBombSection:AddToggle("Enable BFS Button", function(enabled)
        buttonToggles["Sheriff"] = enabled
        if enabled then
            BindableButtons.AddBButton("bomb_fling_sheriff", "BFS", function()
                bfsToggleActive = not bfsToggleActive
                SetBindableButtonActive("bomb_fling_sheriff", bfsToggleActive)

                if bfsToggleActive then
                    if bfsLoopMaid and not bfsLoopMaid._destroyed then
                        bfsLoopMaid:Destroy()
                    end
                    bfsLoopMaid = Maid.new()
                    local thread = task.spawn(function()
                        while bfsToggleActive do
                            local target = findSheriffWithFallback()
                            if target then
                                executeBombFling(target)
                            end
                            task.wait(loopBombFlingDelay)
                        end
                    end)
                    bfsLoopMaid:GiveTask(function() safe_cancel(thread) end)
                else
                    if bfsLoopMaid and not bfsLoopMaid._destroyed then
                        bfsLoopMaid:Destroy()
                    end
                    bfsLoopMaid = nil
                end
            end)
            local btn = BindableButtons.Buttons["bomb_fling_sheriff"]
            if btn then
                local screen = workspace.CurrentCamera.ViewportSize
                btn.Size = __UD2(bombFlingButtonSize * (screen.Y / screen.X), 0, bombFlingButtonSize, 0)
            end
        else
            bfsToggleActive = false
            if bfsLoopMaid and not bfsLoopMaid._destroyed then
                bfsLoopMaid:Destroy()
            end
            bfsLoopMaid = nil
            BindableButtons.DeleteBButton("bomb_fling_sheriff")
        end
    end)

    funBombSection:AddSlider("BFS Button Size", 5, 25, 11, function(value)
        bombFlingButtonSize = value / 100
        local btn = BindableButtons.Buttons["bomb_fling_sheriff"]
        if btn then
            local screen = workspace.CurrentCamera.ViewportSize
            btn.Size = __UD2(bombFlingButtonSize * (screen.Y / screen.X), 0, bombFlingButtonSize, 0)
        end
    end)

    funBombSection:AddButton("Reset BFS Button Position", function()
        savedPositions["bomb_fling_sheriff"] = nil
        savePositions(savedPositions)
        local btn = BindableButtons.Buttons["bomb_fling_sheriff"]
        if btn then
            btn.Position = __UD2(0.1, 0, 0.9, 0)
        end
        Notify("Info", "BFS button position reset", 2)
    end)

    funBombSection:AddToggle("Enable BFM Button", function(enabled)
        buttonToggles["Murderer"] = enabled
        if enabled then
            BindableButtons.AddBButton("bomb_fling_murderer", "BFM", function()
                bfmToggleActive = not bfmToggleActive
                SetBindableButtonActive("bomb_fling_murderer", bfmToggleActive)

                if bfmToggleActive then
                    if bfmLoopMaid and not bfmLoopMaid._destroyed then
                        bfmLoopMaid:Destroy()
                    end
                    bfmLoopMaid = Maid.new()
                    local thread = task.spawn(function()
                        while bfmToggleActive do
                            local target = findMurderer()
                            if target then
                                executeBombFling(target)
                            end
                            task.wait(loopBombFlingDelay)
                        end
                    end)
                    bfmLoopMaid:GiveTask(function() safe_cancel(thread) end)
                else
                    if bfmLoopMaid and not bfmLoopMaid._destroyed then
                        bfmLoopMaid:Destroy()
                    end
                    bfmLoopMaid = nil
                end
            end)
            local btn = BindableButtons.Buttons["bomb_fling_murderer"]
            if btn then
                local screen = workspace.CurrentCamera.ViewportSize
                btn.Size = __UD2(bombFlingButtonSize * (screen.Y / screen.X), 0, bombFlingButtonSize, 0)
            end
        else
            bfmToggleActive = false
            if bfmLoopMaid and not bfmLoopMaid._destroyed then
                bfmLoopMaid:Destroy()
            end
            bfmLoopMaid = nil
            BindableButtons.DeleteBButton("bomb_fling_murderer")
        end
    end)

    funBombSection:AddSlider("BFM Button Size", 5, 25, 11, function(value)
        bombFlingButtonSize = value / 100
        local btn = BindableButtons.Buttons["bomb_fling_murderer"]
        if btn then
            local screen = workspace.CurrentCamera.ViewportSize
            btn.Size = __UD2(bombFlingButtonSize * (screen.Y / screen.X), 0, bombFlingButtonSize, 0)
        end
    end)

    funBombSection:AddButton("Reset BFM Button Position", function()
        savedPositions["bomb_fling_murderer"] = nil
        savePositions(savedPositions)
        local btn = BindableButtons.Buttons["bomb_fling_murderer"]
        if btn then
            local camera = workspace.CurrentCamera
            local screen = camera.ViewportSize
            local buttonSizeY = 0.11
            local widthScale = buttonSizeY * (screen.Y / screen.X)
            btn.Position = __UD2(0.1 + (1 * (widthScale + 0.005)), 0, 0.9, 0)
        end
        Notify("Info", "BFM button position reset", 2)
    end)

    funBombSection:AddToggle("Enable BFSP Button", function(enabled)
        buttonToggles["BFSP"] = enabled
        if enabled then
            BindableButtons.AddBButton("bomb_fling_selected_players", "BFSP", function()
                bfspToggleActive = not bfspToggleActive
                SetBindableButtonActive("bomb_fling_selected_players", bfspToggleActive)

                if bfspToggleActive then
                    if #selectedPlayers == 0 then
                        Notify("Error", "No players selected for BFSP", 2)
                        bfspToggleActive = false
                        SetBindableButtonActive("bomb_fling_selected_players", false)
                        return
                    end
                    if bfspLoopMaid and not bfspLoopMaid._destroyed then
                        bfspLoopMaid:Destroy()
                    end
                    bfspLoopMaid = Maid.new()
                    local thread = task.spawn(function()
                        while bfspToggleActive do
                            for _, player in ipairs(selectedPlayers) do
                                if player and player.Parent and not isWhitelisted(player) then
                                    executeBombFling(player)
                                    task.wait(0.2)
                                end
                            end
                            task.wait(loopBombFlingDelay)
                        end
                    end)
                    bfspLoopMaid:GiveTask(function() safe_cancel(thread) end)
                else
                    if bfspLoopMaid and not bfspLoopMaid._destroyed then
                        bfspLoopMaid:Destroy()
                    end
                    bfspLoopMaid = nil
                end
            end)
            local btn = BindableButtons.Buttons["bomb_fling_selected_players"]
            if btn then
                local screen = workspace.CurrentCamera.ViewportSize
                btn.Size = __UD2(bfspButtonSize * (screen.Y / screen.X), 0, bfspButtonSize, 0)
            end
        else
            bfspToggleActive = false
            if bfspLoopMaid and not bfspLoopMaid._destroyed then
                bfspLoopMaid:Destroy()
            end
            bfspLoopMaid = nil
            BindableButtons.DeleteBButton("bomb_fling_selected_players")
        end
    end)

    funBombSection:AddSlider("BFSP Button Size", 5, 25, 11, function(value)
        bfspButtonSize = value / 100
        local btn = BindableButtons.Buttons["bomb_fling_selected_players"]
        if btn then
            local screen = workspace.CurrentCamera.ViewportSize
            btn.Size = __UD2(bfspButtonSize * (screen.Y / screen.X), 0, bfspButtonSize, 0)
        end
    end)

    funBombSection:AddButton("Reset BFSP Button Position", function()
        savedPositions["bomb_fling_selected_players"] = nil
        savePositions(savedPositions)
        local btn = BindableButtons.Buttons["bomb_fling_selected_players"]
        if btn then
            local camera = workspace.CurrentCamera
            local screen = camera.ViewportSize
            local buttonSizeY = 0.11
            local widthScale = buttonSizeY * (screen.Y / screen.X)
            btn.Position = __UD2(0.1 + (2 * (widthScale + 0.005)), 0, 0.9, 0)
        end
        Notify("Info", "BFSP button position reset", 2)
    end)
end

shared.Notify("Bomb Shi Plugin Successfully Loaded!", 1)

RootMaid:GiveTasks(
    function()
        for id, _ in pairs(BindableButtons.Buttons) do
            BindableButtons.DeleteBButton(id)
        end
    end,
    function()
        bfsToggleActive, bfmToggleActive, bfspToggleActive = false, false, false
        for _, m in ipairs({bfsLoopMaid, bfmLoopMaid, bfspLoopMaid, trollPlayerLoopMaid}) do
            if m and not m._destroyed then m:Destroy() end
        end
    end
)
