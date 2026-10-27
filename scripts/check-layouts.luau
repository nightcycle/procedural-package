--!strict
-- Production-module smoke checks in Lune. World queries and the engine RNG are adapters.
local roblox = require("@lune/roblox")
local makeLoader = require("./lib/load-package")
type RInstance = roblox.Instance & { [string]: any }
type Datatypes = {
	CFrame: typeof(CFrame),
	Vector3: typeof(Vector3),
	NumberRange: typeof(NumberRange),
	Color3: typeof(Color3),
	UDim: typeof(UDim),
}
local datatypes = (roblox :: any) :: Datatypes
local CFrame, Vector3 = datatypes.CFrame, datatypes.Vector3
local NumberRange, Color3, UDim = datatypes.NumberRange, datatypes.Color3, datatypes.UDim

roblox.implementMethod("BasePart", "GetPivot", function(part: RInstance): CFrame
	return part.CFrame * part.PivotOffset
end)
roblox.implementMethod("BasePart", "PivotTo", function(part: RInstance, frame: CFrame)
	part.CFrame = frame * part.PivotOffset:Inverse()
end)

local function random(seed: number)
	local state = seed % 2147483647
	local function nextUnit(): number
		state = (state * 16807 + 1) % 2147483647
		return state / 2147483647
	end
	return {
		NextNumber = function(_self: unknown, minimum: number, maximum: number): number
			return minimum + nextUnit() * (maximum - minimum)
		end,
		NextInteger = function(_self: unknown, minimum: number, maximum: number): number
			return minimum + math.floor(nextUnit() * (maximum - minimum + 1))
		end,
		Shuffle = function<T>(_self: unknown, array: { T })
			for index = #array, 2, -1 do
				local other = 1 + math.floor(nextUnit() * index)
				array[index], array[other] = array[other], array[index]
			end
		end,
	}
end

local source = roblox.Instance.new("Folder") :: RInstance
local template = roblox.Instance.new("Part") :: RInstance
template.Name = "Template"
template.Size = Vector3.new(4, 6, 4)
template.Parent = source
local queryHit = true
local world = {
	HasTag = function(_self: unknown, _tag: string): boolean
		return false
	end,
	Raycast = function(_self: unknown, start: Vector3, direction: Vector3, _params: unknown)
		return if queryHit then { Position = start + direction / 2 } else nil
	end,
	Shapecast = function(
		_self: unknown,
		_part: unknown,
		direction: Vector3,
		_params: unknown,
		_frame: CFrame,
		_size: Vector3
	)
		return if queryHit then { Distance = direction.Magnitude / 2 } else nil
	end,
}
local load = makeLoader({ Random = { new = random }, workspace = world }, {
	IndexUtil = {
		waitForPath = function(_path: string, _timeout: number, _delimiter: string)
			return source
		end,
	},
})
local Generator = load("src/Generator")
local ParameterUtil = load("src/ParameterUtil")
local SourceUtil = load("src/SourceUtil")
local GeometryUtil = load("src/GeometryUtil")
local Layouts = load("src/Layouts")
local pauses, callbacks = 0, 0
local definition = Generator.append(
	{ Tint = Color3.new(1, 0, 0) },
	function(instance: RInstance, parameters: any, _target: unknown)
		callbacks += 1
		instance.Color = parameters.Attributes.Tint
	end
)
local attributes = table.clone(definition.Attributes)
attributes.Source_Path = "fixture"
attributes.Source_PivotMethod = "Bottom"
attributes.Source_ScaleMethod = "Fit"
attributes.Source_Padding = UDim.new(0)
attributes.Layout_PauseInterval = 1
attributes.Layout_ColumnLimit = NumberRange.new(4)
attributes.Layout_RowLimit = NumberRange.new(3)
attributes.Layout_PopulationLimit = NumberRange.new(12)
attributes.Layout_CurveSize0 = UDim.new(0, 20)
attributes.Layout_CurveSize1 = UDim.new(0, 20)
local parameters = {
	Attributes = attributes,
	Size = Vector3.new(80, 24, 60),
	Pause = function(_self: unknown)
		pauses += 1
	end,
}
local function generate(): { RInstance }
	local target = roblox.Instance.new("Folder")
	definition.OnGenerate(parameters, target)
	return target:GetChildren() :: { RInstance }
