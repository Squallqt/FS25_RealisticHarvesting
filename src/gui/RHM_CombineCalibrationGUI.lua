-- EN: High-end touchscreen field terminal for combine harvester calibration (CEBIS / CommandCenter style).
--     Features dynamic Tier progression:
--       - Tier 1 (Standard): Pure manual controls, no optimal markers, AUTO locked with informative prompt.
--       - Tier 2 (Sensor Kit): Displays glowing green sweet-spot bands on sliders with live deviation indicators.
--       - Tier 3 (Monitor): Unlocks live digital telemetry cards (Load, Speed Efficiency, Loss) and custom profile Save/Load.
--       - Tier 4 (Opti-Harvest AI): Cybernetic styling accents and active one-touch [AI AUTO-CALIBRATION].
--     Interactive horizontal track-bar sliders with recessed grooves, tick marks, direct dragging, and micro-step buttons [-]/[+].
--     Deep obsidian carbon glass aesthetic with zero blue cast, matching authentic in-cab agricultural displays.
-- UA: Висококласний сенсорний польовий термінал для калібрування комбайна (у стилі CEBIS / CommandCenter).
--     Має динамічну прогресію за рівнями (Tiers):
--       - Рівень 1 (Базовий): Чисте ручне керування, без оптимальних маркерів, AUTO заблоковано з підказкою.
--       - Рівень 2 (Сенсорний набір): Сяючі зелені смуги sweet-spot на слайдерах з точними показниками відхилення.
--       - Рівень 3 (Монітор): Картки цифрової телеметрії (Навантаження, ККД швидкості, Втрати) та Збереження/Завантаження профілів.
--       - Рівень 4 (Opti-Harvest AI): Кібернетичні акценти та активна кнопка [AI АВТО-КАЛІБРУВАННЯ] в один дотик.
--     Інтерактивні трек-слайдери з поглибленими пазами, мітками шкали, прямим перетягуванням та мікро-кнопками [-]/[+].
--     Глибоке карбонове скло без сторонніх синіх відтінків, що відповідає справжнім терміналам у кабіні.

RHMCombineCalibrationGUI = {}
local CombineCalibrationGUI_mt = Class(RHMCombineCalibrationGUI)

local PARAM_SECTION_MAP = {
    -- GRAIN
    rotor            = "SEPARATION",
    concave          = "SEPARATION",
    upperSieve       = "CLEANING",
    lowerSieve       = "CLEANING",
    fan              = "CLEANING",
    -- FORAGE
    chopLength       = "SEPARATION",
    kernelProcessor  = "SEPARATION",
    blower           = "DISCHARGE",
    -- ROOT
    shakingIntensity = "SEPARATION",
    feeder           = "SEPARATION",
}

local SECTIONS_ORDERED = {
    { key = "SEPARATION", label = "rhm_ui_section_separation" },
    { key = "CLEANING",   label = "rhm_ui_section_cleaning"   },
    { key = "DISCHARGE",  label = "rhm_ui_section_discharge"  },
}

function RHMCombineCalibrationGUI.new(modDirectory)
    local self = setmetatable({}, CombineCalibrationGUI_mt)
    self.modDirectory = modDirectory
    self.isOpen = false
    self.isCursorActive = false

    -- In-cab terminal layout
    self.ui = {
        x = 0.60, y = 0.35,
        w = 0.38, h = 0.55,
        margin       = 0.010,
        headerHeight = 0.038,
        statsHeight  = 0.032,
        lineHeight   = 0.036,
        sectionGap   = 0.020,
        fontSize     = 0.0125,
        titleSize    = 0.0150,
        sectionSize  = 0.0115,
        statusSize   = 0.0095,
        buttonW      = 0.017,
        buttonH      = 0.017,

        -- Deep obsidian carbon glass palette (neutral dark, subtle translucency)
        colors = {
            outerRim       = {0.20, 0.22, 0.25, 0.35}, -- 1px metallic rim
            bezel          = {0.06, 0.07, 0.08, 0.85}, -- Titanium outer frame (translucent)
            bg             = {0.018, 0.020, 0.024, 0.82}, -- Deep obsidian dark glass (translucent field view)
            header         = {0.040, 0.045, 0.052, 0.88}, -- Dark status bar
            headerAccent   = {0.18, 0.78, 0.42, 0.85}, -- Emerald harvest accent line
            sectionBg      = {0.030, 0.035, 0.042, 0.80}, -- Carbon strip for section headers
            sectionNotch   = {0.18, 0.78, 0.42, 0.95}, -- Emerald accent mark on section headers
            statsCardBg    = {0.015, 0.018, 0.022, 0.75}, -- Recessed telemetry card background
            statsCardBorder= {1.00, 1.00, 1.00, 0.08},
            separator      = {1.00, 1.00, 1.00, 0.06},
            paramRowHover  = {1.00, 1.00, 1.00, 0.025},

            -- Tactile Slider Colors
            trackGroove    = {0.012, 0.015, 0.018, 0.85}, -- Deep recessed groove
            trackBorder    = {0.060, 0.065, 0.075, 0.80},
            trackTick      = {1.00, 1.00, 1.00, 0.12},
            trackOptimal   = {0.12, 0.65, 0.35, 0.45}, -- Glowing green sweet spot band
            trackOptimalBorder = {0.20, 0.85, 0.50, 0.70},
            trackCenterNotch   = {0.30, 1.00, 0.60, 0.95},
            trackThumb     = {0.94, 0.95, 0.97, 1.00}, -- Brushed metallic silver
            trackThumbHover= {1.00, 1.00, 1.00, 1.00},
            trackFill      = {0.18, 0.80, 0.45, 0.85}, -- Emerald fill
            trackFillWarn  = {0.95, 0.72, 0.18, 0.85}, -- Warm amber fill
            trackFillErr   = {0.90, 0.24, 0.24, 0.85}, -- Alert ruby red fill

            text           = {0.94, 0.95, 0.97, 1.00},
            textDim        = {0.60, 0.63, 0.68, 1.00},
            success        = {0.20, 0.85, 0.48, 1.00}, -- Crisp emerald green
            warning        = {0.95, 0.72, 0.18, 1.00}, -- Warm amber
            error          = {0.90, 0.24, 0.24, 1.00}, -- Alert red

            button         = {0.055, 0.060, 0.070, 0.85},
            buttonBorder   = {1.00, 1.00, 1.00, 0.08},
            buttonHover    = {0.12, 0.14, 0.16, 0.95},
            buttonAuto     = {0.08, 0.42, 0.24, 0.90}, -- Rich emerald pill
            buttonAutoBorder={0.20, 0.85, 0.50, 0.85},
            buttonAutoHover= {0.12, 0.55, 0.32, 1.00},
            buttonReset    = {0.14, 0.07, 0.07, 0.85},
            buttonResetBorder={0.35, 0.10, 0.10, 0.50},
            buttonResetHover={0.38, 0.10, 0.10, 1.00},
        }
    }

    self.activeVehicle = nil
    self.hoveredElement = nil
    self.mouseX = 0
    self.mouseY = 0
    self.hoveredParameter = nil
    self.draggingSlider = nil

    self.savedCameraRotatableInfo = {}
    self.savedCameraZoomInfo = {}

    self.lastScrollTimeStamp = 0
    self.scrollDelayMs = 100

    self.buttons = {}
    self.sliders = {}

    self.isDraggingTablet = false
    self.dragOffsetTabletX = 0
    self.dragOffsetTabletY = 0
    self.hasCustomPosition = false

    local bgTexture = self.modDirectory .. "textures/hud_icons.dds"
    self.overlay = Overlay.new(bgTexture, 0, 0, 1, 1)
    if GuiUtils and GuiUtils.getUVs then
        self.overlay:setUVs(GuiUtils.getUVs({388, 4, 56, 56}, {512, 64}))
    else
        self.overlay:setUVs({0.758, 0.062, 0.758, 0.937, 0.867, 0.062, 0.867, 0.937})
    end

    return self
