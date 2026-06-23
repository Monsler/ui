local Styles = require('ui.styles')
local Fonts = require('ui.fonts')
local Events = require('ui.events')

local Node = {}
Node.__index = Node

local _node_counter = 0

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

local function make_color(r, g, b, a)
    if type(r) == 'table' then
        return r
    end

    if a == nil then
        local max_component = math.max(r or 0, g or 0, b or 0)
        a = max_component <= 1 and 1 or 255
    end

    return {r, g, b, a}
end

function Node.new(type, props)
    _node_counter = _node_counter + 1

    local self = setmetatable({}, Node)

    self._id = _node_counter
    self._type = type or 'container'
    self._parent = nil
    self._children = {}
    self._styles = Styles.new()
    self._font = nil
    self._font_faux_bold = false
    self._font_faux_italic = false
    self._text = nil
    self._image = nil
    self._measure_fn = nil
    self._draw_fn = nil
    self._refresh_theme_fn = nil

    self._theme_name = nil
    self._theme_defaults = nil
    self._style_overrides = {}

    self._x = 0
    self._y = 0
    self._width = 0
    self._height = 0

    self._dirty = true
    self._built = false

    self._data = {}

    if props then
        self:apply(props)
    end

    return self
end

function Node:size(w, h)
    self:_set_style('width', w)
    self:_set_style('height', h)
    return self
end

function Node:size_full()
    self:_set_style('width', 'full')
    self:_set_style('height', 'full')
    return self
end

function Node:width_full()
    self:_set_style('width', 'full')
    return self
end

function Node:height_full()
    self:_set_style('height', 'full')
    return self
end

function Node:size_content()
    self:_set_style('width', nil)
    self:_set_style('height', nil)
    self:_set_style('size_mode', 'content')
    return self
end

function Node:width(w)
    self:_set_style('width', w)
    return self
end

function Node:height(h)
    self:_set_style('height', h)
    return self
end

function Node:min_width(w)
    self:_set_style('min_width', w)
    return self
end

function Node:min_height(h)
    self:_set_style('min_height', h)
    return self
end

function Node:max_width(w)
    self:_set_style('max_width', w)
    return self
end

function Node:max_height(h)
    self:_set_style('max_height', h)
    return self
end

function Node:padding(value)
    self:_set_style('padding', value)
    return self
end

function Node:padding_top(v)
    self:_set_style('padding_top', v)
    return self
end

function Node:padding_right(v)
    self:_set_style('padding_right', v)
    return self
end

function Node:padding_bottom(v)
    self:_set_style('padding_bottom', v)
    return self
end

function Node:padding_left(v)
    self:_set_style('padding_left', v)
    return self
end

function Node:margin(value)
    self:_set_style('margin', value)
    return self
end

function Node:margin_top(v)
    self:_set_style('margin_top', v)
    return self
end

function Node:margin_right(v)
    self:_set_style('margin_right', v)
    return self
end

function Node:margin_bottom(v)
    self:_set_style('margin_bottom', v)
    return self
end

function Node:margin_left(v)
    self:_set_style('margin_left', v)
    return self
end

function Node:color(r, g, b, a)
    self:_set_style('color', make_color(r, g, b, a))
    return self
end

function Node:background(r, g, b, a)
    self:_set_style('background', make_color(r, g, b, a))
    return self
end

function Node:background_accent(r, g, b, a)
    self:_set_style('background_accent', make_color(r, g, b, a))
    return self
end

function Node:background_accent_side(side)
    self:_set_style('background_accent_side', side)
    return self
end

function Node:background_accent_size(size)
    self:_set_style('background_accent_size', size)
    return self
end

function Node:hover_background(r, g, b, a)
    self:_set_style('hover_background', make_color(r, g, b, a))
    return self
end

function Node:pressed_background(r, g, b, a)
    self:_set_style('pressed_background', make_color(r, g, b, a))
    return self
end

function Node:border_width(w)
    self:_set_style('border_width', w)
    return self
end

function Node:border_color(r, g, b, a)
    self:_set_style('border_color', make_color(r, g, b, a))
    return self
end

function Node:border_radius(r)
    self:_set_style('border_radius', r)
    return self
end

function Node:box_shadow(offset_x, offset_y, blur, r, g, b, a, spread)
    self:_set_style('box_shadow_offset_x', offset_x or 0)
    self:_set_style('box_shadow_offset_y', offset_y or 0)
    self:_set_style('box_shadow_blur', blur or 0)
    self:_set_style('box_shadow_color', make_color(r, g, b, a))

    if spread ~= nil then
        self:_set_style('box_shadow_spread', spread)
    end

    return self
end

function Node:box_shadow_color(r, g, b, a)
    self:_set_style('box_shadow_color', make_color(r, g, b, a))
    return self
end

