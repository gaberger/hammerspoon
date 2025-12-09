-- Hammerspoon Config: Multi-Layout Window Manager for 48" Monitor
-- Ctrl+Alt+G = Show zones, Ctrl+Alt+1/2/3 = Switch layouts (auto-saved per Space)
-- Layouts automatically restore when switching between macOS Spaces

local gap = 10
local showBanner = true  -- Toggle with Ctrl+Alt+B

-- ============================================
-- FLOATING APPS (never snap to zones)
-- ============================================
local floatingApps = {
    "Finder",
    "System Preferences",
    "System Settings",
    "Calculator",
    "Preview",
    "1Password",
    "Raycast",
    "Alfred",
    "Spotlight",
    -- Add more apps here
}

local function isFloatingApp(win)
    if not win then return false end
    local app = win:application()
    if not app then return false end
    local appName = app:name()
    for _, name in ipairs(floatingApps) do
        if appName == name then
            return true
        end
    end
    return false
end

-- Toggle floating status for current app (Ctrl+Alt+F)
hs.hotkey.bind({"ctrl", "alt"}, "F", function()
    local win = hs.window.focusedWindow()
    if not win then return end
    local app = win:application()
    if not app then return end
    local appName = app:name()
    
    -- Check if already floating
    for i, name in ipairs(floatingApps) do
        if name == appName then
            table.remove(floatingApps, i)
            hs.alert.show(appName .. ": snapping ON", 1)
            return
        end
    end
    
    -- Add to floating list
    table.insert(floatingApps, appName)
    hs.alert.show(appName .. ": floating", 1)
end)

-- ============================================
-- LAYOUT DEFINITIONS
-- ============================================
-- Each zone: { x = left%, w = width%, y = top%, h = height%, label = "name" }
-- Percentages are 0-1 (e.g., 0.6 = 60%)

local layouts = {
    {
        name = "Default",
        zones = {
            { x = 0,    w = 0.25, y = 0,   h = 0.5, label = "1 Top" },
            { x = 0,    w = 0.25, y = 0.5, h = 0.5, label = "1 Bottom" },
            { x = 0.25, w = 0.25, y = 0,   h = 1,   label = "2" },
            { x = 0.5,  w = 0.25, y = 0,   h = 1,   label = "3" },
            { x = 0.75, w = 0.25, y = 0,   h = 0.5, label = "4 Top" },
            { x = 0.75, w = 0.25, y = 0.5, h = 0.5, label = "4 Bottom" }
        }
    },
    {
        name = "Coding",
        zones = {
            { x = 0,   w = 0.6,  y = 0,   h = 1,   label = "Editor" },
            { x = 0.6, w = 0.4,  y = 0,   h = 0.5, label = "Terminal" },
            { x = 0.6, w = 0.4,  y = 0.5, h = 0.5, label = "Browser" }
        }
    },
    {
        name = "Demo",
        zones = {
            { x = 0,    w = 0.25, y = 0, h = 1, label = "Notes 1" },
            { x = 0.25, w = 0.25, y = 0, h = 1, label = "Notes 2" },
            { x = 0.5,  w = 0.5,  y = 0, h = 1, label = "Main" }
        }
    }
}

local currentLayoutIndex = 1
local currentLayout = layouts[currentLayoutIndex]

-- ============================================
-- SPACE-TO-LAYOUT MAPPING
-- ============================================
-- Maps Space IDs to layout indices. Persists across reloads via hs.settings.

local spaceLayouts = hs.settings.get("windowManager.spaceLayouts") or {}
local autoSwitchEnabled = true

-- Get current space ID
local function getCurrentSpaceId()
    local screen = hs.screen.mainScreen()
    if not screen then return nil end
    local spaces = hs.spaces.spacesForScreen(screen)
    if not spaces then return nil end
    local focusedSpace = hs.spaces.focusedSpace()
    return focusedSpace
end

-- Grid hotkey (Ctrl+Alt+G) is defined later after zone functions are declared

-- ============================================
-- LAYOUT BANNER (persistent indicator)
-- ============================================

local layoutBanner = nil