end

function RHMCombineCalibrationGUI:delete()
    if self.overlay then
        self.overlay:delete()
        self.overlay = nil
    end
end

function RHMCombineCalibrationGUI:toggle(vehicle)
    if self.isOpen then
        self:close()
    else
        self:open(vehicle)
    end
end

function RHMCombineCalibrationGUI:open(vehicle)
    if self.isOpen then return end

    local combineVehicle = vehicle
    if vehicle and not vehicle.spec_rhm_Combine then
        local function findCombine(v, visited)
            if not v or visited[v] then return nil end
            visited[v] = true
            if v.spec_rhm_Combine then return v end
            if v.rootVehicle then
                local r = findCombine(v.rootVehicle, visited)
                if r then return r end
            end
            if v.attacherVehicle then
                local r = findCombine(v.attacherVehicle, visited)
                if r then return r end
            end
            if v.getAttachedImplements then
                for _, impl in ipairs(v:getAttachedImplements() or {}) do
                    if impl.object then
                        local r = findCombine(impl.object, visited)
                        if r then return r end
                    end
                end
            end
            return nil
        end
        local found = findCombine(vehicle.rootVehicle or vehicle, {})
        if found then
            combineVehicle = found
            rhm_log(string.format("RHM [UI]: RHM: [GUI] NEXAT: found combine vehicle in hierarchy: %s", tostring(combineVehicle)))
        else
            rhm_log("RHM [UI]: RHM: [GUI] No combine with spec_rhm_Combine found in vehicle hierarchy — GUI will not open")
            return
        end
    end

    self.isOpen = true

    -- Notify compatibility layer (IC, Headtracking) to suspend conflicting overlays and exclusive action events
    if RHM_ModCompatibility and RHM_ModCompatibility.onCalibrationGUIOpened then
        RHM_ModCompatibility.onCalibrationGUIOpened()
    end

    g_inputBinding:setShowMouseCursor(true)
    self.isCursorActive = true

    local cv = nil
    if g_realisticHarvestManager and g_realisticHarvestManager.getControlledVehicle then
        cv = g_realisticHarvestManager:getControlledVehicle()
    end
    if not cv then
        if g_localPlayer and g_localPlayer.getCurrentVehicle then
            cv = g_localPlayer:getCurrentVehicle()
        elseif g_currentMission then
            if g_currentMission.getControlledVehicle then
                cv = g_currentMission:getControlledVehicle()
            elseif g_currentMission.controlledVehicle then
                cv = g_currentMission.controlledVehicle
            end
        end
    end

    local camTarget = (cv and cv.spec_enterable and cv)
                   or (vehicle and vehicle.spec_enterable and vehicle)
                   or (combineVehicle and combineVehicle.spec_enterable and combineVehicle)

    if camTarget and camTarget.spec_enterable then
        RHMInputUtil.setCameraRotation(camTarget, false, self.savedCameraRotatableInfo)
        RHMInputUtil.setCameraZoom(camTarget, false, self.savedCameraZoomInfo)
    end

    self.activeVehicle = combineVehicle
    self.controllerVehicle = cv or vehicle or combineVehicle

    -- Validate active crop on the combine
    if combineVehicle and combineVehicle.spec_rhm_Combine and combineVehicle.spec_rhm_Combine.combineMemory then
        local mem = combineVehicle.spec_rhm_Combine.combineMemory
        local mType = combineVehicle.spec_rhm_Combine.machineType or "grain"
        local mapCrops = RHM_CombineSettingsDatabase:getCropNamesForMachineType(mType, combineVehicle)

        local isValidCrop = false
        local canonicalCurrent = RHM_CombineSettingsDatabase and RHM_CombineSettingsDatabase.getCanonicalCropName and RHM_CombineSettingsDatabase:getCanonicalCropName(mem.currentCrop)
        if mem.currentCrop and mapCrops then
            for _, c in ipairs(mapCrops) do
                if c == mem.currentCrop or (canonicalCurrent and c == canonicalCurrent) then
                    mem.currentCrop = c
                    isValidCrop = true
                    break
                end
            end
            if not isValidCrop and RHM_CombineSettingsDatabase and RHM_CombineSettingsDatabase.cropAliases then
                local alias = RHM_CombineSettingsDatabase.cropAliases[mem.currentCrop]
                if alias then
                    local canonicalAlias = RHM_CombineSettingsDatabase:getCanonicalCropName(alias)
                    for _, c in ipairs(mapCrops) do
                        if c == alias or (canonicalAlias and c == canonicalAlias) then
                            mem.currentCrop = c
                            isValidCrop = true
                            break
                        end
                    end
                end
            end
        end

        if not isValidCrop and mapCrops and #mapCrops > 0 then
            local defaultCrop = mapCrops[1]
            local preferred = (mType == "grain" and "WHEAT")
                           or (mType == "root" and "POTATO")
                           or (mType == "forage" and "MAIZE_FORAGE")
                           or (mType == "cotton" and "COTTON")
            if preferred then
                for _, c in ipairs(mapCrops) do
                    if c == preferred then
                        defaultCrop = preferred
                        break
                    end
                end
            end
            mem.currentCrop = defaultCrop
            if combineVehicle.spec_rhm_Combine.loadCalculator then
                combineVehicle.spec_rhm_Combine.loadCalculator.currentCrop = defaultCrop
            end
        end
    end
end

function RHMCombineCalibrationGUI:close()
    if not self.isOpen then return end

    self.isOpen = false
    self.isCursorActive = false
    self.draggingSlider = nil

    -- Notify compatibility layer that calibration GUI has closed
    if RHM_ModCompatibility and RHM_ModCompatibility.onCalibrationGUIClosed then
        RHM_ModCompatibility.onCalibrationGUIClosed()
    end

    local vehicle = self.controllerVehicle or (g_realisticHarvestManager and g_realisticHarvestManager:getControlledVehicle()) or self.activeVehicle
    local camTarget = (vehicle and vehicle.spec_enterable and vehicle)
                   or (self.activeVehicle and self.activeVehicle.spec_enterable and self.activeVehicle)

    local otherModOwnsCursor = false
    if CpHud and CpHud.isHudActive then
        otherModOwnsCursor = true
    end
    if AutoDrive and AutoDrive.isEditorModeEnabled and AutoDrive:isEditorModeEnabled() then
        otherModOwnsCursor = true
    end
    if VehicleMouseCursor and VehicleMouseCursor._cursorOwned then
        otherModOwnsCursor = true
    end

    if not otherModOwnsCursor then
        g_inputBinding:setShowMouseCursor(false)
    end

    if camTarget and camTarget.spec_enterable then
        RHMInputUtil.setCameraRotation(camTarget, true, self.savedCameraRotatableInfo)
        RHMInputUtil.setCameraZoom(camTarget, true, self.savedCameraZoomInfo)
    end
    self.savedCameraRotatableInfo = {}
    self.savedCameraZoomInfo = {}
end

function RHMCombineCalibrationGUI:cycleCrop(direction)
    local spec = self.activeVehicle.spec_rhm_Combine
    local machineType = spec.machineType or "grain"
    local crops = RHM_CombineSettingsDatabase:getCropNamesForMachineType(machineType, self.activeVehicle)
    if #crops == 0 then return end

    local current = spec.combineMemory.currentCrop
    local canonicalCurrent = RHM_CombineSettingsDatabase and RHM_CombineSettingsDatabase.getCanonicalCropName and RHM_CombineSettingsDatabase:getCanonicalCropName(current)
    local index = 1

    if current then
        for i, name in ipairs(crops) do
            if name == current or (canonicalCurrent and name == canonicalCurrent) then
                index = i
                break
            end
        end
        if index == 1 and crops[1] ~= current and (not canonicalCurrent or crops[1] ~= canonicalCurrent) and RHM_CombineSettingsDatabase and RHM_CombineSettingsDatabase.cropAliases then
            local alias = RHM_CombineSettingsDatabase.cropAliases[current]
            if alias then
                local canonicalAlias = RHM_CombineSettingsDatabase:getCanonicalCropName(alias)
                for i, name in ipairs(crops) do
                    if name == alias or (canonicalAlias and name == canonicalAlias) then
                        index = i
                        break
                    end
                end
            end
        end
        index = index + direction
    else
        index = (direction > 0) and 1 or #crops
    end

    if index > #crops then index = 1 end
    if index < 1 then index = #crops end

    local newCrop = crops[index]
    spec.combineMemory:switchCrop(newCrop)
