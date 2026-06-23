
local Node = require('ui.node')
local Layout = require('ui.layout')
local Events = require('ui.events')
local Fonts = require('ui.fonts')

local Tree = {}
Tree.__index = Tree
Tree.all_trees = setmetatable({}, { __mode = "k" })

local ANIMATION_COLOR_EPSILON = 0.5
local ANIMATION_NUMBER_EPSILON = 0.001

local function copy_draw_color(color)
    if not color or #color < 3 then
        return {0, 0, 0, 0}
    end

    return {
        color[1] or 0,
        color[2] or 0,
        color[3] or 0,
        color[4] or 255,
    }
end

local function get_target_background_color(node, styles)
    local bg = styles:get_background_for_state('normal')

    if Events.is_hovered(node) then
        bg = styles:get_background_for_state('hover') or bg
    end
    if Events.is_pressed(node) then
        bg = styles:get_background_for_state('pressed') or bg
    end

    return bg
end

local function animate_channel(current, target, alpha, epsilon)
    local next_value = current + (target - current) * alpha
    if math.abs(target - next_value) <= epsilon then
        return target, false
    end
    return next_value, true
end

local function animate_color_state(node, field_name, target_color, alpha)
    target_color = copy_draw_color(target_color)

    local current_color = node[field_name]
    if not current_color then
        node[field_name] = copy_draw_color(target_color)
        return false
    end

    local active = false
    for i = 1, 4 do
        local channel_active
        current_color[i], channel_active = animate_channel(
            current_color[i] or 0,
            target_color[i] or 0,
            alpha,
            ANIMATION_COLOR_EPSILON
        )
        if channel_active then
            active = true
        end
    end

    return active
end

local function animate_number_state(node, field_name, target_value, alpha)
    target_value = target_value or 0

    if node[field_name] == nil then
        node[field_name] = target_value
        return false
    end

    local next_value, active = animate_channel(
        node[field_name],
        target_value,
        alpha,
        ANIMATION_NUMBER_EPSILON
    )
    node[field_name] = next_value
    return active
end





function Tree.new(root)
    local self = setmetatable({}, Tree)
    Tree.all_trees[self] = true

    self._root = root
    self._screen_w = love.graphics.getWidth()
    self._screen_h = love.graphics.getHeight()
    self._camera_x = 0
    self._camera_y = 0
    self._debug_mode = false
    self._tooltip_node = nil
    self._tooltip_text = nil
    self._cursor_name = 'arrow'
    self._cursor_cache = {}

    
    self._batch = nil

    
    self._fonts_dirty = true  
    self._has_scroll_inertia = false  

    return self
end


function Tree:set_root(root)
    self._root = root
    self._fonts_dirty = true
    self:rebuild()
    return self
end


function Tree:get_root()
    return self._root
end

function Tree:_set_cursor(cursor_name)
    cursor_name = cursor_name or 'arrow'
    if self._cursor_name == cursor_name then
        return
    end

    local cursor = self._cursor_cache[cursor_name]
    if cursor == nil then
        local ok, system_cursor = pcall(love.mouse.getSystemCursor, cursor_name)
        cursor = ok and system_cursor or false
        self._cursor_cache[cursor_name] = cursor
    end

    if cursor then
        love.mouse.setCursor(cursor)
        self._cursor_name = cursor_name
    elseif cursor_name ~= 'arrow' then
        self:_set_cursor('arrow')
    end
end



function Tree:rebuild()
    if not self._root then return end

    
    self._root:refresh_theme_styles()
    self._fonts_dirty = false

    
    Layout.compute(
        self._root,
        self._camera_x,
        self._camera_y,
        self._screen_w,
        self._screen_h
    )

    
    self._root:clear_dirty()

    
    self:_update_sliders()
end


function Tree:update(dt)
    self._last_active_time = love.timer.getTime()
    if not self._root then return end
    local frame_dt = dt or love.timer.getDelta()

    
    if self._root:is_dirty() then
        self:rebuild()
    end

    
    local new_w = love.graphics.getWidth()
    local new_h = love.graphics.getHeight()
    if new_w ~= self._screen_w or new_h ~= self._screen_h then
        self._screen_w = new_w
        self._screen_h = new_h
        self:rebuild()
    end

    
    self:_update_animations(self._root, frame_dt)

    if self._has_scroll_inertia then
        self._has_scroll_inertia = self:_update_scroll_inertia(self._root, frame_dt)
    end
end


function Tree:_update_fonts(node)
    if node._styles then
        node:_update_font()
    end
    if node._children then
        for _, child in ipairs(node._children) do
            self:_update_fonts(child)
        end
    end
end

