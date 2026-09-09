-- EN: Central manager for the Realistic Harvesting mod. Created once per mission and stored
--     as the global g_realisticHarvestManager. Coordinates all mod subsystems:
--     settings, HUD, calibration GUI, console commands, and input events.
-- UA: Центральний менеджер мода Realistic Harvesting. Створюється один раз за місію і зберігається
--     як глобальний g_realisticHarvestManager. Координує всі підсистеми мода:
--     налаштування, HUD, GUI калібрування, консольні команди та події вводу.
RHM_RealisticHarvestManager = {}
local RealisticHarvestManager_mt = Class(RHM_RealisticHarvestManager)

-- EN: Initializes all mod subsystems: settings, UI, HUD, calibration GUI, and console commands.
--     Creates the HUD and settings UI only on the game client (not dedicated server).
-- UA: Ініціалізує всі підсистеми мода: налаштування, UI, HUD, GUI калібрування і консольні команди.
--     Створює HUD і settings UI тільки на клієнті гри (не на виділеному сервері).
function RHM_RealisticHarvestManager.new(mission, modDirectory, modName)
    local self = setmetatable({}, RealisticHarvestManager_mt)

    self.mission = mission
    self.modDirectory = modDirectory
    self.modName = modName

    -- EN: Initialize settings: the RHMSettingsManager handles XML I/O, RHMSettings holds all values.
    -- UA: Ініціалізуємо налаштування: RHMSettingsManager обробляє XML, RHMSettings зберігає значення.
    self.settingsManager = RHMSettingsManager.new()
    self.settings = RHMSettings.new(self.settingsManager)

    self.savedCameraRotatableInfo = {} -- EN: Stores camera rotatability before cursor mode / UA: Зберігає стан камери до режиму курсора

    -- EN: PREPEND to class onFrameOpen so our elements are in the layout BEFORE the base game
    --     computes positions. appendedFunction runs too late (after the frame is already drawn).
    -- UA: PREPEND до класу onFrameOpen — наші елементи потрапляють в layout ДО того як гра
    --     рахує позиції. appendedFunction запускається занадто пізно (кадр вже намальований).
    if mission:getIsClient() and g_gui then
        local settings = self.settings
        InGameMenuSettingsFrame.onFrameOpen = Utils.prependedFunction(
            InGameMenuSettingsFrame.onFrameOpen,
            function(settingsPage)
                pcall(function()
                    RHMSettingsUI.inject(settings)
                    RHMSettingsUI.refreshUI(settings)
                end)
            end
        )
    end

    -- EN: Console commands are always registered (server and client need them).
    -- UA: Консольні команди реєструються завжди (і сервер, і клієнт їх потребують).
    self.settingsGUI = RHMSettingsGUI.new()
    self.settingsGUI:registerConsoleCommands()

    self.combineSettingsGUI = RHMCombineSettingsGUI.new()

    -- EN: Load saved settings from XML before creating HUD (HUD reads settings in its constructor).
    -- UA: Завантажуємо збережені налаштування з XML перед створенням HUD (HUD читає налаштування в конструкторі).
    self.settings:load()

    -- EN: Create the draggable HUD overlay (client only, handles display of live data).
    -- UA: Створюємо перетягуваний HUD (тільки клієнт, відображає живі дані).
    if mission:getIsClient() then
        self.hud = RHMDraggableHUD.new(self.modDirectory, self.settings)

        if not self.hud then
            Logging.error("RHM: Failed to create HUD instance!")
        end

        self.debugLogTimer = 0
        self.debugLogInterval = 10000  -- EN: 10s interval for debug info in logs / UA: 10сек інтервал для відладки в логах
    end

    -- EN: Create the visual calibration GUI (client only, for manual settings adjustment).
    -- UA: Створюємо візуальний GUI калібрування (тільки клієнт, для ручного регулювання).
    if mission:getIsClient() then
        self.calibrationGUI = RHMCombineCalibrationGUI.new(modDirectory)
    end

    if mission:getIsClient() and RHM_CropFactorTuning and RHM_CropFactorTuning.isEnabled and RHM_CropFactorTuning.isEnabled() then
        self.cropFactorTuneGUI = RHM_CropFactorTuningGui.new(modDirectory)
        RHM_CropFactorTuning.registerConsoleCommand()
    end

    return self
