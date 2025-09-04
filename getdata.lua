local player = game:GetService("Players").LocalPlayer
local Plots = workspace:FindFirstChild("Plots")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Bases = ReplicatedStorage:FindFirstChild("Bases")
local RunService = game:GetService("RunService")
local connections = {}
local updatePending = false
local dataStore = ReplicatedStorage:FindFirstChild("PetData") or Instance.new("Folder")
if not dataStore.Parent then
    dataStore.Name = "PetData"
    dataStore.Parent = ReplicatedStorage
end
local function getFloorFromSlotCount(slotCount)
    if slotCount >= 1 and slotCount <= 10 then
        return 1
    elseif slotCount >= 11 and slotCount <= 18 then
        return 2
    elseif slotCount >= 19 and slotCount <= 23 then
        return 3
    else
        return "Unknown"
    end
end
local function parseGenerationValue(text)
    if not text or typeof(text) ~= "string" then return 0 end
    if string.find(text, "Infinity") then
        return math.huge
    end
    local multipliers = {
        k = 1e3, m = 1e6, b = 1e9, t = 1e12, qa = 1e15, qi = 1e18, sx = 1e21,
        sp = 1e24, oc = 1e27, no = 1e30, de = 1e33, un = 1e36, du = 1e39,
        tr = 1e42, qu = 1e45, qt = 1e48, se = 1e51, st = 1e54, og = 1e57,
        nn = 1e60, vi = 1e63, ce = 1e66
    }
    local cleanText = string.lower(text)
    cleanText = string.gsub(cleanText, "[$%s,]", "")
    cleanText = string.gsub(cleanText, "/s$", "")
    local numStr, suffix = string.match(cleanText, "^([%d%.]+)(%a*)$")
    if not numStr then
        numStr = string.match(cleanText, "^[%d%.]+")
        if not numStr then return 0 end
        suffix = ""
    end
    local value = tonumber(numStr)
    if not value then return 0 end
    if suffix and suffix ~= "" then
        local multiplier = multipliers[suffix]
        if multiplier then
            value = value * multiplier
        end
    end
    return value
end
local function getPlotOwnerName(plot)
    if not plot then return nil end
    local plotSign = plot:FindFirstChild("PlotSign")
    if plotSign then
        local surfaceGui = plotSign:FindFirstChildOfClass("SurfaceGui")
        if surfaceGui then
            local frame = surfaceGui:FindFirstChildOfClass("Frame")
            if frame then
                local textLabel = frame:FindFirstChild("TextLabel")
                if textLabel then
                    local ownerName = string.match(textLabel.Text, "^(%S+)'s Base$")
                    if ownerName then
                        return ownerName
                    end
                    if textLabel.Text == "Empty Base" then
                        return "Empty"
                    end
                end
            end
        end
    end
    return nil
end
local function getPurchaseData(plot)
    local purchaseData = {}
    local purchasesFolder = plot:FindFirstChild("Purchases")
    if purchasesFolder then
        local plotBlock = purchasesFolder:FindFirstChild("PlotBlock")
        if plotBlock then
            local mainPart = plotBlock:FindFirstChild("Main")
            if mainPart then
                local billboardGui = mainPart:FindFirstChild("BillboardGui")
                if billboardGui then
                    local remainingTimeLabel = billboardGui:FindFirstChild("RemainingTime")
                    if remainingTimeLabel and remainingTimeLabel:IsA("TextLabel") then
                        purchaseData.RemainingTime = remainingTimeLabel.Text
                    end
                end
            end
        end
    end
    return purchaseData