function Tree:_update_animations(node, dt)
    if not node or not node._styles then
        return false
    end

    local has_active_animation = false
    local styles = node._styles
    local duration = styles:get('transition_duration') or 0
    local alpha = duration > 0 and math.min(1, (dt or 0) / duration) or 1

    if duration > 0 then
        if animate_color_state(node, '_anim_background', get_target_background_color(node, styles), alpha) then
            has_active_animation = true
        end
        if animate_color_state(node, '_anim_color', styles:get('color'), alpha) then
            has_active_animation = true
        end
        if animate_color_state(node, '_anim_border_color', styles:get('border_color'), alpha) then
            has_active_animation = true
        end
        if animate_number_state(node, '_anim_opacity', styles:get('opacity') or 1, alpha) then
            has_active_animation = true
        end
    else
        node._anim_background = nil
        node._anim_color = nil
        node._anim_border_color = nil
        node._anim_opacity = nil
    end

    if node._toggle_target_offset ~= nil then
        if animate_number_state(node, '_toggle_knob_offset', node._toggle_target_offset, alpha) then
            has_active_animation = true
        end
    end

    if node._toggle_knob and node._toggle_knob._styles then
        local knob = node._toggle_knob
        local knob_duration = knob._styles:get('transition_duration') or duration
        local knob_alpha = knob_duration > 0 and math.min(1, (dt or 0) / knob_duration) or 1

        if knob_duration > 0 then
            if animate_color_state(knob, '_anim_background', knob._styles:get('background'), knob_alpha) then
                has_active_animation = true
            end
        else
            knob._anim_background = nil
        end

        if knob._toggle_target_offset ~= nil then
            if animate_number_state(knob, '_toggle_knob_offset', knob._toggle_target_offset, knob_alpha) then
                has_active_animation = true
            end
        end
    end

    if node._children then
        for _, child in ipairs(node._children) do
            if self:_update_animations(child, dt) then
                has_active_animation = true
            end
        end
    end

    return has_active_animation
end


function Tree:_find_drag_target(node)
    node = node or self._root
    if not node then return nil end

    if node._slider_dragging or node._splitter_dragging then
        return node
    end

    if node._children then
        for _, child in ipairs(node._children) do
            local result = self:_find_drag_target(child)
            if result then return result end
        end
    end

    return nil
end


function Tree:_find_scroll_ancestor(node)
    local current = node
    while current do
        if current._type == 'scroll_view' then
            return current
        end
        current = current._parent
    end
    return nil
end


function Tree:_update_sliders(node)
    node = node or self._root
    if not node then return end

    
    local has_work = false

    if node._slider_update and node._type == 'slider' then
        node._slider_update()
        has_work = true
    end

    
    if node._type == 'scroll_view' and node._children and #node._children > 0 then
        local content_w = 0
        local content_h = 0
        local node_x = node._x or 0
        local node_y = node._y or 0

        for _, child in ipairs(node._children) do
            
            local rel_x = (child._x or 0) - node_x
            local rel_y = (child._y or 0) - node_y
            local child_right = rel_x + (child._width or 0)
            local child_bottom = rel_y + (child._height or 0)
            content_w = math.max(content_w, child_right)
            content_h = math.max(content_h, child_bottom)
        end

        local overflow_w = content_w - (node._width or 0)
        local overflow_h = content_h - (node._height or 0)

        
        local fixed_axis = node._styles and node._styles:get('scroll_axis')
        if fixed_axis then
            node._scroll_axis = fixed_axis
            if fixed_axis == 'horizontal' then
                node._scroll_max = math.max(0, overflow_w)
            else
                node._scroll_max = math.max(0, overflow_h)
            end
        else
            if overflow_w > overflow_h then
                node._scroll_axis = 'horizontal'
                node._scroll_max = math.max(0, overflow_w)
            else
                node._scroll_axis = 'vertical'
                node._scroll_max = math.max(0, overflow_h)
            end
        end

        node._scroll_offset = math.max(0, math.min(node._scroll_max, node._scroll_offset or 0))
        if node._scroll_max <= 0 then
            node._scrollbar_dragging = false
        end

        has_work = true
    end

    
    if node._children then
        for _, child in ipairs(node._children) do
            self:_update_sliders(child)
        end
    end
end


local SCROLL_FRICTION = 0.95  
local SCROLL_MIN_VELOCITY = 10  

function Tree:_update_scroll_inertia(node, dt)
    node = node or self._root
    if not node then return false end

    local has_active_inertia = false
    local frame_dt = dt or love.timer.getDelta()

    if node._type == 'scroll_view' and node._scroll_inertia then
        local vel = node._scroll_velocity

        if math.abs(vel) > SCROLL_MIN_VELOCITY then
            
            local delta = vel * frame_dt
            node._scroll_offset = math.max(0, math.min(node._scroll_max,
                node._scroll_offset - delta))

            
            node._scroll_velocity = vel * math.pow(SCROLL_FRICTION, frame_dt * 60)
            has_active_inertia = true

            
            if node._scroll_offset <= 0 or node._scroll_offset >= node._scroll_max then
                node._scroll_inertia = false
                node._scroll_velocity = 0
                has_active_inertia = false
            end
        else
            node._scroll_inertia = false
            node._scroll_velocity = 0
        end
    end

    if node._children then
        for _, child in ipairs(node._children) do
            if self:_update_scroll_inertia(child, frame_dt) then
                has_active_inertia = true
            end
        end
    end

    return has_active_inertia
end





local function rects_intersect(ax, ay, aw, ah, bx, by, bw, bh)
    return ax < bx + bw and ax + aw > bx and ay < by + bh and ay + ah > by
end

local function intersect_rect(ax, ay, aw, ah, bx, by, bw, bh)
    local nx = math.max(ax, bx)
    local ny = math.max(ay, by)
    local nr = math.min(ax + aw, bx + bw)
    local nb = math.min(ay + ah, by + bh)
    if nr <= nx or nb <= ny then
        return nil
    end
    return nx, ny, nr - nx, nb - ny
end

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

