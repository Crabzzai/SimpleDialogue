--!strict
--!optimize 2

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Types = require(script.Parent.Parent.Types)
local DialogueUI = require(script.Parent.Parent.UI.DialogueUI)
local FloatingTextUI = require(script.Parent.Parent.UI.FloatingTextUI)
local ProximityPromptHandler = require(script.Parent.Parent.Handlers.ProximityPromptHandler)

type DialogueSystem = Types.DialogueSystem
type DialogueConfig = Types.DialogueConfig
type NPC = Types.NPC
type DialogueTree = Types.DialogueTree
type DialogueNode = Types.DialogueNode
type DialogueOption = Types.DialogueOption
type UIConfig = Types.UIConfig

local GlobalUpdateManager = {
	connection = nil :: RBXScriptConnection?,
	npcParts = {} :: { [Part]: { model: Model } },
	playerParts = {} :: { [Part]: { character: Model?, offset: Vector3? } },
	dialogueFloatingParts = {} :: { [Part]: { character: Model?, offsetDistance: number? } },
	active = false,
}

local SharedFloatingPart: Part? = nil
local SharedPlayerTextPart: Part? = nil
local AllNPCs: { NPC } = {}
local ActiveDialogue: DialogueSystem? = nil
local PlayerTextHideTimestamp: number = 0
local PlayerTextUpdateConnection: RBXScriptConnection? = nil

local DialogueSystem = {}
DialogueSystem.__index = DialogueSystem

local DEFAULT_CONFIG: DialogueConfig = {
	textSpeed = 0.05,
	autoAdvance = false,
	autoAdvanceDelay = 2,
	proximityDistance = 10,
	offsetDistance = 2,
	playerTextDisplayDuration = 2,
	playerTextOffset = Vector3.new(0, 3, 0),
}
local DEFAULT_CONFIG_MT = {}
DEFAULT_CONFIG_MT.__index = DEFAULT_CONFIG

function DialogueSystem.InitializeGlobalUpdate()
	if GlobalUpdateManager.active then
		return
	end

	GlobalUpdateManager.active = true
	GlobalUpdateManager.connection = RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end

		for part, data in pairs(GlobalUpdateManager.npcParts) do
			if part and part.Parent and data.model and data.model.PrimaryPart then
				local headPosition = data.model.PrimaryPart.Position + Vector3.new(0, 3, 0)
				part.Position = headPosition

				local camCFrame = camera.CFrame
				local camLook = camCFrame.LookVector.Unit
				local lookDir = Vector3.new(camLook.X, camLook.Y, camLook.Z).Unit
				local finalCFrame = CFrame.lookAt(part.Position, part.Position + lookDir, Vector3.new(0, 1, 0))
				part.CFrame = finalCFrame
			elseif part then
				GlobalUpdateManager.npcParts[part] = nil
			end
		end

		for part, data in pairs(GlobalUpdateManager.playerParts) do
			if part and part.Parent and data.character then
				local rootPart = data.character:FindFirstChild("HumanoidRootPart")
				if rootPart and rootPart:IsA("BasePart") then
					local rootCFrame = rootPart.CFrame
					local offset = data.offset or Vector3.new(0, 3, 0)

					part.CFrame = rootCFrame * CFrame.new(offset)

					FloatingTextUI.UpdateOrientation(part)
				else
					GlobalUpdateManager.playerParts[part] = nil
				end
			elseif part then
				GlobalUpdateManager.playerParts[part] = nil
			end
		end

		for part, data in pairs(GlobalUpdateManager.dialogueFloatingParts) do
			if part and part.Parent and data.character then
				local rootPart = data.character:FindFirstChild("HumanoidRootPart")
				if rootPart and rootPart:IsA("BasePart") then
					local playerPos = rootPart.Position

					local camCFrame = camera.CFrame
					local camLook = camCFrame.LookVector.Unit
					local camUp = Vector3.new(0, 1, 0)

					local camRight = camLook:Cross(camUp).Unit
					local cleanCamUp = camRight:Cross(camLook).Unit
					local cleanCamCFrame = CFrame.fromMatrix(Vector3.zero, camRight, cleanCamUp)

					local offsetDistance = data.offsetDistance or 2
					local partSizeX = part.Size.X
					local offset = cleanCamCFrame.RightVector * (offsetDistance + (partSizeX / 2))
					local finalPosition = playerPos + offset

					local lookDirection = Vector3.new(camLook.X, camLook.Y, camLook.Z).Unit
					local finalCFrame = CFrame.lookAt(
						finalPosition,
						finalPosition + lookDirection,
						Vector3.new(0, 1, 0)
					)

					part.CFrame = finalCFrame
				else
					GlobalUpdateManager.dialogueFloatingParts[part] = nil
				end
			elseif part then
				GlobalUpdateManager.dialogueFloatingParts[part] = nil
			end
		end

		if
			next(GlobalUpdateManager.npcParts) == nil
			and next(GlobalUpdateManager.playerParts) == nil
			and next(GlobalUpdateManager.dialogueFloatingParts) == nil
		then
			if GlobalUpdateManager.connection then
				GlobalUpdateManager.connection:Disconnect()
				GlobalUpdateManager.connection = nil
			end
			GlobalUpdateManager.active = false
		end
	end)
