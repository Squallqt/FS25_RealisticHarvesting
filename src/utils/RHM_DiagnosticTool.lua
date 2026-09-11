-- EN: Diagnostic & Telemetry Recording Tool for Realistic Harvesting Mod
--     Provides automated and on-demand harvest testing, telemetry logging, and XML persistence.
-- UA: Інструмент діагностики та запису телеметрії для моду Realistic Harvesting
--     Забезпечує автоматичний та ручний збір тестів збирання, логування телеметрії та збереження в XML.

RHM_DiagnosticTool = {}
RHM_DiagnosticTool.sessionRecords = {}
RHM_DiagnosticTool.recordedThisPass = {}
RHM_DiagnosticTool.autoRecordEnabled = false
RHM_DiagnosticTool.harvestStableTime = {}

---EN: Returns path to the XML file for saving crop test records.
---UA: Повертає шлях до XML файлу для збереження результатів тестування культур.
function RHM_DiagnosticTool:getXmlFilePath()
    local userPath = getUserProfileAppPath()
    if not userPath then
        return nil
    end

    local modSettingsPath = userPath .. "modSettings"
    local rhmPath = modSettingsPath .. "/FS25_RealisticHarvesting"

    if not fileExists(modSettingsPath) then
        createFolder(modSettingsPath)
    end
    if not fileExists(rhmPath) then
        createFolder(rhmPath)
    end

    return rhmPath .. "/crop_test_records.xml"
end

---EN: Finds active combine (either controlled by player or running AI worker).
---UA: Знаходить активний комбайн (керований гравцем або найманим робітником).
function RHM_DiagnosticTool:findActiveCombine()
    local mission = g_currentMission
    if not mission then return nil end

    -- 1. Check controlled vehicle from RHM manager
    if g_realisticHarvestManager and g_realisticHarvestManager.getControlledVehicle then
        local veh = g_realisticHarvestManager:getControlledVehicle()
        if veh and veh.spec_rhm_Combine then
            return veh
        end
    end

    -- 2. Check mission controlled vehicle
    if mission.controlledVehicle and mission.controlledVehicle.spec_rhm_Combine then
        return mission.controlledVehicle
    end

    -- 3. Search vehicles for actively threshing combine
    if mission.vehicles then
        for _, veh in pairs(mission.vehicles) do
            if veh.spec_rhm_Combine and veh.spec_combine and veh.spec_combine.isThreshing then
                return veh
            end
        end
        -- Fallback: any turned on combine
        for _, veh in pairs(mission.vehicles) do
            if veh.spec_rhm_Combine and veh.getIsTurnedOn and veh:getIsTurnedOn() then
                return veh
            end
        end
    end

    return nil
end

