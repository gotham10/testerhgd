local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local petData = ReplicatedStorage:FindFirstChild("PetData")
local connections = {}
local function clearConnections()
    for _, conn in ipairs(connections) do
        conn:Disconnect()
    end
    connections = {}
end
local function findAndMarkBestPet()
    clearConnections()
    if not petData then
        return
    end
    local bestPetFolder = petData:FindFirstChild("BestPet")
    if not bestPetFolder or #bestPetFolder:GetChildren() == 0 then
        for _, plot in ipairs(Workspace:FindFirstChild("Plots"):GetChildren()) do
            local animalPodiums = plot:FindFirstChild("AnimalPodiums")
            if animalPodiums then
                for _, podium in ipairs(animalPodiums:GetChildren()) do
                    local existingMarker = podium:FindFirstChild("BestPetMarker")
                    if existingMarker then
                        existingMarker:Destroy()
                    end
                end
            end
        end
        return
    end
    local podiumIdValue = bestPetFolder:FindFirstChild("podium_id")
    local plotGuidValue = bestPetFolder:FindFirstChild("plotguid")
    if not podiumIdValue or not plotGuidValue then
        return
    end
    local podiumId = podiumIdValue.Value
    local plotGuid = plotGuidValue.Value
    local targetPlot = Workspace:FindFirstChild("Plots"):FindFirstChild(plotGuid)
    if not targetPlot then
        return
    end
    local animalPodiums = targetPlot:FindFirstChild("AnimalPodiums")
    if not animalPodiums then
        return
    end
    local targetPodium = animalPodiums:FindFirstChild(tostring(podiumId))
    if not targetPodium then
        return
    end
    local baseModel = targetPodium:FindFirstChild("Base")
    if not baseModel or not baseModel:IsA("Model") then
        return
    end
    local spawnPart = baseModel:FindFirstChild("Spawn")
    if not spawnPart or not spawnPart:IsA("Part") then
        return
    end
    local markerPart = Instance.new("Part")
    markerPart.Size = Vector3.new(2, 2, 2)
    markerPart.CFrame = spawnPart.CFrame * CFrame.new(0, 0, -2.5)
    markerPart.Anchored = true
    markerPart.CanCollide = false
    markerPart.Material = Enum.Material.Neon
    markerPart.BrickColor = BrickColor.new("Bright red")
    markerPart.Name = "BestPetMarker"
    local existingMarker = targetPodium:FindFirstChild("BestPetMarker")
    if existingMarker then
        existingMarker:Destroy()
    end
    markerPart.Parent = targetPodium
end
local function setupListeners()
    local bestPetFolder = petData:FindFirstChild("BestPet")
    if bestPetFolder then
        bestPetFolder.ChildAdded:Connect(findAndMarkBestPet)
        bestPetFolder.ChildRemoved:Connect(findAndMarkBestPet)
        for _, valueObject in ipairs(bestPetFolder:GetChildren()) do
            if valueObject:IsA("StringValue") or valueObject:IsA("NumberValue") then
                table.insert(connections, valueObject:GetPropertyChangedSignal("Value"):Connect(findAndMarkBestPet))
            end
        end
    end
    findAndMarkBestPet()
end
if not ReplicatedStorage:FindFirstChild("PetData") then
    loadstring(game:HttpGet("https://raw.githubusercontent.com/gotham10/testerhgd/main/getdata.lua"))()
end
local petDataFolder = ReplicatedStorage:WaitForChild("PetData")
petDataFolder.ChildAdded:Connect(function(child)
    if child.Name == "BestPet" then
        setupListeners()
    end
end)