end

function RHMCombineCalibrationGUI:update(dt)
    if not self.isOpen then return end

    -- Keep mouse cursor explicitly visible while calibration GUI is open
    if g_inputBinding and g_inputBinding.setShowMouseCursor then
        g_inputBinding:setShowMouseCursor(true)
    end

    -- Keep camera rotation and translation blocked while GUI is open
    local vehicle = self.controllerVehicle or (g_realisticHarvestManager and g_realisticHarvestManager:getControlledVehicle()) or self.activeVehicle
    local camTarget = (vehicle and vehicle.spec_enterable and vehicle)
                   or (self.activeVehicle and self.activeVehicle.spec_enterable and self.activeVehicle)
    if camTarget and camTarget.spec_enterable and camTarget.spec_enterable.cameras then
        for _, camera in pairs(camTarget.spec_enterable.cameras) do
            camera.isRotatable = false
            camera.allowTranslation = false
        end
    end

    -- Suppress IC active controller while calibration GUI is open
    if g_currentMission and g_currentMission.interactiveControl then
        if g_currentMission.interactiveControl.activeController ~= nil then
            if type(g_currentMission.interactiveControl.setActiveInteractiveController) == "function" then
                g_currentMission.interactiveControl:setActiveInteractiveController(nil)
            end
        end
    end

    -- Keep VMC cursor overlay suppressed while calibration GUI is open
    if VehicleMouseCursor ~= nil and VehicleMouseCursor._cursorGui ~= nil then
        if VehicleMouseCursor._cursorGui.isOpen then
            VehicleMouseCursor._cursorGui.isOpen = false
        end
        VehicleMouseCursor._cursorOwned = false
    end

    if not self.activeVehicle then
        self:close()
        return
    end

    local vehicleToCheck = self.controllerVehicle or self.activeVehicle
    local isEntered = false

    if vehicleToCheck then
        local cv = nil
        if g_realisticHarvestManager and g_realisticHarvestManager.getControlledVehicle then
            cv = g_realisticHarvestManager:getControlledVehicle()
        end
        if not cv then
            if g_localPlayer and g_localPlayer.getCurrentVehicle then
                cv = g_localPlayer:getCurrentVehicle()
            elseif g_currentMission then
                if g_currentMission.getControlledVehicle then
                    cv = g_currentMission:getControlledVehicle()
                elseif g_currentMission.controlledVehicle then
                    cv = g_currentMission.controlledVehicle
                end
            end
        end

        if cv then
            if cv == vehicleToCheck then
                isEntered = true
            else
                local rootA = cv.rootVehicle or cv
                local rootB = vehicleToCheck.rootVehicle or vehicleToCheck
                if rootA == rootB then
                    isEntered = true
                end
            end
        end

        if not isEntered and vehicleToCheck.getIsEntered then
            isEntered = vehicleToCheck:getIsEntered()
        end
        if not isEntered and vehicleToCheck.spec_enterable and vehicleToCheck.spec_enterable.isEntered then
            isEntered = true
        end
        if not isEntered and vehicleToCheck.getIsAIActive and vehicleToCheck:getIsAIActive() then
            if vehicleToCheck.isEntered or (vehicleToCheck.rootVehicle and vehicleToCheck.rootVehicle.isEntered) then
                isEntered = true
            end
        end
    end

    if not isEntered then
        self:close()
    end
end

