-- ============================================================================
-- RHM_HarvestHistoryGUI.lua
-- Realistic Harvesting Mod - Fullscreen Native TabbedMenu Controller
-- ============================================================================
-- Technical architecture:
--   Inherits from GIANTS Engine 10 native TabbedMenu.
--   Provides a full-screen, gamepad/mouse/keyboard compatible multi-tab UI
--   with complete HUD suppression and zero rendering conflicts.
--   Dynamically adjusts available tabs: shows full 4-tab suite (including Trip Odometer)
--   when operating a combine, or 3-tab farm view (Fields, Fleet, Analytics) when on foot/in other vehicles.
-- ============================================================================

RHM_HarvestHistoryGUI = {}
local HarvestHistoryGUI_mt = Class(RHM_HarvestHistoryGUI, TabbedMenu)

function RHM_HarvestHistoryGUI.new(messageCenter, l18n, inputManager)
    local self = TabbedMenu.new(nil, HarvestHistoryGUI_mt, messageCenter, l18n, inputManager)
    self.messageCenter = messageCenter
    self.l18n = l18n
    self.inputManager = g_inputBinding
    return self
end

function RHM_HarvestHistoryGUI:onGuiSetupFinished()
    RHM_HarvestHistoryGUI:superClass().onGuiSetupFinished(self)
    self.clickBackCallback = self:makeSelfCallback(self.onButtonBack)

    if self.pageTrip then self.pageTrip:initialize() end
    if self.pageFields then self.pageFields:initialize() end
    if self.pageFleet then self.pageFleet:initialize() end
    if self.pageAnalytics then self.pageAnalytics:initialize() end

    self:setupPages()
    self:setupMenuButtonInfo()
end

function RHM_HarvestHistoryGUI:setupPages()
    local isCombinePredicate = function()
        return self:getPlayerEnteredCombine() ~= nil
    end

    local pages = {
        { self.pageTrip, 'rhmUi.icon_tab_trip', isCombinePredicate },
        { self.pageFields, 'rhmUi.icon_field' },
        { self.pageFleet, 'rhmUi.icon_tab_fleet' },
        { self.pageAnalytics, 'rhmUi.icon_tab_analytics' }
    }

    for idx, thisPage in ipairs(pages) do
        local page, sliceId, predicate = unpack(thisPage)
        if page then
            self:registerPage(page, idx, predicate)
            self:addPageTab(page, nil, nil, sliceId)
        end
    end

    self:rebuildTabList()
end

function RHM_HarvestHistoryGUI:setupMenuButtonInfo()
    local onButtonBackFunction = self.clickBackCallback
    local onResetTripFunction = self:makeSelfCallback(self.onClickResetTrip)

    self.defaultMenuButtonInfo = {
        {
            inputAction = InputAction.MENU_BACK,
            text = g_i18n:getText("button_back"),
            callback = onButtonBackFunction
        },
        {
            inputAction = InputAction.MENU_EXTRA_1,
            text = (g_i18n and g_i18n:hasText("rhm_btn_reset_trip")) and g_i18n:getText("rhm_btn_reset_trip") or "Reset Trip",
            callback = onResetTripFunction
        }
    }

    self.defaultMenuButtonInfoByActions = self.defaultMenuButtonInfoByActions or {}
    self.defaultButtonActionCallbacks = self.defaultButtonActionCallbacks or {}
    self.defaultMenuButtonInfoByActions[InputAction.MENU_BACK] = self.defaultMenuButtonInfo[1]
    self.defaultMenuButtonInfoByActions[InputAction.MENU_EXTRA_1] = self.defaultMenuButtonInfo[2]
    self.defaultButtonActionCallbacks[InputAction.MENU_BACK] = onButtonBackFunction
    self.defaultButtonActionCallbacks[InputAction.MENU_EXTRA_1] = onResetTripFunction
end

