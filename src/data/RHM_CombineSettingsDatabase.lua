-- EN: Static database of optimal combine settings and crop profiles.
--     Stores parameter templates (fan, rotor, sieves, feeder) for every supported crop type,
--     maps FS25 FillType enums to internal crop names, and defines which parameters are
--     active for each machine type (grain, forage, root, cotton).
-- UA: Статична база даних оптимальних налаштувань комбайна та профілів культур.
--     Зберігає шаблони параметрів (вентилятор, ротор, решета, подача) для кожного типу культури,
--     відображає FillType enum FS25 на внутрішні назви культур, і визначає які параметри активні
--     для кожного типу машини (зернова, форажна, коренеплоди, бавовна).
RHM_CombineSettingsDatabase = {}

-- EN: Fully dynamic physics-based settings generator.
--     Static hardcoded templates have been replaced by the ASABE / FS25 physical calculation engine
--     in RHM_CombineSettingsDatabase:calculatePhysicalOptimalSettings(cropName, context).
-- UA: Повністю динамічний фізичний генератор налаштувань.
--     Статичні захардкоджені шаблони замінено фізичним розрахунковим модулем
--     в RHM_CombineSettingsDatabase:calculatePhysicalOptimalSettings(cropName, context).
-- EN: Active parameters per machine type. Defines which parameter sliders appear in the calibration GUI.
-- UA: Активні параметри для кожного типу машини. Визначає які повзунки параметрів відображаються в GUI калібрування.

---Active parameters per machine type (defines which sliders appear in GUI)
RHM_CombineSettingsDatabase.machineParams = {
    grain   = { "fan", "rotor", "upperSieve", "lowerSieve", "feeder" },
    forage  = { "fan", "rotor", "feeder" },
    root    = { "fan", "rotor", "feeder" },
    cotton  = { "fan", "rotor", "feeder" },
}

---L10n key overrides for parameter labels per machine type
---Falls back to generic "rhm_ui_<param>" if no override defined
RHM_CombineSettingsDatabase.machineParamLabels = {
    grain = {
        fan        = "rhm_ui_fan_speed",
        rotor      = "rhm_ui_rotor_speed",
        upperSieve = "rhm_ui_upper_sieve",
        lowerSieve = "rhm_ui_lower_sieve",
        feeder     = "rhm_ui_feeder_speed",
    },
    forage = {
        fan    = "rhm_ui_forage_fan",
        rotor  = "rhm_ui_forage_drum",
        feeder = "rhm_ui_forage_feeder",
    },
    root = {
        fan    = "rhm_ui_fan_speed",
        rotor  = "rhm_ui_root_roller",
        feeder = "rhm_ui_root_feeder",
    },
    cotton = {
        fan    = "rhm_ui_fan_speed",
        rotor  = "rhm_ui_picker_speed",  -- Picker/spindle
        feeder = "rhm_ui_feeder_speed",
    },
}

-- EN: Returns the ordered list of parameter names active for the given machine type.
--     Used to determine which sliders to display and which RHM_CombineMemory keys to initialize.
-- UA: Повертає впорядкований список назв параметрів активних для заданого типу машини.
--     Використовується для визначення яких повзунки відображати та які ключі RHM_CombineMemory ініціалізувати.
function RHM_CombineSettingsDatabase:getParamsForMachineType(machineType)
    return self.machineParams[machineType] or self.machineParams.grain
end

-- EN: Returns the localization key for a parameter label based on machine type.
--     Falls back to generic "rhm_ui_<param>" if no specific override is defined.
-- UA: Повертає ключ локалізації для підпису параметру залежно від типу машини.
--     Повертається до загального "rhm_ui_<param>" якщо немає специфічного перевизначення.
function RHM_CombineSettingsDatabase:getParamLabel(machineType, paramName)
    local labels = self.machineParamLabels[machineType]
    if labels and labels[paramName] then
        return labels[paramName]
    end
    return "rhm_ui_" .. paramName
end

-- EN: Guard wrapper for FillType values — returns nil if the fill type is missing (DLC/mod not loaded).
-- UA: Захисна обгортка для значень FillType — повертає nil якщо тип врожаю відсутній (DLC/мод не завантажений).
local function safeFillType(ft)
    return (ft ~= nil and ft ~= 0) and ft or nil
end

