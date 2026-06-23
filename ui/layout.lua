local Layout = {}

local math_max = math.max
local math_min = math.min
local math_ceil = math.ceil
local math_huge = math.huge
local table_insert = table.insert
local ipairs = ipairs
local tonumber = tonumber
local tostring = tostring

local JUSTIFY_MAP = {
    flex_start = 'start',
    flex_end = 'end',
    center = 'center',
    space_between = 'space_between',
    space_around = 'space_around',
    space_evenly = 'space_evenly',
}

local ALIGN_MAP = {
    flex_start = 'start',
    flex_end = 'end',
    center = 'center',
    stretch = 'stretch',
    baseline = 'baseline',
}

local UTF8_CHAR_PATTERN = '[%z\1-\127\194-\244][\128-\191]*'

local WRAP_BREAK_CHARS = {
    [' '] = true,
    ['\t'] = true,
    ['_'] = true,
    ['-'] = true,
    ['/'] = true,
}

local function measure_content(node, max_w)
    if node._measure_fn then
        return node:_measure_fn()
    end

    if node._text and node._font then
        local text = node._text
        local font = node._font
        local text_wrap = node._styles:get('text_wrap')
        local text_overflow = node._styles:get('text_overflow') or 'clip'
        local max_lines = node._styles:get('max_lines') or 0
        local faux_extra_w = 0
        local faux_extra_h = 0

        if node._font_faux_bold then
            faux_extra_w = faux_extra_w + 1
            faux_extra_h = faux_extra_h + 1
        end

        if node._font_faux_italic then
            faux_extra_w = faux_extra_w + math_ceil(font:getHeight() * 0.18)
        end

        local wrap_w = node._width
        if not wrap_w or wrap_w <= 0 then
            wrap_w = max_w
        end

        if wrap_w and wrap_w > faux_extra_w then
            wrap_w = wrap_w - faux_extra_w
        end

        if text_wrap and wrap_w and wrap_w > 0 then
            local lines = Layout.wrap_text(text, font, wrap_w)
            lines = Layout.apply_text_limits(lines, font, wrap_w, max_lines, text_overflow)
            local max_line_w = 0
            for _, line in ipairs(lines) do
                local lw = font:getWidth(line)
                if lw > max_line_w then max_line_w = lw end
            end
            return max_line_w + faux_extra_w, font:getHeight() * #lines + faux_extra_h
        else
            if text_overflow == 'ellipsis' and wrap_w ~= nil then
                text = Layout.truncate_text_ellipsis(text, font, wrap_w)
            end
            return font:getWidth(text) + faux_extra_w, font:getHeight() + faux_extra_h
        end
    end

    return 0, 0
end

local function clamp_size(value, min_val, max_val)
    return math_max(min_val, math_min(value, max_val))
end

local function split_text_paragraphs(text)
    local paragraphs = {}
    local start_index = 1

    while true do
        local newline_index = text:find('\n', start_index, true)
        if not newline_index then
            table_insert(paragraphs, text:sub(start_index))
            break
        end

        table_insert(paragraphs, text:sub(start_index, newline_index - 1))
        start_index = newline_index + 1
    end

    if #paragraphs == 0 then
        table_insert(paragraphs, '')
    end

    return paragraphs
end

local function tokenize_wrap_chunks(text)
    local chunks = {}
    local current_chunk = ''

    for char in text:gmatch(UTF8_CHAR_PATTERN) do
        current_chunk = current_chunk .. char
        if WRAP_BREAK_CHARS[char] then
            table_insert(chunks, current_chunk)
            current_chunk = ''
        end
    end

    if current_chunk ~= '' then
        table_insert(chunks, current_chunk)
    end

    if #chunks == 0 then
        table_insert(chunks, '')
    end

    return chunks
end

local function append_wrapped_chunk(lines, current_line, chunk, font, max_width)
    if chunk == '' then
        return current_line
    end

    if current_line == '' and chunk:match('^[ \t]+$') then
        return current_line
    end

    local test_line = current_line .. chunk
    if current_line ~= '' and font:getWidth(test_line) <= max_width then
        return test_line
    end

    if current_line == '' and font:getWidth(chunk) <= max_width then
        return chunk
    end

    if current_line ~= '' then
        table_insert(lines, current_line)
        current_line = ''
    end

    local token_part = ''
    for char in chunk:gmatch(UTF8_CHAR_PATTERN) do
        if not (token_part == '' and (char == ' ' or char == '\t')) then
            local test_part = token_part .. char
            if token_part ~= '' and font:getWidth(test_part) > max_width then
                table_insert(lines, token_part)
                token_part = (char == ' ' or char == '\t') and '' or char
            else
                token_part = test_part
            end
        end
    end

    return token_part
end