local function updateBanner()
    if layoutBanner then
        layoutBanner:delete()
        layoutBanner = nil
    end
    
    if not showBanner then return end
    
    local screen = hs.screen.mainScreen()
    local screenFrame = screen:frame()
    
    -- Banner size and position (top-left corner)
    local bannerW = 140
    local bannerH = 32
    local bannerX = screenFrame.x + 12
    local bannerY = screenFrame.y + 12
    
    layoutBanner = hs.canvas.new({ x = bannerX, y = bannerY, w = bannerW, h = bannerH })
    
    -- Background pill
    layoutBanner:appendElements({
        type = "rectangle",
        frame = { x = 0, y = 0, w = bannerW, h = bannerH },
        fillColor = { red = 0.1, green = 0.1, blue = 0.15, alpha = 0.85 },
        strokeColor = { red = 0.3, green = 0.4, blue = 0.5, alpha = 0.6 },
        strokeWidth = 1,
        roundedRectRadii = { xRadius = 8, yRadius = 8 }
    })
    
    -- Layout icon
    layoutBanner:appendElements({
        type = "text",
        frame = { x = 10, y = 4, w = 24, h = 24 },
        text = "⬡",
        textSize = 18,
        textColor = { red = 0.4, green = 0.7, blue = 0.9, alpha = 0.9 },
        textAlignment = "center"
    })
    
    -- Layout name
    layoutBanner:appendElements({
        type = "text",
        frame = { x = 34, y = 6, w = bannerW - 44, h = 20 },
        text = currentLayout.name,
        textSize = 14,
        textColor = { red = 0.9, green = 0.9, blue = 0.95, alpha = 0.95 },
        textAlignment = "left",
        textFont = "SF Pro Text"
    })
    
    layoutBanner:level(hs.canvas.windowLevels.floating)
    layoutBanner:clickActivating(false)
    layoutBanner:canvasMouseEvents(false)
    layoutBanner:show()
end

-- Toggle banner with Ctrl+Alt+B
hs.hotkey.bind({"ctrl", "alt"}, "B", function()
    showBanner = not showBanner
    updateBanner()
    hs.alert.show("Layout banner: " .. (showBanner and "ON" or "OFF"), 0.8)
end)

-- ============================================
-- HELPER FUNCTIONS
-- ============================================

local function getScreenFrame()
    local screen = hs.screen.mainScreen()
    local frame = screen:frame()
    return {
        x = frame.x + gap,
        y = frame.y + gap,
        w = frame.w - (gap * 2),
        h = frame.h - (gap * 2)
    }
end

-- Get zone frame in screen coordinates
local function getZoneFrame(zone, sf)
    local availW = sf.w
    local availH = sf.h
    
    return {
        x = sf.x + (zone.x * availW) + (zone.x > 0 and gap or 0),
        y = sf.y + (zone.y * availH) + (zone.y > 0 and gap or 0),
        w = zone.w * availW - (zone.x > 0 and gap or 0),
        h = zone.h * availH - (zone.y > 0 and gap or 0)
    }
end

-- ============================================
-- KEYBOARD SHORTCUTS FOR QUICK SNAPPING
-- ============================================

-- Snap to zone by number (Ctrl+Cmd + 1-6)
local function snapToZone(zoneIndex)
    local win = hs.window.focusedWindow()
    if not win then return end
    
    local zone = currentLayout.zones[zoneIndex]
    if not zone then return end
    
    local sf = getScreenFrame()
    local zf = getZoneFrame(zone, sf)
    
    win:setFrame({ x = zf.x, y = zf.y, w = zf.w, h = zf.h })
    hs.alert.show(zone.label, 0.5)
end

hs.hotkey.bind({"ctrl", "cmd"}, "1", function() snapToZone(1) end)
hs.hotkey.bind({"ctrl", "cmd"}, "2", function() snapToZone(2) end)
hs.hotkey.bind({"ctrl", "cmd"}, "3", function() snapToZone(3) end)
hs.hotkey.bind({"ctrl", "cmd"}, "4", function() snapToZone(4) end)
hs.hotkey.bind({"ctrl", "cmd"}, "5", function() snapToZone(5) end)
hs.hotkey.bind({"ctrl", "cmd"}, "6", function() snapToZone(6) end)

-- Fullscreen
hs.hotkey.bind({"ctrl", "cmd"}, "F", function()
    local win = hs.window.focusedWindow()
    if not win then return end
    local sf = getScreenFrame()
    win:setFrame({ x = sf.x, y = sf.y, w = sf.w, h = sf.h })
end)

