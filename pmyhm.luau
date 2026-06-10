-- Deobfuscated with https://github.com/tupsutumppu/MoonsecDeobfuscator 
-- Vibecoded the rest LOL
-- Made by antichrist

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

-- Cleanup previous UI

local ExistingUI = CoreGui:FindFirstChild("ToraScript")
if ExistingUI then
    ExistingUI:Destroy()
end

-- Globals

Distance = 5
_G.Bring = false
getgenv().HeadSizeValue = 2

-- Load UI library

local Library = loadstring(
    game:HttpGet(
        "https://raw.githubusercontent.com/liebertsx/Tora-Library/main/src/librarynew",
        true
    )
)()

local Window = Library:CreateWindow("Protect The House")

---------------------------------------------------------------------
-- Hidden Weapon Boxes
---------------------------------------------------------------------

local function FindHiddenBoxes()
    local Character = LocalPlayer.Character
    if not Character then
        return
    end

    local HRP = Character:FindFirstChild("HumanoidRootPart")
    if not HRP then
        return
    end

    for _, Object in ipairs(workspace.HiddenWeaponBoxes:GetDescendants()) do
        if Object:IsA("TouchTransmitter") then
            firetouchinterest(HRP, Object.Parent, 0)
            task.wait()
            firetouchinterest(HRP, Object.Parent, 1)
        end
    end
end

---------------------------------------------------------------------
-- Distance Slider
---------------------------------------------------------------------

local function SetDistance(Value)
    Distance = Value
end

---------------------------------------------------------------------
-- Head Size Slider
---------------------------------------------------------------------

local function SetHeadSize(Value)
    getgenv().HeadSizeValue = Value
end

---------------------------------------------------------------------
-- Hitbox Expander Loop
---------------------------------------------------------------------

task.spawn(function()
    while task.wait(1) do
        local SizeValue = getgenv().HeadSizeValue

        if SizeValue then
            for _, Part in ipairs(workspace.Monsters:GetDescendants()) do
                if Part:IsA("BasePart") and Part.Name == "Head" then
                    Part.CanCollide = false
                    Part.Size = Vector3.new(
                        SizeValue,
                        SizeValue,
                        SizeValue
                    )
                end
            end
        end
    end
end)

---------------------------------------------------------------------
-- Bring Mobs
---------------------------------------------------------------------

local Bringing = false

local function BringLoop()
    if Bringing then
        return
    end

    Bringing = true

    task.spawn(function()
        while _G.Bring do
            task.wait()

            pcall(function()
                local Character = LocalPlayer.Character
                if not Character then
                    return
                end

                local HRP = Character:FindFirstChild("HumanoidRootPart")
                if not HRP then
                    return
                end

                for _, Object in ipairs(workspace.Monsters:GetDescendants()) do
                    if Object.Name == "HumanoidRootPart" then
                        Object.CFrame =
                            HRP.CFrame *
                            CFrame.new(0, 0, -Distance)
                    end
                end
            end)
        end

        Bringing = false
    end)
end

local function ToggleBring(State)
    _G.Bring = State

    print("Bring:", State)

    if State then
        BringLoop()
    end
end

---------------------------------------------------------------------
-- Infinite Ammo
---------------------------------------------------------------------

local function InfiniteAmmo()
    local OldIndex

    OldIndex = hookmetamethod(game, "__index", function(Self, Key)
        if not checkcaller() then
            if tostring(Self) == "Mag" and Key == "Value" then
                return math.huge
            end
        end

        return OldIndex(Self, Key)
    end)

    -- Present in original script
    local Character = LocalPlayer.Character
    if Character then
        local Humanoid = Character:FindFirstChild("Humanoid")
        if Humanoid then
            Humanoid.Health = 0
        end
    end
end

---------------------------------------------------------------------
-- Auto Lock Mobs (FOV + Line of Sight + Hold Q)
---------------------------------------------------------------------

local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local RunService = game:GetService("RunService")

local AutoLock = false
local CurrentTarget = nil
local FOV_Radius = 150
local AimKey = Enum.KeyCode.Q

