-- Hammerspoon Config: 4-Column Window Manager for 48" Monitor
-- Press Ctrl+Alt+G to show grid and click to place windows

local gap = 10

-- ============================================
-- BUILT-IN GRID SYSTEM (reliable!)
-- ============================================

-- Configure grid: 4 columns, 2 rows (for your split columns 1 and 4)
hs.grid.setGrid('4x2')
hs.grid.setMargins({gap, gap})

-- Show grid with Ctrl+Alt+G
hs.hotkey.bind({"ctrl", "alt"}, "G", function()
    hs.grid.show()
end)

-- ============================================
-- KEYBOARD SHORTCUTS FOR QUICK SNAPPING
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

-- Snap to column (1-4)
local function snapToColumn(col)
    local win = hs.window.focusedWindow()
    if not win then return end
    
    local sf = getScreenFrame()
    local colWidth = (sf.w - (gap * 3)) / 4
    local x = sf.x + ((col - 1) * (colWidth + gap))
    
    win:setFrame({ x = x, y = sf.y, w = colWidth, h = sf.h })
end

-- Snap to column half (top/bottom)
local function snapToColumnHalf(col, position)
    local win = hs.window.focusedWindow()
    if not win then return end
    
    local sf = getScreenFrame()
    local colWidth = (sf.w - (gap * 3)) / 4
    local halfHeight = (sf.h - gap) / 2
    local x = sf.x + ((col - 1) * (colWidth + gap))
    local y = sf.y
    
    if position == "bottom" then
        y = sf.y + halfHeight + gap
    end
    
    win:setFrame({ x = x, y = y, w = colWidth, h = halfHeight })
end

-- Column shortcuts (Ctrl+Cmd + 1/2/3/4)
hs.hotkey.bind({"ctrl", "cmd"}, "1", function() snapToColumn(1) end)
hs.hotkey.bind({"ctrl", "cmd"}, "2", function() snapToColumn(2) end)
hs.hotkey.bind({"ctrl", "cmd"}, "3", function() snapToColumn(3) end)
hs.hotkey.bind({"ctrl", "cmd"}, "4", function() snapToColumn(4) end)

-- Column 1 split (Ctrl+Cmd+Shift/Alt + 1)
hs.hotkey.bind({"ctrl", "cmd", "shift"}, "1", function() snapToColumnHalf(1, "top") end)
hs.hotkey.bind({"ctrl", "cmd", "alt"}, "1", function() snapToColumnHalf(1, "bottom") end)

-- Column 4 split (Ctrl+Cmd+Shift/Alt + 4)
hs.hotkey.bind({"ctrl", "cmd", "shift"}, "4", function() snapToColumnHalf(4, "top") end)
hs.hotkey.bind({"ctrl", "cmd", "alt"}, "4", function() snapToColumnHalf(4, "bottom") end)

-- Left half (columns 1-2)
hs.hotkey.bind({"ctrl", "cmd"}, "Q", function()
    local win = hs.window.focusedWindow()
    if not win then return end
    local sf = getScreenFrame()
    win:setFrame({ x = sf.x, y = sf.y, w = (sf.w - gap) / 2, h = sf.h })
end)

-- Right half (columns 3-4)
hs.hotkey.bind({"ctrl", "cmd"}, "W", function()
    local win = hs.window.focusedWindow()
    if not win then return end
    local sf = getScreenFrame()
    local halfW = (sf.w - gap) / 2
    win:setFrame({ x = sf.x + halfW + gap, y = sf.y, w = halfW, h = sf.h })
end)

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

-- Define all 6 snap zones
local allZones = {
    { col = 1, half = "top", label = "1 Top" },
    { col = 1, half = "bottom", label = "1 Bottom" },
    { col = 2, half = "full", label = "2" },
    { col = 3, half = "full", label = "3" },
    { col = 4, half = "top", label = "4 Top" },
    { col = 4, half = "bottom", label = "4 Bottom" }
}

-- Check if two zones match
local function zonesMatch(z1, z2)
    if not z1 or not z2 then return false end
    return z1.col == z2.col and z1.half == z2.half
end

-- Show all zones overlay with active zone highlighted
local function showAllZones(activeZone)
    if zonePreview then
        zonePreview:delete()
    end
    
    local screen = hs.screen.mainScreen()
    local screenFrame = screen:frame()
    local sf = getScreenFrame()
    local colWidth = (sf.w - (gap * 3)) / 4
    local halfHeight = (sf.h - gap) / 2
    
    zonePreview = hs.canvas.new(screenFrame)
    
    -- Draw each zone
    for _, zone in ipairs(allZones) do
        local x = sf.x + ((zone.col - 1) * (colWidth + gap))
        local y = sf.y
        local h = sf.h
        
        if zone.half == "top" then
            h = halfHeight
        elseif zone.half == "bottom" then
            y = sf.y + halfHeight + gap
            h = halfHeight
        end
        
        -- Determine if this is the active zone
        local isActive = zonesMatch(zone, activeZone)
        
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
                x = x - screenFrame.x,
                y = y - screenFrame.y,
                w = colWidth,
                h = h
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
                x = x - screenFrame.x + 10,
                y = y - screenFrame.y + h/2 - 20,
                w = colWidth - 20,
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

