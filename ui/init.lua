local Node = require('ui.node')
local Tree = require('ui.tree')
local Styles = require('ui.styles')
local Layout = require('ui.layout')
local Events = require('ui.events')
local Fonts = require('ui.fonts')
local Elements = require('ui.elements')

local UI = {}

function UI.container(props)
    return Elements.container(props)
end

function UI.text(text, props)
    return Elements.text(text, props)
end

function UI.button(text, props)
    return Elements.button(text, props)
end

function UI.heading(text, level)
    return Elements.heading(text, level)
end

function UI.paragraph(text)
    return Elements.paragraph(text)
end

function UI.input(placeholder, props)
    return Elements.input(placeholder, props)
end

function UI.image(path, props)
    return Elements.image(path, props)
end

function UI.divider(props)
    return Elements.divider(props)
end

function UI.divider_v(props)
    return Elements.divider_v(props)
end

function UI.progress(value, props)
    return Elements.progress(value, props)
end

function UI.checkbox(checked, label, props)
    return Elements.checkbox(checked, label, props)
end

function UI.slider(value, props)
    return Elements.slider(value, props)
end

function UI.scroll_view(props)
    return Elements.scroll_view(props)
end

function UI.card(props)
    return Elements.card(props)
end

function UI.badge(text, props)
    return Elements.badge(text, props)
end

function UI.button_small(text, props)
    return Elements.button_small(text, props)
end

function UI.button_large(text, props)
    return Elements.button_large(text, props)
end

function UI.icon_button(icon, props)
    return Elements.icon_button(icon, props)
end

function UI.spacer(size)
    return Elements.spacer(size)
end

function UI.spring(props)
    return Elements.spring(props)
end

function UI.h_spacer(width, props)
    return Elements.h_spacer(width, props)
end

function UI.v_spacer(height, props)
    return Elements.v_spacer(height, props)
end

function UI.tree(root)
    return Tree.new(root)
end

function UI.build(root_config)
    local root = Node.from_table(root_config)
    return Tree.new(root)
end

function UI.node(type, props)
    return Node.new(type, props)
end

function UI.from_table(config)
    return Node.from_table(config)
end

UI.register_font = Fonts.register
UI.preload_fonts = Fonts.preload
UI.set_default_font = Fonts.set_default
UI.set_default_font_size = Fonts.set_default_size

UI.register_theme = Styles.register_theme
UI.set_theme = Styles.set_theme
UI.get_theme_style = Styles.get_theme_style

UI.on = Events.on
UI.once = Events.once
UI.off = Events.off
UI.reset_events = Events.reset

function UI.get_slider_value(node)
    return Elements.get_slider_value(node)
end

function UI.set_slider_value(node, value)
    return Elements.set_slider_value(node, value)
end

function UI.set_progress(node, value)
    return Elements.set_progress(node, value)
end

function UI.is_checked(node)
    return Elements.is_checked(node)
end

function UI.toggle(enabled, label, props)
    return Elements.toggle(enabled, label, props)
end

function UI.modal(content, props)
    return Elements.modal(content, props)
end

function UI.dropdown(options, selected, props)
    return Elements.dropdown(options, selected, props)
end

function UI.tabs(items, active_index, props)
    return Elements.tabs(items, active_index, props)
end

function UI.splitter(first, second, props)
    return Elements.splitter(first, second, props)
end

function UI.is_toggle_on(node)
    return Elements.is_toggle_on(node)
end

function UI.on_toggle_change(node, callback)
    return Elements.on_toggle_change(node, callback)
end

function UI.custom(draw_fn, measure_fn, props)
    return Elements.custom(draw_fn, measure_fn, props)
end

function UI.version()
    return '1.0.0'
end

function UI.quick(root_config)
    local tree = UI.build(root_config)

    return {
        tree = tree,

        update = function(dt)
            tree:update()
        end,

        draw = function()
            tree:draw()
        end,

        mousemoved = function(x, y, dx, dy)
            tree:mousemoved(x, y, dx, dy)
        end,

        mousepressed = function(x, y, button)
            tree:mousepressed(x, y, button)
        end,

        mousereleased = function(x, y, button)
            tree:mousereleased(x, y, button)
        end,

        wheelmoved = function(x, y)
            tree:wheelmoved(x, y)
        end,

        keypressed = function(key)
            tree:keypressed(key)
        end,

        textinput = function(text)
            tree:textinput(text)
        end,

        get_root = function()
            return tree:get_root()
        end,

        rebuild = function()
            tree:rebuild()
        end,

        debug = function(enabled)
            tree:debug_mode(enabled)
            return tree
        end,

        stats = function()
            return tree:get_stats()
        end,
    }
end

UI.Node = Node
UI.Tree = Tree
UI.Styles = Styles
UI.Layout = Layout
UI.Events = Events
UI.Fonts = Fonts
UI.Elements = Elements

return UI
