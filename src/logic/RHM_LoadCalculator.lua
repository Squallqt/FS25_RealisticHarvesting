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

---EN: Resolves engine horsepower (HP) from vehicle motorized spec, configuration, or carrier tractor (NEXAT/towed).
---UA: Визначає потужність двигуна (к.с.) зі специфікації, конфігурації техніки або тягового трактора (NEXAT/причіпні).
function RHM_LoadCalculator:getEnginePowerHp(vehicle)
    if not vehicle then return 400 end

    -- 1. Check motorized spec on vehicle or root/attacher carrier (for trailed harvesters, tractor setups, or NEXAT)
    local motorObj = vehicle
    if not (vehicle.spec_motorized and vehicle.spec_motorized.motor) then
        local root = vehicle.rootVehicle or (vehicle.getRootVehicle and vehicle:getRootVehicle())
        if root and root.spec_motorized and root.spec_motorized.motor then
            motorObj = root
        else
            local attacher = vehicle.attacherVehicle or (vehicle.getAttacherVehicle and vehicle:getAttacherVehicle())
            if attacher and attacher.spec_motorized and attacher.spec_motorized.motor then
                motorObj = attacher
            end
        end
    end

    if motorObj.spec_motorized and motorObj.spec_motorized.motor and motorObj.spec_motorized.motor.hp then
        local hp = tonumber(motorObj.spec_motorized.motor.hp)
        if hp and hp > 0 then return hp end
    end

    -- 2. Check motor configuration if motor.hp is not yet loaded
    if motorObj.configurations and motorObj.configurations.motor and motorObj.xmlFile then
        local key, _ = ConfigurationUtil.getXMLConfigurationKey(
            motorObj.xmlFile, 
            motorObj.configurations.motor, 
            "vehicle.motorized.motorConfigurations.motorConfiguration", 
            "vehicle.motorized", 
            "motor"
        )
        if key then
            local hp = motorObj.xmlFile:getValue(key .. "#hp")
            if hp and tonumber(hp) > 0 then return tonumber(hp) end
        end
    end

    -- 3. Check basePerfMass back-calculation if cached
    if self.basePerfMass and self.basePerfMass > 0 then
        return math.max(150, self.basePerfMass * 3.6 * 5.2)
    end

    return 400
end

