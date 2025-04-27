--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SimpleDialogueModule = ReplicatedStorage:WaitForChild("SimpleDialogue")
local SimpleDialogue = require(SimpleDialogueModule)
local Types = require(SimpleDialogueModule.Types)

type DialogueSystem = Types.DialogueSystem
type DialogueConfig = Types.DialogueConfig
type DialogueTree = Types.DialogueTree
type DialogueNode = Types.DialogueNode
type DialogueOption = Types.DialogueOption

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local existingNPCs: {Model} = {}

local function TestBasicDialogue(): DialogueSystem
    print("Testing basic dialogue...")
    
    local npcModel = Instance.new("Model")
    npcModel.Name = "TestNPC"
    table.insert(existingNPCs, npcModel)
    
    local torso = Instance.new("Part") :: Part
    torso.Name = "Torso"
    torso.Size = Vector3.new(2, 2, 1)
    local spawnPos = (character:WaitForChild("HumanoidRootPart") :: Part).Position
    torso.Position = spawnPos + Vector3.new(0, 0, 5)
    torso.Anchored = true
    torso.Parent = npcModel
    
    local head = Instance.new("Part") :: Part
    head.Name = "Head"
    head.Size = Vector3.new(1, 1, 1)
    head.Position = (torso :: Part).Position + Vector3.new(0, 1.5, 0)
    head.Anchored = true
    head.Parent = npcModel
    
    npcModel.PrimaryPart = torso
    npcModel.Parent = workspace
    
    local dialogue: DialogueSystem = SimpleDialogue.new(npcModel)
    
    local config: DialogueConfig = {
        textSpeed = 0.03,
        autoAdvance = false,
        proximityDistance = 10,
        offsetDistance = 2,
        highlightDampingRatio = 1,
        highlightFrequency = 4,
        textColor = Color3.fromRGB(255, 255, 255),
        optionColor = Color3.fromRGB(200, 200, 200),
        backgroundColor = Color3.fromRGB(0, 0, 0),
        font = Enum.Font.Gotham,
        fontSize = 18
    }
    dialogue:SetConfiguration(config)
    
    local dialogueTree: DialogueTree = SimpleDialogue.CreateTree({
        SimpleDialogue.CreateNode("Hey there!", {
            SimpleDialogue.CreateOption("Hi!", function()
                print("Player said hi")
            end, -1, "HELLO!"),
            SimpleDialogue.CreateOption("Bye!", function()
                print("Player said bye")
            end, -1)
        })
    })
    
    dialogue:SetDialogueTree(dialogueTree)
    
    local interactions = 0
    
    dialogue:SetOnInteract(function()
        interactions += 1
        print("Interaction:", interactions)
    end)
    
    dialogue:SetOnOptionSelected(function(option: DialogueOption)
        print("Selected:", option.text)
    end)
    
    dialogue:SetOnDialogueEnd(function()
        print("Dialogue ended")
    end)
    
    return dialogue
end

local function TestComplexDialogue(): DialogueSystem
    print("Testing shop/quest dialogue...")
    
    local npcModel = Instance.new("Model")
    npcModel.Name = "ShopKeeper"
    table.insert(existingNPCs, npcModel)
    
    local torso = Instance.new("Part") :: Part
    torso.Name = "Torso"
    torso.Size = Vector3.new(2, 2, 1)
    local spawnPos = (character:WaitForChild("HumanoidRootPart") :: Part).Position
    torso.Position = spawnPos + Vector3.new(5, 0, 5)
    torso.Anchored = true
    torso.Parent = npcModel
    
    local head = Instance.new("Part") :: Part
    head.Name = "Head"
    head.Size = Vector3.new(1, 1, 1)
    head.Position = torso.Position + Vector3.new(0, 1.5, 0)
    head.Anchored = true
    head.Parent = npcModel
    
    npcModel.PrimaryPart = torso
    npcModel.Parent = workspace
    
    local dialogue: DialogueSystem = SimpleDialogue.new(npcModel)
    
    local config: DialogueConfig = {
        textSpeed = 0.03,
        autoAdvance = false,
        proximityDistance = 10,
        offsetDistance = 2,
        highlightDampingRatio = 1,
        highlightFrequency = 4,
        textColor = Color3.fromRGB(255, 255, 255),
        optionColor = Color3.fromRGB(200, 200, 200),
        backgroundColor = Color3.fromRGB(0, 0, 0),
        font = Enum.Font.SourceSansBold,
        fontSize = 18
    }
    dialogue:SetConfiguration(config)
    
    local questNode: DialogueNode = SimpleDialogue.CreateNode(
        "I need help finding my lost cat...", {
            SimpleDialogue.CreateOption("I'll help!", function()
                print("Quest started")
            end, 1),
            SimpleDialogue.CreateOption("Maybe later", function()
                print("Quest declined")
            end, 1)
        }
    )
    
    local shopNode: DialogueNode = SimpleDialogue.CreateNode(
        "Take a look at my wares:", {
            SimpleDialogue.CreateOption("Sword (100g)", function()
                print("Trying to buy sword")
            end, 3),
            SimpleDialogue.CreateOption("Shield (50g)", function()
                print("Trying to buy shield")
            end, 3),
            SimpleDialogue.CreateOption("Leave", function()
                print("Left shop")
            end, 1)
        }
    )
    
    local mainNode: DialogueNode = SimpleDialogue.CreateNode(
        "Welcome to my shop!", {
            SimpleDialogue.CreateOption("Need any help?", function()
                print("Going to quest node")
            end, 2),
            SimpleDialogue.CreateOption("Show me your items", function()
                print("Going to shop node")
            end, 3),
            SimpleDialogue.CreateOption("Goodbye", function()
                print("Ended chat")
            end, -1)
        }
    )
    
    local dialogueTree: DialogueTree = SimpleDialogue.CreateTree({mainNode, questNode, shopNode})
    dialogue:SetDialogueTree(dialogueTree)
    
    return dialogue
end

local function StartTests()
    for _, npc in ipairs(existingNPCs) do
        npc:Destroy()
    end
    table.clear(existingNPCs)
    
    TestBasicDialogue()
    TestComplexDialogue()
    print("Test NPCs created")
end

player.CharacterAdded:Connect(function(newCharacter)
    character = newCharacter
    task.wait(1)
    StartTests()
end)

if player.Character then
    StartTests()
end