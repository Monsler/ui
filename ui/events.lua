local Events = {}


Events.TYPES = {
    
    MOUSE_MOVE = 'mouse_move',
    MOUSE_PRESS = 'mouse_press',
    MOUSE_RELEASE = 'mouse_release',
    MOUSE_ENTER = 'mouse_enter',
    MOUSE_LEAVE = 'mouse_leave',
    SCROLL = 'scroll',

    
    CLICK = 'click',
    DOUBLE_CLICK = 'double_click',
    RIGHT_CLICK = 'right_click',

    
    KEY_PRESSED = 'key_pressed',
    KEY_RELEASED = 'key_released',
    TEXT_INPUT = 'text_input',

    
    FOCUS_GAINED = 'focus_gained',
    FOCUS_LOST = 'focus_lost',

    
    VALUE_CHANGED = 'value_changed',
    STATE_CHANGED = 'state_changed',
}


local Event = {}
Event.__index = Event





function Event.new(type, target, data)
    local self = setmetatable({}, Event)
    self.type = type
    self.target = target
    self.current_target = nil  
    self.data = data or {}
    self.propagation_stopped = false
    self.default_prevented = false
    self.timestamp = love.timer.getTime()
    return self
end


function Event:stop_propagation()
    self.propagation_stopped = true
end


function Event:prevent_default()
    self.default_prevented = true
end





local event_manager = {
    listeners = {},       
    hover_state = {},     
    hover_node = nil,     
    pressed_state = {},   
    focused_node = nil,   
    last_click_time = 0,  
    last_click_node = nil,
    double_click_delay = 0.3,
}
function Events.on(node, event_type, callback, once)
    assert(node ~= nil, 'Node is required')
    assert(type(event_type) == 'string', 'Event type must be a string')
    assert(type(callback) == 'function', 'Callback must be a function')

    local node_id = tostring(node)

    if not event_manager.listeners[node_id] then
        event_manager.listeners[node_id] = {}
    end

    if not event_manager.listeners[node_id][event_type] then
        event_manager.listeners[node_id][event_type] = {}
    end

    table.insert(event_manager.listeners[node_id][event_type], {
        callback = callback,
        once = once or false,
    })
end


function Events.once(node, event_type, callback)
    Events.on(node, event_type, callback, true)
end





function Events.off(node, event_type, callback)
    local node_id = tostring(node)
    local listeners = event_manager.listeners[node_id]
    if not listeners then return end

    if event_type == nil then
        
        event_manager.listeners[node_id] = nil
        return
    end

    local type_listeners = listeners[event_type]
    if not type_listeners then return end

    if callback == nil then
        
        listeners[event_type] = nil
        return
    end

    
    for i = #type_listeners, 1, -1 do
        if type_listeners[i].callback == callback then
            table.remove(type_listeners, i)
        end
    end

    if #type_listeners == 0 then
        listeners[event_type] = nil
    end
end



function Events.emit(event)
    assert(event and event.type, 'Valid event object required')

    
    local chain = {}
    local current = event.target

    while current do
        table.insert(chain, current)
        current = current._parent
    end

    
    for _, node in ipairs(chain) do
        if event.propagation_stopped then break end

        event.current_target = node
        local node_id = tostring(node)
        local listeners = event_manager.listeners[node_id]

        if listeners then
            local type_listeners = listeners[event.type]
            if type_listeners then
                
                local to_remove = {}

                for i, listener in ipairs(type_listeners) do
                    local ok, err = pcall(listener.callback, event, node)
                    if not ok then
                        
                        if love and love.errhand then
                            print('[UI Events] Error in listener: ' .. tostring(err))
                        end
                    end

                    if listener.once then
                        table.insert(to_remove, i)
                    end
                end

                
                for i = #to_remove, 1, -1 do
                    table.remove(type_listeners, to_remove[i])
                end
            end
        end
    end
end




function Events.handle_mouse_move(root_node, x, y)
    if not root_node then return end

    
    local hovered = Events.hit_test(root_node, x, y)

    
    Events.update_hover_states(root_node, hovered)

    
    if hovered then
        local event = Event.new(Events.TYPES.MOUSE_MOVE, hovered, {x = x, y = y})
        Events.emit(event)
    end
end


function Events.handle_mouse_move_with_target(root_node, target, x, y)
    if not root_node then return end

    
    Events.update_hover_states(root_node, target)

    
    if target then
        local event = Event.new(Events.TYPES.MOUSE_MOVE, target, {x = x, y = y})
        Events.emit(event)
    end
end



function Events.handle_mouse_press(root_node, x, y, button)
    if not root_node then return end

    button = button or 1

    local pressed = Events.hit_test(root_node, x, y)
    if not pressed then return end

    
    local now = love.timer.getTime()
    local is_double_click = (now - event_manager.last_click_time) < event_manager.double_click_delay
        and event_manager.last_click_node == pressed

    
    local event_type
    if button == 2 then
        event_type = Events.TYPES.RIGHT_CLICK
    elseif is_double_click then
        event_type = Events.TYPES.DOUBLE_CLICK
    else
        event_type = Events.TYPES.MOUSE_PRESS
    end

    
    event_manager.pressed_state[tostring(pressed)] = true

    if is_double_click then
        event_manager.last_click_time = 0
        event_manager.last_click_node = nil
    else
        event_manager.last_click_time = now
        event_manager.last_click_node = pressed
    end

    
    local event = Event.new(event_type, pressed, {x = x, y = y, button = button})
    Events.emit(event)