---EN: Resolves attached cutter power requirements (HP) and properties dynamically from FS25 XML/specs.
---    Seamlessly supports standard combines, NEXAT modular systems, self-propelled harvesters with integrated
---    cutters (e.g. potato/carrot/cotton), and multi-implement tractor trains (front topper + rear harvester).
---UA: Динамічно визначає вимоги жатки до потужності (к.с.) та її властивості з XML/специфікацій FS25.
---    Повністю підтримує стандартні комбайни, модульні системи NEXAT, самохідні комбайни з вбудованими жатками
---    (картопля/морква/бавовна) та зв'язки знарядь на тракторі (передній гичкозрізувач + задній комбайн).
function RHM_LoadCalculator:getAttachedHeaderInfo(vehicle)
    local headerHp = 0
    local maxWorkingSpeed = nil
    local isCutterActive = false
    local isPickup = false
    local isForageCutter = false
    local cutterCount = 0

    if not vehicle then
        return headerHp, 10.0, isCutterActive, isPickup, isForageCutter, cutterCount
    end

    -- Find the motorized carrier / tractor if vehicle is attached (e.g. NEXAT, tractor with front/rear implements)
    local motorCarrier = nil
    if vehicle.spec_motorized and vehicle.spec_motorized.motor then
        motorCarrier = vehicle
    else
        local root = vehicle.rootVehicle or (vehicle.getRootVehicle and vehicle:getRootVehicle())
        if root and root.spec_motorized and root.spec_motorized.motor then
            motorCarrier = root
        else
            local attacher = vehicle.attacherVehicle or (vehicle.getAttacherVehicle and vehicle:getAttacherVehicle())
            if attacher and attacher.spec_motorized and attacher.spec_motorized.motor then
                motorCarrier = attacher
            end
        end
    end

    -- Collect all objects in the harvesting train:
    -- 1. The vehicle itself (supports self-propelled harvesters with integrated cutters)
    -- 2. Direct implements of vehicle
    -- 3. Implements of the motor carrier/tractor (discovers front haulm toppers, rear lifters, NEXAT modules)
    local objectsToScan = {}
    local scanned = {}

    local function addObj(obj)
        if obj and not scanned[obj] then
            scanned[obj] = true
            table.insert(objectsToScan, obj)
        end
    end

    addObj(vehicle)

    if vehicle.getAttachedImplements then
        for _, implement in pairs(vehicle:getAttachedImplements()) do
            addObj(implement.object)
        end
    end

    if motorCarrier and motorCarrier ~= vehicle then
        addObj(motorCarrier)
        if motorCarrier.getAttachedImplements then
            for _, implement in pairs(motorCarrier:getAttachedImplements()) do
                addObj(implement.object)
            end
        end
    end

    -- Traverse collected equipment
    for _, obj in ipairs(objectsToScan) do
        local isCutter = (obj.spec_cutter ~= nil or obj.spec_forageHarvesterCutter ~= nil 
                       or obj.spec_forageCutter ~= nil or obj.spec_pickup ~= nil)

        -- In trailed setups (e.g. Grimme Rootster on a tractor), the harvester implement itself consumes PTO power
        local isTrailedHarvester = (obj ~= motorCarrier and obj.spec_combine ~= nil)

        if isCutter or isTrailedHarvester then
            cutterCount = cutterCount + 1

            -- Check active state
            if obj.getIsTurnedOn and obj:getIsTurnedOn() then
                isCutterActive = true
            elseif vehicle.getIsTurnedOn and vehicle:getIsTurnedOn() then
                isCutterActive = true
            elseif vehicle.spec_combine and vehicle.spec_combine.isThreshing then
                isCutterActive = true
            end

            if obj.spec_forageHarvesterCutter ~= nil or obj.spec_forageCutter ~= nil then
                isForageCutter = true
            end
            if obj.spec_pickup ~= nil then
                isPickup = true
            end

            -- Working speed limit of the header/tool
            -- CRITICAL FIX: NEVER call obj:getSpeedLimit(true) on the vehicle itself,
            -- because vehicle:getSpeedLimit is hooked by RHM and returns our own dynamic speedLimit (locking it to 5 km/h)!
            local limit = nil
            if obj ~= vehicle then
                if obj.spec_cutter and obj.spec_cutter.maxWorkingSpeed then
                    limit = obj.spec_cutter.maxWorkingSpeed
                elseif obj.speedLimit and obj.speedLimit > 0 and obj.speedLimit < 50 then
                    limit = obj.speedLimit
                elseif obj.getSpeedLimit then
                    limit = obj:getSpeedLimit(true)
                end
            else
                -- For self-propelled machines with integrated/built-in cutters (obj == vehicle):
                -- Use the genuine vanilla working speed captured before RHM limiting,
                -- or read directly from spec_cutter.maxWorkingSpeed or obj.speedLimit.
                if self.vanillaWorkingSpeed and self.vanillaWorkingSpeed > 0 then
                    limit = self.vanillaWorkingSpeed
                elseif self.genuineSpeedLimit and self.genuineSpeedLimit > 0 then
                    limit = self.genuineSpeedLimit
                elseif obj.spec_cutter and obj.spec_cutter.maxWorkingSpeed then
                    limit = obj.spec_cutter.maxWorkingSpeed
                elseif obj.speedLimit and obj.speedLimit > 0 and obj.speedLimit < 50 then
                    limit = obj.speedLimit
                end
            end

            if limit and limit > 0 and limit < 50 then
                if maxWorkingSpeed == nil then
                    maxWorkingSpeed = limit
                else
                    maxWorkingSpeed = math.min(maxWorkingSpeed, limit)
                end
            end

            -- Power consumption of the tool (HP)
            local ptoHp = 0
            if obj ~= motorCarrier then
                -- A: Check spec_powerConsumer
                if obj.spec_powerConsumer then
                    local pc = obj.spec_powerConsumer
                    local kw = pc.neededPtoPower or pc.neededMaxPtoPower or pc.neededMinPtoPower or pc.neededPower or 0
                    if kw and kw > 0 then
                        ptoHp = kw * 1.35962 -- kW to HP
                    end
                end
                -- B: Check getNeededPtoPower / getNeededPower methods
                if ptoHp == 0 then
                    if obj.getNeededPtoPower then
                        local kw = obj:getNeededPtoPower()
                        if kw and kw > 0 then ptoHp = kw * 1.35962 end
                    end
                end
                if ptoHp == 0 and obj.getNeededPower then
                    local kw = obj:getNeededPower()
                    if kw and kw > 0 then ptoHp = kw * 1.35962 end
                end
                -- C: Store item XML specs fallback
                if ptoHp == 0 and obj.configFileName and g_storeManager and g_storeManager.getItemByXMLFilename then
                    local item = g_storeManager:getItemByXMLFilename(obj.configFileName)
                    if item and item.specs and item.specs.neededPower then
                        ptoHp = tonumber(item.specs.neededPower) or 0
                    end
                end
            end

            -- D: Physical fallback based on working width
            if ptoHp == 0 then
                local width = 6.0
                if obj.spec_cutter and obj.spec_cutter.workingWidth then
                    width = obj.spec_cutter.workingWidth
                end
                if isForageCutter then
                    ptoHp = width * 85.0 -- ~85 HP/m for rotary forage cutter
                elseif obj.spec_cutter ~= nil then
                    ptoHp = width * 12.0 -- ~12 HP/m for grain cutter
                elseif isTrailedHarvester then
                    ptoHp = 120.0 -- Trailed root/grain harvester baseline
                end
            end

            headerHp = headerHp + ptoHp
        end
    end

    -- If self-propelled machine with built-in cutter and no separate PTO consumer was registered:
    if headerHp == 0 and vehicle == motorCarrier and vehicle.spec_cutter ~= nil then
        local width = (vehicle.spec_cutter and vehicle.spec_cutter.workingWidth) or 3.0
        local cropUpper = (self.currentCrop and string.upper(self.currentCrop)) or ""
        local isStripper = (cropUpper:find("BEAN") or cropUpper:find("PEA") or cropUpper:find("SPINACH"))
        local hpPerMeter = isStripper and 38.0 or 25.0
        headerHp = width * hpPerMeter
    end

    maxWorkingSpeed = maxWorkingSpeed or self.vanillaWorkingSpeed or (self.genuineSpeedLimit > 0 and self.genuineSpeedLimit) or 10.0
    return headerHp, maxWorkingSpeed, isCutterActive, isPickup, isForageCutter, cutterCount