function Layout.wrap_text(text, font, max_width)
    if not text or text == '' then return {''} end

    local lines = {}
    local paragraphs = split_text_paragraphs(text)

    for _, paragraph in ipairs(paragraphs) do
        local current_line = ''
        local chunks = tokenize_wrap_chunks(paragraph)

        for _, chunk in ipairs(chunks) do
            current_line = append_wrapped_chunk(lines, current_line, chunk, font, max_width)
        end

        table_insert(lines, current_line)
    end

    if #lines == 0 then
        table_insert(lines, '')
    end

    return lines
end

function Layout.truncate_text_ellipsis(text, font, max_width)
    if not text or text == '' then
        return ''
    end

    if not max_width or max_width <= 0 then
        return ''
    end

    if font:getWidth(text) <= max_width then
        return text
    end

    local ellipsis = '...'
    local ellipsis_w = font:getWidth(ellipsis)
    if ellipsis_w > max_width then
        return ''
    end

    local chars = {}
    for char in text:gmatch(UTF8_CHAR_PATTERN) do
        table_insert(chars, char)
    end

    local low = 0
    local high = #chars
    local best = ellipsis

    while low <= high do
        local mid = math.floor((low + high) / 2)
        local candidate = table.concat(chars, '', 1, mid) .. ellipsis

        if font:getWidth(candidate) <= max_width then
            best = candidate
            low = mid + 1
        else
            high = mid - 1
        end
    end

    return best
end

function Layout.apply_text_limits(lines, font, max_width, max_lines, text_overflow)
    if not max_lines or max_lines <= 0 or #lines <= max_lines then
        return lines
    end

    local limited = {}
    for i = 1, max_lines do
        limited[i] = lines[i] or ''
    end

    if text_overflow == 'ellipsis' and max_lines >= 1 then
        limited[max_lines] = Layout.truncate_text_ellipsis(
            limited[max_lines] or '',
            font,
            max_width
        )
    end

    return limited
end

local function parse_grid_tracks(template)
    local tracks = {}
    if template == nil then
        return tracks
    end

    if type(template) == 'table' then
        for _, token in ipairs(template) do
            table_insert(tracks, tostring(token))
        end
        return tracks
    end

    for token in tostring(template):gmatch('%S+') do
        table_insert(tracks, token)
    end

    return tracks
end

local function parse_grid_track_token(token)
    if type(token) == 'number' then
        return {type = 'px', value = token}
    end

    token = tostring(token or 'auto')
    if token == 'auto' then
        return {type = 'auto', value = 0}
    end

    local px = token:match('^(%-?[%d%.]+)px$')
    if px then
        return {type = 'px', value = tonumber(px) or 0}
    end

    local fr = token:match('^(%-?[%d%.]+)fr$')
    if fr then
        return {type = 'fr', value = tonumber(fr) or 1}
    end

    local pct = token:match('^(%-?[%d%.]+)%%$')
    if pct then
        return {type = 'percentage', value = tonumber(pct) or 0}
    end

    return {type = 'px', value = tonumber(token) or 0}
end

local function parse_grid_line_range(value)
    if value == nil then
        return nil, nil
    end

    if type(value) == 'number' then
        local start_line = math_max(1, math.floor(value))
        return start_line, start_line + 1
    end

    local raw = tostring(value)
    local start_str, end_str = raw:match('^%s*(%d+)%s*/%s*(%d+)%s*$')
    if start_str and end_str then
        local start_line = math_max(1, tonumber(start_str) or 1)
        local end_line = math_max(start_line + 1, tonumber(end_str) or (start_line + 1))
        return start_line, end_line
    end

    local line = tonumber(raw:match('^%s*(%d+)%s*$'))
    if line then
        line = math_max(1, line)
        return line, line + 1
    end

    return nil, nil
end

local function ensure_track_count(tracks, count, auto_token)
    while #tracks < count do
        table_insert(tracks, auto_token or 'auto')
    end
end

local function ensure_occupancy_row(occupancy, row)
    if not occupancy[row] then
        occupancy[row] = {}
    end
    return occupancy[row]
end

local function can_place_grid_item(occupancy, row, col, row_span, col_span)
    for r = row, row + row_span - 1 do
        local row_map = occupancy[r]
        if row_map then
            for c = col, col + col_span - 1 do
                if row_map[c] then
                    return false
                end
            end
        end
    end
    return true
end

local function occupy_grid_item(occupancy, row, col, row_span, col_span)
    for r = row, row + row_span - 1 do
        local row_map = ensure_occupancy_row(occupancy, r)
        for c = col, col + col_span - 1 do
            row_map[c] = true
        end
    end
end