-- ============================================
-- DRAG TO SNAP - Using window position monitoring
-- ============================================

local dragSnapEnabled = true
local windowPositions = {}
local zonePreview = nil

-- Show all zones overlay with active zone highlighted
local function showAllZones(activeZoneIndex)
    if zonePreview then
        zonePreview:delete()
    end
    
    local screen = hs.screen.mainScreen()
    local screenFrame = screen:frame()
    local sf = getScreenFrame()
    
    zonePreview = hs.canvas.new(screenFrame)
    
    -- Draw layout name
    zonePreview:appendElements({
        type = "text",
        frame = { x = 20, y = 20, w = 300, h = 40 },
        text = currentLayout.name,
        textSize = 32,
        textColor = { red = 1, green = 1, blue = 1, alpha = 0.8 },
        textAlignment = "left"
    })
    
    -- Draw each zone
    for i, zone in ipairs(currentLayout.zones) do
        local zf = getZoneFrame(zone, sf)
        
        -- Determine if this is the active zone
        local isActive = (i == activeZoneIndex)
        
        -- Colors: green for active, muted blue-gray for inactive
        local strokeColor, fillColor, textColor
        if isActive then
            strokeColor = { red = 0.2, green = 0.8, blue = 0.4, alpha = 0.9 }
            fillColor = { red = 0.2, green = 0.8, blue = 0.4, alpha = 0.25 }
            textColor = { red = 0.2, green = 0.8, blue = 0.4, alpha = 0.9 }
        else
            strokeColor = { red = 0.4, green = 0.5, blue = 0.7, alpha = 0.6 }
            fillColor = { red = 0.3, green = 0.4, blue = 0.5, alpha = 0.1 }
            textColor = { red = 0.4, green = 0.5, blue = 0.7, alpha = 0.7 }
        end
        
        -- Zone rectangle
        zonePreview:appendElements({
            type = "rectangle",
            frame = {
                x = zf.x - screenFrame.x,
                y = zf.y - screenFrame.y,
                w = zf.w,
                h = zf.h
            },
            strokeColor = strokeColor,
            fillColor = fillColor,
            strokeWidth = isActive and 4 or 2,
            roundedRectRadii = { xRadius = 10, yRadius = 10 }
        })
        
        -- Zone label
        zonePreview:appendElements({
            type = "text",
            frame = {
                x = zf.x - screenFrame.x + 10,
                y = zf.y - screenFrame.y + zf.h/2 - 20,
                w = zf.w - 20,
                h = 40
            },
            text = zone.label,
            textSize = isActive and 28 or 22,
            textColor = textColor,
            textAlignment = "center"
        })
    end
    
    zonePreview:level(hs.canvas.windowLevels.overlay)
    zonePreview:show()
end

local function hideZonePreview()
    if zonePreview then
        zonePreview:delete()
        zonePreview = nil
    end
end

-- Show grid with Ctrl+Alt+G (toggle zones overlay)
local gridVisible = false
hs.hotkey.bind({"ctrl", "alt"}, "G", function()
    if gridVisible then
        hideZonePreview()
        gridVisible = false
    else
        showAllZones(nil) -- Show all zones with none highlighted
        gridVisible = true
        -- Auto-hide after 3 seconds
        hs.timer.doAfter(3, function()
            if gridVisible then
                hideZonePreview()
                gridVisible = false
            end
        end)
    end
end)

-- Get zone index for a window based on its center position
local function getZoneForWindow(win)
    local frame = win:frame()
    local centerX = frame.x + frame.w / 2
    local centerY = frame.y + frame.h / 2
    
    local sf = getScreenFrame()
    
    -- Find which zone the window center is in
    local bestZone = 1
    local bestDistance = math.huge
    
    for i, zone in ipairs(currentLayout.zones) do
        local zf = getZoneFrame(zone, sf)
        local zoneCenterX = zf.x + zf.w / 2
        local zoneCenterY = zf.y + zf.h / 2
        
        -- Check if center is inside this zone
        if centerX >= zf.x and centerX <= zf.x + zf.w and
           centerY >= zf.y and centerY <= zf.y + zf.h then
            return i
        end
        
        -- Otherwise track closest zone
        local dist = math.sqrt((centerX - zoneCenterX)^2 + (centerY - zoneCenterY)^2)
        if dist < bestDistance then
            bestDistance = dist
            bestZone = i
        end
    end
    
    return bestZone
