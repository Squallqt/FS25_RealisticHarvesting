-- EN: Physics-based engine load and speed limit calculator for combine harvesters.
--     Tracks cut area and harvested mass each tick to compute: engine load (%),
--     dynamic speed limit, productivity (t/h, L/h), yield (t/ha), and crop loss (%)
--     from combine settings deviation. Supports grain, forage, root, and cotton types.
-- UA: Фізичний калькулятор навантаження двигуна та ліміту швидкості для комбайнів.
--     Відстежує площу зрізу та масу врожаю кожен тік для розрахунку: навантаження (%),
--     динамічного ліміту швидкості, продуктивності (т/год, л/год), врожайності (т/га)
--     та втрат врожаю (%) від відхилення налаштувань. Підтримує зернові, форажні, коренеплоди, бавовну.
RHM_LoadCalculator = {}
local LoadCalculator_mt = Class(RHM_LoadCalculator)

function RHM_LoadCalculator.new(modDirectory)
    local self = setmetatable({}, LoadCalculator_mt)
    
    self.modDirectory = modDirectory or g_currentModDirectory
    
    -- EN: average load calculation data / UA: Дані для розрахунку середнього навантаження
    self.totalDistance = 0
    self.totalArea = 0
    self.currentTime = 0
    self.avgTime = 1500  -- EN: 1.5 seconds between measuring / UA: 1.5 секунди між вимірами
    self.distanceForMeasuring = 3  -- EN: 3 meters / UA: 3 метри
    
    -- EN: Base perf (will be set in onLoad) / UA: Базова продуктивність (оновиться в onLoad)
    self.basePerfMass = 0  -- EN: kg per second / UA: кг на секунду
    self.currentAvgMass = 0
    self.lastAvgMass = 0  -- EN: Prior average for acceleration / UA: Попереднє середнє для прискорення
    self.rawAvgMass = 0  -- EN: Raw unsmoothed value for braking / UA: Сире незгладжене для гальмування
    
    -- EN: Current Load Enum / UA: Поточне навантаження
    self.engineLoad = 0
    self.speedLimit = 15  -- EN: Current km/h limit / UA: Поточний ліміт км/год
    self.genuineSpeedLimit = -1  -- EN: Genuine limits from game db / UA: Ліміт з гри
    self.lastCropType = nil  -- EN: Last crop / UA: Остання культура
    self.lastHarvestTime = 0  -- EN: Last harvest time / UA: Час останнього збирання
    
    -- Crop loss and productivity
    self.cropLoss = 0  -- EN: Current crop loss (%) / UA: Поточні втрати врожаю (%)
    self.tonPerHour = 0  -- EN: Yield in T/h / UA: Продуктивність в Т/год
    self.litersPerHour = 0  -- EN: Yield in L/h / UA: Продуктивність в Л/год
    self.hectaresPerHour = 0 -- EN: Area rate in ha/h / UA: Продуктивність в га/год
    self.totalOutputMass = 0  -- EN: Total harvested mass / UA: Загальна маса зібраного врожаю
    
    -- EN: Yield counters accumulation / UA: Накопичення продуктивності
    self.productivityMass = 0  -- EN: Accumulated mass (kg) / UA: Накопичена маса (кг)
    self.productivityLiters = 0  -- EN: Accumulated volume (L) / UA: Накопичений об'єм (л)
    self.productivityTime = 0  -- EN: Accumulation time (ms) / UA: Час накопичення (мс)
    self.productivityUpdateInterval = 3000  -- EN: Update interval (ms) / UA: Інтервал оновлення
    
    -- EN: Load accumulator / UA: Накопичувач навантаження
    self.loadAccumulatedMass = 0 -- kg
    
    -- Combine RHMSettings System
    self.combineMemory = nil  -- EN: Will be set by rhm_Combine / UA: Буде встановлено з rhm_Combine
    self.currentCrop = nil    -- EN: Current crop for loss calc / UA: Поточна культура для розрахунку втрат
    
    self.debug = false  -- EN: Kept for compatibility, unused / UA: Залишено для сумісності, не використовується
    rhm_log("RHM [RHM_LoadCalculator]: RHM: RHM_LoadCalculator initialized")
    
    return self
end

