-- EN: Non-blocking HUD notification and onboarding tutorial manager for Realistic Harvesting.
--     Renders sleek in-game notifications with dark translucent rounded background and neon accents.
--     Features cascading tutorial hints with cooldowns and persistent seen-flags across saves.
-- UA: Неблокуючий менеджер сповіщень та навчальних підказок для Realistic Harvesting.
--     Відображає стильні напівпрозорі сповіщення із закругленими кутами та неоновим акцентом.
--     Підтримує каскадні підказки з кулдауном і збереженням прапорців перегляду між сесіями.

RHM_NotificationManager = {}
RHM_NotificationManager.INSTANCE = nil

local NotificationManager_mt = Class(RHM_NotificationManager)

-- Visual constants matching the native style
local COLOR_GAME_GREEN = {0.529, 0.706, 0, 1}
local COLOR_PANEL_BG = {0, 0, 0, 0.72}
local COLOR_TEXT = {1, 1, 1, 1}
local COLOR_OK = {1, 1, 1, 0.95}

local ROUNDED_PANEL_TEXTURE_SIZE = 64
local ROUNDED_PANEL_CORNER_SIZE = 5
local ROUNDED_PANEL_UV = {
    topLeft     = {  0,  0,  5,  5 },
    top         = {  5,  0, 54,  5 },
    topRight    = { 59,  0,  5,  5 },
    left        = {  0,  5,  5, 54 },
    center      = {  5,  5, 54, 54 },
    right       = { 59,  5,  5, 54 },
    bottomLeft  = {  0, 59,  5,  5 },
    bottom      = {  5, 59, 54,  5 },
    bottomRight = { 59, 59,  5,  5 }
}

function RHM_NotificationManager.new(modDirectory)
    local self = setmetatable({}, NotificationManager_mt)

    self.modDirectory = modDirectory or g_currentModDirectory
    self.activeNotification = nil
    self.cooldownTimer = 5000 -- 5s initial silence after loading game
    self.cooldownDurationMs = 45000 -- 45s between tutorial hints to prevent spam
    self.seenTutorials = RHM_NotificationManager.seenTutorials or {}
    RHM_NotificationManager.seenTutorials = self.seenTutorials

    self.cumulativeTier1HarvestTime = 0
    self.harvestActiveRunTime = 0

    self.panelBackgroundRounded = Utils.getFilename("textures/panelRounded.dds", self.modDirectory)
    self.quadOverlay = nil
    self.dividerOverlay = nil
    self.notificationCloseGlyph = nil
    self.notificationCloseGlyphInputMode = nil

    self.mouseButtonDownLast = false
    self.gamepadButtonDownLast = false

    return self
end

function RHM_NotificationManager:load()
    if not self.quadOverlay then
        self.quadOverlay = Overlay.new(self.panelBackgroundRounded, 0, 0, 1, 1)
    end
    if not self.dividerOverlay then
        self.dividerOverlay = Overlay.new("dataS/menu/base/graph_pixel.dds", 0, 0, 1, 1)
    end

    addConsoleCommand("rhm_hint", "Show a tutorial hint manually [welcome|overload|loss|moisture|headland|upgrade]", "consoleCommandShowHint", self)
    addConsoleCommand("rhm_reset_hints", "Reset seen tutorial hints so they appear again", "consoleCommandResetHints", self)
end

function RHM_NotificationManager:delete()
    removeConsoleCommand("rhm_hint")
    removeConsoleCommand("rhm_reset_hints")

    if self.quadOverlay then
        self.quadOverlay:delete()
        self.quadOverlay = nil
    end
    if self.dividerOverlay then
        self.dividerOverlay:delete()
        self.dividerOverlay = nil
    end
    if self.notificationCloseGlyph then
        self.notificationCloseGlyph:delete()
        self.notificationCloseGlyph = nil
    end

    self.activeNotification = nil
end

function RHM_NotificationManager:scalePixelToScreenWidth(pixel)
    local screenW = g_screenWidth or 1920
    return (pixel or 0) / screenW
end

function RHM_NotificationManager:scalePixelToScreenHeight(pixel)
    local screenH = g_screenHeight or 1080
    return (pixel or 0) / screenH
