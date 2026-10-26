--!strict
local UILabs = require(game:GetService("ReplicatedStorage").DevPackages.UILabs)
local Components = game:GetService("ReplicatedStorage").DebugStories.Components
local Story = require(Components.Story)
local Controls = require(Components.Controls)
local Fixtures = require(Components.Fixtures)
local Types = require(script.Parent.Parent.Types)
local Source = require(script.Parent)
local methods: { Types.ScaleMethod } = { "Stretch", "Fit", "Fill" }
local references: { Types.ScaleReference } = { "Min", "Max", "Average", "Height" }

return Story.create(
	"Source attributes · Fitting and padding",
	"Calls prepareClone directly. Blue = target cell; gold = fitted geometry, including random scale and source Model scale.",
	{
		Source_ScaleMethod = UILabs.Choose(methods, 3),
		Source_ScaleReference = UILabs.Choose(references),
		PaddingScale = UILabs.Slider(0.1, 0, 0.45, 0.01),
		PaddingOffset = UILabs.Slider(0, 0, 1, 0.1),
		Random_Scale = UILabs.Slider(1, 0.1, 2, 0.05),
		SourceModelScale = UILabs.Slider(1, 0.25, 3, 0.25),
		Rotation = UILabs.Slider(0, -90, 90, 1),
		AsModel = true,
	},
	function(scene, values)
		local template = Fixtures.template(Controls.boolean(values, "AsModel"), true)
		scene.Keep(template)
		if template:IsA("Model") then
			template:ScaleTo(Controls.number(values, "SourceModelScale"))
		end
		local cellSize = Vector3.new(14, 12, 10)
		local copy = Source.prepareClone(
			template,
			cellSize,
			CFrame.Angles(0, math.rad(Controls.number(values, "Rotation")), 0),
			Controls.choose(values, "Source_ScaleMethod", methods) :: Types.ScaleMethod,
			Controls.choose(values, "Source_ScaleReference", references) :: Types.ScaleReference,
			Controls.number(values, "Random_Scale"),
			UDim.new(Controls.number(values, "PaddingScale"), Controls.number(values, "PaddingOffset")),
			"Center"
		)
		Fixtures.tint(copy, Fixtures.Gold)
		local displayed: Instance = copy
		displayed.Parent = scene.Content
		scene.Box(CFrame.identity, cellSize, Fixtures.Blue)
		scene.Marker(CFrame.identity)
		scene.SetStatus(
			`{Controls.string(values, "Source_ScaleMethod")} / {Controls.string(values, "Source_ScaleReference")} · random scale {Controls.number(
				values,
				"Random_Scale"
			)}\nModel scale {if template:IsA("Model") then template:GetScale() else 1} · Fit caps growth; Fill may enlarge; Stretch uses nonuniform BasePart scaling.`
		)
	end
)