end

-- Snap window to its zone
local function snapWindowToZone(win)
    if not win or not win:isStandard() then return end
    
    local zoneIndex = getZoneForWindow(win)
    local zone = currentLayout.zones[zoneIndex]
    local sf = getScreenFrame()
    local zf = getZoneFrame(zone, sf)
    
    hideZonePreview()
    win:setFrame({ x = zf.x, y = zf.y, w = zf.w, h = zf.h })
    hs.alert.show(currentLayout.name .. ": " .. zone.label, 0.5)
end

-- Track window movement
local function checkWindowMoved(win)
    if not win or not dragSnapEnabled then return end
    
    local id = win:id()
    local currentFrame = win:frame()
    local lastFrame = windowPositions[id]
    
    if lastFrame then
        -- Check if window stopped moving (position same as last check)
        local dx = math.abs(currentFrame.x - lastFrame.x)
        local dy = math.abs(currentFrame.y - lastFrame.y)
        
        if dx < 5 and dy < 5 and lastFrame.moving then
            -- Window stopped moving - snap it!
            snapWindowToZone(win)
            windowPositions[id] = { x = currentFrame.x, y = currentFrame.y, moving = false }
        elseif dx > 10 or dy > 10 then
            -- Window is moving
            windowPositions[id] = { x = currentFrame.x, y = currentFrame.y, moving = true }
        end
    else
        windowPositions[id] = { x = currentFrame.x, y = currentFrame.y, moving = false }
    end
end

-- Watch all windows for movement
local windowFilter = hs.window.filter.new():setDefaultFilter()
local lastPreviewZone = nil
local isDragging = false
local draggedWindow = nil

-- Mouse down event tap to detect window clicks (global to prevent GC)
-- Hold Option to bypass snapping
mouseDownTap = hs.eventtap.new({hs.eventtap.event.types.leftMouseDown}, function(event)
    if not dragSnapEnabled then return false end
    
    -- Check if Option key is held - bypass snapping
    local flags = event:getFlags()
    if flags.alt then return false end
    
    local mousePos = hs.mouse.absolutePosition()
    
    -- Find window under mouse cursor
    local win = nil
    local allWindows = hs.window.orderedWindows()
    
    for _, w in ipairs(allWindows) do
        if w:isStandard() then
            local frame = w:frame()
            if mousePos.x >= frame.x and mousePos.x <= frame.x + frame.w and
               mousePos.y >= frame.y and mousePos.y <= frame.y + frame.h then
                win = w
                break
            end
        end
    end
    
    if win then
        -- Skip floating apps
        if isFloatingApp(win) then return false end
        
        local frame = win:frame()
        local titleBarHeight = 50 -- Title bar height
        
        -- Check if click is in title bar area (top of window)
        if mousePos.y <= frame.y + titleBarHeight then
            isDragging = true
            draggedWindow = win
            local zoneIndex = getZoneForWindow(win)
            showAllZones(zoneIndex)
            lastPreviewZone = zoneIndex
        end
    end
    
    return false -- Don't consume the event
end)

-- Mouse up event tap to hide zones and snap (global to prevent GC)
mouseUpTap = hs.eventtap.new({hs.eventtap.event.types.leftMouseUp}, function(event)
    if isDragging and draggedWindow then
        -- Snap the window to its zone
        snapWindowToZone(draggedWindow)
        isDragging = false
        draggedWindow = nil
        lastPreviewZone = nil
    end
    return false
end)

-- Mouse dragged event to update highlighted zone while dragging (global to prevent GC)
mouseDragTap = hs.eventtap.new({hs.eventtap.event.types.leftMouseDragged}, function(event)
    if isDragging and draggedWindow and dragSnapEnabled then
        -- Update zone highlight based on current window position
        local zoneIndex = getZoneForWindow(draggedWindow)
        if zoneIndex and zoneIndex ~= lastPreviewZone then
            showAllZones(zoneIndex)
            lastPreviewZone = zoneIndex
        end
    end
    return false
end)

-- Start the event taps
mouseDownTap:start()
mouseUpTap:start()
mouseDragTap:start()