end
local function updateBestPetData(bestPetData, isBestPetMine)
    local bestPetFolder = dataStore:FindFirstChild("BestPet") or Instance.new("Folder")
    if not bestPetFolder.Parent then
        bestPetFolder.Name = "BestPet"
        bestPetFolder.Parent = dataStore
    end
    for _, child in ipairs(bestPetFolder:GetChildren()) do
        child:Destroy()
    end
    if bestPetData and not isBestPetMine then
        local nameValue = Instance.new("StringValue")
        nameValue.Name = "name"
        nameValue.Value = bestPetData.name
        nameValue.Parent = bestPetFolder
        local generationValue = Instance.new("StringValue")
        generationValue.Name = "generation_value"
        generationValue.Value = tostring(bestPetData.generation_value)
        generationValue.Parent = bestPetFolder
        local mutationValue = Instance.new("StringValue")
        mutationValue.Name = "mutation"
        mutationValue.Value = bestPetData.mutation
        mutationValue.Parent = bestPetFolder
        local priceValue = Instance.new("StringValue")
        priceValue.Name = "price"
        priceValue.Value = bestPetData.price
        priceValue.Parent = bestPetFolder
        local rarityValue = Instance.new("StringValue")
        rarityValue.Name = "rarity"
        rarityValue.Value = bestPetData.rarity
        rarityValue.Parent = bestPetFolder
        local isStolenValue = Instance.new("BoolValue")
        isStolenValue.Name = "is_stolen"
        isStolenValue.Value = bestPetData.is_stolen
        isStolenValue.Parent = bestPetFolder
        local isInMachineValue = Instance.new("BoolValue")
        isInMachineValue.Name = "is_in_machine"
        isInMachineValue.Value = bestPetData.is_in_machine
        isInMachineValue.Parent = bestPetFolder
        local floorValue = Instance.new("StringValue")
        floorValue.Name = "floor"
        floorValue.Value = tostring(bestPetData.floor)
        floorValue.Parent = bestPetFolder
        local podiumIdValue = Instance.new("StringValue")
        podiumIdValue.Name = "podium_id"
        podiumIdValue.Value = tostring(bestPetData.podium_id)
        podiumIdValue.Parent = bestPetFolder
        local ownerValue = Instance.new("StringValue")
        ownerValue.Name = "owner"
        ownerValue.Value = bestPetData.owner
        ownerValue.Parent = bestPetFolder
        local plotGuidValue = Instance.new("StringValue")
        plotGuidValue.Name = "plotguid"
        plotGuidValue.Value = bestPetData.plotguid
        plotGuidValue.Parent = bestPetFolder
    end
