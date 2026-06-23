local Node = require('ui.node')
local Styles = require('ui.styles')

local Elements = {}

local function save_scissor_rect()
    local sx, sy, sw, sh = love.graphics.getScissor()
    if sx == nil then
        return nil
    end
    return {sx, sy, sw, sh}
end

local function restore_scissor_rect(scissor_rect)
    if scissor_rect then
        love.graphics.setScissor(
            scissor_rect[1],
            scissor_rect[2],
            scissor_rect[3],
            scissor_rect[4]
        )
    else
        love.graphics.setScissor()
    end
end

local function load_image_source(source)
    if not source then
        return nil, nil
    end

    if type(source) == 'string' then
        local ok, img = pcall(function()
            return love.graphics.newImage(source)
        end)
        if ok and img then
            return img, source
        end
        return nil, source
    end

    if type(source) == 'userdata' or type(source) == 'table' then
        local ok, is_drawable = pcall(function()
            return source:typeOf('Texture') or source:typeOf('Drawable')
        end)
        if ok and is_drawable then
            return source, nil
        end
    end

    return nil, nil
end

local function ensure_node_image(node)
    if node._image then
        local ok = pcall(function()
            node._image:getWidth()
        end)
        if ok then
            return node._image
        end
    end

    if node._image_path then
        local img = load_image_source(node._image_path)
        node._image = img
        return img
    end

    return node._image
end

local function copy_value(value)
    if type(value) ~= 'table' then
        return value
    end

    local result = {}
    for k, v in pairs(value) do
        result[k] = copy_value(v)
    end
    return result
end

local function merge_props(base, extra)
    local result = {}

    if base then
        for k, v in pairs(base) do
            result[k] = copy_value(v)
        end
    end

    if extra then
        for k, v in pairs(extra) do
            result[k] = copy_value(v)
        end
    end

    return result
end

local function themed_node(node_type, theme_name, defaults, props)
    local node = Node.new(node_type)
    node:bind_theme(theme_name, defaults)
    if defaults and defaults.text ~= nil then
        node:text(defaults.text)
    end
    node:apply(props)
    return node
end





function Elements.container(props)
    return themed_node('container', 'container', {
        transition_duration = 0.12,
    }, props)
end



function Elements.text(text, props)
    return themed_node('text', 'text', {
        text = text,
    }, props)
end





function Elements.heading(text, level)
    level = level or 1

    local sizes = {[1] = 32, [2] = 24, [3] = 18}
    local weights = {[1] = 'bold', [2] = 'bold', [3] = 'semi_bold'}

    return themed_node('text', 'heading', {
        text = text,
        font_size = sizes[level] or 32,
        font_weight = weights[level] or 'bold',
    })
end




function Elements.paragraph(text)
    return themed_node('text', 'paragraph', {
        text = text,
        font_size = 14,
        font_weight = 'normal',
        text_wrap = true,
        line_height = 1.5,
    })
end



function Elements.button(text, props)
    props = props or {}

    local node = themed_node('button', 'button', {
        text = text or 'Button',
        background = {60, 60, 60, 255},
        hover_background = {80, 80, 80, 255},
        pressed_background = {40, 40, 40, 255},
        color = {255, 255, 255, 255},
        padding = 12,
        border_radius = 4,
        text_align = 'center',
        transition_duration = 0.12,
    }, props)

    
    node:interactive(true)
    node:cursor('hand')

    return node
end


function Elements.button_small(text, props)
    props = props or {}
    props.padding = props.padding or 8
    props.font_size = props.font_size or 12
    return Elements.button(text, props)
end


function Elements.button_large(text, props)
    props = props or {}
    props.padding = props.padding or 16
    props.font_size = props.font_size or 18
    return Elements.button(text, props)
end


function Elements.icon_button(icon, props)
    props = props or {}
    props.text = icon or '?'
    props.padding = props.padding or 10
    props.font_size = props.font_size or 16
    return Elements.button(nil, props)
end



function Elements.input(placeholder, props)
    local node = themed_node('input', 'input', {
        text = placeholder or '',
        background = {40, 40, 40, 255},
        hover_background = {50, 50, 50, 255},
        color = {200, 200, 200, 255},
        padding = 10,
        border_width = 1,
        border_color = {80, 80, 80, 255},
        border_radius = 4,
        font_size = 14,
        transition_duration = 0.12,
    }, props)
    node:interactive(true)
    node:cursor('ibeam')

    
    node._input_text = ''
    node._input_placeholder = placeholder or ''
    node._input_focused = false
    node._input_cursor_pos = 0

    
    node:on_click(function(event)
        node._input_focused = true
    end)

    return node
end



