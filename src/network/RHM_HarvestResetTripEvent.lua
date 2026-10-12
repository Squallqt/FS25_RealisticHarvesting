-- ============================================================================
-- RHM_HarvestResetTripEvent.lua
-- Realistic Harvesting Mod - Trip Odometer Reset Request & Broadcast Event
-- ============================================================================
-- Technical architecture:
--   Bi-directional:
--     Client -> Server: Sends request to reset active field trip odometer.
--     Server: Validates farm permissions, archives trip, resets to 0.
--     Server -> Clients: Broadcasts confirmation to reset local client display.
-- ============================================================================

RHM_HarvestResetTripEvent = {}
local HarvestResetTripEvent_mt = Class(RHM_HarvestResetTripEvent, Event)

InitEventClass(RHM_HarvestResetTripEvent, "RHM_HarvestResetTripEvent")

function RHM_HarvestResetTripEvent.emptyNew()
    return Event.new(HarvestResetTripEvent_mt)
end

function RHM_HarvestResetTripEvent.new(farmId, vehicleOrKey, record, machineKey)
    local self = RHM_HarvestResetTripEvent.emptyNew()
    self.farmId = farmId or 1
    if type(vehicleOrKey) == "table" then
        self.vehicle = vehicleOrKey
        self.machineKey = machineKey or (RHM_HarvestTracker and RHM_HarvestTracker.getMachineKey and RHM_HarvestTracker.getMachineKey(vehicleOrKey)) or ""
    elseif type(vehicleOrKey) == "string" then
        self.machineKey = vehicleOrKey
        self.vehicle = nil
    else
        self.vehicle = nil
        self.machineKey = machineKey or ""
    end
    self.record = record
    return self
end

function RHM_HarvestResetTripEvent:writeStream(streamId, connection)
    streamWriteUInt8(streamId, self.farmId)
    NetworkUtil.writeNodeObject(streamId, self.vehicle)
    streamWriteString(streamId, self.machineKey or "")
    local hasRecord = (self.record ~= nil and type(self.record) == "table" and (self.record.fieldId or 0) > 0)
    streamWriteBool(streamId, hasRecord)
    if hasRecord then
        local rec = self.record
        streamWriteInt32(streamId, rec.year or 1)
        streamWriteInt32(streamId, rec.fieldId or 0)
        streamWriteString(streamId, rec.cropName or "--")
        streamWriteFloat32(streamId, rec.harvested or 0)
        streamWriteFloat32(streamId, rec.harvestedMassKg or 0)
        streamWriteFloat32(streamId, rec.lost or 0)
        streamWriteFloat32(streamId, rec.lossMoney or 0)
        streamWriteFloat32(streamId, rec.fuelUsed or 0)
        streamWriteFloat32(streamId, rec.areaHa or 0)
        streamWriteString(streamId, rec.efficiencyRank or "A")
        streamWriteString(streamId, rec.dominantReason or "speed")
        streamWriteBool(streamId, rec.isContract == true)
        streamWriteString(streamId, rec.machineName or "")
        streamWriteString(streamId, tostring(rec.timestamp or ""))
    end
end

function RHM_HarvestResetTripEvent:readStream(streamId, connection)
    self.farmId = streamReadUInt8(streamId)
    self.vehicle = NetworkUtil.readNodeObject(streamId)
    self.machineKey = streamReadString(streamId)
    local hasRecord = streamReadBool(streamId)
    if hasRecord then
        self.record = {
            year = streamReadInt32(streamId),
            fieldId = streamReadInt32(streamId),
            cropName = streamReadString(streamId),
            harvested = streamReadFloat32(streamId),
            harvestedMassKg = streamReadFloat32(streamId),
            lost = streamReadFloat32(streamId),
            lossMoney = streamReadFloat32(streamId),
            fuelUsed = streamReadFloat32(streamId),
            areaHa = streamReadFloat32(streamId),
            efficiencyRank = streamReadString(streamId),
            dominantReason = streamReadString(streamId),
            isContract = streamReadBool(streamId),
            machineName = streamReadString(streamId),
            timestamp = streamReadString(streamId)
        }
    end
    self:run(connection)
