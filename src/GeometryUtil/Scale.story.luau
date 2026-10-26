--!strict
local UILabs = require(game:GetService("ReplicatedStorage").DevPackages.UILabs)
local Components = game:GetService("ReplicatedStorage").DebugStories.Components
local Story = require(Components.Story)
local Controls = require(Components.Controls)
local Fixtures = require(Components.Fixtures)
local Geometry = require(script.Parent)

return Story.create(
	"Scale math · Geometry and native pivot offsets",
	"Blue = original footprint. Gold = scaled result. Exercise BasePart scaling and Model:ScaleTo through scaleInstance.",
	{
		Scale = UILabs.Slider(1.5, 0.05, 3, 0.05),
		AsModel = true,
		PrimaryPart = true,
	},
	function(scene, values)
		local template = Fixtures.template(Controls.boolean(values, "AsModel"), Controls.boolean(values, "PrimaryPart"))
		scene.Keep(template)
		local beforeFrame, beforeSize = Geometry.getExtents(template)
		scene.Box(beforeFrame, beforeSize, Fixtures.Blue)
		local expectedPivot = template:GetPivot()
		local copy = template:Clone()
		local factor = Controls.number(values, "Scale")
		if template:IsA("BasePart") then
			expectedPivot = template.CFrame
				* CFrame.new(template.PivotOffset.Position * factor)
				* template.PivotOffset.Rotation
		end
		Geometry.scaleInstance(copy, factor)
		local displayed: Instance = copy
		displayed.Parent = scene.Content
		Fixtures.tint(copy, Fixtures.Gold)
		local frame, size = Geometry.getExtents(copy)
		scene.Box(frame, size, Fixtures.Gold)
		scene.Marker(copy:GetPivot(), 4)
		local pivotError = (expectedPivot.Position - copy:GetPivot().Position).Magnitude
		scene.SetStatus(
			`Requested factor {factor} · extents {beforeSize} → {size}\n{if template:IsA("Model")
				then "Model pivot stays fixed"
				else "BasePart PivotOffset translation scales"}: {if pivotError < 0.001 then "PASS" else "FAIL"} · error {string.format(
				"%.6f",
				pivotError
			)} studs`
		)
	end
)