RHM_CombineSettingsDatabase.crops = {
    -- Зернові
    ["WHEAT"]   = { machineType = "grain", group = "grain",   fillType = safeFillType(FillType.WHEAT) },
    ["BARLEY"]  = { machineType = "grain", group = "grain",   fillType = safeFillType(FillType.BARLEY) },
    ["OAT"]     = { machineType = "grain", group = "grain",   fillType = safeFillType(FillType.OAT) },
    ["SORGHUM"] = { machineType = "grain", group = "grain",   fillType = safeFillType(FillType.SORGHUM) },
    
    -- Рис
    ["RICE"]            = { machineType = "grain", group = "rice", fillType = safeFillType(FillType.RICE) },
    ["RICE_LONG_GRAIN"] = { machineType = "grain", group = "rice", fillType = safeFillType(FillType.RICE_LONG_GRAIN) },
    
    -- Олійні
    ["CANOLA"]    = { machineType = "grain", group = "oilseed", fillType = safeFillType(FillType.CANOLA) },
    ["SUNFLOWER"] = { machineType = "grain", group = "oilseed", fillType = safeFillType(FillType.SUNFLOWER) },
    
    -- Кукурудза
    ["CORN"] = { machineType = "grain", group = "corn", fillType = safeFillType(FillType.MAIZE) },
    
    -- Бобові
    ["SOYBEAN"]  = { machineType = "grain", group = "legume", fillType = safeFillType(FillType.SOYBEAN) },
    ["PEA"]      = { machineType = "grain", group = "legume", fillType = safeFillType(FillType.PEA) },
    ["LENTIL"]   = { machineType = "grain", group = "legume", fillType = safeFillType(FillType.LENTIL) },
    ["CHICKPEA"] = { machineType = "grain", group = "legume", fillType = safeFillType(FillType.CHICKPEA) },

    -- Додаткові зернові (Mod crops)
    ["RYE"]       = { machineType = "grain", group = "grain", fillType = nil },
    ["SPELT"]     = { machineType = "grain", group = "grain", fillType = nil },
    ["TRITICALE"] = { machineType = "grain", group = "grain", fillType = nil },
    ["OATS"]      = { machineType = "grain", group = "grain", fillType = nil },
    ["MILLET"]    = { machineType = "grain", group = "grain", fillType = nil },
    ["BUCKWHEAT"] = { machineType = "grain", group = "grain", fillType = nil },
    
    -- Додаткові олійні (Mod crops)
    ["LINSEED"]   = { machineType = "grain", group = "oilseed", fillType = nil },
    ["FLAX"]      = { machineType = "grain", group = "oilseed", fillType = nil },
    ["MUSTARD"]   = { machineType = "grain", group = "oilseed", fillType = nil },
    ["SAFFLOWER"] = { machineType = "grain", group = "oilseed", fillType = nil },
    ["POPPY"]     = { machineType = "grain", group = "oilseed", fillType = nil },
    
    -- Трави
    ["GRASS_SEED"] = { machineType = "grain", group = "grain", fillType = nil },
    ["CLOVER"]     = { machineType = "grain", group = "grain", fillType = nil },
    
    -- Волокнисті (Mod crops)
    ["HEMP"] = { machineType = "grain", group = "oilseed", fillType = nil },
    
    -- Root & Veg (machineType = "root")
    ["POTATO"]    = { machineType = "root", group = "root",      fillType = safeFillType(FillType.POTATO) },
    ["SUGARBEET"] = { machineType = "root", group = "root",      fillType = safeFillType(FillType.SUGARBEET) },
    ["BEETROOT"]  = { machineType = "root", group = "root",      fillType = safeFillType(FillType.BEETROOT) },
    ["CARROT"]    = { machineType = "root", group = "root",      fillType = safeFillType(FillType.CARROT) },
    ["PARSNIP"]   = { machineType = "root", group = "root",      fillType = safeFillType(FillType.PARSNIP) },
    ["ONION"]     = { machineType = "root", group = "root",      fillType = safeFillType(FillType.ONION) },
    ["SPINACH"]   = { machineType = "root", group = "vegetable", fillType = safeFillType(FillType.SPINACH) },
    ["GREENBEAN"] = { machineType = "root", group = "vegetable", fillType = safeFillType(FillType.GREENBEAN) },

    -- Форажні (для кормозбирального комбайна) (machineType = "forage")
    ["GRASS"]            = { machineType = "forage", group = "forage", fillType = safeFillType(FillType.GRASS) },
    ["DRYGRASS"]         = { machineType = "forage", group = "forage", fillType = safeFillType(FillType.DRYGRASS) },
    ["GRASS_WINDROW"]    = { machineType = "forage", group = "forage", fillType = safeFillType(FillType.GRASS_WINDROW) },
    ["DRYGRASS_WINDROW"] = { machineType = "forage", group = "forage", fillType = safeFillType(FillType.DRYGRASS_WINDROW) },
    ["STRAW_WINDROW"]    = { machineType = "forage", group = "forage", fillType = safeFillType(FillType.STRAW) },
    ["ALFALFA"]          = { machineType = "forage", group = "forage", fillType = nil },
    ["ALFALFA_WINDROW"]  = { machineType = "forage", group = "forage", fillType = nil },
    ["CLOVER_WINDROW"]   = { machineType = "forage", group = "forage", fillType = nil },
    ["MAIZE_FORAGE"]     = { machineType = "forage", group = "forage", fillType = safeFillType(FillType.MAIZE) },

    -- Бавовник (machineType = "cotton")
    ["COTTON"] = { machineType = "cotton", group = "cotton", fillType = safeFillType(FillType.COTTON) },
}

