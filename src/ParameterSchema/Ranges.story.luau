--!strict
local UILabs = require(game:GetService("ReplicatedStorage").DevPackages.UILabs)
local Components = game:GetService("ReplicatedStorage").DebugStories.Components
local Story = require(Components.Story)
local Controls = require(Components.Controls)
local Fixtures = require(Components.Fixtures)
local Schema = require(script.Parent)

return Story.create(
	"Range math · Validation boundaries",
	"Green = valid; red = invalid. Compare general, scale, population, and grid-dimension range validators.",
	{
		Minimum = UILabs.Slider(0, -3, 5, 0.1),
		Maximum = UILabs.Slider(3, -3, 5, 0.1),
	},
	function(scene, values)
		local a, b = Controls.number(values, "Minimum"), Controls.number(values, "Maximum")
		local range = NumberRange.new(math.min(a, b), math.max(a, b))
		local validators = {
			{ Name = "range", Check = Schema.range },
			{ Name = "scaleRange", Check = Schema.scaleRange },
			{ Name = "countRange", Check = Schema.countRange },
			{ Name = "dimensionRange", Check = Schema.dimensionRange },
		}
		local results: { string } = {}
		for index, validator in validators do
			local valid = validator.Check(range)
			Fixtures.part(
				validator.Name,
				Vector3.new(3, if valid then 6 else 1, 3),
				CFrame.new((index - 2.5) * 5, 0, 0),
				if valid then Fixtures.Green else Fixtures.Red,
				scene.Content
			)
			table.insert(results, `{validator.Name}: {if valid then "PASS" else "REJECT"}`)
		end
		scene.SetStatus(
			`Range {range} · left → right: general / scale / population / dimensions\n{table.concat(results, " · ")}`
		)
	end
)