function Tree:_is_node_visible_in_clip(node, clip_x, clip_y, clip_w, clip_h, offset_x, offset_y)
    if not clip_x then
        return true
    end

    local w = node._width or 0
    local h = node._height or 0
    if w <= 0 or h <= 0 then
        return true
    end

    local x = (node._x or 0) + (offset_x or 0)
    local y = (node._y or 0) + (offset_y or 0)
    local styles = node._styles

    if styles and styles:get('box_shadow_color') then
        local shadow_pad = math.max(
            0,
            (styles:get('box_shadow_blur') or 0) + math.abs(styles:get('box_shadow_spread') or 0)
        )
        local shadow_offset_x = styles:get('box_shadow_offset_x') or 0
        local shadow_offset_y = styles:get('box_shadow_offset_y') or 0

        x = x + math.min(0, shadow_offset_x) - shadow_pad
        y = y + math.min(0, shadow_offset_y) - shadow_pad
        w = w + math.abs(shadow_offset_x) + shadow_pad * 2
        h = h + math.abs(shadow_offset_y) + shadow_pad * 2
    end

    return rects_intersect(x, y, w, h, clip_x, clip_y, clip_w, clip_h)
end

function Tree:_get_node_screen_rect(node)
    local x = node._x or 0
    local y = node._y or 0
    local current = node._parent

    while current do
        if current._type == 'scroll_view' then
            local axis = current._scroll_axis or 'vertical'
            local offset = current._scroll_offset or 0
            if axis == 'horizontal' then
                x = x - offset
            else
                y = y - offset
            end
        end
        current = current._parent
    end

    return x, y, node._width or 0, node._height or 0
end

function Tree:_get_scrollbar_geometry(node, x, y, w, h)
    if node._type ~= 'scroll_view' or not node._styles then
        return nil
    end

    local scroll_max = node._scroll_max or 0
    if scroll_max <= 0 then
        return nil
    end

    local styles = node._styles
    local axis = node._scroll_axis or 'vertical'
    local size = math.max(0, styles:get('scrollbar_size') or 0)
    local padding = math.max(0, styles:get('scrollbar_padding') or 0)
    if size <= 0 then
        return nil
    end

    local viewport_len = axis == 'horizontal' and w or h
    local track_len = viewport_len - padding * 2
    if track_len <= 0 then
        return nil
    end

    local total_len = viewport_len + scroll_max
    local min_thumb_size = math.max(4, styles:get('scrollbar_min_thumb_size') or 24)
    local thumb_len = math.min(track_len, math.max(min_thumb_size, track_len * viewport_len / total_len))
    local thumb_travel = math.max(0, track_len - thumb_len)
    local ratio = scroll_max > 0 and ((node._scroll_offset or 0) / scroll_max) or 0
    ratio = math.max(0, math.min(1, ratio))
    local thumb_pos = thumb_travel * ratio

    if axis == 'horizontal' then
        local track_x = x + padding
        local track_y = y + h - padding - size
        return {
            axis = axis,
            track_x = track_x,
            track_y = track_y,
            track_w = track_len,
            track_h = size,
            thumb_x = track_x + thumb_pos,
            thumb_y = track_y,
            thumb_w = thumb_len,
            thumb_h = size,
            thumb_len = thumb_len,
            thumb_travel = thumb_travel,
        }
    end

    local track_x = x + w - padding - size
    local track_y = y + padding
    return {
        axis = axis,
        track_x = track_x,
        track_y = track_y,
        track_w = size,
        track_h = track_len,
        thumb_x = track_x,
        thumb_y = track_y + thumb_pos,
        thumb_w = size,
        thumb_h = thumb_len,
        thumb_len = thumb_len,
        thumb_travel = thumb_travel,
    }
end

function Tree:_hit_scrollbar(node, x, y)
    local sx, sy, sw, sh = self:_get_node_screen_rect(node)
    local geometry = self:_get_scrollbar_geometry(node, sx, sy, sw, sh)
    if not geometry then
        return nil
    end

    if rects_intersect(x, y, 1, 1, geometry.thumb_x, geometry.thumb_y, geometry.thumb_w, geometry.thumb_h) then
        geometry.part = 'thumb'
        return geometry
    end

    if rects_intersect(x, y, 1, 1, geometry.track_x, geometry.track_y, geometry.track_w, geometry.track_h) then
        geometry.part = 'track'
        return geometry
    end

    return nil
end

function Tree:_find_scrollbar_target(node, x, y)
    local current = node
    while current do
        if current._type == 'scroll_view' then
            local hit = self:_hit_scrollbar(current, x, y)
            if hit then
                return current, hit
            end
        end
        current = current._parent
    end
    return nil, nil
end

function Tree:_set_scrollbar_offset_from_pointer(node, pointer_x, pointer_y)
    local sx, sy, sw, sh = self:_get_node_screen_rect(node)
    local geometry = self:_get_scrollbar_geometry(node, sx, sy, sw, sh)
    if not geometry then
        return
    end

    local pointer = geometry.axis == 'horizontal' and pointer_x or pointer_y
    local track_start = geometry.axis == 'horizontal' and geometry.track_x or geometry.track_y
    local grab_offset = node._scrollbar_drag_grab_offset or 0
    local pos = pointer - track_start - grab_offset
    local ratio = 0
    if geometry.thumb_travel > 0 then
        ratio = math.max(0, math.min(1, pos / geometry.thumb_travel))
    end

    node._scroll_offset = ratio * (node._scroll_max or 0)
    node._scroll_inertia = false
    node._scroll_velocity = 0
    node._dirty = true