---EN: Dynamically calculates the physical crop difficulty factor based on FS25 game data
---UA: Динамічно розраховує фізичний фактор опору культури на основі даних гри FS25
---@param fruitTypeIndex number FruitType index from cutter
---@param fillTypeIndex number FillType index from tank
---@param machineType string "grain", "forage", "root", or "cotton"
---@param isPickup boolean Whether harvesting from swaths/windrows
---@param isForageCutter boolean Whether using direct forage cutter
---@return number cropFactor Scaled difficulty coefficient
function RHM_LoadCalculator:getCropFactor(fruitTypeIndex, fillTypeIndex, machineType, isPickup, isForageCutter)
    machineType = machineType or "grain"

    -- 1. Identify fruitType and fillType descriptors from GIANTS managers
    local fruitTypeDesc = nil
    if g_fruitTypeManager and fruitTypeIndex and fruitTypeIndex ~= 0 and fruitTypeIndex ~= FruitType.UNKNOWN then
        fruitTypeDesc = g_fruitTypeManager:getFruitTypeByIndex(fruitTypeIndex)
    end

    local fillTypeDesc = nil
    if g_fillTypeManager and fillTypeIndex and fillTypeIndex ~= 0 and fillTypeIndex ~= FillType.UNKNOWN then
        fillTypeDesc = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)
    end

    local cropName = "UNKNOWN"
    if fruitTypeDesc and fruitTypeDesc.name then
        cropName = string.upper(fruitTypeDesc.name)
    elseif fillTypeDesc and fillTypeDesc.name then
        cropName = string.upper(fillTypeDesc.name)
    elseif self.currentCrop then
        cropName = string.upper(self.currentCrop)
    end

    -- 2. Base density and yield data from FS25
    -- Density in kg/L (FS25 massPerLiter is in tons/L, so multiply by 1000)
    local density = 0.78
    if fillTypeDesc and fillTypeDesc.massPerLiter and fillTypeDesc.massPerLiter > 0 then
        density = fillTypeDesc.massPerLiter * 1000
    end

    -- Base yield in L/m2
    local literPerSqm = 1.0
    if fruitTypeDesc and fruitTypeDesc.literPerSqm and fruitTypeDesc.literPerSqm > 0 then
        literPerSqm = fruitTypeDesc.literPerSqm
    end

    -- Check if crop produces straw/windrows (meaning straw enters the thresher)
    local hasStraw = false
    if fruitTypeDesc and fruitTypeDesc.hasWindrow ~= nil then
        hasStraw = fruitTypeDesc.hasWindrow
    else
        hasStraw = (cropName == "WHEAT" or cropName == "BARLEY" or cropName == "OAT" 
                 or cropName == "RYE" or cropName == "SPELT" or cropName == "TRITICALE")
    end

    -- 3. Calculate category-specific resistance
    local factor = 1.0

    if machineType == "forage" then
        -- FORAGE HARVESTERS (Chop whole crop: Corn silage, grass, etc.)
        if cropName:find("MAIZE") or cropName:find("CORN") or cropName:find("SILAGE") or cropName:find("CHAFF") or cropName:find("GPS") then
            factor = 0.30  -- Calibrated to ~350-550 t/h on 800+ HP (Kemper/Orbis direct whole silage)
        elseif cropName:find("STRAW") then
            factor = 0.48  -- Straw windrow pickup
        elseif cropName:find("HAY") or cropName:find("DRYGRASS") then
            factor = 0.30  -- Dry grass / Hay swath pickup (softer, wilted fibers)
        elseif cropName:find("GRASS") or cropName:find("MEADOW") or cropName:find("ALFALFA") or cropName:find("LUCERNE") or cropName:find("CLOVER") then
            if isPickup then
                factor = 0.40  -- Grass swath pickup (zero cutting work, up to 410 t/h on 900 HP)
            else
                factor = 0.65  -- Direct-cut standing grass (Direct Disc / XDisc: 3000 RPM discs + chop ~250 t/h)
            end
        else
            factor = isPickup and 0.35 or 0.50  -- Universal forage fallback
        end

    elseif machineType == "root" then
        -- ROOT & VEGETABLE HARVESTERS (Beet, Potato, Carrot, Parsnip, Onion, etc.)
        if cropName:find("POTATO") then
            factor = 0.55
        elseif cropName:find("SUGARBEET") or cropName:find("BEETROOT") then
            factor = 0.65
        elseif cropName:find("CARROT") or cropName:find("PARSNIP") then
            factor = 0.35
        elseif cropName:find("SPINACH") or cropName:find("GREENBEAN") then
            factor = 1.80  -- Lower mass, delicate leafy harvesting
        else
            factor = 0.50  -- Universal root fallback
        end

    elseif machineType == "cotton" then
        -- COTTON HARVESTERS (Very fluffy, light density 0.05 kg/L)
        factor = 4.50

    else
        -- GRAIN COMBINE HARVESTERS
        if isPickup then
            factor = cropName:find("STRAW") and 0.48 or 0.45
        elseif hasStraw then
            -- Cereals with straw:
            -- Calibrated so 500hp combine in 100% fertilized wheat operates at 4.5 - 6.0 km/h at ~90% load
            factor = 0.85
            if cropName == "OAT" then
                factor = 1.10
            elseif cropName == "BARLEY" then
                factor = 0.88
            elseif cropName == "RYE" or cropName == "SPELT" or cropName == "TRITICALE" then
                factor = 0.85
            end
        else
            -- Crops without straw in thresher (heads/cobs only, stalks left on field)
            if cropName:find("CORN") or cropName:find("MAIZE") then
                factor = 0.48  -- Only cobs enter combine (~30% plant biomass)
            elseif cropName:find("SUNFLOWER") then
                factor = 1.35
            elseif cropName:find("CANOLA") or cropName:find("OILSEED") or cropName:find("FLAX") or cropName:find("LINSEED") or cropName:find("MUSTARD") or cropName:find("POPPY") then
                factor = 1.15
            elseif cropName:find("SOYBEAN") or cropName:find("PEA") or cropName:find("LENTIL") or cropName:find("CHICKPEA") or cropName:find("BEANS") then
                factor = 1.10
            elseif cropName:find("RICE") then
                factor = 1.25
            else
                -- DYNAMIC AUTO-CALCULATION FOR UNKNOWN / MODDED CROPS
                local cropKgPerSqm = math.max(0.1, literPerSqm * density)
                local baseRef = hasStraw and 0.85 or 0.55
                factor = math.min(3.0, math.max(0.3, baseRef * (0.8 / cropKgPerSqm)))
            end
        end
    end

    -- Hook for dev tuning if enabled
    if RHM_CropFactorTuning and RHM_CropFactorTuning.isEnabled and RHM_CropFactorTuning.isEnabled() then
        local tun = RHM_CropFactorTuning.getFactorOverride(self.currentCrop)
        if tun ~= nil then
            factor = tun
        end
    end

    return factor