function RHMCombineCalibrationGUI:draw()
    if not self.isOpen then return end
    if not (g_currentMission and g_currentMission.hud) then return end

    self.buttons = {}
    self.sliders = {}
    self.hoveredParameter = nil

    local ui = self.ui
    local spec = self.activeVehicle and self.activeVehicle.spec_rhm_Combine

    if spec and spec.combineMemory then
        local machineType = spec.machineType or "grain"
        local activeParams = RHM_CombineSettingsDatabase:getParamsForMachineType(machineType)
        local numParams = #activeParams + 1 -- +1 for targetEngineLoad

        local sectionsShown = 0
        for _, section in ipairs(SECTIONS_ORDERED) do
            for _, p in ipairs(activeParams) do
                if PARAM_SECTION_MAP[p] == section.key then
                    sectionsShown = sectionsShown + 1
                    break
                end
            end
        end
        sectionsShown = sectionsShown + 1 -- +1 for PERFORMANCE section

        local packageLevel = spec.packageLevel or 1
        local actualStatsHeight = (packageLevel >= 3) and (ui.statsHeight + ui.margin * 0.4) or 0

        local dynamicH = ui.headerHeight
                       + actualStatsHeight
                       + ui.lineHeight + 0.004 -- crop row
                       + (sectionsShown * ui.sectionGap)
                       + (numParams * ui.lineHeight)
                       + (ui.lineHeight * 2.1) -- action buttons
                       + ui.margin * 3.0

        ui.h = dynamicH
        if not self.hasCustomPosition then
            -- EN: Cleanly offset below the base game top-right clock/money bar (bar bottom ≈ 0.920).
            --     Leaves ~40px breathing margin from the top HUD and ~70px above the speedometer.
            -- UA: Чистий відступ нижче верхньої смуги годинника/грошей базової гри (низ смуги ≈ 0.920).
            --     Залишає ~40px відступу від верхнього HUD та ~70px над спідометром.
            local topY = 0.880
            ui.y = topY - dynamicH
            ui.x = 1.0 - ui.w - 0.016
        end
    else
        ui.h = 0.50
        if not self.hasCustomPosition then
            ui.y = 0.38
            ui.x = 1.0 - ui.w - 0.016
        end
    end

    local x, y = ui.x, ui.y
    local w, h = ui.w, ui.h

    -- ── Outer Metallic Rim & Obsidian Glass Panel ───────────────────────────
    local rimW = 0.0012
    self:drawRect(x - rimW * 2, y - rimW * 2, w + rimW * 4, h + rimW * 4, ui.colors.outerRim)
    self:drawRect(x - rimW, y - rimW, w + rimW * 2, h + rimW * 2, ui.colors.bezel)
    self:drawRect(x, y, w, h, ui.colors.bg)

    -- ── Terminal Status Header ──────────────────────────────────────────────
    local headerY = y + h - ui.headerHeight
    self:drawRect(x, headerY, w, ui.headerHeight, ui.colors.header)
    self:drawRect(x, headerY, w, 0.0015, ui.colors.headerAccent)

    -- Tier Badge & Combine Model
    local packageLevel = (spec and spec.packageLevel) or 1
    local tierConfigs = {
        [1] = { label = g_i18n:hasText("rhm_ui_tier1_manual") and g_i18n:getText("rhm_ui_tier1_manual") or "TIER 1 - MANUAL",  bg = {0.10, 0.11, 0.13, 0.90}, text = {0.68, 0.70, 0.74, 1.0} },
        [2] = { label = g_i18n:hasText("rhm_ui_tier2_sensors") and g_i18n:getText("rhm_ui_tier2_sensors") or "TIER 2 - SENSORS", bg = {0.18, 0.12, 0.04, 0.90}, text = {0.95, 0.72, 0.18, 1.0} },
        [3] = { label = g_i18n:hasText("rhm_ui_tier3_monitor") and g_i18n:getText("rhm_ui_tier3_monitor") or "TIER 3 - MONITOR", bg = {0.04, 0.16, 0.08, 0.90}, text = {0.20, 0.85, 0.45, 1.0} },
        [4] = { label = g_i18n:hasText("rhm_ui_tier4_opti") and g_i18n:getText("rhm_ui_tier4_opti") or "TIER 4 - AI OPTI", bg = {0.04, 0.18, 0.22, 0.90}, text = {0.18, 0.82, 0.92, 1.0} }
    }
    local tier = tierConfigs[math.min(4, math.max(1, packageLevel))] or tierConfigs[1]

    local badgeW = 0.065
    local badgeH = 0.017
    local badgeX = x + ui.margin
    local badgeY = headerY + (ui.headerHeight - badgeH) * 0.5
    self:drawRect(badgeX, badgeY, badgeW, badgeH, tier.bg)
    self:drawRect(badgeX, badgeY, badgeW, 0.0006, tier.text)
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextBold(true)
    setTextColor(unpack(tier.text))
    renderText(badgeX + badgeW * 0.5, badgeY + badgeH * 0.25, ui.fontSize * 0.68, tier.label)

    -- Combine Brand & Model
    local vName = self.activeVehicle and self.activeVehicle:getName() or "COMBINE"
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextColor(unpack(ui.colors.text))
    local titleX = badgeX + badgeW + 0.008
    renderText(titleX, headerY + ui.headerHeight * 0.32, ui.titleSize, string.upper(vName))

    -- Circular Close [✕] Button
    local closeBtnW = 0.018
    local closeBtnH = ui.headerHeight * 0.60
    local closeBtnX = x + w - ui.margin - closeBtnW
    local closeBtnY = headerY + (ui.headerHeight - closeBtnH) * 0.5
    self:drawButton(closeBtnX, closeBtnY, closeBtnW, closeBtnH, "X", function()
        self:close()
    end, {0.22, 0.08, 0.08, 0.85})

    local cy = headerY - ui.margin * 0.5

    if not self.activeVehicle or not spec or not spec.combineMemory then
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextColor(unpack(ui.colors.textDim))
        local notInitText = g_i18n:hasText("rhm_ui_combine_not_init") and g_i18n:getText("rhm_ui_combine_not_init") or "Combine not initialized"
        renderText(x + w * 0.5, cy - ui.lineHeight, ui.fontSize, notInitText)
        self:_resetTextState()
        return
    end

    local memory = spec.combineMemory
    local machineType = spec.machineType or "grain"

    -- ── Tier 3+ Live Telemetry Cards ────────────────────────────────────────
    if packageLevel >= 3 then
        cy = cy - ui.statsHeight
        local cardGap = 0.004
        local innerW = w - ui.margin * 2
        local cardW = (innerW - cardGap * 2) / 3
        local cardH = ui.statsHeight
        local startX = x + ui.margin

        local load = (spec.loadCalculator and spec.loadCalculator.engineLoad or 0) * 100
        local effPenalty = 0
        local lossPenalty = 0
        if memory.currentCrop then
            local context = self:getHarvestContext(machineType)
            effPenalty, lossPenalty, _ = memory:checkSettingsForCrop(memory.currentCrop, context)
        end
        local isForage = (machineType == "forage")

        -- Card 1: Engine Load
        local cx1 = startX
        self:drawRect(cx1, cy, cardW, cardH, ui.colors.statsCardBg)
        self:drawRect(cx1, cy + cardH - 0.0006, cardW, 0.0006, ui.colors.statsCardBorder)
        local loadColor = (load > 95) and ui.colors.error or ((load > 80) and ui.colors.warning or ui.colors.success)
        local cardLoadText = g_i18n:hasText("rhm_ui_card_engine_load") and g_i18n:getText("rhm_ui_card_engine_load") or "ENGINE LOAD"
        setTextBold(true)
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextColor(unpack(ui.colors.textDim))
        renderText(cx1 + cardW * 0.5, cy + cardH * 0.56, ui.statusSize * 0.85, cardLoadText)
        setTextColor(unpack(loadColor))
        renderText(cx1 + cardW * 0.5, cy + cardH * 0.14, ui.fontSize, string.format("%.0f%%", load))

        -- Card 2: Speed Efficiency
        local cx2 = cx1 + cardW + cardGap
        self:drawRect(cx2, cy, cardW, cardH, ui.colors.statsCardBg)
        self:drawRect(cx2, cy + cardH - 0.0006, cardW, 0.0006, ui.colors.statsCardBorder)
        local speedVal = math.max(0, effPenalty)
        local speedColor = (speedVal <= 0.05) and ui.colors.success or ((speedVal <= 2.0) and ui.colors.warning or ui.colors.error)
        local speedPrefix = (speedVal <= 0.05) and "" or "-"
        local cardEffText = g_i18n:hasText("rhm_ui_card_efficiency") and g_i18n:getText("rhm_ui_card_efficiency") or "EFFICIENCY"
        setTextColor(unpack(ui.colors.textDim))
        renderText(cx2 + cardW * 0.5, cy + cardH * 0.56, ui.statusSize * 0.85, cardEffText)
        setTextColor(unpack(speedColor))
        renderText(cx2 + cardW * 0.5, cy + cardH * 0.14, ui.fontSize, string.format("%s%.1f%%", speedPrefix, speedVal))

        -- Card 3: Predicted Loss
        local cx3 = cx2 + cardW + cardGap
        self:drawRect(cx3, cy, cardW, cardH, ui.colors.statsCardBg)
        self:drawRect(cx3, cy + cardH - 0.0006, cardW, 0.0006, ui.colors.statsCardBorder)
        local cardLossText = g_i18n:hasText("rhm_ui_card_predicted_loss") and g_i18n:getText("rhm_ui_card_predicted_loss") or "PREDICTED LOSS"
        setTextColor(unpack(ui.colors.textDim))
        renderText(cx3 + cardW * 0.5, cy + cardH * 0.56, ui.statusSize * 0.85, cardLossText)
        if isForage then
            setTextColor(unpack(ui.colors.textDim))
            renderText(cx3 + cardW * 0.5, cy + cardH * 0.14, ui.fontSize, "N/A")
        else
            local displayLoss = math.max(0, lossPenalty)
            local lossColor = (displayLoss <= 0.05) and ui.colors.success or ((displayLoss <= 2.0) and ui.colors.warning or ui.colors.error)
            setTextColor(unpack(lossColor))
            renderText(cx3 + cardW * 0.5, cy + cardH * 0.14, ui.fontSize, string.format("%.1f%%", displayLoss))
        end

        setTextBold(false)
        cy = cy - ui.margin * 0.4
    end

    -- ── Crop Selector & Auto Calibration Row ────────────────────────────────
    cy = cy - ui.lineHeight - 0.002

    local function getLocalizedCropName(rawName)
        if not rawName then return "NONE" end
        if RHM_CombineSettingsDatabase and RHM_CombineSettingsDatabase.getCropDisplayName then
            return RHM_CombineSettingsDatabase:getCropDisplayName(rawName)
        end
        return rawName
    end

    -- [<] CROP NAME [>]
    local cropNavX = x + ui.margin
    local arrowW = 0.020
    self:drawButton(cropNavX, cy + 0.004, arrowW, ui.buttonH + 0.004, "<", function()
        self:cycleCrop(-1)
    end)

    local cropName = getLocalizedCropName(memory.currentCrop)
    local cropBoxW = 0.135
    local cropBoxX = cropNavX + arrowW + 0.004
    self:drawRect(cropBoxX, cy + 0.004, cropBoxW, ui.buttonH + 0.004, {0.04, 0.045, 0.05, 0.90})
    self:drawRect(cropBoxX, cy + 0.004, cropBoxW, 0.0006, {1.0, 1.0, 1.0, 0.08})
    setTextBold(true)
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextColor(unpack(ui.colors.text))
    renderText(cropBoxX + cropBoxW * 0.5, cy + 0.009, ui.fontSize, cropName)
    setTextBold(false)

    self:drawButton(cropBoxX + cropBoxW + 0.004, cy + 0.004, arrowW, ui.buttonH + 0.004, ">", function()
        self:cycleCrop(1)
    end)

    -- AUTO Calibration Button
    local autoBtnW = 0.115
    local autoBtnX = x + w - ui.margin - autoBtnW
    local autoBtnH = ui.buttonH + 0.004

    if packageLevel >= 4 then
        local btnAutoText = g_i18n:hasText("rhm_ui_btn_ai_auto") and g_i18n:getText("rhm_ui_btn_ai_auto") or "AI AUTO-CALIB"
        self:drawButton(autoBtnX, cy + 0.004, autoBtnW, autoBtnH, btnAutoText, function()
            memory:requestAutoSettings()
        end, ui.colors.buttonAuto)
        self:drawRect(autoBtnX, cy + 0.004, autoBtnW, 0.0008, ui.colors.buttonAutoBorder)
    else
        self:drawRect(autoBtnX, cy + 0.004, autoBtnW, autoBtnH, {0.05, 0.055, 0.065, 0.85})
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextBold(true)
        setTextColor(0.40, 0.42, 0.46, 1.0)
        local btnLockedText = g_i18n:hasText("rhm_ui_btn_auto_locked") and g_i18n:getText("rhm_ui_btn_auto_locked") or "AUTO (LOCKED)"
        renderText(autoBtnX + autoBtnW * 0.5, cy + 0.009, ui.fontSize * 0.78, btnLockedText)
        setTextBold(false)

        table.insert(self.buttons, {
            x = autoBtnX, y = cy + 0.004, w = autoBtnW, h = autoBtnH,
            callback = function()
                local msg = g_i18n:hasText("rhm_msg_req_tier4") and g_i18n:getText("rhm_msg_req_tier4") or "Requires Opti-Harvest AI (Tier 4)"
                if RHM_NotificationManager and RHM_NotificationManager.INSTANCE then
                    RHM_NotificationManager.INSTANCE:showNotification("RHM", msg, 4000)
                elseif g_currentMission and g_currentMission.hud and g_currentMission.hud.showInGameMessage then
                    g_currentMission.hud:showInGameMessage("RHM", msg, -1)
                end
            end
        })
    end

    self:drawRect(x + ui.margin, cy - 0.004, w - ui.margin * 2, 0.001, ui.colors.separator)
    cy = cy - ui.margin * 0.3

    -- ── Parameter Sections ──────────────────────────────────────────────────
    local activeParams = RHM_CombineSettingsDatabase:getParamsForMachineType(machineType)
    local drawnParams = {}

    for _, section in ipairs(SECTIONS_ORDERED) do
        local hasAny = false
        for _, p in ipairs(activeParams) do
            if PARAM_SECTION_MAP[p] == section.key then
                hasAny = true
                break
            end
        end

        if hasAny then
            cy = cy - ui.sectionGap
            local secW = w - ui.margin * 2
            local secH = ui.sectionGap - 0.004
            self:drawRect(x + ui.margin, cy + 0.002, secW, secH, ui.colors.sectionBg)
            self:drawRect(x + ui.margin, cy + 0.002, 0.0025, secH, ui.colors.sectionNotch)

            setTextBold(true)
            setTextAlignment(RenderText.ALIGN_LEFT)
            setTextColor(unpack(ui.colors.text))
            local sLabel = g_i18n:hasText(section.label) and g_i18n:getText(section.label) or section.key
            renderText(x + ui.margin + 0.006, cy + 0.006, ui.sectionSize, sLabel)

            for _, p in ipairs(activeParams) do
                if PARAM_SECTION_MAP[p] == section.key and not drawnParams[p] then
                    cy = cy - ui.lineHeight
                    local labelKey = RHM_CombineSettingsDatabase:getParamLabel(machineType, p)
                    local label = g_i18n:hasText(labelKey) and g_i18n:getText(labelKey) or p
                    self:drawParameterRow(x + ui.margin, cy, secW, p, label, memory, ui, machineType, packageLevel)
                    drawnParams[p] = true
                end
            end
        end
    end

    -- PERFORMANCE Section
    cy = cy - ui.sectionGap
    local secW = w - ui.margin * 2
    local secH = ui.sectionGap - 0.004
    self:drawRect(x + ui.margin, cy + 0.002, secW, secH, ui.colors.sectionBg)
    self:drawRect(x + ui.margin, cy + 0.002, 0.0025, secH, ui.colors.sectionNotch)
    setTextBold(true)
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextColor(unpack(ui.colors.text))
    local perfLabel = g_i18n:hasText("rhm_ui_section_performance") and g_i18n:getText("rhm_ui_section_performance") or "PERFORMANCE"
    renderText(x + ui.margin + 0.006, cy + 0.006, ui.sectionSize, perfLabel)

    for _, p in ipairs(activeParams) do
        if not drawnParams[p] then
            cy = cy - ui.lineHeight
            local labelKey = RHM_CombineSettingsDatabase:getParamLabel(machineType, p)
            local label = g_i18n:hasText(labelKey) and g_i18n:getText(labelKey) or p
            self:drawParameterRow(x + ui.margin, cy, secW, p, label, memory, ui, machineType, packageLevel)
            drawnParams[p] = true
        end
    end

    cy = cy - ui.lineHeight
    local loadLabel = g_i18n:hasText("rhm_target_load") and g_i18n:getText("rhm_target_load") or "Target Engine Load"
    self:drawParameterRow(x + ui.margin, cy, secW, "targetEngineLoad", loadLabel, memory, ui, machineType, packageLevel)

    cy = cy - ui.margin * 0.8
    self:drawRect(x + ui.margin, cy, w - ui.margin * 2, 0.001, ui.colors.separator)
    cy = cy - ui.margin * 0.6

    -- ── Action Buttons ──────────────────────────────────────────────────────
    cy = cy - ui.lineHeight * 1.0
    local actionBtnW = (w - ui.margin * 2.5) / 2

    if packageLevel >= 2 then
        local btnLoadText = g_i18n:hasText("rhm_ui_btn_load_preset") and g_i18n:getText("rhm_ui_btn_load_preset") or "LOAD PRESET"
        self:drawButton(x + ui.margin, cy, actionBtnW, 0.026, btnLoadText, function()
            local success = memory:loadUserPreset()
            local msg = ""
            if success then
                local cropTitle = memory.currentCrop
                if RHM_CombineSettingsDatabase and RHM_CombineSettingsDatabase.getCropDisplayName then
                    cropTitle = RHM_CombineSettingsDatabase:getCropDisplayName(memory.currentCrop)
                end
                local formatStr = g_i18n:hasText("rhm_msg_profile_loaded") and g_i18n:getText("rhm_msg_profile_loaded") or "Loaded Profile: %s"
                msg = string.format(formatStr, tostring(cropTitle))
            else
                msg = g_i18n:hasText("rhm_msg_profile_not_found") and g_i18n:getText("rhm_msg_profile_not_found") or "No saved profile found for this crop"
            end
            if RHM_NotificationManager and RHM_NotificationManager.INSTANCE then
                RHM_NotificationManager.INSTANCE:showNotification("RHM", msg, 4000)
            elseif g_currentMission and g_currentMission.hud and g_currentMission.hud.showInGameMessage then
                g_currentMission.hud:showInGameMessage("RHM", msg, -1)
            end
        end, {0.08, 0.10, 0.12, 0.95})

        local btnSaveText = g_i18n:hasText("rhm_ui_btn_save_profile") and g_i18n:getText("rhm_ui_btn_save_profile") or "SAVE PROFILE"
        self:drawButton(x + w - ui.margin - actionBtnW, cy, actionBtnW, 0.026, btnSaveText, function()
            local success = memory:saveCurrentProfile(memory.currentCrop)
            if success then
                local cropTitle = memory.currentCrop
                if RHM_CombineSettingsDatabase and RHM_CombineSettingsDatabase.getCropDisplayName then
                    cropTitle = RHM_CombineSettingsDatabase:getCropDisplayName(memory.currentCrop)
                end
                local formatStr = g_i18n:hasText("rhm_msg_profile_saved") and g_i18n:getText("rhm_msg_profile_saved") or "Saved Profile: %s"
                local msg = string.format(formatStr, tostring(cropTitle))
                if RHM_NotificationManager and RHM_NotificationManager.INSTANCE then
                    RHM_NotificationManager.INSTANCE:showNotification("RHM", msg, 4000)
                elseif g_currentMission and g_currentMission.hud and g_currentMission.hud.showInGameMessage then
                    g_currentMission.hud:showInGameMessage("RHM", msg, -1)
                end
            end
        end, {0.08, 0.10, 0.12, 0.95})
    else
        local btnLoadLockText = g_i18n:hasText("rhm_ui_btn_load_locked") and g_i18n:getText("rhm_ui_btn_load_locked") or "LOAD (LOCKED)"
        self:drawButton(x + ui.margin, cy, actionBtnW, 0.026, btnLoadLockText, function()
            local msg = (g_i18n:hasText("rhm_msg_req_tier2") and g_i18n:getText("rhm_msg_req_tier2"))
                     or (g_i18n:hasText("rhm_msg_req_tier3") and g_i18n:getText("rhm_msg_req_tier3"))
                     or "Profiles require Sensors Package (Tier 2)"
            if RHM_NotificationManager and RHM_NotificationManager.INSTANCE then
                RHM_NotificationManager.INSTANCE:showNotification("RHM", msg, 4000)
            elseif g_currentMission and g_currentMission.hud and g_currentMission.hud.showInGameMessage then
                g_currentMission.hud:showInGameMessage("RHM", msg, -1)
            end
        end, {0.05, 0.055, 0.065, 0.70})

        local btnSaveLockText = g_i18n:hasText("rhm_ui_btn_save_locked") and g_i18n:getText("rhm_ui_btn_save_locked") or "SAVE (LOCKED)"
        self:drawButton(x + w - ui.margin - actionBtnW, cy, actionBtnW, 0.026, btnSaveLockText, function()
            local msg = (g_i18n:hasText("rhm_msg_req_tier2") and g_i18n:getText("rhm_msg_req_tier2"))
                     or (g_i18n:hasText("rhm_msg_req_tier3") and g_i18n:getText("rhm_msg_req_tier3"))
                     or "Profiles require Sensors Package (Tier 2)"
            if RHM_NotificationManager and RHM_NotificationManager.INSTANCE then
                RHM_NotificationManager.INSTANCE:showNotification("RHM", msg, 4000)
            elseif g_currentMission and g_currentMission.hud and g_currentMission.hud.showInGameMessage then
                g_currentMission.hud:showInGameMessage("RHM", msg, -1)
            end
        end, {0.05, 0.055, 0.065, 0.70})
    end

    cy = cy - ui.lineHeight * 1.0
    local resetBtnW = w - ui.margin * 2
    local resetBtnText = g_i18n:hasText("rhm_ui_btn_reset_defaults") and g_i18n:getText("rhm_ui_btn_reset_defaults") or "RESET TO FACTORY DEFAULTS"
    self:drawButton(x + ui.margin, cy, resetBtnW, 0.026, resetBtnText, function()
        memory:requestResetSettings()
    end, ui.colors.buttonReset)

    -- ── Scroll Wheel Handling ───────────────────────────────────────────────
    if self.lastScrollTimeStamp + self.scrollDelayMs < g_time then
        local mx, my = g_inputBinding:getMousePosition()
        if mx and my and mx >= ui.x and mx <= ui.x + ui.w and my >= ui.y and my <= ui.y + ui.h then
            if Input.isMouseButtonPressed(Input.MOUSE_BUTTON_WHEEL_UP) then
                self.lastScrollTimeStamp = g_time
                self:handleWheelScroll(1, mx, my)
            elseif Input.isMouseButtonPressed(Input.MOUSE_BUTTON_WHEEL_DOWN) then
                self.lastScrollTimeStamp = g_time
                self:handleWheelScroll(-1, mx, my)
            end
        end
    end

    self:_resetTextState()