end

function DialogueSystem.CleanupFromGlobalManager(part: Part?)
	if not part then
		return
	end

	GlobalUpdateManager.npcParts[part :: Part] = nil
	GlobalUpdateManager.playerParts[part :: Part] = nil
	GlobalUpdateManager.dialogueFloatingParts[part :: Part] = nil
end

function DialogueSystem.new(npcModel: Model)
	local config = setmetatable({}, DEFAULT_CONFIG_MT)

	local self = (
		setmetatable({
			config = config,
			npc = nil :: Types.NPC?,
			player = Players.LocalPlayer,
			character = nil :: Model?,
			rootPart = nil :: BasePart?,
			camera = nil :: Camera?,
			options = {} :: { any },
			isDialogueActive = false,
			currentNode = nil :: Types.DialogueNode?,
			currentNodeIndex = nil :: number?,
			currentNPC = nil :: Types.NPC?,
			onOptionSelectedCallback = nil :: ((option: Types.DialogueOption) -> ())?,
			onDialogueEndCallback = nil :: (() -> ())?,
			floatingPart = nil :: BasePart?,
			frame = nil :: Frame?,
			playerFloatingText = nil :: { frame: Frame?, textLabel: TextLabel? }?,
			_distanceCheckConnection = nil :: RBXScriptConnection?,
		}, DialogueSystem) :: any
	) :: DialogueSystem

	self.player.CharacterAdded:Connect(function(character)
		self:Initialize()
	end)

	self.npc = self:CreateNPC(npcModel)

	return self
end

function DialogueSystem.Initialize(self: DialogueSystem)
	if ActiveDialogue then
		ActiveDialogue:EndDialogue()
	end

	self.character = self.player.Character or self.player.CharacterAdded:Wait()
	if not self.character then
		return
	end

	local humanoidRootPart = self.character:WaitForChild("HumanoidRootPart") :: BasePart
	if not humanoidRootPart then
		return
	end

	self.rootPart = humanoidRootPart
	self.camera = workspace.CurrentCamera

	self:SetupUI()
	self:StartUpdateLoops()
end

function DialogueSystem.SetupUI(self: DialogueSystem)
	if not self.character then
		return
	end

	if not self.config.useScreenGui then
		if not SharedFloatingPart then
			SharedFloatingPart = Instance.new("Part")
			if SharedFloatingPart then
				SharedFloatingPart.Name = "DialogueFloatingPart"
				SharedFloatingPart.Anchored = true
				SharedFloatingPart.CanCollide = false
				SharedFloatingPart.Transparency = 1
				SharedFloatingPart.Size = Vector3.new(4, 2, 0.2)
				SharedFloatingPart.Parent = workspace
			end
		end

		self.floatingPart = SharedFloatingPart

		if not self.frame or not self.frame.Parent then
			if not SharedFloatingPart then
				error("SharedFloatingPart is nil, cannot create UI")
				return
			end
			local ui = DialogueUI.Create(SharedFloatingPart)
			if not ui or not ui.frame then
				error("Failed to create UI elements")
				return
			end
			self.frame = ui.frame
		end
	else
		if self.screenGui then
			self.screenGui:Destroy()
		end

		self.screenGui = DialogueUI.CreateScreenGui()

		if self.screenGui then
			local ui = DialogueUI.Create(self.screenGui)
			if not ui or not ui.frame then
				error("Failed to create UI elements for ScreenGui")
				return
			end
			self.frame = ui.frame
			ui.frame.AnchorPoint = Vector2.new(0.5, 0.5)
			ui.frame.Position = UDim2.new(0.5, 0, 0.5, 0)
			ui.frame.Visible = false

			if self._screenGuiUpdateConnection then
				self._screenGuiUpdateConnection:Disconnect()
			end

			self._screenGuiUpdateConnection = RunService.RenderStepped:Connect(function()
				self:UpdateScreenGuiPosition()
			end)
		end
	end