-- Track window positions (no longer auto-snaps on resize/programmatic moves)
windowFilter:subscribe(hs.window.filter.windowMoved, function(win)
    if win:isStandard() then
        local id = win:id()
        local frame = win:frame()
        windowPositions[id] = { x = frame.x, y = frame.y, moving = false }
    end
end)

-- Toggle drag-to-snap with Ctrl+Alt+D
hs.hotkey.bind({"ctrl", "alt"}, "D", function()
    dragSnapEnabled = not dragSnapEnabled
    hs.alert.show("Drag-to-Snap: " .. (dragSnapEnabled and "ON" or "OFF"), 1)
end)

-- ============================================
-- LAYOUT SWITCHING (Ctrl+Alt+1/2/3)
-- ============================================

local function switchLayout(index, skipSave)
    if layouts[index] then
        currentLayoutIndex = index
        currentLayout = layouts[index]
        showAllZones(nil)
        updateBanner()
        
        -- Auto-save layout to current space (unless skipSave is true)
        if not skipSave then
            local spaceId = getCurrentSpaceId()
            if spaceId then
                spaceLayouts[tostring(spaceId)] = index
                hs.settings.set("windowManager.spaceLayouts", spaceLayouts)
            end
        end
        
        hs.alert.show("Layout: " .. currentLayout.name, 1)
        -- Auto-hide after 2 seconds
        hs.timer.doAfter(2, function()
            hideZonePreview()
        end)
    end
end

hs.hotkey.bind({"ctrl", "alt"}, "1", function() switchLayout(1) end)
hs.hotkey.bind({"ctrl", "alt"}, "2", function() switchLayout(2) end)
hs.hotkey.bind({"ctrl", "alt"}, "3", function() switchLayout(3) end)

-- ============================================
-- SPACE-AWARE AUTO-SWITCHING
-- ============================================
-- Layouts auto-save to current Space when you switch with Ctrl+Alt+1/2/3

-- Clear layout assignment for current space (Ctrl+Alt+Shift+S)
hs.hotkey.bind({"ctrl", "alt", "shift"}, "S", function()
    local spaceId = getCurrentSpaceId()
    if spaceId then
        spaceLayouts[tostring(spaceId)] = nil
        hs.settings.set("windowManager.spaceLayouts", spaceLayouts)
        hs.alert.show("Space layout cleared", 1)
    end
end)

-- Toggle auto-switch on space change (Ctrl+Alt+A)
hs.hotkey.bind({"ctrl", "alt"}, "A", function()
    autoSwitchEnabled = not autoSwitchEnabled
    hs.alert.show("Auto-switch on Space change: " .. (autoSwitchEnabled and "ON" or "OFF"), 1)
end)

-- Watch for space changes
spaceWatcher = hs.spaces.watcher.new(function()
    if not autoSwitchEnabled then return end
    
    -- Small delay to let the space switch complete
    hs.timer.doAfter(0.1, function()
        local spaceId = getCurrentSpaceId()
        if spaceId then
            local layoutIndex = spaceLayouts[tostring(spaceId)]
            if layoutIndex and layouts[layoutIndex] then
                -- Only switch if different from current
                if layoutIndex ~= currentLayoutIndex then
                    currentLayoutIndex = layoutIndex
                    currentLayout = layouts[layoutIndex]
                    updateBanner()
                    hs.alert.show("⬡ " .. currentLayout.name, 0.8)
                end
            end
        end
    end)
end)
spaceWatcher:start()

-- Debug: Show all space assignments (Ctrl+Alt+Shift+A)
hs.hotkey.bind({"ctrl", "alt", "shift"}, "A", function()
    local count = 0
    local msg = "Space Layouts:\n"
    for spaceId, layoutIdx in pairs(spaceLayouts) do
        if layouts[layoutIdx] then
            msg = msg .. "• " .. layouts[layoutIdx].name .. "\n"
            count = count + 1
        end
    end
    if count == 0 then
        msg = "No spaces configured yet"
    end
    hs.alert.show(msg, 2)
end)

-- ============================================
-- HELP SCREEN (Ctrl+Alt+H)
-- ============================================

local helpOverlay = nil
local helpVisible = false

