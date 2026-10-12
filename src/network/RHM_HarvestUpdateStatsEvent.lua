-- ============================================================================
-- RHM_HarvestUpdateStatsEvent.lua
-- Realistic Harvesting Mod - Lightweight Periodic Field Trip Delta Event
-- ============================================================================
-- Technical architecture:
--   Broadcasts live currentTrip metrics from Server to Clients for a specific farm.
--   Runs Server -> Client at ~1Hz interval when active.
-- ============================================================================

RHM_HarvestUpdateStatsEvent = {}
local HarvestUpdateStatsEvent_mt = Class(RHM_HarvestUpdateStatsEvent, Event)

InitEventClass(RHM_HarvestUpdateStatsEvent, "RHM_HarvestUpdateStatsEvent")

function RHM_HarvestUpdateStatsEvent.emptyNew()
    return Event.new(HarvestUpdateStatsEvent_mt)
end

function RHM_HarvestUpdateStatsEvent.new(farmId, trip)
    local self = RHM_HarvestUpdateStatsEvent.emptyNew()
    self.farmId = farmId or 1
    self.trip = trip
    return self
end

function RHM_HarvestUpdateStatsEvent:writeStream(streamId, connection)
    streamWriteUInt8(streamId, self.farmId)
    local trip = self.trip or {}

    streamWriteInt32(streamId, trip.fieldId or 0)
    streamWriteString(streamId, trip.cropName or "UNKNOWN")
    streamWriteInt32(streamId, trip.fillTypeIndex or FillType.UNKNOWN)
    streamWriteFloat32(streamId, trip.harvestedLiters or 0)
    streamWriteFloat32(streamId, trip.harvestedMassKg or 0)
    streamWriteFloat32(streamId, trip.harvestedAreaHa or 0)
    streamWriteFloat32(streamId, trip.lostLiters or 0)
    streamWriteFloat32(streamId, trip.lossMoney or 0)
    streamWriteFloat32(streamId, trip.fuelUsedL or 0)
    streamWriteFloat32(streamId, trip.sessionDuration or 0)
    streamWriteString(streamId, trip.efficiencyRank or "A")

    local reasons = trip.reasons or {}
    streamWriteFloat32(streamId, reasons.speed or 0)
    streamWriteFloat32(streamId, reasons.settings or 0)
    streamWriteFloat32(streamId, reasons.moisture or 0)
    streamWriteFloat32(streamId, reasons.wear or 0)
    streamWriteFloat32(streamId, reasons.slope or 0)

    streamWriteFloat32(streamId, trip.avgSpeedSum or 0)
    streamWriteUInt32(streamId, trip.avgSpeedCount or 0)
    streamWriteFloat32(streamId, trip.avgLoadSum or 0)
    streamWriteUInt32(streamId, trip.avgLoadCount or 0)
    streamWriteBool(streamId, trip.isActive == true)
    streamWriteBool(streamId, trip.isContract == true)
    streamWriteString(streamId, trip.lastMachineKey or "")

    local tracker = g_realisticHarvestManager and g_realisticHarvestManager.harvestTracker
    local fStat = nil
    if tracker and trip and trip.fieldId and trip.fieldId > 0 then
        local farm = tracker:getFarmData(self.farmId)
        if farm and farm.fieldStats then
            fStat = farm.fieldStats[trip.fieldId]
        end
    end
    local hasFStat = (fStat ~= nil)
    streamWriteBool(streamId, hasFStat)
    if hasFStat then
        streamWriteInt32(streamId, fStat.fieldId or trip.fieldId)
        streamWriteFloat32(streamId, fStat.harvestedLiters or 0)
        streamWriteFloat32(streamId, fStat.harvestedMassKg or 0)
        streamWriteFloat32(streamId, fStat.harvestedAreaHa or 0)
        streamWriteFloat32(streamId, fStat.lostLiters or 0)
        streamWriteFloat32(streamId, fStat.lossMoney or 0)
        streamWriteFloat32(streamId, fStat.fuelUsedL or 0)
        streamWriteFloat32(streamId, fStat.sessionDuration or 0)
        streamWriteUInt16(streamId, fStat.operationsCount or 1)
        streamWriteBool(streamId, fStat.isContract == true)
        streamWriteString(streamId, fStat.lastCrop or fStat.lastCropName or trip.cropName or "--")
        local fReasons = fStat.reasons or {}
        streamWriteFloat32(streamId, fReasons.speed or 0)
        streamWriteFloat32(streamId, fReasons.settings or 0)
        streamWriteFloat32(streamId, fReasons.moisture or 0)
        streamWriteFloat32(streamId, fReasons.wear or 0)
        streamWriteFloat32(streamId, fReasons.slope or 0)
    end