---EN: Extracts complete telemetry data snapshot from a combine.
---UA: Витягує повний знімок телеметричних даних з комбайна.
function RHM_DiagnosticTool:extractVehicleData(vehicle)
    if not vehicle or not vehicle.spec_rhm_Combine then
        return nil
    end

    local rhmSpec = vehicle.spec_rhm_Combine
    local calc = rhmSpec.loadCalculator
    if not calc then return nil end

    local spec_combine = vehicle.spec_combine

    -- 1. VEHICLE INFO
    local vehicleName = vehicle:getFullName() or "Unknown Vehicle"
    local vehicleConfig = vehicle.configFileName or ""
    local category = (vehicle.xmlFile and vehicle.xmlFile:getValue("vehicle.storeData.category")) or "unknown"
    local machineType = (rhmSpec.combineMemory and rhmSpec.combineMemory.machineType) or rhmSpec.machineType or "grain"
    local engineHp = calc:getEnginePowerHp(vehicle)
    local effectiveHp = calc.lastEffectiveHp or engineHp

    -- 2. HEADER INFO
    local headerName = "Integrated / Built-in"
    local headerWidth = 0
    local headerCat = "unknown"
    if vehicle.getAttachedImplements then
        for _, impl in pairs(vehicle:getAttachedImplements()) do
            local obj = impl.object
            if obj and (obj.spec_cutter or obj.spec_forageHarvesterCutter or obj.spec_forageCutter or obj.spec_pickup) then
                headerName = obj:getFullName() or headerName
                if obj.spec_cutter and obj.spec_cutter.workingWidth then
                    headerWidth = obj.spec_cutter.workingWidth
                end
                if obj.xmlFile then
                    headerCat = obj.xmlFile:getValue("vehicle.storeData.category") or headerCat
                end
            end
        end
    end
    if headerWidth == 0 and vehicle.spec_cutter and vehicle.spec_cutter.workingWidth then
        headerWidth = vehicle.spec_cutter.workingWidth
    end
    if headerWidth == 0 then
        headerWidth = 3.0 -- safe fallback
    end
    local headerHp = calc.headerHp or 0

    -- 3. CROP & YIELD INFO
    local inputFruitType = (spec_combine and spec_combine.lastValidInputFruitType) or 0
    local fruitDesc = g_fruitTypeManager and g_fruitTypeManager:getFruitTypeByIndex(inputFruitType)
    local fruitName = (fruitDesc and fruitDesc.name) or tostring(calc.currentCrop or "UNKNOWN")

    local outputFillType = rhmSpec.lastFillType or 0
    local fillDesc = g_fillTypeManager and g_fillTypeManager:getFillTypeByIndex(outputFillType)
    local fillName = (fillDesc and fillDesc.name) or fruitName

    local density = (fillDesc and fillDesc.massPerLiter and fillDesc.massPerLiter > 0 and fillDesc.massPerLiter) or 0.75

    local lpsqm = 0.85
    if fruitDesc then
        if fruitDesc.harvest and fruitDesc.harvest.literPerSqm and fruitDesc.harvest.literPerSqm > 0 then
            lpsqm = fruitDesc.harvest.literPerSqm
        elseif fruitDesc.literPerSqm and fruitDesc.literPerSqm > 0 then
            lpsqm = fruitDesc.literPerSqm
        elseif fruitDesc.litersPerSqm and fruitDesc.litersPerSqm > 0 then
            lpsqm = fruitDesc.litersPerSqm
        end
    end

    local yRef = math.max(1.0, lpsqm * 10.0 * density * 1.10)
    local actualYield = calc.currentYield or 0
    local yieldRatio = (actualYield > 0.5) and (yRef / actualYield) or 1.0

    local cropUpper = string.upper(fruitName)
    local isStripper = (cropUpper:find("BEAN") or cropUpper:find("PEA") or cropUpper:find("SPINACH")) ~= nil

    -- 4. SPEEDS & METRICS
    local currentSpeed = (vehicle.getLastSpeed and vehicle:getLastSpeed()) or 0
    local targetSpeed = calc:getSpeedLimit() or 0
    local vanillaSpeed = calc.genuineSpeedLimit or calc.vanillaWorkingSpeed or 10.0
    local massFlowKgS = calc.currentAvgMass or 0
    local throughputTph = massFlowKgS * 3.6
    local engineLoad = calc:getEngineLoad() or 0
    local cropLoss = calc.cropLoss or 0
    local moisture = (rhmSpec.data and rhmSpec.data.moisture) or 0
    local eSpec = calc.lastSpecificEnergy or 0

    -- 5. POWER BREAKDOWN
    local pBase = calc.lastPowerBase or (effectiveHp * 0.08)
    local pHeader = calc.lastPowerHeader or 0
    local pProcess = calc.lastPowerProcess or 0
    local pSoil = calc.lastPowerSoil or 0
    local pTotal = calc.lastPowerTotal or (pBase + pHeader + pProcess + pSoil)

    local timestamp = ""
    if getDate then
        timestamp = getDate("%Y-%m-%d %H:%M:%S")
    else
        timestamp = tostring(os.date and os.date("%Y-%m-%d %H:%M:%S") or "now")
    end

    return {
        timestamp = timestamp,
        vehicleName = vehicleName,
        vehicleConfig = vehicleConfig,
        category = category,
        machineType = machineType,
        engineHp = engineHp,
        effectiveHp = effectiveHp,
        headerName = headerName,
        headerWidth = headerWidth,
        headerHp = headerHp,
        headerCat = headerCat,
        isStripper = isStripper,
        isPickup = calc.isPickup or false,
        isForageCutter = calc.isForageCutter or false,
        fruitType = inputFruitType,
        fruitName = fruitName,
        fillType = outputFillType,
        fillName = fillName,
        density = density,
        lpsqm = lpsqm,
        yRef = yRef,
        actualYield = actualYield,
        yieldRatio = yieldRatio,
        currentSpeed = currentSpeed,
        targetSpeed = targetSpeed,
        vanillaSpeed = vanillaSpeed,
        massFlowKgS = massFlowKgS,
        throughputTph = throughputTph,
        engineLoad = engineLoad,
        cropLoss = cropLoss,
        moisture = moisture,
        eSpec = eSpec,
        pBase = pBase,
        pHeader = pHeader,
        pProcess = pProcess,
        pSoil = pSoil,
        pTotal = pTotal
    }
