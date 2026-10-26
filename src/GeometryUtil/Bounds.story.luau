--!strict
local UILabs = require(game:GetService("ReplicatedStorage").DevPackages.UILabs)
local Components = game:GetService("ReplicatedStorage").DebugStories.Components
local Story = require(Components.Story)
local Controls = require(Components.Controls)
local Fixtures = require(Components.Fixtures)
local Geometry = require(script.Parent)

return Story.create(
	"Bounds math · Rotated extents",
	"Compare axisAlignedSize with an independent eight-corner calculation. Blue = rotated part; gold = world-axis bounds.",
	{
		Width = UILabs.Slider(8, 1, 16, 0.5),
		Height = UILabs.Slider(3, 1, 16, 0.5),
		Depth = UILabs.Slider(5, 1, 16, 0.5),
		Roll = UILabs.Slider(20, -180, 180, 1),
		Pan = UILabs.Slider(35, -180, 180, 1),
		Tilt = UILabs.Slider(10, -180, 180, 1),
	},
	function(scene, values)
		local size = Vector3.new(
			Controls.number(values, "Width"),
			Controls.number(values, "Height"),
			Controls.number(values, "Depth")
		)
		local frame = CFrame.Angles(
			math.rad(Controls.number(values, "Roll")),
			math.rad(Controls.number(values, "Pan")),
			math.rad(Controls.number(values, "Tilt"))
		)
		Fixtures.part("RotatedSource", size, frame, Fixtures.Blue, scene.Content)
		local bounds = Geometry.axisAlignedSize(frame, size)
		local minimum, maximum = Vector3.one * math.huge, -Vector3.one * math.huge
		for x = -1, 1, 2 do
			for y = -1, 1, 2 do
				for z = -1, 1, 2 do
					local point = frame:PointToWorldSpace(size * Vector3.new(x, y, z) / 2)
					minimum, maximum = minimum:Min(point), maximum:Max(point)
				end
			end
		end
		local errorMagnitude = (bounds - (maximum - minimum)).Magnitude
		scene.Box(CFrame.identity, bounds, Fixtures.Gold)
		scene.Marker(CFrame.identity)
		scene.SetStatus(
			`axisAlignedSize = {bounds}\nCorner comparison: {if errorMagnitude < 0.001 then "PASS" else "FAIL"} · error {string.format(
				"%.6f",
				errorMagnitude
			)} studs`
		)
	end
)