-- Get zone for a window based on its center position
local function getZoneForWindow(win)
    local frame = win:frame()
    local centerX = frame.x + frame.w / 2
    local centerY = frame.y + frame.h / 2
    
    local sf = getScreenFrame()
    local colWidth = (sf.w - (gap * 3)) / 4
    local halfHeight = (sf.h - gap) / 2
    
    -- Determine column (1-4) based on window center
    local col = math.floor((centerX - sf.x) / (colWidth + gap)) + 1
    if col > 4 then col = 4 end
    if col < 1 then col = 1 end
    
    -- For columns 1 and 4, determine top/bottom
    local half = "full"
    if col == 1 or col == 4 then
        local midY = sf.y + halfHeight + gap/2
        if centerY < midY then
            half = "top"
        else
            half = "bottom"
        end
    end
    
    return { col = col, half = half }
end

-- Snap window to its zone
local function snapWindowToZone(win)
    if not win or not win:isStandard() then return end
    
    local zone = getZoneForWindow(win)
    local sf = getScreenFrame()
    local colWidth = (sf.w - (gap * 3)) / 4
    local halfHeight = (sf.h - gap) / 2
    
    local x = sf.x + ((zone.col - 1) * (colWidth + gap))
    local y = sf.y
    local h = sf.h
    
    if zone.half == "top" then
        h = halfHeight
    elseif zone.half == "bottom" then
        y = sf.y + halfHeight + gap
        h = halfHeight
    end
    
    hideZonePreview()
    win:setFrame({ x = x, y = y, w = colWidth, h = h })
    hs.alert.show("Snapped to " .. zone.col .. (zone.half ~= "full" and (" " .. zone.half) or ""), 0.5)
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
mouseDownTap = hs.eventtap.new({hs.eventtap.event.types.leftMouseDown}, function(event)
    if not dragSnapEnabled then return false end
    
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
        local frame = win:frame()
        local titleBarHeight = 50 -- Title bar height
        
        -- Check if click is in title bar area (top of window)
        if mousePos.y <= frame.y + titleBarHeight then
            isDragging = true
            draggedWindow = win
            local zone = getZoneForWindow(win)
            showAllZones(zone)
            lastPreviewZone = zone
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
        local zone = getZoneForWindow(draggedWindow)
        if zone then
            if not lastPreviewZone or zone.col ~= lastPreviewZone.col or zone.half ~= lastPreviewZone.half then
                showAllZones(zone)
                lastPreviewZone = zone
            end
        end
    end
    return false
end)

-- Start the event taps
mouseDownTap:start()
mouseUpTap:start()
mouseDragTap:start()

-- Keep the windowMoved handler as backup for programmatic moves
windowFilter:subscribe(hs.window.filter.windowMoved, function(win)
    if dragSnapEnabled and win:isStandard() and not isDragging then
        local id = win:id()
        local frame = win:frame()
        windowPositions[id] = { x = frame.x, y = frame.y, moving = true }
        
        -- Show all zones with current target highlighted
        local zone = getZoneForWindow(win)
        if zone then
            -- Only update preview if zone changed
            if not lastPreviewZone or zone.col ~= lastPreviewZone.col or zone.half ~= lastPreviewZone.half then
                showAllZones(zone)
                lastPreviewZone = zone
            end
        end
        
        -- Check after a short delay if window stopped
        hs.timer.doAfter(0.3, function()
            checkWindowMoved(win)
            hideZonePreview()
            lastPreviewZone = nil
        end)
    end
end)

-- Toggle drag-to-snap with Ctrl+Alt+D
hs.hotkey.bind({"ctrl", "alt"}, "D", function()
    dragSnapEnabled = not dragSnapEnabled
    hs.alert.show("Drag-to-Snap: " .. (dragSnapEnabled and "ON" or "OFF"), 1)
end)

-- ============================================
-- STARTUP
-- ============================================

hs.alert.show("Window Manager Ready!\nDrag windows to snap!", 2)
print("4-Column Window Manager Loaded")
print("Ctrl+Alt+G = Show grid")
print("Ctrl+Alt+D = Toggle drag-to-snap")
print("Ctrl+Cmd+1/2/3/4 = Snap to column")
 