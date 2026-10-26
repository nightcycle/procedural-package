--!strict
local UILabs = require(game:GetService("ReplicatedStorage").DevPackages.UILabs)
-- UI Labs forwards plugin-canvas input through its environment adapter.
local UserInput = UILabs.Environment.UserInput
local Fixtures = require(script.Parent.Fixtures)

export type Scene = {
	Root: Frame,
	World: WorldModel,
	Content: Model,
	Camera: Camera,
	Status: TextLabel,
	Keep: (Instance) -> (),
	Clear: () -> (),
	Destroy: () -> (),
	Fit: () -> (),
	SetStatus: (string) -> (),
	Line: (Vector3, Vector3, Color3, number?) -> (),
	Box: (CFrame, Vector3, Color3) -> (),
	Marker: (CFrame, number?) -> (),
}
local Viewport = {}

function Viewport.new(target: GuiObject, title: string, description: string): Scene
	local root = Instance.new("Frame")
	root.Name = "VisualDebug"
	root.Size = UDim2.fromOffset(960, 680)
	root.BackgroundColor3 = Color3.fromRGB(19, 24, 34)
	root.BorderSizePixel = 0
	root.ClipsDescendants = true
	root.Parent = target
	local function text(name: string, value: string, position: UDim2, size: UDim2, textSize: number): TextLabel
		local label = Instance.new("TextLabel")
		label.Name = name
		label.Text = value
		label.Position = position
		label.Size = size
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.Code
		label.TextColor3 = Color3.fromRGB(220, 231, 247)
		label.TextSize = textSize
		label.TextWrapped = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Center
		label.Parent = root
		return label
	end
	text("Title", title, UDim2.fromOffset(20, 10), UDim2.new(1, -130, 0, 28), 21)
	text("Description", description, UDim2.fromOffset(20, 40), UDim2.new(1, -40, 0, 36), 14)
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Viewport"
	viewport.Position = UDim2.fromOffset(12, 84)
	viewport.Size = UDim2.new(1, -24, 1, -182)
	viewport.BackgroundColor3 = Color3.fromRGB(27, 35, 49)
	viewport.BorderSizePixel = 0
	viewport.Ambient = Color3.fromRGB(170, 185, 210)
	viewport.LightColor = Color3.new(1, 0.96, 0.86)
	viewport.LightDirection = Vector3.new(-1, -2, -1)
	viewport.Active = true
	viewport.Parent = root
	local world = Instance.new("WorldModel")
	world.Name = "PreviewWorld"
	world.Parent = viewport
	local content = Instance.new("Model")
	content.Name = "Content"
	content.Parent = world
	local camera = Instance.new("Camera")
	camera.FieldOfView = 45
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local status = text("Status", "", UDim2.new(0, 20, 1, -90), UDim2.new(1, -40, 0, 54), 14)
	text(
		"Hint",
		"Drag to orbit · Scroll to zoom · RGB axes = X / Y / Z · Gold = solved result",
		UDim2.new(0, 20, 1, -30),
		UDim2.new(1, -40, 0, 24),
		12
	)
	local connections: { RBXScriptConnection } = {}
	local retained: { Instance } = {}
	local center, radius = Vector3.zero, 20
	local yaw, pitch, zoom = math.rad(38), math.rad(28), 1
	local dragging = false
	local alive = true
	local function updateCamera()
		local size = viewport.AbsoluteSize
		local aspect = if size.Y > 0 then math.max(size.X / size.Y, 0.1) else 1.8
		local vertical = math.rad(camera.FieldOfView / 2)
		local limiting = math.min(vertical, math.atan(math.tan(vertical) * aspect))
		local distance = radius / math.sin(limiting) * 1.12 * zoom
		local direction = Vector3.new(math.cos(pitch) * math.sin(yaw), math.sin(pitch), math.cos(pitch) * math.cos(yaw))
		camera.CFrame = CFrame.lookAt(center + direction * distance, center)
	end
	local reset = Instance.new("TextButton")
	reset.Name = "ResetCamera"
	reset.Text = "Reset view"
	reset.Position = UDim2.new(1, -112, 0, 12)
	reset.Size = UDim2.fromOffset(96, 28)
	reset.BackgroundColor3 = Color3.fromRGB(54, 76, 103)
	reset.BorderSizePixel = 0
	reset.TextColor3 = Color3.new(1, 1, 1)
	reset.Font = Enum.Font.Code
	reset.TextSize = 13
	reset.Parent = root
	table.insert(
		connections,
		reset.Activated:Connect(function()
			yaw, pitch, zoom = math.rad(38), math.rad(28), 1
			updateCamera()
		end)
	)
	table.insert(
		connections,
		viewport.InputBegan:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = true
			end
		end)
	)
	table.insert(
		connections,
		UserInput.InputEnded:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				dragging = false
			end
		end)
	)
	table.insert(
		connections,
		UserInput.InputChanged:Connect(function(input: InputObject)
			if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
				yaw -= input.Delta.X * 0.008
				pitch = math.clamp(pitch + input.Delta.Y * 0.008, math.rad(-80), math.rad(85))
				updateCamera()
			end
		end)
	)
	table.insert(
		connections,
		viewport.InputChanged:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseWheel then
				zoom = math.clamp(zoom * 0.85 ^ input.Position.Z, 0.2, 5)
				updateCamera()
			end
		end)
	)
	table.insert(connections, viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateCamera))
	local function clear()
		content:ClearAllChildren()
		for _, instance in retained do
			instance:Destroy()
		end
		table.clear(retained)
	end
	local function line(a: Vector3, b: Vector3, color: Color3, thickness: number?)
		local length = (b - a).Magnitude
		if length < 0.0001 then
			return
		end
		Fixtures.part(
			"Guide",
			Vector3.new(thickness or 0.08, thickness or 0.08, length),
			CFrame.lookAt((a + b) / 2, b),
			color,
			content
		)
	end
	return {
		Root = root,
		World = world,
		Content = content,
		Camera = camera,
		Status = status,
		Keep = function(instance: Instance)
			table.insert(retained, instance)
		end,
		Clear = clear,
		Destroy = function()
			if not alive then
				return
			end
			alive = false
			for _, connection in connections do
				connection:Disconnect()
			end
			clear()
			root:Destroy()
		end,
		Fit = function()
			if #content:GetDescendants() > 0 then
				local frame, size = content:GetBoundingBox()
				center, radius = frame.Position, math.max(size.Magnitude / 2, 2)
			end
			updateCamera()
		end,
		SetStatus = function(value: string)
			status.Text = value
		end,
		Line = line,
		Box = function(frame: CFrame, size: Vector3, color: Color3)
			local half = size / 2
			for axis = 1, 3 do
				for a = -1, 1, 2 do
					for b = -1, 1, 2 do
						local start = if axis == 1
							then Vector3.new(-half.X, a * half.Y, b * half.Z)
							elseif axis == 2 then Vector3.new(a * half.X, -half.Y, b * half.Z)
							else Vector3.new(a * half.X, b * half.Y, -half.Z)
						local finish = start
							+ (
								if axis == 1
									then Vector3.xAxis * size.X
									elseif axis == 2 then Vector3.yAxis * size.Y
									else Vector3.zAxis * size.Z
							)
						line(frame:PointToWorldSpace(start), frame:PointToWorldSpace(finish), color)
					end
				end
			end
		end,
		Marker = function(frame: CFrame, length: number?)
			local origin = frame.Position
			local size = length or 3
			line(origin, origin + frame.RightVector * size, Fixtures.Red, 0.16)
			line(origin, origin + frame.UpVector * size, Fixtures.Green, 0.16)
			line(origin, origin - frame.LookVector * size, Fixtures.Blue, 0.16)
			local dot = Fixtures.part("Origin", Vector3.one * 0.35, CFrame.new(origin), Fixtures.Gold, content)
			dot.Shape = Enum.PartType.Ball
		end,
	}
end

return Viewport