end

---EN: Sets base performance mass / UA: Встановлює базову продуктивність (маса)
function RHM_LoadCalculator:setBasePerformance(basePerfMass)
    self.basePerfMass = basePerfMass
    
    rhm_log(string.format("RHM [RHM_LoadCalculator]: RHM: Base performance set to %.2f kg/s (%.1f t/h)", 
        self.basePerfMass, self.basePerfMass * 3.6))
end

---EN: Gets base performance from engine power / UA: Отримує базову продуктивність з потужності двигуна
function RHM_LoadCalculator:getBasePerformanceFromPower(vehicle)
    -- NEW LOGIC: Calculate throughput based on Horsepower
    -- Approximation: 1 HP ~= 0.035 kg/s throughput for Grain
    
    local coef = 0.035  -- EN: Standard coefficient for grain / UA: Стандартний коефіцієнт для зерна
    local power = 0
    
    local keyCategory = "vehicle.storeData.category"
    local category = vehicle.xmlFile:getValue(keyCategory)
    
    if category == "forageHarvesters" or category == "forageHarvesterCutters" then
        coef = 0.051  -- Forage harvesters: calibrated to JD 9900 (956hp) ~400 t/hr corn silage
    elseif category == "beetVehicles" or category == "beetHarvesting" then
        coef = 0.060  -- Beet harvesting
    elseif category == "potatoVehicles" then
        coef = 0.060  -- Potato harvesting
    elseif category == "cottonVehicles" then
        coef = 0.015  -- Cotton
    elseif category == "vegetableVehicles" then
        coef = 0.060  -- Vegetable harvesting
    end
    
    if vehicle.spec_motorized and vehicle.spec_motorized.motor then
        power = vehicle.spec_motorized.motor.hp or 0
    end
    
    -- SMART DETECTION: If category didn't match specific types
    if math.abs(coef - 0.035) < 0.001 then
        local isVegetable = false
        
        -- 1. Check FillTypes (if available)
        if vehicle.getFillUnitFillTypes and vehicle.spec_fillUnit then
            for _, fillUnit in ipairs(vehicle.spec_fillUnit.fillUnits) do
                 if fillUnit.supportedFillTypes then
                     for fillTypeIndex, _ in pairs(fillUnit.supportedFillTypes) do
                        local fillType = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)
                        if fillType and fillType.name then
                            local name = string.upper(fillType.name)
                            if name == "ONION" or name == "CARROT" or name == "BEETROOT" or name == "PARSNIP" then
                                isVegetable = true
                                break
                            end
                        end
                     end
                 end
                 if isVegetable then break end
            end
        end
        
        -- 2. Check Vehicle Name / Filename
        if not isVegetable then
            local name = string.lower(vehicle:getFullName() or "")
            local xml = string.lower(vehicle.configFileName or "")
            
            if name:find("onion") or name:find("carrot") or name:find("vegetable") or 
               xml:find("onion") or xml:find("carrot") or xml:find("vegetable") or
               name:find("ur%-%d+") or name:find("umr") or name:find("keiler") or 
               xml:find("ur_") or xml:find("umr_") then
                isVegetable = true
            end
        end
        
        if isVegetable then
            coef = 0.080 -- EN: Standardized vegetable coefficient (increased for downhill capacity) / UA: Стандартизований коефіцієнт для овочів
        end
    end
    
    -- NEXAT FIX (Module search)
    if (not power or power == 0) then
        local function findVehicleWithEngine(v)
            if not v then return nil end
            if v.spec_motorized and v.spec_motorized.motor and v.spec_motorized.motor.hp and v.spec_motorized.motor.hp > 0 then
                return v
            end
            if v.getAttacherVehicle then
                return findVehicleWithEngine(v:getAttacherVehicle())
            end
            if v.rootVehicle and v.rootVehicle ~= v then
                 if v.rootVehicle.spec_motorized and v.rootVehicle.spec_motorized.motor and v.rootVehicle.spec_motorized.motor.hp > 0 then
                    return v.rootVehicle
                 end
            end
            return nil
        end
        local engineVeh = findVehicleWithEngine(vehicle)
        if engineVeh then
            power = engineVeh.spec_motorized.motor.hp or 0
        end
    end
    
    if power == 0 then
        local key, motorId = ConfigurationUtil.getXMLConfigurationKey(
            vehicle.xmlFile, 
            vehicle.configurations.motor, 
            "vehicle.motorized.motorConfigurations.motorConfiguration", 
            "vehicle.motorized", 
            "motor"
        )
        local fallbackConfigKey = "vehicle.motorized.motorConfigurations.motorConfiguration(0)"
        local fallbackOldKey = "vehicle"
        
        if SpecializationUtil.hasSpecialization(Motorized, vehicle.specializations) then
            power = ConfigurationUtil.getConfigurationValue(
                vehicle.xmlFile, key, "", "#hp", nil, fallbackConfigKey, fallbackOldKey
            )
        end
    end
    
    if power and tonumber(power) > 0 then
        local basePerf = tonumber(power) * coef
        rhm_log(string.format("RHM [RHM_LoadCalculator]: RHM DEBUG: BasePerf Mass computed for %s (cat: %s, coef: %.3f): %d hp -> %.2f kg/s (%.1f t/h)", 
            vehicle:getFullName(), category or "unknown", coef, power, basePerf, basePerf * 3.6))
        return basePerf
    end
    
    -- NEXAT POWER FIX
    if vehicle.configFileName and vehicle.configFileName:lower():find("nexat") then
        local basePerf = 1100 * coef  
        return basePerf
    end
    
    return 10.0  -- Default ~36 t/h