end

-- EN: Toggles the calibration GUI open/closed for the given combine vehicle.
-- UA: Перемикає GUI калібрування відкритий/закритий для заданого комбайна.
function RHM_RealisticHarvestManager:toggleMenu(vehicle)
    if self.calibrationGUI then
        self.calibrationGUI:toggle(vehicle)
    end
end

-- EN: Called after the mission finishes loading. Initializes HUD overlay assets (textures, positions).
-- UA: Викликається після завершення завантаження місії. Ініціалізує ресурси HUD (текстури, позиції).
function RHM_RealisticHarvestManager:onMissionLoaded()
    if self.hud then
        self.hud:load()
    end
end

-- EN: Recursively searches the vehicle hierarchy for the first vehicle with spec_rhm_Combine.
--     Used to find the combine when the player is controlling a tractor in a Nexat modular system.
-- UA: Рекурсивно шукає в ієрархії транспорту перший транспортний засіб з spec_rhm_Combine.
--     Використовується для пошуку комбайна коли гравець керує трактором у модульній системі Nexat.
local function findCombineInHierarchy(vehicle, checkedVehicles)
    if not vehicle then return nil end

    checkedVehicles = checkedVehicles or {}
    if checkedVehicles[vehicle] then return nil end
    checkedVehicles[vehicle] = true

    if vehicle.spec_rhm_Combine then return vehicle end

    -- EN: Search up through parent (rootVehicle, attacherVehicle) and down through children.
    -- UA: Шукаємо вгору через батьків (rootVehicle, attacherVehicle) і вниз через дочірні.
    if vehicle.rootVehicle and not checkedVehicles[vehicle.rootVehicle] then
        local found = findCombineInHierarchy(vehicle.rootVehicle, checkedVehicles)
        if found then return found end
    end

    if vehicle.attacherVehicle and not checkedVehicles[vehicle.attacherVehicle] then
        local found = findCombineInHierarchy(vehicle.attacherVehicle, checkedVehicles)
        if found then return found end
    end

    if vehicle.getAttachedImplements then
        local implements = vehicle:getAttachedImplements()
        if implements then
            for _, implement in ipairs(implements) do
                if implement.object and not checkedVehicles[implement.object] then
                    local found = findCombineInHierarchy(implement.object, checkedVehicles)
                    if found then return found end
                end
            end
        end
    end

    return nil
end

-- EN: Returns the vehicle currently controlled by the local player.
--     Falls back through multiple methods to handle various FS25 versions/states.
-- UA: Повертає транспортний засіб, яким зараз керує локальний гравець.
--     Перебирає кілька методів для підтримки різних версій/станів FS25.
function RHM_RealisticHarvestManager:getControlledVehicle()
    if g_localPlayer and g_localPlayer.getCurrentVehicle then
        local v = g_localPlayer:getCurrentVehicle()
        if v then return v end
    end
    if g_currentMission then
        if g_currentMission.getControlledVehicle then
            local v = g_currentMission:getControlledVehicle()
            if v then return v end
        end
        if g_currentMission.controlledVehicle then
            return g_currentMission.controlledVehicle
        end
        if g_currentMission.player and g_currentMission.player.getCurrentVehicle then
            local v = g_currentMission.player:getCurrentVehicle()
            if v then return v end
        end
    end
    return nil
end