---EN: Dynamically derives physical optimal settings for any crop (vanilla or modded) using FS25 properties & ASABE standards.
---UA: Динамічно розраховує фізичні оптимальні налаштування для будь-якої культури за властивостями FS25 та стандартами ASABE.
function RHM_CombineSettingsDatabase:calculatePhysicalOptimalSettings(cropName, context)
    context = context or {}
    local machineType = context.machineType or "grain"
    if self.crops[cropName] and self.crops[cropName].machineType then
        machineType = self.crops[cropName].machineType
    end

    -- 1. Query GIANTS managers for physical characteristics
    local fillTypeDesc = nil
    if context.fillType and g_fillTypeManager and g_fillTypeManager.getFillTypeByIndex then
        fillTypeDesc = g_fillTypeManager:getFillTypeByIndex(context.fillType)
    elseif g_fillTypeManager and g_fillTypeManager.getFillTypeByName then
        fillTypeDesc = g_fillTypeManager:getFillTypeByName(cropName)
    end

    local fruitTypeDesc = nil
    if context.fruitType and g_fruitTypeManager and g_fruitTypeManager.getFruitTypeByIndex then
        fruitTypeDesc = g_fruitTypeManager:getFruitTypeByIndex(context.fruitType)
    elseif g_fruitTypeManager and g_fruitTypeManager.getFruitTypeByName then
        fruitTypeDesc = g_fruitTypeManager:getFruitTypeByName(cropName)
    end

    -- 2. Bulk Density (kg/L)
    local densityKgPerL = 0.75
    if fillTypeDesc and fillTypeDesc.massPerLiter and fillTypeDesc.massPerLiter > 0 then
        densityKgPerL = fillTypeDesc.massPerLiter * 1000
    else
        local knownDensities = {
            WHEAT = 0.78, BARLEY = 0.62, OAT = 0.52, OATS = 0.52,
            CANOLA = 0.42, SUNFLOWER = 0.42, SAFFLOWER = 0.42,
            CORN = 0.76, MAIZE = 0.76, SOYBEAN = 0.75, SORGHUM = 0.72,
            RICE = 0.58, RICE_LONG_GRAIN = 0.58,
            PEA = 0.75, LENTIL = 0.75, CHICKPEA = 0.75,
            RYE = 0.72, SPELT = 0.53, TRITICALE = 0.70,
            MILLET = 0.65, BUCKWHEAT = 0.60,
            LINSEED = 0.45, FLAX = 0.45, MUSTARD = 0.45, POPPY = 0.40,
            HEMP = 0.50, GRASS_SEED = 0.28, CLOVER = 0.35,
        }
        densityKgPerL = knownDensities[cropName] or 0.75
    end

    -- 3. Straw / MOG Presence
    local hasStraw = false
    if fruitTypeDesc and fruitTypeDesc.hasWindrow ~= nil then
        hasStraw = fruitTypeDesc.hasWindrow
    elseif cropName == "WHEAT" or cropName == "BARLEY" or cropName == "OAT" or cropName == "OATS"
        or cropName == "RYE" or cropName == "SPELT" or cropName == "TRITICALE"
        or cropName == "RICE" or cropName == "RICE_LONG_GRAIN" then
        hasStraw = true
    end

    local template = {}

    if machineType == "forage" then
        local isPickup = context.isPickup or false
        if cropName:find("WINDROW") or cropName:find("PICKUP") or cropName == "STRAW" or cropName == "HAY" then
            isPickup = true
        end

        if cropName:find("CORN") or cropName:find("MAIZE") or cropName:find("SILAGE") or cropName:find("CHAFF") or cropName:find("GPS") then
            -- Corn silage: high-speed accelerator blower (75%), fast chopping drum (80%), high intake feedrolls (70%)
            template = {
                fan    = {optimal = 75, min = 55, max = 95, tolerance = 8},
                rotor  = {optimal = 80, min = 60, max = 100, tolerance = 8},
                feeder = {optimal = 70, min = 50, max = 90, tolerance = 8},
                moistureLimit = 65,
            }
        elseif isPickup then
            -- Windrow pickup (pre-wilted/dry grass, hay, or straw): moderate drum, swift feeder
            template = {
                fan    = {optimal = 55, min = 35, max = 75, tolerance = 8},
                rotor  = {optimal = 60, min = 40, max = 80, tolerance = 8},
                feeder = {optimal = 65, min = 45, max = 85, tolerance = 8},
                moistureLimit = 40,
            }
        else
            -- Direct-cut standing grass/lucerne/clover: juicy long stems, high cut resistance
            template = {
                fan    = {optimal = 65, min = 45, max = 85, tolerance = 8},
                rotor  = {optimal = 65, min = 45, max = 85, tolerance = 8},
                feeder = {optimal = 55, min = 35, max = 75, tolerance = 8},
                moistureLimit = 75,
            }
        end

    elseif machineType == "root" then
        if cropName:find("SPINACH") or cropName:find("LEAF") or cropName:find("HERB") then
            template = {
                fan    = {optimal = 20, min = 5,  max = 40, tolerance = 5},
                rotor  = {optimal = 25, min = 10, max = 45, tolerance = 5},
                feeder = {optimal = 60, min = 40, max = 80, tolerance = 8},
                moistureLimit = 25,
            }
        elseif cropName:find("ONION") or cropName:find("GARLIC") then
            template = {
                fan    = {optimal = 75, min = 55, max = 95, tolerance = 8},
                rotor  = {optimal = 45, min = 25, max = 65, tolerance = 8},
                feeder = {optimal = 55, min = 35, max = 75, tolerance = 8},
                moistureLimit = 18,
            }
        elseif cropName:find("POTATO") then
            template = {
                fan    = {optimal = 35, min = 15, max = 55, tolerance = 8},
                rotor  = {optimal = 40, min = 20, max = 60, tolerance = 8},
                feeder = {optimal = 70, min = 50, max = 90, tolerance = 8},
                moistureLimit = 20,
            }
        elseif cropName:find("SUGARBEET") or cropName:find("BEETROOT") then
            template = {
                fan    = {optimal = 40, min = 20, max = 60, tolerance = 8},
                rotor  = {optimal = 55, min = 35, max = 75, tolerance = 8},
                feeder = {optimal = 65, min = 45, max = 85, tolerance = 8},
                moistureLimit = 22,
            }
        elseif cropName:find("GREENBEAN") then
            template = {
                fan    = {optimal = 45, min = 25, max = 65, tolerance = 8},
                rotor  = {optimal = 35, min = 15, max = 55, tolerance = 8},
                feeder = {optimal = 65, min = 45, max = 85, tolerance = 8},
                moistureLimit = 18,
            }
        else
            -- General Root / Carrot / Parsnip
            template = {
                fan    = {optimal = 38, min = 20, max = 58, tolerance = 8},
                rotor  = {optimal = 45, min = 25, max = 65, tolerance = 8},
                feeder = {optimal = 68, min = 48, max = 88, tolerance = 8},
                moistureLimit = 20,
            }
        end

    elseif machineType == "cotton" then
        template = {
            fan    = {optimal = 80, min = 60, max = 100, tolerance = 10},
            rotor  = {optimal = 70, min = 50, max = 90, tolerance = 10},
            feeder = {optimal = 60, min = 40, max = 80, tolerance = 10},
            moistureLimit = 10,
        }

    else
        -- GRAIN COMBINE HARVESTER (Aerodynamic & Threshing Physics Engine)
        -- A. Fan Speed: Aerodynamic terminal velocity directly related to bulk density
        local fanOpt = math.floor(math.max(20, math.min(90, 20 + (densityKgPerL * 52) + 0.5)))
        
        -- Specific aerodynamic corrections for seed geometry & chaff drag:
        if cropName == "CANOLA" or cropName == "MUSTARD" or cropName == "LINSEED" or cropName == "FLAX" then
            fanOpt = 39
        elseif cropName == "POPPY" then
            fanOpt = 35
        elseif cropName == "GRASS_SEED" or cropName == "CLOVER" then
            fanOpt = 25
        elseif cropName == "OAT" or cropName == "OATS" or cropName == "SUNFLOWER" or cropName == "SAFFLOWER" then
            fanOpt = 44
        elseif cropName == "BARLEY" or cropName == "WHEAT" or cropName == "RYE" or cropName == "TRITICALE" or cropName == "SPELT" then
            fanOpt = 56
        elseif cropName == "SORGHUM" then
            fanOpt = 58
        elseif cropName == "RICE" or cropName == "RICE_LONG_GRAIN" then
            fanOpt = 50
        elseif cropName == "SOYBEAN" then
            fanOpt = 61
        elseif cropName == "CORN" or cropName == "MAIZE" then
            fanOpt = 67
        elseif cropName == "PEA" or cropName == "LENTIL" or cropName == "CHICKPEA" then
            fanOpt = 55
        end

        -- B. Rotor & Concave: Based on straw volume, seed brittleness, and ear architecture
        local rotorOpt = 55
        local concaveOpt = 45
        local feederOpt = 25
        local upperOpt = 48
        local lowerOpt = 32
        local moistLimit = 14

        if cropName == "BARLEY" then
            -- Tough awns: higher drum speed (63%) and tighter concave (22%)
            rotorOpt = 63; concaveOpt = 22; upperOpt = 47; lowerOpt = 32; feederOpt = 14; moistLimit = 14
        elseif cropName == "WHEAT" or cropName == "RYE" or cropName == "TRITICALE" or cropName == "SPELT" or cropName == "MILLET" then
            -- Standard cereal grain: rotor 56%, concave 25%
            rotorOpt = 56; concaveOpt = 25; upperOpt = 47; lowerOpt = 32; feederOpt = 12; moistLimit = 14
        elseif cropName == "OAT" or cropName == "OATS" then
            -- Loose hulls: gentle rotor 50%, concave 30%
            rotorOpt = 50; concaveOpt = 30; upperOpt = 45; lowerOpt = 28; feederOpt = 12; moistLimit = 14
        elseif cropName == "CANOLA" or cropName == "MUSTARD" or cropName == "LINSEED" or cropName == "FLAX" or cropName == "POPPY" then
            -- Fragile pods, easily shattered: low rotor (33%), narrow sieves
            rotorOpt = 33; concaveOpt = 40; upperOpt = 30; lowerOpt = 18; feederOpt = 40; moistLimit = 9
        elseif cropName == "CORN" or cropName == "MAIZE" then
            -- Big cobs, cracking prevention: ultra-low drum (13%), wide concave (60%), large sieves (65/48)
            rotorOpt = 13; concaveOpt = 60; upperOpt = 65; lowerOpt = 48; feederOpt = 60; moistLimit = 15
        elseif cropName == "SUNFLOWER" or cropName == "SAFFLOWER" then
            -- Fragile hulls: low drum (18%), wide concave (60%)
            rotorOpt = 18; concaveOpt = 60; upperOpt = 60; lowerOpt = 40; feederOpt = 55; moistLimit = 9
        elseif cropName == "SOYBEAN" then
            -- Brittle embryo: gentle rotor (39%), medium-wide concave (38%)
            rotorOpt = 39; concaveOpt = 38; upperOpt = 55; lowerOpt = 36; feederOpt = 36; moistLimit = 13
        elseif cropName == "PEA" or cropName == "LENTIL" or cropName == "CHICKPEA" then
            -- Large pulses: slow drum (30%), wide concave (45%)
            rotorOpt = 30; concaveOpt = 45; upperOpt = 55; lowerOpt = 35; feederOpt = 30; moistLimit = 14
        elseif cropName == "SORGHUM" then
            rotorOpt = 42; concaveOpt = 35; upperOpt = 45; lowerOpt = 30; feederOpt = 20; moistLimit = 14
        elseif cropName == "RICE" or cropName == "RICE_LONG_GRAIN" then
            rotorOpt = 45; concaveOpt = 30; upperOpt = 40; lowerOpt = 25; feederOpt = 15; moistLimit = 14
        elseif cropName == "GRASS_SEED" or cropName == "CLOVER" then
            rotorOpt = 45; concaveOpt = 25; upperOpt = 25; lowerOpt = 15; feederOpt = 10; moistLimit = 12
        elseif cropName == "BUCKWHEAT" then
            rotorOpt = 35; concaveOpt = 35; upperOpt = 38; lowerOpt = 22; feederOpt = 25; moistLimit = 13
        elseif cropName == "HEMP" then
            rotorOpt = 40; concaveOpt = 35; upperOpt = 45; lowerOpt = 28; feederOpt = 25; moistLimit = 12
        else
            -- Dynamic calculation for unlisted custom mod crop
            if hasStraw then
                rotorOpt = 56; concaveOpt = 25; upperOpt = 47; lowerOpt = 32; feederOpt = 14; moistLimit = 14
            elseif densityKgPerL < 0.50 then
                rotorOpt = 35; concaveOpt = 40; upperOpt = 32; lowerOpt = 18; feederOpt = 35; moistLimit = 10
            elseif densityKgPerL >= 0.70 then
                rotorOpt = 25; concaveOpt = 55; upperOpt = 60; lowerOpt = 42; feederOpt = 50; moistLimit = 14
            else
                rotorOpt = 45; concaveOpt = 35; upperOpt = 45; lowerOpt = 28; feederOpt = 25; moistLimit = 14
            end
        end

        template = {
            fan        = {optimal = fanOpt, min = math.max(10, fanOpt - 20), max = math.min(100, fanOpt + 20), tolerance = 6},
            rotor      = {optimal = rotorOpt, min = math.max(10, rotorOpt - 20), max = math.min(100, rotorOpt + 20), tolerance = 6},
            concave    = {optimal = concaveOpt, min = math.max(10, concaveOpt - 20), max = math.min(100, concaveOpt + 20), tolerance = 6},
            upperSieve = {optimal = upperOpt, min = math.max(10, upperOpt - 20), max = math.min(100, upperOpt + 20), tolerance = 5},
            lowerSieve = {optimal = lowerOpt, min = math.max(5, lowerOpt - 15), max = math.min(100, lowerOpt + 20), tolerance = 5},
            feeder     = {optimal = feederOpt, min = math.max(5, feederOpt - 10), max = math.min(100, feederOpt + 15), tolerance = 4},
            moistureLimit = moistLimit,
        }
    end

    return template