end

---EN: Updates load calculation variables / UA: Оновлює дані для розрахунку навантаження
function RHM_LoadCalculator:update(vehicle, dt, mass)
    -- EN: Safety check for vehicle parameter
    -- UA: Перевірка безпеки для параметра vehicle
    if not vehicle then
        return
    end
    
    self.totalDistance = self.totalDistance + (vehicle.lastMovedDistance or 0)
    self.loadAccumulatedMass = (self.loadAccumulatedMass or 0) + (mass or 0)
    
    -- INSTANT REACTION FIX:
    -- EN: Only reset to 5 km/h if starting from idle (prevents reset loop during harvest)
    -- UA: Після простою скидаємо до 5 км/год (запобігає циклу скидання під час роботи)
    if mass and mass > 0 and self.speedLimit >= (self.genuineSpeedLimit - 0.1) and self.genuineSpeedLimit > 0 
       and (self.lastAvgMass or 0) < 0.1 then
         self.speedLimit = 5.0
    end
    
    self.currentTime = self.currentTime + dt
    if self.currentTime > self.avgTime or self.totalDistance > self.distanceForMeasuring then
        self:updateSettingsImpact() -- EN: Recalculate settings penalty / UA: Перераховання штрафу налаштувань
        self:calculateEngineLoad(vehicle)
        self:calculateSpeedLimit(vehicle)
        
        -- EN: Reset tick accumulators / UA: Скидаємо лічильники
        self.currentTime = 0
        self.loadAccumulatedMass = 0
        self.totalDistance = 0
    end
end

