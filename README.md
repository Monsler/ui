### Установка
положить папку ui в корень с вашей игрой/приложением

### Минимальный пример
<img width="802" height="632" alt="image" src="https://github.com/user-attachments/assets/670092f9-664a-4b60-8926-b2cfebc00b05" />

```lua
local ui = require('ui')

local root
local tree

function love.load()
    root = ui.container()
        :size_full()
        :background(30, 30, 30, 255)
        :layout_column()
        :align_items('center')
        :justify_content('center')
        :add(
            ui.container()
                :layout_column()
                :align_items('center')
                :gap(10)
                :padding(10)
                :background(100, 100, 100, 255)
                :add(
                    ui.text('hello, ui!')
                        :font_bold()
                        :font_size(26)
                )
                :add(
                    ui.container()
                        :layout_column()
                        :padding(10)
                        :border_radius(100)
                        :align_items('center')
                        :background(255, 0, 0, 255)
                        :add(
                            ui.container()
                                :layout_column()
                                :padding(10)
                                :background(0, 255, 0, 255)
                                :border_radius(100)
                                :add(
                                    ui.container()
                                        :size(10, 10)
                                        :background(0, 0, 255, 255)
                                        :border_radius(100)
                                )
                        )
                )
        )

    tree = ui.tree(root)
end

function love.update(dt)
    tree:update(dt)
end

function love.draw()
    tree:draw()
end
```
