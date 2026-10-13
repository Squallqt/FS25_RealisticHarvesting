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

local function clearTrip(trip, keepField)
    if not trip then return end
    for _, field in ipairs({ "harvestedLiters", "harvestedMassKg", "harvestedAreaHa", "lostLiters", "lossMoney", "fuelUsedL",
        "sessionDuration", "avgSpeedSum", "avgSpeedCount", "avgLoadSum", "avgLoadCount" }) do
        trip[field] = 0
    end
    trip.efficiencyRank = RHM_HarvestTracker.RANK_A
    trip.reasons = { speed = 0, settings = 0, moisture = 0, wear = 0, slope = 0 }
    trip.isActive = false
    if not keepField then
        trip.fieldId = 0
        trip.isContract = false
        trip.cropName = "--"
        trip.fillTypeIndex = FillType.UNKNOWN
    end
end

function RHM_HarvestResetTripEvent:run(connection)
    local tracker = g_realisticHarvestManager and g_realisticHarvestManager.harvestTracker
    if not tracker then return end
    local key = self.machineKey or ""
    local vehicles = (g_currentMission.vehicleSystem and g_currentMission.vehicleSystem.vehicles) or g_currentMission.vehicles

    if connection and not connection:getIsServer() then
        local user = g_currentMission.userManager and g_currentMission.userManager:getUserByConnection(connection)
        if not user then return end
        local combine = self.vehicle
        if not combine and key ~= "" then
            for _, vehicle in pairs(vehicles or {}) do
                if vehicle.spec_rhm_Combine and RHM_HarvestTracker.getMachineKey(vehicle) == key then
                    combine = vehicle
                    break
                end
            end
        end
        if combine then
            if combine:getOwnerFarmId() ~= self.farmId then return end
            tracker:resetTripForCombine(self.farmId, combine, user)
        elseif key ~= "" then
            tracker:resetTripForMachineKey(self.farmId, key, user)
        else
            tracker:resetTrip(self.farmId, user)
        end
        return
    end

    local farm = tracker:getFarmData(self.farmId)
    if key == "" and self.vehicle then key = RHM_HarvestTracker.getMachineKey(self.vehicle) end
    if key == "" or farm.currentTrip.lastMachineKey == nil or farm.currentTrip.lastMachineKey == key then
        clearTrip(farm.currentTrip, key == "")
        farm.currentTrip.lastMachineKey = nil
    end
    local notify = false
    if key ~= "" then
        clearTrip(farm.combineTrips and farm.combineTrips[key])
        for _, vehicle in pairs(vehicles or {}) do
            if vehicle.spec_rhm_Combine and vehicle:getOwnerFarmId() == self.farmId
                and (vehicle == self.vehicle or RHM_HarvestTracker.getMachineKey(vehicle) == key) then
                notify = notify or vehicle.spec_rhm_Combine.pendingQuickTripReset == true
                vehicle.spec_rhm_Combine.pendingQuickTripReset = false
                clearTrip(vehicle.spec_rhm_Combine.trip)
                if farm.combineTrips and farm.combineTrips[key] then
                    vehicle.spec_rhm_Combine.trip = farm.combineTrips[key]
                end
            end
        end
    end
    if notify and g_currentMission.showBlinkingWarning then
        local msg = (g_i18n and g_i18n:hasText("rhm_trip_reset_done") and g_i18n:getText("rhm_trip_reset_done")) or "Harvest Trip Reset!"
        g_currentMission:showBlinkingWarning(msg, 2000)
    end
    if self.record and (self.record.fieldId or 0) > 0 then
        table.insert(farm.seasonHistory, 1, self.record)
        if #farm.seasonHistory > 50 then table.remove(farm.seasonHistory) end
    end
    if g_realisticHarvestManager.harvestHistoryGUI and g_realisticHarvestManager.harvestHistoryGUI.isOpen then
        g_realisticHarvestManager.harvestHistoryGUI:refreshCurrentPage()
    end
end