local function place_grid_child(occupancy, cursor_row, cursor_col, col_count, wanted_row, wanted_col, row_span, col_span)
    row_span = math_max(1, row_span or 1)
    col_span = math_max(1, col_span or 1)

    if wanted_row and wanted_col then
        occupy_grid_item(occupancy, wanted_row, wanted_col, row_span, col_span)
        return wanted_row, wanted_col
    end

    if wanted_row then
        local col = 1
        while true do
            if can_place_grid_item(occupancy, wanted_row, col, row_span, col_span) then
                occupy_grid_item(occupancy, wanted_row, col, row_span, col_span)
                return wanted_row, col
            end
            col = col + 1
        end
    end

    if wanted_col then
        local row = 1
        while true do
            if can_place_grid_item(occupancy, row, wanted_col, row_span, col_span) then
                occupy_grid_item(occupancy, row, wanted_col, row_span, col_span)
                return row, wanted_col
            end
            row = row + 1
        end
    end

    local row = cursor_row or 1
    local col = cursor_col or 1
    local max_cols = math_max(1, col_count)

    while true do
        if col + col_span - 1 <= max_cols and can_place_grid_item(occupancy, row, col, row_span, col_span) then
            occupy_grid_item(occupancy, row, col, row_span, col_span)
            return row, col
        end

        col = col + 1
        if col > max_cols then
            row = row + 1
            col = 1
        end
    end
end

