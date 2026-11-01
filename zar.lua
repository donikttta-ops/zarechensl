-- language: Lua, target: Roblox (Зареченск РП), executor any
-- apathy | Force Seat + Car Flight (sin VirtualInput / sin fire* → menos chance de 267)

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ===== Force Seat =====
local autoSitRange = 12

local function getCharacter()
    return LocalPlayer.Character
end

local function getHumanoid()
    local char = getCharacter()
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function getRoot()
    local char = getCharacter()
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function forceSit(seat)
    local humanoid = getHumanoid()
    local root = getRoot()
    if not humanoid or not root or not seat then return false end
    if not (seat:IsA("Seat") or seat:IsA("VehicleSeat")) then return false end
    if seat.Occupant then return false end

    local targetCF = seat.CFrame * CFrame.new(0, 1.5, 0)
    root.CFrame = targetCF
    task.wait(0.05)

    pcall(function()
        seat:Sit(humanoid)
    end)

    task.wait(0.08)
    if not humanoid.Sit then
        pcall(function()
            humanoid.Sit = true
            local weld = Instance.new("Weld")
            weld.Name = "SeatWeld"
            weld.Part0 = seat
            weld.Part1 = root
            weld.C0 = CFrame.new(0, 1.5, 0)
            weld.Parent = seat
        end)
    end

    return humanoid.Sit
end

local function findNearestSeat(range)
    local root = getRoot()
    if not root then return nil end

    local nearest, nearestDist = nil, range

    for _, obj in ipairs(Workspace:GetDescendants()) do
        if (obj:IsA("Seat") or obj:IsA("VehicleSeat")) and not obj.Occupant then
            local dist = (obj.Position - root.Position).Magnitude
            if dist < nearestDist then
                nearestDist = dist
                nearest = obj
            end
        end
    end

    return nearest
end

local function tryForceSeat()
    local seat = findNearestSeat(autoSitRange)
    if seat then
        local ok = forceSit(seat)
        if ok then
            Rayfield:Notify({
                Title = "apathy",
                Content = "Сел в: " .. (seat.Name or "Сиденье"),
                Duration = 2
            })
        else
            Rayfield:Notify({
                Title = "apathy",
                Content = "Не удалось сесть",
                Duration = 2
            })
        end
    else
        Rayfield:Notify({
            Title = "apathy",
            Content = "Рядом нет свободного сиденья",
            Duration = 2
        })
    end
end

-- ===== Car Flight (no BodyGyro → no spin) =====
local vehicleFlyEnabled = false
local vehicleFlyActive = false
local vehicleSpeed = 120
local vehicleRoot = nil
local vehicleBV = nil
local vehicleConn = nil
local vehicleMonitor = nil

local function getVehicleRoot()
    local char = LocalPlayer.Character
    if not char then return nil end
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid or not humanoid.Sit then return nil end
    local seat = humanoid.SeatPart
    if not seat then return nil end
    local model = seat:FindFirstAncestorOfClass("Model")
    if model and model.PrimaryPart then
        return model.PrimaryPart
    end
    return seat
end

local function stopVehicleFly()
    vehicleFlyActive = false
    if vehicleConn then
        vehicleConn:Disconnect()
        vehicleConn = nil
    end
    if vehicleBV then
        vehicleBV:Destroy()
        vehicleBV = nil
    end
    if vehicleRoot and vehicleRoot.Parent then
        vehicleRoot.AssemblyAngularVelocity = Vector3.zero
    end
    vehicleRoot = nil
end

local function startVehicleFly()
    if vehicleFlyActive then return end
    local root = getVehicleRoot()
    if not root then return end

    vehicleRoot = root
    vehicleFlyActive = true

    vehicleBV = Instance.new("BodyVelocity")
    vehicleBV.Name = "ApathyFly"
    vehicleBV.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    vehicleBV.P = 10000
    vehicleBV.Velocity = Vector3.zero
    vehicleBV.Parent = vehicleRoot

    vehicleConn = RunService.Heartbeat:Connect(function()
        if not vehicleFlyEnabled or not vehicleRoot or not vehicleRoot.Parent then
            stopVehicleFly()
            return
        end

        vehicleRoot.AssemblyAngularVelocity = Vector3.zero

        local camCF = Camera.CFrame
        local move = Vector3.zero

        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
            move = move + camCF.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then
            move = move - camCF.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then
            move = move - camCF.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then
            move = move + camCF.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.E) or UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            move = move + Vector3.new(0, 1, 0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Q) or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            move = move - Vector3.new(0, 1, 0)
        end

        if move.Magnitude > 0 then
            move = move.Unit * vehicleSpeed
        end

        vehicleBV.Velocity = move
    end)
end

local function setVehicleFly(state)
    vehicleFlyEnabled = state
    if state then
        if not vehicleMonitor then
            vehicleMonitor = RunService.Heartbeat:Connect(function()
                if not vehicleFlyEnabled then return end
                local root = getVehicleRoot()
                if root then
                    if not vehicleFlyActive then
                        startVehicleFly()
                    end
                else
                    if vehicleFlyActive then
                        stopVehicleFly()
                    end
                end
            end)
        end
        startVehicleFly()
    else
        stopVehicleFly()
        if vehicleMonitor then
            vehicleMonitor:Disconnect()
            vehicleMonitor = nil
        end
    end
end

LocalPlayer.CharacterRemoving:Connect(function()
    stopVehicleFly()
end)

-- ===== UI =====
local Window = Rayfield:CreateWindow({
    Name = "apathy — Зареченск",
    LoadingTitle = "apathy",
    LoadingSubtitle = "Force Seat + Flight",
    Theme = "Amethyst",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "apathy",
        FileName = "zarechensk_v2"
    },
    KeySystem = false
})

local Tab = Window:CreateTab("Транспорт", 4483362458)

Tab:CreateSection("Сиденье")

Tab:CreateSlider({
    Name = "Дальность поиска",
    Range = {4, 30},
    Increment = 1,
    Suffix = " ст.",
    CurrentValue = 12,
    Flag = "SeatRange",
    Callback = function(Value)
        autoSitRange = Value
    end
})

Tab:CreateButton({
    Name = "Сесть в ближайшее сиденье",
    Callback = function()
        tryForceSeat()
    end
})

Tab:CreateSection("Полёт")

Tab:CreateToggle({
    Name = "Полёт на машине",
    CurrentValue = false,
    Flag = "CarFlight",
    Callback = function(Value)
        setVehicleFly(Value)
        Rayfield:Notify({
            Title = "apathy",
            Content = Value and "Полёт ВКЛ — WASD + E/Q" or "Полёт ВЫКЛ",
            Duration = 3
        })
    end
})

Tab:CreateSlider({
    Name = "Скорость полёта",
    Range = {20, 400},
    Increment = 10,
    Suffix = " ст.",
    CurrentValue = 120,
    Flag = "FlySpeed",
    Callback = function(Value)
        vehicleSpeed = Value
    end
})

Tab:CreateSection("Инфо")
Tab:CreateParagraph({
    Title = "Как пользоваться",
    Content = "1. Подойди к сиденью → «Сесть в ближайшее сиденье»\n2. Включи «Полёт на машине» → WASD движение, E/Space вверх, Q/Ctrl вниз\nБез BodyGyro = без вращения камеры."
})

Rayfield:Notify({
    Title = "apathy",
    Content = "Force Seat + Car Flight готов",
    Duration = 4
})

Rayfield:LoadConfiguration()