end

function Tree:_draw_scrollbar(node, x, y, w, h, opacity)
    if node._styles and node._styles:get('hide_scrollbar') then return end

    local geometry = self:_get_scrollbar_geometry(node, x, y, w, h)
    if not geometry then
        return
    end

    local styles = node._styles
    local radius = math.min(geometry.track_w, geometry.track_h) / 2
    local track_color = styles:get('scrollbar_track_color') or {255, 255, 255, 40}
    local thumb_color = styles:get('scrollbar_thumb_color') or {255, 255, 255, 120}

    if node._scrollbar_dragging or self:_hit_scrollbar(node, love.mouse.getPosition()) then
        thumb_color = styles:get('scrollbar_thumb_hover_color') or thumb_color
    end

    if track_color and (track_color[4] or 255) > 0 then
        self:_set_color(
            track_color[1] / 255,
            track_color[2] / 255,
            track_color[3] / 255,
            ((track_color[4] or 255) / 255) * opacity
        )
        love.graphics.rectangle(
            'fill',
            geometry.track_x,
            geometry.track_y,
            geometry.track_w,
            geometry.track_h,
            radius,
            radius
        )
    end

    if thumb_color and (thumb_color[4] or 255) > 0 then
        self:_set_color(
            thumb_color[1] / 255,
            thumb_color[2] / 255,
            thumb_color[3] / 255,
            ((thumb_color[4] or 255) / 255) * opacity
        )
        love.graphics.rectangle(
            'fill',
            geometry.thumb_x,
            geometry.thumb_y,
            geometry.thumb_w,
            geometry.thumb_h,
            radius,
            radius
        )
    end
end


function Tree:draw()
    if not self._root then return end

    
    local prev_font = love.graphics.getFont()
    local prev_r, prev_g, prev_b, prev_a = love.graphics.getColor()

    
    self._draw_state = {
        font = prev_font,
        r = prev_r, g = prev_g, b = prev_b, a = prev_a,
    }

    
    self:_draw_node(self._root, nil, nil, nil, nil, 0, 0)

    
    if self._tooltip_node and self._tooltip_text then
        self:_draw_tooltip()
    end

    
    if self._debug_mode then
        self:_draw_debug(self._root)
    end

    
    love.graphics.setFont(prev_font)
    love.graphics.setColor(prev_r, prev_g, prev_b, prev_a)

    
    self._draw_state = nil
end