local function showHelp()
    if helpOverlay then
        helpOverlay:delete()
    end
    
    local screen = hs.screen.mainScreen()
    local screenFrame = screen:frame()
    
    -- Help content
    local spaceId = getCurrentSpaceId()
    local spaceLayoutName = "None"
    if spaceId and spaceLayouts[tostring(spaceId)] then
        local idx = spaceLayouts[tostring(spaceId)]
        if layouts[idx] then
            spaceLayoutName = layouts[idx].name
        end
    end
    
    local helpText = [[
WINDOW MANAGER SHORTCUTS

LAYOUTS (auto-saved per Space)
  Ctrl+Alt+1     Default (4 columns)
  Ctrl+Alt+2     Coding (editor + terminal)
  Ctrl+Alt+3     Demo (main + notes)

SNAP WINDOWS
  Ctrl+Cmd+1-6   Snap to zone 1-6
  Ctrl+Cmd+F     Fullscreen
  Drag window    Auto-snap on release
  ⌥+Drag         Free move (no snap)

SPACES
  Ctrl+Alt+⇧+S   Clear Space assignment
  Ctrl+Alt+⇧+A   Show all assignments
  Ctrl+Alt+A     Toggle auto-switch

VIEW & TOGGLE
  Ctrl+Alt+G     Show zones
  Ctrl+Alt+B     Toggle layout banner
  Ctrl+Alt+D     Toggle drag-to-snap
  Ctrl+Alt+F     Toggle app floating
  Ctrl+Alt+H     This help screen

Current: ]] .. currentLayout.name .. " | Space: " .. spaceLayoutName
    
    -- Calculate panel size
    local panelW = 420
    local panelH = 500
    local panelX = (screenFrame.w - panelW) / 2
    local panelY = (screenFrame.h - panelH) / 2
    
    helpOverlay = hs.canvas.new(screenFrame)
    
    -- Semi-transparent background
    helpOverlay:appendElements({
        type = "rectangle",
        frame = { x = 0, y = 0, w = screenFrame.w, h = screenFrame.h },
        fillColor = { red = 0, green = 0, blue = 0, alpha = 0.7 }
    })
    
    -- Help panel background
    helpOverlay:appendElements({
        type = "rectangle",
        frame = { x = panelX, y = panelY, w = panelW, h = panelH },
        fillColor = { red = 0.15, green = 0.15, blue = 0.2, alpha = 0.95 },
        strokeColor = { red = 0.4, green = 0.5, blue = 0.7, alpha = 0.8 },
        strokeWidth = 2,
        roundedRectRadii = { xRadius = 12, yRadius = 12 }
    })
    
    -- Help text
    helpOverlay:appendElements({
        type = "text",
        frame = { x = panelX + 30, y = panelY + 20, w = panelW - 60, h = panelH - 40 },
        text = helpText,
        textSize = 16,
        textColor = { red = 0.9, green = 0.9, blue = 0.95, alpha = 1 },
        textAlignment = "left",
        textFont = "Menlo"
    })
    
    -- Dismiss hint
    helpOverlay:appendElements({
        type = "text",
        frame = { x = panelX, y = panelY + panelH - 35, w = panelW, h = 25 },
        text = "Press Ctrl+Alt+H or click anywhere to close",
        textSize = 12,
        textColor = { red = 0.6, green = 0.6, blue = 0.7, alpha = 0.8 },
        textAlignment = "center"
    })
    
    helpOverlay:level(hs.canvas.windowLevels.overlay)
    helpOverlay:show()
end

local function hideHelp()
    if helpOverlay then
        helpOverlay:delete()
        helpOverlay = nil
    end
    helpVisible = false
end

hs.hotkey.bind({"ctrl", "alt"}, "H", function()
    if helpVisible then
        hideHelp()
    else
        showHelp()
        helpVisible = true
        -- Click anywhere to dismiss
        helpClickTap = hs.eventtap.new({hs.eventtap.event.types.leftMouseDown}, function(e)
            hideHelp()
            if helpClickTap then
                helpClickTap:stop()
                helpClickTap = nil
            end
            return false
        end):start()
    end
end)

-- ============================================
-- STARTUP
-- ============================================

-- Initialize banner
updateBanner()

hs.alert.show("Window Manager Ready!\nCtrl+Alt+H for help", 2)
print("Multi-Layout Window Manager Loaded")
print("Ctrl+Alt+H = Show help")
 