-- EN: Called every game frame. Updates the calibration GUI and HUD data.
--     Searches the player's vehicle hierarchy for a combine spec to track live data.
--     Only updates HUD when a combine is found and running.
-- UA: Викликається щоразу за кадр гри. Оновлює GUI калібрування і дані HUD.
--     Шукає в ієрархії транспорту гравця специфікацію комбайна для відстеження живих даних.
--     Оновлює HUD тільки коли знайдено і запущено комбайн.
function RHM_RealisticHarvestManager:update(dt)
    -- EN: If any game GUI (ESC pause menu, shop, map) is open, cleanly close our calibration GUI
    -- UA: Якщо відкритий будь-який GUI гри (меню паузи ESC, магазин, карта), чисто закриваємо GUI калібрування
    if g_gui:getIsGuiVisible() then
        if self.calibrationGUI and self.calibrationGUI.isOpen then
            self.calibrationGUI:close()
        end
        if self.isCursorVisible then
            self.isCursorVisible = false
            g_inputBinding:setShowMouseCursor(false)
        end
        return
    end

    if self.calibrationGUI then
        self.calibrationGUI:update(dt)
    end

    if self.cropFactorTuneGUI then
        self.cropFactorTuneGUI:update(dt)
    end

    -- EN: Self-healing camera manager: ensures cameras are locked ONLY when menu or HUD cursor is active,
    --     and guaranteed to be unlocked as soon as neither is active!
    -- UA: Менеджер самовідновлення камери: гарантує, що камери заблоковані ТІЛЬКИ коли відкрите меню або активний курсор HUD,
    --     і гарантовано розблоковані, як тільки вони неактивні!
    local controlledVehicle = self:getControlledVehicle()
    local shouldBlockCamera = (self.isCursorVisible == true) or (self.calibrationGUI ~= nil and self.calibrationGUI.isOpen == true)

    local vehiclesToManage = {}
    if controlledVehicle and controlledVehicle.spec_enterable and controlledVehicle.spec_enterable.cameras then
        table.insert(vehiclesToManage, controlledVehicle)
    end
    if self.lastActiveCombine and self.lastActiveCombine ~= controlledVehicle and self.lastActiveCombine.spec_enterable and self.lastActiveCombine.spec_enterable.cameras then
        table.insert(vehiclesToManage, self.lastActiveCombine)
    end

    if #vehiclesToManage > 0 then
        for _, v in ipairs(vehiclesToManage) do
            for _, camera in pairs(v.spec_enterable.cameras) do
                if shouldBlockCamera then
                    if camera.isRotatable then camera.isRotatable = false end
                    if camera.allowTranslation then camera.allowTranslation = false end
                    if camera.allowZoom then camera.allowZoom = false end
                    if camera.rotSpeed and camera.rotSpeed > 0 then
                        camera._rhmSavedRotSpeed = camera.rotSpeed
                        camera.rotSpeed = 0
                    end
                else
                    -- Fail-safe unlock: camera must be rotatable during normal play!
                    if not camera.isRotatable then camera.isRotatable = true end
                    if not camera.allowTranslation then camera.allowTranslation = true end
                    if not camera.allowZoom then camera.allowZoom = true end
                    if camera.rotSpeed == 0 and camera._rhmSavedRotSpeed then
                        camera.rotSpeed = camera._rhmSavedRotSpeed
                        camera._rhmSavedRotSpeed = nil
                    end
                end
            end
        end
    else
        -- If player is not controlling an enterable vehicle, ensure cursor mode is off
        if self.isCursorVisible then
            self.isCursorVisible = false
            g_inputBinding:setShowMouseCursor(false)
        end
    end

    if self.hud then
        local vehicle = controlledVehicle
        local combineVehicle = nil

        if vehicle then
            -- EN: For modular systems (Nexat), search from the root vehicle of the train.
            -- UA: Для модульних систем (Nexat), шукаємо від кореневого транспортного засобу.
            local searchRoot = vehicle.rootVehicle or vehicle
            local now = g_time
            local throttleMs = 250
            
            -- EN: Cache optimization: only search hierarchy if vehicle changed or timeout expired
            -- UA: Оптимізація кешу: шукаємо ієрархію тільки якщо транспорт змінився або таймаут минув
            if vehicle == self._rhmHudVehicleRef and searchRoot == self._rhmHudSearchRootRef
                and self.lastActiveCombine and (now - (self._rhmHudHierarchySearchTime or 0)) < throttleMs then
                combineVehicle = self.lastActiveCombine
            else
                combineVehicle = findCombineInHierarchy(searchRoot)
                self._rhmHudHierarchySearchTime = now
                self._rhmHudVehicleRef = vehicle
                self._rhmHudSearchRootRef = searchRoot
            end
        else
            -- EN: Clear cache when no vehicle controlled
            -- UA: Очищаємо кеш коли немає контрольованого транспорту
            self._rhmHudVehicleRef = nil
            self._rhmHudSearchRootRef = nil
        end

        self.lastActiveCombine = combineVehicle

        if combineVehicle then
            self.hud:setVehicle(combineVehicle)
            self.hud:update(dt)
        else
            self.hud:setVehicle(nil)
        end
    end