function Node:box_shadow_offset(x, y)
    self:_set_style('box_shadow_offset_x', x or 0)
    self:_set_style('box_shadow_offset_y', y or 0)
    return self
end

function Node:box_shadow_blur(v)
    self:_set_style('box_shadow_blur', v)
    return self
end

function Node:box_shadow_spread(v)
    self:_set_style('box_shadow_spread', v)
    return self
end

function Node:font_size(size)
    self:_set_style('font_size', size)
    self:_update_font()
    return self
end

function Node:font_bold()
    self:_set_style('font_weight', 'bold')
    self:_update_font()
    return self
end

function Node:font_italic()
    self:_set_style('font_style', 'italic')
    self:_update_font()
    return self
end

function Node:font_family(name)
    self:_set_style('font_family', name)
    self:_update_font()
    return self
end

function Node:font_weight(weight)
    self:_set_style('font_weight', weight)
    self:_update_font()
    return self
end

function Node:_update_font()
    self._font, self._font_faux_bold, self._font_faux_italic = Fonts.from_style(self._styles)
    return self
end

function Node:text(str)
    self._text = tostring(str)
    self:_set_style('interactive', false)
    return self
end

function Node:text_align(align)
    self:_set_style('text_align', align)
    return self
end

function Node:text_wrap(enabled)
    self:_set_style('text_wrap', enabled ~= false)
    return self
end

function Node:text_overflow(value)
    self:_set_style('text_overflow', value)
    return self
end

function Node:max_lines(value)
    self:_set_style('max_lines', value)
    return self
end

function Node:line_height(h)
    self:_set_style('line_height', h)
    return self
end

function Node:layout_row()
    self:_set_style('layout', 'row')
    return self
end

function Node:layout_column()
    self:_set_style('layout', 'column')
    return self
end

function Node:layout_grid()
    self:_set_style('layout', 'grid')
    return self
end

function Node:layout_none()
    self:_set_style('layout', 'none')
    return self
end

function Node:justify_content(value)
    self:_set_style('justify_content', value)
    return self
end

function Node:align_items(value)
    self:_set_style('align_items', value)
    return self
end

function Node:align_self(value)
    self:_set_style('align_self', value)
    return self
end

function Node:flex(value)
    self:_set_style('flex', value)
    return self
end

function Node:spring()
    self:_set_style('spring', true)
    self:_set_style('flex', 1)
    return self
end

function Node:is_spring()
    return self._styles:get('spring') or false
end

function Node:spacing(value)
    self:_set_style('gap', value)
    return self
end

function Node:gap(value)
    self:_set_style('gap', value)
    return self
end

function Node:row_gap(value)
    self:_set_style('row_gap', value)
    return self
end

function Node:column_gap(value)
    self:_set_style('column_gap', value)
    return self
end

function Node:flex_wrap(value)
    self:_set_style('flex_wrap', value)
    return self
end

function Node:grid_template_columns(value)
    self:_set_style('grid_template_columns', value)
    return self
end

function Node:grid_template_rows(value)
    self:_set_style('grid_template_rows', value)
    return self
end

function Node:grid_auto_rows(value)
    self:_set_style('grid_auto_rows', value)
    return self
end

function Node:grid_auto_columns(value)
    self:_set_style('grid_auto_columns', value)
    return self
end

function Node:grid_column(value)
    self:_set_style('grid_column', value)
    return self
end

function Node:grid_row(value)
    self:_set_style('grid_row', value)
    return self
end

function Node:position_absolute()
    self:_set_style('position', 'absolute')
    return self
end

function Node:position_relative()
    self:_set_style('position', 'relative')
    return self
end

function Node:top(v)
    self:_set_style('top', v)
    return self
end

function Node:right(v)
    self:_set_style('right', v)
    return self
end

function Node:bottom(v)
    self:_set_style('bottom', v)
    return self
end

function Node:left(v)
    self:_set_style('left', v)
    return self
end

function Node:overflow(v)
    self:_set_style('overflow', v)
    return self
end

function Node:clip(v)
    self:_set_style('clip', v)
    return self
end

function Node:scrollbar_size(v)
    self:_set_style('scrollbar_size', v)
    return self
end

function Node:hide_scrollbar(v)
    if v == nil then v = true end
    self:_set_style('hide_scrollbar', v)
    return self
end

function Node:scroll_axis(v)
    self:_set_style('scroll_axis', v)
    return self
end

function Node:scrollbar_min_thumb_size(v)
    self:_set_style('scrollbar_min_thumb_size', v)
    return self
end

function Node:scrollbar_padding(v)
    self:_set_style('scrollbar_padding', v)
    return self
end

function Node:scrollbar_track_color(r, g, b, a)
    self:_set_style('scrollbar_track_color', make_color(r, g, b, a))
    return self
end

