--!strict
--!optimize 2

local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")
local Fusion
local success = pcall(function()
	Fusion = require(script.Parent.Parent.Packages.Fusion)
end)
if not success then
	Fusion = require(game:GetService("ReplicatedStorage").Packages.Fusion)
end
local Types = require(script.Parent.Parent.Types)

type NPCConfig = Types.NPCConfig

local Value = Fusion.Value
local Spring = Fusion.Spring

type PromptData = {
	onTriggered: (() -> ())?,
	highlight: Highlight?,
	highlightSpring: {
		outlineTransparency: any,
		outlineSpring: any,
	}?,
	fadeOutTask: thread?,
}
local activePrompts: { [ProximityPrompt]: PromptData } = {}

local sharedRenderSteppedConnection: RBXScriptConnection? = nil
local activeHighlights: { [Highlight]: any } = {}

local ProximityPromptHandler = {}

local function enableAllPrompts()
	for prompt, _ in activePrompts do
		prompt.Enabled = true
	end
end

local function setAllPromptsEnabled(enabled: boolean)
	for prompt, _ in activePrompts do
		prompt.Enabled = enabled
	end
end

local function ensureSharedRenderStepped()
	if sharedRenderSteppedConnection then
		return
	end

	sharedRenderSteppedConnection = RunService.RenderStepped:Connect(function()
		for highlight, springData in pairs(activeHighlights) do
			if highlight and highlight.Parent then
				highlight.OutlineTransparency = springData:get()
			else
				if highlight then
					activeHighlights[highlight] = nil
				end
			end
		end

		if next(activeHighlights) == nil then
			if sharedRenderSteppedConnection then
				sharedRenderSteppedConnection:Disconnect()
				sharedRenderSteppedConnection = nil
			end
		end
	end)
end

local function createHighlight(npcModel: Model): Highlight
	local highlight = Instance.new("Highlight")
	highlight.Name = "DialogueHighlight"
	highlight.FillTransparency = 1
	highlight.OutlineTransparency = 1
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.Parent = npcModel
	return highlight
end

local function initializePromptHandling()
	ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
		local promptData = activePrompts[prompt]

		if not promptData then
			return
		end

		if promptData.fadeOutTask then
			task.cancel(promptData.fadeOutTask)
			promptData.fadeOutTask = nil
		end

		if not promptData.highlight and prompt.Parent then
			promptData.highlight = createHighlight(
				if prompt.Parent:IsA("Model") then prompt.Parent else (prompt.Parent and prompt.Parent.Parent :: Model)
			)

			local outlineTransparency = Value(1)
			local outlineSpring = Spring(outlineTransparency, 25)

			promptData.highlightSpring = {
				outlineTransparency = outlineTransparency,
				outlineSpring = outlineSpring,
			}

			ensureSharedRenderStepped()
			if promptData.highlight then
				activeHighlights[promptData.highlight] = outlineSpring
			end
		end

		if promptData.highlight and promptData.highlightSpring then
			promptData.highlight.Enabled = true
			promptData.highlightSpring.outlineTransparency:set(0)
		end

		activePrompts[prompt] = promptData

		prompt.PromptHidden:Wait()
		local currentData = activePrompts[prompt]
		if currentData and currentData.highlight and currentData.highlightSpring then
			currentData.highlightSpring.outlineTransparency:set(1)

			currentData.fadeOutTask = task.delay(0.5, function()
				if currentData.highlight and currentData.highlight.Enabled then
					currentData.highlight.Enabled = false
				end
			end)
		end
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local promptData = activePrompts[prompt]
		if promptData then
			setAllPromptsEnabled(false)
			if promptData.onTriggered then
				promptData.onTriggered()
			end
		end
	end)
end

task.spawn(initializePromptHandling)

function ProximityPromptHandler.Create(npcModel: Model, config: NPCConfig, onTriggered: (() -> ())?)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Prompt"
	print("Primarypart: ", npcModel.PrimaryPart)
	prompt.Parent = if npcModel.PrimaryPart then npcModel.PrimaryPart else npcModel
	prompt.ObjectText = config.objectText or "Talk"
	prompt.ActionText = config.actionText or "Press E"
	prompt.HoldDuration = config.holdDuration or 0
	prompt.RequiresLineOfSight = config.requiresLineOfSight or false
	prompt.MaxActivationDistance = config.maxActivationDistance or 10
	prompt.Enabled = config.enabled ~= false

	if onTriggered then
		activePrompts[prompt] = {
			onTriggered = onTriggered,
			highlight = nil,
			highlightSpring = nil,
			fadeOutTask = nil,
		}
	end

	return prompt
end

function ProximityPromptHandler.Update(prompt: ProximityPrompt, config: NPCConfig)
	if config.objectText then
		prompt.ObjectText = config.objectText
	end

	if config.actionText then
		prompt.ActionText = config.actionText
	end

	if config.holdDuration then
		prompt.HoldDuration = config.holdDuration
	end

	if config.requiresLineOfSight ~= nil then
		prompt.RequiresLineOfSight = config.requiresLineOfSight
	end

	if config.maxActivationDistance then
		prompt.MaxActivationDistance = config.maxActivationDistance
	end

	if config.enabled ~= nil then
		prompt.Enabled = config.enabled
	end
end

function ProximityPromptHandler.Destroy(prompt: ProximityPrompt)
	local promptData = activePrompts[prompt]
	if promptData then
		if promptData.fadeOutTask then
			task.cancel(promptData.fadeOutTask)
		end

		if promptData.highlight then
			if activeHighlights[promptData.highlight] then
				activeHighlights[promptData.highlight] = nil
			end
			promptData.highlight:Destroy()
		end
	end
	activePrompts[prompt] = nil
	prompt:Destroy()
end

function ProximityPromptHandler.EnableAllPrompts()
	enableAllPrompts()
end

function ProximityPromptHandler.SetAllPromptsEnabled(enabled: boolean)
	setAllPromptsEnabled(enabled)
end

function ProximityPromptHandler.Cleanup()
	if sharedRenderSteppedConnection then
		sharedRenderSteppedConnection:Disconnect()
		sharedRenderSteppedConnection = nil
	end

	for prompt, promptData in pairs(activePrompts) do
		if promptData.fadeOutTask then
			task.cancel(promptData.fadeOutTask)
		end
		if promptData.highlight then
			promptData.highlight:Destroy()
		end
		prompt:Destroy()
	end

	activePrompts = {}
	activeHighlights = {}
end

return ProximityPromptHandler