end

---EN: Appends a recorded sample to crop_test_records.xml.
---UA: Додає записаний зразок до crop_test_records.xml.
function RHM_DiagnosticTool:saveRecordToXml(data)
    local xmlPath = self:getXmlFilePath()
    if not xmlPath then return end

    local xml = nil
    if fileExists(xmlPath) then
        xml = XMLFile.load("RHM_CropTestRecords", xmlPath)
    end
    if not xml then
        xml = XMLFile.create("RHM_CropTestRecords", xmlPath, "cropTestRecords")
    end

    if xml then
        local count = 0
        while xml:hasProperty(string.format("cropTestRecords.record(%d)", count)) do
            count = count + 1
        end

        local k = string.format("cropTestRecords.record(%d)", count)
        xml:setInt(k .. "#id", count + 1)
        xml:setString(k .. "#timestamp", data.timestamp or "")
        xml:setString(k .. "#crop", data.fruitName or "")
        xml:setString(k .. "#fillType", data.fillName or "")
        xml:setString(k .. "#vehicle", data.vehicleName or "")
        xml:setString(k .. "#category", data.category or "")
        xml:setString(k .. "#machineType", data.machineType or "")
        xml:setFloat(k .. "#engineHp", data.engineHp or 0)
        xml:setString(k .. "#header", data.headerName or "")
        xml:setFloat(k .. "#width", data.headerWidth or 0)
        xml:setFloat(k .. "#headerHp", data.headerHp or 0)
        xml:setFloat(k .. "#yieldTph", data.actualYield or 0)
        xml:setFloat(k .. "#nominalYieldTph", data.yRef or 0)
        xml:setFloat(k .. "#yieldRatio", data.yieldRatio or 1.0)
        xml:setFloat(k .. "#speedKmh", data.currentSpeed or 0)
        xml:setFloat(k .. "#targetSpeedKmh", data.targetSpeed or 0)
        xml:setFloat(k .. "#vanillaSpeedKmh", data.vanillaSpeed or 0)
        xml:setFloat(k .. "#throughputTph", data.throughputTph or 0)
        xml:setFloat(k .. "#massFlowKgS", data.massFlowKgS or 0)
        xml:setFloat(k .. "#engineLoadPct", data.engineLoad or 0)
        xml:setFloat(k .. "#cropLossPct", data.cropLoss or 0)
        xml:setFloat(k .. "#eSpec", data.eSpec or 0)
        xml:setFloat(k .. "#moisture", data.moisture or 0)
        xml:setFloat(k .. "#density", data.density or 0.75)
        xml:setFloat(k .. "#lpsqm", data.lpsqm or 0.85)
        xml:setFloat(k .. "#pBase", data.pBase or 0)
        xml:setFloat(k .. "#pHeader", data.pHeader or 0)
        xml:setFloat(k .. "#pProcess", data.pProcess or 0)
        xml:setFloat(k .. "#pSoil", data.pSoil or 0)
        xml:setFloat(k .. "#pTotal", data.pTotal or 0)

        xml:save()
        xml:delete()
    end
end