end

---EN: Dynamically calculates the physical specific processing energy (HP per t/h) based on FS25 crop traits.
---UA: Динамічно розраховує питому енергію обмолоту/подрібнення (к.с. на т/год) на основі властивостей культури з FS25.
function RHM_LoadCalculator:getCropSpecificEnergy(fruitTypeIndex, fillTypeIndex, machineType, isPickup, isForageCutter)
    machineType = machineType or "grain"

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

    -- Bulk density (kg/L)
    local density = 0.75
    if fillTypeDesc and fillTypeDesc.massPerLiter and fillTypeDesc.massPerLiter > 0 then
        density = fillTypeDesc.massPerLiter * 1000
    end

    -- Does this crop generate straw/windrows in the thresher?
    local hasStraw = false
    if fruitTypeDesc and fruitTypeDesc.hasWindrow ~= nil then
        hasStraw = fruitTypeDesc.hasWindrow
    else
        hasStraw = (cropName == "WHEAT" or cropName == "BARLEY" or cropName == "OAT" or cropName == "OATS"
                 or cropName == "RYE" or cropName == "SPELT" or cropName == "TRITICALE" or cropName:find("RICE"))
    end

    -- 1. FORAGE HARVESTERS (Chopping whole plant: corn silage, grass, poplar, etc.)
    if machineType == "forage" or isForageCutter then
        if cropName:find("POPLAR") or cropName:find("WOOD") then
            return 6.5 -- Poplar wood chipping: heavy wood cutting drum resistance
        elseif cropName:find("MAIZE") or cropName:find("CORN") or cropName:find("SILAGE") or cropName:find("CHAFF") or cropName:find("GPS") then
            return 2.1 -- Whole corn silage: ~2.1 HP per t/h
        elseif cropName:find("GRASS") or cropName:find("MEADOW") or cropName:find("ALFALFA") or cropName:find("LUCERNE") or cropName:find("CLOVER") then
            if isPickup then
                return 1.8 -- Swath pickup: ~1.8 HP per t/h
            else
                return 2.6 -- Direct-cut standing grass (tough elastic fibers): ~2.6 HP per t/h
            end
        elseif cropName:find("STRAW") or cropName:find("HAY") or cropName:find("DRYGRASS") then
            return 1.8 -- Dry windrow pickup: ~1.8 HP per t/h
        else
            return isPickup and 1.8 or 2.2 -- Universal forage fallback
        end

    -- 2. ROOT & SPECIALIZED VEGETABLE HARVESTERS (Lifting, cleaning, pod stripping)
    elseif machineType == "root" then
        if cropName:find("SPINACH") then
            -- Spinach: dense leafy green carpet, high moisture, large biomass
            return 6.0 -- ~6.0 HP per t/h
        elseif (cropName:find("GREEN") and (cropName:find("BEAN") or cropName:find("PEA")))
               or cropName:find("GREENBEANS") or cropName:find("GREENBEAN") then
            -- Fresh green beans / pod peas: very low bunker yield (~4.2 t/ha), stripper reel
            -- chews through massive green bushes (~40-50 t/ha) to extract the pods!
            return 12.5 -- ~12.5 HP per t/h
        elseif cropName:find("PEA") or cropName:find("BEAN") or cropName:find("LENTIL") or cropName:find("LUPIN") then
            -- Specialized vegetable peas / beans / lupins
            return 8.5 -- ~8.5 HP per t/h
        elseif cropName:find("POTATO") then
            -- Potatoes: scooping whole soil ridges, sifting hundreds of tons of dirt/clods, front haulm topper
            return 1.85 -- ~1.85 HP per t/h
        elseif cropName:find("CARROT") or cropName:find("PARSNIP") or cropName:find("RUTABAGA") or cropName:find("TURNIP") then
            -- Deep taproots (20-25 cm): tight soil grip, pulling belts, top-chopping knives
            return 1.35 -- ~1.35 HP per t/h
        elseif cropName:find("BEETROOT") or cropName:find("RED BEET") or cropName:find("REDBEET") then
            -- Red table beet: firm root, rubber pulling belts
            return 1.25 -- ~1.25 HP per t/h
        elseif cropName:find("SUGARBEET") or cropName:find("BEET") then
            -- Sugar beets: round shape, lifted by squeeze wheels, smooth turbine webs
            return 1.00 -- ~1.00 HP per t/h
        elseif cropName:find("ONION") or cropName:find("GARLIC") then
            -- Onions / Garlic: shallow lifting, gentle sorting webs
            return 0.95 -- ~0.95 HP per t/h
        else
            return 1.35 -- Universal modded root fallback
        end

    -- 3. COTTON HARVESTERS (Fluffy, low density lint picking & baling)
    elseif machineType == "cotton" or cropName:find("COTTON") then
        return 12.0 -- Spindle picking + round/square bale chamber hydraulic compaction

    -- 4. SUGARCANE HARVESTERS
    elseif cropName:find("SUGARCANE") or cropName:find("CANE") then
        return 2.2 -- Base chopping, billet chopper cylinder, extractor fans (high tonnage: 80-120 t/ha)

    -- 5. GRAPES & OLIVES (Specialized straddle harvesters)
    elseif cropName:find("GRAPE") or cropName:find("OLIVE") then
        return 3.5 -- Shaker rods, bucket elevators, cleaning blowers

    -- 6. GRAIN COMBINE HARVESTERS (Grain tank stream processing)
    else
        if isPickup then
            return 3.0
        elseif hasStraw then
            -- Cereals with straw (Wheat, Barley, Oat, Rye, Triticale, Spelt, Rice): thresher + straw chopper
            if cropName:find("RICE") then
                return 5.8 -- Wet silicon-rich rice straw (higher cutting resistance)
            else
                return 5.2 -- Standard straw cereals
            end
        elseif cropName:find("CORN") or cropName:find("MAIZE") then
            -- Corn for grain: only cobs enter the combine (stalks chopped on header)
            return 2.8
        elseif cropName:find("SORGHUM") then
            -- Sorghum: thick fibrous stalks, hard seed heads
            return 5.2
        elseif cropName:find("CANOLA") or cropName:find("OILSEED") or cropName:find("FLAX") or cropName:find("LINSEED") or cropName:find("MUSTARD") or cropName:find("POPPY") or cropName:find("RADISH") then
            -- Oilseeds & Oilseed Radish: low seed yield (~3.5 t/ha) with massive tough stalk volume
            return 9.5
        elseif cropName:find("SUNFLOWER") then
            return 6.2
        elseif cropName:find("SOYBEAN") or cropName:find("PEA") or cropName:find("LENTIL") or cropName:find("CHICKPEA") or cropName:find("BEAN") then
            if cropName:find("GREEN") then
                return 12.5 -- Fresh green beans / pods
            else
                return 5.8 -- Dry grain pulses
            end
        else
            -- Universal dynamic fallback for unknown / modded crops based on physical properties
            if density < 0.50 then
                return 8.5 -- Light seeds with heavy biomass
            else
                return 4.5 -- Dense grain
            end
        end
    end
