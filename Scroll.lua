local gooey = require "gooey.gooey"
-- local appmod = require "src.core.app"
-- local helpermod = require "src.core.helpers.helper"
-- local guihelpermod = require "src.core.helpers.gui_helper"

local Scroll = {}


-- Create a new scroller
function Scroll:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end


-- Init the nodes and the data
function Scroll:init(data)
    -- Smooth scrolling
    self.parent             = data.parent
    self.config             = data.config or {}
    self.dynamic            = data.dynamic -- Whether this is a dynamic list or a static list (true for dyanmic).
    self.scrollTo           = data.scrollTo -- Set the scroll position of the list's x and y (e.g. {x = 1, y = 0})
    self.inertia            = data.inertia or true  -- Disable/Enable inertia effect
    self.inputAction        = {}   -- The current touch/mouse input action
    self.actionId           = data.actionId or hash('touch') -- defold input action id, required by the gooey lists
    self.data               = data.data or {}
    self.gooyGroupName      = data.gooyGroupName
    self.containerNodeId    = data.containerNodeId
    self.stencilNodeId      = data.stencilNodeId
    self.stencilNode        = gui.get_node(self.stencilNodeId)

    -- Dynamic list
    self.dynamicListItemId  = data.dynamicListItemId -- Applies to dynamic lists only, (string|hash) - Id of the single list item that is to be cloned to present the list data.
    self.onListItemSelect   = data.onListItemSelect -- Function to call when a list item is selected.
    self.onListUpdate       = data.onListUpdate -- Optional function to call when the state of the list has been updated. Use this to update the visual representation.

    -- Accumulated scroll offsets
    self.scrollOffsetX = 0
    self.scrollOffsetY = 0
    self.velocity      = 0 -- Inertia velocity (pixels/second) and friction
    self.friction      = data.friction or 6 --How fast inertia slows down, tweak as required

    -- Drag state
    self.isDragging    = false
    self.dragLastX     = 0
    self.dragLastY     = 0
    ---------------------------------------------------

    -- Init and position the static list elements and set the stencil.
    self:setScrollableList()
    
    -- local action1 = {x = 557.5, screen_dy = 0, dy = 0, dx = 0, y = 237.5, screen_x = 557, screen_y = 237, screen_dx = 0, pressed = false, released = false, value = 1}
    -- local action2 = {x = 557.5, screen_dy = 0, dy = 0, dx = 0, y = 237.5, screen_x = 557, screen_y = 237, screen_dx = 0, pressed = false, released = true, value = 0}
    -- self:setScrollableList(action1)
end


-- Handles input events for scrolling
function Scroll:onInput(action, actionId)
    
    -- Only respond to touch input
    if actionId == hash("touch") then
        self.inputAction = action

        -- Check if touch is within the scrollable area
        local over = gui.pick_node(self.stencilNode, action.x, action.y)

        -- Begin dragging if touch is pressed and over the scroll area
        if action.pressed and over then
            self.isDragging   = true
            self.velocity = 0  -- Reset velocity on new drag
            
            -- End dragging when touch is released
        elseif action.released then
            self.isDragging = false

        end

        -- Handle on item clicks/touches. Make sure we are not actively scrolling otherwise
        -- this will override the smooth scrolling handled on the update() function.
        if (not self.isDragging) and self.velocity == 0 then
            self:setScrollableList()
        end
    end
end


-- Updates scroll position and velocity each frame
function Scroll:update(dt)
    -- If dragging, update scroll offset based on finger movement
    if self.isDragging and self.inputAction then
        self:setScrollableList()  -- Re-render list with current input

        -- Calculate movement delta since last frame
        local dx = self.inputAction.x - self.dragLastX
        local dy = self.inputAction.y - self.dragLastY

        -- Update scroll offset and velocity depending on scroll direction
        if self.config.horizontal then
            self.scrollOffsetX = self.scrollOffsetX + dx
            self.velocity   = dx / dt  -- Velocity in pixels per second
            self.dragLastX  = self.inputAction.x
        else
            self.scrollOffsetY = self.scrollOffsetY + dy
            self.velocity  = dy / dt
            self.dragLastY = self.inputAction.y
        end

    -- If not dragging, apply inertia-based scrolling
    elseif self.inertia == true then
        -- Apply exponential decay to velocity (frame-rate independent)
        local decay = math.exp(-self.friction * dt)
        self.velocity = self.velocity * decay

        -- Stop scrolling if velocity is negligible
        if math.abs(self.velocity) < 1 then
            self.velocity = 0
        end

        -- Advance scroll offset based on decayed velocity
        if self.config.horizontal then
            self.scrollOffsetX = self.scrollOffsetX + self.velocity * dt
        else
            self.scrollOffsetY = self.scrollOffsetY + self.velocity * dt
        end

        -- Re-render list using updated scroll offset
        local x = 0
        local y = 0
        if self.config.horizontal then
            x = self.scrollOffsetX
        else
            y = self.scrollOffsetY
        end
        self:setScrollableList({ x = x, y = y })

        -- Store last rendered position for continuity
        self.dragLastX = x
        self.dragLastY = y
    end
end


function Scroll:setScrollableList(action)
    -- Use current input if none provided
    action = action or self.inputAction
    
    -- Make sure we have data for the initialisation otherwise GUI is not updated unless touch input is triggered.
    if (not self.data or (not next(self.data))) then return end

    -- Position the list elements and set the stencil.
    if self.dynamic then
        self:setDynamiclist(action)
    else
        self:setStaticList(action)
    end
end


-- Renders the scrollable list with optional input action
function Scroll:setStaticList(action)

    -- Create a gooey group to manage UI interactions
    local group = gooey.group(self.gooyGroupName, function()
        -- Render static list with current scroll state
        self.list = gooey.static_list(self.containerNodeId, self.stencilNodeId, self.data, self.actionId, action, self.config,
        function(list)
            if self.onListItemSelect then 
                self.onListItemSelect(self.parent, list, action)
            end 
        end,
        function(list)
            if self.onListUpdate then
                self.onListUpdate(parent, list)
            end
        end)

        -- Scroll to a specific position if requested
        if self.scrollTo and self.scrollTo.x and self.scrollTo.y then
            self.list.scroll_to(self.scrollTo.x, self.scrollTo.y)
            self.scrollTo = nil  -- Clear scroll target after use
        end
	end)

    -- Return whether the input was consumed by the list
    return group.consumed
end


function Scroll:setDynamiclist(action)
    local group = gooey.group(self.gooyGroupName, function()
        self.list = gooey.dynamic_list(self.containerNodeId, self.stencilNodeId, self.dynamicListItemId, self.data, self.actionId, action, self.config, 
        function(item)
            if self.onListItemSelect then 
                self.onListItemSelect(self.parent, item, action)
            end 
        end,
        function(list)
            if self.onListUpdate then self.onListUpdate(self.parent, list) end
        end)

        -- Scroll to a specific position if requested
        if self.scrollTo and self.scrollTo.x and self.scrollTo.y then
            self.list.scroll_to(self.scrollTo.x, self.scrollTo.y)
            self.scrollTo = nil  -- Clear scroll target after use so this happens only once
        end
    end)

    -- Return whether the input was consumed by the list
    return group.consumed
    
    -- Reference the dynamic list data so we can access it to clear the list etc. when refreshing the data
    -- if listId       == 'listContentBg'      then self.listData.friendsList  = list
    -- elseif listId   == 'requestsContentBg'  then self.listData.requestsList = list
    -- elseif listId   == 'blockedContentBg'   then self.listData.blockedList  = list
    -- end
end



return Scroll