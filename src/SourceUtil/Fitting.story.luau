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
	"Calls prepareClone directly. Blue = target cell; gold = fitted geometry. SurfacePadding reserves X/Z space without reducing available height.",
	{
		Source_ScaleMethod = UILabs.Choose(methods, 3),
		Source_ScaleReference = UILabs.Choose(references, 4),
		PaddingScale = UILabs.Slider(0.1, 0, 0.45, 0.01),
		PaddingOffset = UILabs.Slider(0, 0, 1, 0.1),
		Random_Scale = UILabs.Slider(1, 0.1, 2, 0.05),
		SourceModelScale = UILabs.Slider(1, 0.25, 3, 0.25),
		Rotation = UILabs.Slider(0, -90, 90, 1),
		AsModel = true,
		SurfacePadding = true,
	},
	function(scene, values)
		local template = Fixtures.template(Controls.boolean(values, "AsModel"), true)
		scene.Keep(template)
		if template:IsA("Model") then
			template:ScaleTo(Controls.number(values, "SourceModelScale"))
		end
		local cellSize = Vector3.new(14, 12, 10)
		local method: Types.ScaleMethod = Controls.choose(values, "Source_ScaleMethod", methods) :: Types.ScaleMethod
		local reference: Types.ScaleReference =
			Controls.choose(values, "Source_ScaleReference", references) :: Types.ScaleReference
		local surfacePadding = Controls.boolean(values, "SurfacePadding")
		local randomScale = Controls.number(values, "Random_Scale")
		local copy = Source.prepareClone(
			template,
			cellSize,
			CFrame.Angles(0, math.rad(Controls.number(values, "Rotation")), 0),
			method,
			reference,
			randomScale,
			UDim.new(Controls.number(values, "PaddingScale"), Controls.number(values, "PaddingOffset")),
			"Center",
			if surfacePadding then Vector3.new(1, 0, 1) else Vector3.one
		)
		local height: number
		if copy:IsA("Model") then
			local _, size = copy:GetBoundingBox()
			height = size.Y
		else
			height = copy.Size.Y
		end
		local heightCheck = ""
		if surfacePadding and method == "Fill" and reference == "Height" then
			local expected = cellSize.Y * randomScale
			assert(math.abs(height - expected) < 0.001, "surface padding changed Fill/Height output height")
			heightCheck = ` · expected {string.format("%.2f", expected)} PASS`
		end
		Fixtures.tint(copy, Fixtures.Gold)
		local displayed: Instance = copy
		displayed.Parent = scene.Content
		scene.Box(CFrame.identity, cellSize, Fixtures.Blue)
		scene.Marker(CFrame.identity)
		scene.SetStatus(
			`{method} / {reference} · height {string.format("%.2f", height)}{heightCheck}\nRandom scale {randomScale} · Model scale {if template:IsA(
					"Model"
				)
				then template:GetScale()
				else 1} · Fit caps growth; Fill may enlarge; Stretch uses nonuniform BasePart scaling.`
		)
	end
)
