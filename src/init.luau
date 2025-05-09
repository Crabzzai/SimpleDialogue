--!strict
--!optimize 2

local Types = require(script.Types)
local DialogueSystem = require(script.System.DialogueSystem)

local SimpleDialogue = {}
SimpleDialogue.__index = SimpleDialogue

export type DialogueOption = Types.DialogueOption
export type DialogueNode = Types.DialogueNode
export type DialogueTree = Types.DialogueTree
export type DialogueConfig = Types.DialogueConfig
export type NPC = Types.NPC
export type DialogueSystem = Types.DialogueSystem

function SimpleDialogue.new(npcModel: Model): DialogueSystem
	local system = DialogueSystem.new(npcModel)
	system:Initialize()

	local destroyConnection
	destroyConnection = npcModel.Destroying:Connect(function()
		system:Destroy()
		destroyConnection:Disconnect()
	end)

	return system
end

function SimpleDialogue.CreateOption(
	text: string,
	callback: (() -> ())?,
	next: number?,
	displayText: string?
): DialogueOption
	return {
		text = text,
		next = next or -1,
		callback = callback,
		displayText = displayText,
	}
end

function SimpleDialogue.CreateNode(text: string, options: { DialogueOption }): DialogueNode
	return {
		text = text,
		options = options,
		dialogueTree = nil,
	}
end

function SimpleDialogue.CreateAutoNode(text: string, callback: (() -> ())?, shouldEndDialogue: boolean?): DialogueNode
	return {
		text = text,
		options = {
			{
				text = "",
				next = shouldEndDialogue ~= false and -1 or 0,
				callback = callback,
				autoAdvance = true,
				shouldEndDialogue = shouldEndDialogue ~= false,
			},
		},
		dialogueTree = nil,
	}
end

function SimpleDialogue.CreateCondition<T>(
	condition: boolean | (() -> boolean),
	item: T,
	failCallback: (() -> ())?
): T & { condition: (() -> boolean)? }
	local conditionFunc = if typeof(condition) == "boolean"
		then function()
			return condition
		end
		else condition

	-- Add the condition to the item
	local result = item :: any
	result.condition = conditionFunc

	-- Add failCallback if provided
	if failCallback then
		result.failCallback = failCallback
	end

	return result
end

function SimpleDialogue.CreateTree(nodes: { DialogueNode }): DialogueTree
	for _, node in ipairs(nodes) do
		node.dialogueTree = nodes
	end

	for _, node in ipairs(nodes) do
		if node.options then
			for _, option in ipairs(node.options) do
				if option.next == nil then
					option.next = -1
				end
			end
		end
	end

	return nodes
end

return SimpleDialogue
