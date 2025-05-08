--!strict
--!optimize 2

local RunService = game:GetService("RunService")
local Fusion
local success = pcall(function()
	Fusion = require(script.Parent.Parent.Packages.Fusion)
end)
if not success then
	Fusion = require(game:GetService("ReplicatedStorage").Packages.Fusion)
end
local Types = require(script.Parent.Parent.Types)

local New = Fusion.New
local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local Value = Fusion.Value
local Computed = Fusion.Computed
local Spring = Fusion.Spring
local Cleanup = Fusion.Cleanup

type UIConfig = Types.UIConfig

local DialogueUI = {}

function DialogueUI.createTemplate()
	return New("Frame")({
		Name = "Template",
		BackgroundTransparency = 0,
		Size = UDim2.fromOffset(450, 40),
		BackgroundColor3 = Color3.fromRGB(33, 33, 33),
		BorderColor3 = Color3.fromRGB(27, 42, 53),
		Visible = false,

		[Children] = {
			New("UIGradient")({
				Color = ColorSequence.new(Color3.fromRGB(0, 0, 0)),
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.2, 0.9),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),

			New("TextLabel")({
				Name = "Answer",
				BackgroundTransparency = 1,
				Size = UDim2.new(0, 400, 1, 0),
				Position = UDim2.new(0, 50, 0, 0),
				Text = "",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextScaled = true,
				Font = Enum.Font.SourceSansBold,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				TextDirection = Enum.TextDirection.Auto,
				ZIndex = 1,

				[Children] = {
					New("UIStroke")({
						Color = Color3.fromRGB(0, 0, 0),
						Transparency = 0,
						Thickness = 1.8,
					}),
				},
			}),

			New("TextLabel")({
				Name = "Number",
				BackgroundTransparency = 1,
				Size = UDim2.new(0, 50, 1, 0),
				Position = UDim2.new(0, 0, 0, 0),
				Text = "",
				TextColor3 = Color3.fromRGB(239, 255, 166),
				TextScaled = true,
				Font = Enum.Font.SourceSansBold,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				TextDirection = Enum.TextDirection.Auto,
				ZIndex = 1,

				[Children] = {
					New("UIStroke")({
						Color = Color3.fromRGB(0, 0, 0),
						Transparency = 0,
						Thickness = 1.8,
					}),
				},
			}),
		},
	})
end

function DialogueUI.CreateSurfaceGui(part: Part): SurfaceGui
	local existingGui = part:FindFirstChild("SurfaceGui")
	if existingGui and existingGui:IsA("SurfaceGui") then
		return existingGui
	end

	return (
		New("SurfaceGui")({
			Name = "SurfaceGui",
			Parent = part,
			SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
			PixelsPerStud = 50,
			LightInfluence = 0,
			AlwaysOnTop = true,
			Face = Enum.NormalId.Back,
			Adornee = part,
			ZOffset = 2,
			ResetOnSpawn = false,
			ClipsDescendants = false,
			MaxDistance = 0,
		})
	) :: SurfaceGui
end

function DialogueUI.CreateScreenGui(): ScreenGui
	local existingGui = game.Players.LocalPlayer.PlayerGui:FindFirstChild("DialogueGui")
	if existingGui and existingGui:IsA("ScreenGui") then
		return existingGui
	end

	return (
		New("ScreenGui")({
			Name = "DialogueGui",
			Parent = game.Players.LocalPlayer.PlayerGui,
			ResetOnSpawn = false,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		})
	) :: ScreenGui
end

function DialogueUI.Create(inst: Part | ScreenGui): { frame: Frame, template: Frame }
	local ui = {}

	local gui: GuiBase
	if inst:IsA("ScreenGui") then
		gui = inst
	else
		gui = DialogueUI.CreateSurfaceGui(inst)
	end

	local existingPriorityFrame = gui:FindFirstChild("PriorityFrame")

	if existingPriorityFrame and existingPriorityFrame:IsA("Frame") then
		local existingOptionsFrame = existingPriorityFrame:FindFirstChild("OptionsFrame")
		if existingOptionsFrame and existingOptionsFrame:IsA("Frame") then
			ui.frame = existingOptionsFrame
			ui.template = existingOptionsFrame:FindFirstChild("Template") :: Frame

			if ui.frame and ui.template then
				return ui
			end
		end
	end

	ui.frame = New("Frame")({
		Name = "OptionsFrame",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(450, 0),
		Position = UDim2.fromScale(if gui:IsA("ScreenGui") then 0.5 else 0, 0.5),
		AnchorPoint = Vector2.new(if gui:IsA("ScreenGui") then 0.5 else 0, 0.5),
		AutomaticSize = Enum.AutomaticSize.Y,
		SizeConstraint = Enum.SizeConstraint.RelativeXY,
		Parent = gui,
		ZIndex = 10,

		[Children] = {
			DialogueUI.createTemplate(),
			New("UIListLayout")({
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 10),
				FillDirection = Enum.FillDirection.Vertical,
				ItemLineAlignment = Enum.ItemLineAlignment.Automatic,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
			}),
		},
	}) :: Frame

	ui.template = ui.frame:FindFirstChild("Template") :: Frame

	return ui
end

function DialogueUI.CreateOptionButton(text: string, config: UIConfig): Frame?
	local template = config.template
	local optionsFrame = config.optionsFrame

	if not template or not optionsFrame then
		return nil
	end

	local option = template:Clone() :: Frame
	option.Name = "Option"
	option.Visible = true
	option.Parent = optionsFrame

	local answer = option:FindFirstChild("Answer") :: TextLabel
	local number = option:FindFirstChild("Number") :: TextLabel
	local gradient = option:FindFirstChild("UIGradient") :: UIGradient

	if not (answer and number) then
		return nil
	end

	local _isHovered = Value(false)
	local hoverSpring = Spring(
		Computed(function()
			return if _isHovered:get() then 1 else 0
		end),
		25
	)

	local positionSpring = Spring(
		Computed(function()
			return if _isHovered:get() then 80 else 50
		end),
		25
	)

	local springConnection = RunService.RenderStepped:Connect(function()
		local alpha = hoverSpring:get()
		local lerpedSequence = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.2, 0.9 - (0.17 * alpha)),
			NumberSequenceKeypoint.new(1, 1),
		})
		gradient.Transparency = lerpedSequence

		answer.Position = UDim2.new(0, positionSpring:get(), 0, 0)
	end)

	local hitbox = New("Frame")({
		Name = "Hitbox",
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 20, 1, 10),
		Position = UDim2.new(0, -10, 0, -5),
		ZIndex = 98,
		Parent = option,
	})

	New("TextButton")({
		Name = "Button",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0, 0),
		Text = "",
		ZIndex = 100,
		Parent = hitbox,

		[OnEvent("MouseEnter")] = function()
			_isHovered:set(true)
		end,

		[OnEvent("MouseLeave")] = function()
			_isHovered:set(false)
		end,

		[Cleanup] = function()
			_isHovered:set(false)
			springConnection:Disconnect()
		end,
	})

	answer.Text = text:gsub("^%d+%. ", "")

	local optionCount = #optionsFrame:GetChildren() - 2
	number.Text = "#" .. optionCount

	return option
end

function DialogueUI.ClearOptions(frame: Frame)
	if not frame then
		return
	end

	for _, child in ipairs(frame:GetChildren()) do
		if child:IsA("Frame") and child.Name ~= "Template" then
			child:Destroy()
		end
	end
end

function DialogueUI.UpdateText(ui: { dialogueText: TextLabel? }, text: string)
	if ui.dialogueText then
		ui.dialogueText.Text = text
	end
end

return DialogueUI