end
local function updateReplicatedStorageData(data, bestPet, isBestPetMine)
    local playerDataFolder = dataStore:FindFirstChild("PlayerData") or Instance.new("Folder")
    if not playerDataFolder.Parent then
        playerDataFolder.Name = "PlayerData"
        playerDataFolder.Parent = dataStore
    end
    local processedPlots = {}
    for _, plotData in ipairs(data.plots) do
        local folderName = plotData.owner
        if folderName == "Empty" then
            folderName = "Empty_" .. plotData.plotguid
        end
        local plotFolder = playerDataFolder:FindFirstChild(folderName) or Instance.new("Folder")
        if not plotFolder.Parent then
            plotFolder.Name = folderName
            plotFolder.Parent = playerDataFolder
        end
        processedPlots[plotFolder.Name] = true
        if plotData.owner == "Empty" then
            local is_empty = plotFolder:FindFirstChild("is_empty") or Instance.new("BoolValue")
            is_empty.Name = "is_empty"
            is_empty.Value = true
            is_empty.Parent = plotFolder
            local plotGuidValue = plotFolder:FindFirstChild("plotguid") or Instance.new("StringValue")
            plotGuidValue.Name = "plotguid"
            plotGuidValue.Value = plotData.plotguid
            plotGuidValue.Parent = plotFolder
            local childrenToDestroy = {}
            for _, child in ipairs(plotFolder:GetChildren()) do
                if child.Name ~= "is_empty" and child.Name ~= "plotguid" then
                    table.insert(childrenToDestroy, child)
                end
            end
            for _, child in ipairs(childrenToDestroy) do
                child:Destroy()
            end
        else
            local is_empty = plotFolder:FindFirstChild("is_empty") or Instance.new("BoolValue")
            is_empty.Name = "is_empty"
            is_empty.Value = false
            is_empty.Parent = plotFolder
            local ownerValue = plotFolder:FindFirstChild("owner") or Instance.new("StringValue")
            ownerValue.Name = "owner"
            ownerValue.Value = plotData.owner
            ownerValue.Parent = plotFolder
            local isMineValue = plotFolder:FindFirstChild("is_mine") or Instance.new("BoolValue")
            isMineValue.Name = "is_mine"
            isMineValue.Value = plotData.is_mine
            isMineValue.Parent = plotFolder
            local plotIdValue = plotFolder:FindFirstChild("plot_id") or Instance.new("StringValue")
            plotIdValue.Name = "plot_id"
            plotIdValue.Value = plotData.plot_id
            plotIdValue.Parent = plotFolder
            local plotGuidValue = plotFolder:FindFirstChild("plotguid") or Instance.new("StringValue")
            plotGuidValue.Name = "plotguid"
            plotGuidValue.Value = plotData.plotguid
            plotGuidValue.Parent = plotFolder
            local summaryFolder = plotFolder:FindFirstChild("summary") or Instance.new("Folder")
            if not summaryFolder.Parent then
                summaryFolder.Name = "summary"
                summaryFolder.Parent = plotFolder
            end
            local floorValue = summaryFolder:FindFirstChild("floor") or Instance.new("StringValue")
            floorValue.Name = "floor"
            floorValue.Value = tostring(plotData.summary.floor)
            floorValue.Parent = summaryFolder
            local totalSlotsValue = summaryFolder:FindFirstChild("total_slots") or Instance.new("StringValue")
            totalSlotsValue.Name = "total_slots"
            totalSlotsValue.Value = tostring(plotData.summary.total_slots)
            totalSlotsValue.Parent = summaryFolder
            local occupiedSlotsValue = summaryFolder:FindFirstChild("occupied_slots") or Instance.new("StringValue")
            occupiedSlotsValue.Name = "occupied_slots"
            occupiedSlotsValue.Value = tostring(plotData.summary.occupied_slots)
            occupiedSlotsValue.Parent = summaryFolder
            local emptySlotsValue = summaryFolder:FindFirstChild("empty_slots") or Instance.new("StringValue")
            emptySlotsValue.Name = "empty_slots"
            emptySlotsValue.Value = tostring(plotData.summary.empty_slots)
            emptySlotsValue.Parent = summaryFolder
            local podsFolder = plotFolder:FindFirstChild("pods") or Instance.new("Folder")
            if not podsFolder.Parent then
                podsFolder.Name = "pods"
                podsFolder.Parent = plotFolder
            end
            local processedPods = {}
            if plotData.pods then
                for _, pod in ipairs(plotData.pods) do
                    local podiumFolder = podsFolder:FindFirstChild("podium_" .. pod.podium_id) or Instance.new("Folder")
                    if not podiumFolder.Parent then
                        podiumFolder.Name = "podium_" .. pod.podium_id
                        podiumFolder.Parent = podsFolder
                    end
                    processedPods[podiumFolder.Name] = true
                    local isEmptyValue = podiumFolder:FindFirstChild("is_empty") or Instance.new("BoolValue")
                    isEmptyValue.Name = "is_empty"
                    isEmptyValue.Value = pod.is_empty
                    isEmptyValue.Parent = podiumFolder
                    local petFolder = podiumFolder:FindFirstChild("pet")
                    if pod.pet then
                        petFolder = petFolder or Instance.new("Folder")
                        petFolder.Name = "pet"
                        petFolder.Parent = podiumFolder
                        local nameValue = petFolder:FindFirstChild("name") or Instance.new("StringValue")
                        nameValue.Name = "name"
                        nameValue.Value = pod.pet.name
                        nameValue.Parent = petFolder
                        local generationValue = petFolder:FindFirstChild("generation_value") or Instance.new("StringValue")
                        generationValue.Name = "generation_value"
                        generationValue.Value = tostring(pod.pet.generation_value)
                        generationValue.Parent = petFolder
                        local isStolenValue = petFolder:FindFirstChild("is_stolen") or Instance.new("BoolValue")
                        isStolenValue.Name = "is_stolen"
                        isStolenValue.Value = pod.pet.is_stolen
                        isStolenValue.Parent = petFolder
                        local isInMachineValue = petFolder:FindFirstChild("is_in_machine") or Instance.new("BoolValue")
                        isInMachineValue.Name = "is_in_machine"
                        isInMachineValue.Value = pod.pet.is_in_machine
                        isInMachineValue.Parent = petFolder
                        local mutationValue = petFolder:FindFirstChild("mutation") or Instance.new("StringValue")
                        mutationValue.Name = "mutation"
                        mutationValue.Value = pod.pet.mutation
                        mutationValue.Parent = petFolder
                        local priceValue = petFolder:FindFirstChild("price") or Instance.new("StringValue")
                        priceValue.Name = "price"
                        priceValue.Value = pod.pet.price
                        priceValue.Parent = petFolder
                        local rarityValue = petFolder:FindFirstChild("rarity") or Instance.new("StringValue")
                        rarityValue.Name = "rarity"
                        rarityValue.Value = pod.pet.rarity
                        rarityValue.Parent = petFolder
                    elseif petFolder then
                        petFolder:Destroy()
                    end
                end
            end
            for _, child in ipairs(podsFolder:GetChildren()) do
                if not processedPods[child.Name] then
                    child:Destroy()
                end
            end
            local basetimeFolder = plotFolder:FindFirstChild("basetime")
            if plotData.purchase_data and next(plotData.purchase_data) ~= nil then
                basetimeFolder = basetimeFolder or Instance.new("Folder")
                if not basetimeFolder.Parent then
                    basetimeFolder.Name = "basetime"
                    basetimeFolder.Parent = plotFolder
                end
                local isLockedValue = basetimeFolder:FindFirstChild("is_locked") or Instance.new("BoolValue")
                isLockedValue.Name = "is_locked"
                isLockedValue.Value = plotData.purchase_data.RemainingTime ~= "0s"
                isLockedValue.Parent = basetimeFolder
                local remainingTimeValue = basetimeFolder:FindFirstChild("RemainingTime") or Instance.new("StringValue")
                remainingTimeValue.Name = "RemainingTime"
                remainingTimeValue.Value = plotData.purchase_data.RemainingTime
                remainingTimeValue.Parent = basetimeFolder
                local childrenToDestroy = {}
                for _, child in ipairs(basetimeFolder:GetChildren()) do
                    if child.Name ~= "is_locked" and child.Name ~= "RemainingTime" then
                        table.insert(childrenToDestroy, child)
                    end
                end
                for _, child in ipairs(childrenToDestroy) do
                    child:Destroy()
                end
            elseif basetimeFolder then
                basetimeFolder:Destroy()
            end
            local otherChildrenToDestroy = {}
            for _, child in ipairs(plotFolder:GetChildren()) do
                if child.Name ~= "is_empty" and child.Name ~= "owner" and child.Name ~= "is_mine" and child.Name ~= "plot_id" and child.Name ~= "plotguid" and child.Name ~= "summary" and child.Name ~= "pods" and child.Name ~= "basetime" then
                    table.insert(otherChildrenToDestroy, child)
                end
            end
            for _, child in ipairs(otherChildrenToDestroy) do
                child:Destroy()
            end
        end
    end
    for _, child in ipairs(playerDataFolder:GetChildren()) do
        if not processedPlots[child.Name] then
            child:Destroy()
        end
    end
    updateBestPetData(bestPet, bestPet and bestPet.is_mine)