function Elements.image(path, props)
    props = props or {}

    local node = themed_node('image', 'image', nil, props)

    
    local img, image_path = load_image_source(path)
    node._image_path = image_path

    if img then
        node._image = img
        
        if not props.width then
            node:width(img:getWidth())
        end
        if not props.height then
            node:height(img:getHeight())
        end
    else
        
        node._image = nil
        if not props.width then node:width(100) end
        if not props.height then node:height(100) end
        if not props.background and not Styles.get_theme_style('image') then
            node:background(50, 50, 50)
        end
    end

    
    node._draw_fn = function(x, y, w, h)
        local image = ensure_node_image(node)
        if image then
            local radius = node._styles:get('border_radius') or 0
            local color = node._styles:get('color') or {255, 255, 255, 255}
            
            
            local r, g, b, a = color[1] / 255, color[2] / 255, color[3] / 255, (color[4] or 255) / 255
            
            if radius > 0 then
                
                love.graphics.stencil(function()
                    love.graphics.rectangle('fill', x, y, w, h, radius, radius)
                end, 'replace', 1)
                love.graphics.setStencilTest('greater', 0)
                love.graphics.setColor(r, g, b, a)
                love.graphics.draw(image, x, y, 0,
                    w / image:getWidth(),
                    h / image:getHeight())
                love.graphics.setStencilTest()
            else
                love.graphics.setColor(r, g, b, a)
                love.graphics.draw(image, x, y, 0,
                    w / image:getWidth(),
                    h / image:getHeight())
            end
        end
    end

    return node
end





function Elements.divider(props)
    props = props or {}
    local divider_props = merge_props(props, {
        background = props.background or props.color,
    })

    return themed_node('divider', 'divider', {
        height = 1,
        background = {80, 80, 80, 255},
        margin_top = props.margin or 8,
        margin_bottom = props.margin or 8,
    }, divider_props)
end


function Elements.divider_v(props)
    props = props or {}
    local divider_props = merge_props(props, {
        background = props.background or props.color,
    })

    return themed_node('divider', 'divider_v', {
        width = 1,
        background = {80, 80, 80, 255},
        margin_left = props.margin or 8,
        margin_right = props.margin or 8,
    }, divider_props)
end



function Elements.progress(value, props)
    props = props or {}
    value = math.max(0, math.min(1, value or 0))

    local node = themed_node('progress', 'progress', {
        width = 200,
        height = 8,
        background = {40, 40, 40, 255},
        border_radius = 4,
        progress_color = {80, 150, 255, 255},
    }, props)

    node._progress_value = value
    node._refresh_theme_fn = function(target)
        if target._style_overrides and target._style_overrides.color ~= nil then
            target._progress_color = target:get_style_prop('color')
        else
            target._progress_color = target:get_style_prop('progress_color')
                or {80, 150, 255, 255}
        end
    end
    node._refresh_theme_fn(node)

    
    node._draw_fn = function(x, y, w, h)
        local fill_w = w * node._progress_value
        local r, g, b, a = unpack(node._progress_color)
        love.graphics.setColor(r/255, g/255, b/255, a/255)
        love.graphics.rectangle('fill', x, y, fill_w, h, 4)
        love.graphics.setColor(1, 1, 1, 1)
    end

    return node
end


function Elements.set_progress(node, value)
    if node._type == 'progress' then
        node._progress_value = math.max(0, math.min(1, value))
        node:_mark_dirty()
    end
end




function Elements.checkbox(checked, label, props)
    props = props or {}

    local container = themed_node('checkbox', 'checkbox', {
        checkbox_on_background = {80, 150, 255, 255},
        checkbox_off_background = {50, 50, 50, 255},
        checkbox_border_color = {100, 100, 100, 255},
        checkbox_checkmark_color = {255, 255, 255, 255},
        checkbox_label_color = {220, 220, 220, 255},
        transition_duration = 0.12,
    }, props)
    local on_bg = container:get_style_prop('checkbox_on_background') or {80, 150, 255, 255}
    local off_bg = container:get_style_prop('checkbox_off_background') or {50, 50, 50, 255}
    local border_color = container:get_style_prop('checkbox_border_color') or {100, 100, 100, 255}
    local checkmark_color = container:get_style_prop('checkbox_checkmark_color') or {255, 255, 255, 255}
    container:layout_row()
    container:spacing(8)
    container:align_items('center')
    container:interactive(true)
    container:cursor('hand')

    
    local box = themed_node('checkbox_box', 'checkbox_box', {
        width = 18,
        height = 18,
        background = checked and on_bg or off_bg,
        border_width = 1,
        border_color = border_color,
        border_radius = 3,
    })
    box:align_items('center')
    box:justify_content('center')
    box._checked = checked or false
    container._checkbox_box = box

    
    local checkmark = themed_node('checkmark', 'checkbox_checkmark', {
        text = '✓',
        font_size = 14,
        color = {255, 255, 255, 255},
        visible = checked or false,
        align_self = 'center',
    })
    checkmark:color(checkmark_color)
    checkmark._checked = checked or false
    box:add(checkmark)
    container._checkmark = checkmark

    
    if label then
        local text = themed_node('text', 'checkbox_label', {
            text = label,
            font_size = 14,
            color = {220, 220, 220, 255},
        })
        container._checkbox_label = text
        container:add(box)
        container:add(text)
    else
        container:add(box)
    end

    local function refresh_checkbox_visual()
        local on_bg = container:get_style_prop('checkbox_on_background') or {80, 150, 255, 255}
        local off_bg = container:get_style_prop('checkbox_off_background') or {50, 50, 50, 255}
        local border_color = container:get_style_prop('checkbox_border_color') or {100, 100, 100, 255}
        local checkmark_color = container:get_style_prop('checkbox_checkmark_color') or {255, 255, 255, 255}
        local label_color = container:get_style_prop('checkbox_label_color') or {220, 220, 220, 255}

        box._styles:set('background', box._checked and on_bg or off_bg)
        box._styles:set('border_color', border_color)
        checkmark._styles:set('visible', box._checked)
        checkmark._styles:set('color', checkmark_color)

        if container._checkbox_label then
            container._checkbox_label._styles:set('color', label_color)
        end
    end

    container._refresh_theme_fn = refresh_checkbox_visual
    refresh_checkbox_visual()

    
    container:on_click(function()
        box._checked = not box._checked
        checkmark._checked = box._checked
        refresh_checkbox_visual()

        container:_mark_dirty()
    end)

    return container
