--!strict
-- Exercise production layouts/transforms; only engine pivots and RNG need Lune adapters.
local roblox = require("@lune/roblox")
local makeLoader = require("./lib/load-package")
type RInstance = roblox.Instance & { [string]: any }
local datatypes = (roblox :: any) :: {
	CFrame: typeof(CFrame),
	Vector3: typeof(Vector3),
	NumberRange: typeof(NumberRange),
	UDim: typeof(UDim),
}
local CFrame, Vector3, NumberRange, UDim = datatypes.CFrame, datatypes.Vector3, datatypes.NumberRange, datatypes.UDim
roblox.implementMethod("BasePart", "GetPivot", function(part: RInstance): CFrame
	return part.CFrame * part.PivotOffset
end)
roblox.implementMethod("BasePart", "PivotTo", function(part: RInstance, frame: CFrame)
	part.CFrame = frame * part.PivotOffset:Inverse()
end)
local function random(seed: number)
	local state = seed + 1
	local function unit(): number
		state = (state * 16807 + 1) % 2147483647
		return state / 2147483647
	end
	return {
		NextNumber = function(_self: unknown, low: number, high: number): number
			return low + (high - low) * unit()
		end,
		NextInteger = function(_self: unknown, low: number, high: number): number
			return low + math.floor((high - low + 1) * unit())
		end,
		Shuffle = function<T>(_self: unknown, array: { T })
			for index = #array, 2, -1 do
				local other = math.floor(unit() * index) + 1
				array[index], array[other] = array[other], array[index]
			end
		end,
	}
end
local template = roblox.Instance.new("Part") :: RInstance
template.Size = Vector3.new(2, 3, 5)
local load = makeLoader({ Random = { new = random } }, {
	IndexUtil = {
		waitForPath = function()
			return template
		end,
	},
})
local Parameters, Source, Geometry, Layouts =
	load("src/ParameterUtil"), load("src/SourceUtil"), load("src/GeometryUtil"), load("src/Layouts")
local generator = load("src/Generator").new()
local kinds =
	{ "Single", "SurfaceGrid", "SurfaceRandom", "SurfaceCurvedLine", "Stack", "Arch", "NGon", "Grid", "Random" }
local function parameters(kind: string): any
	local attributes = Parameters.getDefaults(nil, kind)
	attributes.Source_Path = "template"
	attributes.Source_PivotMethod = "Center"
	attributes.Source_ScaleMethod = "Fit"
	attributes.Source_Padding = UDim.new(0)
	return Parameters.resolve({ Attributes = attributes, Size = Vector3.new(40, 24, 30), Pause = function() end })
end
local function generate(scoped: any): { RInstance }
	local target = roblox.Instance.new("Folder")
	generator.OnGenerate(scoped, target)
	local copies = target:GetChildren() :: { RInstance }
	for _, copy in copies do
		copy.Parent = nil
	end
	target:Destroy()
	return copies
end
local function close(a: Vector3, b: Vector3, message: string)
	assert((a - b).Magnitude < 0.001, `{message}: {a} ~= {b}`)
end
local function within(copy: RInstance, size: Vector3)
	local frame, bounds = Geometry.getBounds(copy)
	local edge = frame.Position:Abs() + bounds / 2
	assert(
		edge.X <= size.X / 2 + 0.001 and edge.Y <= size.Y / 2 + 0.001 and edge.Z <= size.Z / 2 + 0.001,
		`out of bounds: {edge} / {size}`
	)
end