end

function RHM_NotificationManager:snapScreenRect(x, y, width, height)
    local screenW = g_screenWidth or 1920
    local screenH = g_screenHeight or 1080
    local snappedX = math.floor(x * screenW + 0.5) / screenW
    local snappedY = math.floor(y * screenH + 0.5) / screenH
    local snappedWidth = math.max(math.floor(width * screenW + 0.5) / screenW, 1 / screenW)
    local snappedHeight = math.max(math.floor(height * screenH + 0.5) / screenH, 1 / screenH)
    return snappedX, snappedY, snappedWidth, snappedHeight
end

function RHM_NotificationManager:consoleCommandShowHint(name)
    name = tostring(name or "welcome"):upper():gsub("%s+", "")
    if name == "" or name == "WELCOME" or name == "1" then
        local title = g_i18n:hasText("rhm_tut_welcome_title") and g_i18n:getText("rhm_tut_welcome_title") or "REALISTIC HARVESTING"
        local msg = g_i18n:hasText("rhm_tut_welcome_msg") and g_i18n:getText("rhm_tut_welcome_msg") or "Harvesting speed is now dynamically controlled by crop density, engine power, and moisture. Press Shift+K to open the combine calibration terminal."
        self:showNotification(title, msg, 0, false)
        return "Displayed hint: WELCOME"
    elseif name == "OVERLOAD" or name == "2" then
        local title = g_i18n:hasText("rhm_tut_overload_title") and g_i18n:getText("rhm_tut_overload_title") or "ENGINE OVERLOAD"
        local msg = g_i18n:hasText("rhm_tut_overload_msg") and g_i18n:getText("rhm_tut_overload_msg") or "The combine is operating at peak capacity! The hydrostatic drive automatically slows down to protect the drum. Raise the cutter or reduce width to relieve pressure."
        self:showNotification(title, msg, 0, false)
        return "Displayed hint: OVERLOAD"
    elseif name == "LOSS" or name == "3" then
        local title = g_i18n:hasText("rhm_tut_loss_title") and g_i18n:getText("rhm_tut_loss_title") or "CROP LOSS"
        local msg = g_i18n:hasText("rhm_tut_loss_msg") and g_i18n:getText("rhm_tut_loss_msg") or "Excessive crop loss detected! Rotor speed, fan airflow, or sieve openings are misaligned for this crop. Press Shift+K to load an optimal factory preset."
        self:showNotification(title, msg, 0, false)
        return "Displayed hint: LOSS"
    elseif name == "MOISTURE" or name == "4" then
        local title = g_i18n:hasText("rhm_tut_moisture_title") and g_i18n:getText("rhm_tut_moisture_title") or "HIGH MOISTURE"
        local msg = g_i18n:hasText("rhm_tut_moisture_msg") and g_i18n:getText("rhm_tut_moisture_msg") or "Damp straw and grain require significantly more horsepower to thresh, reducing your harvesting speed and increasing loss risk. Harvest during dry conditions for optimal efficiency."
        self:showNotification(title, msg, 0, false)
        return "Displayed hint: MOISTURE"
    elseif name == "HEADLAND" or name == "5" then
        local title = g_i18n:hasText("rhm_tut_headland_title") and g_i18n:getText("rhm_tut_headland_title") or "WORKING SPEED MEMORY"
        local msg = g_i18n:hasText("rhm_tut_headland_msg") and g_i18n:getText("rhm_tut_headland_msg") or "The combine automatically remembers your cruising harvest speed across field turns. When lowering the header for the next row, it will smoothly accelerate back to this speed."
        self:showNotification(title, msg, 0, false)
        return "Displayed hint: HEADLAND"
    elseif name == "UPGRADE" or name == "UPGRADE_TIERS" or name == "6" then
        local title = g_i18n:hasText("rhm_tut_upgrade_title") and g_i18n:getText("rhm_tut_upgrade_title") or "UPGRADE PACKAGES"
        local msg = g_i18n:hasText("rhm_tut_upgrade_msg") and g_i18n:getText("rhm_tut_upgrade_msg") or "Harvester upgrade packages are available at the vehicle shop: Tier 2 (Sensors & Profiles), Tier 3 (Telemetry & Loss Monitor), and Tier 4 (Opti-Harvest AI autopilot)."
        self:showNotification(title, msg, 0, false)
        return "Displayed hint: UPGRADE"
    else
        return "Unknown hint name. Available: welcome, overload, loss, moisture, headland, upgrade (or 1..6)"
    end