---EN: Records a diagnostic sample, prints formatted report, logs CSV, and saves XML.
---UA: Записує діагностичний зразок, друкує звіт, додає CSV рядок та зберігає в XML.
function RHM_DiagnosticTool:recordSample(vehicle, isAuto)
    local data = self:extractVehicleData(vehicle)
    if not data then
        print("RHM: Failed to record sample - vehicle telemetry not available.")
        return false
    end

    table.insert(self.sessionRecords, data)
    local recordId = #self.sessionRecords

    -- 1. PRINT FORMATTED REPORT BLOCK TO CONSOLE / LOG.TXT
    local autoTag = isAuto and "[AUTO-RECORDED]" or "[MANUAL RECORD]"
    print("================================================================================")
    print(string.format("                 [RHM CROP HARVEST TEST RECORD #%d] %s", recordId, autoTag))
    print("================================================================================")
    print(string.format("Timestamp:     %s", data.timestamp))
    print(string.format("Vehicle:       %s (%.1f HP) | Category: %s [%s]", data.vehicleName, data.engineHp, data.category, data.machineType))
    print(string.format("Header:        %s (Width: %.1fm | PTO: %.1f HP)", data.headerName, data.headerWidth, data.headerHp))
    print(string.format("Crop:          %s (Fruit: %d, Fill: %s) | Density: %.2f kg/L | Base l/m2: %.2f", data.fruitName, data.fruitType, data.fillName, data.density, data.lpsqm))
    print(string.format("Field Yield:   %.2f t/ha (Nominal Ref: %.2f t/ha | Ratio: %.2f)", data.actualYield, data.yRef, data.yieldRatio))
    print(string.format("Throughput:    %.1f t/h (%.2f kg/s) | Moisture: %.1f%%", data.throughputTph, data.massFlowKgS, data.moisture))
    print(string.format("Speed:         %.1f km/h (RHM Target: %.1f km/h | Vanilla Limit: %.1f km/h)", data.currentSpeed, data.targetSpeed, data.vanillaSpeed))
    print(string.format("Engine Load:   %.1f%% (Loss: %.1f%%)", data.engineLoad, data.cropLoss))
    print("--------------------------------------------------------------------------------")
    print("POWER BALANCE BREAKDOWN:")
    print(string.format("  P_base:      %5.1f HP (Hydrostatic & driveline losses)", data.pBase))
    print(string.format("  P_header:    %5.1f HP (Cutter/topper/stripper rotation)", data.pHeader))
    print(string.format("  P_process:   %5.1f HP (Threshing/chopping/webs | E_spec = %.2f HP/(t/h))", data.pProcess, data.eSpec))
    print(string.format("  P_soil:      %5.1f HP (Subsurface share cutting resistance in ground)", data.pSoil))
    print(string.format("  TOTAL:       %5.1f / %.1f HP (%.1f%% load)", data.pTotal, data.effectiveHp, data.engineLoad))
    print("================================================================================")

    -- 2. PRINT MACHINE-READABLE CSV LINE TO LOG.TXT
    -- Format: [RHM_CSV];ID;Timestamp;Crop;Vehicle;HP;Width;Yield;NominalYield;Speed;TargetSpeed;Tph;Load;ESpec;PBase;PHeader;PProcess;PSoil;PTotal
    local csvLine = string.format("[RHM_CSV];%d;%s;%s;%s;%.1f;%.1f;%.2f;%.2f;%.1f;%.1f;%.1f;%.1f;%.2f;%.1f;%.1f;%.1f;%.1f;%.1f",
        recordId, data.timestamp, data.fruitName, data.vehicleName, data.engineHp, data.headerWidth,
        data.actualYield, data.yRef, data.currentSpeed, data.targetSpeed, data.throughputTph, data.engineLoad,
        data.eSpec, data.pBase, data.pHeader, data.pProcess, data.pSoil, data.pTotal)
    print(csvLine)

    -- 3. PERSIST TO XML
    self:saveRecordToXml(data)

    -- 4. ON-SCREEN BANNER NOTIFICATION
    if g_currentMission and g_currentMission.showBlinkingWarning then
        local msg = string.format("RHM Record #%d: %s | %.1f km/h | %.0f%% Load | %.1f t/ha | %s",
            recordId, data.fruitName, data.currentSpeed, data.engineLoad, data.actualYield, data.vehicleName)
        g_currentMission:showBlinkingWarning(msg, 4000)
    end

    return true
end

