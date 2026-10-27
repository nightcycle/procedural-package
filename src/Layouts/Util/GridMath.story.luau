--!strict
local UILabs = require(game:GetService("ReplicatedStorage").DevPackages.UILabs)
local Components = game:GetService("ReplicatedStorage").DebugStories.Components
local Story = require(Components.Story)
local Controls = require(Components.Controls)
local Fixtures = require(Components.Fixtures)
local Preview = require(Components.Preview)
local Util = require(script.Parent)

return Story.create(
	"Grid math · Clamp / spacing / pause",
	"Inspect clampDimension and grid. Centers use area / count spacing; fixed footprints have gaps or overlap. Turn off NaturalFootprint to partition the area.",
	{
		ProposedColumns = UILabs.Slider(5.8, 0, 12, 0.1),
		Minimum = UILabs.Slider(2, 0, 8, 1),
		Maximum = UILabs.Slider(6, 0, 8, 1),
		Rows = UILabs.Slider(3, 0, 8, 1),
		PauseInterval = UILabs.Slider(4, 1, 32, 1),
		CellWidth = UILabs.Slider(6, 1, 50, 1),
		CellDepth = UILabs.Slider(8, 1, 40, 1),
		NaturalFootprint = true,
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
		local naturalSize = if Controls.boolean(values, "NaturalFootprint")
			then Vector3.new(
				Controls.number(values, "CellWidth"),
				parameters.Size.Y,
				Controls.number(values, "CellDepth")
			)
			else nil
		local cells = Util.grid(parameters, columns, rows, naturalSize)
		scene.Box(CFrame.identity, parameters.Size, Fixtures.Gold)
		for _, cell in cells do
			scene.Box(cell.Frame, cell.Size, Fixtures.Blue)
		end
		local expected = math.floor(#cells / parameters.Attributes.Layout_PauseInterval)
		local cellSize = if cells[1] then cells[1].Size else Vector3.zero
		local gapX = if #cells > 0 and columns > 1 then cells[2].Frame.X - cells[1].Frame.X - cellSize.X else 0
		local gapZ = if #cells > 0 and rows > 1 then cells[columns + 1].Frame.Z - cells[1].Frame.Z - cellSize.Z else 0
		scene.Marker(CFrame.identity)
		scene.SetStatus(
			`{columns} columns × {rows} rows = {#cells} cells · gap X/Z {string.format("%.2f / %.2f", gapX, gapZ)} (negative = overlap)\nPause calls: {pauses} / expected {expected} · {if pauses
						== expected
					and #cells == columns * rows
				then "PASS"
				else "FAIL"}`
		)
	end
)