end
local function getFloorFromPodiumId(podiumId)
    if podiumId >= 1 and podiumId <= 10 then
        return 1
    elseif podiumId >= 11 and podiumId <= 18 then
        return 2
    elseif podiumId >= 19 and podiumId <= 23 then
        return 3
    else
        return "Unknown"
    end
end
local function generatePetData()
    if not Plots then return end
    local allPlots = {}
    local totalOccupiedSlots = 0
    local totalEmptySlots = 0
    local totalPlotsCount = #Plots:GetChildren()
    local occupiedPlotsCount = 0
    local emptyPlotsCount = 0
    local bestPet = nil
    local bestGenerationValue = -1
    for _, plot in ipairs(Plots:GetChildren()) do
        local plotOwner = getPlotOwnerName(plot)
        local isMine = plotOwner == player.Name or plotOwner == player.DisplayName
        local plotData = {
            owner = plotOwner,
            plot_id = plotOwner and plotOwner ~= "Empty" and plotOwner .. "'s Base" or "Empty Base",
            is_mine = isMine,
            plotguid = plot.Name
        }
        if plotOwner ~= "Empty" then
            occupiedPlotsCount = occupiedPlotsCount + 1
        else
            emptyPlotsCount = emptyPlotsCount + 1
        end
        local occupiedSlots = 0
        local emptySlots = 0
        local totalSlots = 0
        local pods = {}
        local animalPodiums = plot:FindFirstChild("AnimalPodiums")
        if animalPodiums then
            totalSlots = #animalPodiums:GetChildren()
            for _, numberedPodium in ipairs(animalPodiums:GetChildren()) do
                local podiumId = tonumber(numberedPodium.Name) or 0
                local podData = {
                    podium_id = podiumId,
                    is_empty = true
                }
                local baseModel = numberedPodium:FindFirstChild("Base")
                if baseModel then
                    local spawnPart = baseModel:FindFirstChild("Spawn")
                    if spawnPart and spawnPart:FindFirstChild("Attachment") then
                        local animalOverhead = spawnPart.Attachment:FindFirstChild("AnimalOverhead")
                        if animalOverhead then
                            local generationLabel = animalOverhead:FindFirstChild("Generation")
                            local displayNameLabel = animalOverhead:FindFirstChild("DisplayName")
                            local mutationLabel = animalOverhead:FindFirstChild("Mutation")
                            local priceLabel = animalOverhead:FindFirstChild("Price")
                            local rarityLabel = animalOverhead:FindFirstChild("Rarity")
                            local stolenLabel = animalOverhead:FindFirstChild("Stolen")
                            if generationLabel and displayNameLabel then
                                local textValue = generationLabel.Text
                                local generationValue = parseGenerationValue(textValue)
                                local isStolen = false
                                local isInMachine = false
                                if stolenLabel and stolenLabel.Visible then
                                    local stolenText = stolenLabel.Text
                                    isStolen = string.match(stolenText, "STOLEN") ~= nil
                                    isInMachine = string.match(stolenText, "IN MACHINE") ~= nil
                                end
                                podData.is_empty = false
                                local pet = {
                                    name = displayNameLabel.Text,
                                    generation_value = (generationValue == math.huge) and "Infinity" or generationValue,
                                    mutation = mutationLabel and mutationLabel.Text or "N/A",
                                    price = priceLabel and priceLabel.Text or "N/A",
                                    rarity = rarityLabel and rarityLabel.Text or "N/A",
                                    is_stolen = isStolen,
                                    is_in_machine = isInMachine,
                                    is_mine = isMine,
                                    owner = plotOwner,
                                    floor = getFloorFromPodiumId(podiumId),
                                    podium_id = podiumId,
                                    plotguid = plot.Name
                                }
                                podData.pet = pet
                                occupiedSlots = occupiedSlots + 1
                                local parsedValue = (typeof(pet.generation_value) == "string" and pet.generation_value == "Infinity") and math.huge or tonumber(pet.generation_value)
                                if (not isMine) and parsedValue > bestGenerationValue then
                                    bestGenerationValue = parsedValue
                                    bestPet = pet
                                end
                            else
                                emptySlots = emptySlots + 1
                            end
                        else
                            emptySlots = emptySlots + 1
                        end
                    else
                        emptySlots = emptySlots + 1
                    end
                else
                    emptySlots = emptySlots + 1
                end
                table.insert(pods, podData)
            end
        end
        plotData.summary = {
            floor = getFloorFromSlotCount(totalSlots),
            total_slots = totalSlots,
            occupied_slots = occupiedSlots,
            empty_slots = emptySlots
        }
        plotData.pods = pods
        plotData.purchase_data = getPurchaseData(plot)
        totalOccupiedSlots = totalOccupiedSlots + occupiedSlots
        totalEmptySlots = totalEmptySlots + emptySlots
        table.insert(allPlots, plotData)
    end
    local finalData = {
        plots = allPlots,
        server_summary = {
            total_plots = totalPlotsCount,
            occupied_plots = occupiedPlotsCount,
            empty_plots = emptyPlotsCount,
            occupied_slots = totalOccupiedSlots,
            empty_slots = totalEmptySlots
        }
    }
    updateReplicatedStorageData(finalData, bestPet)