---EN: Periodic check in updateTick for automated test sampling.
---UA: Періодична перевірка в updateTick для автоматичного збору зразків.
function RHM_DiagnosticTool:checkAutoRecord(vehicle, dt)
    if not self.autoRecordEnabled or not vehicle or not vehicle.spec_rhm_Combine then
        return
    end

    local rhmSpec = vehicle.spec_rhm_Combine
    local calc = rhmSpec.loadCalculator
    if not calc then return end

    local vehId = vehicle.rootNode or vehicle
    local massFlow = calc.currentAvgMass or 0
    local speed = (vehicle.getLastSpeed and vehicle:getLastSpeed()) or 0

    -- Only sample when vehicle is actively harvesting stably at reasonable speed
    if massFlow > 0.5 and speed > 1.0 and (calc.harvestActiveTime or 0) > 4000 then
        self.harvestStableTime[vehId] = (self.harvestStableTime[vehId] or 0) + dt
        
        -- Stable continuous harvest for at least 3.5 seconds after feederhouse is full
        if self.harvestStableTime[vehId] >= 3500 then
            local crop = tostring(calc.currentCrop or "UNKNOWN")
            local key = string.format("%s_%s", tostring(vehId), crop)

            if not self.recordedThisPass[key] then
                self.recordedThisPass[key] = true
                self:recordSample(vehicle, true)
            end
        end
    else
        self.harvestStableTime[vehId] = 0
        -- Reset pass latch after leaving crop or stopping (> 2 seconds empty)
        if (calc.idleHarvestTime or 0) > 2000 then
            local crop = tostring(calc.currentCrop or "UNKNOWN")
            local key = string.format("%s_%s", tostring(vehId), crop)
            self.recordedThisPass[key] = nil
        end
    end
end