---EN: Calculates Engine Load / UA: Розраховує навантаження на двигун
function RHM_LoadCalculator:calculateEngineLoad(vehicle)
    if self.currentTime <= 0 then
        return
    end
    
    -- EN: BASE CROP FACTOR & MACHINE TYPE / UA: БАЗОВИЙ КОЕФІЦІЄНТ ТА ТИП МАШИНИ
    local spec_combine = vehicle.spec_combine
    local rhmSpec = vehicle.spec_rhm_Combine
    
    if not spec_combine then
        rhm_log("RHM [RHM_LoadCalculator]: WARNING - vehicle.spec_combine is nil, using fallback values")
        self.engineLoad = 0
        return
    end

    -- Keep currentCrop synchronized from combine memory
    if self.combineMemory and self.combineMemory.currentCrop then
        self.currentCrop = self.combineMemory.currentCrop
    end

    local machineType = (rhmSpec and rhmSpec.combineMemory) and rhmSpec.combineMemory.machineType or "grain"
    local isPickup = false
    local isForageCutter = false
    
    -- EN: ROBUST DETECTION (Check attached implements) / UA: НАДІЙНА ДЕТЕКЦІЯ
    if vehicle.getAttachedImplements then
        local implements = vehicle:getAttachedImplements()
        if implements then
            for _, implement in pairs(implements) do
                local implObj = implement.object
                if implObj then
                    local storeItem = nil
                    if g_storeManager and g_storeManager.getItemByXMLFilename then
                        storeItem = g_storeManager:getItemByXMLFilename(implObj.configFileName)
                    end
                    local cat = storeItem and storeItem.categoryName or ""
                    
                    -- Detect Forage Harvester Header
                    if implObj.spec_forageHarvesterCutter ~= nil or implObj.spec_forageCutter ~= nil 
                       or cat == "forageHarvesterCutters" then
                        isForageCutter = true
                    end

                    -- Detect WINDROW Pickup (excluding root/veg direct harvesters)
                    if implObj.spec_pickup ~= nil or cat == "pickups" or cat == "slasher" then
                        local isVegetableHarvester = false
                        
                        -- Category check
                        if cat == "vegetableVehicles" or cat == "onionHarvesters" 
                           or cat == "rootCropHarvesters" then
                            isVegetableHarvester = true
                        end
                        
                        -- FillType check
                        if not isVegetableHarvester and implObj.spec_fillUnit then
                            for _, fillUnit in ipairs(implObj.spec_fillUnit.fillUnits or {}) do
                                if fillUnit.supportedFillTypes then
                                    for fillTypeIndex, _ in pairs(fillUnit.supportedFillTypes) do
                                        local ft = nil
                                        if g_fillTypeManager and g_fillTypeManager.getFillTypeByIndex then
                                            ft = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)
                                        end
                                        if ft and ft.name then
                                            local ftName = string.upper(ft.name)
                                            if ftName == "ONION" or ftName == "ONION_DIRTY"
                                               or ftName == "CARROT" or ftName == "BEETROOT"
                                               or ftName == "PARSNIP" or ftName == "POTATO" then
                                                isVegetableHarvester = true
                                                break
                                            end
                                        end
                                    end
                                end
                                if isVegetableHarvester then break end
                            end
                        end
                        
                        -- Filename fallback
                        if not isVegetableHarvester then
                            local xml = string.lower(implObj.configFileName or "")
                            if xml:find("onion") or xml:find("carrot") or xml:find("beetroot")
                               or xml:find("parsnip") or xml:find("ur_") or xml:find("umr_")
                               or xml:find("keiler") then
                                isVegetableHarvester = true
                            end
                        end
                        
                        if not isVegetableHarvester then
                            isPickup = true
                        end
                    end
                    
                    if isPickup or isForageCutter then break end
                end
            end
        end
    end

    -- Resolve fruit type name for pickup fallback and logging
    local fruitTypeDesc = nil
    if g_fruitTypeManager and g_fruitTypeManager.getFruitTypeByIndex then
        fruitTypeDesc = g_fruitTypeManager:getFruitTypeByIndex(spec_combine.lastValidInputFruitType or 0)
    end
    
    local currentFruitTypeName = "UNKNOWN"
    if fruitTypeDesc and fruitTypeDesc.name then
        currentFruitTypeName = string.upper(fruitTypeDesc.name)
    elseif rhmSpec and rhmSpec.lastFillType then
        local fillTypeDesc = nil
        if g_fillTypeManager and g_fillTypeManager.getFillTypeByIndex then
            fillTypeDesc = g_fillTypeManager:getFillTypeByIndex(rhmSpec.lastFillType)
        end
        if fillTypeDesc and fillTypeDesc.name then
            currentFruitTypeName = string.upper(fillTypeDesc.name)
        end
    end

    -- Fallback pickup detection: WINDROW or fruitType 0
    if not isPickup then
        if currentFruitTypeName:find("WINDROW") or spec_combine.lastValidInputFruitType == 0 then
            isPickup = true
        end
    end
    self.isPickup = isPickup

    -- DYNAMIC CROP FACTOR CALCULATION
    local cropFactor = self:getCropFactor(spec_combine.lastValidInputFruitType, rhmSpec and rhmSpec.lastFillType, machineType, isPickup, isForageCutter)

    if self.lastCropType ~= spec_combine.lastValidInputFruitType then
        self.lastCropType = spec_combine.lastValidInputFruitType
        local mode = isPickup and "PICKUP" or (isForageCutter and "FORAGE_CUTTER" or "DIRECT_CUT")
        rhm_log(string.format("RHM [RHM_LoadCalculator]: RHM DEBUG: [INPUT] %s (%s). Final Factor: %.3f", mode, currentFruitTypeName, cropFactor))
    end
    
    -- EN: MOISTURE FACTOR / UA: КОЕФІЦІЄНТ ВОЛОГОСТІ
    local moistureFactor = 1.0
    local rhmSpec = vehicle.spec_rhm_Combine
    if rhmSpec and rhmSpec.data and rhmSpec.data.moisture and rhmSpec.data.moisture > 0 then
        local currentMoisture = rhmSpec.data.moisture
        local moistureLimit = 14 -- Default general limit
        
        if RHM_CombineSettingsDatabase and self.currentCrop then
            local cropSettings = RHM_CombineSettingsDatabase:getSettingsForCrop(self.currentCrop)
            if cropSettings and cropSettings.moistureLimit then
                moistureLimit = cropSettings.moistureLimit
            end
        end
        
        local machineType = self.combineMemory and self.combineMemory.machineType or "grain"
        if machineType ~= "forage" and machineType ~= "root" then
            if currentMoisture > moistureLimit then
                local diff = currentMoisture - moistureLimit
                local penaltyPerPercent = 0.02 -- EN: 2% difficulty per 1% moisture over limit
                if rhmSpec.packageLevel and rhmSpec.packageLevel >= 4 then
                    penaltyPerPercent = 0.01 -- EN: Opti-Harvest reduces penalty by 50%
                end
                
                moistureFactor = 1.0 + (diff * penaltyPerPercent)
            end
        end
    end

    -- EN: Calculate RAW average mass intake per second / UA: Розраховуємо RAW середню масу за секунду (кг/с)
    -- EN: Uses accumulatedMass over the target distance/time / UA: Використовуємо accumulatedMass
    local safeTime = math.max(100, self.currentTime) -- Protect against division by zero
    local rawAvgMass = (self.loadAccumulatedMass or 0) * (1000 / safeTime) * cropFactor * moistureFactor
    
    -- ADAPTIVE SMOOTHING
    local loadRatio = self.currentAvgMass / math.max(0.01, self.basePerfMass)
    local smoothFactor = 0.3 + 0.4 * math.min(1.0, loadRatio)
    smoothFactor = math.min(0.7, smoothFactor)  -- Max 70% smoothing
    
    local avgMass = rawAvgMass
    if self.currentAvgMass > (0.5 * self.basePerfMass) then
        avgMass = (1 - smoothFactor) * rawAvgMass + smoothFactor * self.currentAvgMass
    end
    
    self.lastAvgMass = self.currentAvgMass
    self.currentAvgMass = avgMass
    self.rawAvgMass = rawAvgMass  
    
    -- EN: Fetch power boost for load calculation / UA: Отримуємо power boost для розрахунку навантаження
    local powerBoost = 0
    if g_realisticHarvestManager and g_realisticHarvestManager.settings then
        powerBoost = g_realisticHarvestManager.settings:getPowerBoost()
    end
    
    local maxAvgMass = (1 + 0.01 * powerBoost) * self.basePerfMass * (self.settingsEfficiency or 1.0)
    
    if maxAvgMass > 0 then
        self.engineLoad = self.currentAvgMass / maxAvgMass
    else
        self.engineLoad = 0
    end
