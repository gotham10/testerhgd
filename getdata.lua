local player = game:GetService("Players").LocalPlayer
local Plots = workspace:FindFirstChild("Plots")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Bases = ReplicatedStorage:FindFirstChild("Bases")

local function getFloorFromSlotCount(slotCount)
    if not Bases then return "Unknown" end
    
    local floorRanges = {}
    local currentMaxSlots = 0
    local floorCount = 1
    local floorModels = {}

    for _, model in ipairs(Bases:GetChildren()) do
        table.insert(floorModels, model)
    end

    table.sort(floorModels, function(a, b)
        local aPodiums = a:FindFirstChild("AnimalPodiums")
        local bPodiums = b:FindFirstChild("AnimalPodiums")
        if aPodiums and bPodiums then
            return #aPodiums:GetChildren() < #bPodiums:GetChildren()
        end
        return false
    end)

    for _, model in ipairs(floorModels) do
        local animalPodiums = model:FindFirstChild("AnimalPodiums")
        if animalPodiums then
            local maxSlots = #animalPodiums:GetChildren()
            if maxSlots > currentMaxSlots then
                floorRanges[floorCount] = {min = currentMaxSlots + 1, max = maxSlots}
                currentMaxSlots = maxSlots
                floorCount = floorCount + 1
            end
        end
    end

    for floorNum, range in pairs(floorRanges) do
        if slotCount >= range.min and slotCount <= range.max then
            return floorNum
        end
    end
    
    return "Unknown"
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

local function prettyPrint(data, indent)
    local output = ""
    local indentStr = string.rep(" ", indent or 0)
    
    if type(data) == "table" then
        local keys = {}
        local isArray = true
        for k, v in pairs(data) do
            table.insert(keys, k)
            if type(k) ~= "number" or k ~= #keys then
                isArray = false
            end
        end
        table.sort(keys)
        
        output = output .. (isArray and "[" or "{") .. "\n"
        for i, k in ipairs(keys) do
            local v = data[k]
            output = output .. string.rep(" ", indent + 2)
            if not isArray then
                output = output .. "\"" .. tostring(k) .. "\": "
            end
            output = output .. prettyPrint(v, indent + 2)
            if i < #keys then
                output = output .. ","
            end
            output = output .. "\n"
        end
        output = output .. indentStr .. (isArray and "]" or "}")
    elseif type(data) == "string" then
        output = "\"" .. tostring(data) .. "\""
    elseif type(data) == "number" then
        output = tostring(data)
    elseif type(data) == "boolean" then
        output = tostring(data)
    else
        output = "null"
    end
    
    return output
end

local function generatePetData()
    if not Plots then return end
    
    local allPlots = {}
    local totalOccupiedSlots = 0
    local totalEmptySlots = 0
    local totalPlotsCount = #Plots:GetChildren()
    local occupiedPlotsCount = 0
    local emptyPlotsCount = 0

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
        local floorType = "Unknown"
        local pods = {}

        local animalPodiums = plot:FindFirstChild("AnimalPodiums")
        if animalPodiums then
            totalSlots = #animalPodiums:GetChildren()
            floorType = getFloorFromSlotCount(totalSlots)

            for _, numberedPodium in ipairs(animalPodiums:GetChildren()) do
                local podData = {
                    podium_id = tonumber(numberedPodium.Name) or 0,
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
                                podData.pet = {
                                    name = displayNameLabel.Text,
                                    generation_value = (generationValue == math.huge) and "Infinity" or generationValue,
                                    mutation = mutationLabel and mutationLabel.Text or "N/A",
                                    price = priceLabel and priceLabel.Text or "N/A",
                                    rarity = rarityLabel and rarityLabel.Text or "N/A",
                                    is_stolen = isStolen,
                                    is_in_machine = isInMachine
                                }
                                occupiedSlots = occupiedSlots + 1
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
            floor = floorType,
            total_slots = totalSlots,
            occupied_slots = occupiedSlots,
            empty_slots = emptySlots
        }

        if not isMine then
            plotData.pods = pods
        end
        
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
    
    setclipboard(prettyPrint(finalData, 0))
end

generatePetData()
