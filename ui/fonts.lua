local Fonts = {}

local font_cache = {}         
local font_files = {}         
local default_font = nil      
local default_size = 14       


local FONT_WEIGHTS = {
    thin = 100,
    extra_light = 200,
    light = 300,
    normal = 400,
    medium = 500,
    semi_bold = 600,
    bold = 700,
    extra_bold = 800,
    black = 900,
}


local FONT_STYLES = {
    normal = 'normal',
    italic = 'italic',
}
local function make_cache_key(family, size, weight, style)
    return string.format('%s_%d_%s_%s',
        tostring(family),
        math.floor(size),
        tostring(weight),
        tostring(style)
    )
end


local function normalize_weight(weight)
    if type(weight) == 'number' then
        return weight
    end
    if type(weight) == 'string' then
        return FONT_WEIGHTS[weight] or 400
    end
    return 400
end


local function normalize_style(style)
    if type(style) == 'string' then
        return FONT_STYLES[style] or 'normal'
    end
    return 'normal'
end

local function resolve_font_path(font_entry, weight, style)
    if type(font_entry) == 'string' then
        return font_entry, (weight or 400) >= 600, style == 'italic'
    end

    if type(font_entry) ~= 'table' then
        return nil, (weight or 400) >= 600, style == 'italic'
    end

    local is_bold = (weight or 400) >= 600
    local is_italic = style == 'italic'

    if is_bold and is_italic then
        if font_entry.bold_italic then return font_entry.bold_italic, false, false end
        if font_entry.bolditalic then return font_entry.bolditalic, false, false end
        if font_entry.italic then return font_entry.italic, true, false end
        if font_entry.bold then return font_entry.bold, false, true end
        return font_entry.normal or font_entry.regular or font_entry[1], true, true
    end

    if is_bold then
        if font_entry.bold then return font_entry.bold, false, false end
        if font_entry.semi_bold then return font_entry.semi_bold, false, false end
        if font_entry.semibold then return font_entry.semibold, false, false end
        return font_entry.normal or font_entry.regular or font_entry[1], true, false
    end

    if is_italic then
        if font_entry.italic then return font_entry.italic, false, false end
        return font_entry.normal or font_entry.regular or font_entry[1], false, true
    end

    return font_entry.normal or font_entry.regular or font_entry[1], false, false
end



function Fonts.register(name, path, sizes)
    assert(type(name) == 'string', 'Font name must be a string')
    assert(type(path) == 'string' or type(path) == 'table', 'Font path must be a string or table')

    font_files[name] = path

    
    if sizes and type(sizes) == 'table' then
        for _, size in ipairs(sizes) do
            Fonts.get(name, size)
        end
    end
end




function Fonts.get(family, size, weight, style)
    size = size or default_size
    weight = normalize_weight(weight or 'normal')
    style = normalize_style(style or 'normal')

    
    local actual_family = family
    if not actual_family or actual_family == 'default' then
        actual_family = default_font
    end

    local cache_key = make_cache_key(actual_family, size, weight, style)

    
    if font_cache[cache_key] then
        local cached = font_cache[cache_key]
        return cached.font, cached.faux_bold, cached.faux_italic
    end

    
    local font
    local font_path, faux_bold, faux_italic = resolve_font_path(font_files[actual_family], weight, style)

    if font_path then
        
        local ok, result = pcall(function()
            return love.graphics.newFont(font_path, size)
        end)

        if ok and result then
            font = result
        else
            
            font = love.graphics.newFont(size)
        end
    else
        
        font = love.graphics.newFont(size)
    end

    
    font_cache[cache_key] = {
        font = font,
        faux_bold = faux_bold,
        faux_italic = faux_italic,
    }

    return font, faux_bold, faux_italic
end



function Fonts.set_default(name)
    if name then
        assert(font_files[name], 'Font "' .. name .. '" not registered')
    end
    default_font = name
end



function Fonts.set_default_size(size)
    assert(type(size) == 'number' and size > 0, 'Font size must be a positive number')
    default_size = size
end


function Fonts.get_default_size()
    return default_size
end


function Fonts.clear_cache()
    font_cache = {}
end


function Fonts.get_registered_fonts()
    local result = {}
    for name, path in pairs(font_files) do
        table.insert(result, {name = name, path = path})
    end
    return result
end





function Fonts.preload(config)
    assert(type(config) == 'table', 'Preload config must be a table')

    for _, font_config in ipairs(config) do
        Fonts.register(font_config.name, font_config.path, font_config.sizes)
    end
end





function Fonts.measure_text(text, font)
    font = font or Fonts.get(nil, default_size)
    local width = font:getWidth(text)
    local height = font:getHeight()
    return width, height
end




function Fonts.get_line_height(font)
    font = font or Fonts.get(nil, default_size)
    return font:getHeight()
end





function Fonts.from_style(style)
    local family = style:get('font_family') or 'default'
    local size = style:get('font_size') or default_size
    local weight = style:get('font_weight') or 'normal'
    local font_style = style:get('font_style') or 'normal'

    return Fonts.get(family, size, weight, font_style)
end

return Fonts