function Tree:_draw_node(node, clip_x, clip_y, clip_w, clip_h, offset_x, offset_y)
    if not node._styles then return end

    offset_x = offset_x or 0
    offset_y = offset_y or 0

    if not self:_is_node_visible_in_clip(node, clip_x, clip_y, clip_w, clip_h, offset_x, offset_y) then
        return
    end

    local styles = node._styles

    
    if styles:get('visible') == false then return end

    local x = node._x or 0
    local y = node._y or 0
    local w = node._width or 0
    local h = node._height or 0

    
    if w <= 0 or h <= 0 then
        
        if node._children then
            for _, child in ipairs(node._children) do
                self:_draw_node(child, clip_x, clip_y, clip_w, clip_h, offset_x, offset_y)
            end
        end
        return
    end

    
    if node._font and self._draw_state then
        if node._font ~= self._draw_state.font then
            love.graphics.setFont(node._font)
            self._draw_state.font = node._font
        end
    elseif node._font then
        love.graphics.setFont(node._font)
    end

    
    local opacity = node._anim_opacity or styles:get('opacity') or 1
    if opacity < 1 then
        love.graphics.push('all')
        love.graphics.setColor(1, 1, 1, opacity)
    end

    self:_draw_box_shadow(styles, x, y, w, h, opacity)

    
    local bg = node._anim_background or get_target_background_color(node, styles)

    if bg and #bg >= 3 then
        local r, g, b, a = bg[1] / 255, bg[2] / 255, bg[3] / 255, (bg[4] or 255) / 255
        a = a * opacity
        
        self:_set_color(r, g, b, a)

        local radius = styles:get('border_radius') or 0
        if radius > 0 then
            
            self:_draw_rounded_rect(x, y, w, h, radius)
        else
            love.graphics.rectangle('fill', x, y, w, h)
        end
    end

    
    if node._bg_image then
        self:_draw_bg_image(
            node,
            x,
            y,
            w,
            h,
            opacity,
            clip_x,
            clip_y,
            clip_w,
            clip_h,
            offset_x,
            offset_y
        )
    end

    self:_draw_background_accent(styles, x, y, w, h, opacity)

    
    local border_w = styles:get('border_width') or 0
    if border_w > 0 then
        local border_c = node._anim_border_color or styles:get('border_color') or {0, 0, 0, 255}
        local br, bg_c, bb, ba = border_c[1]/255, border_c[2]/255, border_c[3]/255, (border_c[4] or 255)/255
        ba = ba * opacity
        self:_set_color(br, bg_c, bb, ba)
        love.graphics.setLineWidth(border_w)

        local radius = styles:get('border_radius') or 0
        if radius > 0 then
            self:_draw_rounded_rect_outline(x, y, w, h, radius)
        else
            love.graphics.rectangle('line', x, y, w, h)
        end
    end

    
    if node._text and node._font then
        local text_color = node._anim_color or styles:get('color') or {255, 255, 255, 255}
        local tr, tg, tb, ta = text_color[1]/255, text_color[2]/255, text_color[3]/255, (text_color[4] or 255)/255
        ta = ta * opacity
        self:_set_color(tr, tg, tb, ta)

        local padding = styles:get_padding()
        local text_x = x + padding.left
        local text_y = y + padding.top
        local text_w = math.max(0, w - padding.left - padding.right)

        local text_align = styles:get('text_align') or 'left'
        local text_wrap = styles:get('text_wrap') ~= false
        local text_overflow = styles:get('text_overflow') or 'clip'
        local max_lines = styles:get('max_lines') or 0

        if text_wrap and text_w > 0 then
            
            local lines = Layout.wrap_text(node._text, node._font, text_w)
            lines = Layout.apply_text_limits(lines, node._font, text_w, max_lines, text_overflow)
            local line_h = node._font:getHeight() * (styles:get('line_height') or 1.2)

            for i, line in ipairs(lines) do
                local line_w = node._font:getWidth(line)
                local draw_x = text_x

                if text_align == 'center' then
                    draw_x = text_x + (text_w - line_w) / 2
                elseif text_align == 'right' then
                    draw_x = text_x + text_w - line_w
                end

                self:_draw_text_run(
                    line,
                    draw_x,
                    text_y + (i - 1) * line_h,
                    node._font_faux_bold,
                    node._font_faux_italic
                )
            end
        else
            local draw_text = node._text
            if text_overflow == 'ellipsis' then
                draw_text = Layout.truncate_text_ellipsis(draw_text, node._font, text_w)
            end

            local line_w = node._font:getWidth(draw_text)
            local draw_x = text_x

            if text_align == 'center' then
                draw_x = text_x + (text_w - line_w) / 2
            elseif text_align == 'right' then
                draw_x = text_x + text_w - line_w
            end

            self:_draw_text_run(
                draw_text,
                draw_x,
                text_y,
                node._font_faux_bold,
                node._font_faux_italic
            )
        end
    end

    
    if node._draw_fn then
        node._draw_fn(x, y, w, h, opacity)
    end

    
    self:_set_color(1, 1, 1, 1)

    
    if node._children then
        local scroll_offset = node._scroll_offset or 0
        local scroll_axis = node._scroll_axis or 'vertical'
        local next_offset_x = offset_x
        local next_offset_y = offset_y
        local next_clip_x, next_clip_y, next_clip_w, next_clip_h = clip_x, clip_y, clip_w, clip_h

        if node._type == 'scroll_view' then
            local viewport_x = x + offset_x
            local viewport_y = y + offset_y
            if next_clip_x then
                next_clip_x, next_clip_y, next_clip_w, next_clip_h = intersect_rect(
                    next_clip_x, next_clip_y, next_clip_w, next_clip_h,
                    viewport_x, viewport_y, w, h
                )
            else
                next_clip_x, next_clip_y, next_clip_w, next_clip_h = viewport_x, viewport_y, w, h
            end

        end

        if next_clip_x or node._type ~= 'scroll_view' then
            if scroll_offset ~= 0 then
                love.graphics.push()
                if scroll_axis == 'horizontal' then
                    love.graphics.translate(-scroll_offset, 0)
                    next_offset_x = next_offset_x - scroll_offset
                else
                    love.graphics.translate(0, -scroll_offset)
                    next_offset_y = next_offset_y - scroll_offset
                end
            end

            for _, child in ipairs(node._children) do
                self:_draw_node(child, next_clip_x, next_clip_y, next_clip_w, next_clip_h, next_offset_x, next_offset_y)
            end

            if scroll_offset ~= 0 then
                love.graphics.pop()
            end
        end
    end

    
    if node._type == 'scroll_view' then
        self:_draw_scrollbar(node, x, y, w, h, opacity)
    end

    if node._post_draw_fn then
        node._post_draw_fn(x, y, w, h)
    end

    
    if opacity < 1 then
        love.graphics.pop()
    end
end


function Tree:_set_color(r, g, b, a)
    if self._draw_state then
        local ds = self._draw_state
        
        if math.abs(ds.r - r) > 0.001 or math.abs(ds.g - g) > 0.001 or
           math.abs(ds.b - b) > 0.001 or math.abs(ds.a - a) > 0.001 then
            love.graphics.setColor(r, g, b, a)
            ds.r, ds.g, ds.b, ds.a = r, g, b, a
        end
    else
        love.graphics.setColor(r, g, b, a)
    end
end


function Tree:_draw_rounded_rect(x, y, w, h, r)
    r = math.min(r, w / 2, h / 2)
    
    love.graphics.rectangle('fill', x, y, w, h, r, r)
end


function Tree:_draw_rounded_rect_outline(x, y, w, h, r)
    r = math.min(r, w / 2, h / 2)
    love.graphics.rectangle('line', x, y, w, h, r, r)
end