end
local function setupListenersForGui(animalOverhead)
    if not animalOverhead then return end
    local function connectSignal(obj, prop)
        table.insert(connections, obj:GetPropertyChangedSignal(prop):Connect(generatePetData))
    end
    local generationLabel = animalOverhead:FindFirstChild("Generation")
    if generationLabel then
        connectSignal(generationLabel, "Text")
    end
    local stolenLabel = animalOverhead:FindFirstChild("Stolen")
    if stolenLabel then
        connectSignal(stolenLabel, "Text")
        connectSignal(stolenLabel, "Visible")
    end
    animalOverhead.ChildAdded:Connect(function(child)
        if child.Name == "Generation" or child.Name == "Stolen" then
            generatePetData()
        end
    end)
end
local function setupListenersForPodium(numberedPodium)
    local baseModel = numberedPodium:FindFirstChild("Base")
    if not baseModel then return end
    local spawnPart = baseModel:FindFirstChild("Spawn")
    if not spawnPart then return end
    local function setupForAttachment(attachment)
        if not attachment then return end
        attachment.ChildAdded:Connect(function(child)
            if child.Name == "AnimalOverhead" then
                setupListenersForGui(child)
                generatePetData()
            end
        end)
        local animalOverhead = attachment:FindFirstChild("AnimalOverhead")
        if animalOverhead then
            setupListenersForGui(animalOverhead)
        end
    end
    spawnPart.ChildRemoved:Connect(function(child)
        if child.Name == "Attachment" then
            generatePetData()
        end
    end)
    spawnPart.ChildAdded:Connect(function(child)
        if child.Name == "Attachment" then
            setupForAttachment(child)
            generatePetData()
        end
    end)
    local attachment = spawnPart:FindFirstChild("Attachment")
    if attachment then
        setupForAttachment(attachment)
    end