end



function Events.handle_mouse_release(root_node, x, y, button)
    if not root_node then return end

    button = button or 1

    local released = Events.hit_test(root_node, x, y)
    if not released then return end

    
    event_manager.pressed_state[tostring(released)] = false

    
    
    if button == 1 and not event_manager._scroll_has_focus_global then
        local event = Event.new(Events.TYPES.CLICK, released, {x = x, y = y})
        Events.emit(event)
    end

    
    local event = Event.new(Events.TYPES.MOUSE_RELEASE, released, {x = x, y = y, button = button})
    Events.emit(event)
end



function Events.handle_scroll(root_node, x, y, dy)
    if not root_node then return end

    local target = Events.hit_test(root_node, x, y)
    if not target then return end

    local event = Event.new(Events.TYPES.SCROLL, target, {x = x, y = y, dy = dy})
    Events.emit(event)
end




function Events.handle_key_pressed(tree, key)
    if not event_manager.focused_node then return end

    local event = Event.new(Events.TYPES.KEY_PRESSED, event_manager.focused_node, {key = key})
    Events.emit(event)
end




function Events.handle_text_input(tree, text)
    if not event_manager.focused_node then return end

    local event = Event.new(Events.TYPES.TEXT_INPUT, event_manager.focused_node, {text = text})
    Events.emit(event)
end





function Events.hit_test(node, x, y)
    if not node or not node._styles then return nil end

    local styles = node._styles
    if styles:get('visible') == false then return nil end

    
    local nx, ny = node._x or 0, node._y or 0
    local nw, nh = node._width or 0, node._height or 0

    if x < nx or x > nx + nw or y < ny or y > ny + nh then
        return nil
    end

    
    if node._children and #node._children > 0 then
        
        local scroll_offset_y = node._scroll_offset or 0
        local scroll_offset_x = 0

        
        if node._scroll_axis == 'horizontal' then
            scroll_offset_x = node._scroll_offset or 0
            scroll_offset_y = 0
        end

        local adjusted_y = y + scroll_offset_y
        local adjusted_x = x + scroll_offset_x

        for i = #node._children, 1, -1 do
            local child = node._children[i]
            local result = Events.hit_test(child, adjusted_x, adjusted_y)
            if result then
                return result
            end
        end
    end

    
    local is_interactive = styles:get('interactive')
    local node_id = tostring(node)
    local has_listeners = event_manager.listeners[node_id] ~= nil

    if is_interactive or has_listeners or node._type == 'button' then
        return node
    end

    
    return nil
end



function Events.reset_hover_and_press()
    
    if event_manager.hover_node then
        local old_id = tostring(event_manager.hover_node)
        event_manager.hover_state[old_id] = false
        local event = Event.new(Events.TYPES.MOUSE_LEAVE, event_manager.hover_node, {})
        Events.emit(event)
        event_manager.hover_node = nil
    end
    for node_id, _ in pairs(event_manager.pressed_state) do
        event_manager.pressed_state[node_id] = false
    end
    
    event_manager._scroll_has_focus_global = true
end


function Events.reset_scroll_focus()
    event_manager._scroll_has_focus_global = false
end



local function update_hover_states(tree, new_hovered)
    local old_hovered = event_manager.hover_node
    local new_hovered_id = new_hovered and tostring(new_hovered) or nil

    
    if old_hovered == new_hovered then return end

    
    if old_hovered then
        local old_id = tostring(old_hovered)
        event_manager.hover_state[old_id] = false
        local event = Event.new(Events.TYPES.MOUSE_LEAVE, old_hovered, {})
        Events.emit(event)
    end

    
    if new_hovered then
        event_manager.hover_state[new_hovered_id] = true
        local event = Event.new(Events.TYPES.MOUSE_ENTER, new_hovered, {})
        Events.emit(event)
    end

    
    event_manager.hover_node = new_hovered
end

Events.update_hover_states = update_hover_states



function Events.focus(node)
    if event_manager.focused_node and event_manager.focused_node ~= node then
        local blur_event = Event.new(Events.TYPES.FOCUS_LOST, event_manager.focused_node, {})
        Events.emit(blur_event)
    end

    event_manager.focused_node = node

    if node then
        local focus_event = Event.new(Events.TYPES.FOCUS_GAINED, node, {})
        Events.emit(focus_event)
    end
end


function Events.get_focused()
    return event_manager.focused_node
end


function Events.blur()
    Events.focus(nil)
end



function Events.is_hovered(node)
    return event_manager.hover_state[tostring(node)] or false
end


function Events.is_pressed(node)
    return event_manager.pressed_state[tostring(node)] or false
end


function Events.reset()
    event_manager.listeners = {}
    event_manager.hover_state = {}
    event_manager.hover_node = nil
    event_manager.pressed_state = {}
    event_manager.focused_node = nil
    event_manager.last_click_time = 0
    event_manager.last_click_node = nil
end

return Events
