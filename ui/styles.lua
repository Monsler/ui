local Styles = {}
Styles.__index = Styles

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



local VALID_PROPERTIES = {
    
    width = 'number|string',
    height = 'number|string',
    min_width = 'number',
    min_height = 'number',
    max_width = 'number',
    max_height = 'number',

    
    padding = 'number|table',
    padding_top = 'number',
    padding_right = 'number',
    padding_bottom = 'number',
    padding_left = 'number',

    margin = 'number|table',
    margin_top = 'number',
    margin_right = 'number',
    margin_bottom = 'number',
    margin_left = 'number',

    
    border_width = 'number',
    border_color = 'table',
    border_radius = 'number',
    box_shadow_color = 'table|nil',
    box_shadow_offset_x = 'number',
    box_shadow_offset_y = 'number',
    box_shadow_blur = 'number',
    box_shadow_spread = 'number',

    
    background = 'table|nil',
    background_accent = 'table|nil',
    background_accent_side = 'string',
    background_accent_size = 'number',
    background_image_color = 'table',
    color = 'table',
    hover_background = 'table|nil',
    pressed_background = 'table|nil',
    scrollbar_size = 'number',
    scrollbar_min_thumb_size = 'number',
    scrollbar_padding = 'number',
    scrollbar_track_color = 'table',
    scrollbar_thumb_color = 'table',
    scrollbar_thumb_hover_color = 'table',

    
    layout = 'string',          
    justify_content = 'string', 
    align_items = 'string',     
    align_self = 'string',      
    flex = 'number',            
    flex_wrap = 'string',       
    gap = 'number',             
    row_gap = 'number',
    column_gap = 'number',
    spring = 'boolean',         
    grid_template_columns = 'string|table',
    grid_template_rows = 'string|table',
    grid_auto_rows = 'number|string',
    grid_auto_columns = 'number|string',
    grid_column = 'number|string',
    grid_row = 'number|string',

    
    position = 'string',        
    top = 'number|string',
    right = 'number|string',
    bottom = 'number|string',
    left = 'number|string',

    
    font_size = 'number',
    font_family = 'string',
    font_weight = 'string|number', 
    font_style = 'string',      
    text_align = 'string',      
    line_height = 'number',
    text_wrap = 'boolean',
    text_overflow = 'string',
    max_lines = 'number',

    
    visible = 'boolean',
    opacity = 'number',
    z_index = 'number',
    overflow = 'string',        
    transition_duration = 'number',

    
    size_mode = 'string',       

    
    disabled = 'boolean',
    interactive = 'boolean',

    
    cursor = 'string',          
    tooltip = 'string',
    clip = 'boolean',
}


local DEFAULTS = {
    width = nil,
    height = nil,
    min_width = 0,
    min_height = 0,
    max_width = math.huge,
    max_height = math.huge,

    padding = 0,
    padding_top = nil,
    padding_right = nil,
    padding_bottom = nil,
    padding_left = nil,

    margin = 0,
    margin_top = nil,
    margin_right = nil,
    margin_bottom = nil,
    margin_left = nil,

    border_width = 0,
    border_color = {0, 0, 0, 255},
    border_radius = 0,
    box_shadow_color = nil,
    box_shadow_offset_x = 0,
    box_shadow_offset_y = 0,
    box_shadow_blur = 0,
    box_shadow_spread = 0,

    background = nil,
    background_accent = nil,
    background_accent_side = 'left',
    background_accent_size = 4,
    background_image_color = {255, 255, 255, 255},
    color = {255, 255, 255, 255},
    hover_background = nil,
    pressed_background = nil,
    scrollbar_size = 8,
    scrollbar_min_thumb_size = 24,
    scrollbar_padding = 2,
    scrollbar_track_color = {255, 255, 255, 40},
    scrollbar_thumb_color = {255, 255, 255, 120},
    scrollbar_thumb_hover_color = {255, 255, 255, 180},

    layout = 'none',
    justify_content = 'flex_start',
    align_items = 'flex_start',
    align_self = nil,
    flex = 0,
    flex_wrap = 'nowrap',
    gap = 0,
    row_gap = nil,
    column_gap = nil,
    spring = false,
    grid_template_columns = nil,
    grid_template_rows = nil,
    grid_auto_rows = 'auto',
    grid_auto_columns = '1fr',
    grid_column = nil,
    grid_row = nil,

    position = 'relative',
    top = nil,
    right = nil,
    bottom = nil,
    left = nil,

    font_size = 14,
    font_family = 'default',
    font_weight = 'normal',
    font_style = 'normal',
    text_align = 'left',
    line_height = 1.2,
    text_wrap = true,
    text_overflow = 'clip',
    max_lines = 0,

    visible = true,
    opacity = 1,
    z_index = 0,
    overflow = 'visible',
    transition_duration = 0,

    size_mode = 'content',

    disabled = false,
    interactive = false,

    cursor = 'arrow',
    tooltip = nil,
    clip = false,
}
local function validate_type(value, expected_type)
    if value == nil then return true end

    local types = {}
    for t in string.gmatch(expected_type, '([^|]+)') do
        table.insert(types, t)
    end

    local actual_type = type(value)

    
    if actual_type == 'table' then
        if table.concat(types, '|'):find('table') then return true end
        
        if #value >= 3 and #value <= 4 then
            for _, v in ipairs(value) do
                if type(v) ~= 'number' then return false end
            end
            return true
        end
    end

    for _, t in ipairs(types) do
        if actual_type == t then return true end
        
        if t == 'string' and actual_type == 'string' then return true end
        if t == 'number' and actual_type == 'number' then return true end
    end

    return false
end