---EN: Console command: rhm_record (Records manual test sample of active combine).
---UA: Консольна команда: rhm_record (Записує зразок для активного комбайна).
function RHM_DiagnosticTool:consoleCommandRecord()
    local vehicle = self:findActiveCombine()
    if not vehicle then
        print("RHM: No active combine found to record test data.")
        return "No active combine found. Enter a combine or start harvesting."
    end

    local success = self:recordSample(vehicle, false)
    if success then
        return string.format("RHM: Crop harvest test recorded (Total records: %d). See console / log.txt.", #self.sessionRecords)
    else
        return "RHM: Failed to record sample."
    end
end

---EN: Console command: rhm_auto_record [on|off] (Toggles automatic test recording).
---UA: Консольна команда: rhm_auto_record [on|off] (Вмикає/вимикає автозапис тестів).
function RHM_DiagnosticTool:consoleCommandAuto(arg)
    if arg ~= nil and arg ~= "" then
        arg = string.lower(tostring(arg))
        if arg == "1" or arg == "true" or arg == "on" then
            self.autoRecordEnabled = true
        elseif arg == "0" or arg == "false" or arg == "off" then
            self.autoRecordEnabled = false
        end
    else
        self.autoRecordEnabled = not self.autoRecordEnabled
    end

    local stateStr = self.autoRecordEnabled and "ENABLED (ON)" or "DISABLED (OFF)"
    print(string.format("RHM: Crop Test Auto-Recording is now %s.", stateStr))
    if g_currentMission and g_currentMission.showBlinkingWarning then
        g_currentMission:showBlinkingWarning(string.format("RHM: Test Auto-Record is %s", stateStr), 3000)
    end
    return string.format("RHM Auto-Record: %s. Drive through fields to automatically log test samples.", stateStr)
end

---EN: Console command: rhm_dump_records (Prints summary table of all recorded tests).
---UA: Консольна команда: rhm_dump_records (Виводить підсумкову таблицю всіх тестів).
function RHM_DiagnosticTool:consoleCommandDump()
    if #self.sessionRecords == 0 then
        print("RHM: No test records in this session yet. Use 'rhm_record' or enable 'rhm_auto_record on'.")
        return "No records found."
    end

    print("========================================================================================================================")
    print("                                      RHM CROP HARVEST TEST SESSION SUMMARY")
    print("========================================================================================================================")
    print(string.format("%-3s | %-12s | %-20s | %-6s | %-6s | %-8s | %-7s | %-6s | %-7s | %-6s | %-10s",
        "#", "Crop", "Vehicle", "HP", "Width", "Yield", "Speed", "Load", "Tph", "E_spec", "P_tot/P_eng"))
    print("----+--------------+----------------------+--------+--------+----------+---------+--------+---------+--------+-----------")

    for i, r in ipairs(self.sessionRecords) do
        print(string.format("%-3d | %-12s | %-20s | %5.0fHP | %4.1fm | %6.1ft/h | %5.1fkm | %5.1f%% | %5.1ft/h | %5.2f  | %5.1f/%-5.1f",
            i, r.fruitName:sub(1, 12), r.vehicleName:sub(1, 20), r.engineHp, r.headerWidth,
            r.actualYield, r.currentSpeed, r.engineLoad, r.throughputTph, r.eSpec, r.pTotal, r.effectiveHp))
    end
    print("========================================================================================================================")
    return string.format("Total %d test records dumped to console.", #self.sessionRecords)
end

---EN: Console command: rhm_clear_records (Clears records from memory and resets XML).
---UA: Консольна команда: rhm_clear_records (Очищує записи з пам'яті та скидає XML).
function RHM_DiagnosticTool:consoleCommandClear()
    self.sessionRecords = {}
    self.recordedThisPass = {}
    local xmlPath = self:getXmlFilePath()
    if xmlPath and fileExists(xmlPath) then
        local xml = XMLFile.create("RHM_CropTestRecords", xmlPath, "cropTestRecords")
        if xml then
            xml:save()
            xml:delete()
        end
    end
    print("RHM: Crop test records cleared.")
    return "All test records cleared."
end

---EN: Console command: rhm_inspect (Detailed live vehicle inspection).
---UA: Консольна команда: rhm_inspect (Детальний живий огляд комбайна).
function RHM_DiagnosticTool:consoleCommandInspect()
    local vehicle = self:findActiveCombine()
    if not vehicle then
        print("RHM: No active combine found.")
        return "No active combine found."
    end

    local rhmSpec = vehicle.spec_rhm_Combine
    local calc = rhmSpec.loadCalculator
    local data = self:extractVehicleData(vehicle)
    if not data then
        print("RHM: Telemetry not available.")
        return "Telemetry not available."
    end

    print("=====================================================")
    print(" RHM LIVE COMBINE INSPECTION")
    print("=====================================================")
    print(string.format("Vehicle: %s (%.1f HP)", data.vehicleName, data.engineHp))
    print(string.format("Category: %s | MachineType: %s", data.category, data.machineType))
    print(string.format("Header: %s (Width: %.1fm | PTO: %.1f HP)", data.headerName, data.headerWidth, data.headerHp))
    print(string.format("Crop: %s (Fruit: %d, Fill: %s)", data.fruitName, data.fruitType, data.fillName))
    print(string.format("Yield: %.2f t/ha (Nominal Ref: %.2f t/ha)", data.actualYield, data.yRef))
    print(string.format("Speed: %.1f km/h (Limit: %.1f km/h | Max: %.1f km/h)", data.currentSpeed, data.targetSpeed, data.vanillaSpeed))
    print(string.format("Throughput: %.1f t/h (%.2f kg/s) | Load: %.1f%%", data.throughputTph, data.massFlowKgS, data.engineLoad))
    print(string.format("E_spec: %.2f HP/(t/h) | Moisture: %.1f%%", data.eSpec, data.moisture))
    print(string.format("Power Balance: Base=%.1f HP, Header=%.1f HP, Process=%.1f HP, Soil=%.1f HP -> Total: %.1f / %.1f HP",
        data.pBase, data.pHeader, data.pProcess, data.pSoil, data.pTotal, data.effectiveHp))
    print("=====================================================")
    return "Inspection completed. See console for details."
end

-- Initialize Console Commands
if not RHM_DiagnosticTool.initialized then
    addConsoleCommand("rhm_inspect", "Prints live diagnostic info for the current RHM harvester.", "consoleCommandInspect", RHM_DiagnosticTool)
    addConsoleCommand("rhm_record", "Captures and records a harvest test sample for the current crop.", "consoleCommandRecord", RHM_DiagnosticTool)
    addConsoleCommand("rhm_test", "Alias for rhm_record (captures crop test sample).", "consoleCommandRecord", RHM_DiagnosticTool)
    addConsoleCommand("rhm_auto_record", "Toggles automatic recording of test samples while harvesting [on|off].", "consoleCommandAuto", RHM_DiagnosticTool)
    addConsoleCommand("rhm_dump_records", "Prints a summary table of all recorded crop tests in this session.", "consoleCommandDump", RHM_DiagnosticTool)
    addConsoleCommand("rhm_clear_records", "Clears all recorded crop test samples.", "consoleCommandClear", RHM_DiagnosticTool)
    RHM_DiagnosticTool.initialized = true
    rhm_log("RHM: Diagnostic & Test Suite initialized. Commands: rhm_record, rhm_auto_record, rhm_dump_records, rhm_inspect.")
end
