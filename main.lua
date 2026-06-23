local ui = require('ui')

local root
local tree
local checkbox
local slider
local status_text

function love.load()
    root = ui.container()
    root:size_full()
    root:background(30, 30, 45, 255)
    root:layout_column()
    root:align_items('center')
    root:justify_content('center')
    root:spacing(20)

    local heading = ui.heading('ui test', 1)
    root:add(heading)

    checkbox = ui.checkbox(false, 'turbo mode')
    root:add(checkbox)

    slider = ui.slider(0.5)
    slider:width(200)
    root:add(slider)

    status_text = ui.text('click to apply', {font_size = 16})

    local button = ui.button('apply settings')
    button:size(160, 40)
    button:on_click(function()
        local is_turbo = ui.is_checked(checkbox)
        local speed = ui.get_slider_value(slider)
        status_text:text('turbo: ' .. tostring(is_turbo) .. '\nspeed: ' .. string.format('%.2f', speed))
    end)
    root:add(button)
    root:add(status_text)

    tree = ui.tree(root)
end

function love.update(dt)
    tree:update(dt)
end

function love.draw()
    tree:draw()
end

function love.mousemoved(x, y, dx, dy)
    tree:mousemoved(x, y, dx, dy)
end

function love.mousepressed(x, y, button)
    tree:mousepressed(x, y, button)
end

function love.mousereleased(x, y, button)
    tree:mousereleased(x, y, button)
end

function love.wheelmoved(x, y)
    tree:wheelmoved(x, y)
end

function love.keypressed(key)
    tree:keypressed(key)
end

function love.textinput(text)
    tree:textinput(text)
end
