# Core API

This page documents the core functionality of SimpleDialogue.

## SimpleDialogue

The main module that provides dialogue creation and management capabilities.

### Methods

#### `SimpleDialogue.new(model)`

Creates a new dialogue controller attached to the specified model.

**Parameters:**
- `model`: The NPC model (Instance)

**Returns:**
- A dialogue controller instance

**Example:**
```lua
local dialogue = SimpleDialogue.new(npcModel)
```

#### `SimpleDialogue.CreateNode(text, options)`

Creates a dialogue node with the specified text and options.

**Parameters:**

- `text`: The NPC's dialogue text (string)

- `options`: Array of options created with `SimpleDialogue.CreateOption()`

**Returns:**
- A dialogue node object

**Example:**
```lua
local node = SimpleDialogue.CreateNode("Hello! How can I help you?", {
    SimpleDialogue.CreateOption("Option 1", callback),
    SimpleDialogue.CreateOption("Option 2", callback)
})
```

#### `SimpleDialogue.CreateAutoNode(text, callback, shouldEndDialogue)`

Creates a dialogue node with the specified text and options.

**Parameters:**

- `text`: The NPC's dialogue text (string)

- `callback`: Function to call when the dialogue text is fully shown.

- `shouldEndDialogue`: A boolean to let the controller know whether if it should automatically end the dialogue after the callback has been ran.

**Returns:**
- A dialogue node object

**Example:**
```lua
local node = SimpleDialogue.CreateAutoNode("Hello! How can I help you?", function()
    task.spawn(5)
    dialogue:EndDialogue()
end, false)
```

#### `SimpleDialogue.CreateOption(text, callback, next, displayText)`

Creates a dialogue option for a node.

**Parameters:**

- `text`: The text displayed for this option (string)

- `callback`: Function to call when this option is selected (function, optional)

- `next`: Index of the next node to display, or -1 to end dialogue (number, optional, defaults to -1)

- `displayText`: Text to display from the NPC after selecting this option (string, optional)

**Returns:**
- A dialogue option object

**Example:**
```lua
local option = SimpleDialogue.CreateOption("Tell me more", function()
    print("Player chose to learn more")
end, 2, "I'm glad you're interested!")
```

#### `SimpleDialogue.CreateCondition(condition, item, failCallback)`

Creates a dialogue option for a node.

**Parameters:**

- `condition`: The condition to be met (boolean | function)

- `item`: The item the condition is about (DialogueNode | DialogueOption)

- `failCallback`: Callback function if a node failed to open (function, optional)

**Returns:**
- A dialogue option object

**Example:**
```lua
local beenHereBefore = false

local node = SimpleDialogue.CreateCondition(
    function()
        return beenHereBefore
    end,
    SimpleDialogue.CreateAutoNode("Have a good day then!", function()
        task.wait(5)
        dialogue:EndDialogue()
    end, false),
    function()
        print("This will run, if the node failed to open.")
    end
),
```

#### `SimpleDialogue.CreateTree(nodes)`

Creates a complete dialogue tree from a collection of nodes.

**Parameters:**

- `nodes`: Array of dialogue nodes created with `SimpleDialogue.CreateNode()`, and `SimpleDialogue.CreateAutoNode()`

**Returns:**
- A dialogue tree object

**Example:**
```lua
local dialogueTree = SimpleDialogue.CreateTree({
    SimpleDialogue.CreateNode("Hello!", options1),
    SimpleDialogue.CreateNode("More information", options2)
})
```

### Instance Methods

Methods available on dialogue controller instances:

#### `:SetDialogueTree(tree)`

Sets the dialogue tree for this controller.

**Parameters:**

- `tree`: A dialogue tree created with `SimpleDialogue.CreateTree()`

**Example:**
```lua
dialogue:SetDialogueTree(dialogueTree)
```

#### `:SetConfiguration(config)`

Configures the dialogue system settings.

**Parameters:**

- `config`: Configuration table with the following options:

- `textSpeed`: Speed of text typing effect (number)

- `autoAdvance`: Whether dialogue auto-advances (boolean)

- `proximityDistance`: Maximum player distance before dialogue ends (number)

- `offsetDistance`: UI offset distance (number)

- Various visual customization options

**Example:**
```lua
dialogue:SetConfiguration({
    textSpeed = 0.03,
    proximityDistance = 10
})
```

#### `:DisplayNode(node)`

Displays a specific dialogue node.

**Parameters:**

- `node`: A dialogue node from the tree, either a node instance or specific number

**Example:**
```lua
dialogue:DisplayNode(dialogueTree[2]) -- Display the second node
dialogue:DisplayNode(4) -- Display the fourth node 
```

#### `:ShowNPCText(text, callback)`

Shows a message from the NPC with a typing effect.

**Parameters:**

- `text`: Message text to display

- `callback`: Function to call when text is fully displayed (optional)

**Example:**
```lua
dialogue:ShowNPCText("This is important information!", function()
    print("Text displayed fully")
end)
```

#### `:ShowPlayerText(text)`

Shows text above the player's character.

**Parameters:**

- `text`: Text to display above the player

**Example:**
```lua
dialogue:ShowPlayerText("I need to find that sword!")
```

#### `:EndDialogue()`

Ends the current dialogue interaction.

**Example:**
```lua
dialogue:EndDialogue()
```

#### `:SetOnInteract(callback)`

Sets a callback to run when dialogue begins.

**Parameters:**

- `callback`: Function to call when dialogue starts

**Example:**
```lua
dialogue:SetOnInteract(function()
    print("Dialogue started")
end)
```

#### `:SetOnOptionSelected(callback)`

Sets a callback to run when a dialogue option is selected.

**Parameters:**

- `callback`: Function to call with the selected option

**Example:**
```lua
dialogue:SetOnOptionSelected(function(option)
    print("Selected option:", option.text)
end)
```

#### `:SetOnDialogueEnd(callback)`

Sets a callback to run when dialogue ends.

**Parameters:**

- `callback`: Function to call when dialogue ends

**Example:**
```lua
dialogue:SetOnDialogueEnd(function()
    print("Dialogue ended")
end)
```

#### `:Destroy()`

Cleans up the dialogue controller and removes event connections.

**Example:**
```lua
dialogue:Destroy()
```