end

function DialogueSystem.StartUpdateLoops(self: DialogueSystem)
	if self._distanceCheckConnection then
		self._distanceCheckConnection:Disconnect()
		self._distanceCheckConnection = nil
	end

	self._distanceCheckConnection = RunService.Heartbeat:Connect(function()
		if self.isDialogueActive and self.currentNPC and self.rootPart then
			local npcModel = self.currentNPC.model
			if not npcModel or not npcModel.PrimaryPart then
				return
			end

			local rootPos: Vector3 = self.rootPart.Position
			local npcPos: Vector3 = npcModel.PrimaryPart.Position
			local distance = (rootPos - npcPos).Magnitude

			local proximityDistance = (self.config.proximityDistance or DEFAULT_CONFIG.proximityDistance) :: number
			local shouldEndDialogue = self.currentNode
				and self.currentNode.options
				and self.currentNode.options[1]
				and self.currentNode.options[1].shouldEndDialogue ~= false
			if distance > proximityDistance and shouldEndDialogue then
				self:EndDialogue()
			end
		end
	end)

	if self.playerFloatingText and SharedPlayerTextPart then
		DialogueSystem.InitializeGlobalUpdate()
		GlobalUpdateManager.playerParts[SharedPlayerTextPart] = {
			character = self.character,
			offset = self.config.playerTextOffset or DEFAULT_CONFIG.playerTextOffset,
		}
	end

	if self.floatingPart then
		DialogueSystem.InitializeGlobalUpdate()
		GlobalUpdateManager.dialogueFloatingParts[self.floatingPart] = {
			character = self.character,
			offsetDistance = self.config.offsetDistance or DEFAULT_CONFIG.offsetDistance,
		}
	end
end

function DialogueSystem.UpdateFloatingDisplayPosition(self: DialogueSystem)
	if not self.rootPart or not self.camera or not self.floatingPart then
		return
	end

	local playerPos: Vector3 = self.rootPart.Position

	local camCFrame = self.camera.CFrame
	local camLook = camCFrame.LookVector.Unit
	local camUp = Vector3.new(0, 1, 0)

	local camRight = camLook:Cross(camUp).Unit
	local cleanCamUp = camRight:Cross(camLook).Unit
	local cleanCamCFrame = CFrame.fromMatrix(Vector3.zero, camRight, cleanCamUp)

	local offsetDistance = (self.config.offsetDistance or DEFAULT_CONFIG.offsetDistance) :: number
	local partSizeX: number = self.floatingPart.Size.X
	local offset: Vector3 = cleanCamCFrame.RightVector * (offsetDistance + (partSizeX / 2))
	local finalPosition: Vector3 = playerPos + offset

	local lookDirection = Vector3.new(camLook.X, camLook.Y, camLook.Z).Unit
	local finalCFrame = CFrame.lookAt(finalPosition, finalPosition + lookDirection, Vector3.new(0, 1, 0))

	self.floatingPart.CFrame = finalCFrame
end

function DialogueSystem.UpdateScreenGuiPosition(self: DialogueSystem)
	if not self.config.useScreenGui or not self.screenGui or not self.frame then
		return
	end

	if not self.rootPart or not self.camera then
		return
	end

	local playerPos = self.rootPart.Position

	local camCFrame = self.camera.CFrame
	local camLook = camCFrame.LookVector.Unit
	local camUp = Vector3.new(0, 1, 0)

	local camRight = camLook:Cross(camUp).Unit
	local cleanCamUp = camRight:Cross(camLook).Unit
	local cleanCamCFrame = CFrame.fromMatrix(Vector3.zero, camRight, cleanCamUp)

	local offsetDistance = (self.config.offsetDistance or DEFAULT_CONFIG.offsetDistance) :: number
	local offset = cleanCamCFrame.RightVector * offsetDistance
	local worldPos = playerPos + offset

	local screenPos, isOnScreen = self.camera:WorldToScreenPoint(worldPos)

	if isOnScreen then
		self.frame.AnchorPoint = Vector2.new(0, 0.5)
		self.frame.Position = UDim2.new(0, screenPos.X, 0, screenPos.Y)

		local buttonWidth = 450
		local buttonHeight = 40

		local template = self.frame:FindFirstChild("Template")
		if template and template:IsA("Frame") then
			template.Size = UDim2.fromOffset(buttonWidth, buttonHeight)
		end

		for _, child in ipairs(self.frame:GetChildren()) do
			if child:IsA("Frame") and child.Name ~= "Template" then
				child.Size = UDim2.fromOffset(buttonWidth, buttonHeight)
			end
		end

		self.frame.Visible = true
	else
		self.frame.Visible = false
	end
