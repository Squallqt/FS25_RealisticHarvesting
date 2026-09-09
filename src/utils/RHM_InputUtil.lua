-- EN: Input utility for managing camera rotation and zoom states during HUD drag or GUI interactions.
-- UA: Утиліта вводу для керування обертанням та масштабуванням камери під час перетягування HUD або взаємодії з GUI.
RHMInputUtil = {}

-- EN: Enable or disable camera rotation for all cameras on a vehicle.
--     Used to block camera rotation when the mouse cursor is shown (e.g. during HUD dragging).
--     Saves original camera states to a table so they can be restored later.
-- UA: Вмикає або вимикає обертання камери для всіх камер транспортного засобу.
--     EN: Used to block the camera while showing the mouse cursor (e.g., when dragging the HUD).
--     UA: Використовується для блокування камери під час показу курсору миші (наприклад, при перетягуванні HUD).
--     EN: Saves original camera states into a table so they can be restored later.
--     UA: Зберігає оригінальні стани камер у таблицю, щоб їх можна було відновити пізніше.
function RHMInputUtil.setCameraRotation(vehicle, enableRotation, savedRotatableInfo)
    if not vehicle or not vehicle.spec_enterable or not vehicle.spec_enterable.cameras then
        return
    end

    if not savedRotatableInfo then
        savedRotatableInfo = {}
    end

    for i, camera in pairs(vehicle.spec_enterable.cameras) do
        if enableRotation then
            -- EN: Unconditionally restore full camera rotation and movement.
            -- UA: Безумовно відновлюємо повне обертання та рух камери.
            camera.isRotatable = true
            camera.allowTranslation = true
            camera.allowZoom = true
            if camera.rotSpeed == 0 and camera._rhmSavedRotSpeed then
                camera.rotSpeed = camera._rhmSavedRotSpeed
                camera._rhmSavedRotSpeed = nil
            end
            savedRotatableInfo[camera] = nil
        else
            -- EN: Disable camera rotation and save token (never save false as baseline).
            -- UA: Вимикаємо обертання камери та зберігаємо стан (ніколи не зберігаємо false як базу).
            if savedRotatableInfo[camera] == nil then
                savedRotatableInfo[camera] = true
            end
            camera.isRotatable = false
            camera.allowTranslation = false
            camera.allowZoom = false
            if camera.rotSpeed and camera.rotSpeed > 0 then
                camera._rhmSavedRotSpeed = camera.rotSpeed
                camera.rotSpeed = 0
            end
        end
    end

    return savedRotatableInfo
end

-- EN: Enable or disable camera zoom (mouse wheel) for all cameras on a vehicle.
--     Used to block camera zoom when the GUI needs to capture scroll wheel events.
-- UA: Вмикає або вимикає масштабування камери (колесо миші) для всіх камер транспортного засобу.
function RHMInputUtil.setCameraZoom(vehicle, enableZoom, savedZoomInfo)
    if not vehicle or not vehicle.spec_enterable or not vehicle.spec_enterable.cameras then
        return
    end

    if not savedZoomInfo then
        savedZoomInfo = {}
    end

    for i, camera in pairs(vehicle.spec_enterable.cameras) do
        if enableZoom then
            camera.allowTranslation = true
            camera.allowZoom = true
            savedZoomInfo[camera] = nil
        else
            if savedZoomInfo[camera] == nil then
                savedZoomInfo[camera] = true
            end
            camera.allowTranslation = false
            camera.allowZoom = false
        end
    end

    return savedZoomInfo
end

rhm_log("RHM [UI]: [OK] RHMInputUtil loaded")