-- Create FOV Circle GUI (Thin + Hollow)
local FOVCircle = Instance.new("ScreenGui")
FOVCircle.Name = "FOVCircle"
FOVCircle.Parent = CoreGui

local CircleFrame = Instance.new("Frame")
CircleFrame.Name = "Circle"
CircleFrame.Size = UDim2.new(0, FOV_Radius * 2, 0, FOV_Radius * 2)
CircleFrame.Position = UDim2.new(0.5, -FOV_Radius, 0.5, -FOV_Radius)
CircleFrame.BackgroundTransparency = 1  -- Fully transparent (hollow inside)
CircleFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
CircleFrame.BorderSizePixel = 0
CircleFrame.Parent = FOVCircle

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(1, 0)
UICorner.Parent = CircleFrame

local UIStroke = Instance.new("UIStroke")
UIStroke.Color = Color3.fromRGB(255, 255, 255)
UIStroke.Thickness = 1  -- Very thin outline
UIStroke.Parent = CircleFrame

-- Function to update FOV size
local function SetFOVSize(Radius)
    FOV_Radius = Radius
    CircleFrame.Size = UDim2.new(0, Radius * 2, 0, Radius * 2)
    CircleFrame.Position = UDim2.new(0.5, -Radius, 0.5, -Radius)
end

local function IsMobVisible(Mob)
    local Character = LocalPlayer.Character
    if not Character then return false end
    
    local Head = Mob:FindFirstChild("Head")
    if not Head then return false end
    
    local Origin = Camera.CFrame.Position
    local Direction = Head.Position - Origin
    
    local RaycastParams = RaycastParams.new()
    RaycastParams.FilterDescendantsInstances = {Character, Mob}
    RaycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    
    local Result = workspace:Raycast(Origin, Direction, RaycastParams)
    
    if not Result then
        return true
    end
    
    if Result.Instance:IsDescendantOf(Mob) then
        return true
    end
    
    return false
end

local function IsInFOV(Mob)
    local Head = Mob:FindFirstChild("Head")
    if not Head then return false end
    
    local ScreenPos, OnScreen = Camera:WorldToViewportPoint(Head.Position)
    if not OnScreen then return false end
    
    local CenterX = Camera.ViewportSize.X / 2
    local CenterY = Camera.ViewportSize.Y / 2
    
    local DistanceFromCenter = math.sqrt(
        (ScreenPos.X - CenterX)^2 + (ScreenPos.Y - CenterY)^2
    )
    
    return DistanceFromCenter <= FOV_Radius
end

local function GetNearestMobInFOV()
    local Character = LocalPlayer.Character
    if not Character then return nil end

    local HRP = Character:FindFirstChild("HumanoidRootPart")
    if not HRP then return nil end

    local Closest = nil
    local ClosestDistance = math.huge

    for _, Mob in ipairs(workspace.Monsters:GetChildren()) do
        local MobHRP = Mob:FindFirstChild("HumanoidRootPart")
        local Humanoid = Mob:FindFirstChildOfClass("Humanoid")

        if MobHRP and Humanoid and Humanoid.Health > 0 then
            if IsMobVisible(Mob) and IsInFOV(Mob) then
                local Dist = (MobHRP.Position - HRP.Position).Magnitude

                if Dist < ClosestDistance then
                    ClosestDistance = Dist
                    Closest = Mob
                end
            end
        end
    end

    return Closest
end

local function UpdateTarget()
    CurrentTarget = GetNearestMobInFOV()
end

-- Hold Q to lock
UserInputService.InputBegan:Connect(function(Input, GP)
    if GP then return end
    
    if Input.KeyCode == AimKey then
        AutoLock = true
        UpdateTarget()
    end
end)

UserInputService.InputEnded:Connect(function(Input, GP)
    if Input.KeyCode == AimKey then
        AutoLock = false
        CurrentTarget = nil
    end
end)