end

function DialogueSystem.CreateNPC(self: DialogueSystem, npcModel: Model): NPC
	local npc: NPC = {
		model = npcModel,
		Prompt = nil,
		FloatingText = nil,
		_connections = {},
	}

	local textPart = Instance.new("Part")
	textPart.Name = "NPCFloatingTextPart"
	textPart.Anchored = true
	textPart.CanCollide = false
	textPart.Transparency = 1
	textPart.Size = Vector3.new(2, 0.5, 0.2)
	textPart.Parent = npcModel

	if npcModel.PrimaryPart then
		textPart.CFrame = npcModel.PrimaryPart.CFrame * CFrame.new(0, 3, 0)
	end

	npc.FloatingText = FloatingTextUI.Create(textPart)
	if npc.FloatingText then
		FloatingTextUI.UpdateText(npc.FloatingText, npcModel.Name)

		DialogueSystem.InitializeGlobalUpdate()
		GlobalUpdateManager.npcParts[textPart] = { model = npcModel }
	end

	npc.Prompt = ProximityPromptHandler.Create(npcModel, {
		objectText = "Talk",
		actionText = "Press E",
		holdDuration = 0,
		requiresLineOfSight = false,
		maxActivationDistance = self.config.proximityDistance,
	}, function()
		if npc.onInteract then
			npc.onInteract()
		end

		if npc.dialogueTree then
			self:StartDialogue(npc, npc.dialogueTree)
		end
	end)

	table.insert(AllNPCs, npc)
	return npc
end

function DialogueSystem.StartDialogue(self: DialogueSystem, npc: NPC, dialogueTree: DialogueTree)
	if ActiveDialogue then
		ActiveDialogue:EndDialogue()
	end

	ProximityPromptHandler.SetAllPromptsEnabled(false)

	self.currentNPC = npc
	self.isDialogueActive = true
	self.currentNodeIndex = 1
	ActiveDialogue = self

	if npc and npc.FloatingText and npc.FloatingText.frame then
		if not npc._connections.updateConnection or not npc._connections.updateConnection.Connected then
			npc._connections.updateConnection = RunService.RenderStepped:Connect(function()
				if npc.FloatingText and npc.FloatingText.frame then
					local surfaceGui = npc.FloatingText.frame.Parent
					if surfaceGui then
						local textPart = surfaceGui.Parent
						if textPart and textPart:IsA("Part") then
							FloatingTextUI.UpdateOrientation(textPart)
						end
					end
				end
			end)
		end
	end

	self:SetupUI()
	self:StartUpdateLoops()

	if self.frame then
		self.frame.Visible = true
	end

	if dialogueTree and dialogueTree[1] then
		self:DisplayNode(dialogueTree[1])
	else
		warn("No dialogue tree or first node provided")
	end
end