end

---EN: Applies live environmental offsets (moisture, yield) to optimal settings pins.
---UA: Застосовує живі поправки навколишнього середовища (вологість, врожайність) до оптимальних налаштувань.
function RHM_CombineSettingsDatabase:applyEnvironmentalOffsets(baseTemplate, context)
    if not baseTemplate or not context then return baseTemplate end

    local moisture = context.moisture
    local yield = context.yield
    local machineType = context.machineType or "grain"

    -- Deep copy template so we don't modify the static database template
    local adjusted = {}
    for k, v in pairs(baseTemplate) do
        if type(v) == "table" then
            adjusted[k] = {
                optimal = v.optimal,
                min = v.min,
                max = v.max,
                tolerance = v.tolerance
            }
        else
            adjusted[k] = v
        end
    end

    -- 1. Grain combines: Moisture and Yield live corrections
    if machineType == "grain" and moisture and moisture > 0 then
        local refMoisture = baseTemplate.moistureLimit or 14.0
        local deltaM = moisture - refMoisture

        if deltaM > 0 then
            -- Tough/damp grain: faster rotor (+1.5%/1%), tighter concave (-1.0%/1%), stronger fan (+1.2%/1%)
            if adjusted.rotor then
                adjusted.rotor.optimal = math.min(100, math.floor(adjusted.rotor.optimal + deltaM * 1.5 + 0.5))
            end
            if adjusted.concave then
                adjusted.concave.optimal = math.max(10, math.floor(adjusted.concave.optimal - deltaM * 1.0 + 0.5))
            end
            if adjusted.fan then
                adjusted.fan.optimal = math.min(100, math.floor(adjusted.fan.optimal + deltaM * 1.2 + 0.5))
            end
        elseif deltaM < -2.0 then
            -- Very dry/brittle grain (< 12%): slower rotor (-1.5%/1%), wider concave (+1.0%/1%), gentler fan (-0.8%/1%)
            local dryDelta = math.abs(deltaM + 2.0)
            if adjusted.rotor then
                adjusted.rotor.optimal = math.max(10, math.floor(adjusted.rotor.optimal - dryDelta * 1.5 + 0.5))
            end
            if adjusted.concave then
                adjusted.concave.optimal = math.min(100, math.floor(adjusted.concave.optimal + dryDelta * 1.0 + 0.5))
            end
            if adjusted.fan then
                adjusted.fan.optimal = math.max(15, math.floor(adjusted.fan.optimal - dryDelta * 0.8 + 0.5))
            end
        end

        -- Stand density / Yield correction: high yield (> 8 t/ha) needs wider sieves & concaves to prevent choking
        if yield and yield > 8.0 then
            local excessYield = math.min(10.0, yield - 8.0)
            if adjusted.upperSieve then
                adjusted.upperSieve.optimal = math.min(100, math.floor(adjusted.upperSieve.optimal + excessYield * 1.0 + 0.5))
            end
            if adjusted.lowerSieve then
                adjusted.lowerSieve.optimal = math.min(100, math.floor(adjusted.lowerSieve.optimal + excessYield * 0.8 + 0.5))
            end
            if adjusted.concave then
                adjusted.concave.optimal = math.min(100, math.floor(adjusted.concave.optimal + excessYield * 1.0 + 0.5))
            end
        end
    end

    return adjusted