end


function Elements.is_checked(node)
    if node._checkbox_box then
        return node._checkbox_box._checked
    end
    return false
end



function Elements.slider(value, props)
    props = props or {}
    value = math.max(0, math.min(1, value or 0.5))

    local container = themed_node('slider', 'slider', {
        width = 200,
        height = 20,
        slider_track_color = {50, 50, 50, 255},
        slider_fill_color = {80, 150, 255, 255},
        slider_thumb_color = {220, 220, 220, 255},
        transition_duration = 0.12,
    }, props)
    container:width(props.width or 200)
    container:height(props.height or 20)
    container:interactive(true)
    container:cursor('hand')
    container:layout_none()  

    container._slider_value = value
    container._slider_dragging = false

    
    local track = themed_node('slider_track', 'slider_track', {
        width = 'full',
        height = 4,
        background = container:get_style_prop('slider_track_color') or {50, 50, 50, 255},
        border_radius = 2,
        position = 'absolute',
    })
    container:add(track)
    container._slider_track = track

    
    local fill = themed_node('slider_fill', 'slider_fill', {
        height = 4,
        background = container:get_style_prop('slider_fill_color') or {80, 150, 255, 255},
        border_radius = 2,
        position = 'absolute',
    })
    container:add(fill)
    container._slider_fill = fill

    
    local thumb = themed_node('slider_thumb', 'slider_thumb', {
        width = 16,
        height = 16,
        background = container:get_style_prop('slider_thumb_color') or {220, 220, 220, 255},
        border_radius = 8,
        position = 'absolute',
    })
    container:add(thumb)
    container._slider_thumb = thumb

    local function refresh_slider_visual()
        track._styles:set('background',
            container:get_style_prop('slider_track_color') or {50, 50, 50, 255})
        fill._styles:set('background',
            container:get_style_prop('slider_fill_color') or {80, 150, 255, 255})
        thumb._styles:set('background',
            container:get_style_prop('slider_thumb_color') or {220, 220, 220, 255})
    end

    container._refresh_theme_fn = refresh_slider_visual
    refresh_slider_visual()

    
    local function update_slider()
        local cx = container._x or 0
        local cy = container._y or 0
        local w = container._width or 200
        local h = container._height or 20

        
        track._x = cx
        track._y = cy + (h - 4) / 2
        track._width = w

        
        local fill_w = w * container._slider_value
        fill._x = cx
        fill._y = cy + (h - 4) / 2
        fill._width = fill_w

        
        thumb._x = cx + fill_w - 8
        thumb._y = cy + (h - 16) / 2

        if props.on_value_change then
            props.on_value_change(container._slider_value)
        end
    end

    container._slider_update = update_slider

    container:on_press(function(event)
        container._slider_dragging = true
        local w = container._width or 200
        container._slider_value = math.max(0, math.min(1, (event.data.x - container._x) / w))
        update_slider()
        container:_mark_dirty()
    end)

    container:on_release(function()
        container._slider_dragging = false
    end)

    return container
end


function Elements.get_slider_value(node)
    return node._slider_value or 0
end


function Elements.set_slider_value(node, value)
    node._slider_value = math.max(0, math.min(1, value))
    if node._slider_update then
        node._slider_update()
    end
    node:_mark_dirty()
end