end

function RHM_HarvestResetTripEvent:run(connection)
    local tracker = g_realisticHarvestManager and g_realisticHarvestManager.harvestTracker
    if not tracker then return end

    if connection and not connection:getIsServer() then
        -- Server validates permissions and executes reset (received from remote client)
        local user = g_currentMission.userManager and g_currentMission.userManager:getUserByConnection(connection)
        
        local combineObj = self.vehicle
        local vehicles = (g_currentMission.vehicleSystem and g_currentMission.vehicleSystem.vehicles) or g_currentMission.vehicles
        if not combineObj and vehicles and self.machineKey and self.machineKey ~= "" then
            for _, v in pairs(vehicles) do
                if v and v.spec_rhm_Combine then
                    local mk = (RHM_HarvestTracker and RHM_HarvestTracker.getMachineKey and RHM_HarvestTracker.getMachineKey(v)) or v.configFileName
                    if mk == self.machineKey or (v.configFileName and self.machineKey:sub(1, #v.configFileName) == v.configFileName) then
                        combineObj = v
                        break
                    end
                end
            end
        end

        if combineObj then
            tracker:resetTripForCombine(self.farmId, combineObj, user)
        elseif self.machineKey and self.machineKey ~= "" then
            local record = tracker:archiveAndResetCombineTrip(self.farmId, self.machineKey, nil)
            if g_server then
                g_server:broadcastEvent(RHM_HarvestResetTripEvent.new(self.farmId, nil, type(record) == "table" and record or nil, self.machineKey), nil, nil, nil)
            end
        else
            tracker:resetTrip(self.farmId, user)
        end
    else
        -- Client received broadcast confirmation from server: clear local display & add archived record
        local farm = tracker:getFarmData(self.farmId)
        if farm then
            if farm.currentTrip then
                farm.currentTrip.harvestedLiters = 0
                farm.currentTrip.harvestedMassKg = 0
                farm.currentTrip.harvestedAreaHa = 0
                farm.currentTrip.lostLiters = 0
                farm.currentTrip.lossMoney = 0
                farm.currentTrip.fuelUsedL = 0
                farm.currentTrip.sessionDuration = 0
                farm.currentTrip.avgSpeedSum = 0
                farm.currentTrip.avgSpeedCount = 0
                farm.currentTrip.avgLoadSum = 0
                farm.currentTrip.avgLoadCount = 0
                farm.currentTrip.efficiencyRank = RHM_HarvestTracker.RANK_A
                farm.currentTrip.reasons = { speed = 0, settings = 0, moisture = 0, wear = 0, slope = 0 }
                farm.currentTrip.isActive = false
                farm.currentTrip.fieldId = 0
                farm.currentTrip.isContract = false
                farm.currentTrip.cropName = "--"
                farm.currentTrip.fillTypeIndex = FillType.UNKNOWN
            end
            if self.vehicle and self.vehicle.spec_rhm_Combine then
                if self.vehicle.resetTrip then self.vehicle:resetTrip() end
                local mKey = (RHM_HarvestTracker and RHM_HarvestTracker.getMachineKey and RHM_HarvestTracker.getMachineKey(self.vehicle)) or self.vehicle.configFileName
                if farm.combineTrips and farm.combineTrips[mKey] then
                    local mTrip = farm.combineTrips[mKey]
                    mTrip.harvestedLiters = 0
                    mTrip.harvestedMassKg = 0
                    mTrip.harvestedAreaHa = 0
                    mTrip.lostLiters = 0
                    mTrip.lossMoney = 0
                    mTrip.fuelUsedL = 0
                    mTrip.sessionDuration = 0
                    mTrip.avgSpeedSum = 0
                    mTrip.avgSpeedCount = 0
                    mTrip.avgLoadSum = 0
                    mTrip.avgLoadCount = 0
                    mTrip.efficiencyRank = RHM_HarvestTracker.RANK_A
                    mTrip.reasons = { speed = 0, settings = 0, moisture = 0, wear = 0, slope = 0 }
                    mTrip.isActive = false
                    mTrip.fieldId = 0
                    mTrip.isContract = false
                    mTrip.cropName = "--"
                    mTrip.fillTypeIndex = FillType.UNKNOWN
                end
            end
            if farm.combineTrips then
                local cfg = (self.vehicle and self.vehicle.configFileName)
                for k, mTrip in pairs(farm.combineTrips) do
                    local match = (self.machineKey and self.machineKey ~= "" and (k == self.machineKey or k:find(self.machineKey, 1, true) ~= nil))
                        or (cfg and (k == cfg or k:sub(1, #cfg) == cfg))
                    if match and mTrip then
                        mTrip.harvestedLiters = 0
                        mTrip.harvestedMassKg = 0
                        mTrip.harvestedAreaHa = 0
                        mTrip.lostLiters = 0
                        mTrip.lossMoney = 0
                        mTrip.fuelUsedL = 0
                        mTrip.sessionDuration = 0
                        mTrip.avgSpeedSum = 0
                        mTrip.avgSpeedCount = 0
                        mTrip.avgLoadSum = 0
                        mTrip.avgLoadCount = 0
                        mTrip.efficiencyRank = RHM_HarvestTracker.RANK_A
                        mTrip.reasons = { speed = 0, settings = 0, moisture = 0, wear = 0, slope = 0 }
                        mTrip.isActive = false
                        mTrip.fieldId = 0
                        mTrip.isContract = false
                        mTrip.cropName = "--"
                        mTrip.fillTypeIndex = FillType.UNKNOWN
                    end
                end
            end
            if self.record and type(self.record) == "table" and (self.record.fieldId or 0) > 0 then
                farm.seasonHistory = farm.seasonHistory or {}
                table.insert(farm.seasonHistory, 1, self.record)
                if #farm.seasonHistory > 50 then
                    table.remove(farm.seasonHistory)
                end
            end
        end

        -- Mirror directly to active client combine vehicle instances
        local vehicles = (g_currentMission.vehicleSystem and g_currentMission.vehicleSystem.vehicles) or g_currentMission.vehicles
        if vehicles then
            for _, vehicle in pairs(vehicles) do
                if vehicle and type(vehicle) == "table" and vehicle.spec_rhm_Combine then
                    local vFarmId = (vehicle.getOwnerFarmId and vehicle:getOwnerFarmId()) or 1
                    if vFarmId == self.farmId then
                        local mKey = (RHM_HarvestTracker and RHM_HarvestTracker.getMachineKey and RHM_HarvestTracker.getMachineKey(vehicle)) or vehicle.configFileName
                        local isTarget = not self.machineKey or self.machineKey == ""
                            or mKey == self.machineKey
                            or vehicle == self.vehicle
                            or (vehicle.configFileName and self.machineKey and self.machineKey:find(vehicle.configFileName, 1, true) ~= nil)
                        if isTarget then
                            if vehicle.resetTrip then vehicle:resetTrip() end
                            if farm and farm.combineTrips and farm.combineTrips[mKey] then
                                vehicle.spec_rhm_Combine.trip = farm.combineTrips[mKey]
                            elseif farm then
                                vehicle.spec_rhm_Combine.trip = farm.currentTrip
                            end
                        end
                    end
                end
            end
        end

        if g_realisticHarvestManager and g_realisticHarvestManager.harvestHistoryGUI and g_realisticHarvestManager.harvestHistoryGUI.isOpen then
            g_realisticHarvestManager.harvestHistoryGUI:refreshCurrentPage()
        end
    end
end