-- HeightAxis rotates before measuring/fitting and remains applied after layout rotation.
for _, axis in { "X", "Y", "Z" } do
	local raw = if axis == "X" then Vector3.new(3, 2, 5) elseif axis == "Z" then Vector3.new(2, 5, 3) else template.Size
	for _, kind in kinds do
		local scoped = parameters(kind)
		scoped.Attributes.Layout_HeightAxis = axis
		scoped.Attributes.Source_ScaleMethod = "Fill"
		scoped.Attributes.Source_ScaleReference = "Height"
		close(
			Source.getLayoutSize({ template }, scoped),
			if kind == "Grid" or kind == "Random" then raw else raw * (24 / raw.Y),
			`{kind}/{axis} bounds`
		)
		scoped.Attributes.Source_ScaleMethod = "Fit"
		local copies = generate(scoped)
		assert(#copies > 0, kind)
		for _, copy in copies do
			local direction = if axis == "X"
				then copy.CFrame.RightVector
				elseif axis == "Z" then copy.CFrame.ZVector
				else copy.CFrame.UpVector
			if kind ~= "Arch" then
				close(direction, Vector3.yAxis, `{kind}/{axis} initial rotation lost`)
			end
			copy:Destroy()
		end
	end
	local scoped = parameters("Single")
	scoped.Attributes.Layout_HeightAxis = axis
	scoped.Attributes.Source_ScaleMethod = "Stretch"
	local copy = Source.prepareForLayout(template, scoped, 1)
	local _, size = Geometry.getBounds(copy)
	close(size, scoped.Size, `Stretch must map target dimensions into {axis} source axes`)
	copy:Destroy()
	for _, pivot in { "Bottom", "Top", "PrimaryPartBottom", "PrimaryPartTop" } do
		scoped.Attributes.Source_PivotMethod = pivot
		copy = Source.prepareForLayout(template, scoped, 1)
		local frame, bounds = Geometry.getBounds(copy)
		local bottom = pivot == "Bottom" or pivot == "PrimaryPartBottom"
		assert(math.abs(frame.Y - (if bottom then bounds.Y / 2 else -bounds.Y / 2)) < 0.001, `wrong {axis}/{pivot}`)
		copy:Destroy()
	end
end

-- Per-template axis overrides affect both reservation and placement without changing area attributes.
local scoped = parameters("Single")
template:SetAttribute("Layout_HeightAxis", "Z")
close(Source.getLayoutSize({ template }, scoped), Vector3.new(2, 5, 3), "override reservation")
local copies = generate(scoped)
close(copies[1].CFrame.ZVector, Vector3.yAxis, "override placement")
assert(scoped.Attributes.Layout_HeightAxis == "Y")
copies[1]:Destroy()
template:SetAttribute("Layout_HeightAxis", "invalid")
assert(not pcall(function()
	generate(scoped)
end), "invalid template axis accepted")
template:SetAttribute("Layout_HeightAxis", nil)

-- Volume variants fit small 3D cells and allow overlapping height intervals under Floor alignment.
for _, kind in { "Grid" } do
	scoped = parameters(kind)
	scoped.Attributes.Layout_ColumnLimit, scoped.Attributes.Layout_RowLimit = NumberRange.new(4), NumberRange.new(3)
	scoped.Attributes.Layout_PopulationLimit = NumberRange.new(12)
	scoped.Attributes.Layout_LayerLimit = NumberRange.new(4)
	scoped.Attributes.Source_ScaleMethod = "Stretch"
	scoped.Attributes.Source_PivotMethod = "Bottom"
	scoped.Attributes.Layout_SurfaceDetectionMethod = "Raycast"
	scoped.Attributes.Solver_Cast_Path = "must-not-resolve"
	local volume = Layouts[kind].GetCells(scoped, template.Size, random(3))
	assert(#volume == 48)
	for _, cell in volume do
		assert(cell.FitSize == cell.Size and cell.Size.Y < scoped.Size.Y, "volume cell must subdivide height")
	end
	local first, second = generate(scoped), generate(scoped)
	local heights: { [number]: boolean } = {}
	local overlapping = false
	for index, copy in first do
		within(copy, scoped.Size)
		assert(copy.Size.Y < scoped.Size.Y, "pillar stretched to full area height")
		assert(copy.CFrame == second[index].CFrame, "same seed changed volume placement")
		heights[math.round(copy.CFrame.Y * 1000)] = true
		for otherIndex = 1, index - 1 do
			local other = first[otherIndex]
			local sameColumn = math.abs(copy.CFrame.X - other.CFrame.X) < (copy.Size.X + other.Size.X) / 2
				and math.abs(copy.CFrame.Z - other.CFrame.Z) < (copy.Size.Z + other.Size.Z) / 2
			if sameColumn and math.abs(copy.CFrame.Y - other.CFrame.Y) < (copy.Size.Y + other.Size.Y) / 2 - 0.001 then
				overlapping = true
			end
		end
		second[index]:Destroy()
	end
	for _, copy in first do
		copy:Destroy()
	end
	local distinct = 0
	for _ in heights do
		distinct += 1
	end
	assert(distinct > 1, "Floor alignment collapsed random height")
	assert(overlapping, "volume cells never overlap vertically")
end

-- Random uses independent normalized samples, with no density-dependent cells or fitting sizes.
scoped = parameters("Random")
scoped.Attributes.Layout_PopulationLimit = NumberRange.new(12)
local scatter = Layouts.Random.GetCells(scoped, template.Size, random(3))
assert(#scatter == 12)
for _, cell in scatter do
	assert(cell.Frame == CFrame.identity and cell.Size == scoped.Size and cell.FitSize == nil)
	assert(
		cell.Offset
			and cell.Offset.X >= -0.5
			and cell.Offset.X <= 0.5
			and cell.Offset.Y >= -0.5
			and cell.Offset.Y <= 0.5
			and cell.Offset.Z >= -0.5
			and cell.Offset.Z <= 0.5
	)
end

-- Stack pads resolve in X/Z, interpolate bottom-to-top, and leave height unchanged.
scoped = parameters("Stack")
scoped.Attributes.Source_ScaleMethod = "Stretch"
scoped.Attributes.Layout_PopulationLimit = NumberRange.new(3)
scoped.Attributes.Layout_BasePadding, scoped.Attributes.Layout_TopPadding = UDim.new(0.1, 1), UDim.new(0.25, 2)
copies = generate(scoped)
assert(#copies == 3)
close(copies[1].Size, Vector3.new(30.4, 8, 22.4), "base padding")
close(copies[3].Size, Vector3.new(18, 8, 13), "top padding")
assert(copies[1].CFrame.Y == -8 and copies[3].CFrame.Y == 8)
for _, copy in copies do
	within(copy, scoped.Size)
	copy:Destroy()
end

-- Arch thickness follows its tangent; all rotated geometry fits the rectangular area.
for _, shape in { 0, 0.1, 0.5, 0.9, 0.9999, 1 } do
	for _, dimensions in { Vector3.new(60, 17, 13), Vector3.new(17, 60, 13), Vector3.new(20, 20, 8) } do
		for _, count in { 1, 2, 3, 4, 9, 20 } do
			scoped = parameters("Arch")
			scoped.Size = dimensions
			scoped.Attributes.Source_ScaleMethod = "Stretch"
			scoped.Attributes.Layout_ArchShape = shape
			scoped.Attributes.Layout_BasePadding = UDim.new(0.1, 0.1)
			scoped.Attributes.Layout_TopPadding = UDim.new(0.2, 0.2)
			scoped.Attributes.Layout_PopulationLimit = NumberRange.new(count)
			copies = generate(scoped)
			assert(#copies == count)
			if count > 2 then
				assert(copies[math.ceil(count / 2)].CFrame.Y > copies[1].CFrame.Y, "arch crown missing")
			end
			local minimum, maximum = math.huge, -math.huge
			for _, copy in copies do
				within(copy, scoped.Size)
				local frame, size = Geometry.getBounds(copy)
				minimum, maximum = math.min(minimum, frame.Y - size.Y / 2), math.max(maximum, frame.Y + size.Y / 2)
				copy:Destroy()
			end
			assert(math.abs(minimum + scoped.Size.Y / 2) < 0.001, `arch bases miss floor: {shape}/{count}/{minimum}`)
			assert(
				math.abs(maximum - scoped.Size.Y / 2) < 0.001,
				`arch crown misses ceiling: {shape}/{count}/{maximum}`
			)
		end
	end
end

-- Shape controls change curve length/population and reach the triangle/rectangle limits.
scoped = parameters("Arch")
scoped.Attributes.Layout_PopulationLimit = NumberRange.new(0, 1000)
local counts: { number } = {}
for _, shape in { 0, 0.5, 1 } do
	scoped.Attributes.Layout_ArchShape = shape
	local cells = Layouts.Arch.GetCells(scoped, Vector3.one, random(1))
	table.insert(counts, #cells)
	if shape == 1 then
		close(cells[1].Frame.UpVector, Vector3.yAxis, "rectangular arch must have vertical legs")
		assert(math.abs(cells[math.ceil(#cells / 2)].Frame.UpVector.Y) < 0.001, "rectangular arch must have flat roof")
	end
end
assert(counts[1] < counts[2] and counts[2] < counts[3], "natural population must follow Bezier arc length")

-- Zero height layers produce no geometry and are specific to the volume grid.
scoped = parameters("Grid")
scoped.Attributes.Layout_LayerLimit = NumberRange.new(0)
assert(#generate(scoped) == 0)

-- A regular polygon keeps equal side lengths and closed joins on rectangular areas.
for _, sides in { 3, 4, 5, 8, 17 } do
	scoped = parameters("NGon")
	scoped.Size = Vector3.new(60, 17, 13)
	scoped.Attributes.Source_ScaleMethod = "Stretch"
	scoped.Attributes.Layout_Sides = sides
	copies = generate(scoped)
	assert(#copies == sides)
	close(copies[1].CFrame.RightVector, Vector3.xAxis, "front polygon face must be parallel to front plane")
	assert(
		math.abs(copies[1].CFrame.Z - copies[1].Size.Z / 2 + scoped.Size.Z / 2) < 0.001,
		"polygon front face is not flush"
	)
	for index, copy in copies do
		within(copy, scoped.Size)
		assert(math.abs(copy.Size.X - copies[1].Size.X) < 0.001, "unequal polygon sides")
		local nextCopy = copies[index % sides + 1]
		close(
			copy.CFrame.Position + copy.CFrame.RightVector * copy.Size.X / 2,
			nextCopy.CFrame.Position - nextCopy.CFrame.RightVector * nextCopy.Size.X / 2,
			"polygon join"
		)
	end
	for _, copy in copies do
		copy:Destroy()
	end
end

for _, kind in { "Stack", "Arch", "Random" } do
	scoped = parameters(kind)
	scoped.Attributes.Layout_PopulationLimit = NumberRange.new(0)
	assert(#generate(scoped) == 0, "zero population")
end
for _, case in
	{
		{ Kind = "Arch", Name = "Layout_ArchShape", Values = { -0.1, 1.1, math.huge, 0 / 0 } },
		{ Kind = "Grid", Name = "Layout_LayerLimit", Values = { NumberRange.new(-1), NumberRange.new(0.1, 0.9), 3 } },
		{ Kind = "Random", Name = "Layout_AvoidOverlap", Values = { 1, "true" } },
		{ Kind = "Random", Name = "Layout_PlacementAttempts", Values = { 0, -1, 1.5, math.huge } },
		{ Kind = "NGon", Name = "Layout_Sides", Values = { 0, 2, 3.5, math.huge } },
		{ Kind = "Stack", Name = "Layout_BasePadding", Values = { UDim.new(0.5), UDim.new(0, -1), 2 } },
		{ Kind = "Arch", Name = "Layout_TopPadding", Values = { UDim.new(0 / 0), UDim.new(-1), "invalid" } },
	}
do
	for _, invalid in case.Values do
		scoped = parameters(case.Kind)
		scoped.Attributes[case.Name] = invalid
		assert(not pcall(function()
			generate(scoped)
		end), `accepted invalid {case.Name}`)
	end
end
template:Destroy()
print(
	"Verified X/Y/Z axes, per-cell volume fitting, seeded overlapping layers, taper padding, floor/ceiling arch fitting, triangle-to-rectangle shapes, front-flush regular polygons, and validation."
)