end

---EN: Draws an interactive parameter row with direct track slider and [-][+] micro-buttons.
---UA: Малює інтерактивний рядок параметра з прямим трек-слайдером та мікро-кнопками [-][+].
function RHMCombineCalibrationGUI:drawParameterRow(x, y, w, param, label, memory, ui, machineType, packageLevel)
    local val = memory.currentSettings[param] or 0
    local optimal = 0
    local tolerance = 5
    local isOptimal = false
    local hasOptimal = false

    local isRowHovered = self:checkHover(x, y - 0.003, w, ui.lineHeight)
    if isRowHovered then
        self:drawRect(x, y - 0.003, w, ui.lineHeight, ui.colors.paramRowHover)
        self.hoveredParameter = param
    end

    -- Query optimal value from DB
    if RHM_CombineSettingsDatabase and memory.currentCrop then
        local context = self:getHarvestContext(machineType)
        local settings = RHM_CombineSettingsDatabase:getSettingsForCrop(memory.currentCrop, context)
        if settings and settings[param] then
            optimal = settings[param].optimal
            tolerance = settings[param].tolerance or 5
            isOptimal = math.abs(val - optimal) <= tolerance
            hasOptimal = true
        end
    end

    -- Format physical value
    local displayStr = ""
    if RHM_UnitConverter and RHM_UnitConverter.formatSetting then
        displayStr = RHM_UnitConverter.formatSetting(param, val, machineType)
    else
        displayStr = string.format("%d%%", val)
    end

    -- Proportions (Grid Column System with dedicated Telemetry Capsule)
    local labelW       = 0.100
    local valBoxW      = 0.046
    local pillW        = 0.054
    local pillH        = 0.016
    local sliderW      = 0.108
    local microBtnW    = 0.015
    local microBtnH    = 0.016

    local valBoxX      = x + labelW
    local pillX        = valBoxX + valBoxW + 0.005
    local sliderStartX = pillX + pillW + 0.007
    local btnStartX    = sliderStartX + sliderW + 0.006

    -- Determine colors & status text based on Tier progression
    local valColor = ui.colors.text
    local statusText = ""
    local statusColor = ui.colors.textDim
    local pillBg = {0.04, 0.045, 0.05, 0.80}
    local pillBorder = {1.0, 1.0, 1.0, 0.10}
    local fillColor = ui.colors.trackFill

    if packageLevel >= 2 and hasOptimal and param ~= "targetEngineLoad" then
        if isOptimal then
            valColor = ui.colors.success
            statusText = g_i18n:hasText("rhm_ui_status_optimal") and g_i18n:getText("rhm_ui_status_optimal") or "OPTIMAL"
            statusColor = ui.colors.success
            pillBg = {0.02, 0.14, 0.06, 0.85}
            pillBorder = {0.20, 0.85, 0.48, 0.50}
            fillColor = ui.colors.trackFill
        else
            local deviation = math.abs(val - optimal) - tolerance
            if deviation > 20 then
                valColor = ui.colors.error
                statusColor = ui.colors.error
                pillBg = {0.16, 0.03, 0.03, 0.85}
                pillBorder = {0.90, 0.24, 0.24, 0.50}
                fillColor = ui.colors.trackFillErr
            else
                valColor = ui.colors.warning
                statusColor = ui.colors.warning
                pillBg = {0.16, 0.10, 0.02, 0.85}
                pillBorder = {0.95, 0.72, 0.18, 0.50}
                fillColor = ui.colors.trackFillWarn
            end
            local lowText = g_i18n:hasText("rhm_ui_status_low") and g_i18n:getText("rhm_ui_status_low") or "LOW"
            local highText = g_i18n:hasText("rhm_ui_status_high") and g_i18n:getText("rhm_ui_status_high") or "HIGH"
            statusText = (val < optimal) and lowText or highText
        end
    else
        valColor = ui.colors.text
        statusText = ""
        fillColor = {0.45, 0.48, 0.52, 0.85}
        hasOptimal = false
    end

    -- ── Label ──────────────────────────────────────────────────────────────
    setTextBold(true)
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextColor(unpack(ui.colors.text))
    renderText(x + 0.002, y + 0.012, ui.fontSize, label)

    -- ── Physical Value in Recessed Dark Box ────────────────────────────────
    local valBoxH = 0.018
    local valBoxY = y + (ui.lineHeight - valBoxH) * 0.5
    self:drawRect(valBoxX, valBoxY, valBoxW, valBoxH, {0.018, 0.020, 0.024, 0.90})
    self:drawRect(valBoxX, valBoxY, valBoxW, 0.0006, {1.0, 1.0, 1.0, 0.08})

    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextColor(unpack(valColor))
    renderText(valBoxX + valBoxW * 0.5, valBoxY + 0.004, ui.fontSize * 0.92, displayStr)

    -- ── Status Pill Capsule (Option 1) ─────────────────────────────────────
    if statusText ~= "" and packageLevel >= 2 then
        local pillY = y + (ui.lineHeight - pillH) * 0.5
        self:drawRect(pillX, pillY, pillW, pillH, pillBg)
        self:drawRect(pillX, pillY, pillW, 0.0006, pillBorder)
        self:drawRect(pillX, pillY + pillH - 0.0006, pillW, 0.0006, pillBorder)
        self:drawRect(pillX, pillY, 0.0006, pillH, pillBorder)
        self:drawRect(pillX + pillW - 0.0006, pillY, 0.0006, pillH, pillBorder)

        setTextBold(true)
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextColor(unpack(statusColor))
        renderText(pillX + pillW * 0.5, pillY + 0.0035, ui.statusSize * 0.88, statusText)
    end

    -- ── Advanced Recessed Track Slider ─────────────────────────────────────
    local trackH = 0.0075
    local trackY = y + (ui.lineHeight - trackH) * 0.5

    -- Outer Groove Border & Slot
    self:drawRect(sliderStartX - 0.0006, trackY - 0.0006, sliderW + 0.0012, trackH + 0.0012, ui.colors.trackBorder)
    self:drawRect(sliderStartX, trackY, sliderW, trackH, ui.colors.trackGroove)

    -- Gauge Tick Notches (0%, 25%, 50%, 75%, 100%)
    for step = 0, 4 do
        local tickX = sliderStartX + (step / 4) * sliderW
        self:drawRect(tickX, trackY - 0.002, 0.0006, trackH + 0.004, ui.colors.trackTick)
    end

    -- Glowing Green Optimal Sweet-Spot Band (Tier 2+)
    if packageLevel >= 2 and hasOptimal then
        local optMin = math.max(0, optimal - tolerance)
        local optMax = math.min(100, optimal + tolerance)
        local bandStartX = sliderStartX + (optMin / 100) * sliderW
        local bandW = ((optMax - optMin) / 100) * sliderW
        self:drawRect(bandStartX, trackY, bandW, trackH, ui.colors.trackOptimal)
        self:drawRect(bandStartX, trackY, bandW, 0.0006, ui.colors.trackOptimalBorder)

        -- Bright center sweet-spot pin
        local centerPinX = sliderStartX + (optimal / 100) * sliderW
        self:drawRect(centerPinX, trackY - 0.001, 0.0008, trackH + 0.002, ui.colors.trackCenterNotch)
    end

    -- Active Value Fill
    local currentFillW = math.max(0, math.min(sliderW, (val / 100) * sliderW))
    self:drawRect(sliderStartX, trackY, currentFillW, trackH, fillColor)

    -- Tactile Metallic Thumb Handle
    local thumbW = 0.0055
    local thumbH = 0.0170
    local thumbX = sliderStartX + currentFillW - thumbW * 0.5
    local thumbY = trackY + (trackH - thumbH) * 0.5

    -- Thumb drop shadow & border
    self:drawRect(thumbX - 0.0006, thumbY - 0.0006, thumbW + 0.0012, thumbH + 0.0012, {0.02, 0.02, 0.02, 0.95})
    self:drawRect(thumbX, thumbY, thumbW, thumbH, (isRowHovered or self.draggingSlider) and ui.colors.trackThumbHover or ui.colors.trackThumb)

    -- Thumb center indicator groove
    self:drawRect(thumbX + thumbW * 0.5 - 0.0004, thumbY + 0.002, 0.0008, thumbH - 0.004, isOptimal and {0.18, 0.80, 0.45, 1.0} or {0.30, 0.35, 0.40, 1.0})

    -- Register Slider Hitbox for direct dragging
    table.insert(self.sliders, {
        x = sliderStartX,
        y = trackY - 0.006,
        w = sliderW,
        h = trackH + 0.012,
        param = param
    })

    -- Smart Step Function
    local function performSmartStep(direction)
        if param == "targetEngineLoad" then
            local newLoad = math.max(50, math.min(100, val + (direction * 5)))
            memory:updateSetting(param, newLoad)
            return
        end

        if RHM_UnitConverter and RHM_UnitConverter.percentToPhysical then
            local physVal = RHM_UnitConverter.percentToPhysical(param, val, machineType)
            local range = RHM_UnitConverter.getPhysicalRange(param, machineType)

            if range then
                local stepValue = (range.unit == "RPM") and 10 or 0.5
                local targetPhysVal = physVal

                local snapped = math.floor((physVal / stepValue) + 0.5) * stepValue
                if math.abs(physVal - snapped) > 0.01 then
                    if direction > 0 then
                        targetPhysVal = math.ceil(physVal / stepValue) * stepValue
                    else
                        targetPhysVal = math.floor(physVal / stepValue) * stepValue
                    end
                else
                    targetPhysVal = snapped + (stepValue * direction)
                end

                local targetPercent = RHM_UnitConverter.physicalToPercent(param, targetPhysVal, machineType)
                if math.abs(targetPercent - val) < 0.5 then
                    targetPercent = val + direction
                end
                memory:updateSetting(param, math.floor(targetPercent + 0.5))
            else
                memory:updateSetting(param, val + direction)
            end
        else
            memory:updateSetting(param, val + direction)
        end
    end

    -- Micro Fine-Tuning Buttons [-] and [+]
    local btnY = y + (ui.lineHeight - microBtnH) * 0.5
    self:drawButton(btnStartX, btnY, microBtnW, microBtnH, "-", function()
        performSmartStep(-1)
    end)

    self:drawButton(btnStartX + microBtnW + 0.003, btnY, microBtnW, microBtnH, "+", function()
        performSmartStep(1)
    end)
