--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UILabs = require(ReplicatedStorage.DevPackages.UILabs)
local Components = ReplicatedStorage.DebugStories.Components
local Story = require(Components.Story)
local Controls = require(Components.Controls)
local Fixtures = require(Components.Fixtures)
local Preview = require(Components.Preview)

return Story.create(
	"Random attributes · Seed / scale / rotations",
	"Production random placement and per-copy transforms. Return to the same seed to reproduce the same geometry.",
	{
		Random_Seed = UILabs.Slider(2026, 0, 10000, 1),
		Population = UILabs.Slider(18, 0, 60, 1),
		ScaleMin = UILabs.Slider(0.6, 0.1, 2, 0.05),
		ScaleMax = UILabs.Slider(1.3, 0.1, 2, 0.05),
		Roll = UILabs.Slider(0, 0, 90, 1),
		Pan = UILabs.Slider(180, 0, 180, 1),
		Tilt = UILabs.Slider(0, 0, 90, 1),
		AsModel = true,
		ShowCells = true,
	},
	function(scene, values)
		local low, high = Controls.number(values, "ScaleMin"), Controls.number(values, "ScaleMax")
		local roll, pan, tilt =
			Controls.number(values, "Roll"), Controls.number(values, "Pan"), Controls.number(values, "Tilt")
		local parameters = Preview.parameters({
			Layout_Type = "SurfaceRandom",
			Layout_PopulationLimit = NumberRange.new(Controls.number(values, "Population")),
			Random_Seed = Controls.number(values, "Random_Seed"),
			Random_Scale = NumberRange.new(math.min(low, high), math.max(low, high)),
			Random_Roll = NumberRange.new(-roll, roll),
			Random_Pan = NumberRange.new(-pan, pan),
			Random_Tilt = NumberRange.new(-tilt, tilt),
		})
		local template = Fixtures.template(Controls.boolean(values, "AsModel"))
		scene.Keep(template)
		local count = Preview.generate(scene, parameters, template, Controls.boolean(values, "ShowCells"))
		scene.SetStatus(
			`Seed {parameters.Attributes.Random_Seed} · {count} copies · scale {parameters.Attributes.Random_Scale}\nRanges use the lower/higher slider endpoints; rotation ranges are symmetric around zero.`
		)
	end
)
