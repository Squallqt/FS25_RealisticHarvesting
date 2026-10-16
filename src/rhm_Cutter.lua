-- EN: rhm_Cutter — vehicle specialization for cutters / headers.
--     Provides native, non-intrusive independent header launch control from the combine.
--     When independent launch is enabled, prevents the cutter from starting automatically
--     when the combine's thresher is turned on.
-- UA: rhm_Cutter — спеціалізація техніки для жаток.
--     Забезпечує нативний, безпечний роздільний запуск жатки від комбайна.
--     Коли роздільний запуск увімкнено, запобігає автоматичному увімкненню жатки
--     при включенні молотарки комбайна.

rhm_Cutter = {}

function rhm_Cutter.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(Cutter, specializations)
end

function rhm_Cutter.initSpecialization()
end

function rhm_Cutter.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, "updateIndependentLaunchState", rhm_Cutter.updateIndependentLaunchState)
end

function rhm_Cutter.registerOverwrittenFunctions(vehicleType)
end

function rhm_Cutter.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", rhm_Cutter)
    SpecializationUtil.registerEventListener(vehicleType, "onPostLoad", rhm_Cutter)
    SpecializationUtil.registerEventListener(vehicleType, "onPostAttach", rhm_Cutter)
    SpecializationUtil.registerEventListener(vehicleType, "onPreDetach", rhm_Cutter)
end

function rhm_Cutter:onLoad(savegame)
    local spec = self.spec_rhm_Cutter
    if spec == nil then
        spec = {}
        self.spec_rhm_Cutter = spec
    end

    spec.originalTurnedOnByAttacherVehicle = true
    if self.spec_turnOnVehicle ~= nil then
        spec.originalTurnedOnByAttacherVehicle = self.spec_turnOnVehicle.turnedOnByAttacherVehicle
    end
end

function rhm_Cutter:onPostLoad(savegame)
    self:updateIndependentLaunchState()
end

function rhm_Cutter:onPostAttach(attacherVehicle, inputJointDescIndex, jointDescIndex)
    self:updateIndependentLaunchState(attacherVehicle)
end

function rhm_Cutter:onPreDetach(attacherVehicle, implement)
    local spec = self.spec_rhm_Cutter
    if spec and self.spec_turnOnVehicle and spec.originalTurnedOnByAttacherVehicle ~= nil then
        self.spec_turnOnVehicle.turnedOnByAttacherVehicle = spec.originalTurnedOnByAttacherVehicle
    end
end

function rhm_Cutter:updateIndependentLaunchState(attacherVehicle)
    local spec = self.spec_rhm_Cutter
    if not spec or not self.spec_turnOnVehicle then
        return
    end

    local isIndependentLaunchEnabled = false
    if g_realisticHarvestManager and g_realisticHarvestManager.settings then
        isIndependentLaunchEnabled = g_realisticHarvestManager.settings.enableIndependentLaunch == true
    end

    local carrier = attacherVehicle or (self.getRootVehicle and self:getRootVehicle())
    local isAttachedToCombine = false
    if carrier and carrier.spec_rhm_Combine ~= nil then
        isAttachedToCombine = true
    elseif self.getAttacherVehicle and self:getAttacherVehicle() then
        local directAttacher = self:getAttacherVehicle()
        if directAttacher and (directAttacher.spec_rhm_Combine ~= nil or (directAttacher.getRootVehicle and directAttacher:getRootVehicle().spec_rhm_Combine ~= nil)) then
            isAttachedToCombine = true
        end
    end
    if not isAttachedToCombine and carrier and RHM_Api and RHM_Api.findCombine then
        local combine = RHM_Api.findCombine(carrier)
        if combine ~= nil and (combine.spec_rhm_Combine ~= nil or combine.spec_combine ~= nil) then
            isAttachedToCombine = true
        end
    end

    if isIndependentLaunchEnabled and isAttachedToCombine then
        self.spec_turnOnVehicle.turnedOnByAttacherVehicle = false
    else
        if spec.originalTurnedOnByAttacherVehicle ~= nil then
            self.spec_turnOnVehicle.turnedOnByAttacherVehicle = spec.originalTurnedOnByAttacherVehicle
        end
    end
end

rhm_log("RHM [Cutter]: RHM: rhm_Cutter specialization loaded!")
