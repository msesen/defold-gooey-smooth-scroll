# defold-gooey-smooth-scroll
A lua module that adds smooth scrolling/inertia to the lists using the official Gooey library for the Defold game engine.

# Make sure you understand how Gooey works
- https://github.com/britzl/gooey
- This module works with gooey.static, dynamic, vertical and horizontal lists.

# Installation
Place the Scroll.lua module in your project and require it at the top of your gui_script file.
``` 
local Scroll = require '[path to the module].Scroll'
```

# Usage
1. Init your list(s), e.g. inside the init() lifecycle function add the following - you can init multiple lists.
  ```
  function init(self)
    self.availableAchievementsScroll = Scroll:new()
    self.availableAchievementsScroll:init({
        parent = self,
        dynamic = true,
        data = {},
        gooyGroupName = 'availableAchievements',
        containerNodeId = 'availableContentBg',
        stencilNodeId = 'dynamiclistStencil',
        dynamicListItemId = 'availableItemContainer',
        onListUpdate = onUpdateDynamicList,
        onListItemSelect = onAvailableListClick
    })
  end
  ```

2. Listen for input events.
 ```
 function on_input(self, action_id, action)
   -- Handle lists - 
   if gui.is_enabled(self.availableAchievements) then self.availableAchievementsScroll:onInput(action, action_id) end
   if gui.is_enabled(self.completedAchievements) then self.completedAchievementsScroll:onInput(action, action_id) end
   ...
 end
 ```

3. Add the following to the update() lifecycle function
 ```
 function update(self, dt)
  -- Handle lists
  if gui.is_enabled(self.availableAchievements) then self.availableAchievementsScroll:update(dt) end
  if gui.is_enabled(self.completedAchievements) then self.completedAchievementsScroll:update(dt) end
 end
 ```

4. Optional - create any list click handlers as per usual inside the gui_script
```
self.availableAchievementsScroll:init({
      ...
      onListItemSelect = onAvailableListClick -- This is the name of the click handler function
      ...
  })

-- Example handler function inside the gui_script
local function onAvailableListClick(self, list, action)
    -- Apply any logic on the list and based on the input action
    -- e.g. go through a list of nodes to see if a specific node was touched etc.
end
```

#### Finally, don't forget to update the data property of your scroll once you have the data (e.g. fetched from an http request or loaded at a later point)
```
-- Update the list data when required.
self.availableAchievementsScroll.data = [available achievements data]
```