function DialogueSystem.DisplayNode(self: DialogueSystem, node: DialogueNode | number)
	if not node then
		warn("Attempted to display nil dialogue node")
		return
	end

	local _node: DialogueNode?

	if type(node) == "number" then
		local dialogueTree = self.npc and self.npc.dialogueTree
		if dialogueTree and dialogueTree[node] then
			_node = dialogueTree[node]
		else
			warn("Invalid node index:", node)
			return
		end
	else
		_node = node
	end

	if not _node then
		warn("Invalid node provided")
		return
	end

	if _node.condition and not _node.condition() then
		if _node.failCallback then
			task.spawn(_node.failCallback)
		end

		self:EndDialogue()
		return
	end

	self.currentNode = _node
	self:ClearOptions()

	if _node.onEnter then
		task.spawn(_node.onEnter)
	end

	local isAutoAdvanceNode = _node.options
		and #_node.options == 1
		and (_node.options[1].text == "" or _node.options[1].autoAdvance)
		and (_node.options[1].next == -1 or _node.options[1].autoAdvance)

	if not _node.options or #_node.options == 0 or isAutoAdvanceNode then
		if not _node.options or #_node.options == 0 then
			warn("No options provided for dialogue node")
		end

		if isAutoAdvanceNode then
			self:ShowNPCText(_node.text, function()
				if _node.options and _node.options[1] and _node.options[1].callback then
					local callback = _node.options[1].callback
					if callback then
						task.spawn(function()
							callback()
						end)
					end
				end

				local shouldEndDialogue = _node.options
					and _node.options[1]
					and _node.options[1].shouldEndDialogue ~= false

				if shouldEndDialogue then
					self:EndDialogue()
				end
			end)
			return
		else
			local continueOption: DialogueOption = {
				text = "Continue",
				next = -1,
			}
			_node.options = { continueOption }
		end
	end

	if self.currentNPC and self.currentNPC.FloatingText then
		self:ShowNPCText(_node.text, function()
			for i, option in ipairs(_node.options) do
				if option.condition and not option.condition() then
					continue
				end

				local button = DialogueUI.CreateOptionButton(option.text, {
					template = self.frame and self.frame:FindFirstChild("Template") :: Frame?,
					optionsFrame = self.frame,
				})

				if button then
					local hitbox = button:FindFirstChild("Hitbox")
					local buttonElement = hitbox and hitbox:FindFirstChild("Button") or button:FindFirstChild("Button")

					if buttonElement and buttonElement:IsA("TextButton") then
						local btnClickConn = buttonElement.MouseButton1Click:Connect(function()
							self:ShowPlayerText(option.text)

							if option.displayText and self.currentNPC and self.currentNPC.FloatingText then
								FloatingTextUI.UpdateText(self.currentNPC.FloatingText, "")

								self:ShowNPCText(option.displayText, function()
									if option.callback then
										task.spawn(option.callback)
									end

									if self.onOptionSelectedCallback then
										task.spawn(function()
											self.onOptionSelectedCallback(option)
										end)
									end

									if option.next == 0 then
										self:ClearOptions()
									elseif option.next == -1 then
										self:EndDialogue()
									elseif type(option.next) == "number" then
										local nextNode = self.npc
											and self.npc.dialogueTree
											and self.npc.dialogueTree[option.next]
										if nextNode then
											self.currentNodeIndex = option.next
											self:DisplayNode(nextNode)
										else
											warn("Invalid next node index:", option.next)
											self:EndDialogue()
										end
									else
										warn("Invalid next value for option:", option.text)
										self:EndDialogue()
									end
								end)
							else
								if self.currentNPC and self.currentNPC.FloatingText then
									FloatingTextUI.Hide(self.currentNPC.FloatingText)
								end

								if option.callback then
									task.spawn(option.callback)
								end

								if self.onOptionSelectedCallback then
									task.spawn(function()
										self.onOptionSelectedCallback(option)
									end)
								end

								if option.next == 0 then
									self:ClearOptions()
								elseif option.next == -1 then
									self:EndDialogue()
								elseif type(option.next) == "number" then
									local nextNode = self.npc
										and self.npc.dialogueTree
										and self.npc.dialogueTree[option.next]
									if nextNode then
										self.currentNodeIndex = option.next
										self:DisplayNode(nextNode)
									else
										warn("Invalid next node index:", option.next)
										self:EndDialogue()
									end
								else
									warn("Invalid next value for option:", option.text)
									self:EndDialogue()
								end
							end
						end)

						table.insert(self.options, {
							frame = button,
							connections = { btnClickConn },
						})
					else
						warn("Failed to find Button DialogueSystem in option button")
					end
				else
					warn("Failed to create option button for:", option.text)
				end
			end

			self:UpdateFloatingDisplaySize()
		end)
	else
		warn("NPC floating text not available")
	end
end

function DialogueSystem.ClearOptions(self: DialogueSystem)
	if not self.frame then
		return
	end

	for _, optionData in ipairs(self.options) do
		if optionData.connections then
			for _, connection in ipairs(optionData.connections) do
				connection:Disconnect()
			end
		end
	end

	table.clear(self.options)

	DialogueUI.ClearOptions(self.frame)
end