local function resolve_grid_track_sizes(track_defs, available_size, auto_sizes, gap)
    local sizes = {}
    local fixed_total = 0
    local fr_total = 0
    local fr_indices = {}

    for i, token in ipairs(track_defs) do
        local def = parse_grid_track_token(token)
        if def.type == 'px' then
            sizes[i] = math_max(0, def.value)
            fixed_total = fixed_total + sizes[i]
        elseif def.type == 'percentage' then
            sizes[i] = math_max(0, available_size * def.value / 100)
            fixed_total = fixed_total + sizes[i]
        elseif def.type == 'auto' then
            sizes[i] = math_max(0, auto_sizes[i] or 0)
            fixed_total = fixed_total + sizes[i]
        elseif def.type == 'fr' then
            sizes[i] = 0
            fr_total = fr_total + math_max(0, def.value)
            table_insert(fr_indices, {index = i, value = math_max(0, def.value)})
        end
    end

    local total_gap = gap * math_max(0, #track_defs - 1)
    local remaining = math_max(0, available_size - fixed_total - total_gap)

    if fr_total > 0 then
        for _, fr in ipairs(fr_indices) do
            sizes[fr.index] = remaining * (fr.value / fr_total)
        end
    end

    return sizes
end

local function sum_grid_span(track_sizes, start_index, span, gap)
    local total = 0
    local last_index = start_index + span - 1
    for i = start_index, last_index do
        total = total + (track_sizes[i] or 0)
        if i < last_index then
            total = total + gap
        end
    end
    return total
end

local function is_node_visible(node)
    return node and node._styles and node._styles:get('visible') ~= false
end

local function collect_visible_children(children)
    local visible_children = {}
    for _, child in ipairs(children or {}) do
        if is_node_visible(child) then
            table_insert(visible_children, child)
        end
    end
    return visible_children
end

local function build_grid_model(node, available_w, available_h)
    local styles = node._styles
    local children = collect_visible_children(node._children)
    local gap = styles:get('gap') or 0
    local row_gap = styles:get('row_gap') or gap
    local column_gap = styles:get('column_gap') or gap

    local col_tracks = parse_grid_tracks(styles:get('grid_template_columns'))
    local row_tracks = parse_grid_tracks(styles:get('grid_template_rows'))
    local auto_col_token = styles:get('grid_auto_columns') or '1fr'
    local auto_row_token = styles:get('grid_auto_rows') or 'auto'

    if #col_tracks == 0 then
        table_insert(col_tracks, auto_col_token)
    end

    local placements = {}
    local occupancy = {}
    local cursor_row = 1
    local cursor_col = 1
    local max_row = 0
    local max_col = #col_tracks

    for _, child in ipairs(children) do
        local child_styles = child._styles
        local col_start, col_end = parse_grid_line_range(child_styles:get('grid_column'))
        local row_start, row_end = parse_grid_line_range(child_styles:get('grid_row'))
        local col_span = math_max(1, (col_end or ((col_start or 1) + 1)) - (col_start or 1))
        local row_span = math_max(1, (row_end or ((row_start or 1) + 1)) - (row_start or 1))

        ensure_track_count(col_tracks, math_max(#col_tracks, (col_start or 1) + col_span - 1), auto_col_token)
        if row_start then
            ensure_track_count(row_tracks, math_max(#row_tracks, row_start + row_span - 1), auto_row_token)
        end

        local placed_row, placed_col = place_grid_child(
            occupancy,
            cursor_row,
            cursor_col,
            #col_tracks,
            row_start,
            col_start,
            row_span,
            col_span
        )

        placements[child] = {
            row = placed_row,
            col = placed_col,
            row_span = row_span,
            col_span = col_span,
        }

        max_row = math_max(max_row, placed_row + row_span - 1)
        max_col = math_max(max_col, placed_col + col_span - 1)

        if not row_start and not col_start then
            cursor_row = placed_row
            cursor_col = placed_col + col_span
            if cursor_col > #col_tracks then
                cursor_row = cursor_row + 1
                cursor_col = 1
            end
        end
    end

    ensure_track_count(col_tracks, max_col, auto_col_token)
    ensure_track_count(row_tracks, math_max(1, max_row), auto_row_token)

    local auto_col_sizes = {}
    local auto_row_sizes = {}

    for child, placement in pairs(placements) do
        local margin = child._styles:get_margin()
        local child_w = (child._width or 0) + margin.left + margin.right
        local child_h = (child._height or 0) + margin.top + margin.bottom

        if placement.col_span == 1 then
            auto_col_sizes[placement.col] = math_max(auto_col_sizes[placement.col] or 0, child_w)
        else
            local per_col_w = math_max(0, (child_w - column_gap * (placement.col_span - 1)) / placement.col_span)
            for col = placement.col, placement.col + placement.col_span - 1 do
                auto_col_sizes[col] = math_max(auto_col_sizes[col] or 0, per_col_w)
            end
        end
        if placement.row_span == 1 then
            auto_row_sizes[placement.row] = math_max(auto_row_sizes[placement.row] or 0, child_h)
        else
            local per_row_h = math_max(0, (child_h - row_gap * (placement.row_span - 1)) / placement.row_span)
            for row = placement.row, placement.row + placement.row_span - 1 do
                auto_row_sizes[row] = math_max(auto_row_sizes[row] or 0, per_row_h)
            end
        end
    end

    local col_sizes = resolve_grid_track_sizes(col_tracks, available_w, auto_col_sizes, column_gap)
    local row_sizes = resolve_grid_track_sizes(row_tracks, available_h, auto_row_sizes, row_gap)

    return {
        placements = placements,
        col_sizes = col_sizes,
        row_sizes = row_sizes,
        column_gap = column_gap,
        row_gap = row_gap,
    }
end

function Layout.compute(root, parent_x, parent_y, parent_w, parent_h)
    if not root or not root._styles then return end

    local styles = root._styles

    if styles:get('visible') == false then
        root._width = 0
        root._height = 0
        return
    end

    Layout.measure(root, parent_w, parent_h)

    Layout.position(root, parent_x, parent_y, parent_w, parent_h)
end

function Layout.measure(node, available_w, available_h)
    if not node or not node._styles then return end

    local styles = node._styles
    if styles:get('visible') == false then
        node._width = 0
        node._height = 0
        node._grid_model = nil
        return
    end

    local layout_type = styles:get('layout')

    local width, height = Layout.resolve_node_size(node, available_w, available_h)

    node._width = width
    node._height = height

    if node._children and #node._children > 0 then
        local padding = styles:get_padding()
        local content_w = math_max(0, width - padding.left - padding.right)
        local content_h = math_max(0, height - padding.top - padding.bottom)

        local measure_w = content_w > 0 and content_w or available_w - padding.left - padding.right
        local measure_h = content_h > 0 and content_h or available_h - padding.top - padding.bottom
        measure_w = math_max(0, measure_w)
        measure_h = math_max(0, measure_h)

        if layout_type == 'row' then
            Layout.measure_row(node, measure_w, measure_h)
        elseif layout_type == 'column' then
            Layout.measure_column(node, measure_w, measure_h)
        elseif layout_type == 'grid' then
            Layout.measure_grid(node, measure_w, measure_h)
        else
            for _, child in ipairs(node._children) do
                Layout.measure(child, measure_w, measure_h)
            end
        end
    end
end

function Layout.resolve_node_size(node, available_w, available_h)
    local styles = node._styles
    local margin = styles:get_margin()

    local avail_w = math_max(0, available_w - margin.left - margin.right)
    local avail_h = math_max(0, available_h - margin.top - margin.bottom)

    local width = styles:get('width')
    if type(width) == 'table' then
        if width.type == 'percentage' then
            width = avail_w * (width.value / 100)
        elseif width.type == 'full' then
            width = avail_w
        end
    elseif width == nil then
        width = nil
    end

    local height = styles:get('height')
    if type(height) == 'table' then
        if height.type == 'percentage' then
            height = avail_h * (height.value / 100)
        elseif height.type == 'full' then
            height = avail_h
        end
    elseif height == nil then
        height = nil
    end

    local width_from_content = width == nil
    local height_from_content = height == nil

    if width_from_content or height_from_content then
        local content_w, content_h = measure_content(node, available_w)

        if width_from_content then
            width = content_w
        end
        if height_from_content then
            height = content_h
        end
    end

    local padding = styles:get_padding()
    if width_from_content then
        width = width + padding.left + padding.right
    end
    if height_from_content then
        height = height + padding.top + padding.bottom
    end

    local min_w = styles:get('min_width') or 0
    local min_h = styles:get('min_height') or 0
    local max_w = styles:get('max_width') or math_huge
    local max_h = styles:get('max_height') or math_huge

    width = clamp_size(width, min_w, max_w)
    height = clamp_size(height, min_h, max_h)

    return width, height
end

function Layout.measure_row(node, available_w, available_h)
    local styles = node._styles
    local all_children = node._children or {}
    local gap = styles:get('gap') or 0
    local column_gap = styles:get('column_gap') or gap
    local wrap = styles:get('flex_wrap') or 'nowrap'

    for _, child in ipairs(all_children) do
        Layout.measure(child, available_w, available_h)
    end

    local children = collect_visible_children(all_children)

    if wrap == 'wrap' then
        local lines = {}
        local current_line = {}
        local current_line_w = 0
        local max_child_h = 0

        for _, child in ipairs(children) do
            local child_styles = child._styles
            local margin = child_styles:get_margin()
            local child_w = (child._width or 0) + margin.left + margin.right
            local child_h = (child._height or 0) + margin.top + margin.bottom

            local would_width = current_line_w + child_w + (#current_line > 0 and column_gap or 0)

            if would_width > available_w and #current_line > 0 then
                table_insert(lines, {
                    children = current_line,
                    width = current_line_w,
                    height = max_child_h
                })
                current_line = {child}
                current_line_w = child_w
                max_child_h = child_h
            else
                table_insert(current_line, child)
                current_line_w = would_width
                max_child_h = math_max(max_child_h, child_h)
            end
        end

        if #current_line > 0 then
            table_insert(lines, {
                children = current_line,
                width = current_line_w,
                height = max_child_h
            })
        end

        local total_h = 0
        local max_w = 0

        for _, line in ipairs(lines) do
            local line_fixed_w = 0
            local line_flex_total = 0
            local line_flex_children = {}
            local line_spring_children = {}
            local line_max_h = 0

            for _, child in ipairs(line.children) do
                local child_styles = child._styles
                local flex = child_styles:get('flex') or 0
                local is_spring = child_styles:get('spring') or false
                local margin = child_styles:get_margin()

                if is_spring then
                    table_insert(line_spring_children, {node = child, flex = 1})
                    line_flex_total = line_flex_total + 1
                    line_fixed_w = line_fixed_w + margin.left + margin.right
                elseif flex > 0 then
                    line_flex_total = line_flex_total + flex
                    table_insert(line_flex_children, {node = child, flex = flex})
                    line_fixed_w = line_fixed_w + margin.left + margin.right
                else
                    line_fixed_w = line_fixed_w + (child._width or 0) + margin.left + margin.right
                end
                line_max_h = math_max(line_max_h, (child._height or 0) + margin.top + margin.bottom)
            end

            local line_gap = column_gap * math_max(0, #line.children - 1)
            local line_remaining = available_w - line_fixed_w - line_gap

            if line_flex_total > 0 and line_remaining > 0 then
                for _, sc in ipairs(line_spring_children) do
                    local share = line_remaining * (sc.flex / line_flex_total)
                    sc.node._width = math_max(sc.node._width or 0, share)
                end
                for _, fc in ipairs(line_flex_children) do
                    local share = line_remaining * (fc.flex / line_flex_total)
                    fc.node._width = math_max(fc.node._width or 0, share)
                end
            end

            total_h = total_h + line.height + (#lines > 1 and gap or 0)
            max_w = math_max(max_w, line.width)
        end

        if node._type ~= 'scroll_view' then
            local pad = styles:get_padding()
            node._width = math_max(node._width or 0, max_w + pad.left + pad.right)
            node._height = math_max(node._height or 0, total_h + pad.top + pad.bottom)
        end
    else
        local fixed_width = 0
        local flex_total = 0
        local flex_children = {}
        local spring_children = {}
        local max_child_h = 0

        for _, child in ipairs(children) do
            local child_styles = child._styles
            local flex = child_styles:get('flex') or 0
            local is_spring = child_styles:get('spring') or false
            local margin = child_styles:get_margin()

            if is_spring then
                table_insert(spring_children, {node = child, flex = 1})
                flex_total = flex_total + 1
                fixed_width = fixed_width + margin.left + margin.right
            elseif flex > 0 then
                flex_total = flex_total + flex
                table_insert(flex_children, {node = child, flex = flex})
                fixed_width = fixed_width + margin.left + margin.right
            else
                fixed_width = fixed_width + (child._width or 0) + margin.left + margin.right
            end
            max_child_h = math_max(max_child_h, (child._height or 0) + margin.top + margin.bottom)
        end

        local total_gap = column_gap * math_max(0, #children - 1)
        local remaining = available_w - fixed_width - total_gap

        if flex_total > 0 and remaining > 0 then
            for _, sc in ipairs(spring_children) do
                local share = remaining * (sc.flex / flex_total)
                sc.node._width = math_max(sc.node._width or 0, share)
            end
            for _, fc in ipairs(flex_children) do
                local share = remaining * (fc.flex / flex_total)
                fc.node._width = math_max(fc.node._width or 0, share)
            end
        end

        if node._type ~= 'scroll_view' then
            local total_w = fixed_width + total_gap
            if flex_total > 0 and remaining > 0 then
                total_w = available_w
            end
            local pad = styles:get_padding()
            node._width = math_max(node._width or 0, total_w + pad.left + pad.right)
            node._height = math_max(node._height or 0, max_child_h + pad.top + pad.bottom)
        end
    end
end

function Layout.measure_column(node, available_w, available_h)
    local styles = node._styles
    local all_children = node._children or {}
    local gap = styles:get('gap') or 0
    local row_gap = styles:get('row_gap') or gap

    for _, child in ipairs(all_children) do
        Layout.measure(child, available_w, available_h)
    end

    local children = collect_visible_children(all_children)

    local fixed_height = 0
    local flex_total = 0
    local flex_children = {}
    local spring_children = {}
    local max_child_w = 0

    for _, child in ipairs(children) do
        local child_styles = child._styles
        local flex = child_styles:get('flex') or 0
        local is_spring = child_styles:get('spring') or false
        local margin = child_styles:get_margin()

        if is_spring then
            table_insert(spring_children, {node = child, flex = 1})
            flex_total = flex_total + 1
            fixed_height = fixed_height + margin.top + margin.bottom
        elseif flex > 0 then
            flex_total = flex_total + flex
            table_insert(flex_children, {node = child, flex = flex})
            fixed_height = fixed_height + margin.top + margin.bottom
        else
            fixed_height = fixed_height + (child._height or 0) + margin.top + margin.bottom
        end
        max_child_w = math_max(max_child_w, (child._width or 0) + margin.left + margin.right)
    end

    local total_gap = row_gap * math_max(0, #children - 1)
    local remaining = available_h - fixed_height - total_gap

    if flex_total > 0 and remaining > 0 then
        for _, sc in ipairs(spring_children) do
            local share = remaining * (sc.flex / flex_total)
            sc.node._height = math_max(sc.node._height or 0, share)
        end
        for _, fc in ipairs(flex_children) do
            local share = remaining * (fc.flex / flex_total)
            fc.node._height = math_max(fc.node._height or 0, share)
        end
    end

    local total_h = fixed_height + total_gap
    if flex_total > 0 and remaining > 0 then
        total_h = available_h
    end
    if node._type ~= 'scroll_view' then
        local pad = styles:get_padding()
        node._width = math_max(node._width or 0, max_child_w + pad.left + pad.right)
        node._height = math_max(node._height or 0, total_h + pad.top + pad.bottom)
    end
end

function Layout.measure_grid(node, available_w, available_h)
    local styles = node._styles
    local children = node._children or {}

    for _, child in ipairs(children) do
        Layout.measure(child, available_w, available_h)
    end

    local grid_model = build_grid_model(node, available_w, available_h)
    node._grid_model = grid_model

    local content_w = 0
    for i, track_w in ipairs(grid_model.col_sizes) do
        content_w = content_w + track_w
        if i < #grid_model.col_sizes then
            content_w = content_w + grid_model.column_gap
        end
    end

    local content_h = 0
    for i, track_h in ipairs(grid_model.row_sizes) do
        content_h = content_h + track_h
        if i < #grid_model.row_sizes then
            content_h = content_h + grid_model.row_gap
        end
    end

    if node._type ~= 'scroll_view' then
        local pad = styles:get_padding()
        node._width = math_max(node._width or 0, content_w + pad.left + pad.right)
        node._height = math_max(node._height or 0, content_h + pad.top + pad.bottom)
    end
end

function Layout.position(node, x, y, parent_w, parent_h)
    if not node or not node._styles then return end

    local styles = node._styles
    if styles:get('visible') == false then
        node._x = x
        node._y = y
        return
    end

    local layout_type = styles:get('layout')

    local margin = styles:get_margin()
    local final_x = x + margin.left
    local final_y = y + margin.top

    local position = styles:get('position')
    if position == 'absolute' then
        local top = styles:get('top')
        local right = styles:get('right')
        local bottom = styles:get('bottom')
        local left = styles:get('left')

        if top then final_y = y + (type(top) == 'number' and top or 0) end
        if left then final_x = x + (type(left) == 'number' and left or 0) end
        if right then final_x = x + parent_w - (node._width or 0) - (type(right) == 'number' and right or 0) end
        if bottom then final_y = y + parent_h - (node._height or 0) - (type(bottom) == 'number' and bottom or 0) end
        if not top and not bottom then
            final_y = node._y ~= 0 and node._y or y
        end
        if not left and not right then
            final_x = node._x ~= 0 and node._x or x
        end
    end

    node._x = final_x
    node._y = final_y

    if node._children and #node._children > 0 then
        local padding = styles:get_padding()
        local content_x = final_x + padding.left
        local content_y = final_y + padding.top
        local content_w = (node._width or 0) - padding.left - padding.right
        local content_h = (node._height or 0) - padding.top - padding.bottom

        if layout_type == 'row' then
            Layout.position_row(node, content_x, content_y, content_w, content_h)
        elseif layout_type == 'column' then
            Layout.position_column(node, content_x, content_y, content_w, content_h)
        elseif layout_type == 'grid' then
            Layout.position_grid(node, content_x, content_y, content_w, content_h)
        else
            for _, child in ipairs(node._children) do
                Layout.position(child, content_x, content_y, content_w, content_h)
            end
        end
    end
end

function Layout.position_row(node, x, y, w, h)
    local styles = node._styles
    local children = collect_visible_children(node._children)
    local gap = styles:get('gap') or 0
    local column_gap = styles:get('column_gap') or gap
    local justify = styles:get('justify_content') or 'flex_start'
    local align = styles:get('align_items') or 'flex_start'
    local wrap = styles:get('flex_wrap') or 'nowrap'

    if wrap == 'wrap' then
        local lines = {}
        local current_line = {}
        local current_line_w = 0
        local max_child_h = 0

        for _, child in ipairs(children) do
            local margin = child._styles:get_margin()
            local child_w = (child._width or 0) + margin.left + margin.right
            local child_h = (child._height or 0) + margin.top + margin.bottom

            local would_width = current_line_w + child_w + (#current_line > 0 and column_gap or 0)

            if would_width > w and #current_line > 0 then
                table_insert(lines, {
                    children = current_line,
                    width = current_line_w,
                    height = max_child_h
                })
                current_line = {child}
                current_line_w = child_w
                max_child_h = child_h
            else
                table_insert(current_line, child)
                current_line_w = would_width
                max_child_h = math_max(max_child_h, child_h)
            end
        end

        if #current_line > 0 then
            table_insert(lines, {
                children = current_line,
                width = current_line_w,
                height = max_child_h
            })
        end

        local current_y = y
        for line_idx, line in ipairs(lines) do
            local total_line_w = 0
            for _, child in ipairs(line.children) do
                local margin = child._styles:get_margin()
                total_line_w = total_line_w + (child._width or 0) + margin.left + margin.right
            end
            total_line_w = total_line_w + column_gap * math_max(0, #line.children - 1)

            local start_x = x
            if justify == 'center' then
                start_x = x + (w - total_line_w) / 2
            elseif justify == 'flex_end' then
                start_x = x + w - total_line_w
            end

            local current_x = start_x
            for i, child in ipairs(line.children) do
                local child_align = child._styles:get('align_self') or align
                local child_w = child._width or 0
                local child_h = child._height or 0

                local child_y = current_y
                local margin = child._styles:get_margin()
                if child_align == 'center' then
                    child_y = current_y + (line.height - (child_h + margin.top + margin.bottom)) / 2
                elseif child_align == 'flex_end' then
                    child_y = current_y + line.height - (child_h + margin.top + margin.bottom)
                elseif child_align == 'stretch' then
                    child_y = current_y
                    child_h = math_max(0, line.height - margin.top - margin.bottom)
                    child._height = child_h
                end

                Layout.position(child, current_x, child_y, child_w, child_h)
                if i < #line.children then
                    current_x = current_x + child_w + margin.left + margin.right + column_gap
                else
                    current_x = current_x + child_w + margin.left + margin.right
                end
            end

            current_y = current_y + line.height + gap
        end
    else
        local total_children_w = 0
        for _, child in ipairs(children) do
            local margin = child._styles:get_margin()
            total_children_w = total_children_w + (child._width or 0) + margin.left + margin.right
        end
        total_children_w = total_children_w + column_gap * math_max(0, #children - 1)

        local start_x = x
        local space_between = 0

        if justify == 'center' then
            start_x = x + (w - total_children_w) / 2
        elseif justify == 'flex_end' then
            start_x = x + w - total_children_w
        elseif justify == 'space_between' and #children > 1 then
            local children_only_w = total_children_w - column_gap * math_max(0, #children - 1)
            space_between = (w - children_only_w) / (#children - 1)
        elseif justify == 'space_around' and #children > 1 then
            local children_only_w = total_children_w - column_gap * math_max(0, #children - 1)
            space_between = (w - children_only_w) / #children
            start_x = x + space_between / 2
        elseif justify == 'space_evenly' and #children > 1 then
            space_between = (w - total_children_w) / (#children + 1)
            start_x = x + space_between
        end

        local current_x = start_x
        for i, child in ipairs(children) do
            local child_styles = child._styles
            local child_align = child_styles:get('align_self') or align

            local child_w = child._width or 0
            local child_h = child._height or 0

            local child_y = y
            local margin = child_styles:get_margin()
            if child_align == 'center' then
                child_y = y + (h - (child_h + margin.top + margin.bottom)) / 2
            elseif child_align == 'flex_end' then
                child_y = y + h - (child_h + margin.top + margin.bottom)
            elseif child_align == 'stretch' then
                child_y = y
                child_h = math_max(0, h - margin.top - margin.bottom)
                child._height = child_h
            end

            local child_x = current_x

            Layout.position(child, child_x, child_y, child_w, child_h)
            if i < #children then
                current_x = current_x + child_w + margin.left + margin.right + column_gap + space_between
            else
                current_x = current_x + child_w + margin.left + margin.right
            end
        end
    end
end

function Layout.position_column(node, x, y, w, h)
    local styles = node._styles
    local children = collect_visible_children(node._children)
    local gap = styles:get('gap') or 0
    local row_gap = styles:get('row_gap') or gap
    local justify = styles:get('justify_content') or 'flex_start'
    local align = styles:get('align_items') or 'flex_start'

    local total_children_h = 0
    for _, child in ipairs(children) do
        local margin = child._styles:get_margin()
        total_children_h = total_children_h + (child._height or 0) + margin.top + margin.bottom
    end
    total_children_h = total_children_h + row_gap * math_max(0, #children - 1)

    local start_y = y
    local space_between = 0

    if justify == 'center' then
        start_y = y + (h - total_children_h) / 2
    elseif justify == 'flex_end' then
        start_y = y + h - total_children_h
    elseif justify == 'space_between' and #children > 1 then
        local children_only_h = total_children_h - row_gap * math_max(0, #children - 1)
        space_between = (h - children_only_h) / (#children - 1)
    elseif justify == 'space_around' and #children > 1 then
        local children_only_h = total_children_h - row_gap * math_max(0, #children - 1)
        space_between = (h - children_only_h) / #children
        start_y = y + space_between / 2
    elseif justify == 'space_evenly' and #children > 1 then
        space_between = (h - total_children_h) / (#children + 1)
        start_y = y + space_between
    end

    local current_y = start_y
    for i, child in ipairs(children) do
        local child_styles = child._styles
        local child_align = child_styles:get('align_self') or align

        local child_w = child._width or 0
        local child_h = child._height or 0

        local child_x = x
        local margin = child_styles:get_margin()
        if child_align == 'center' then
            child_x = x + (w - (child_w + margin.left + margin.right)) / 2
        elseif child_align == 'flex_end' then
            child_x = x + w - (child_w + margin.left + margin.right)
        elseif child_align == 'stretch' then
            child_x = x
            child_w = math_max(0, w - margin.left - margin.right)
            child._width = child_w
        end

        local child_y = current_y

        Layout.position(child, child_x, child_y, child_w, child_h)
        if i < #children then
            current_y = current_y + child_h + margin.top + margin.bottom + row_gap + space_between
        else
            current_y = current_y + child_h + margin.top + margin.bottom
        end
    end
end

function Layout.position_grid(node, x, y, w, h)
    local styles = node._styles
    local children = collect_visible_children(node._children)
    local align = styles:get('align_items') or 'stretch'
    local justify = styles:get('justify_content') or 'stretch'

    local grid_model = node._grid_model or build_grid_model(node, w, h)
    node._grid_model = grid_model

    local col_offsets = {}
    local row_offsets = {}
    local current_x = x
    local current_y = y

    for i, track_w in ipairs(grid_model.col_sizes) do
        col_offsets[i] = current_x
        current_x = current_x + track_w + grid_model.column_gap
    end

    for i, track_h in ipairs(grid_model.row_sizes) do
        row_offsets[i] = current_y
        current_y = current_y + track_h + grid_model.row_gap
    end

    for _, child in ipairs(children) do
        local placement = grid_model.placements[child]
        if placement then
            local child_styles = child._styles
            local margin = child_styles:get_margin()
            local child_align = child_styles:get('align_self') or align

            local cell_x = col_offsets[placement.col] or x
            local cell_y = row_offsets[placement.row] or y
            local cell_w = sum_grid_span(grid_model.col_sizes, placement.col, placement.col_span, grid_model.column_gap)
            local cell_h = sum_grid_span(grid_model.row_sizes, placement.row, placement.row_span, grid_model.row_gap)

            local inner_x = cell_x + margin.left
            local inner_y = cell_y + margin.top
            local inner_w = math_max(0, cell_w - margin.left - margin.right)
            local inner_h = math_max(0, cell_h - margin.top - margin.bottom)

            local child_w = child._width or 0
            local child_h = child._height or 0

            if child_styles:is_width_full() or justify == 'stretch' then
                child_w = inner_w
                child._width = inner_w
            elseif justify == 'center' then
                inner_x = inner_x + (inner_w - child_w) / 2
            elseif justify == 'flex_end' then
                inner_x = inner_x + inner_w - child_w
            end

            if child_styles:is_height_full() or child_align == 'stretch' then
                child_h = inner_h
                child._height = inner_h
            elseif child_align == 'center' then
                inner_y = inner_y + (inner_h - child_h) / 2
            elseif child_align == 'flex_end' then
                inner_y = inner_y + inner_h - child_h
            end

            Layout.measure(child, child_w, child_h)
            Layout.position(child, inner_x - margin.left, inner_y - margin.top, child_w, child_h)
        end
    end
end

return Layout