end

function RHMCombineCalibrationGUI:drawButton(x, y, w, h, text, callback, colorOverride)
    local isHovered = self:checkHover(x, y, w, h)
    local bgColor

    if colorOverride then
        bgColor = isHovered and {
            colorOverride[1] * 1.3,
            colorOverride[2] * 1.3,
            colorOverride[3] * 1.3,
            colorOverride[4]
        } or colorOverride
    elseif isHovered then
        bgColor = self.ui.colors.buttonHover
    else
        bgColor = self.ui.colors.button
    end

    self:drawRect(x, y, w, h, bgColor)
    self:drawRect(x, y, w, 0.0006, self.ui.colors.buttonBorder)

    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextBold(true)

    if isHovered then
        if text == "+" then
            setTextColor(0.20, 0.85, 0.48, 1.0)
        elseif text == "-" then
            setTextColor(0.95, 0.35, 0.35, 1.0)
        else
            setTextColor(1.0, 1.0, 1.0, 1.0)
        end
    else
        if text == "+" or text == "-" then
            setTextColor(0.70, 0.74, 0.80, 1.0)
        elseif colorOverride then
            setTextColor(unpack(self.ui.colors.text))
        else
            setTextColor(unpack(self.ui.colors.textDim))
        end
    end

    renderText(x + w * 0.5, y + h * 0.5 - self.ui.fontSize * 0.40, self.ui.fontSize, text)
    setTextBold(false)

    table.insert(self.buttons, {x=x, y=y, w=w, h=h, callback=callback})
