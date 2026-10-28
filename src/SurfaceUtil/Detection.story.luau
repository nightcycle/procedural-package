--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Components = ReplicatedStorage.DebugStories.Components
local Story = require(Components.Story)
local Controls = require(Components.Controls)
local Fixtures = require(Components.Fixtures)
local Preview = require(Components.Preview)
local Types = require(script.Parent.Parent.Types)
local Surface = require(script.Parent)
local CastSolver = require(script.Parent.Parent.CastSolver)
local methods: { Types.SurfaceDetectionMethod } = { "Raycast", "Shapecast", "None" }

return Story.create(
	"Surface attributes · WorldModel casts",
	"Production detect uses a CastSolver bound to this viewport's WorldModel and private filters.",
	{
		Layout_SurfaceDetectionMethod = UILabs.Choose(methods),
		HitSurface = true,
		Slope = UILabs.Slider(12, -25, 25, 1),
		ModelScale = UILabs.Slider(1, 0.5, 2, 0.1),
		ModelYaw = UILabs.Slider(20, -90, 90, 1),
		LocalX = UILabs.Slider(0, -12, 12, 1),
	},
	function(scene, values)
		local scale = Controls.number(values, "ModelScale")
		local frame = CFrame.new(6, 8, 0) * CFrame.Angles(0, math.rad(Controls.number(values, "ModelYaw")), 0)
		local owner = Instance.new("ProceduralModel")
		scene.Keep(owner)
		owner.Size = Vector3.new(40, 16, 30)
		owner:ScaleTo(scale)
		owner:PivotTo(frame)
		local support = Fixtures.part(
			"Support",
			Vector3.new(40, 1, 28) * scale,
			frame * CFrame.new(0, -3 * scale, 0) * CFrame.Angles(0, 0, math.rad(Controls.number(values, "Slope"))),
			Fixtures.Blue,
			nil
		)
		support.CanCollide, support.CanQuery = true, true
		if Controls.boolean(values, "HitSurface") then
			support.Parent = scene.Content
		else
			scene.Keep(support)
		end
		local method = Controls.choose(values, "Layout_SurfaceDetectionMethod", methods) :: Types.SurfaceDetectionMethod
		local parameters = Preview.parameters({ Layout_SurfaceDetectionMethod = method })
		local localSize = Vector3.new(40, 16, 30)
		local origin = CFrame.new(Controls.number(values, "LocalX"), -localSize.Y / 2, 0)
		local copy = Fixtures.part("CastGeometry", Vector3.new(3, 6, 3), CFrame.identity, Fixtures.Gold, nil)
		scene.Keep(copy)
		copy.PivotOffset = CFrame.new(0, -3, 0)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { support }
		local target = Instance.new("Folder")
		scene.Keep(target)
		local solved = Surface.detect(
			copy,
			origin,
			parameters,
			Vector3.zero,
			localSize,
			target :: any,
			owner,
			CastSolver.new(scene.World, params)
		)
		local result = solved or origin
		copy.Size *= scale
		copy.PivotOffset = CFrame.new(copy.PivotOffset.Position * scale)
		copy:PivotTo(frame * CFrame.new(result.Position * scale) * result.Rotation)
		copy.Parent = scene.Content
		if not solved then
			Fixtures.tint(copy, Fixtures.Red, 0.6)
		end
		scene.Box(frame, localSize * scale, Color3.fromRGB(76, 93, 120))
		scene.Line(
			frame:PointToWorldSpace(Vector3.new(origin.X, 8, 0) * scale),
			frame:PointToWorldSpace(Vector3.new(origin.X, -8, 0) * scale),
			Fixtures.Green,
			0.16
		)
		scene.Marker(frame * CFrame.new(result.Position * scale), 3 * scale)
		scene.SetStatus(
			`{method} → {if solved then "PLACED" else "MISS / discarded by generation"} · local origin {result.Position}\nBlue = support; green = cast span; gold = placement; red ghost = miss. Owner scale {scale} is included in world queries.`
		)
	end
)
