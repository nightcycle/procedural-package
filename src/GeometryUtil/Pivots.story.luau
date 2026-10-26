--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Components = ReplicatedStorage.DebugStories.Components
local Story = require(Components.Story)
local Controls = require(Components.Controls)
local Fixtures = require(Components.Fixtures)
local Types = require(script.Parent.Parent.Types)
local Geometry = require(script.Parent)
local methods: { Types.PivotMethod } = {
	"Pivot",
	"Center",
	"Bottom",
	"Top",
	"PrimaryPartPivot",
	"PrimaryPartCenter",
	"PrimaryPartBottom",
	"PrimaryPartTop",
}

return Story.create(
	"Pivot math · Native / extents / PrimaryPart",
	"Gold origin = getGeneratedPivot result. Toggle PrimaryPart to inspect the matching fallback behavior.",
	{
		Source_PivotMethod = UILabs.Choose(methods, 3),
		AsModel = true,
		PrimaryPart = true,
		Rotation = UILabs.Slider(0, -90, 90, 1),
	},
	function(scene, values)
		local template = Fixtures.template(Controls.boolean(values, "AsModel"), Controls.boolean(values, "PrimaryPart"))
		template:PivotTo(CFrame.Angles(0, 0, math.rad(Controls.number(values, "Rotation"))))
		local displayed: Instance = template
		displayed.Parent = scene.Content
		local method: Types.PivotMethod = Controls.choose(values, "Source_PivotMethod", methods) :: Types.PivotMethod
		local pivot = Geometry.getGeneratedPivot(template, method)
		local frame, size = Geometry.getExtents(template)
		scene.Box(frame, size, Fixtures.Blue)
		scene.Marker(pivot, 5)
		scene.SetStatus(
			`{method}: {pivot.Position}\n{if template:IsA("Model") and template.PrimaryPart
				then "PrimaryPart assigned"
				else "No PrimaryPart: PrimaryPart methods fall back to the corresponding regular method"}`
		)
	end
)