function Tree:_draw_box_shadow(styles, x, y, w, h, opacity)
    local color = styles:get('box_shadow_color')
    if not color or #color < 3 then
        return
    end

    local base_alpha = ((color[4] or 255) / 255) * opacity
    if base_alpha <= 0 then
        return
    end

    local offset_x = styles:get('box_shadow_offset_x') or 0
    local offset_y = styles:get('box_shadow_offset_y') or 0
    local blur = math.max(0, styles:get('box_shadow_blur') or 0)
    local spread = styles:get('box_shadow_spread') or 0
    local radius = styles:get('border_radius') or 0
    local layers = math.max(1, math.ceil(blur / 2))

    for i = layers, 1, -1 do
        local t = i / layers
        local grow = spread + blur * t
        local layer_alpha = base_alpha
        if blur > 0 then
            layer_alpha = base_alpha * ((layers - i + 1) / layers) * 0.45
        end

        self:_set_color(
            (color[1] or 0) / 255,
            (color[2] or 0) / 255,
            (color[3] or 0) / 255,
            layer_alpha
        )

        local shadow_x = x + offset_x - grow
        local shadow_y = y + offset_y - grow
        local shadow_w = w + grow * 2
        local shadow_h = h + grow * 2
        local shadow_radius = math.max(0, radius + grow)

        if shadow_radius > 0 then
            self:_draw_rounded_rect(shadow_x, shadow_y, shadow_w, shadow_h, shadow_radius)
        else
            love.graphics.rectangle('fill', shadow_x, shadow_y, shadow_w, shadow_h)
        end
    end
end

function Tree:_draw_background_accent(styles, x, y, w, h, opacity)
    local accent = styles:get('background_accent')
    if not accent or #accent < 3 then
        return
    end

    local side = styles:get('background_accent_side') or 'left'
    local size = math.max(0, math.min(styles:get('background_accent_size') or 4, math.max(w, h)))
    if size <= 0 then
        return
    end

    local ax, ay, aw, ah = x, y, w, h
    if side == 'right' then
        ax = x + w - size
        aw = size
    elseif side == 'top' then
        ah = size
    elseif side == 'bottom' then
        ay = y + h - size
        ah = size
    else
        aw = size
    end

    local r, g, b, a = accent[1] / 255, accent[2] / 255, accent[3] / 255, (accent[4] or 255) / 255
    self:_set_color(r, g, b, a * opacity)

    local radius = styles:get('border_radius') or 0
    if radius > 0 then
        love.graphics.stencil(function()
            love.graphics.rectangle('fill', x, y, w, h, radius, radius)
        end, 'replace', 1)
        love.graphics.setStencilTest('greater', 0)
        love.graphics.rectangle('fill', ax, ay, aw, ah)
        love.graphics.setStencilTest()
    else
        love.graphics.rectangle('fill', ax, ay, aw, ah)
    end
end

function Tree:_draw_text_run(text, x, y, faux_bold, faux_italic)
    if not faux_bold and not faux_italic then
        love.graphics.print(text, x, y)
        return
    end

    love.graphics.push()
    love.graphics.translate(x, y)
    if faux_italic then
        love.graphics.shear(0.18, 0)
    end

    love.graphics.print(text, 0, 0)
    if faux_bold then
        love.graphics.print(text, 1, 0)
        love.graphics.print(text, 0, 1)
        love.graphics.print(text, 1, 1)
    end

    love.graphics.pop()
end


function Tree:_draw_bg_image(
    node,
    x,
    y,
    w,
    h,
    opacity,
    clip_x,
    clip_y,
    clip_w,
    clip_h,
    offset_x,
    offset_y
)
    local img = node._bg_image
    if not img then return end

    local mode = node._bg_image_mode or 'cover'
    local tint = node._styles:get('background_image_color') or {255, 255, 255, 255}
    local img_w = img:getWidth()
    local img_h = img:getHeight()

    self:_set_color(
        tint[1] / 255,
        tint[2] / 255,
        tint[3] / 255,
        ((tint[4] or 255) / 255) * (opacity or 1)
    )

    local screen_x = x + (offset_x or 0)
    local screen_y = y + (offset_y or 0)
    local scissor_x, scissor_y, scissor_w, scissor_h = screen_x, screen_y, w, h

    if clip_x then
        scissor_x, scissor_y, scissor_w, scissor_h = intersect_rect(
            scissor_x,
            scissor_y,
            scissor_w,
            scissor_h,
            clip_x,
            clip_y,
            clip_w,
            clip_h
        )
    end

    if not scissor_x then
        return
    end

    local old_scissor = save_scissor_rect()
    love.graphics.intersectScissor(scissor_x, scissor_y, scissor_w, scissor_h)

    if mode == 'cover' then
        
        local scale_x = w / img_w
        local scale_y = h / img_h
        local scale = math.max(scale_x, scale_y)
        local draw_w = img_w * scale
        local draw_h = img_h * scale
        local draw_x = x + (w - draw_w) / 2
        local draw_y = y + (h - draw_h) / 2

        
        love.graphics.draw(img, draw_x, draw_y, 0, scale, scale)

    elseif mode == 'contain' then
        
        local scale_x = w / img_w
        local scale_y = h / img_h
        local scale = math.min(scale_x, scale_y)
        local draw_w = img_w * scale
        local draw_h = img_h * scale
        local draw_x = x + (w - draw_w) / 2
        local draw_y = y + (h - draw_h) / 2

        love.graphics.draw(img, draw_x, draw_y, 0, scale, scale)

    elseif mode == 'stretch' then
        
        local scale_x = w / img_w
        local scale_y = h / img_h
        love.graphics.draw(img, x, y, 0, scale_x, scale_y)

    elseif mode == 'tile' then
        
        local ox = x
        while ox < x + w do
            local oy = y
            while oy < y + h do
                love.graphics.draw(img, ox, oy)
                oy = oy + img_h
            end
            ox = ox + img_w
        end
    else
        
        local scale_x = w / img_w
        local scale_y = h / img_h
        local scale = math.max(scale_x, scale_y)
        local draw_w = img_w * scale
        local draw_h = img_h * scale
        local draw_x = x + (w - draw_w) / 2
        local draw_y = y + (h - draw_h) / 2

        love.graphics.draw(img, draw_x, draw_y, 0, scale, scale)
    end

    restore_scissor_rect(old_scissor)