---EN: Resolves the combine vehicle currently operated by the local player (nil if on foot or in non-combine vehicle).
---    Handles SP, MP host, and MP client reliably even when GUI pauses controlledVehicle.
---UA: Визначає комбайн, яким зараз керує локальний гравець (nil якщо гравець пішки або в іншому транспорті).
---    Надійно працює в одиночній грі, на сервері та для MP-клієнтів, навіть коли GUI скидає controlledVehicle.
function RHM_HarvestHistoryGUI:getPlayerEnteredCombine()
    local function verifyCombine(veh)
        if not veh then return nil end
        local isEntered = (veh.getIsEntered and veh:getIsEntered())
            or (veh.spec_enterable and veh.spec_enterable.isEntered)
            or (veh.rootVehicle and veh.rootVehicle.getIsEntered and veh.rootVehicle:getIsEntered())
        if isEntered then
            if RHM_Api and RHM_Api.findCombine then
                local found = RHM_Api.findCombine(veh)
                if found then return found end
            end
            if veh.spec_rhm_Combine ~= nil or veh.spec_combine ~= nil or veh.spec_cottonHarvester ~= nil or veh.spec_forageHarvester ~= nil then
                local isCotton = (veh.spec_cottonHarvester ~= nil)
                    or (veh.typeName and veh.typeName:lower():find("cotton") ~= nil)
                    or (veh.xmlFile and veh.xmlFile:hasProperty("vehicle.cottonHarvester"))
                if not isCotton then
                    local isNonCombine = (veh.spec_baler ~= nil or veh.spec_pelletizer ~= nil or veh.spec_strawHarvestPelletizer ~= nil)
                        or (veh.typeName and (veh.typeName:lower():find("baler") or veh.typeName:lower():find("pellet") or veh.typeName:lower():find("premos") or
                            veh.typeName:lower():find("biobaler")))
                    if isNonCombine then
                        return nil
                    end
                end
                return veh
            end
        end
        return nil
    end

    -- 1. Check vehicle passed directly from the action event trigger
    if self.callerVehicle ~= nil then
        local found = verifyCombine(self.callerVehicle)
        if found then return found end
    end

    -- 2. Fallback: resolve vehicle currently entered by the local player (SP / MP Host / MP Client)
    local candidate = nil
    if g_localPlayer and g_localPlayer.getCurrentVehicle then
        candidate = g_localPlayer:getCurrentVehicle()
    end
    if not candidate and g_currentMission and g_currentMission.player and g_currentMission.player.getCurrentVehicle then
        candidate = g_currentMission.player:getCurrentVehicle()
    end
    if not candidate and g_realisticHarvestManager and g_realisticHarvestManager.getControlledVehicle then
        candidate = g_realisticHarvestManager:getControlledVehicle()
    end
    if not candidate and g_currentMission and g_currentMission.controlledVehicle then
        candidate = g_currentMission.controlledVehicle
    end

    if candidate ~= nil then
        local found = verifyCombine(candidate)
        if found then return found end
    end

    return nil
end

---EN: Dynamically updates bottom action buttons (hides Reset Trip button when not operating a combine or on other tabs)
---UA: Динамічно оновлює нижні кнопки (ховає Скинути рейс якщо гравець не в комбайні або на інших вкладках)
function RHM_HarvestHistoryGUI:updateMenuButtonsForPage(curPage)
    local enteredCombine = self:getPlayerEnteredCombine()
    local isTripPage = (curPage == self.pageTrip) and (enteredCombine ~= nil)

    local buttonInfo = {
        {
            inputAction = InputAction.MENU_BACK,
            text = g_i18n:getText("button_back"),
            callback = self.clickBackCallback
        }
    }

    if isTripPage then
        table.insert(buttonInfo, {
            inputAction = InputAction.MENU_EXTRA_1,
            text = (g_i18n and g_i18n:hasText("rhm_btn_reset_trip")) and g_i18n:getText("rhm_btn_reset_trip") or "Reset Trip",
            callback = self:makeSelfCallback(self.onClickResetTrip)
        })
    end

    self.defaultMenuButtonInfo = buttonInfo
    self.defaultMenuButtonInfoByActions = {}
    self.defaultButtonActionCallbacks = {}
    for _, btn in ipairs(buttonInfo) do
        self.defaultMenuButtonInfoByActions[btn.inputAction] = btn
        self.defaultButtonActionCallbacks[btn.inputAction] = btn.callback
    end

    if self.setMenuButtonInfo then
        self:setMenuButtonInfo(buttonInfo)
    elseif self.assignMenuButtonInfo then
        self:assignMenuButtonInfo(buttonInfo)
    end
end

