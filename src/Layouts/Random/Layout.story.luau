--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Components = ReplicatedStorage.DebugStories.Components
local Story = require(Components.Story)
local Controls = require(Components.Controls)
local Fixtures = require(Components.Fixtures)
local Preview = require(Components.Preview)
local CastSolver = require(script.Parent.Parent.Parent.CastSolver)
local Types = require(script.Parent.Parent.Parent.Types)
local axes: { Types.HeightAxis } = { "X", "Y", "Z" }

return Story.create(
	"Random · 3D placement and overlap checks",
	"Independent volume sampling of authored-size copies. Toggle overlap avoidance to query previously accepted geometry.",
	{
		Population = UILabs.Slider(40, 0, 100, 1),
		Seed = UILabs.Slider(2026, 0, 10000, 1),
		Width = UILabs.Slider(40, 5, 80, 1),
		Height = UILabs.Slider(20, 5, 60, 1),
		Depth = UILabs.Slider(30, 5, 60, 1),
		Scale = UILabs.Slider(1, 0.1, 4, 0.1),
		Yaw = UILabs.Slider(45, 0, 180, 5),
		AvoidOverlap = false,
		Attempts = UILabs.Slider(32, 1, 64, 1),
		HeightAxis = UILabs.Choose(axes, 2),
		AsModel = false,
	},
	function(scene, values)
		local parameters = Preview.parameters({
			Layout_Type = "Random",
			Layout_PopulationLimit = NumberRange.new(Controls.number(values, "Population")),
			Random_Seed = Controls.number(values, "Seed"),
			Random_Scale = NumberRange.new(Controls.number(values, "Scale")),
			Random_Pan = NumberRange.new(-Controls.number(values, "Yaw"), Controls.number(values, "Yaw")),
			Layout_HeightAxis = Controls.choose(values, "HeightAxis", axes),
			Layout_AvoidOverlap = Controls.boolean(values, "AvoidOverlap"),
			Layout_PlacementAttempts = Controls.number(values, "Attempts"),
			Source_Padding = UDim.new(0.05, 0),
		})
		parameters.Size = Vector3.new(
			Controls.number(values, "Width"),
			Controls.number(values, "Height"),
			Controls.number(values, "Depth")
		)
		local template = Fixtures.template(Controls.boolean(values, "AsModel"))
		scene.Keep(template)
		if template:IsA("BasePart") then
			template.CanQuery = true
		end
		for _, child in template:GetDescendants() do
			if child:IsA("BasePart") then
				child.CanQuery = true
			end
		end
		local owner = Instance.new("ProceduralModel")
		owner.Size = parameters.Size
		owner:PivotTo(CFrame.identity)
		scene.Keep(owner)
		local count = Preview.generate(scene, parameters, template, false, owner, CastSolver.new(scene.World))
		scene.Box(CFrame.identity, parameters.Size, Fixtures.Blue)
		scene.SetStatus(
			`Placed {count} / {parameters.Attributes.Layout_PopulationLimit.Min} · overlap checks {if parameters.Attributes.Layout_AvoidOverlap
				then "ON"
				else "OFF"}\nSource proportions stay fixed as population changes. Occupied candidates retry up to {parameters.Attributes.Layout_PlacementAttempts} times.`
		)
	end
)