end

-- EN: Returns the optimal settings template for a crop by internal name (e.g. "WHEAT").
--     If crop is unlisted or custom mod crop, dynamically calculates its physical profile.
--     If context (moisture, yield) is supplied, applies live environmental adjustments.
-- UA: Повертає шаблон оптимальних налаштувань для культури за назвою.
--     Якщо культура невідома чи модова, динамічно генерує фізичний паспорт.
--     Якщо передано контекст (вологість, врожайність), застосовує живі поправки.
function RHM_CombineSettingsDatabase:getSettingsForCrop(cropName, context)
    if not cropName then return nil end

    local crop = self.crops[cropName]
    local baseTemplate = nil

    if crop then
        if not crop.template then
            crop.template = self:calculatePhysicalOptimalSettings(cropName, context)
        end
        baseTemplate = crop.template
    else
        -- Completely unknown or custom mod crop: dynamically derive physical template
        baseTemplate = self:calculatePhysicalOptimalSettings(cropName, context)
        local fillTypeIdx = (context and context.fillType) or (g_fillTypeManager and g_fillTypeManager.getFillTypeIndexByName and g_fillTypeManager:getFillTypeIndexByName(cropName))
        self.crops[cropName] = {
            name = cropName,
            nameEN = cropName,
            template = baseTemplate,
            machineType = (context and context.machineType) or "grain",
            group = "custom",
            fillType = (fillTypeIdx and fillTypeIdx > 0) and fillTypeIdx or nil,
        }
        rhm_log(string.format("RHM: [CROP DB] Dynamically generated physical profile for mod crop '%s' (machine: %s)", cropName, tostring(self.crops[cropName].machineType)))
    end

    if context and (context.moisture or context.yield) then
        return self:applyEnvironmentalOffsets(baseTemplate, context)
    end

    return baseTemplate
