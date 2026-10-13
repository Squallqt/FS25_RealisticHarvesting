-- ============================================================================
-- RHM_HarvestSyncInitialEvent.lua
-- Realistic Harvesting Mod - Initial Full Farm State Sync Event
-- ============================================================================
-- Technical architecture:
--   Transmits full farm telemetry data (currentTrip, fleetStats, seasonHistory,
--   farmSettings) to a client upon joining or farm switch.
--   Runs Server -> Client.
-- ============================================================================

RHM_HarvestSyncInitialEvent = {}
local HarvestSyncInitialEvent_mt = Class(RHM_HarvestSyncInitialEvent, Event)

InitEventClass(RHM_HarvestSyncInitialEvent, "RHM_HarvestSyncInitialEvent")

function RHM_HarvestSyncInitialEvent.emptyNew()
    return Event.new(HarvestSyncInitialEvent_mt)
end

function RHM_HarvestSyncInitialEvent.new(farmId, farmData)
    local self = RHM_HarvestSyncInitialEvent.emptyNew()
    self.farmId = farmId or 1
    self.farmData = farmData
    return self
end

function RHM_HarvestSyncInitialEvent:writeStream(streamId, connection)
    streamWriteUInt8(streamId, self.farmId)
    streamWriteBool(streamId, self.isDelta == true)

    local tracker = g_realisticHarvestManager and g_realisticHarvestManager.harvestTracker
    local farm = self.farmData or (tracker and tracker:getFarmData(self.farmId))
    if not farm then
        farm = tracker and tracker:createDefaultFarmData() or {}
    end

    -- Current Trip
    local hasTrip = farm.currentTrip ~= nil
    streamWriteBool(streamId, hasTrip)
    if hasTrip then
        local trip = farm.currentTrip
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
    end

    -- Farm Settings
    streamWriteBool(streamId, farm.farmSettings ~= nil)
    if farm.farmSettings then
        local set = farm.farmSettings
        streamWriteBool(streamId, set.aiSpeedLimiter ~= false)
        streamWriteFloat32(streamId, set.aiMaxLossPct or 2.0)
        streamWriteBool(streamId, set.volunteerCrops ~= false)
        streamWriteBool(streamId, set.autoResetOnFieldChange ~= false)
        streamWriteUInt8(streamId, set.autoResetMode or (set.autoResetOnFieldChange ~= false and 1 or 3))
    end

    -- Fleet Stats count & entries (capped at 30, exclude contract/mission combines)
    local fleet = farm.fleetStats or {}
    local fleetList = {}
    for key, v in pairs(fleet) do
        table.insert(fleetList, { key = key, name = v.name or "Harvester", workSeconds = v.workSeconds or 0,
            totalHarvested = v.totalHarvested or 0, totalLost = v.totalLost or 0, isMission = v.isMission, isLeased = v.isLeased })
    end
    streamWriteBool(streamId, self.isDelta ~= true or farm.replaceFleetStats == true)
    streamWriteUInt16(streamId, #fleetList)
    for _, v in ipairs(fleetList) do
        streamWriteString(streamId, v.key)
        streamWriteString(streamId, v.name)
        streamWriteFloat32(streamId, v.workSeconds)
        streamWriteFloat32(streamId, v.totalHarvested)
        streamWriteFloat32(streamId, v.totalLost)
        streamWriteBool(streamId, v.isMission == true)
        streamWriteBool(streamId, v.isLeased == true)
    end

    -- Season History count & entries (capped at 20)
    streamWriteBool(streamId, farm.seasonHistory ~= nil)
    if farm.seasonHistory then
        local history = farm.seasonHistory
        local histCount = #history
        streamWriteUInt16(streamId, histCount)
        for i = 1, histCount do
            local h = history[i]
            streamWriteUInt16(streamId, h.year or 1)
            streamWriteInt32(streamId, h.fieldId or 0)
            streamWriteString(streamId, h.cropName or "UNKNOWN")
            streamWriteFloat32(streamId, h.harvested or 0)
            streamWriteFloat32(streamId, h.harvestedMassKg or 0)
            streamWriteFloat32(streamId, h.lost or 0)
            streamWriteFloat32(streamId, h.lossMoney or 0)
            streamWriteFloat32(streamId, h.areaHa or 0)
            streamWriteString(streamId, h.efficiencyRank or "A")
            streamWriteString(streamId, h.dominantReason or "speed")
            streamWriteBool(streamId, h.isContract == true)
            streamWriteFloat32(streamId, h.fuelUsed or 0)
            streamWriteString(streamId, h.machineName or "")
            streamWriteString(streamId, tostring(h.timestamp or ""))
        end
    end

    -- Yearly Stats count & entries (capped at 20)
    local yearlyList = {}
    if farm.yearlyStats then
        for _, yStat in pairs(farm.yearlyStats) do
            table.insert(yearlyList, yStat)
        end
    end
    streamWriteUInt16(streamId, #yearlyList)
    for _, yStat in ipairs(yearlyList) do
        streamWriteUInt16(streamId, yStat.year or 1)
        streamWriteFloat32(streamId, yStat.harvestedLiters or 0)
        streamWriteFloat32(streamId, yStat.harvestedMassKg or 0)
        streamWriteFloat32(streamId, yStat.harvestedAreaHa or 0)
        streamWriteFloat32(streamId, yStat.lostLiters or 0)
        streamWriteFloat32(streamId, yStat.lossMoney or 0)
        streamWriteFloat32(streamId, yStat.sessionDuration or 0)
        streamWriteFloat32(streamId, yStat.avgSpeedSum or 0)
        streamWriteUInt32(streamId, yStat.avgSpeedCount or 0)
        streamWriteFloat32(streamId, yStat.avgLoadSum or 0)
        streamWriteUInt32(streamId, yStat.avgLoadCount or 0)
        streamWriteUInt16(streamId, yStat.fieldOperations or 0)
        RHM_HarvestSyncInitialEvent.writeStatDetails(streamId, yStat)
    end

    -- Combine Trips count & entries (capped at 20)
    local cList = {}
    if farm.combineTrips then
        for machineKey, mTrip in pairs(farm.combineTrips) do
            table.insert(cList, { machineKey = machineKey, trip = mTrip })
        end
    end
    streamWriteBool(streamId, self.isDelta ~= true or farm.replaceCombineTrips == true)
    streamWriteUInt16(streamId, #cList)
    for _, item in ipairs(cList) do
        local mTrip = item.trip
        streamWriteString(streamId, item.machineKey)
        streamWriteInt32(streamId, mTrip.fieldId or 0)
        streamWriteString(streamId, mTrip.cropName or "--")
        streamWriteInt32(streamId, mTrip.fillTypeIndex or FillType.UNKNOWN)
        streamWriteFloat32(streamId, mTrip.harvestedLiters or 0)
        streamWriteFloat32(streamId, mTrip.harvestedMassKg or 0)
        streamWriteFloat32(streamId, mTrip.harvestedAreaHa or 0)
        streamWriteFloat32(streamId, mTrip.lostLiters or 0)
        streamWriteFloat32(streamId, mTrip.lossMoney or 0)
        streamWriteFloat32(streamId, mTrip.fuelUsedL or 0)
        streamWriteFloat32(streamId, mTrip.sessionDuration or 0)
        streamWriteString(streamId, mTrip.efficiencyRank or "A")
        streamWriteFloat32(streamId, mTrip.avgSpeedSum or 0)
        streamWriteUInt32(streamId, mTrip.avgSpeedCount or 0)
        streamWriteFloat32(streamId, mTrip.avgLoadSum or 0)
        streamWriteUInt32(streamId, mTrip.avgLoadCount or 0)
        local mReasons = mTrip.reasons or {}
        streamWriteFloat32(streamId, mReasons.speed or 0)
        streamWriteFloat32(streamId, mReasons.settings or 0)
        streamWriteFloat32(streamId, mReasons.moisture or 0)
        streamWriteFloat32(streamId, mReasons.wear or 0)
        streamWriteFloat32(streamId, mReasons.slope or 0)
        streamWriteBool(streamId, mTrip.isActive == true)
        streamWriteBool(streamId, mTrip.isContract == true)
    end

    -- Field Stats count & entries (capped at 50)
    local fList = {}
    if farm.fieldStats then
        for fId, fStat in pairs(farm.fieldStats) do
            table.insert(fList, fStat)
        end
    end
    streamWriteBool(streamId, self.isDelta ~= true or farm.replaceFieldStats == true)
    streamWriteUInt16(streamId, #fList)
    for _, fStat in ipairs(fList) do
        streamWriteInt32(streamId, fStat.fieldId or 0)
        streamWriteFloat32(streamId, fStat.harvestedLiters or 0)
        streamWriteFloat32(streamId, fStat.harvestedMassKg or 0)
        streamWriteFloat32(streamId, fStat.harvestedAreaHa or 0)
        streamWriteFloat32(streamId, fStat.lostLiters or 0)
        streamWriteFloat32(streamId, fStat.lossMoney or 0)
        streamWriteFloat32(streamId, fStat.fuelUsedL or 0)
        streamWriteFloat32(streamId, fStat.sessionDuration or 0)
        streamWriteUInt16(streamId, fStat.operationsCount or 0)
        streamWriteBool(streamId, fStat.isContract == true)
        streamWriteString(streamId, fStat.lastCropName or fStat.lastCrop or "--")
        streamWriteInt32(streamId, fStat.lastYear or 1)
        RHM_HarvestSyncInitialEvent.writeCropVolumes(streamId, fStat.cropVolumes)
        local fReasons = fStat.reasons or {}
        streamWriteFloat32(streamId, fReasons.speed or 0)
        streamWriteFloat32(streamId, fReasons.settings or 0)
        streamWriteFloat32(streamId, fReasons.moisture or 0)
        streamWriteFloat32(streamId, fReasons.wear or 0)
        streamWriteFloat32(streamId, fReasons.slope or 0)
    end

    -- Field Clusters count & entries
    streamWriteBool(streamId, farm.fieldClusters ~= nil)
    if farm.fieldClusters then
        local clusterList = {}
        if farm.fieldClusters then
            for masterId, cluster in pairs(farm.fieldClusters) do
                local members = {}
                for memberId, _ in pairs(cluster.members or {}) do
                    table.insert(members, memberId)
                end
                table.insert(clusterList, { masterId = masterId, members = members })
            end
        end
        streamWriteUInt16(streamId, #clusterList)
        for _, c in ipairs(clusterList) do
            streamWriteInt32(streamId, c.masterId)
            streamWriteUInt16(streamId, #c.members)
            for _, mId in ipairs(c.members) do
                streamWriteInt32(streamId, mId)
            end
        end
    end
end

function RHM_HarvestSyncInitialEvent:readStream(streamId, connection)
    self.farmId = streamReadUInt8(streamId)
    self.isDelta = streamReadBool(streamId)

    local tracker = g_realisticHarvestManager and g_realisticHarvestManager.harvestTracker
    local apply = connection:getIsServer() and tracker ~= nil
    local farm = apply and tracker:getFarmData(self.farmId) or RHM_HarvestTracker:createDefaultFarmData()

    -- Current Trip
    local hasTrip = streamReadBool(streamId)
    if hasTrip then
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
        trip.lastMachineKey = lmk ~= "" and lmk or nil
    end

    -- Farm Settings
    if streamReadBool(streamId) then
        local set = farm.farmSettings
        set.aiSpeedLimiter = streamReadBool(streamId)
        set.aiMaxLossPct = streamReadFloat32(streamId)
        set.volunteerCrops = streamReadBool(streamId)
        set.autoResetOnFieldChange = streamReadBool(streamId)
        set.autoResetMode = streamReadUInt8(streamId)
    end

    -- Fleet Stats
    local replaceFleet = streamReadBool(streamId)
    local fleetCount = streamReadUInt16(streamId)
    farm.fleetStats = replaceFleet and {} or (farm.fleetStats or {})
    for _ = 1, fleetCount do
        local key = streamReadString(streamId)
        local name = streamReadString(streamId)
        local workSeconds = streamReadFloat32(streamId)
        local totalHarvested = streamReadFloat32(streamId)
        local totalLost = streamReadFloat32(streamId)
        farm.fleetStats[key] = {
            name = name, workSeconds = workSeconds, totalHarvested = totalHarvested, totalLost = totalLost,
            isMission = streamReadBool(streamId), isLeased = streamReadBool(streamId)
        }
    end

    -- Season History
    if streamReadBool(streamId) then
        local histCount = streamReadUInt16(streamId)
        farm.seasonHistory = {}
        for _ = 1, histCount do
            table.insert(farm.seasonHistory, {
                year = streamReadUInt16(streamId),
                fieldId = streamReadInt32(streamId),
                cropName = streamReadString(streamId),
                harvested = streamReadFloat32(streamId),
                harvestedMassKg = streamReadFloat32(streamId),
                lost = streamReadFloat32(streamId),
                lossMoney = streamReadFloat32(streamId),
                areaHa = streamReadFloat32(streamId),
                efficiencyRank = streamReadString(streamId),
                dominantReason = streamReadString(streamId),
                isContract = streamReadBool(streamId),
                fuelUsed = streamReadFloat32(streamId),
                machineName = streamReadString(streamId),
                timestamp = streamReadString(streamId)
            })
        end
    end

    -- Yearly Stats
    local yearlyCount = streamReadUInt16(streamId)
    farm.yearlyStats = self.isDelta and (farm.yearlyStats or {}) or {}
    for _ = 1, yearlyCount do
        local y = streamReadUInt16(streamId)
        farm.yearlyStats[y] = {
            year = y,
            harvestedLiters = streamReadFloat32(streamId),
            harvestedMassKg = streamReadFloat32(streamId),
            harvestedAreaHa = streamReadFloat32(streamId),
            lostLiters = streamReadFloat32(streamId),
            lossMoney = streamReadFloat32(streamId),
            sessionDuration = streamReadFloat32(streamId),
            avgSpeedSum = streamReadFloat32(streamId),
            avgSpeedCount = streamReadUInt32(streamId),
            avgLoadSum = streamReadFloat32(streamId),
            avgLoadCount = streamReadUInt32(streamId),
            fieldOperations = streamReadUInt16(streamId)
        }
        RHM_HarvestSyncInitialEvent.readStatDetails(streamId, farm.yearlyStats[y])
    end

    -- Combine Trips
    local replaceTrips = streamReadBool(streamId)
    local combineCount = streamReadUInt16(streamId)
    farm.combineTrips = replaceTrips and {} or (farm.combineTrips or {})
    for _ = 1, combineCount do
        local machineKey = streamReadString(streamId)
        local mTrip = {
            fieldId = streamReadInt32(streamId),
            cropName = streamReadString(streamId),
            fillTypeIndex = streamReadInt32(streamId),
            harvestedLiters = streamReadFloat32(streamId),
            harvestedMassKg = streamReadFloat32(streamId),
            harvestedAreaHa = streamReadFloat32(streamId),
            lostLiters = streamReadFloat32(streamId),
            lossMoney = streamReadFloat32(streamId),
            fuelUsedL = streamReadFloat32(streamId),
            sessionDuration = streamReadFloat32(streamId),
            efficiencyRank = streamReadString(streamId),
            avgSpeedSum = streamReadFloat32(streamId),
            avgSpeedCount = streamReadUInt32(streamId),
            avgLoadSum = streamReadFloat32(streamId),
            avgLoadCount = streamReadUInt32(streamId),
            reasons = {
                speed = streamReadFloat32(streamId),
                settings = streamReadFloat32(streamId),
                moisture = streamReadFloat32(streamId),
                wear = streamReadFloat32(streamId),
                slope = streamReadFloat32(streamId)
            },
            isActive = streamReadBool(streamId),
            isContract = streamReadBool(streamId)
        }
        farm.combineTrips[machineKey] = mTrip
    end

    -- Field Stats
    local replaceFields = streamReadBool(streamId)
    local fCount = streamReadUInt16(streamId)
    farm.fieldStats = replaceFields and {} or (farm.fieldStats or {})
    for _ = 1, fCount do
        local fId = streamReadInt32(streamId)
        farm.fieldStats[fId] = {
            fieldId = fId,
            harvestedLiters = streamReadFloat32(streamId),
            harvestedMassKg = streamReadFloat32(streamId),
            harvestedAreaHa = streamReadFloat32(streamId),
            lostLiters = streamReadFloat32(streamId),
            lossMoney = streamReadFloat32(streamId),
            fuelUsedL = streamReadFloat32(streamId),
            sessionDuration = streamReadFloat32(streamId),
            operationsCount = streamReadUInt16(streamId),
            isContract = streamReadBool(streamId),
            lastCropName = streamReadString(streamId),
            lastYear = streamReadInt32(streamId),
            avgSpeedSum = 0,
            avgSpeedCount = 0,
            avgLoadSum = 0,
            avgLoadCount = 0,
            cropVolumes = RHM_HarvestSyncInitialEvent.readCropVolumes(streamId),
            reasons = {
                speed = streamReadFloat32(streamId),
                settings = streamReadFloat32(streamId),
                moisture = streamReadFloat32(streamId),
                wear = streamReadFloat32(streamId),
                slope = streamReadFloat32(streamId)
            }
        }
        farm.fieldStats[fId].lastCrop = farm.fieldStats[fId].lastCropName
    end

    -- Field Clusters
    if streamReadBool(streamId) then
        local clusterCount = streamReadUInt16(streamId)
        farm.fieldClusters = {}
        farm.fieldClusterMembers = {}
        for _ = 1, clusterCount do
            local masterId = streamReadInt32(streamId)
            local memberCount = streamReadUInt16(streamId)
            farm.fieldClusters[masterId] = { members = { [masterId] = true } }
            farm.fieldClusterMembers[masterId] = masterId
            for _ = 1, memberCount do
                local mId = streamReadInt32(streamId)
                farm.fieldClusters[masterId].members[mId] = true
                farm.fieldClusterMembers[mId] = masterId
            end
        end

    end

    -- Link client combine specs if vehicles already spawned
    if apply and g_currentMission then
        local vehicles = (g_currentMission.vehicleSystem and g_currentMission.vehicleSystem.vehicles) or g_currentMission.vehicles
        if vehicles then
            for _, vehicle in pairs(vehicles) do
                if vehicle and type(vehicle) == "table" and vehicle.spec_rhm_Combine then
                    local vFarmId = (vehicle.getOwnerFarmId and vehicle:getOwnerFarmId()) or 1
                    if vFarmId == self.farmId and farm.combineTrips then
                        local machineKey = (RHM_HarvestTracker and RHM_HarvestTracker.getMachineKey and RHM_HarvestTracker.getMachineKey(vehicle)) or vehicle.configFileName or
                            (vehicle.getFullName and vehicle:getFullName()) or "Harvester"
                        local mTrip = farm.combineTrips[machineKey]
                        if mTrip then
                            vehicle.spec_rhm_Combine.trip = mTrip
                        end
                    end
                end
            end
        end
    end

    if apply then self:run(connection) end
end

function RHM_HarvestSyncInitialEvent:run(connection)
    -- Notify GUI of fresh initial state if open
    if g_realisticHarvestManager and g_realisticHarvestManager.harvestHistoryGUI and g_realisticHarvestManager.harvestHistoryGUI.isOpen then
        g_realisticHarvestManager.harvestHistoryGUI:refreshCurrentPage()
    end
end

function RHM_HarvestSyncInitialEvent.writeCropVolumes(streamId, volumes)
    local entries = {}
    for crop, liters in pairs(volumes or {}) do
        table.insert(entries, { crop = crop, liters = liters })
    end
    streamWriteUInt16(streamId, #entries)
    for _, entry in ipairs(entries) do
        streamWriteString(streamId, entry.crop)
        streamWriteFloat32(streamId, entry.liters)
    end
end

function RHM_HarvestSyncInitialEvent.readCropVolumes(streamId)
    local volumes = {}
    local count = streamReadUInt16(streamId)
    for _ = 1, count do
        local crop = streamReadString(streamId)
        volumes[crop] = streamReadFloat32(streamId)
    end
    return volumes
end

function RHM_HarvestSyncInitialEvent.writeStatDetails(streamId, stat)
    local reasons = stat.reasons or {}
    for _, reason in ipairs({ "speed", "settings", "moisture", "wear", "slope" }) do
        streamWriteFloat32(streamId, reasons[reason] or 0)
    end
    RHM_HarvestSyncInitialEvent.writeCropVolumes(streamId, stat.cropVolumes)
end

function RHM_HarvestSyncInitialEvent.readStatDetails(streamId, stat)
    stat.reasons = {}
    for _, reason in ipairs({ "speed", "settings", "moisture", "wear", "slope" }) do
        stat.reasons[reason] = streamReadFloat32(streamId)
    end
    stat.cropVolumes = RHM_HarvestSyncInitialEvent.readCropVolumes(streamId)
end