function RHM_HarvestHistoryGUI:onOpen()
    local enteredCombine = self:getPlayerEnteredCombine()
    local hasCombine = (enteredCombine ~= nil)

    RHM_HarvestHistoryGUI:superClass().onOpen(self)
    self.isOpen = true

    -- EN: Dynamically enable or disable the Trip tab based on whether player is inside a combine
    -- UA: Динамічно вмикаємо або вимикаємо вкладку Рейсу залежно від того, чи гравець у комбайні
    if self.setPageEnabled and RHM_HarvestHistoryTrip then
        self:setPageEnabled(RHM_HarvestHistoryTrip, hasCombine)
    end
    if self.setPageTabEnabled and self.pageTrip then
        self:setPageTabEnabled(self.pageTrip, hasCombine)
    end

    if self.updatePages then
        self:updatePages()
    elseif self.rebuildTabList then
        self:rebuildTabList()
    end

    if hasCombine then
        if self.pageTrip then
            self.pageTrip.targetCombine = enteredCombine
            if self.goToPage then
                self:goToPage(self.pageTrip, true)
            end
        end
        self:updateMenuButtonsForPage(self.pageTrip)
    else
        if self.pageTrip then
            self.pageTrip.targetCombine = nil
        end
        if self.pageFields and self.goToPage then
            self:goToPage(self.pageFields, true)
        end
        self:updateMenuButtonsForPage(self.pageFields)
    end

    self:refreshCurrentPage()
end

function RHM_HarvestHistoryGUI:onPageChange(pageIndex, pageMappingIndex, element, skipTabVisualUpdate)
    local enteredCombine = self:getPlayerEnteredCombine()
    local hasCombine = (enteredCombine ~= nil)

    RHM_HarvestHistoryGUI:superClass().onPageChange(self, pageIndex, pageMappingIndex, element, skipTabVisualUpdate)
    local curPage = self:getCurrentPage()

    -- Safety redirect: prevent navigating to Trip page when not operating a combine
    if not hasCombine and curPage == self.pageTrip then
        if self.pageFields and self.goToPage then
            self:goToPage(self.pageFields, true)
            return
        end
    end

    self:updateMenuButtonsForPage(curPage)
    self:refreshCurrentPage()
end

function RHM_HarvestHistoryGUI:onClose()
    self.isOpen = false
    self.callerVehicle = nil
    if self.pageTrip then
        self.pageTrip.targetCombine = nil
    end
    RHM_HarvestHistoryGUI:superClass().onClose(self)
end

function RHM_HarvestHistoryGUI:onClickBack()
    self:exitMenu()
end

function RHM_HarvestHistoryGUI:onButtonBack()
    self:exitMenu()
end

function RHM_HarvestHistoryGUI:exitMenu()
    g_gui:showGui("")
end

function RHM_HarvestHistoryGUI:onClickResetTrip()
    local enteredCombine = self:getPlayerEnteredCombine()
    if not enteredCombine then
        return
    end
    local page = self:getCurrentPage()
    if (page == self.pageTrip or not page or (self.pageTrip and self.pageTrip.getIsVisible and self.pageTrip:getIsVisible())) and self.pageTrip and self.pageTrip.onClickResetTrip then
        self.pageTrip:onClickResetTrip()
    end
end

function RHM_HarvestHistoryGUI:getCurrentPage()
    if self.currentPage ~= nil and type(self.currentPage) == "table" then
        return self.currentPage
    end
    if self.pages and self.currentPageIndex and self.pages[self.currentPageIndex] then
        local entry = self.pages[self.currentPageIndex]
        return entry.page or entry
    end
    if self.pageTrip and self.pageTrip.getIsVisible and self.pageTrip:getIsVisible() then
        return self.pageTrip
    elseif self.pageFields and self.pageFields.getIsVisible and self.pageFields:getIsVisible() then
        return self.pageFields
    elseif self.pageFleet and self.pageFleet.getIsVisible and self.pageFleet:getIsVisible() then
        return self.pageFleet
    elseif self.pageAnalytics and self.pageAnalytics.getIsVisible and self.pageAnalytics:getIsVisible() then
        return self.pageAnalytics
    end
    return nil
end

function RHM_HarvestHistoryGUI:refreshCurrentPage()
    local currentPage = self:getCurrentPage()
    if currentPage then
        if currentPage.updateData then
            currentPage:updateData()
        elseif currentPage.updateTables then
            currentPage:updateTables()
        elseif currentPage.updateControls then
            currentPage:updateControls()
        end
    end
end