function Elements.scroll_view(props)
    props = props or {}

    local node = themed_node('scroll_view', 'scroll_view', nil, props)
    node:overflow('hidden')
    node:clip(true)

    node._scroll_offset = 0
    node._scroll_max = 0
    node._scroll_dragging = false
    node._scroll_drag_start_x = 0
    node._scroll_drag_start_y = 0
    node._scroll_drag_start_offset = 0
    node._scroll_has_focus = false
    node._scrollbar_dragging = false
    node._scrollbar_drag_grab_offset = nil
    node._scroll_axis = 'vertical'  

    
    node._scroll_velocity = 0
    node._scroll_inertia = false
    node._scroll_history = {}  

    node:on_scroll(function(event)
        node._scroll_offset = math.max(0, math.min(node._scroll_max,
            node._scroll_offset - event.data.dy * 30))
        node:_mark_dirty()
    end)

    node:on_press(function(event)
        node._scroll_dragging = true
        node._scroll_drag_start_x = event.data.x
        node._scroll_drag_start_y = event.data.y
        node._scroll_drag_start_offset = node._scroll_offset
        node._scroll_inertia = false
        node._scroll_velocity = 0
        node._scroll_history = {}
    end)

    node:on_release(function()
        node._scroll_dragging = false
        node._scroll_has_focus = false

        
        if #node._scroll_history >= 2 then
            local last = node._scroll_history[#node._scroll_history]
            local first = node._scroll_history[1]
            local dt = last.t - first.t
            if dt > 0.01 then
                local axis = node._scroll_axis or 'vertical'
                local delta = axis == 'horizontal'
                    and (last.x - first.x)
                    or (last.y - first.y)
                node._scroll_velocity = delta / dt
                node._scroll_inertia = true
            end
        end
    end)

    
    node._draw_fn = function(x, y, w, h)
        local radius = node._styles:get('border_radius') or 0
        if radius > 0 then
            
            
            local old_scissor = save_scissor_rect()
            love.graphics.stencil(function()
                love.graphics.rectangle('fill', x, y, w, h, radius, radius)
            end, 'replace', 1)
            love.graphics.setStencilTest('greater', 0)
            
            if old_scissor then
                restore_scissor_rect(old_scissor)
            end
        else
            
            node._scroll_old_scissor = save_scissor_rect()
            
            local screen_x, screen_y = x, y
            local screen_w, screen_h = w, h
            if love.graphics.transformPoint then
                screen_x, screen_y = love.graphics.transformPoint(x, y)
                local screen_x2, screen_y2 = love.graphics.transformPoint(x + w, y + h)
                screen_w = screen_x2 - screen_x
                screen_h = screen_y2 - screen_y
            end
            love.graphics.intersectScissor(screen_x, screen_y, screen_w, screen_h)
        end
    end

    
    node._post_draw_fn = function(x, y, w, h)
        local radius = node._styles:get('border_radius') or 0
        if radius > 0 then
            love.graphics.setStencilTest()
        else
            
            local old = node._scroll_old_scissor
            if old then
                restore_scissor_rect(old)
            else
                love.graphics.setScissor()
            end
        end
    end

    return node
end





function Elements.card(props)
    props = props or {}

    return themed_node('card', 'card', {
        background = {45, 45, 45, 255},
        border_radius = 8,
        padding = 16,
        layout = 'column',
        spacing = 8,
    }, props)
end



function Elements.badge(text, props)
    props = props or {}

    return themed_node('badge', 'badge', {
        text = text,
        font_size = 11,
        font_weight = 'bold',
        color = {255, 255, 255, 255},
        background = {80, 150, 255, 255},
        padding = 4,
        border_radius = 10,
        text_align = 'center',
    }, props)
end





function Elements.spacer(size)
    return themed_node('spacer', 'spacer', {
        width = size,
        height = size,
        flex = 1,
        spring = true,  
    })
end




function Elements.toggle(enabled, label, props)
    props = props or {}

    local container = themed_node('toggle', 'toggle', {
        toggle_on_background = {80, 150, 255, 255},
        toggle_off_background = {80, 80, 80, 255},
        toggle_knob_on_color = {255, 255, 255, 255},
        toggle_knob_off_color = {200, 200, 200, 255},
        toggle_label_color = {220, 220, 220, 255},
        transition_duration = 0.12,
    }, props)
    container:layout_row()
    container:spacing(10)
    container:align_items('center')
    container:interactive(true)
    container:cursor('hand')

    
    local switch = themed_node('toggle_switch', 'toggle_switch', {
        width = 44,
        height = 24,
        border_radius = 12,
        transition_duration = container:get_style_prop('transition_duration') or 0.12,
    })
    switch._enabled = enabled or false
    container._toggle_switch = switch

    
    local knob = themed_node('toggle_knob', 'toggle_knob', {
        width = 18,
        height = 18,
        border_radius = 9,
        transition_duration = container:get_style_prop('transition_duration') or 0.12,
    })
    knob._enabled = enabled or false
    knob._toggle_knob_offset = enabled and 23 or 3
    knob._toggle_target_offset = knob._toggle_knob_offset
    container._toggle_knob = knob

    
    local function update_visual()
        local on_bg = container:get_style_prop('toggle_on_background') or {80, 150, 255, 255}
        local off_bg = container:get_style_prop('toggle_off_background') or {80, 80, 80, 255}
        local knob_on = container:get_style_prop('toggle_knob_on_color') or {255, 255, 255, 255}
        local knob_off = container:get_style_prop('toggle_knob_off_color') or {200, 200, 200, 255}
        local label_color = container:get_style_prop('toggle_label_color') or {220, 220, 220, 255}

        if switch._enabled then
            switch._styles:set('background', on_bg)
            knob._styles:set('background', knob_on)
            knob._toggle_target_offset = 23
        else
            switch._styles:set('background', off_bg)
            knob._styles:set('background', knob_off)
            knob._toggle_target_offset = 3
        end

        if container._toggle_label then
            container._toggle_label._styles:set('color', label_color)
        end

        container:_mark_dirty()
    end

    
    switch._draw_fn = function(x, y, w, h, opacity)
        
        local kx = x + knob._toggle_knob_offset
        local ky = y + 3
        local kr = 9
        local knob_color = knob._anim_background or knob._styles:get('background') or {255, 255, 255, 255}
        local r = (knob_color[1] or 255) / 255
        local g = (knob_color[2] or 255) / 255
        local b = (knob_color[3] or 255) / 255
        local a = ((knob_color[4] or 255) / 255) * (opacity or 1)

        love.graphics.setColor(r, g, b, a)
        love.graphics.circle('fill', kx + kr, ky + kr, kr)
    end

    
    update_visual()

    
    container:on_click(function()
        switch._enabled = not switch._enabled
        knob._enabled = switch._enabled
        update_visual()

        
        if container._toggle_callback then
            container._toggle_callback(switch._enabled)
        end
    end)

    container:add(switch)

    
    if label then
        local text = themed_node('text', 'toggle_label', {
            text = label,
            font_size = 14,
            color = {220, 220, 220, 255},
        })
        container._toggle_label = text
        container:add(text)
    end

    container._refresh_theme_fn = update_visual
    update_visual()

    return container
end


function Elements.is_toggle_on(node)
    if node._toggle_switch then
        return node._toggle_switch._enabled
    end
    return false
end


function Elements.on_toggle_change(node, callback)
    node._toggle_callback = callback
    return node
end





function Elements.spring(props)
    props = props or {}
    props.spring = true
    props.flex = 1
    
    local node = themed_node('spring', 'spring', nil, props)
    return node
end





function Elements.h_spacer(width, props)
    props = props or {}
    props.spring = true
    props.flex = 1
    props.width = width or 0
    props.min_width = width or 0
    
    local node = themed_node('h_spacer', 'h_spacer', nil, props)
    return node
end





function Elements.v_spacer(height, props)
    props = props or {}
    props.spring = true
    props.flex = 1
    props.height = height or 0
    props.min_height = height or 0
    
    local node = themed_node('v_spacer', 'v_spacer', nil, props)
    return node
end





local function normalize_dropdown_option(option, index)
    if type(option) == 'table' then
        local label = option.label or option.text or option.value
        if label == nil then
            label = tostring(index)
        end
        return {
            label = tostring(label),
            value = option.value ~= nil and option.value or label,
        }
    end

    return {
        label = tostring(option),
        value = option,
    }
end

local function normalize_tab_item(item, index)
    if type(item) == 'table' then
        local label = item.label or item.title or item.text or tostring(index)
        local content = item.content or item.node or item.body
        if content == nil then
            content = Elements.text(label)
        elseif type(content) ~= 'table' or getmetatable(content) == nil then
            content = Elements.text(tostring(content))
        end

        return {
            label = tostring(label),
            content = content,
        }
    end

    local label = tostring(item)
    return {
        label = label,
        content = Elements.text(label),
    }
end

function Elements.modal(content, props)
    props = props or {}

    local close_on_backdrop = props.close_on_backdrop ~= false
    local on_close = props.on_close
    local panel_props = merge_props({
        width = props.panel_width or 420,
        max_width = props.panel_max_width or 720,
        background = props.panel_background or {35, 35, 45, 255},
        border_radius = props.panel_border_radius or 16,
        padding = props.panel_padding or 20,
        layout = 'column',
        gap = props.panel_gap or 12,
        box_shadow_color = props.panel_shadow_color or {0, 0, 0, 120},
        box_shadow_offset_x = props.panel_shadow_offset_x or 0,
        box_shadow_offset_y = props.panel_shadow_offset_y or 12,
        box_shadow_blur = props.panel_shadow_blur or 26,
        box_shadow_spread = props.panel_shadow_spread or 0,
        transition_duration = props.transition_duration or 0.12,
    }, props.panel_props)

    local overlay_props = {}
    for key, value in pairs(props) do
        if key ~= 'panel_props'
            and key ~= 'panel_width'
            and key ~= 'panel_max_width'
            and key ~= 'panel_background'
            and key ~= 'panel_border_radius'
            and key ~= 'panel_padding'
            and key ~= 'panel_gap'
            and key ~= 'panel_shadow_color'
            and key ~= 'panel_shadow_offset_x'
            and key ~= 'panel_shadow_offset_y'
            and key ~= 'panel_shadow_blur'
            and key ~= 'panel_shadow_spread'
            and key ~= 'close_on_backdrop'
            and key ~= 'on_close' then
            overlay_props[key] = copy_value(value)
        end
    end

    local overlay = themed_node('modal', 'modal', {
        width = 'full',
        height = 'full',
        position = 'absolute',
        left = 0,
        top = 0,
        background = {0, 0, 0, 160},
        padding = 24,
        layout = 'column',
        justify_content = 'center',
        align_items = 'center',
        visible = false,
        interactive = true,
        transition_duration = 0.12,
    }, overlay_props)

    local panel = themed_node('modal_panel', 'modal_panel', panel_props)
    panel:layout_column()
    panel:interactive(true)
    panel:on_click(function(event)
        event:stop_propagation()
    end)

    if content then
        panel:add(content)
    end

    overlay:add(panel)
    overlay._modal_panel = panel
    overlay._modal_on_close = on_close
    overlay._modal_close_on_backdrop = close_on_backdrop

    function overlay:get_modal_panel()
        return self._modal_panel
    end

    function overlay:set_modal_content(node)
        self._modal_panel:clear()
        if node then
            self._modal_panel:add(node)
        end
        self:_mark_dirty()
        return self
    end

    function overlay:open_modal()
        self:show()
        self:_mark_dirty()
        return self
    end

    function overlay:close_modal()
        self:hide()
        self:_mark_dirty()
        if self._modal_on_close then
            self._modal_on_close(self)
        end
        return self
    end

    overlay:on_click(function(event)
        if overlay._modal_close_on_backdrop then
            overlay:close_modal()
        end
        event:stop_propagation()
    end)

    return overlay
end

function Elements.dropdown(options, selected, props)
    if type(selected) == 'table' and props == nil then
        props = selected
        selected = nil
    end
    props = props or {}

    local button_props = merge_props({
        width = 'full',
        background = props.button_background or {45, 45, 55, 255},
        hover_background = props.button_hover_background or {60, 60, 70, 255},
        pressed_background = props.button_pressed_background or {35, 35, 45, 255},
        border_radius = props.button_border_radius or 10,
        padding = props.button_padding or 10,
        layout = 'row',
        align_items = 'center',
        gap = props.button_gap or 8,
        transition_duration = props.transition_duration or 0.12,
    }, props.button_props)

    local menu_props = merge_props({
        width = 'full',
        background = props.menu_background or {35, 35, 45, 255},
        border_radius = props.menu_border_radius or 12,
        padding = props.menu_padding or 6,
        layout = 'column',
        gap = props.menu_gap or 4,
        visible = false,
        box_shadow_color = props.menu_shadow_color or {0, 0, 0, 90},
        box_shadow_offset_x = props.menu_shadow_offset_x or 0,
        box_shadow_offset_y = props.menu_shadow_offset_y or 8,
        box_shadow_blur = props.menu_shadow_blur or 20,
        box_shadow_spread = props.menu_shadow_spread or 0,
        transition_duration = props.transition_duration or 0.12,
    }, props.menu_props)

    local item_props = merge_props({
        width = 'full',
        padding = props.item_padding or 10,
        border_radius = props.item_border_radius or 8,
        background = props.item_background,
        hover_background = props.item_hover_background or {255, 255, 255, 24},
        pressed_background = props.item_pressed_background or {255, 255, 255, 40},
        color = props.item_color or {230, 230, 240, 255},
        text_wrap = false,
        text_overflow = 'ellipsis',
        transition_duration = props.transition_duration or 0.12,
    }, props.item_props)

    local container = themed_node('dropdown', 'dropdown', {
        width = props.width or 220,
        layout = 'column',
        gap = props.gap or 6,
    }, props.container_props)

    local button = themed_node('dropdown_button', 'dropdown_button', button_props)
    button:layout_row()
    button:align_items('center')
    button:interactive(true)
    button:cursor('hand')

    local selected_label = themed_node('text', 'dropdown_label', {
        text = '',
        font_size = props.font_size or 14,
        color = props.button_color or {240, 240, 245, 255},
        text_wrap = false,
        text_overflow = 'ellipsis',
        flex = 1,
        width = 'full',
    }, props.label_props)

    local arrow = themed_node('text', 'dropdown_arrow', {
        text = 'v',
        font_size = props.arrow_font_size or props.font_size or 14,
        color = props.arrow_color or props.button_color or {240, 240, 245, 255},
        transition_duration = props.transition_duration or 0.12,
    }, props.arrow_props)

    button:add(selected_label)
    button:add(arrow)

    local menu = themed_node('dropdown_menu', 'dropdown_menu', menu_props)
    menu:layout_column()

    container:add(button)
    container:add(menu)

    container._dropdown_button = button
    container._dropdown_label = selected_label
    container._dropdown_arrow = arrow
    container._dropdown_menu = menu
    container._dropdown_options = {}
    container._dropdown_selected_index = nil
    container._dropdown_selected_value = nil
    container._dropdown_on_change = props.on_change

    function container:is_dropdown_open()
        return self._dropdown_menu._styles:get('visible') ~= false
    end

    function container:open_dropdown()
        self._dropdown_menu:show()
        self._dropdown_arrow:text('^')
        self:_mark_dirty()
        return self
    end

    function container:close_dropdown()
        self._dropdown_menu:hide()
        self._dropdown_arrow:text('v')
        self:_mark_dirty()
        return self
    end

    function container:toggle_dropdown()
        if self:is_dropdown_open() then
            return self:close_dropdown()
        end
        return self:open_dropdown()
    end

    function container:get_dropdown_value()
        return self._dropdown_selected_value
    end

    function container:get_dropdown_label()
        return self._dropdown_label._text
    end

    function container:set_dropdown_selected(value)
        local selected_index = nil

        if type(value) == 'number' then
            selected_index = value
        else
            for index, option in ipairs(self._dropdown_options) do
                if option.value == value or option.label == value then
                    selected_index = index
                    break
                end
            end
        end

        local option = self._dropdown_options[selected_index]
        if not option then
            option = {label = props.placeholder or '', value = nil}
            selected_index = nil
        end

        self._dropdown_selected_index = selected_index
        self._dropdown_selected_value = option.value
        self._dropdown_label:text(option.label)
        self:_mark_dirty()
        return self
    end

    function container:on_dropdown_change(callback)
        self._dropdown_on_change = callback
        return self
    end

    function container:set_dropdown_options(next_options, next_selected)
        self._dropdown_options = {}
        self._dropdown_menu:clear()

        for index, option in ipairs(next_options or {}) do
            local option_index = index
            local normalized = normalize_dropdown_option(option, index)
            table.insert(self._dropdown_options, normalized)

            local item = themed_node('dropdown_item', 'dropdown_item', item_props)
            item:text(normalized.label)
            item:interactive(true)
            item:cursor('hand')
            item:on_click(function(event)
                event:stop_propagation()
                container:set_dropdown_selected(option_index)
                container:close_dropdown()
                if container._dropdown_on_change then
                    container._dropdown_on_change(
                        container._dropdown_selected_value,
                        container._dropdown_label._text,
                        option_index,
                        container
                    )
                end
            end)

            self._dropdown_menu:add(item)
        end

        if next_selected ~= nil then
            self:set_dropdown_selected(next_selected)
        elseif self._dropdown_selected_index ~= nil then
            self:set_dropdown_selected(self._dropdown_selected_index)
        elseif #self._dropdown_options > 0 then
            self:set_dropdown_selected(1)
        else
            self:set_dropdown_selected(nil)
        end

        self:_mark_dirty()
        return self
    end

    button:on_click(function(event)
        event:stop_propagation()
        container:toggle_dropdown()
    end)

    container:set_dropdown_options(options, selected)

    return container
end




function Elements.tabs(items, active_index, props)
    props = props or {}

    local container = themed_node('tabs', 'tabs', {
        width = props.width or 'full',
        layout = 'column',
        gap = props.gap or 8,
    }, props.container_props)

    local tabs_bar = themed_node('tabs_bar', 'tabs_bar', {
        width = 'full',
        layout = 'row',
        gap = props.tab_gap or 6,
        background = props.tabs_bar_background,
        border_radius = props.tabs_bar_radius or 0,
        padding = props.tabs_bar_padding or 0,
    }, props.tabs_bar_props)

    local tabs_content = themed_node('tabs_content', 'tabs_content', {
        width = 'full',
        flex = 1,
        layout = 'column',
        background = props.content_background,
        border_radius = props.content_border_radius or 0,
        padding = props.content_padding or 0,
    }, props.content_props)

    local tab_button_base = merge_props({
        padding = props.tab_padding or 10,
        border_radius = props.tab_border_radius or 10,
        background = props.tab_background or {40, 40, 48, 255},
        hover_background = props.tab_hover_background or {54, 54, 64, 255},
        pressed_background = props.tab_pressed_background or {32, 32, 40, 255},
        color = props.tab_color or {200, 200, 210, 255},
        text_wrap = false,
        text_overflow = 'ellipsis',
        transition_duration = props.transition_duration or 0.12,
    }, props.tab_props)

    container:add(tabs_bar)
    container:add(tabs_content)

    container._tabs_bar = tabs_bar
    container._tabs_content = tabs_content
    container._tabs_buttons = {}
    container._tabs_pages = {}
    container._tabs_items = {}
    container._tabs_active_index = nil
    container._tabs_on_change = props.on_change

    local function refresh_tabs_visual()
        local active_bg = container:get_style_prop('active_tab_background')
            or props.active_tab_background
            or {80, 150, 255, 255}
        local inactive_bg = container:get_style_prop('tab_background')
            or props.tab_background
            or tab_button_base.background
            or {40, 40, 48, 255}
        local active_color = container:get_style_prop('active_tab_color')
            or props.active_tab_color
            or {255, 255, 255, 255}
        local inactive_color = container:get_style_prop('tab_color')
            or props.tab_color
            or tab_button_base.color
            or {200, 200, 210, 255}

        for index, button in ipairs(container._tabs_buttons) do
            local is_active = index == container._tabs_active_index
            button._styles:set('background', is_active and active_bg or inactive_bg)
            if button._tab_label_node then
                button._tab_label_node._styles:set('color', is_active and active_color or inactive_color)
            end
        end

        for index, page in ipairs(container._tabs_pages) do
            page:visible(index == container._tabs_active_index)
        end

        container:_mark_dirty()
    end

    function container:get_active_tab_index()
        return self._tabs_active_index
    end

    function container:get_active_tab()
        local tab = self._tabs_items[self._tabs_active_index]
        return tab and tab.content or nil
    end

    function container:on_tab_change(callback)
        self._tabs_on_change = callback
        return self
    end

    function container:set_active_tab(index)
        if not self._tabs_items[index] then
            return self
        end

        self._tabs_active_index = index
        refresh_tabs_visual()

        if self._tabs_on_change then
            local tab = self._tabs_items[index]
            self._tabs_on_change(index, tab.label, tab.content, self)
        end

        return self
    end

    function container:set_tabs(next_items, next_active_index)
        self._tabs_items = {}
        self._tabs_buttons = {}
        self._tabs_pages = {}
        self._tabs_bar:clear()
        self._tabs_content:clear()

        for index, item in ipairs(next_items or {}) do
            local tab_index = index
            local tab_item = normalize_tab_item(item, index)
            table.insert(self._tabs_items, tab_item)

            local tab_button = themed_node('tab_button', 'tab_button', tab_button_base)
            tab_button:layout_row()
            tab_button:align_items('center')
            tab_button:interactive(true)
            tab_button:cursor('hand')

            local tab_label = themed_node('text', 'tab_label', {
                text = tab_item.label,
                font_size = props.tab_font_size or 14,
                color = props.tab_color or {200, 200, 210, 255},
                text_wrap = false,
                text_overflow = 'ellipsis',
            }, props.tab_label_props)

            tab_button._tab_label_node = tab_label
            tab_button:add(tab_label)
            tab_button:on_click(function(event)
                event:stop_propagation()
                container:set_active_tab(tab_index)
            end)

            local page = themed_node('tab_page', 'tab_page', {
                width = 'full',
                flex = 1,
                layout = 'column',
                visible = false,
            }, props.page_props)
            page:add(tab_item.content)

            self._tabs_bar:add(tab_button)
            self._tabs_content:add(page)
            table.insert(self._tabs_buttons, tab_button)
            table.insert(self._tabs_pages, page)
        end

        local resolved_index = next_active_index or self._tabs_active_index or 1
        if not self._tabs_items[resolved_index] then
            resolved_index = #self._tabs_items > 0 and 1 or nil
        end
        self._tabs_active_index = resolved_index
        refresh_tabs_visual()
        return self
    end

    container._refresh_theme_fn = refresh_tabs_visual
    container:set_tabs(items, active_index)

    return container
end

function Elements.splitter(first, second, props)
    props = props or {}

    local orientation = props.orientation or 'horizontal'
    local is_horizontal = orientation ~= 'vertical'
    local handle_size = props.handle_size or 8
    local initial_size = props.initial_size or 220
    local min_size = props.min_size or 80
    local max_size = props.max_size or 100000
    local second_min_size = props.second_min_size or 0

    local container = themed_node('splitter', 'splitter', {
        width = props.width or 'full',
        height = props.height or 'full',
        layout = is_horizontal and 'row' or 'column',
        gap = 0,
    }, props.container_props)

    local first_pane = themed_node('splitter_pane', 'splitter_pane', {
        layout = 'column',
        width = is_horizontal and initial_size or 'full',
        height = is_horizontal and 'full' or initial_size,
        min_width = is_horizontal and min_size or 0,
        min_height = is_horizontal and 0 or min_size,
    }, props.first_pane_props)

    local second_pane = themed_node('splitter_pane', 'splitter_pane', {
        layout = 'column',
        flex = 1,
        width = is_horizontal and nil or 'full',
        height = is_horizontal and 'full' or nil,
        min_width = is_horizontal and second_min_size or 0,
        min_height = is_horizontal and 0 or second_min_size,
    }, props.second_pane_props)

    local handle = themed_node('splitter_handle', 'splitter_handle', {
        width = is_horizontal and handle_size or 'full',
        height = is_horizontal and 'full' or handle_size,
        background = props.handle_background or {70, 70, 80, 255},
        hover_background = props.handle_hover_background or {90, 90, 105, 255},
        pressed_background = props.handle_pressed_background or {110, 110, 130, 255},
        border_radius = props.handle_border_radius or 0,
        transition_duration = props.transition_duration or 0.12,
    }, props.handle_props)
    handle:interactive(true)
    handle:cursor(is_horizontal and 'sizewe' or 'sizens')

    if first then
        first_pane:add(first)
    end
    if second then
        second_pane:add(second)
    end

    container:add(first_pane)
    container:add(handle)
    container:add(second_pane)

    container._splitter_orientation = orientation
    container._splitter_is_horizontal = is_horizontal
    container._splitter_handle_size = handle_size
    container._splitter_min_size = min_size
    container._splitter_max_size = max_size
    container._splitter_second_min_size = second_min_size
    container._splitter_size = initial_size
    container._splitter_first_pane = first_pane
    container._splitter_second_pane = second_pane
    container._splitter_handle = handle
    container._splitter_on_change = props.on_change
    container._splitter_dragging = false

    handle._splitter_dragging = false
    handle._splitter_owner = container

    local function apply_split_size(size, notify)
        local available = is_horizontal and (container._width or 0) or (container._height or 0)
        local hard_max = max_size
        if available > 0 then
            hard_max = math.min(
                max_size,
                math.max(min_size, available - handle_size - second_min_size)
            )
        end
        local next_size = math.max(min_size, math.min(size or initial_size, hard_max))

        container._splitter_size = next_size
        if is_horizontal then
            first_pane:width(next_size)
        else
            first_pane:height(next_size)
        end

        if notify and container._splitter_on_change then
            container._splitter_on_change(next_size, container)
        end
    end

    function container:set_split_size(size)
        apply_split_size(size, true)
        return self
    end

    function container:get_split_size()
        return self._splitter_size
    end

    function container:get_first_pane()
        return self._splitter_first_pane
    end

    function container:get_second_pane()
        return self._splitter_second_pane
    end

    function container:on_splitter_change(callback)
        self._splitter_on_change = callback
        return self
    end

    handle:on_press(function(event)
        event:stop_propagation()
        handle._splitter_dragging = true
        container._splitter_dragging = true
        container._splitter_drag_start_x = event.data.x or 0
        container._splitter_drag_start_y = event.data.y or 0
        container._splitter_drag_start_size = container._splitter_size or initial_size
    end)

    handle:on_release(function(event)
        if event then
            event:stop_propagation()
        end
        handle._splitter_dragging = false
        container._splitter_dragging = false
    end)

    container._splitter_apply_size = apply_split_size
    container._refresh_theme_fn = function()
        apply_split_size(container._splitter_size or initial_size, false)
    end
    apply_split_size(initial_size, false)

    return container
end

function Elements.custom(draw_fn, measure_fn, props)
    props = props or {}

    local node = themed_node('custom', 'custom', nil, props)

    if draw_fn then
        node._draw_fn = function(x, y, w, h)
            draw_fn(x, y, w, h, node)
        end
    end

    if measure_fn then
        node._measure_fn = function()
            return measure_fn(node)
        end
    end

    return node
end





return Elements