end

function RHM_HarvestUpdateStatsEvent:readStream(streamId, connection)
    self.farmId = streamReadUInt8(streamId)

    local tracker = g_realisticHarvestManager and g_realisticHarvestManager.harvestTracker
    if tracker then
        local farm = tracker:getFarmData(self.farmId)
        local trip = farm.currentTrip

        trip.fieldId = streamReadInt32(streamId)
        trip.cropName = streamReadString(streamId)
        trip.fillTypeIndex = streamReadInt32(streamId)
        trip.harvestedLiters = streamReadFloat32(streamId)
        trip.harvestedMassKg = streamReadFloat32(streamId)
        trip.harvestedAreaHa = streamReadFloat32(streamId)
        trip.lostLiters = streamReadFloat32(streamId)
        trip.lossMoney = streamReadFloat32(streamId)
        trip.fuelUsedL = streamReadFloat32(streamId)
        trip.sessionDuration = streamReadFloat32(streamId)
        trip.efficiencyRank = streamReadString(streamId)

        trip.reasons = trip.reasons or {}
        trip.reasons.speed = streamReadFloat32(streamId)
        trip.reasons.settings = streamReadFloat32(streamId)
        trip.reasons.moisture = streamReadFloat32(streamId)
        trip.reasons.wear = streamReadFloat32(streamId)
        trip.reasons.slope = streamReadFloat32(streamId)

        trip.avgSpeedSum = streamReadFloat32(streamId)
        trip.avgSpeedCount = streamReadUInt32(streamId)
        trip.avgLoadSum = streamReadFloat32(streamId)
        trip.avgLoadCount = streamReadUInt32(streamId)
        trip.isActive = streamReadBool(streamId)
        trip.isContract = streamReadBool(streamId)
        local lmk = streamReadString(streamId)
        if lmk and lmk ~= "" then
            trip.lastMachineKey = lmk
            farm.combineTrips = farm.combineTrips or {}
            if not farm.combineTrips[lmk] then
                farm.combineTrips[lmk] = {}
            end
            local mTrip = farm.combineTrips[lmk]
            mTrip.fieldId = trip.fieldId
            mTrip.cropName = trip.cropName
            mTrip.fillTypeIndex = trip.fillTypeIndex
            mTrip.harvestedLiters = trip.harvestedLiters
            mTrip.harvestedMassKg = trip.harvestedMassKg
            mTrip.harvestedAreaHa = trip.harvestedAreaHa
            mTrip.lostLiters = trip.lostLiters
            mTrip.lossMoney = trip.lossMoney
            mTrip.fuelUsedL = trip.fuelUsedL
            mTrip.sessionDuration = trip.sessionDuration
            mTrip.efficiencyRank = trip.efficiencyRank
            mTrip.reasons = {
                speed = trip.reasons and trip.reasons.speed or 0,
                settings = trip.reasons and trip.reasons.settings or 0,
                moisture = trip.reasons and trip.reasons.moisture or 0,
                wear = trip.reasons and trip.reasons.wear or 0,
                slope = trip.reasons and trip.reasons.slope or 0
            }
            mTrip.avgSpeedSum = trip.avgSpeedSum
            mTrip.avgSpeedCount = trip.avgSpeedCount
            mTrip.avgLoadSum = trip.avgLoadSum
            mTrip.avgLoadCount = trip.avgLoadCount
            mTrip.isActive = trip.isActive
            mTrip.isContract = trip.isContract
        end

        local hasFStat = streamReadBool(streamId)
        if hasFStat then
            local fid = streamReadInt32(streamId)
            farm.fieldStats = farm.fieldStats or {}
            if not farm.fieldStats[fid] then
                farm.fieldStats[fid] = { fieldId = fid }
            end
            local fs = farm.fieldStats[fid]
            fs.fieldId = fid
            fs.harvestedLiters = streamReadFloat32(streamId)
            fs.harvestedMassKg = streamReadFloat32(streamId)
            fs.harvestedAreaHa = streamReadFloat32(streamId)
            fs.lostLiters = streamReadFloat32(streamId)
            fs.lossMoney = streamReadFloat32(streamId)
            fs.fuelUsedL = streamReadFloat32(streamId)
            fs.sessionDuration = streamReadFloat32(streamId)
            fs.operationsCount = streamReadUInt16(streamId)
            fs.isContract = streamReadBool(streamId)
            fs.lastCrop = streamReadString(streamId)
            fs.lastCropName = fs.lastCrop
            fs.reasons = fs.reasons or {}
            fs.reasons.speed = streamReadFloat32(streamId)
            fs.reasons.settings = streamReadFloat32(streamId)
            fs.reasons.moisture = streamReadFloat32(streamId)
            fs.reasons.wear = streamReadFloat32(streamId)
            fs.reasons.slope = streamReadFloat32(streamId)
        end

        -- Mirror directly to active client combine vehicle instances
        local vehicles = nil
        if g_currentMission.vehicleSystem then
            if g_currentMission.vehicleSystem.getVehicles then
                vehicles = g_currentMission.vehicleSystem:getVehicles()
            elseif g_currentMission.vehicleSystem.vehicles then
                vehicles = g_currentMission.vehicleSystem.vehicles
            end
        elseif g_currentMission.vehicles then
            vehicles = g_currentMission.vehicles
        end

        if vehicles then
            for _, vehicle in pairs(vehicles) do
                if vehicle and type(vehicle) == "table" and vehicle.spec_rhm_Combine then
                    local vFarmId = (vehicle.getOwnerFarmId and vehicle:getOwnerFarmId()) or 1
                    if vFarmId == self.farmId then
                        local mKey = (RHM_HarvestTracker and RHM_HarvestTracker.getMachineKey and RHM_HarvestTracker.getMachineKey(vehicle)) or vehicle.configFileName
                        local isMatch = false
                        if lmk and lmk ~= "" then
                            if mKey == lmk then
                                isMatch = true
                            elseif vehicle.configFileName and lmk:sub(1, #vehicle.configFileName) == vehicle.configFileName then
                                isMatch = true
                            end
                        end
                        if isMatch or (vehicle.getIsEntered and vehicle:getIsEntered()) or (vehicle.getIsControlled and vehicle:getIsControlled()) then
                            vehicle.spec_rhm_Combine.trip = (farm.combineTrips and farm.combineTrips[mKey]) or farm.currentTrip
                        end
                    end
                end
            end
        end

        -- Direct safeguard for the player's actively controlled vehicle
        if g_currentMission and g_currentMission.controlledVehicle and g_currentMission.controlledVehicle.spec_rhm_Combine then
            local cv = g_currentMission.controlledVehicle
            local cvFarmId = (cv.getOwnerFarmId and cv:getOwnerFarmId()) or 1
            if cvFarmId == self.farmId then
                local mKey = (RHM_HarvestTracker and RHM_HarvestTracker.getMachineKey and RHM_HarvestTracker.getMachineKey(cv)) or cv.configFileName
                cv.spec_rhm_Combine.trip = (farm.combineTrips and farm.combineTrips[mKey]) or farm.currentTrip
            end
        end
    end

    self:run(connection)
end

function RHM_HarvestUpdateStatsEvent:run(connection)
    -- Notify GUI if open on this client
    if g_realisticHarvestManager and g_realisticHarvestManager.harvestHistoryGUI and g_realisticHarvestManager.harvestHistoryGUI.isOpen then
        g_realisticHarvestManager.harvestHistoryGUI:refreshCurrentPage()
    end
end