end

---EN: Calculates Vehicle Speed Limit / UA: Розраховує обмеження швидкості
function RHM_LoadCalculator:calculateSpeedLimit(vehicle)
    if self.currentAvgMass == 0 then
        -- EN: If not harvesting, return to vanilla working speed / UA: Якщо не збираємо, повертаємось до ванільної робочої швидкості
        local target = self.genuineSpeedLimit > 0 and self.genuineSpeedLimit or 10.0
        if self.speedLimit > target then
            self.speedLimit = math.max(target, self.speedLimit - 0.5)
        elseif self.speedLimit < target then
            self.speedLimit = math.min(target, self.speedLimit + 0.5)
        end
        return
    end
    
    local powerBoost = 0
    local targetLoad = 0.95
    if self.combineMemory and self.combineMemory.currentSettings and self.combineMemory.currentSettings.targetEngineLoad then
        targetLoad = self.combineMemory.currentSettings.targetEngineLoad / 100.0
    end
    
    if g_realisticHarvestManager and g_realisticHarvestManager.settings then
        powerBoost = g_realisticHarvestManager.settings:getPowerBoost()
    end
    
    local maxAvgMass = (1 + 0.01 * powerBoost) * self.basePerfMass * (self.settingsEfficiency or 1.0)
    if maxAvgMass <= 0.01 then return end
    
    local loadRatio = self.currentAvgMass / maxAvgMass

    -- EN: Calculate error between target and current load
    -- UA: Розраховуємо різницю між цільовим і реальним навантаженням
    local difference = targetLoad - loadRatio
    
    -- EN: Deadzone of +/- 2% to prevent micro-oscillations and jitter around the target
    -- UA: Мертва зона +/- 2% щоб запобігти мікроколиванням навколо цілі
    if math.abs(difference) < 0.02 then
        difference = 0
    end
    
    -- EN: Proportional adjustment: hard brake on overload, smooth acceleration on underload
    -- UA: Пропорційне регулювання: швидке гальмування при перевантаженні, плавний розгін
    local step = difference * 1.5
    if difference < 0 then
        step = difference * 4.0 -- EN: Panic brake / UA: Екстренне скидання швидкості при забиванні
    end
    
    -- EN: Limit speed jump to avoid jittering
    -- UA: Обмежуємо максимальний стрибок швидкості за один тік, щоб уникнути ривків
    step = math.max(-2.5, math.min(0.8, step))
    
    self.speedLimit = self.speedLimit + step

    -- EN: Clamp speed within safe bounds
    -- UA: Обмеження швидкості: не менше 4 км/год і не більше оригінального ліміту гри.
    --     ВАЖЛИВО: `genuineSpeedLimit` може залишатися -1, якщо гравець/круїзконтроль
    --     не викликав `getSpeedLimit()` до моменту оновлення. Не допускаємо від’ємних лімітів.
    local genuine = self.genuineSpeedLimit
    if genuine and genuine > 0 then
        self.speedLimit = math.max(math.min(genuine, 4.0), math.min(genuine, self.speedLimit))
    else
        -- Upper bound unknown yet; at least prevent going negative / zero.
        self.speedLimit = math.max(self.speedLimit, 4.0)
    end
end

---EN: Returns current engine load factor / UA: Повертає поточне навантаження двигуна
function RHM_LoadCalculator:getEngineLoad()
    return self.engineLoad * 100
end

---EN: Returns calculated speed limit target / UA: Повертає остаточний ліміт швидкості
function RHM_LoadCalculator:getSpeedLimit()
    return self.speedLimit or 0
end

---EN: Caches base limit speed boundary / UA: Встановлює оригінальні межі ліміту
function RHM_LoadCalculator:setGenuineSpeedLimit(limit, maxCap)
    self.vanillaWorkingSpeed = limit
    self.genuineSpeedLimit = maxCap or limit
    self.speedLimit = limit
end