end

-- EN: Converts a game FillType integer to the internal crop name used in the database.
--     Handles windrow variants (_WINDROW suffix) and cut variants (CUT_ prefix) via fallback logic.
-- UA: Перетворює ціле число FillType гри на внутрішню назву культури у базі даних.
--     Обробляє варіанти валків (_WINDROW суфікс) та зрізані варіанти (CUT_ префікс) через резервну логіку.
function RHM_CombineSettingsDatabase:getCropNameFromFillType(fillType)
    if not fillType or fillType == FillType.UNKNOWN then
        return nil
    end

    -- Отримуємо точний рядок-ключ з таблиці FillType (наприклад "RICE_LONG_GRAIN")
    local fillTypeKey = nil
    for k, v in pairs(FillType) do
        if v == fillType then
            fillTypeKey = k
            break
        end
    end

    if not fillTypeKey and g_fillTypeManager and g_fillTypeManager.getFillTypeNameByIndex then
        fillTypeKey = g_fillTypeManager:getFillTypeNameByIndex(fillType)
    end

    if not fillTypeKey then
        return nil
    end

    -- Шукаємо crop за ключем FillType
    local fillTypeMapping = {
        ["WHEAT"] = "WHEAT",
        ["BARLEY"] = "BARLEY",
        ["OAT"] = "OAT",
        ["CANOLA"] = "CANOLA",
        ["SUNFLOWER"] = "SUNFLOWER",
        ["MAIZE"] = "CORN",
        ["SOYBEAN"] = "SOYBEAN",
        ["SORGHUM"] = "SORGHUM",
        ["RICE"] = "RICE",
        ["RICE_LONG_GRAIN"] = "RICE_LONG_GRAIN",
        ["RICELONGGRAIN"] = "RICE_LONG_GRAIN",
        ["RICE_LONGGRAIN"] = "RICE_LONG_GRAIN",

        -- FS25 New & Mod Crops
        ["PEA"] = "PEA",
        ["LENTIL"] = "LENTIL",
        ["CHICKPEA"] = "CHICKPEA",

        ["RYE"] = "RYE",
        ["SPELT"] = "SPELT",
        ["TRITICALE"] = "TRITICALE",
        ["MILLET"] = "MILLET",
        ["BUCKWHEAT"] = "BUCKWHEAT",

        ["LINSEED"] = "LINSEED",
        ["FLAX"] = "LINSEED",
        ["MUSTARD"] = "MUSTARD",
        ["POPPY"] = "POPPY",
        ["HEMP"] = "HEMP",

        -- Root/Veg
        ["POTATO"] = "POTATO",
        ["SUGARBEET"] = "SUGARBEET",
        ["BEETROOT"] = "BEETROOT",
        ["CARROT"] = "CARROT",
        ["PARSNIP"] = "PARSNIP",
        ["ONION"] = "ONION",
        ["ONION_DIRTY"] = "ONION",
        ["SPINACH"] = "SPINACH",
        ["GREENBEAN"] = "GREENBEAN",

        -- Forage outputs
        ["CHAFF"] = "MAIZE_FORAGE",
        ["GRASS"] = "GRASS",
        ["DRYGRASS"] = "DRYGRASS",
        ["HAY"] = "DRYGRASS",
        ["HAY_WINDROW"] = "DRYGRASS_WINDROW",
        ["TALLGRASS"] = "GRASS",
        ["GRASS_WINDROW"] = "GRASS_WINDROW",
        ["DRYGRASS_WINDROW"] = "DRYGRASS_WINDROW",
        ["STRAW"] = "STRAW_WINDROW",
        ["STRAW_WINDROW"] = "STRAW_WINDROW",
        ["SILAGE"] = "MAIZE_FORAGE",
        ["GPS"] = "MAIZE_FORAGE",
        ["ALFALFA"] = "ALFALFA",
        ["ALFALFA_WINDROW"] = "ALFALFA_WINDROW",
        ["LUCERNE"] = "ALFALFA",
        ["LUCERNE_WINDROW"] = "ALFALFA_WINDROW",
        ["CLOVER_WINDROW"] = "CLOVER_WINDROW",

        -- Cotton
        ["COTTON"] = "COTTON",
    }

    local matchedName = fillTypeMapping[fillTypeKey]

    if not matchedName and fillTypeKey then
        if fillTypeKey:find("_WINDROW") then
            local baseType = fillTypeKey:gsub("_WINDROW", "")
            matchedName = fillTypeMapping[baseType]
        elseif fillTypeKey:find("CUT_") then
            local baseType = fillTypeKey:gsub("CUT_", "")
            matchedName = fillTypeMapping[baseType]
        end
    end

    if not matchedName and fillTypeKey then
        -- Dynamic fallback: register unmapped mod fillType directly as crop name
        matchedName = fillTypeKey
        rhm_log(string.format("RHM: [CROP DB] Dynamic crop auto-registered for FillType: '%s' (ID: %d)", tostring(fillTypeKey), fillType))
    end

    return matchedName