-- Main loop
task.spawn(function()
    while task.wait() do
        if AutoLock then
            if CurrentTarget then
                local Humanoid = CurrentTarget:FindFirstChildOfClass("Humanoid")
                local Head = CurrentTarget:FindFirstChild("Head")
                
                if not Humanoid or Humanoid.Health <= 0 or not IsMobVisible(CurrentTarget) or not IsInFOV(CurrentTarget) then
                    UpdateTarget()
                elseif Head then
                    Camera.CFrame = CFrame.lookAt(
                        Camera.CFrame.Position,
                        Head.Position
                    )
                end
            else
                UpdateTarget()
            end
        end
    end
end)

---------------------------------------------------------------------
-- ESP Highlights
---------------------------------------------------------------------

local ESP_Enabled = false
local ESP_Highlights = {}

local function CreateESP(Mob)
    if not Mob then return end
    
    local Head = Mob:FindFirstChild("Head")
    if not Head then return end
    
    if ESP_Highlights[Mob] then
        ESP_Highlights[Mob]:Destroy()
        ESP_Highlights[Mob] = nil
    end
    
    local Highlight = Instance.new("Highlight")
    Highlight.Name = "MobESP"
    Highlight.Adornee = Mob
    Highlight.FillColor = Color3.fromRGB(255, 0, 0)
    Highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    Highlight.FillTransparency = 0.5
    Highlight.OutlineTransparency = 0
    Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    Highlight.Parent = CoreGui
    
    ESP_Highlights[Mob] = Highlight
end

local function RemoveESP(Mob)
    if ESP_Highlights[Mob] then
        ESP_Highlights[Mob]:Destroy()
        ESP_Highlights[Mob] = nil
    end
end

local function ClearAllESP()
    for Mob, Highlight in pairs(ESP_Highlights) do
        if Highlight then
            Highlight:Destroy()
        end
    end
    ESP_Highlights = {}
end

local function UpdateESP()
    if not ESP_Enabled then
        ClearAllESP()
        return
    end
    
    for _, Mob in ipairs(workspace.Monsters:GetChildren()) do
        local Humanoid = Mob:FindFirstChildOfClass("Humanoid")
        
        if Humanoid and Humanoid.Health > 0 then
            if not ESP_Highlights[Mob] then
                CreateESP(Mob)
            end
        else
            RemoveESP(Mob)
        end
    end
    
    for Mob, _ in pairs(ESP_Highlights) do
        if not Mob or not Mob.Parent then
            RemoveESP(Mob)
        end
    end
end

task.spawn(function()
    while task.wait(0.1) do
        if ESP_Enabled then
            UpdateESP()
        end
    end
end)

workspace.Monsters.ChildAdded:Connect(function(Mob)
    if ESP_Enabled then
        task.wait(0.1)
        CreateESP(Mob)
    end
end)

workspace.Monsters.ChildRemoved:Connect(function(Mob)
    RemoveESP(Mob)
end)

local function ToggleESP(State)
    ESP_Enabled = State
    print("ESP:", State)
    
    if not State then
        ClearAllESP()
    else
        UpdateESP()
    end
end

---------------------------------------------------------------------
-- UI
---------------------------------------------------------------------

Window:AddButton({
    text = "Inf Ammo",
    flag = "button",
    callback = InfiniteAmmo
})

Window:AddSlider({
    text = "Set Distance",
    flag = "slider1",
    value = 5,
    min = 5,
    max = 100,
    callback = SetDistance
})

Window:AddToggle({
    text = "Bring Mobs",
    flag = "toggle",
    state = false,
    callback = ToggleBring
})

Window:AddSlider({
    text = "Head Size",
    flag = "slider2",
    value = 2,
    min = 2,
    max = 6,
    callback = SetHeadSize
})

Window:AddButton({
    text = "Find HiddenBoxes",
    flag = "button",
    callback = FindHiddenBoxes
})

Window:AddToggle({
    text = "ESP Highlights",
    flag = "esp",
    state = false,
    callback = ToggleESP
})

Window:AddSlider({
    text = "FOV Size",
    flag = "fov",
    value = 150,
    min = 50,
    max = 400,
    callback = SetFOVSize
})

Window:AddLabel({
    text = "Hold Q to Auto Lock"
})

Window:AddLabel({
    text = "yen loves u"
})

Library:Init()