---EN: Fully resets accumulated internal data variables / UA: Повністю очищує змінні бази даних
function RHM_LoadCalculator:reset()
    self.totalDistance = 0
    self.totalArea = 0
    self.currentTime = 0
    self.currentAvgMass = 0
    self.engineLoad = 0
    self.cropLoss = 0
    self.speedLimit = self.vanillaWorkingSpeed or (self.genuineSpeedLimit > 0 and self.genuineSpeedLimit or 15)
    self.productivityMass = 0
    self.productivityLiters = 0
    self.productivityTime = 0
    self.tonPerHour = 0
    self.litersPerHour = 0
    self.hectaresPerHour = 0
    
    self.prodBuffer = {}
    self.prodStartIndex = 1
    self.prodEndIndex = 0
    self.currentBufferTime = 0
    
    self.yieldBuffer = {}
    self.yieldStartIndex = 1
    self.yieldEndIndex = 0
    
    self.currentYield = 0
    self.instantYield = 0
end

---EN: Calculates engine load based crop losses / UA: Розраховує втрати врожаю від перевантаження
function RHM_LoadCalculator:calculateCropLoss()
    if not g_realisticHarvestManager or not g_realisticHarvestManager.settings then return 0 end
    if not g_realisticHarvestManager.settings.enableCropLoss then return 0 end
    
    local lossMultiplier = g_realisticHarvestManager.settings:getLossMultiplier()
    
    -- EN: Losses start smoothly from 80% engine load
    -- UA: Втрати починаються плавно з 80% завантаження
    if self.engineLoad > 0.80 then
        local overload = self.engineLoad - 0.80
        -- UA: Прогресивна крива (експонента): 
        -- При 80% (overload=0) -> 0% втрат
        -- При 90% (overload=0.1) -> 0.5% (мізерні втрати)
        -- При 100% (overload=0.2) -> 2.0% (допустимі втрати)
        -- При 110% (overload=0.3) -> 4.5% (пік продуктивності)
        -- При 130% (overload=0.5) -> 12.5% (величезні втрати)
        local rawLoss = (overload * overload) * 50
        
        -- UA: Різке зростання, якщо завантаження перевищило 110% (забита молотарка)
        if self.engineLoad > 1.10 then
            rawLoss = rawLoss + ((self.engineLoad - 1.10) * 100)
        end
        
        self.cropLoss = math.min(rawLoss * lossMultiplier, 50) 
    else
        self.cropLoss = 0
    end
    return self.cropLoss
end

---EN: Calculates losses from inaccurate player threshing settings / UA: Розраховує втрати від неправильних налаштувань гравцем
function RHM_LoadCalculator:updateSettingsImpact()
    self.settingsEfficiency = 1.0
    self.settingsLoss = 0
    if self.combineMemory and self.combineMemory.currentCrop then
        self.currentCrop = self.combineMemory.currentCrop
    end
    if not self.combineMemory or not self.currentCrop then return end
    local effPenalty, lossPenalty, _ = self.combineMemory:checkSettingsForCrop(self.currentCrop)
    
    if effPenalty < 0 then
        self.settingsEfficiency = 1.0 + (math.abs(effPenalty) * 5.0 / 100.0)
    else
        self.settingsEfficiency = 1.0 - (effPenalty / 100.0)
    end
    
    -- EN: Forage harvesters (silage choppers) produce no grain losses — all crop goes to tank/trailer.
    -- UA: Силосні комбайни не мають втрат зерна — весь врожай йде в бак/причеп.
    local machineType = self.combineMemory.machineType
    if machineType == "forage" then
        self.settingsLoss = 0
    elseif lossPenalty < 0 then
        self.settingsLoss = 0 
    else
        self.settingsLoss = lossPenalty
    end
end

function RHM_LoadCalculator:calculateTotalCropLoss()
    -- EN: Forage and Cotton harvesters never have crop loss — bypass all calculations.
    -- UA: Силосні та бавовняні комбайни ніколи не мають втрат врожаю — пропускаємо всі розрахунки.
    if self.combineMemory and (self.combineMemory.machineType == "forage" or self.combineMemory.machineType == "cotton") then
        self.cropLoss = 0
        return 0
    end
    if self.combineMemory and self.combineMemory.currentCrop then
        self.currentCrop = self.combineMemory.currentCrop
    end
    self:updateSettingsImpact()
    local baseLoss = self:calculateCropLoss()
    local settingsAddedLoss = self.settingsLoss or 0
    local totalLoss = baseLoss + settingsAddedLoss
    totalLoss = math.min(totalLoss, 50)
    self.cropLoss = totalLoss
    return totalLoss
end

---EN: Returns instantaneous processed metric tonnes per clock hour / UA: Перерахунок в тонни на годину
function RHM_LoadCalculator:getTonPerHour()
    return self.tonPerHour
end

---EN: Returns yield in L/h / UA: Розрахунок літрів на годину
function RHM_LoadCalculator:getLitersPerHour()
    return self.litersPerHour or 0
end

---EN: Returns calculated area rate in hectares per hour / UA: Повертає продуктивність у гектарах на годину
function RHM_LoadCalculator:getHectaresPerHour()
    return self.hectaresPerHour or 0
end