end

---EN: Resolves the localized display name for a crop directly from the FS25 engine (fillType.title).
---UA: Отримує локалізовану назву культури безпосередньо з рушія FS25 (fillType.title).
function RHM_CombineSettingsDatabase:getCropDisplayName(cropName)
    if not cropName then return "" end

    local cropData = self.crops[cropName]

    -- 1. Try registered fillType index via g_fillTypeManager
    if cropData and cropData.fillType and g_fillTypeManager then
        local ft = g_fillTypeManager:getFillTypeByIndex(cropData.fillType)
        if ft and ft.title and ft.title ~= "" then
            return ft.title
        end
    end

    -- 2. Try looking up fillType by cropName directly
    if g_fillTypeManager and g_fillTypeManager.getFillTypeIndexByName then
        local ftIdx = g_fillTypeManager:getFillTypeIndexByName(cropName)
        if ftIdx and ftIdx > 0 then
            local ft = g_fillTypeManager:getFillTypeByIndex(ftIdx)
            if ft and ft.title and ft.title ~= "" then
                return ft.title
            end
        end
    end

    -- 3. Try FruitType manager title
    if g_fruitTypeManager and g_fruitTypeManager.getFruitTypeByName then
        local fruit = g_fruitTypeManager:getFruitTypeByName(cropName)
        if fruit and fruit.title and fruit.title ~= "" then
            return fruit.title
        end
    end

    -- 4. Try base game l10n key (fillType_<name>)
    local l10nKey = "fillType_" .. string.lower(cropName)
    if g_i18n and g_i18n.hasText and g_i18n:hasText(l10nKey) then
        return g_i18n:getText(l10nKey)
    end

    -- 5. Clean formatted fallback string
    local cleanName = cropName:gsub("_", " ")
    return cleanName:sub(1,1):upper() .. cleanName:sub(2):lower()
end

-- EN: Returns the full crop data record (template, machineType, group, fillType, names).
-- UA: Повертає повний запис даних культури (шаблон, тип машини, група, fillType, назви).
function RHM_CombineSettingsDatabase:getCropData(cropName)
    if not cropName then return nil end
    local crop = self.crops[cropName]
    if crop then
        if not crop.template then
            crop.template = self:calculatePhysicalOptimalSettings(cropName)
        end
        -- Dynamic backward compatibility for external consumers expecting .name or .nameEN
        if not crop.name then
            crop.name = self:getCropDisplayName(cropName)
            crop.nameEN = crop.name
        end
    end
    return crop
end

-- EN: Returns a sorted list of all registered crop names in the database.
-- UA: Повертає відсортований список всіх зареєстрованих назв культур у базі даних.
function RHM_CombineSettingsDatabase:getAllCropNames()
    local names = {}
    for cropName, _ in pairs(self.crops) do
        table.insert(names, cropName)
    end
    table.sort(names)
    return names
end

---EN: Discovers and registers all harvestable crops from the active map via g_fruitTypeManager.
---UA: Виявляє та реєструє всі культури з поточної карти через g_fruitTypeManager.
function RHM_CombineSettingsDatabase:initMapCrops()
    if self._mapCropsInitialized then
        return
    end
    if not g_fruitTypeManager or not g_fruitTypeManager.getFruitTypes then
        return
    end

    local mapFruitTypes = g_fruitTypeManager:getFruitTypes()
    if not mapFruitTypes or #mapFruitTypes == 0 then
        return
    end

    self._mapCropsInitialized = true
    local validMapCrops = {}

    -- Helper to classify machine type for unknown/mod crops
    local function detectMachineType(nameUpper)
        if nameUpper == "COTTON" then
            return "cotton"
        elseif nameUpper:find("GRAPE") then
            return "grape"
        elseif nameUpper:find("OLIVE") then
            return "olive"
        elseif nameUpper:find("WEED") or nameUpper:find("OILSEEDRADISH") or nameUpper:find("STONE") then
            return nil -- Not harvestable by standard combines
        elseif nameUpper:find("POTATO") or nameUpper:find("BEET") or nameUpper:find("CARROT")
            or nameUpper:find("PARSNIP") or nameUpper:find("ONION") or nameUpper:find("GARLIC")
            or nameUpper:find("SPINACH") or (nameUpper:find("BEAN") and not nameUpper:find("SOYBEAN"))
            or nameUpper:find("SUGARCANE") then
            return "root"
        elseif nameUpper:find("GRASS") or nameUpper:find("ALFALFA") or nameUpper:find("CLOVER")
            or nameUpper:find("SILAGE") or nameUpper:find("CHAFF") or nameUpper:find("FORAGE")
            or nameUpper:find("LUCERNE") or nameUpper:find("POPLAR") or nameUpper:find("MEADOW") then
            return "forage"
        else
            return "grain"
        end
    end

    for _, fruit in pairs(mapFruitTypes) do
        local rawName = fruit.name
        if rawName and rawName ~= "" then
            local nameUpper = rawName:upper()
            local mType = detectMachineType(nameUpper)

            if mType ~= nil then
                validMapCrops[nameUpper] = true

                if self.crops[nameUpper] then
                    if not self.crops[nameUpper].fillType and fruit.fillTypeIndex then
                        self.crops[nameUpper].fillType = fruit.fillTypeIndex
                    end
                else
                    local context = {
                        machineType = mType,
                        fruitType = fruit.index,
                        fillType = fruit.fillTypeIndex
                    }
                    local template = self:calculatePhysicalOptimalSettings(nameUpper, context)
                    self.crops[nameUpper] = {
                        name = fruit.title or nameUpper,
                        nameEN = fruit.title or nameUpper,
                        template = template,
                        machineType = mType,
                        group = "mapCustom",
                        fillType = fruit.fillTypeIndex
                    }
                    rhm_log(string.format("RHM: [MAP CROP] Auto-registered map fruit: '%s' (%s) -> %s", nameUpper, tostring(fruit.title), mType))
                end
            end
        end
    end

    -- Add standard forage windrows/chaff variants if base crop exists
    if validMapCrops["GRASS"] or validMapCrops["MEADOW"] then
        validMapCrops["GRASS_WINDROW"] = true
        validMapCrops["DRYGRASS_WINDROW"] = true
    end
    if validMapCrops["WHEAT"] or validMapCrops["BARLEY"] or validMapCrops["OAT"] then
        validMapCrops["STRAW_WINDROW"] = true
    end
    if validMapCrops["MAIZE"] then
        validMapCrops["MAIZE_FORAGE"] = true
    end
    if validMapCrops["ALFALFA"] or validMapCrops["LUCERNE"] then
        validMapCrops["ALFALFA_WINDROW"] = true
    end
    if validMapCrops["CLOVER"] then
        validMapCrops["CLOVER_WINDROW"] = true
    end

    self.validMapCrops = validMapCrops