function DialogueSystem.UpdateFloatingDisplaySize(self: DialogueSystem)
	if not self.frame or not self.floatingPart then
		return
	end

	local layout = self.frame:FindFirstChild("UIListLayout") :: UIListLayout?
	if not layout then
		return
	end

	local listHeight: number = layout.AbsoluteContentSize.Y
	local listWidth: number = layout.AbsoluteContentSize.X

	self.floatingPart.Size = Vector3.new(listWidth / 50, listHeight / 50, 0.2)
end

function DialogueSystem.SetConfiguration(self: DialogueSystem, config: DialogueConfig)
	for key, value in pairs(config) do
		self.config[key] = value
	end

	self:SetupUI()
end

function DialogueSystem.SetDialogueTree(self: DialogueSystem, dialogueTree: DialogueTree)
	if self.npc then
		self.npc.dialogueTree = dialogueTree
	end
end

function DialogueSystem.SetOnInteract(self: DialogueSystem, callback: () -> ())
	if self.npc then
		self.npc.onInteract = callback
	end
end

function DialogueSystem.SetOnOptionSelected(self: DialogueSystem, callback: (option: DialogueOption) -> ())
	self.onOptionSelectedCallback = callback
end

function DialogueSystem.SetOnDialogueEnd(self: DialogueSystem, callback: () -> ())
	self.onDialogueEndCallback = callback
end

function DialogueSystem.EndDialogue(self: DialogueSystem)
	if not self.isDialogueActive then
		return
	end

	if self.currentNode and self.currentNode.onExit then
		task.spawn(self.currentNode.onExit)
	end

	local hasRemainingDisplayTime = PlayerTextHideTimestamp > 0 and tick() < PlayerTextHideTimestamp
	self.floatingPart = nil

	self:ClearOptions()

	if self.config.useScreenGui and self.screenGui then
		self.screenGui:Destroy()
		self.screenGui = nil
		if self._screenGuiUpdateConnection then
			self._screenGuiUpdateConnection:Disconnect()
			self._screenGuiUpdateConnection = nil
		end
	end

	self.isDialogueActive = false

	local function finishEnd()
		if not hasRemainingDisplayTime then
			if self._playerUpdateConnection then
				self._playerUpdateConnection:Disconnect()
				self._playerUpdateConnection = nil
			end
		else
			DialogueSystem.EnsureGlobalPlayerTextUpdate(self)
		end

		if self._distanceCheckConnection then
			self._distanceCheckConnection:Disconnect()
			self._distanceCheckConnection = nil
		end

		local npcToPreserve = self.currentNPC
		local npcName = npcToPreserve and npcToPreserve.model.Name or "Unknown"
		local currentText = npcToPreserve
				and npcToPreserve.FloatingText
				and npcToPreserve.FloatingText.textLabel
				and npcToPreserve.FloatingText.textLabel.Text
			or ""

		if not _G.__FadingNPCTexts then
			_G.__FadingNPCTexts = {}
		end

		if npcToPreserve then
			_G.__FadingNPCTexts[npcName] = {
				npc = npcToPreserve,
				text = currentText,
				timestamp = tick(),
			}
		end

		for _, npc in ipairs(AllNPCs) do
			if npc._connections and npc._connections.updateConnection then
				npc._connections.updateConnection:Disconnect()
				npc._connections.updateConnection = nil
			end

			if npc.FloatingText and npc.FloatingText.frame then
				for _, child in ipairs(npc.FloatingText.frame:GetChildren()) do
					if child:IsA("TextButton") then
						child:Destroy()
					end
				end

				local npcModelName = npc.model and npc.model.Name or ""
				if npc ~= npcToPreserve and not _G.__FadingNPCTexts[npcModelName] then
					FloatingTextUI.Hide(npc.FloatingText)
				end
			end
		end

		if npcToPreserve and npcToPreserve.FloatingText then
			if
				not npcToPreserve._connections.updateConnection
				or not npcToPreserve._connections.updateConnection.Connected
			then
				npcToPreserve._connections.updateConnection = RunService.RenderStepped:Connect(function()
					if npcToPreserve.FloatingText and npcToPreserve.FloatingText.frame then
						local surfaceGui = npcToPreserve.FloatingText.frame.Parent
						if surfaceGui then
							local textPart = surfaceGui.Parent
							if textPart and textPart:IsA("Part") then
								FloatingTextUI.UpdateOrientation(textPart)
							end
						end
					end
				end)
			end

			local preservationTime = 4.0

			task.delay(preservationTime, function()
				local fadingInfo = _G.__FadingNPCTexts[npcName]
				if not fadingInfo or (tick() - fadingInfo.timestamp) > 3.0 then
					if ActiveDialogue and ActiveDialogue.currentNPC == npcToPreserve then
						return
					end

					if npcToPreserve._connections.updateConnection then
						npcToPreserve._connections.updateConnection:Disconnect()
						npcToPreserve._connections.updateConnection = nil
					end

					if npcToPreserve.FloatingText and npcToPreserve.FloatingText.frame then
						FloatingTextUI.Hide(npcToPreserve.FloatingText)
					end

					if _G.__FadingNPCTexts[npcName] then
						_G.__FadingNPCTexts[npcName] = nil
					end
				end
			end)
		end

		if hasRemainingDisplayTime then
			local remainingTime = PlayerTextHideTimestamp - tick()

			task.delay(remainingTime, function()
				if (ActiveDialogue :: any) == (self :: any) then
					ActiveDialogue = nil
				end

				if not ActiveDialogue then
					ProximityPromptHandler.SetAllPromptsEnabled(true)
				end

				if self.onDialogueEndCallback then
					self.onDialogueEndCallback()
				end

				if self.playerFloatingText and self.playerFloatingText.frame then
					local surfaceGui = self.playerFloatingText.frame.Parent
					if surfaceGui then
						surfaceGui:Destroy()
					end
					local textPart = surfaceGui and surfaceGui.Parent
					if textPart then
						textPart:Destroy()
					end
				end

				PlayerTextHideTimestamp = 0
			end)
		else
			if (ActiveDialogue :: any) == (self :: any) then
				ActiveDialogue = nil
			end

			if not ActiveDialogue then
				ProximityPromptHandler.SetAllPromptsEnabled(true)
			end

			if self.onDialogueEndCallback then
				self.onDialogueEndCallback()
			end

			if self.playerFloatingText and self.playerFloatingText.frame then
				local surfaceGui = self.playerFloatingText.frame.Parent
				if surfaceGui then
					surfaceGui:Destroy()
				end
				local textPart = surfaceGui and surfaceGui.Parent
				if textPart then
					textPart:Destroy()
				end
			end

			PlayerTextHideTimestamp = 0
		end
	end

	if self.isNPCTyping then
		task.spawn(function()
			while self.isNPCTyping do
				task.wait(0.05)
			end
			finishEnd()
		end)
	else
		finishEnd()
	end