end

-- EN: Called every game frame to draw the HUD and calibration GUI.
--     Suppresses all drawing when any game menu is open, when the game HUD is hidden,
--     or when the player is not in a vehicle.
-- UA: Викликається щоразу за кадр для відображення HUD і GUI калібрування.
--     Пригнічує всі малювання коли відкрите будь-яке меню гри, коли HUD гри прихований,
--     або коли гравець не в транспортному засобі.
function RHM_RealisticHarvestManager:draw()
    -- EN: Skip all drawing when any FS25 GUI screen is visible (e.g. ESC menu, map, settings).
    -- UA: Пропускаємо все малювання коли відкритий будь-який GUI екран FS25 (меню ESC, карта, налаштування).
    if g_gui:getIsGuiVisible() then
        return
    end

    if self.cropFactorTuneGUI then
        self.cropFactorTuneGUI:draw()
    end

    -- EN: Calibration GUI is drawn above the HUD independently.
    -- UA: GUI калібрування малюється поверх HUD незалежно.
    if self.calibrationGUI then
        self.calibrationGUI:draw()
    end

    -- EN: Respect third-party HUD hider mods by checking game HUD visibility.
    -- UA: Поважаємо сторонні моди приховування HUD, перевіряючи видимість HUD гри.
    if g_currentMission and g_currentMission.hud and g_currentMission.hud.getIsVisible and not g_currentMission.hud:getIsVisible() then
        return
    end

    local combineVehicle = self.lastActiveCombine

    -- EN: Don't draw HUD if the player has exited the vehicle.
    -- UA: Не малюємо HUD якщо гравець вийшов з транспортного засобу.
    local playerVehicle = self:getControlledVehicle()
    if not playerVehicle then
        return
    end

    if self.hud and combineVehicle then
        if self.settings and self.settings.showHUD then
            self.hud:draw()
        end
    end
end

-- EN: Cleans up all HUD and GUI resources on mission end.
-- UA: Очищає всі ресурси HUD і GUI при завершенні місії.
function RHM_RealisticHarvestManager:delete()
    if self.hud then
        self.hud:delete()
        self.hud = nil
    end
    if self.cropFactorTuneGUI then
        self.cropFactorTuneGUI:delete()
        self.cropFactorTuneGUI = nil
    end
    if self.calibrationGUI then
        self.calibrationGUI:delete()
    end
end

-- EN: Routes mouse events to the calibration GUI first, then to the HUD (for dragging).
--     The GUI gets priority so it can capture events before the HUD.
-- UA: Направляє події миші спочатку до GUI калібрування, а потім до HUD (для перетягування).
--     GUI отримує пріоритет, щоб перехоплювати події до HUD.
function RHM_RealisticHarvestManager:mouseEvent(posX, posY, isDown, isUp, button)
    if not self.mission:getIsClient() then
        return
    end

    if self.cropFactorTuneGUI and self.cropFactorTuneGUI:mouseEvent(posX, posY, isDown, isUp, button) then
        return true
    end

    if self.calibrationGUI and self.calibrationGUI:mouseEvent(posX, posY, isDown, isUp, button) then
        return true
    end

    if self.hud then
        return self.hud:mouseEvent(posX, posY, isDown, isUp, button)
    end

    return false
end