end

function RHM_NotificationManager:consoleCommandResetHints()
    self.seenTutorials = {}
    RHM_NotificationManager.seenTutorials = self.seenTutorials
    self.cooldownTimer = 0
    return "All tutorial hints have been reset and will trigger naturally again."
end

---EN: Displays a notification modal
---UA: Відображає модальне вікно сповіщення
function RHM_NotificationManager:showNotification(title, text, durationMs, isTutorial, tutorialKey)
    local rawTitle = tostring(title or ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
    local rawText = tostring(text or ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")

    if rawText == "" then
        self:dismissNotification()
        return
    end

    local formattedTitle = nil
    if rawTitle ~= "" then
        if utf8ToUpper ~= nil then
            formattedTitle = utf8ToUpper(rawTitle)
        else
            formattedTitle = string.upper(rawTitle)
        end
    end

    local parsedDuration = tonumber(durationMs) or 0
    local isPersistent = parsedDuration <= 0
    local displayDuration = isPersistent and 60000 or math.max(parsedDuration, 4000)

    self.activeNotification = {
        title = formattedTitle,
        text = rawText,
        durationMs = displayDuration,
        isPersistent = isPersistent,
        timer = 0,
        isTutorial = isTutorial or false,
        tutorialKey = tutorialKey
    }

    if tutorialKey then
        self.seenTutorials[tutorialKey] = true
        if RHM_NotificationManager.seenTutorials then
            RHM_NotificationManager.seenTutorials[tutorialKey] = true
        end
        self.cooldownTimer = self.cooldownDurationMs
    end
end

function RHM_NotificationManager:dismissNotification()
    self.activeNotification = nil
end

function RHM_NotificationManager:closeActiveNotification()
    self:dismissNotification()
end

---EN: Simple word-wrapper matching the native HUD line wrapping
function RHM_NotificationManager:wrapText(text, maxWidth, textSize)
    local words = {}
    for word in tostring(text or ""):gmatch("%S+") do
        table.insert(words, word)
    end

    local lines = {}
    local currentLine = ""

    for _, word in ipairs(words) do
        local candidate = currentLine == "" and word or (currentLine .. " " .. word)
        if currentLine == "" or getTextWidth(textSize, candidate) <= maxWidth then
            currentLine = candidate
        else
            table.insert(lines, currentLine)
            currentLine = word
        end
    end

    if currentLine ~= "" then
        table.insert(lines, currentLine)
    end

    return lines
end

---EN: 9-slice quad renderer for rounded background panel
function RHM_NotificationManager:renderPanelQuad(texturePath, x, y, width, height, color, uvs)
    if width <= 0 or height <= 0 then
        return
    end

    local overlay = self.quadOverlay
    if not overlay then
        self.quadOverlay = Overlay.new(self.panelBackgroundRounded, 0, 0, 1, 1)
        overlay = self.quadOverlay
    end

    overlay:setPosition(x, y)
    overlay:setDimension(width, height)
    if uvs ~= nil and GuiUtils ~= nil and GuiUtils.getUVs ~= nil then
        overlay:setUVs(GuiUtils.getUVs(uvs, {ROUNDED_PANEL_TEXTURE_SIZE, ROUNDED_PANEL_TEXTURE_SIZE}))
    end
    overlay:setColor(color[1], color[2], color[3], color[4] or 1)
    overlay:render()
end

---EN: Draws the 9-slice background with rounded corners
function RHM_NotificationManager:drawPanelBackground(x, y, width, height, color)
    local panelColor = color or COLOR_PANEL_BG
    local panelX, panelY, panelWidth, panelHeight = self:snapScreenRect(x, y, width, height)

    local cornerWidth = math.min(
        math.floor(self:scalePixelToScreenWidth(ROUNDED_PANEL_CORNER_SIZE) * (g_screenWidth or 1920) + 0.5) / (g_screenWidth or 1920),
        panelWidth * 0.5
    )
    local cornerHeight = math.min(
        math.floor(self:scalePixelToScreenHeight(ROUNDED_PANEL_CORNER_SIZE) * (g_screenHeight or 1080) + 0.5) / (g_screenHeight or 1080),
        panelHeight * 0.5
    )

    local leftX = panelX
    local centerX = panelX + cornerWidth
    local rightX = panelX + panelWidth - cornerWidth
    local bottomY = panelY
    local centerY = panelY + cornerHeight
    local topY = panelY + panelHeight - cornerHeight
    local centerWidth = math.max(rightX - centerX, 0)
    local centerHeight = math.max(topY - centerY, 0)
    local uv = ROUNDED_PANEL_UV

    self:renderPanelQuad(self.panelBackgroundRounded, leftX, bottomY, cornerWidth, cornerHeight, panelColor, uv.bottomLeft)
    self:renderPanelQuad(self.panelBackgroundRounded, centerX, bottomY, centerWidth, cornerHeight, panelColor, uv.bottom)
    self:renderPanelQuad(self.panelBackgroundRounded, rightX, bottomY, cornerWidth, cornerHeight, panelColor, uv.bottomRight)

    self:renderPanelQuad(self.panelBackgroundRounded, leftX, centerY, cornerWidth, centerHeight, panelColor, uv.left)
    self:renderPanelQuad(self.panelBackgroundRounded, centerX, centerY, centerWidth, centerHeight, panelColor, uv.center)
    self:renderPanelQuad(self.panelBackgroundRounded, rightX, centerY, cornerWidth, centerHeight, panelColor, uv.right)

    self:renderPanelQuad(self.panelBackgroundRounded, leftX, topY, cornerWidth, cornerHeight, panelColor, uv.topLeft)
    self:renderPanelQuad(self.panelBackgroundRounded, centerX, topY, centerWidth, cornerHeight, panelColor, uv.top)
    self:renderPanelQuad(self.panelBackgroundRounded, rightX, topY, cornerWidth, cornerHeight, panelColor, uv.topRight)
end

---EN: Draws a thin divider line
function RHM_NotificationManager:drawNotificationDivider(x, y, width, height, color)
    local snappedX, snappedY, snappedWidth, snappedHeight = self:snapScreenRect(x, y, width, height)

    local overlay = self.dividerOverlay
    if not overlay then
        self.dividerOverlay = Overlay.new("dataS/menu/base/graph_pixel.dds", 0, 0, 1, 1)
        overlay = self.dividerOverlay
    end

    overlay:setPosition(snappedX, snappedY)
    overlay:setDimension(snappedWidth, snappedHeight)
    overlay:setColor(unpack(color))
    overlay:render()
end

---EN: Gets or creates the official close glyph element
function RHM_NotificationManager:getNotificationCloseGlyph(glyphWidth, glyphHeight)
    if g_inputDisplayManager == nil or InputGlyphElement == nil or InputAction == nil then
        return nil
    end

    local closeAction = InputAction.RHM_CLOSE_NOTIFICATION or InputAction.MENU_ACCEPT or InputAction.ACTIVATE_OBJECT

    if self.notificationCloseGlyph == nil then
        self.notificationCloseGlyph = InputGlyphElement.new(g_inputDisplayManager, glyphWidth, glyphHeight)
        self.notificationCloseGlyph:setKeyboardGlyphColor(COLOR_GAME_GREEN, {0, 0, 0, 0.8})
        self.notificationCloseGlyph:setButtonGlyphColor(COLOR_GAME_GREEN)
    elseif self.notificationCloseGlyph.baseWidth ~= glyphWidth or self.notificationCloseGlyph.baseHeight ~= glyphHeight then
        self.notificationCloseGlyph:delete()
        self.notificationCloseGlyph = InputGlyphElement.new(g_inputDisplayManager, glyphWidth, glyphHeight)
        self.notificationCloseGlyph:setKeyboardGlyphColor(COLOR_GAME_GREEN, {0, 0, 0, 0.8})
        self.notificationCloseGlyph:setButtonGlyphColor(COLOR_GAME_GREEN)
        self.notificationCloseGlyphInputMode = nil
    end

    local inputMode = g_inputBinding ~= nil and g_inputBinding:getInputHelpMode() or nil
    if self.notificationCloseGlyphInputMode ~= inputMode then
        self.notificationCloseGlyph:setAction(closeAction, nil, nil, true)
        self.notificationCloseGlyphInputMode = inputMode
    end

    return self.notificationCloseGlyph
end

function RHM_NotificationManager:getNotificationGamepadState()
    if getNumOfGamepads == nil or getInputButton == nil then
        return false
    end

    local numGamepads = getNumOfGamepads()
    for gamepadId = 0, numGamepads - 1 do
        if getInputButton(1, gamepadId) > 0 then
            return true
        end
    end
    return false
end

function RHM_NotificationManager:updateInput()
    if not self.activeNotification then return end

    local isMouseDown = Input.isMouseButtonPressed ~= nil and (Input.isMouseButtonPressed(Input.MOUSE_BUTTON_LEFT) or Input.isMouseButtonPressed(Input.MOUSE_BUTTON_RIGHT))
    local isGamepadDown = self:getNotificationGamepadState()

    if g_gui ~= nil and g_gui:getIsGuiVisible() then
        self.mouseButtonDownLast = isMouseDown
        self.gamepadButtonDownLast = isGamepadDown
        return
    end

    if isMouseDown and not self.mouseButtonDownLast then
        self:dismissNotification()
        self.mouseButtonDownLast = true
        self.gamepadButtonDownLast = isGamepadDown
        return
    end

    if isGamepadDown and not self.gamepadButtonDownLast then
        self:dismissNotification()
        self.mouseButtonDownLast = isMouseDown
        self.gamepadButtonDownLast = true
        return
    end

    self.mouseButtonDownLast = isMouseDown
    self.gamepadButtonDownLast = isGamepadDown
end

---EN: Main update tick for managing timer and cascading onboarding tutorials
function RHM_NotificationManager:update(dt, combineVehicle)
    -- Poll mouse and gamepad dismiss
    self:updateInput()

    -- 1. Advance active notification timer
    if self.activeNotification then
        self.activeNotification.timer = self.activeNotification.timer + dt
        if not self.activeNotification.isPersistent and self.activeNotification.timer >= self.activeNotification.durationMs then
            self:dismissNotification()
        end
        return
    end

    -- 2. Decrement cooldown between tutorial hints
    if self.cooldownTimer > 0 then
        self.cooldownTimer = self.cooldownTimer - dt
        return
    end

    -- 3. Only evaluate triggers if player is inside an active combine
    if not combineVehicle or not combineVehicle.getIsEntered or not combineVehicle:getIsEntered() then
        return
    end

    local spec = combineVehicle.spec_rhm_Combine
    if not spec or not spec.isRhmCombine or not spec.data then
        return
    end

    local data = spec.data
    local isCutterActive = data.cutterTurnedOn and data.cutterLowered
    local isHarvesting = isCutterActive and (data.lastSpeed or 0) > 0.5
    local load = data.loadPercentage or 0
    local cropLoss = data.cropLoss or 0
    local moisture = data.moisture or 0

    if isHarvesting then
        self.harvestActiveRunTime = self.harvestActiveRunTime + dt
        if spec.packageLevel == 1 then
            self.cumulativeTier1HarvestTime = self.cumulativeTier1HarvestTime + dt
        end
    else
        self.harvestActiveRunTime = math.max(0, self.harvestActiveRunTime - dt * 0.5)
    end

    -- =========================================================================
    -- CASCADING TUTORIAL TRIGGERS (Priority order, max 1 trigger per check)
    -- =========================================================================

    -- TRIGGER 1: First Harvest / Welcome
    if not self.seenTutorials["WELCOME"] and isCutterActive then
        local title = g_i18n:hasText("rhm_tut_welcome_title") and g_i18n:getText("rhm_tut_welcome_title") or "REALISTIC HARVESTING"
        local msg = g_i18n:hasText("rhm_tut_welcome_msg") and g_i18n:getText("rhm_tut_welcome_msg") or "Harvesting speed is now dynamically controlled by crop density, engine power, and moisture. Press Shift+K to open the combine calibration terminal."
        self:showNotification(title, msg, 0, true, "WELCOME")
        return
    end

    -- TRIGGER 2: Engine Overload (> 110%)
    if not self.seenTutorials["OVERLOAD"] and isHarvesting and load >= 110 then
        local title = g_i18n:hasText("rhm_tut_overload_title") and g_i18n:getText("rhm_tut_overload_title") or "ENGINE OVERLOAD"
        local msg = g_i18n:hasText("rhm_tut_overload_msg") and g_i18n:getText("rhm_tut_overload_msg") or "The combine is operating at peak capacity! The hydrostatic drive automatically slows down to protect the drum. In extreme overloads, the threshing unit may clog."
        self:showNotification(title, msg, 0, true, "OVERLOAD")
        return
    end

    -- TRIGGER 3: Excessive Crop Loss (> 2%)
    if not self.seenTutorials["LOSS"] and isHarvesting and cropLoss > 2.0 then
        local title = g_i18n:hasText("rhm_tut_loss_title") and g_i18n:getText("rhm_tut_loss_title") or "CROP LOSS"
        local msg = g_i18n:hasText("rhm_tut_loss_msg") and g_i18n:getText("rhm_tut_loss_msg") or "Excessive crop loss detected! Rotor speed, fan airflow, or sieve openings are misaligned for this crop. Press Shift+K to load an optimal factory preset."
        self:showNotification(title, msg, 0, true, "LOSS")
        return
    end

    -- TRIGGER 4: High Moisture (> 16% or Rain)
    local isRaining = g_currentMission and g_currentMission.environment and g_currentMission.environment.weather and g_currentMission.environment.weather:getIsRaining()
    if not self.seenTutorials["MOISTURE"] and isHarvesting and (moisture > 16.0 or isRaining) then
        local title = g_i18n:hasText("rhm_tut_moisture_title") and g_i18n:getText("rhm_tut_moisture_title") or "HIGH MOISTURE"
        local msg = g_i18n:hasText("rhm_tut_moisture_msg") and g_i18n:getText("rhm_tut_moisture_msg") or "Damp straw and grain require significantly more horsepower to thresh, reducing your harvesting speed and increasing loss risk. Harvest during dry conditions for optimal efficiency."
        self:showNotification(title, msg, 0, true, "MOISTURE")
        return
    end

    -- TRIGGER 5: Headland Turn Speed Memory (cutter raised after >= 15s harvest)
    if not self.seenTutorials["HEADLAND"] and not isCutterActive and self.harvestActiveRunTime >= 15000 then
        local title = g_i18n:hasText("rhm_tut_headland_title") and g_i18n:getText("rhm_tut_headland_title") or "WORKING SPEED MEMORY"
        local msg = g_i18n:hasText("rhm_tut_headland_msg") and g_i18n:getText("rhm_tut_headland_msg") or "The combine automatically remembers your cruising harvest speed across field turns. When lowering the header for the next row, it will smoothly accelerate back to this speed."
        self:showNotification(title, msg, 0, true, "HEADLAND")
        return
    end

    -- TRIGGER 6: Upgrade Tiers (10 cumulative minutes on Tier 1 combine)
    if not self.seenTutorials["UPGRADE_TIERS"] and spec.packageLevel == 1 and self.cumulativeTier1HarvestTime >= 600000 then
        local title = g_i18n:hasText("rhm_tut_upgrade_title") and g_i18n:getText("rhm_tut_upgrade_title") or "UPGRADE PACKAGES"
        local msg = g_i18n:hasText("rhm_tut_upgrade_msg") and g_i18n:getText("rhm_tut_upgrade_msg") or "Harvester upgrade packages are available at the vehicle shop: Tier 2 (Sensors & Profiles), Tier 3 (Telemetry & Loss Monitor), and Tier 4 (Opti-Harvest AI autopilot)."
        self:showNotification(title, msg, 0, true, "UPGRADE_TIERS")
        return
    end
end

---EN: Draws the notification panel on screen
---UA: Малює панель сповіщень на екрані
function RHM_NotificationManager:draw()
    local notification = self.activeNotification
    if not notification or notification.text == nil then return end

    if not self.quadOverlay or not self.dividerOverlay then
        self:load()
    end

    -- Layout proportions
    local panelWidth = math.max(0.22, self:scalePixelToScreenWidth(420))
    local panelX = (1.0 - panelWidth) * 0.5
    local baseAnchorY = 0.14 -- Sitting comfortably in lower screen region

    local padding = self:scalePixelToScreenWidth(15)
    local fullTextWidth = panelWidth - (padding * 2)

    local titleTextSize = self:scalePixelToScreenHeight(18)
    local titleLineHeight = self:scalePixelToScreenHeight(22)
    local textSize = self:scalePixelToScreenHeight(14)
    local lineHeight = self:scalePixelToScreenHeight(20)

    local titleSpacing = self:scalePixelToScreenHeight(7)
    local titleDividerHeight = math.max(self:scalePixelToScreenHeight(1.5), 1 / (g_screenHeight or 1080))
    local titleTextExtraSpacing = self:scalePixelToScreenHeight(8)
    local dividerSpacing = self:scalePixelToScreenHeight(4)
    local bottomDividerTextSpacing = self:scalePixelToScreenHeight(4)

    local titleLines = {}
    if notification.title ~= nil and notification.title ~= "" then
        titleLines = self:wrapText(notification.title, fullTextWidth, titleTextSize)
    end
    local hasTitle = #titleLines > 0

    local lines = self:wrapText(notification.text, fullTextWidth, textSize)
    local baseHeight = padding * 2 + lineHeight

    local closeGlyphSize = 18
    local closeGlyphWidth = self:scalePixelToScreenWidth(closeGlyphSize)
    local closeGlyphHeight = self:scalePixelToScreenHeight(closeGlyphSize)

    local topSectionHeight = hasTitle and (padding + (#titleLines * titleLineHeight) + dividerSpacing + titleDividerHeight) or 0
    local bottomSectionHeight = hasTitle and (topSectionHeight + dividerSpacing + bottomDividerTextSpacing) or 0
    local dynamicHeight = hasTitle
        and (padding + (#titleLines * titleLineHeight) + titleSpacing + titleTextExtraSpacing + (#lines * lineHeight) + bottomSectionHeight)
        or (padding * 2 + (#lines * lineHeight))

    local anchorCenterY = baseAnchorY + baseHeight * 0.5
    local panelY = anchorCenterY - dynamicHeight * 0.5

    -- Record bounds for click detection
    notification.bounds = {
        x1 = panelX,
        y1 = panelY,
        x2 = panelX + panelWidth,
        y2 = panelY + dynamicHeight
    }

    -- 1. Draw 9-slice dark translucent background panel with rounded corners
    self:drawPanelBackground(panelX, panelY, panelWidth, dynamicHeight, COLOR_PANEL_BG)

    local centerX = panelX + panelWidth * 0.5
    local currentY = panelY + dynamicHeight - padding

    -- 2. Render UPPERCASE Bold Title in neon green
    if hasTitle then
        setTextAlignment(RenderText.ALIGN_CENTER)
        setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
        setTextBold(true)
        setTextColor(unpack(COLOR_GAME_GREEN))

        for _, line in ipairs(titleLines) do
            renderText(centerX, currentY, titleTextSize, line)
            currentY = currentY - titleLineHeight
        end

        local dividerWidth = panelWidth - padding * 2
        local dividerY = currentY - dividerSpacing - titleDividerHeight * 0.5
        self:drawNotificationDivider(panelX + padding, dividerY, dividerWidth, titleDividerHeight, COLOR_GAME_GREEN)

        currentY = currentY - titleSpacing - titleTextExtraSpacing
    end

    -- 3. Render Centered Body Text in pure crisp white
    setTextAlignment(RenderText.ALIGN_CENTER)
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_TOP)
    setTextBold(false)
    setTextColor(COLOR_TEXT[1], COLOR_TEXT[2], COLOR_TEXT[3], COLOR_TEXT[4])

    for _, line in ipairs(lines) do
        renderText(centerX, currentY, textSize, line)
        currentY = currentY - lineHeight
    end

    -- 4. Render Bottom Divider and Close Prompt
    if hasTitle then
        local dividerWidth = panelWidth - padding * 2
        local bottomDividerY = currentY - dividerSpacing - bottomDividerTextSpacing - titleDividerHeight * 0.5
        self:drawNotificationDivider(panelX + padding, bottomDividerY, dividerWidth, titleDividerHeight, COLOR_GAME_GREEN)

        -- 5. Footer: Mouse Icon Glyph + "OK"
        local glyph = self:getNotificationCloseGlyph(closeGlyphWidth, closeGlyphHeight)
        local okText = "OK"
        local okTextSize = textSize
        local textSpacing = self:scalePixelToScreenWidth(6)
        local okTextWidth = getTextWidth(okTextSize, okText)

        if glyph ~= nil then
            local glyphWidth = glyph:getGlyphWidth()
            local totalFooterW = glyphWidth + textSpacing + okTextWidth
            local glyphX = centerX - totalFooterW * 0.5
            local glyphY = panelY + math.max((topSectionHeight - titleDividerHeight - closeGlyphHeight) * 0.5, 0)
            glyph:setPosition(glyphX, glyphY)
            glyph:draw()

            setTextAlignment(RenderText.ALIGN_LEFT)
            setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
            setTextBold(true)
            setTextColor(COLOR_OK[1], COLOR_OK[2], COLOR_OK[3], COLOR_OK[4])
            renderText(glyphX + glyphWidth + textSpacing - self:scalePixelToScreenWidth(4), glyphY + closeGlyphHeight * 0.5 + self:scalePixelToScreenHeight(2), okTextSize, okText)
        else
            -- Fallback vector mouse glyph
            local mWidth = self:scalePixelToScreenWidth(14)
            local mHeight = self:scalePixelToScreenHeight(18)
            local totalFooterW = mWidth + textSpacing + okTextWidth
            local mX = centerX - totalFooterW * 0.5
            local mY = panelY + math.max((topSectionHeight - titleDividerHeight - mHeight) * 0.5, 0)

            -- Mouse outline
            self:drawNotificationDivider(mX, mY, mWidth, mHeight, COLOR_GAME_GREEN)
            -- Inner fill
            local bw = 1 / (g_screenWidth or 1920)
            local bh = 1 / (g_screenHeight or 1080)
            self:drawNotificationDivider(mX + bw, mY + bh, mWidth - bw*2, mHeight - bh*2, {0.05, 0.05, 0.05, 1})
            -- Highlight left button
            self:drawNotificationDivider(mX + bw, mY + mHeight*0.5, mWidth*0.5 - bw, mHeight*0.5 - bh, COLOR_GAME_GREEN)

            setTextAlignment(RenderText.ALIGN_LEFT)
            setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_MIDDLE)
            setTextBold(true)
            setTextColor(COLOR_OK[1], COLOR_OK[2], COLOR_OK[3], COLOR_OK[4])
            renderText(mX + mWidth + textSpacing, mY + mHeight * 0.5, okTextSize, okText)
        end
    end

    -- Reset engine render states
    setTextBold(false)
    setTextColor(1, 1, 1, 1)
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextVerticalAlignment(RenderText.VERTICAL_ALIGN_BOTTOM)
end

function RHM_NotificationManager:mouseEvent(posX, posY, isDown, isUp, button)
    if not self.activeNotification then return false end

    -- Close on any left or right mouse click anywhere on the screen
    if (isDown or isUp) and (button == Input.MOUSE_BUTTON_LEFT or button == Input.MOUSE_BUTTON_RIGHT) then
        self:dismissNotification()
        return true
    end

    return false
end

function RHM_NotificationManager:keyEvent(unicode, sym, modifier, isDown)
    if not self.activeNotification then return false end

    if isDown and (sym == Input.KEY_return or sym == Input.KEY_space or sym == Input.KEY_escape) then
        self:dismissNotification()
        return true
    end

    return false
end