end


function Tree:_draw_tooltip()
    if not self._tooltip_text then return end

    local mx, my = love.mouse.getPosition()
    local padding = 8
    local font = love.graphics.getFont() or love.graphics.newFont(12)
    local tw = font:getWidth(self._tooltip_text)
    local th = font:getHeight()

    local tx = mx + 12
    local ty = my - th - 8

    
    love.graphics.setColor(0.1, 0.1, 0.1, 0.9)
    love.graphics.rectangle('fill', tx, ty, tw + padding * 2, th + padding * 2, 4)

    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(font)
    love.graphics.print(self._tooltip_text, tx + padding, ty + padding)

    love.graphics.setColor(1, 1, 1, 1)
end


function Tree:_draw_debug(node)
    if not node._styles then return end
    if node._styles:get('visible') == false then return end

    local x = node._x or 0
    local y = node._y or 0
    local w = node._width or 0
    local h = node._height or 0

    
    love.graphics.setColor(1, 0, 0, 0.5)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle('line', x, y, w, h)

    
    local padding = node._styles:get_padding()
    if padding.top > 0 or padding.right > 0 or padding.bottom > 0 or padding.left > 0 then
        love.graphics.setColor(0, 1, 0, 0.3)
        love.graphics.rectangle('fill',
            x, y, w, h)
        love.graphics.setColor(0, 0, 1, 0.3)
        love.graphics.rectangle('fill',
            x + padding.left, y + padding.top,
            w - padding.left - padding.right,
            h - padding.top - padding.bottom)
    end

    
    if w > 30 and h > 20 then
        love.graphics.setColor(1, 1, 1, 0.8)
        local info = string.format('%d: %.0fx%.0f', node._id, w, h)
        local font = love.graphics.newFont(10)
        love.graphics.setFont(font)
        love.graphics.print(info, x + 2, y + 2)
    end

    love.graphics.setColor(1, 1, 1, 1)

    
    if node._children then
        for _, child in ipairs(node._children) do
            self:_draw_debug(child)
        end
    end
end



function Tree:mousemoved(x, y, dx, dy)
    if not self._root then return end

    
    local drag_target = self._drag_target
    if drag_target and drag_target._slider_dragging then
        local w = drag_target._width or 200
        drag_target._slider_value = math.max(0, math.min(1, (x - drag_target._x) / w))
        if drag_target._slider_update then
            drag_target._slider_update()
        end
        
    elseif drag_target and drag_target._splitter_dragging then
        local splitter = drag_target._splitter_owner
        if splitter and splitter._splitter_apply_size then
            local axis_delta = splitter._splitter_is_horizontal
                and (x - (splitter._splitter_drag_start_x or x))
                or (y - (splitter._splitter_drag_start_y or y))
            local next_size = (splitter._splitter_drag_start_size or splitter._splitter_size or 0) + axis_delta
            splitter._splitter_apply_size(next_size, true)
        end
        Events.reset_hover_and_press()
        self:_set_cursor(drag_target._styles:get('cursor') or 'arrow')
        return
    end

    
    local scroll_drag = self._scroll_drag_target
    if scroll_drag and scroll_drag._scroll_dragging then
        if scroll_drag._scrollbar_dragging then
            scroll_drag._scroll_has_focus = true
            Events.reset_hover_and_press()
            self:_set_scrollbar_offset_from_pointer(scroll_drag, x, y)
            return
        end

        local dx_scroll = x - scroll_drag._scroll_drag_start_x
        local dy_scroll = y - scroll_drag._scroll_drag_start_y
        local dist = math.sqrt(dx_scroll * dx_scroll + dy_scroll * dy_scroll)

        
        local now = love.timer.getTime()
        table.insert(scroll_drag._scroll_history, {x = x, y = y, t = now})
        if #scroll_drag._scroll_history > 10 then
            table.remove(scroll_drag._scroll_history, 1)
        end

        
        if dist > 10 then
            scroll_drag._scroll_has_focus = true
            
            Events.reset_hover_and_press()
        end

        if scroll_drag._scroll_has_focus then
            
            local axis = scroll_drag._scroll_axis or 'vertical'
            local delta = axis == 'horizontal' and dx_scroll or dy_scroll
            local new_offset = math.max(0, math.min(scroll_drag._scroll_max,
                scroll_drag._scroll_drag_start_offset - delta))

            scroll_drag._scroll_offset = new_offset
        end
    end

    
    local hovered = Events.hit_test(self._root, x, y)
    Events.handle_mouse_move_with_target(self._root, hovered, x, y)
    if not hovered then
        self:_set_cursor('arrow')
    end

    
    self._tooltip_node = nil
    self._tooltip_text = nil

    if hovered and hovered._styles:get('tooltip') then
        self._tooltip_node = hovered
        self._tooltip_text = hovered._styles:get('tooltip')
    end

    
    if hovered then
        self:_set_cursor(hovered._styles:get('cursor') or 'arrow')
        
        
    end