end

---EN: Backward compatibility stub for getCropFactor.
---UA: Заглушка зворотної сумісності для getCropFactor.
function RHM_LoadCalculator:getCropFactor(fruitTypeIndex, fillTypeIndex, machineType, isPickup, isForageCutter)
    return 1.0
end

---EN: Sets base performance mass / UA: Встановлює базову продуктивність (маса)
function RHM_LoadCalculator:setBasePerformance(basePerfMass)
    self.basePerfMass = basePerfMass
    
    rhm_log(string.format("RHM [RHM_LoadCalculator]: RHM: Base performance set to %.2f kg/s (%.1f t/h)", 
        self.basePerfMass, self.basePerfMass * 3.6))
end

---EN: Calculates nominal base throughput capacity (kg/s) based on engine horsepower and machine type.
---UA: Розраховує номінальну базову пропускну здатність (кг/с) на основі потужності двигуна та типу машини.
function RHM_LoadCalculator:getBasePerformanceFromPower(vehicle)
    local hp = self:getEnginePowerHp(vehicle)
    local keyCategory = "vehicle.storeData.category"
    local category = vehicle.xmlFile and vehicle.xmlFile:getValue(keyCategory) or ""
    local isForage = (category == "forageHarvesters" or category == "forageHarvesterCutters")
    local isRoot = (category == "beetVehicles" or category == "beetHarvesting" or category == "potatoVehicles" or category == "vegetableVehicles")

    -- Nominal throughput at 100% processing load (t/h)
    local nominalTph = 0
    if isForage then
        nominalTph = hp / 2.1 -- ~2.1 HP per t/h
    elseif isRoot then
        nominalTph = hp / 0.75 -- ~0.75 HP per t/h
    else
        nominalTph = hp / 5.2 -- ~5.2 HP per t/h for grain
    end

    local nominalKgPerSec = (nominalTph * 1000) / 3600
    rhm_log(string.format("RHM [RHM_LoadCalculator]: Nominal base capacity for %s (%d HP): %.1f t/h (%.2f kg/s)", 
        vehicle:getFullName(), hp, nominalTph, nominalKgPerSec))
    return nominalKgPerSec
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