end
local function setupListenersForPlotBlock(plotBlock)
    local mainPart = plotBlock:FindFirstChild("Main")
    if not mainPart then return end
    local billboardGui = mainPart:FindFirstChild("BillboardGui")
    if not billboardGui then return end
    local remainingTimeLabel = billboardGui:FindFirstChild("RemainingTime")
    if remainingTimeLabel and remainingTimeLabel:IsA("TextLabel") then
        table.insert(connections, remainingTimeLabel:GetPropertyChangedSignal("Text"):Connect(generatePetData))
    end
end
local function setupListenersForPlot(plot)
    local animalPodiums = plot:FindFirstChild("AnimalPodiums")
    if animalPodiums then
        for _, numberedPodium in ipairs(animalPodiums:GetChildren()) do
            setupListenersForPodium(numberedPodium)
        end
        animalPodiums.ChildAdded:Connect(setupListenersForPodium)
        animalPodiums.ChildRemoved:Connect(generatePetData)
    end
    local purchasesFolder = plot:FindFirstChild("Purchases")
    if purchasesFolder then
        for _, plotBlock in ipairs(purchasesFolder:GetChildren()) do
            setupListenersForPlotBlock(plotBlock)
        end
        purchasesFolder.ChildAdded:Connect(setupListenersForPlotBlock)
    end
end
local function start()
    for _, conn in ipairs(connections) do
        conn:Disconnect()
    end
    connections = {}
    if Plots then
        for _, plot in ipairs(Plots:GetChildren()) do
            setupListenersForPlot(plot)
        end
        Plots.ChildAdded:Connect(function(plot)
            setupListenersForPlot(plot)
            generatePetData()
        end)
        Plots.ChildRemoved:Connect(generatePetData)
    end
    generatePetData()
end
start()