end

function RHMCombineCalibrationGUI:drawRect(x, y, w, h, color)
    if not self.overlay then return end
    local r, g, b, a = unpack(color)
    self.overlay:setPosition(x, y)
    self.overlay:setDimension(w, h)
    self.overlay:setColor(r, g, b, a or 1.0)
    self.overlay:render()
end

function RHMCombineCalibrationGUI:_resetTextState()
    setTextBold(false)
    setTextColor(1, 1, 1, 1)
    setTextAlignment(RenderText.ALIGN_LEFT)
end

function RHMCombineCalibrationGUI:checkHover(x, y, w, h)
    local mx, my = self.mouseX, self.mouseY
    if not mx or not my then
        mx, my = g_inputBinding:getMousePosition()
    end
    return mx >= x and mx <= x + w and my >= y and my <= y + h
end

function RHMCombineCalibrationGUI:updateSliderFromMouse(slider, posX)
    local param = slider.param
    local spec = self.activeVehicle and self.activeVehicle.spec_rhm_Combine
    if not spec or not spec.combineMemory then return end

    local ratio = math.max(0, math.min(1, (posX - slider.x) / slider.w))
    local percent = math.floor(ratio * 100 + 0.5)

    if param == "targetEngineLoad" then
        percent = math.floor(percent / 5 + 0.5) * 5
        percent = math.max(50, math.min(100, percent))
        spec.combineMemory:updateSetting(param, percent)
        return
    end

    local machineType = spec.machineType or "grain"
    if RHM_UnitConverter and RHM_UnitConverter.percentToPhysical and RHM_UnitConverter.getPhysicalRange then
        local physVal = RHM_UnitConverter.percentToPhysical(param, percent, machineType)
        local range = RHM_UnitConverter.getPhysicalRange(param, machineType)
        if range then
            local step = (range.unit == "RPM") and 10 or 0.5
            local snappedPhys = math.floor((physVal / step) + 0.5) * step
            local snappedPercent = RHM_UnitConverter.physicalToPercent(param, snappedPhys, machineType)
            spec.combineMemory:updateSetting(param, math.floor(snappedPercent + 0.5))
            return
        end
    end

    spec.combineMemory:updateSetting(param, percent)
