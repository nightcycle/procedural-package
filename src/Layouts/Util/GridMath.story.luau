--!strict
local UILabs = require(game:GetService("ReplicatedStorage").DevPackages.UILabs)
local Components = game:GetService("ReplicatedStorage").DebugStories.Components
local Story = require(Components.Story)
local Controls = require(Components.Controls)
local Fixtures = require(Components.Fixtures)
local Preview = require(Components.Preview)
local Util = require(script.Parent)

return Story.create(
	"Grid math · Clamp / partition / pause",
	"Directly inspect clampDimension and grid. Every column × row cell must partition the full X/Z area.",
	{
		ProposedColumns = UILabs.Slider(5.8, 0, 12, 0.1),
		Minimum = UILabs.Slider(2, 1, 8, 1),
		Maximum = UILabs.Slider(6, 1, 8, 1),
		Rows = UILabs.Slider(3, 1, 8, 1),
		PauseInterval = UILabs.Slider(4, 1, 32, 1),
	},
	function(scene, values)
		local a, b = Controls.number(values, "Minimum"), Controls.number(values, "Maximum")
		local columns = Util.clampDimension(
			Controls.number(values, "ProposedColumns"),
			NumberRange.new(math.min(a, b), math.max(a, b))
		)
		local rows = Controls.number(values, "Rows")
		local parameters = Preview.parameters({ Layout_PauseInterval = Controls.number(values, "PauseInterval") })
		local pauses = 0
		parameters.Pause = function()
			pauses += 1
		end
		local cells = Util.grid(parameters, columns, rows)
		for _, cell in cells do
			scene.Box(cell.Frame, cell.Size, Fixtures.Blue)
		end
		local expected = math.floor(#cells / parameters.Attributes.Layout_PauseInterval)
		scene.Marker(CFrame.identity)
		scene.SetStatus(
			`floor + clamp → {columns} columns × {rows} rows = {#cells} cells\nPause calls: {pauses} / expected {expected} · {if pauses
						== expected
					and #cells == columns * rows
				then "PASS"
				else "FAIL"}`
		)
	end
)