function Node:scrollbar_thumb_color(r, g, b, a)
    self:_set_style('scrollbar_thumb_color', make_color(r, g, b, a))
    return self
end

function Node:scrollbar_thumb_hover_color(r, g, b, a)
    self:_set_style('scrollbar_thumb_hover_color', make_color(r, g, b, a))
    return self
end

function Node:background_image(img)
    self._bg_image = img
    self:_mark_dirty()
    return self
end

function Node:background_image_color(r, g, b, a)
    self:_set_style('background_image_color', make_color(r, g, b, a))
    return self
end

function Node:bg_tint(r, g, b, a)
    return self:background_image_color(r, g, b, a)
end

function Node:bg_mode(mode)
    self._bg_image_mode = mode or 'cover'
    self:_mark_dirty()
    return self
end

function Node:bg_cover()
    self._bg_image_mode = 'cover'
    self:_mark_dirty()
    return self
end

function Node:bg_contain()
    self._bg_image_mode = 'contain'
    self:_mark_dirty()
    return self
end

function Node:bg_stretch()
    self._bg_image_mode = 'stretch'
    self:_mark_dirty()
    return self
end

function Node:bg_tile()
    self._bg_image_mode = 'tile'
    self:_mark_dirty()
    return self
end

function Node:align_center()
    self:_set_style('text_align', 'center')
    return self
end

function Node:align_left()
    self:_set_style('text_align', 'left')
    return self
end

function Node:align_right()
    self:_set_style('text_align', 'right')
    return self
end

function Node:center_in_parent()
    self:_set_style('align_self', 'center')
    return self
end

function Node:visible(v)
    self:_set_style('visible', v)
    return self
end

function Node:hide()
    self:_set_style('visible', false)
    return self
end

function Node:show()
    self:_set_style('visible', true)
    return self
end

function Node:opacity(v)
    self:_set_style('opacity', v)
    return self
end

function Node:transition_duration(v)
    self:_set_style('transition_duration', v)
    return self
end

function Node:z_index(v)
    self:_set_style('z_index', v)
    return self
end

function Node:interactive(v)
    self:_set_style('interactive', v)
    return self
end

function Node:disabled(v)
    self:_set_style('disabled', v)
    return self
end

function Node:cursor(v)
    self:_set_style('cursor', v)
    return self
end

function Node:tooltip(v)
    self:_set_style('tooltip', v)
    return self
end

function Node:on_click(callback)
    Events.on(self, Events.TYPES.CLICK, callback)
    self:_set_style('interactive', true)
    return self
end

function Node:on_press(callback)
    Events.on(self, Events.TYPES.MOUSE_PRESS, callback)
    self:_set_style('interactive', true)
    return self
end

function Node:on_release(callback)
    Events.on(self, Events.TYPES.MOUSE_RELEASE, callback)
    return self
end

function Node:on_hover(callback)
    Events.on(self, Events.TYPES.MOUSE_ENTER, callback)
    return self
end

function Node:on_unhover(callback)
    Events.on(self, Events.TYPES.MOUSE_LEAVE, callback)
    return self
end

function Node:on_double_click(callback)
    Events.on(self, Events.TYPES.DOUBLE_CLICK, callback)
    return self
end

function Node:on_right_click(callback)
    Events.on(self, Events.TYPES.RIGHT_CLICK, callback)
    return self
end

function Node:on_scroll(callback)
    Events.on(self, Events.TYPES.SCROLL, callback)
    return self
end

function Node:add(child)
    assert(child ~= nil, 'Cannot add nil child')

    if getmetatable(child) == nil and type(child) == 'table' then
        child = Node.from_table(child)
    end

    assert(child._type ~= nil, 'Child must be a UI node')

    child._parent = self

    table.insert(self._children, child)

    self:_mark_dirty()
    self._fonts_dirty = true

    return self
end

function Node:add_many(children)
    for _, child in ipairs(children) do
        self:add(child)
    end
    return self
end

function Node:insert_at(index, child)
    assert(child ~= nil, 'Cannot insert nil child')
    if getmetatable(child) == nil and type(child) == 'table' then
        child = Node.from_table(child)
    end
    child._parent = self
    table.insert(self._children, index, child)
    self:_mark_dirty()
    return self
end

function Node:remove(child)
    for i, c in ipairs(self._children) do
        if c == child then
            c._parent = nil
            table.remove(self._children, i)
            self:_mark_dirty()
            return self
        end
    end
    return self
end

function Node:remove_at(index)
    local child = self._children[index]
    if child then
        child._parent = nil
        table.remove(self._children, index)
        self:_mark_dirty()
    end
    return self
end

function Node:clear()
    for _, child in ipairs(self._children) do
        child._parent = nil
    end
    self._children = {}
    self:_mark_dirty()
    return self
end

function Node:get_child(index)
    return self._children[index]
end

function Node:child_count()
    return #self._children