end

function RHMCombineCalibrationGUI:mouseEvent(posX, posY, isDown, isUp, button)
    if not self.isOpen then return end

    self.mouseX = posX
    self.mouseY = posY

    local insideGUI = posX >= self.ui.x and posX <= self.ui.x + self.ui.w and
                      posY >= self.ui.y and posY <= self.ui.y + self.ui.h

    -- Handle slider dragging
    if self.draggingSlider then
        if isUp and button == Input.MOUSE_BUTTON_LEFT then
            self.draggingSlider = nil
            return true
        else
            self:updateSliderFromMouse(self.draggingSlider, posX)
            return true
        end
    end

    -- Handle tablet window dragging by header bar
    if self.isDraggingTablet then
        if isUp and button == Input.MOUSE_BUTTON_LEFT then
            self.isDraggingTablet = false
            return true
        else
            self.ui.x = math.max(0.005, math.min(1.0 - self.ui.w - 0.005, posX - self.dragOffsetTabletX))
            self.ui.y = math.max(0.005, math.min(0.98 - self.ui.h, posY - self.dragOffsetTabletY))
            self.hasCustomPosition = true
            return true
        end
    end

    local isWheel = button == Input.MOUSE_BUTTON_WHEEL_UP or button == Input.MOUSE_BUTTON_WHEEL_DOWN
    if isWheel and insideGUI then
        if isDown then
            local wheelUp = button == Input.MOUSE_BUTTON_WHEEL_UP
            local delta = wheelUp and 1 or -1
            if Input.isKeyPressed(Input.KEY_lshift) or Input.isKeyPressed(Input.KEY_rshift) then
                delta = delta * 5
            end

            local param = self.hoveredParameter
            if param and self.activeVehicle and self.activeVehicle.spec_rhm_Combine then
                local spec = self.activeVehicle.spec_rhm_Combine
                if spec.combineMemory then
                    local currentVal = spec.combineMemory.currentSettings[param] or 50
                    if param == "targetEngineLoad" then
                        local newLoad = math.max(50, math.min(100, currentVal + (delta * 5)))
                        spec.combineMemory:updateSetting(param, newLoad)
                    else
                        spec.combineMemory:updateSetting(param, math.max(0, math.min(100, currentVal + delta)))
                    end
                end
            end
        end
        return true
    end

    if isDown and button == Input.MOUSE_BUTTON_LEFT then
        -- Check slider clicks
        if self.sliders then
            for _, slider in ipairs(self.sliders) do
                if posX >= slider.x and posX <= (slider.x + slider.w) and
                   posY >= slider.y and posY <= (slider.y + slider.h) then
                    self.draggingSlider = slider
                    self:updateSliderFromMouse(slider, posX)
                    return true
                end
            end
        end

        -- Check button clicks (including close [X] button)
        for _, btn in ipairs(self.buttons) do
            if posX >= btn.x and posX <= btn.x + btn.w and posY >= btn.y and posY <= btn.y + btn.h then
                if btn.callback then
                    btn.callback()
                end
                return true
            end
        end

        -- Check dragging tablet by header (outside close [X] button)
        local headerY = self.ui.y + self.ui.h - self.ui.headerHeight
        if posY >= headerY and posY <= (self.ui.y + self.ui.h) and
           posX >= self.ui.x and posX <= (self.ui.x + self.ui.w) then
            self.isDraggingTablet = true
            self.dragOffsetTabletX = posX - self.ui.x
            self.dragOffsetTabletY = posY - self.ui.y
            return true
        end
    end

    if insideGUI then
        return true
    end

    -- While modal calibration GUI is open, consume all mouse button presses/releases
    -- so clicks outside the tablet never trigger vehicle tools, IC actions, or camera jumps.
    if isDown or isUp then
        return true
    end
end

function RHMCombineCalibrationGUI:handleWheelScroll(direction, posX, posY)
    local delta = direction
    if Input.isKeyPressed(Input.KEY_lshift) or Input.isKeyPressed(Input.KEY_rshift) then
        delta = delta * 5
    end

    if self.activeVehicle and self.activeVehicle.spec_rhm_Combine then
        local spec = self.activeVehicle.spec_rhm_Combine
        if spec.combineMemory and self.hoveredParameter then
            local currentVal = spec.combineMemory.currentSettings[self.hoveredParameter] or 50
            if self.hoveredParameter == "targetEngineLoad" then
                local newLoad = math.max(50, math.min(100, currentVal + (delta * 5)))
                spec.combineMemory:updateSetting(self.hoveredParameter, newLoad)
            else
                spec.combineMemory:updateSetting(self.hoveredParameter, math.max(0, math.min(100, currentVal + delta)))
            end
        end
    end
end

function RHMCombineCalibrationGUI:getHarvestContext(machineType)
    if self.activeVehicle and self.activeVehicle.spec_rhm_Combine then
        local rhmSpec = self.activeVehicle.spec_rhm_Combine
        return {
            machineType = machineType or rhmSpec.machineType or "grain",
            moisture = (rhmSpec.data and rhmSpec.data.moisture) or 0,
            yield = (rhmSpec.data and rhmSpec.data.yield) or 0,
            isPickup = (rhmSpec.loadCalculator and rhmSpec.loadCalculator.isPickup) or false,
            fillType = rhmSpec.lastFillType,
            fruitType = rhmSpec.lastFruitType,
        }
    end
    return { machineType = machineType or "grain" }
end

rhm_log("RHM [UI]: [OK] RHMCombineCalibrationGUI (Obsidian CEBIS In-Cab Terminal) loaded")

return RHMCombineCalibrationGUI
