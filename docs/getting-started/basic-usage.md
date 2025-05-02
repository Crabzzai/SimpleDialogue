# Basic Usage

This guide covers the fundamental concepts and basic usage of SimpleDialogue.

## Creating a Simple Dialogue

To create a basic NPC dialogue:

```lua
local SimpleDialogue = require(Path.To.SimpleDialogue)

-- Assuming you have an NPC model
local npcModel = workspace.NPC

-- Create a dialogue controller for the NPC
local dialogue = SimpleDialogue.new(npcModel)

-- Create a simple dialogue tree
local dialogueTree = SimpleDialogue.CreateTree({
    SimpleDialogue.CreateNode("Hello! How can I help you today?", {
        SimpleDialogue.CreateOption("Tell me about this place", function()
            dialogue:ShowNPCText("This is a wonderful town with many secrets to discover!")
        end),
        SimpleDialogue.CreateOption("I'm just browsing", function()
            dialogue:ShowNPCText("Feel free to look around!")
        end)
    })
})

-- Set the dialogue tree to the NPC
dialogue:SetDialogueTree(dialogueTree)
```

## Understanding Dialogue Trees

A dialogue tree in SimpleDialogue consists of nodes and options:

- **Nodes**: Text spoken by the NPC
- **Options**: Choices available to the player

Each node can have multiple options (unless an auto node), and each option can lead to another node, creating a branching conversation.
An auto node, is used to show some text above the NPC, and then directly run a callback function afterwards, without giving the player options to choose from.

## Working with Dialogue Callbacks

Callbacks are functions executed when a player selects an option. They can be used to:

- Progress the dialogue
- Give items or rewards
- Trigger game events
- Update quests

Example with callbacks:

```lua
local function givePlayerGold(player, amount)
    -- Implementation for giving gold
    print("Gave player", amount, "gold")
end

local dialogueTree = SimpleDialogue.CreateTree({
    SimpleDialogue.CreateNode("Would you like a reward?", {
        SimpleDialogue.CreateOption("Yes, please!", function(player)
            dialogue:ShowNPCText("Here's 100 gold pieces!")
            givePlayerGold(player, 100)
        end),
        SimpleDialogue.CreateOption("No thanks", function()
            dialogue:ShowNPCText("Come back if you change your mind.")
        end)
    })
})
```

## Using Node Navigation

You can create multi-node conversations by using the node index parameter:

```lua
local dialogueTree = SimpleDialogue.CreateTree({
    -- First node (index 1)
    SimpleDialogue.CreateNode("Welcome to our village! First time visiting?", {
        SimpleDialogue.CreateOption("Yes, it's my first time", nil, 2), -- Go to node at index 2
        SimpleDialogue.CreateOption("No, I've been here before", nil, 3), -- Go to node at index 3
        SimpleDialogue.CreateOption("No, I've been here before", function()
            task.wait(5)
            dialogue:DisplayNode(4) -- Manually change node in the callback
        end, 0), -- 0 means clearing the options, without ending the dialogue.
        SimpleDialogue.CreateOption("Goodbye", nil, -1) -- -1 means end dialogue
    }),
    
    -- Second node (index 2)
    SimpleDialogue.CreateNode("Well, welcome! You should check out our marketplace.", {
        SimpleDialogue.CreateOption("Thanks for the tip", nil, -1)
    }),
    
    -- Third node (index 3)
    SimpleDialogue.CreateNode("Nice to see you again!", {
        SimpleDialogue.CreateOption("Good to be back", nil, -1)
    })

    -- Third node (index 4)
    SimpleDialogue.CreateNode("Nice to see you again!", {
        SimpleDialogue.CreateOption("Good to be back", nil, -1)
    })
})
```

## Using Auto Node

You can create nodes which do not show options to the player, but will instead run a function after the text above the NPC is fully shown.

```lua
local dialogueTree = SimpleDialogue.CreateTree({
    -- First node (index 1)
    SimpleDialogue.CreateNode("Welcome to our village! First time visiting?", {
        SimpleDialogue.CreateOption("Yes, it's my first time", nil, 2),
        SimpleDialogue.CreateOption("No, I've been here before", nil, 3),
        SimpleDialogue.CreateOption("Goodbye", nil, -1)
    }),
    
    -- Second node (index 2)
    SimpleDialogue.CreateAutoNode("Have a look at my shop then!", function()
        print("This will open a shop, and automatically end the dialogue after the callback has been run.")
    end),

    -- Third node (index 3)
    SimpleDialogue.CreateAutoNode("Have a good day then!", function()
        task.wait(5)
        dialogue:EndDialogue()
    end, false) -- This will let the dialogue stay active, so you can end the dialogue yourself.
})
```

## Configuring DialogueSystem

You can customize various aspects of the dialogue system:

```lua
-- Create a dialogue controller
local dialogue = SimpleDialogue.new(npcModel)

-- Configure the dialogue settings
dialogue:SetConfiguration({
    textSpeed = 0.03,             -- Speed of text typing effect
    autoAdvance = false,          -- Whether to auto-advance dialogue
    proximityDistance = 10,       -- Maximum distance before dialogue ends
    offsetDistance = 2,           -- UI offset distance
    useScreenGui = true,          -- Whether to have the dialogue in PlayerGui or on SurfaceGui
})
```

## Event Hooks

You can set up event hooks to listen for dialogue interactions:

```lua
-- Track when dialogue begins
dialogue:SetOnInteract(function()
    print("Dialogue started")
})

-- Track when an option is selected
dialogue:SetOnOptionSelected(function(option)
    print("Selected option:", option.text)
})

-- Track when dialogue ends
dialogue:SetOnDialogueEnd(function()
    print("Dialogue ended")
})
```

Refer to the [API documentation](../api/core.md) for more configuration options and advanced features.