---EN: Updates sliding window rolling averages for metric evaluations / UA: Оновлює ковзні середні продуктивності
function RHM_LoadCalculator:updateProductivity(mass, liters, dt, area)
    self.totalOutputMass = self.totalOutputMass + mass
    
    self.prodBuffer = self.prodBuffer or {}
    self.prodStartIndex = self.prodStartIndex or 1
    self.prodEndIndex = self.prodEndIndex or 0
    
    self.prodEndIndex = self.prodEndIndex + 1
    self.prodBuffer[self.prodEndIndex] = {m = mass, l = liters or 0, t = dt, a = area or 0}
    
    self.currentBufferTime = (self.currentBufferTime or 0) + dt
    while (self.prodEndIndex - self.prodStartIndex + 1) > 1 and self.currentBufferTime > 12000 do
        local old = self.prodBuffer[self.prodStartIndex]
        self.currentBufferTime = self.currentBufferTime - old.t
        self.prodBuffer[self.prodStartIndex] = nil -- free memory
        self.prodStartIndex = self.prodStartIndex + 1
    end
    
    local sumMass = 0
    local sumLiters = 0
    local sumTime = 0
    local sumArea = 0
    for i = self.prodStartIndex, self.prodEndIndex do
        local v = self.prodBuffer[i]
        sumMass = sumMass + v.m
        sumLiters = sumLiters + v.l
        sumTime = sumTime + v.t
        sumArea = sumArea + (v.a or 0)
    end
    
    if sumTime > 100 then
        local hours = sumTime / 3600000
        local rawTonPerHour = (sumMass / 1000) / hours
        self.litersPerHour = sumLiters / hours
        local rawHectaresPerHour = (sumArea / 10000) / hours
        local alpha = 0.05
        if self.tonPerHour == 0 then self.tonPerHour = rawTonPerHour end
        self.tonPerHour = self.tonPerHour * (1 - alpha) + rawTonPerHour * alpha

        if self.hectaresPerHour == 0 then self.hectaresPerHour = rawHectaresPerHour end
        self.hectaresPerHour = self.hectaresPerHour * (1 - alpha) + rawHectaresPerHour * alpha
    else
        self.tonPerHour = 0
        self.litersPerHour = 0
        self.hectaresPerHour = 0
    end
end

---EN: Processes complete physical output block calculations / UA: Виконує розрахунки врожайності
function RHM_LoadCalculator:updateProductivityAndYield(mass, liters, area, dt)
    self:updateProductivity(mass, liters, dt, area)
    if area <= 0.0001 and mass <= 0.001 then
        self.currentYield = self.currentYield or 0
        return
    end
    
    self.yieldBuffer = self.yieldBuffer or {}
    self.yieldStartIndex = self.yieldStartIndex or 1
    self.yieldEndIndex = self.yieldEndIndex or 0
    
    self.yieldEndIndex = self.yieldEndIndex + 1
    self.yieldBuffer[self.yieldEndIndex] = {m = mass, a = area}
    
    if (self.yieldEndIndex - self.yieldStartIndex + 1) > 600 then 
        self.yieldBuffer[self.yieldStartIndex] = nil
        self.yieldStartIndex = self.yieldStartIndex + 1
    end
    
    local sumMass = 0
    local sumArea = 0
    for i = self.yieldStartIndex, self.yieldEndIndex do 
        local v = self.yieldBuffer[i]
        sumMass = sumMass + v.m
        sumArea = sumArea + v.a 
    end
    
    if sumArea > 0.1 then
        local rawYield = (sumMass / sumArea) * 10
        local alpha = 0.03
        if not self.currentYield or self.currentYield == 0 then self.currentYield = rawYield end
        self.currentYield = self.currentYield * (1 - alpha) + rawYield * alpha
    end
end

function RHM_LoadCalculator:setRealTimeYield(yieldTha)
    self.yieldBuffer = self.yieldBuffer or {}
    self.yieldStartIndex = self.yieldStartIndex or 1
    self.yieldEndIndex = self.yieldEndIndex or 0
    
    self.yieldEndIndex = self.yieldEndIndex + 1
    self.yieldBuffer[self.yieldEndIndex] = yieldTha
    
    if (self.yieldEndIndex - self.yieldStartIndex + 1) > 20 then 
        self.yieldBuffer[self.yieldStartIndex] = nil
        self.yieldStartIndex = self.yieldStartIndex + 1
    end
    
    local sum = 0
    local count = self.yieldEndIndex - self.yieldStartIndex + 1
    for i = self.yieldStartIndex, self.yieldEndIndex do 
        sum = sum + self.yieldBuffer[i] 
    end
    self.currentYield = sum / count
end

---EN: Returns formatted yield string / UA: Отримує форматований рядок врожайності
function RHM_LoadCalculator:getYieldText(unitSystem)
    local yield = self.currentYield or 0
    if yield < 0.1 then return "0.0", "t/ha" end
    
    if unitSystem == 2 then 
        return string.format("%.2f", yield * 0.446), "t/ac"
    elseif unitSystem == 3 then 
        return string.format("%.0f", yield * 15), "bu/ac"
    else 
        return string.format("%.1f", yield), "t/ha"
    end
end