end


function Tree:mousepressed(x, y, button)
    if not self._root then return end
    local pressed = Events.hit_test(self._root, x, y)
    local scrollbar_target, scrollbar_hit = self:_find_scrollbar_target(pressed, x, y)
    if scrollbar_target and scrollbar_hit then
        self._scroll_drag_target = scrollbar_target
        scrollbar_target._scroll_dragging = true
        scrollbar_target._scrollbar_dragging = true
        scrollbar_target._scroll_has_focus = true
        scrollbar_target._scroll_inertia = false
        scrollbar_target._scroll_velocity = 0
        scrollbar_target._scroll_history = {}

        local pointer = scrollbar_hit.axis == 'horizontal' and x or y
        local thumb_start = scrollbar_hit.axis == 'horizontal'
            and scrollbar_hit.thumb_x
            or scrollbar_hit.thumb_y

        if scrollbar_hit.part == 'thumb' then
            scrollbar_target._scrollbar_drag_grab_offset = pointer - thumb_start
        else
            scrollbar_target._scrollbar_drag_grab_offset = scrollbar_hit.thumb_len / 2
            self:_set_scrollbar_offset_from_pointer(scrollbar_target, x, y)
        end

        Events.reset_hover_and_press()
        return
    end

    Events.handle_mouse_press(self._root, x, y, button)

    
    pressed = Events.hit_test(self._root, x, y)
    if pressed and (pressed._slider_dragging ~= nil or pressed._splitter_dragging ~= nil) then
        self._drag_target = pressed
    end

    
    if not self._drag_target then
        local scroll_parent = self:_find_scroll_ancestor(pressed)
        if scroll_parent then
            local now = love.timer.getTime()
            self._scroll_drag_target = scroll_parent
            scroll_parent._scroll_dragging = true
            scroll_parent._scroll_drag_start_x = x
            scroll_parent._scroll_drag_start_y = y
            scroll_parent._scroll_drag_start_offset = scroll_parent._scroll_offset or 0
            scroll_parent._scroll_has_focus = false
            
            scroll_parent._scroll_inertia = false
            scroll_parent._scroll_velocity = 0
            scroll_parent._scroll_history = {
                {x = x, y = y, t = now}
            }
        end
    end
end


function Tree:mousereleased(x, y, button)
    if not self._root then return end
    local scroll_target = self._scroll_drag_target

    if not (scroll_target and scroll_target._scrollbar_dragging) then
        Events.handle_mouse_release(self._root, x, y, button)
    end

    
    if self._drag_target and self._drag_target._slider_dragging ~= nil then
        self._drag_target._slider_dragging = false
        self._drag_target = nil
    elseif self._drag_target and self._drag_target._splitter_dragging ~= nil then
        local splitter = self._drag_target._splitter_owner
        self._drag_target._splitter_dragging = false
        if splitter then
            splitter._splitter_dragging = false
        end
        self._drag_target = nil
    end

    
    if scroll_target then
        local sv = scroll_target

        if not sv._scrollbar_dragging and #sv._scroll_history >= 2 then
            local last = sv._scroll_history[#sv._scroll_history]
            local first = sv._scroll_history[1]
            local dt = last.t - first.t
            local axis = sv._scroll_axis or 'vertical'
            local delta = axis == 'horizontal'
                and (last.x - first.x)
                or (last.y - first.y)

            if dt > 0.01 then
                sv._scroll_velocity = delta / dt
                sv._scroll_inertia = true
                self._has_scroll_inertia = true  
            end
        end

        sv._scroll_dragging = false
        sv._scrollbar_dragging = false
        sv._scroll_has_focus = false
        sv._scrollbar_drag_grab_offset = nil
        self._scroll_drag_target = nil
    end

    
    Events.reset_scroll_focus()
end


function Tree:wheelmoved(x, y)
    if not self._root then return end
    local mx, my = love.mouse.getPosition()
    Events.handle_scroll(self._root, mx, my, y)
end


function Tree:keypressed(key)
    if not self._root then return end
    Events.handle_key_pressed(self._root, key)
end


function Tree:textinput(text)
    if not self._root then return end
    Events.handle_text_input(self._root, text)
end





function Tree:set_camera(x, y)
    self._camera_x = x
    self._camera_y = y
    self:rebuild()
    return self
end

function Tree:get_camera()
    return self._camera_x, self._camera_y
end



function Tree:debug_mode(enabled)
    self._debug_mode = enabled
    return self
end


function Tree:get_stats()
    local stats = {
        nodes = 0,
        interactive = 0,
        visible = 0,
        max_depth = 0,
    }

    local function count(node, depth)
        stats.nodes = stats.nodes + 1
        stats.max_depth = math.max(stats.max_depth, depth)

        if node._styles then
            if node._styles:get('visible') then
                stats.visible = stats.visible + 1
            end
            if node._styles:get('interactive') then
                stats.interactive = stats.interactive + 1
            end
        end

        if node._children then
            for _, child in ipairs(node._children) do
                count(child, depth + 1)
            end
        end
    end

    if self._root then
        count(self._root, 0)
    end

    return stats
end



function Tree:reset()
    self._root = nil
    Events.reset()
    return self
end


function Tree:destroy()
    self._root = nil
    Events.reset()
    self._tooltip_node = nil
    self._tooltip_text = nil
end

return Tree
