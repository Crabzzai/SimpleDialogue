--!strict
--!optimize 2

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

type UIConfig = Types.UIConfig

local FloatingTextUI = {}
local partToSurfaceGui = {}

function FloatingTextUI.CreateSurfaceGui(part: Part): SurfaceGui
	if partToSurfaceGui[part] then
		local existingGui = partToSurfaceGui[part]
		if existingGui.Parent == part then
			return existingGui
		end
	end

	local surfaceGui = New("SurfaceGui")({
		Name = "FloatingTextSurfaceGui",
		Parent = part,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = 50,
		LightInfluence = 0,
		AlwaysOnTop = true,
		Face = Enum.NormalId.Back,
		Adornee = part,
		ZOffset = 1,
		ResetOnSpawn = false,
		ClipsDescendants = false,
		MaxDistance = 0,
	})

	partToSurfaceGui[part] = surfaceGui

	part.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			partToSurfaceGui[part] = nil
		end
	end)

	return surfaceGui :: SurfaceGui
end

function FloatingTextUI.Create(part: Part): { frame: Frame, textLabel: TextLabel }
	local ui = {}

	local existingSurfaceGui = part:FindFirstChildOfClass("SurfaceGui")
	local existingFrame = existingSurfaceGui and existingSurfaceGui:FindFirstChild("FloatingTextFrame")

	if existingFrame and existingFrame:IsA("Frame") then
		ui.frame = existingFrame
		ui.textLabel = existingFrame:FindFirstChild("TextLabel") :: TextLabel
		return ui
	end

	local surfaceGui = FloatingTextUI.CreateSurfaceGui(part)

	ui.frame = New("Frame")({
		Name = "FloatingTextFrame",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(300, 40),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Parent = surfaceGui,
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
				Name = "TextLabel",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				Text = "",
				TextScaled = true,
				Font = Enum.Font.SourceSansBold,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextYAlignment = Enum.TextYAlignment.Center,
				TextWrapped = true,
				TextColor3 = Color3.fromRGB(255, 255, 255),
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
	}) :: Frame

	ui.textLabel = ui.frame:FindFirstChild("TextLabel") :: TextLabel

	return ui
end

function FloatingTextUI.Cleanup(part: Part)
	local surfaceGui = partToSurfaceGui[part]
	if surfaceGui then
		surfaceGui:Destroy()
		partToSurfaceGui[part] = nil
	end
end

function FloatingTextUI.UpdateText(ui: { frame: Frame?, textLabel: TextLabel? }?, text: string)
	if ui and ui.textLabel then
		ui.textLabel.Text = text
	end
end

function FloatingTextUI.Show(ui: { frame: Frame?, textLabel: TextLabel? }?)
	if ui and ui.frame then
		ui.frame.Visible = true
	end
end

function FloatingTextUI.Hide(ui: { frame: Frame?, textLabel: TextLabel? }?)
	if ui and ui.frame then
		ui.frame.Visible = false
	end
end

function FloatingTextUI.UpdateOrientation(part: Part)
	if not part then
		return
	end

	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	local camCFrame = camera.CFrame
	local camLook = camCFrame.LookVector.Unit

	local lookDir = Vector3.new(camLook.X, camLook.Y, camLook.Z).Unit
	local finalCFrame = CFrame.lookAt(part.Position, part.Position + lookDir, Vector3.new(0, 1, 0))

	part.CFrame = finalCFrame
end

return FloatingTextUI