end

function DialogueSystem.RemoveNPCFromGlobal(npc: NPC)
	for i, storedNpc in ipairs(AllNPCs) do
		if storedNpc == npc then
			table.remove(AllNPCs, i)
			break
		end
	end
end

function DialogueSystem.Destroy(self: DialogueSystem)
	if self._distanceCheckConnection then
		self._distanceCheckConnection:Disconnect()
		self._distanceCheckConnection = nil
	end

	if self.floatingPart then
		DialogueSystem.CleanupFromGlobalManager(self.floatingPart)
	end

	if SharedPlayerTextPart then
		DialogueSystem.CleanupFromGlobalManager(SharedPlayerTextPart)
	end

	if self.npc and self.npc.FloatingText then
		local textPart = self.npc.FloatingText.frame
			and self.npc.FloatingText.frame.Parent
			and self.npc.FloatingText.frame.Parent.Parent

		if textPart and textPart:IsA("Part") then
			DialogueSystem.CleanupFromGlobalManager(textPart)
		end

		if self.npc.FloatingText.frame then
			local surfaceGui = self.npc.FloatingText.frame.Parent
			if surfaceGui then
				surfaceGui:Destroy()
			end
		end
	end

	if self.npc then
		DialogueSystem.RemoveNPCFromGlobal(self.npc)
	end

	if self.playerFloatingText and self.playerFloatingText.frame then
		local surfaceGui = self.playerFloatingText.frame.Parent
		if surfaceGui then
			surfaceGui:Destroy()
		end
		local textPart = surfaceGui and surfaceGui.Parent
		if textPart then
			textPart:Destroy()
		end
	end

	self.options = {}
	self.currentNode = nil
	self.currentNodeIndex = nil
	self.onOptionSelectedCallback = nil
	self.onDialogueEndCallback = nil
	self.floatingPart = nil

	if (ActiveDialogue :: any) == (self :: any) then
		ActiveDialogue = nil
	end
