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

function RHM_HarvestUpdateStatsEvent.new(farmId, farmData)
    local self = RHM_HarvestUpdateStatsEvent.emptyNew()
    self.farmId = farmId or 1
    self.farmData = farmData
    self.isDelta = true
    return self
end

-- Initial snapshots and targeted deltas use the same field names and stream order.
function RHM_HarvestUpdateStatsEvent:writeStream(streamId, connection)
    RHM_HarvestSyncInitialEvent.writeStream(self, streamId, connection)
end

function RHM_HarvestUpdateStatsEvent:readStream(streamId, connection)
    RHM_HarvestSyncInitialEvent.readStream(self, streamId, connection)
end

function RHM_HarvestUpdateStatsEvent:run(connection)
    RHM_HarvestSyncInitialEvent.run(self, connection)
end