---EN: Calculates Engine Load using the physical power-balance model: P_total = P_base + P_header(v) + P_process.
---UA: Розраховує навантаження на двигун за фізичною моделлю балансу потужностей: P_total = P_base + P_header(v) + P_process.
function RHM_LoadCalculator:calculateEngineLoad(vehicle)
    if self.currentTime <= 0 then
        return
    end
    
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

    -- 1. HEADER INFO & POWER CONSUMPTION (PTO)
    local headerHp, maxWorkingSpeed, isCutterActive, isPickup, isForageCutter, cutterCount = self:getAttachedHeaderInfo(vehicle)
    self.headerHp = headerHp
    self.maxWorkingSpeed = maxWorkingSpeed
    self.isCutterActive = isCutterActive
    self.isPickup = isPickup
    self.isForageCutter = isForageCutter

    -- Resolve fruit type and fill type for processing energy lookup
    local inputFruitType = spec_combine.lastValidInputFruitType or 0
    local outputFillType = (rhmSpec and rhmSpec.lastFillType) or 0

    -- Fallback pickup detection: WINDROW or fruitType 0
    if not isPickup then
        local fruitTypeDesc = g_fruitTypeManager and g_fruitTypeManager:getFruitTypeByIndex(inputFruitType)
        local fruitName = (fruitTypeDesc and fruitTypeDesc.name and string.upper(fruitTypeDesc.name)) or ""
        if fruitName:find("WINDROW") or inputFruitType == 0 then
            isPickup = true
            self.isPickup = true
        end
    end

    -- 2. SPECIFIC PROCESSING ENERGY (HP per t/h)
    local eSpec = self:getCropSpecificEnergy(inputFruitType, outputFillType, machineType, isPickup, isForageCutter)
    self.lastSpecificEnergy = eSpec

    if self.lastCropType ~= inputFruitType then
        self.lastCropType = inputFruitType
        local mode = isPickup and "PICKUP" or (isForageCutter and "FORAGE_CUTTER" or "DIRECT_CUT")
        rhm_log(string.format("RHM [RHM_LoadCalculator]: RHM: [INPUT] %s (Fruit: %d, Fill: %d, E_spec: %.2f HP/(t/h), Header: %.1f HP)", 
            mode, inputFruitType, outputFillType, eSpec, headerHp))
    end

    -- 3. MOISTURE FACTOR
    local moistureFactor = 1.0
    if rhmSpec and rhmSpec.data and rhmSpec.data.moisture and rhmSpec.data.moisture > 0 then
        local currentMoisture = rhmSpec.data.moisture
        local moistureLimit = 14 -- Default general limit
        
        if RHM_CombineSettingsDatabase and self.currentCrop then
            local cropSettings = RHM_CombineSettingsDatabase:getSettingsForCrop(self.currentCrop)
            if cropSettings and cropSettings.moistureLimit then
                moistureLimit = cropSettings.moistureLimit
            end
        end
        
        if machineType ~= "forage" and machineType ~= "root" then
            if currentMoisture > moistureLimit then
                local diff = currentMoisture - moistureLimit
                local penaltyPerPercent = 0.02 -- 2% difficulty per 1% moisture over limit
                if rhmSpec.packageLevel and rhmSpec.packageLevel >= 4 then
                    penaltyPerPercent = 0.01 -- Opti-Harvest reduces penalty by 50%
                end
                moistureFactor = 1.0 + (diff * penaltyPerPercent)
            end
        end
    end

    -- 4. RAW THROUGHPUT RATE (kg/s and t/h)
    local safeTime = math.max(100, self.currentTime)
    local rawKgPerSec = (self.loadAccumulatedMass or 0) * (1000 / safeTime)
    local rawTph = rawKgPerSec * 3.6

    -- Adaptive smoothing for mass flow
    local smoothFactor = 0.40
    local avgMass = rawKgPerSec
    if self.currentAvgMass > 0 then
        avgMass = (1 - smoothFactor) * rawKgPerSec + smoothFactor * self.currentAvgMass
    end
    self.lastAvgMass = self.currentAvgMass
    self.currentAvgMass = avgMass
    self.rawAvgMass = rawKgPerSec

    local avgTph = avgMass * 3.6

    -- 5. AVAILABLE ENGINE HORSEPOWER
    local engineHp = self:getEnginePowerHp(vehicle)
    local powerBoost = 0
    if g_realisticHarvestManager and g_realisticHarvestManager.settings then
        powerBoost = g_realisticHarvestManager.settings:getPowerBoost()
    end
    local effectiveEngineHp = engineHp * (1 + 0.01 * powerBoost)

    -- 6. POWER BREAKDOWN (P_base, P_header, P_process, P_soil)
    local pBase = 0
    local pHeader = 0
    local pProcess = 0
    local pSoil = 0

    local isActivelyHarvesting = (avgTph > 0.05) or (rawTph > 0.05)

    if isCutterActive or isActivelyHarvesting then
        -- Base mechanical & driveline losses:
        -- Normal grain / forage combines: ~10% (calibrated with empirical ASABE field standards)
        -- Heavy hydrostatic root harvesters (Dewulf, Grimme, Ropa, Holmer): ~20%
        if machineType == "root" then
            pBase = effectiveEngineHp * 0.20
        else
            pBase = effectiveEngineHp * 0.10
        end

        -- Header power consumption (scales with ground speed)
        if headerHp > 0 then
            local speedKmh = (vehicle.getLastSpeed and vehicle:getLastSpeed()) or 0
            local speedRatio = math.min(1.2, math.max(0.0, speedKmh / math.max(1.0, maxWorkingSpeed)))
            pHeader = headerHp * (0.20 + 0.80 * speedRatio)
        end
    end

    if isActivelyHarvesting then
        -- Crop processing power: Threshing/chopping/cleaning scaled by settings efficiency
        local eff = math.max(0.25, self.settingsEfficiency or 1.0)
        pProcess = (avgTph * eSpec * moistureFactor) / eff

        -- Root harvesters: subsurface share soil cutting resistance (ножі-лемеші під землею)
        -- Only for subterranean root crops (carrots, parsnips, potatoes, sugar beets, onions).
        -- Surface vegetables (green beans, peas, spinach) do not cut underground!
        local cropUpper = (self.currentCrop and string.upper(self.currentCrop)) or ""
        local isSurfaceCrop = (cropUpper:find("BEAN") or cropUpper:find("PEA") or cropUpper:find("SPINACH"))
        if machineType == "root" and not isSurfaceCrop then
            local width = 3.0
            if vehicle.spec_cutter and vehicle.spec_cutter.workingWidth then
                width = vehicle.spec_cutter.workingWidth
            elseif vehicle.spec_combine and vehicle.spec_combine.attachedCutters then
                for cutter, _ in pairs(vehicle.spec_combine.attachedCutters) do
                    if cutter.spec_cutter and cutter.spec_cutter.workingWidth then
                        width = cutter.spec_cutter.workingWidth
                        break
                    end
                end
            end
            pSoil = width * 20.0 -- ~20 HP per meter of cutting width in soil
        end
    end

    local pTotal = 0
    if isActivelyHarvesting then
        pTotal = pBase + pHeader + pProcess + pSoil
    elseif isCutterActive then
        -- Running empty (cutter spinning, no crop intake)
        pTotal = pBase + (pHeader * 0.25)
    else
        pTotal = 0
    end

    -- 7. RESULTING ENGINE LOAD
    local loadRatio = pTotal / math.max(1.0, effectiveEngineHp)

    -- Smooth engineLoad transitions
    if self.engineLoad == 0 or (not isActivelyHarvesting and not isCutterActive) then
        self.engineLoad = loadRatio
    else
        local loadSmoothing = 0.35
        self.engineLoad = (1 - loadSmoothing) * loadRatio + loadSmoothing * self.engineLoad
    end

    -- Store diagnostic telemetry
    self.lastPowerEngine = effectiveEngineHp
    self.lastPowerBase = pBase
    self.lastPowerHeader = pHeader
    self.lastPowerProcess = pProcess
    self.lastPowerSoil = pSoil
    self.lastPowerTotal = pTotal
    self.lastEffectiveHp = effectiveEngineHp