end
local function expectFailure(fn: () -> (), message: string)
	local ok, problem = pcall(fn)
	assert(
		not ok and tostring(problem):find(message, 1, true),
		`expected error containing {message}, received {problem}`
	)
end

-- Natural grid footprints survive count limits and resizing; only the spacing changes.
local function gridCells(size: Vector3, footprint: Vector3, columns: NumberRange, rows: NumberRange, padding: UDim?)
	local scoped = table.clone(parameters)
	scoped.Size = size
	scoped.Attributes = table.clone(attributes)
	scoped.Attributes.Layout_ColumnLimit = columns
	scoped.Attributes.Layout_RowLimit = rows
	scoped.Attributes.Source_Padding = padding or UDim.new(0)
	return Layouts.SurfaceGrid.GetCells(scoped, footprint, random(1))
end
local area = Vector3.new(23, 12, 17)
local footprint = Vector3.new(4, 6, 5)
local unrestricted = NumberRange.new(1, 100)
local natural = gridCells(area, footprint, unrestricted, unrestricted)
assert(#natural == 15, "grid should fit five columns and three rows at the source footprint")
assert((natural[1].Frame.Position - Vector3.new(-9.2, 0, -17 / 3)).Magnitude < 0.001)
assert((natural[15].Frame.Position - Vector3.new(9.2, 0, 17 / 3)).Magnitude < 0.001)
assert(math.abs(natural[2].Frame.X - natural[1].Frame.X - 4.6) < 0.001, "remainder should become gaps")
local sparse = gridCells(area, footprint, NumberRange.new(1, 2), NumberRange.new(1, 2))
assert(#sparse == 4 and sparse[2].Frame.X - sparse[1].Frame.X > footprint.X, "count cap should add gaps")
local crowded = gridCells(area, footprint, NumberRange.new(8, 10), NumberRange.new(5, 8))
assert(#crowded == 40 and crowded[2].Frame.X - crowded[1].Frame.X < footprint.X, "minimum count should overlap")
assert(crowded[9].Frame.Z - crowded[1].Frame.Z < footprint.Z, "rows should overlap independently")
for _, group in { natural, sparse, crowded } do
	for _, cell in group do
		assert(cell.Size == Vector3.new(4, 12, 5), "grid count limits must not resize cells")
	end
end
assert(#gridCells(Vector3.new(31, 12, 22), footprint, unrestricted, unrestricted) == 28, "resize must re-solve counts")
assert(#gridCells(area, Vector3.new(8, 6, 5), unrestricted, unrestricted) == 6, "source resize must re-solve counts")
local oversized = gridCells(Vector3.new(2, 12, 2), footprint, NumberRange.new(3), NumberRange.new(2))
assert(#oversized == 6)
assert((oversized[1].Frame.Position - Vector3.new(-2 / 3, 0, -0.5)).Magnitude < 0.001)
assert((oversized[6].Frame.Position - Vector3.new(2 / 3, 0, 0.5)).Magnitude < 0.001)
for _, cell in oversized do
	assert(cell.Size == Vector3.new(4, 12, 5), "oversized footprints should overlap without resizing")
end
local padded = gridCells(area, footprint, unrestricted, unrestricted, UDim.new(0.1, 2))
assert(#padded == 2 and padded[1].Size == Vector3.new(9, 12, 10.25), "padding should reserve only X/Z footprint space")
local centered = gridCells(area, footprint, NumberRange.new(1), NumberRange.new(1))
assert(centered[1].Frame.Position == Vector3.zero and centered[1].Size == Vector3.new(4, 12, 5))

-- Equal shares of a five-stud dimension reproduce the requested spacing on either axis.
for _, case in
	{
		{ Limit = NumberRange.new(0, 3), Count = 3, Step = 5 / 3 },
		{ Limit = NumberRange.new(10), Count = 10, Step = 0.5 },
		{ Limit = NumberRange.new(1, 10), Count = 5, Step = 1 },
		{ Limit = NumberRange.new(1.1, 3.9), Count = 3, Step = 5 / 3 },
	}
do
	for _, alongX in { true, false } do
		local cells = gridCells(
			Vector3.new(5, 12, 5),
			Vector3.one,
			if alongX then case.Limit else NumberRange.new(1),
			if alongX then NumberRange.new(1) else case.Limit
		)
		assert(#cells == case.Count, "count should clamp the natural fit to the dimension limit")
		for index, cell in cells do
			local coordinate = if alongX then cell.Frame.X else cell.Frame.Z
			assert(math.abs(coordinate - (-2.5 + (index - 0.5) * case.Step)) < 0.001)
			assert(cell.Size == Vector3.new(1, 12, 1), "spacing must not change fitting dimensions")
		end
	end
end
for _, alongX in { true, false } do
	local empty = gridCells(
		area,
		footprint,
		if alongX then NumberRange.new(0) else unrestricted,
		if alongX then unrestricted else NumberRange.new(0)
	)
	assert(#empty == 0, "a zero dimension must produce an empty grid")
end
assert(
	#gridCells(Vector3.new(2, 12, 2), footprint, NumberRange.new(0, 3), NumberRange.new(0, 3)) == 0,
	"an oversized footprint should produce no cells when the minimum allows zero"
)

-- Padding insets target axes before fitting, including Stretch and Height references.
local surfaceAxes = Vector3.new(1, 0, 1)
local function fit(method: string, reference: string, size: Vector3, padding: UDim, axes: Vector3?)
	return SourceUtil.prepareClone(template, size, CFrame.identity, method, reference, 1, padding, "Center", axes)
end
local surfaceHeight = fit("Fill", "Height", Vector3.new(20, 12, 20), UDim.new(0.2, 1), surfaceAxes)
assert((surfaceHeight.Size - Vector3.new(8, 12, 8)).Magnitude < 0.001, "surface padding must not reduce Height fitting")
local singleHeight = fit("Fill", "Height", Vector3.new(20, 12, 20), UDim.new(0.2, 1), nil)
assert((singleHeight.Size - Vector3.new(4, 6, 4)).Magnitude < 0.001, "Single should pad its height as well")
local stretched = fit("Stretch", "Min", Vector3.new(20, 2, 16), UDim.new(0.1, 3), surfaceAxes)
assert((stretched.Size - Vector3.new(11.2, 2, 8)).Magnitude < 0.001, "Stretch should pad X/Z without exhausting height")
local fitted = fit("Fit", "Min", padded[1].Size, UDim.new(0.1, 2), surfaceAxes)
assert(
	(fitted.Size - template.Size).Magnitude < 0.001,
	"reserved grid padding must not shrink an already-fitting source"
)
for _, kind in { "Single", "SurfaceGrid", "SurfaceRandom", "SurfaceCurvedLine" } do
	local scoped = table.clone(parameters)
	scoped.Attributes = table.clone(attributes)
	scoped.Attributes.Layout_Type = kind
	scoped.Attributes.Source_ScaleMethod = "Fill"
	scoped.Attributes.Source_ScaleReference = "Height"
	scoped.Attributes.Source_Padding = UDim.new(0.1, 1)
	local target = roblox.Instance.new("Folder")
	definition.OnGenerate(scoped, target)
	local copy = target:GetChildren()[1] :: RInstance
	local expectedHeight = if kind == "Single" then 17.6 else 24
	assert(math.abs(copy.Size.Y - expectedHeight) < 0.001, `wrong padding axes in {kind} placement`)
	target:Destroy()
end

-- Every layout fits to the full area before its count, spacing, or curve rotation.
local originalSize = template.Size
template.Size = Vector3.one
for _, case in
	{
		{ Method = "Fill", Reference = "Height", Size = Vector3.new(2, 2, 2), GridCount = 4 },
		{ Method = "Fit", Reference = "Min", Size = Vector3.one, GridCount = 25 },
		{ Method = "Stretch", Reference = "Min", Size = Vector3.new(5, 2, 5), GridCount = 1 },
		{ Method = "Fill", Reference = "Max", Size = Vector3.new(5, 5, 5), GridCount = 1 },
	}
do
	for _, kind in { "Single", "SurfaceGrid", "SurfaceRandom", "SurfaceCurvedLine" } do
		local scoped = table.clone(parameters)
		scoped.Size = Vector3.new(5, 2, 5)
		scoped.Attributes = table.clone(attributes)
		scoped.Attributes.Layout_Type = kind
		scoped.Attributes.Source_ScaleMethod = case.Method
		scoped.Attributes.Source_ScaleReference = case.Reference
		scoped.Attributes.Layout_ColumnLimit = NumberRange.new(0, 100)
		scoped.Attributes.Layout_RowLimit = NumberRange.new(0, 100)
		local measured = SourceUtil.getLayoutSize({ template }, scoped, { Tint = Color3.new(1, 0, 0) })
		assert((measured - case.Size).Magnitude < 0.001, `wrong scaled bounds for {kind}/{case.Method}`)
		for _, population in { 3, 20 } do
			scoped.Attributes.Layout_PopulationLimit = NumberRange.new(population)
			local target = roblox.Instance.new("Folder")
			definition.OnGenerate(scoped, target)
			local expectedCount = if kind == "Single"
				then 1
				elseif kind == "SurfaceGrid" then case.GridCount
				else population
			assert(#target:GetChildren() == expectedCount, `layout did not use scaled bounds in {kind}/{case.Method}`)
			for _, copy in target:GetChildren() :: { RInstance } do
				assert(
					(copy.Size - case.Size).Magnitude < 0.001,
					`count changed source scaling in {kind}/{case.Method}`
				)
			end
			target:Destroy()
		end
	end
end

local scaledParameters = table.clone(parameters)
scaledParameters.Size = Vector3.new(5, 2, 5)
scaledParameters.Attributes = table.clone(attributes)
scaledParameters.Attributes.Layout_Type = "SurfaceGrid"
scaledParameters.Attributes.Layout_ColumnLimit = NumberRange.new(0, 100)
scaledParameters.Attributes.Layout_RowLimit = NumberRange.new(0, 100)
scaledParameters.Attributes.Source_ScaleMethod = "Fill"
scaledParameters.Attributes.Source_ScaleReference = "Height"
scaledParameters.Attributes.Random_Scale = NumberRange.new(1, 2)
assert(SourceUtil.getLayoutSize({ template }, scaledParameters) == Vector3.new(4, 4, 4))
local randomScaled = roblox.Instance.new("Folder")
definition.OnGenerate(scaledParameters, randomScaled)
assert(#randomScaled:GetChildren() == 1, "grid should reserve the maximum random scale")
local randomCopy = randomScaled:GetChildren()[1] :: RInstance
assert(randomCopy.Size.X >= 2 and randomCopy.Size.X <= 4, "placement should apply random scale once")
randomScaled:Destroy()

-- Forced grid counts change spacing without changing the already-fitted dimensions.
scaledParameters.Attributes.Random_Scale = NumberRange.new(1)
for _, count in { 3, 10 } do
	scaledParameters.Attributes.Layout_ColumnLimit = NumberRange.new(count)
	scaledParameters.Attributes.Layout_RowLimit = NumberRange.new(1)
	local target = roblox.Instance.new("Folder")
	definition.OnGenerate(scaledParameters, target)
	assert(#target:GetChildren() == count)
	for _, copy in target:GetChildren() :: { RInstance } do
		assert(copy.Size == Vector3.new(2, 2, 2), "grid limits must not refit scaled sources")
	end
	target:Destroy()
end
scaledParameters.Attributes.Layout_ColumnLimit = NumberRange.new(0, 100)
scaledParameters.Attributes.Layout_RowLimit = NumberRange.new(0, 100)

-- Raw size and fitting Size attributes are not the resulting geometry bounds.
scaledParameters.Attributes.Random_Scale = NumberRange.new(1)
template:SetAttribute("Size", Vector3.new(2, 2, 2))
assert(SourceUtil.getLayoutSize({ template }, scaledParameters) == Vector3.one)
template:SetAttribute("Size", nil)
local largerResult = roblox.Instance.new("Part") :: RInstance
largerResult.Name = "SmallSourceLargeResult"
largerResult.Size = Vector3.one / 2
largerResult:SetAttribute("Source_ScaleMethod", "Fill")
largerResult:SetAttribute("Source_ScaleReference", "Height")
largerResult:SetAttribute("Random_Scale", NumberRange.new(2))
largerResult.Parent = source
scaledParameters.Attributes.Source_ScaleMethod = "Fit"
assert(
	SourceUtil.getLayoutSize({ template, largerResult }, scaledParameters) == Vector3.new(4, 4, 4),
	"mixed sources must use the largest post-scaling bounds including source overrides"
)
local mixed = roblox.Instance.new("Folder")
definition.OnGenerate(scaledParameters, mixed)
assert(#mixed:GetChildren() == 1, "mixed-source grid should count post-scaling bounds")
mixed:Destroy()
largerResult:Destroy()
assert(template.Size == Vector3.one, "bounds measurement must not modify the source")

-- Random offsets use the actual scaled, rotated bounds; curve tangents never refit them.
template.Size = Vector3.new(1, 1, 2)
scaledParameters.Size = Vector3.new(10, 2, 10)
scaledParameters.Attributes.Source_ScaleMethod = "Fill"
scaledParameters.Attributes.Source_ScaleReference = "Height"
scaledParameters.Attributes.Layout_PopulationLimit = NumberRange.new(4)
scaledParameters.Attributes.Random_Pan = NumberRange.new(90)
for _, kind in { "SurfaceRandom", "SurfaceCurvedLine" } do
	scaledParameters.Attributes.Layout_Type = kind
	local target = roblox.Instance.new("Folder")
	definition.OnGenerate(scaledParameters, target)
	for _, copy in target:GetChildren() :: { RInstance } do
		assert(copy.Size == Vector3.new(2, 2, 4), "layout rotation must follow fitting")
		if kind == "SurfaceRandom" then
			local frame, boundsSize = GeometryUtil.getBounds(copy)
			assert(math.abs(frame.X) + boundsSize.X / 2 <= 5.001, "random X offset ignored final bounds")
			assert(math.abs(frame.Z) + boundsSize.Z / 2 <= 5.001, "random Z offset ignored final bounds")
		end
	end
	target:Destroy()
end
template.Size = originalSize

-- Swap every layout on the same definition and preserve its callback/custom defaults.
template:SetAttribute("Tint", Color3.new(0, 1, 0))
for _, kind in { "Single", "SurfaceGrid", "SurfaceRandom", "SurfaceCurvedLine" } do
	attributes.Layout_Type = kind
	local before = callbacks
	local first = generate()
	assert(#first == (if kind == "Single" then 1 else 12), `wrong count for {kind}`)
	assert(callbacks - before == #first)
	local second = generate()
	for index, copy in first do
		assert(copy.Color == Color3.new(0, 1, 0), "callback did not receive source-scoped attributes")
		assert(copy.CFrame == second[index].CFrame, `non-deterministic {kind}`)
		assert(math.abs(copy:GetPivot().Y + parameters.Size.Y / 2) < 0.001, "Floor alignment lost")
	end
end
assert(pauses > 0, "generation did not pause cooperatively")
assert(attributes.Tint == Color3.new(1, 0, 0), "template overrides leaked into area attributes")

-- Direct and nested folder sources share overrides while excluding entire tagged subtrees.
assert(SourceUtil.getTemplates(template, parameters)[1] == template)
local hidden = roblox.Instance.new("Folder")
hidden.Name = "Hidden"
hidden:AddTag("Skip")
hidden.Parent = source
local hiddenPart = template:Clone()
hiddenPart.Parent = hidden
attributes.Source_ExcludedTags = "  Skip, , Other  "
local eligible = SourceUtil.getTemplates(source, parameters)
assert(#eligible == 1 and eligible[1] == template, "tagged source subtree was included")
hidden:Destroy()
attributes.Source_ExcludedTags = ""

-- A seed change alters random placement without changing its population.
attributes.Layout_Type = "SurfaceRandom"
local seeded = generate()
attributes.Random_Seed = 2026
local changed = generate()
assert(#seeded == #changed and seeded[1].CFrame ~= changed[1].CFrame)
attributes.Random_Seed = 0

-- Every surface layout uses Center alignment as one layer, not a 3D grid.
attributes.Source_Alignment = "Center"
attributes.Layout_Type = "SurfaceGrid"
for _, copy in generate() do
	assert(math.abs(copy:GetPivot().Y) < 0.001)
end
attributes.Source_Alignment = "Floor"

-- Cubic curve endpoints and midpoint, including Beam's signed handle behavior.
attributes.Layout_Type = "SurfaceCurvedLine"
attributes.Layout_PopulationLimit = NumberRange.new(3)
local cells = Layouts.SurfaceCurvedLine.GetCells(parameters, template.Size, random(1))
local frontLeft = Vector3.new(-parameters.Size.X / 2, 0, -parameters.Size.Z / 2)
local backRight = -frontLeft
assert((cells[1].Frame.Position - frontLeft).Magnitude < 0.001, "curve must start at the front-left corner")
assert((cells[3].Frame.Position - backRight).Magnitude < 0.001, "curve must finish at the back-right corner")
assert((cells[1].Frame.RightVector - Vector3.zAxis).Magnitude < 0.001, "curve must enter through the front")
assert((cells[3].Frame.RightVector - Vector3.xAxis).Magnitude < 0.001, "curve must leave through the right")
assert(
	(cells[2].Frame.Position - Vector3.new(-7.5, 0, 7.5)).Magnitude < 0.001,
	"cubic midpoint must use the signed perpendicular handles"
)
attributes.Layout_CurveSize0, attributes.Layout_CurveSize1 = UDim.new(0, -20), UDim.new(0, -20)
cells = Layouts.SurfaceCurvedLine.GetCells(parameters, template.Size, random(1))
assert(
	(cells[2].Frame.Position - Vector3.new(7.5, 0, -7.5)).Magnitude < 0.001,
	"negative handles should reverse the bend"
)
attributes.Layout_CurveSize0, attributes.Layout_CurveSize1 = UDim.new(0, 0), UDim.new(0, 0)
cells = Layouts.SurfaceCurvedLine.GetCells(parameters, template.Size, random(1))
local diagonal = (backRight - frontLeft).Unit
assert(cells[2].Frame.Position.Magnitude < 0.001, "zero handles must form a straight diagonal")
assert((cells[1].Frame.RightVector - diagonal).Magnitude < 0.001)
assert((cells[3].Frame.RightVector - diagonal).Magnitude < 0.001)
for _, dimensions in { Vector3.new(120, 24, 10), Vector3.new(10, 24, 120) } do
	local previousSize = parameters.Size
	parameters.Size = dimensions
	for _, count in { 2, 5 } do
		attributes.Layout_PopulationLimit = NumberRange.new(count)
		cells = Layouts.SurfaceCurvedLine.GetCells(parameters, template.Size, random(1))
		local corner = Vector3.new(-dimensions.X / 2, 0, -dimensions.Z / 2)
		assert((cells[1].Frame.Position - corner).Magnitude < 0.001)
		assert(
			(cells[count].Frame.Position + corner).Magnitude < 0.001,
			"resizing and population changes must preserve exact corner endpoints"
		)
	end
	parameters.Size = previousSize
end
for _, count in { 0, 1 } do
	attributes.Layout_PopulationLimit = NumberRange.new(count)
	assert(#generate() == count)
end
-- Mixed scale/offset handles follow their own area axes on rectangular areas.
attributes.Layout_CurveSize0 = UDim.new(0.5, 5)
attributes.Layout_CurveSize1 = UDim.new(-0.25, 10)
attributes.Layout_PopulationLimit = NumberRange.new(3)
local curveAreaSize = parameters.Size
for _, dimensions in { Vector3.new(80, 24, 60), Vector3.new(120, 24, 20) } do
	parameters.Size = dimensions
	cells = Layouts.SurfaceCurvedLine.GetCells(parameters, template.Size, random(1))
	local expected = if dimensions.X == 80 then Vector3.new(3.75, 0, 13.125) else Vector3.new(7.5, 0, 5.625)
	assert((cells[2].Frame.Position - expected).Magnitude < 0.001, "UDim handles must follow depth / width")
	assert((cells[1].Frame.RightVector - Vector3.zAxis).Magnitude < 0.001)
	assert((cells[3].Frame.RightVector + Vector3.xAxis).Magnitude < 0.001)
	assert(#generate() == 3, "signed UDim handles must pass generation validation")
end
parameters.Size = curveAreaSize
for _, name in { "Layout_CurveSize0", "Layout_CurveSize1" } do
	local valid = attributes[name]
	for _, invalid in { 12, "0.5, 12", UDim.new(0 / 0, 0), UDim.new(math.huge, 0) } do
		attributes[name] = invalid
		expectFailure(function()
			generate()
		end, name)
	end
	attributes[name] = valid
end
attributes.Layout_Type = "SurfaceRandom"
for _, count in { 0, 1 } do
	attributes.Layout_PopulationLimit = NumberRange.new(count)
	assert(#generate() == count)
end

-- Inactive layout values are ignored until their layout is selected.
attributes.Layout_Type = "Single"
attributes.Layout_PopulationLimit = NumberRange.new(-2)
assert(#generate() == 1)
attributes.Layout_Type = "SurfaceRandom"
expectFailure(function()
	generate()
end, "Layout_PopulationLimit")
attributes.Layout_PopulationLimit = NumberRange.new(12)
attributes.Layout_Type = "invalid"
expectFailure(function()
	generate()
end, "Layout_Type")
attributes.Layout_Type = "Single"
attributes.Layout_PauseInterval = 0
expectFailure(function()
	generate()
end, "Layout_PauseInterval")
attributes.Layout_PauseInterval = 1
template:SetAttribute("Random_Scale", NumberRange.new(0))
expectFailure(function()
	generate()
end, "Random_Scale")
template:SetAttribute("Random_Scale", nil)
template:SetAttribute("Tint", 3)
expectFailure(function()
	generate()
end, "Tint")
template:SetAttribute("Tint", nil)
expectFailure(function()
	Generator.append({ Layout_Type = "Single" }, function() end)
end, "reserved")

-- Source-side layout attributes never alter the area's selected layout/count.
template:SetAttribute("Layout_Type", "Single")
attributes.Layout_Type = "SurfaceGrid"
assert(#generate() == 12)
attributes.Layout_ColumnLimit = NumberRange.new(2, 4)
attributes.Layout_RowLimit = NumberRange.new(2, 3)
assert(#generate() == 12, "natural grid dimensions were not clamped")

-- Both surface modes discard misses before invoking callbacks and still pause.
local owner = {
	GetAttribute = function(_self: unknown, _name: string)
		return nil
	end,
	AttributeChanged = {
		Connect = function()
			return { Disconnect = function() end }
		end,
	},
	Destroying = {
		Connect = function()
			return { Disconnect = function() end }
		end,
	},
	GetPivot = function(_self: unknown)
		return CFrame.new(10, 0, 0)
	end,
	GetScale = function(_self: unknown)
		return 2
	end,
}
local surfaceGenerator = Generator.append(
	{ Tint = Color3.new(1, 0, 0) },
	function(_instance: unknown, _parameters: unknown, _target: unknown)
		callbacks += 1
	end,
	owner
)
for _, mode in { "Raycast", "Shapecast" } do
	attributes.Layout_SurfaceDetectionMethod = mode
	queryHit = false
	local before = callbacks
	local target = roblox.Instance.new("Folder")
	surfaceGenerator.OnGenerate(parameters, target)
	assert(#target:GetChildren() == 0, `misses survived {mode}`)
	assert(callbacks == before, `misses invoked callbacks for {mode}`)
	queryHit = true
	surfaceGenerator.OnGenerate(parameters, target)
	assert(#target:GetChildren() == 12, `hits were dropped by {mode}`)
end
ParameterUtil.validate(parameters)
print(
	"Verified all four layouts, post-scaling bounds, count-independent fitting, random scale and mixed-source bounds, fixed grid footprints, resizing, gaps/overlap, X/Z surface padding, swaps, deterministic transforms, Beam handles, callbacks, overrides, validation, zero/one populations, cooperative pauses, and surface hit/miss paths."
)