local function normalize_color_value(value)
    local color = {value[1] or 0, value[2] or 0, value[3] or 0, value[4]}
    local max_component = 0

    for i = 1, 4 do
        if color[i] ~= nil and color[i] > max_component then
            max_component = color[i]
        end
    end

    if color[4] == nil then
        color[4] = max_component <= 1 and 1 or 255
    end

    if max_component <= 1 then
        return {
            color[1] * 255,
            color[2] * 255,
            color[3] * 255,
            color[4] * 255,
        }
    end

    return color
end


local function normalize_property(key, value)
    if value == nil then return nil end

    
    if type(value) == 'table' and (key:find('color') or key:find('background')) then
        return normalize_color_value(value)
    end

    
    if (key == 'padding' or key == 'margin') and type(value) == 'number' then
        return {
            top = value,
            right = value,
            bottom = value,
            left = value
        }
    end

    
    if type(value) == 'string' and value:match('^%d+%%$') then
        return {
            type = 'percentage',
            value = tonumber(value:match('(%d+)%%'))
        }
    end

    
    if (key == 'width' or key == 'height') and value == 'full' then
        return {type = 'full', value = 100}
    end

    return value
end


local function get_spacing_value(style, prop, side)
    local val = style[prop .. '_' .. side]
    if val ~= nil then return val end

    local compound = style[prop]
    if type(compound) == 'table' then
        return compound[side] or compound[1] or 0
    end
    return compound or 0
end





function Styles.new(props)
    local self = setmetatable({}, Styles)
    self._props = {}
    self._props_version = 0  

    
    for k, v in pairs(DEFAULTS) do
        if type(v) == 'table' then
            self._props[k] = {unpack(v)}
        else
            self._props[k] = v
        end
    end

    
    if props then
        self:apply(props)
    end

    return self
end




function Styles:apply(props)
    assert(type(props) == 'table', 'Styles:apply expects table')

    for key, value in pairs(props) do
        self:set(key, value)
    end

    return self
end





function Styles:set(key, value)
    
    if VALID_PROPERTIES[key] == nil then
        
        
        self._props[key] = value
        self._props_version = self._props_version + 1
        return self
    end

    
    if not validate_type(value, VALID_PROPERTIES[key]) then
        error(string.format(
            'Styles: invalid type for property "%s". Expected %s, got %s',
            key, VALID_PROPERTIES[key], type(value)
        ), 2)
    end

    
    self._props[key] = normalize_property(key, value)
    self._props_version = self._props_version + 1

    return self
end




function Styles:get(key)
    return self._props[key]
end



function Styles:to_table()
    local result = {}
    for k, v in pairs(self._props) do
        if type(v) == 'table' then
            result[k] = {unpack(v)}
        else
            result[k] = v
        end
    end
    return result
end



function Styles:get_padding()
    
    if self._cached_padding and self._padding_version == self._props_version then
        return self._cached_padding
    end

    local padding = {
        top = get_spacing_value(self._props, 'padding', 'top'),
        right = get_spacing_value(self._props, 'padding', 'right'),
        bottom = get_spacing_value(self._props, 'padding', 'bottom'),
        left = get_spacing_value(self._props, 'padding', 'left'),
    }

    
    self._cached_padding = padding
    self._padding_version = self._props_version

    return padding
end



function Styles:get_margin()
    
    if self._cached_margin and self._margin_version == self._props_version then
        return self._cached_margin
    end

    local margin = {
        top = get_spacing_value(self._props, 'margin', 'top'),
        right = get_spacing_value(self._props, 'margin', 'right'),
        bottom = get_spacing_value(self._props, 'margin', 'bottom'),
        left = get_spacing_value(self._props, 'margin', 'left'),
    }

    
    self._cached_margin = margin
    self._margin_version = self._props_version

    return margin
end




function Styles:merge(other)
    local merged = Styles.new(self._props)

    if other and other._props then
        for k, v in pairs(other._props) do
            if v ~= nil then
                if type(v) == 'table' then
                    merged._props[k] = {unpack(v)}
                else
                    merged._props[k] = v
                end
            end
        end
    end

    return merged
end


function Styles:is_width_percentage()
    local w = self._props.width
    return type(w) == 'table' and w.type == 'percentage'
end

function Styles:is_height_percentage()
    local h = self._props.height
    return type(h) == 'table' and h.type == 'percentage'
end

function Styles:is_width_full()
    local w = self._props.width
    return type(w) == 'table' and w.type == 'full'
end

function Styles:is_height_full()
    local h = self._props.height
    return type(h) == 'table' and h.type == 'full'
end




function Styles:get_background_for_state(state)
    if state == 'hover' and self._props.hover_background then
        return self._props.hover_background
    end
    if state == 'pressed' and self._props.pressed_background then
        return self._props.pressed_background
    end
    return self._props.background
end





local themes = {}
local current_theme = nil




function Styles.register_theme(name, theme)
    assert(type(theme) == 'table', 'Theme must be a table')
    themes[name] = theme
end



function Styles.set_theme(name)
    assert(themes[name], 'Theme "' .. name .. '" not found')
    current_theme = name
end




function Styles.get_theme_style(style_name)
    if not current_theme or not themes[current_theme] then
        return nil
    end
    local theme_style = themes[current_theme][style_name]
    if theme_style then
        return Styles.new(theme_style)
    end
    return nil
end

function Styles.get_theme_style_props(style_name)
    if not current_theme or not themes[current_theme] then
        return nil
    end

    local theme_style = themes[current_theme][style_name]
    if theme_style then
        return copy_value(theme_style)
    end

    return nil
end


function Styles.get_current_theme()
    return current_theme
end





Styles.DEFAULTS = DEFAULTS
Styles.VALID_PROPERTIES = VALID_PROPERTIES

return Styles