end

-- EN: Returns a sorted list of crop names that match the specified machine type and exist on the current map.
--     Optionally filters by the active vehicle's hopper/tank supported fill types if provided.
-- UA: Повертає відсортований список назв культур що відповідають типу машини та існують на поточній карті.
--     Опціонально фільтрує за підтримуваними типами в бункері комбайна якщо вказано техніку.
function RHM_CombineSettingsDatabase:getCropNamesForMachineType(machineType, vehicle)
    self:initMapCrops()

    -- Gather supported fillType indices from vehicle hopper/tank if available
    local supportedFillTypes = nil
    if vehicle and vehicle.getFillUnits then
        local fillUnits = vehicle:getFillUnits()
        if fillUnits and #fillUnits > 0 then
            for _, fu in ipairs(fillUnits) do
                if fu.supportedFillTypes and next(fu.supportedFillTypes) ~= nil then
                    supportedFillTypes = supportedFillTypes or {}
                    for ftIdx, isSupp in pairs(fu.supportedFillTypes) do
                        if isSupp then
                            supportedFillTypes[ftIdx] = true
                        end
                    end
                end
            end
        end
    end

    local names = {}
    for cropName, cropData in pairs(self.crops) do
        if cropData.machineType == machineType then
            if not self.validMapCrops or self.validMapCrops[cropName] then
                local isSupported = true
                if supportedFillTypes and cropData.fillType then
                    if not supportedFillTypes[cropData.fillType] then
                        isSupported = false
                    end
                end
                if isSupported then
                    table.insert(names, cropName)
                end
            end
        end
    end

    -- Fallback to all map crops of this machineType if vehicle hopper filter was empty
    if #names == 0 and supportedFillTypes ~= nil then
        for cropName, cropData in pairs(self.crops) do
            if cropData.machineType == machineType then
                if not self.validMapCrops or self.validMapCrops[cropName] then
                    table.insert(names, cropName)
                end
            end
        end
    end

    -- Sort alphabetically by localized display name
    table.sort(names, function(a, b)
        local nameA = self:getCropDisplayName(a):lower()
        local nameB = self:getCropDisplayName(b):lower()
        return nameA < nameB
    end)

    return names
end

-- EN: Calculates a preview of total crop loss for arbitrary settings without applying them.
--     Used in the calibration GUI to show color-coded feedback before the player commits.
--     Loss = 0.15% per unit of deviation above tolerance, capped at 25%.
-- UA: Розраховує попередній перегляд загальних втрат врожаю для довільних налаштувань без їх застосування.
--     Використовується в GUI калібрування для кольорового зворотного зв'язку до підтвердження гравцем.
--     Втрати = 0.15% за одиницю відхилення понад допуск, обмежено до 25%.
function RHM_CombineSettingsDatabase:calcSettingsLossPreview(cropName, settings, context)
    local template = self:getSettingsForCrop(cropName, context)
    if not template then return 0, {} end
    
    local totalPenalty = 0
    local warnings = {}
    
    for paramName, paramData in pairs(template) do
        local val = settings[paramName]
        if val and paramData.optimal then
            local diff = math.abs(val - paramData.optimal)
            local tol = paramData.tolerance or 5
            if diff > tol then
                local penalty = (diff - tol) * 0.15  -- 0.15% loss per unit above tolerance
                totalPenalty = totalPenalty + penalty
                table.insert(warnings, {
                    param = paramName,
                    current = val,
                    optimal = paramData.optimal,
                    diff = diff,
                    penalty = penalty,
                })
            end
        end
    end
    
    return math.min(totalPenalty, 25.0), warnings  -- cap at 25%
end

-- EN: Checks if a parameter value is within the allowed range (min-max) for the crop.
--     Values outside this range are physically unrealistic and blocked by the GUI.
-- UA: Перевіряє чи значення параметру знаходиться в допустимому діапазоні (min-max) для культури.
--     Значення поза цим діапазоном є фізично нереалістичними і блокуються GUI.
function RHM_CombineSettingsDatabase:isValueValid(cropName, paramName, value, context)
    local settings = self:getSettingsForCrop(cropName, context)
    if not settings or not settings[paramName] then
        return false
    end
    
    local param = settings[paramName]
    return value >= param.min and value <= param.max
end

rhm_log("[OK] RHM_CombineSettingsDatabase loaded with " .. #RHM_CombineSettingsDatabase:getAllCropNames() .. " crops")