-- EN: Toggles mouse cursor visibility for HUD drag interaction.
--     Disables camera rotation while cursor is visible.
-- UA: Перемикає видимість курсора миші для взаємодії з перетягуванням HUD.
--     Вимикає обертання камери поки курсор видимий.
function RHM_RealisticHarvestManager:toggleCursor()
    -- EN: If calibration GUI is open, do NOT close it (it has its own close handlers: Shift+K, ESC, [X]).
    -- UA: Якщо GUI калібрування відкритий, НЕ закриваємо його (він має власні обробники: Shift+K, ESC, [X]).
    if self.calibrationGUI and self.calibrationGUI.isOpen then
        return
    end

    local combineVehicle = self.lastActiveCombine
    if not (self.hud and combineVehicle) then
        if self.isCursorVisible then
            self.isCursorVisible = false
            g_inputBinding:setShowMouseCursor(false)
            local vehicle = self:getControlledVehicle()
            if vehicle then
                RHMInputUtil.setCameraRotation(vehicle, true, self.savedCameraRotatableInfo)
            end
        end
        return
    end

    self.isCursorVisible = not self.isCursorVisible
    g_inputBinding:setShowMouseCursor(self.isCursorVisible)

    local vehicle = self:getControlledVehicle()

    if self.isCursorVisible then
        if g_currentMission then
            g_currentMission:showBlinkingWarning("RHM: HUD Cursor Enabled - Drag HUD to move", 3000)
        end
        if vehicle then
            RHMInputUtil.setCameraRotation(vehicle, false, self.savedCameraRotatableInfo)
        end
    else
        g_inputBinding:setShowMouseCursor(false)
        if vehicle then
            RHMInputUtil.setCameraRotation(vehicle, true, self.savedCameraRotatableInfo)
        end
    end
end

-- EN: Key event handler. Allows pressing ESC to cleanly close calibration GUI or HUD cursor.
-- UA: Обробник подій клавіатури. Дозволяє клавішею ESC чисто закривати GUI калібрування або курсор HUD.
function RHM_RealisticHarvestManager:keyEvent(unicode, sym, modifier, isDown)
    if isDown and sym == Input.KEY_esc then
        if self.calibrationGUI and self.calibrationGUI.isOpen then
            self.calibrationGUI:close()
            return true
        end
        if self.isCursorVisible then
            self.isCursorVisible = false
            g_inputBinding:setShowMouseCursor(false)
            local vehicle = self:getControlledVehicle()
            if vehicle then
                RHMInputUtil.setCameraRotation(vehicle, true, self.savedCameraRotatableInfo)
            end
            return true
        end
    end
    return false
end

-- ============================================================================
-- EN: PUBLIC API FOR THIRD-PARTY MODS (e.g. Advanced Damage System - ADS)
-- UA: ПУБЛІЧНИЙ API ДЛЯ СТОРОННІХ МОДІВ (напр. Advanced Damage System - ADS)
-- ============================================================================

---EN: Returns current feed-rate engine load (0 to 100+ %) for a given vehicle or active combine.
---UA: Повертає поточне навантаження двигуна від збирання (0 до 100+ %) для вказаного або активного комбайна.
---@param vehicle table|nil Optional vehicle object. If nil, uses currently controlled vehicle.
---@return number engineLoad Current load percentage (0.0 if not harvesting or not an RHM combine).
function RHM_RealisticHarvestManager:getEngineLoad(vehicle)
    local target = vehicle or self:getControlledVehicle()
    if not target then return 0.0 end

    local combine = findCombineInHierarchy(target.rootVehicle or target)
    if combine and combine.spec_rhm_Combine and combine.spec_rhm_Combine.loadCalculator then
        return combine.spec_rhm_Combine.loadCalculator:getEngineLoad() or 0.0
    end
    return 0.0
end

---EN: Checks if a vehicle is an active combine managed by Realistic Harvesting.
---UA: Перевіряє чи є транспорт активним комбайном під керуванням Realistic Harvesting.
---@param vehicle table|nil
---@return boolean
function RHM_RealisticHarvestManager:isRHMActive(vehicle)
    local target = vehicle or self:getControlledVehicle()
    if not target then return false end

    local combine = findCombineInHierarchy(target.rootVehicle or target)
    return (combine ~= nil and combine.spec_rhm_Combine ~= nil)
end

---EN: Returns live telemetry data table (load, moisture, cropLoss, tonPerHour, yield, etc.).
---UA: Повертає таблицю живої телеметрії (навантаження, вологість, втрати, продуктивність, врожайність тощо).
---@param vehicle table|nil
---@return table|nil
function RHM_RealisticHarvestManager:getVehicleData(vehicle)
    local target = vehicle or self:getControlledVehicle()
    if not target then return nil end

    local combine = findCombineInHierarchy(target.rootVehicle or target)
    if combine and combine.spec_rhm_Combine then
        return combine.spec_rhm_Combine.data
    end
    return nil
end