end

---EN: Calculates Vehicle Speed Limit based on physical power load and target load.
---UA: Розраховує обмеження швидкості на основі навантаження двигуна та цільового навантаження.
function RHM_LoadCalculator:calculateSpeedLimit(vehicle)
    local headerHp, maxWorkingSpeed = self:getAttachedHeaderInfo(vehicle)
    local maxAllowedSpeed = self.genuineSpeedLimit
    if maxAllowedSpeed and maxAllowedSpeed > 0 then
        maxAllowedSpeed = math.min(maxAllowedSpeed, maxWorkingSpeed)
    else
        maxAllowedSpeed = maxWorkingSpeed
    end

    -- If not harvesting, return to normal working speed smoothly
    if (self.currentAvgMass or 0) <= 0.01 and (self.tonPerHour or 0) <= 0.05 then
        local target = maxAllowedSpeed > 0 and maxAllowedSpeed or 10.0
        if self.speedLimit > target then
            self.speedLimit = math.max(target, self.speedLimit - 0.5)
        elseif self.speedLimit < target then
            self.speedLimit = math.min(target, self.speedLimit + 0.5)
        end
        return
    end

    -- Target engine load from combine settings or default to 95%
    local targetLoad = 0.95
    if self.combineMemory and self.combineMemory.currentSettings and self.combineMemory.currentSettings.targetEngineLoad then
        targetLoad = self.combineMemory.currentSettings.targetEngineLoad / 100.0
    end

    local currentLoad = self.engineLoad or 0

    -- Difference between target load and current load
    local difference = targetLoad - currentLoad

    -- Deadzone of +/- 2.5% to prevent micro-oscillations and jitter around target
    if math.abs(difference) < 0.025 then
        difference = 0
    end

    -- Proportional adjustment: rapid braking on overload, smooth acceleration on underload
    local step = 0
    if difference < 0 then
        step = difference * 3.5 -- Emergency braking to prevent choking
    else
        step = difference * 1.5 -- Smooth acceleration
    end

    -- Limit speed adjustment per tick to avoid jerky motion
    step = math.max(-2.5, math.min(0.8, step))

    self.speedLimit = self.speedLimit + step

    -- Clamp speed within safe physical bounds:
    -- Lower bound: 3.5 km/h (prevent stall)
    -- Upper bound: maxAllowedSpeed
    local minSpeed = 3.5
    if maxAllowedSpeed and maxAllowedSpeed > 0 then
        self.speedLimit = math.max(minSpeed, math.min(maxAllowedSpeed, self.speedLimit))
    else
        self.speedLimit = math.max(minSpeed, self.speedLimit)
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