end

function Node:find_by_id(id)
    if self._id == id then return self end
    for _, child in ipairs(self._children) do
        local result = child:find_by_id(id)
        if result then return result end
    end
    return nil
end

function Node:find_by_type(type_name)
    local results = {}
    if self._type == type_name then
        table.insert(results, self)
    end
    for _, child in ipairs(self._children) do
        local found = child:find_by_type(type_name)
        for _, node in ipairs(found) do
            table.insert(results, node)
        end
    end
    return results
end

function Node:find(predicate)
    if predicate(self) then return self end
    for _, child in ipairs(self._children) do
        local result = child:find(predicate)
        if result then return result end
    end
    return nil
end

function Node:find_all(predicate)
    local results = {}
    if predicate(self) then
        table.insert(results, self)
    end
    for _, child in ipairs(self._children) do
        local found = child:find_all(predicate)
        for _, node in ipairs(found) do
            table.insert(results, node)
        end
    end
    return results
end

function Node:apply(props)
    if not props then return self end

    for k, v in pairs(props) do
        if k ~= 'type' and k ~= 'children' and k ~= 'text' and k ~= 'on_click'
           and k ~= 'on_hover' and k ~= 'on_press' and k ~= 'id' then
            self:_set_style(k, v)
        end
    end

    if props.text then
        self:text(props.text)
    end
    if props.on_click then
        self:on_click(props.on_click)
    end
    if props.on_hover then
        self:on_hover(props.on_hover)
    end
    if props.on_press then
        self:on_press(props.on_press)
    end

    self:_update_font()

    return self
end

function Node:get_style()
    return self._styles
end

function Node:get_style_prop(key)
    return self._styles:get(key)
end

function Node:_mark_dirty()
    local current = self
    while current do
        current._dirty = true
        current = current._parent
    end
    return self
end

function Node:build()
    self._built = true
    self:_mark_dirty()
    return self
end

function Node:rebuild()
    self:refresh_theme_styles()
    self:_mark_dirty()
    return self
end

function Node:_set_style(key, value, track_override)
    if track_override ~= false then
        self._style_overrides[key] = copy_value(value)
    end

    self._styles:set(key, value)
    self:_mark_dirty()
    return self
end

function Node:bind_theme(theme_name, defaults)
    self._theme_name = theme_name
    self._theme_defaults = copy_value(defaults or {})
    self:refresh_theme_styles()
    return self
end

function Node:refresh_theme_styles()
    self._styles = Styles.new(self._theme_defaults or {})

    if self._theme_name then
        local theme_props = Styles.get_theme_style_props(self._theme_name)
        if theme_props then
            self._styles:apply(theme_props)
        end
    end

    if self._style_overrides then
        for key, value in pairs(self._style_overrides) do
            self._styles:set(key, copy_value(value))
        end
    end

    self:_update_font()

    for _, child in ipairs(self._children) do
        child:refresh_theme_styles()
    end

    if self._refresh_theme_fn then
        self._refresh_theme_fn(self)
    end

    return self
end

function Node:is_dirty()
    return self._dirty
end

function Node:clear_dirty()
    self._dirty = false
    for _, child in ipairs(self._children) do
        child:clear_dirty()
    end
end

function Node:data(key, value)
    if value == nil then
        if type(key) == 'table' then
            for k, v in pairs(key) do
                self._data[k] = v
            end
        else
            return self._data[key]
        end
    else
        self._data[key] = value
    end
    return self
end

function Node.from_table(config)
    assert(type(config) == 'table', 'Config must be a table')

    local node_type = config.type or 'container'
    local node = Node.new(node_type)
    node:bind_theme(node_type)

    local props = {}
    for k, v in pairs(config) do
        if k ~= 'type' and k ~= 'children' then
            props[k] = v
        end
    end

    node:apply(props)

    if config.children then
        for _, child_config in ipairs(config.children) do
            local child
            if getmetatable(child_config) == Node then
                child = child_config
            else
                child = Node.from_table(child_config)
            end
            node:add(child)
        end
    end

    return node
end

function Node:to_string(indent)
    indent = indent or 0
    local prefix = string.rep('  ', indent)
    local lines = {}

    local size_str = string.format('%.0fx%.0f', self._width or 0, self._height or 0)
    local pos_str = string.format('(%.0f,%.0f)', self._x or 0, self._y or 0)
    local text_str = self._text and string.format(' "%s"', self._text:sub(1, 20)) or ''

    table.insert(lines, string.format('%s[%s] %s %s%s (id=%d)',
        prefix, self._type, size_str, pos_str, text_str, self._id))

    for _, child in ipairs(self._children) do
        table.insert(lines, child:to_string(indent + 1))
    end

    return table.concat(lines, '\n')
end

function Node:debug()
    print(self:to_string())
end

return Node