end

function DialogueSystem.StartPlayerTextUpdateLoop()
	if PlayerTextUpdateConnection then
		PlayerTextUpdateConnection:Disconnect()
	end

	PlayerTextUpdateConnection = RunService.RenderStepped:Connect(function()
		if not ActiveDialogue then
			return
		end

		local self = ActiveDialogue
		if self.playerFloatingText and self.rootPart and self.playerFloatingText.frame then
			local surfaceGui = self.playerFloatingText.frame.Parent
			if surfaceGui then
				local playerTextPart = surfaceGui.Parent
				if playerTextPart and playerTextPart:IsA("Part") then
					local rootCFrame: CFrame = self.rootPart.CFrame
					local playerTextOffset =
						(self.config.playerTextOffset or DEFAULT_CONFIG.playerTextOffset) :: Vector3
					playerTextPart.CFrame = rootCFrame * CFrame.new(playerTextOffset)
					FloatingTextUI.UpdateOrientation(playerTextPart)
				end
			end
		end
	end)
end

function DialogueSystem.EnsureGlobalPlayerTextUpdate(self: DialogueSystem)
	if not self.playerFloatingText or not self.rootPart then
		return
	end

	if not PlayerTextUpdateConnection or not PlayerTextUpdateConnection.Connected then
		PlayerTextUpdateConnection = RunService.RenderStepped:Connect(function()
			if PlayerTextHideTimestamp <= 0 or tick() >= PlayerTextHideTimestamp then
				if PlayerTextUpdateConnection then
					PlayerTextUpdateConnection:Disconnect()
					PlayerTextUpdateConnection = nil
				end
				return
			end

			if self.playerFloatingText and self.rootPart and self.playerFloatingText.frame then
				local surfaceGui = self.playerFloatingText.frame.Parent
				if surfaceGui then
					local playerTextPart = surfaceGui.Parent
					if playerTextPart and playerTextPart:IsA("Part") then
						local rootCFrame: CFrame = self.rootPart.CFrame
						local playerTextOffset =
							(self.config.playerTextOffset or DEFAULT_CONFIG.playerTextOffset) :: Vector3
						playerTextPart.CFrame = rootCFrame * CFrame.new(playerTextOffset)
						FloatingTextUI.UpdateOrientation(playerTextPart)
					end
				end
			end
		end)
	end
end

function DialogueSystem.ShowPlayerText(self: DialogueSystem, text: string)
	if not self.playerFloatingText then
		return
	end

	FloatingTextUI.UpdateText(self.playerFloatingText, text)
	FloatingTextUI.Show(self.playerFloatingText)

	local displayDuration = self.config.playerTextDisplayDuration or DEFAULT_CONFIG.playerTextDisplayDuration
	PlayerTextHideTimestamp = tick() + (displayDuration :: number)

	DialogueSystem.EnsureGlobalPlayerTextUpdate(self)

	local function checkHideText()
		if tick() >= PlayerTextHideTimestamp and self.playerFloatingText then
			FloatingTextUI.Hide(self.playerFloatingText)
			PlayerTextHideTimestamp = 0
		elseif PlayerTextHideTimestamp > 0 then
			task.delay(0.1, checkHideText)
		end
	end

	task.delay(displayDuration, checkHideText)
end

function DialogueSystem.ShowNPCText(self: DialogueSystem, text: string, callback: (() -> ())?)
	if not self.currentNPC or not self.currentNPC.FloatingText then
		return
	end

	self.isNPCTyping = true

	FloatingTextUI.UpdateText(self.currentNPC.FloatingText, "")
	FloatingTextUI.Show(self.currentNPC.FloatingText)

	local textSpeed = self.config.textSpeed or DEFAULT_CONFIG.textSpeed

	local currentText = ""
	local textLength = string.len(text)
	local currentCharIndex = 0

	local function addNextChar()
		currentCharIndex += 1
		currentText = string.sub(text, 1, currentCharIndex)

		if self.currentNPC and self.currentNPC.FloatingText then
			FloatingTextUI.UpdateText(self.currentNPC.FloatingText, currentText)
		end

		if currentCharIndex < textLength then
			task.delay(textSpeed, addNextChar)
		else
			self.isNPCTyping = false
			if callback then
				task.spawn(callback)
			end
		end
	end

	addNextChar()
end

return DialogueSystem
