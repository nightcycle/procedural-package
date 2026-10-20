--!strict
-- Modules
local ENV = require(script.Parent.ENV)
local SourceUtil = require(script.Parent.SourceUtil)
local GeometryUtil = require(script.Parent.GeometryUtil)
local DebugUtil = require(script.Parent.DebugUtil)
-- Types
local Types = require(script.Parent.Types)
type Parameters = Types.Parameters
type TemplateGroup = Types.TemplateGroup
type Bounds = Types.Bounds
-- Constants
-- Private Functions
-- Class
local Util = {}

function solveGrid(size: Vector3, count: number, parameters: Parameters): Vector3
	if parameters.Attributes.RandomPlacement == "Line" then
		return Vector3.new(count, 1, 1)
	end
	local x, y, z = 1, 1, 1
	local iterations = 0
	while x * y * z < count do
		local width = size.X / x
		local height = if parameters.Attributes.GeneratedAlignment == "Center" then size.Y / y else 0
		local depth = size.Z / z
		if width >= height and width >= depth then
			x += 1
		elseif height >= depth then
			y += 1
		else
			z += 1
		end
		iterations += 1
		if iterations % parameters.Attributes.PauseInterval == 0 then
			parameters:Pause()
		end
	end
	return Vector3.new(x, y, z)
end

function Util.runGrid(
	parameters: Types.Parameters,
	copies: { TemplateGroup },
	random: Random,
	targetContainer: GeneratedFolder,
	fn: Types.CallbackFn<any>?
): ()
	local attributes = parameters.Attributes
	local fullSize = parameters.Size
	local pauseInterval = parameters.Attributes.PauseInterval
	local grid = solveGrid(fullSize, #copies, parameters)
	local outerCellSize = fullSize / grid
	local paddingDimMag = math.min(outerCellSize.X, outerCellSize.Z) * parameters.Attributes.GeneratedPadding.Scale
		+ parameters.Attributes.GeneratedPadding.Offset
	local innerCellSize = (Vector3.one * ENV.SMALL):Max(outerCellSize - (Vector3.one * 2 * paddingDimMag))
	local cells: { number } = {}
	for index = 1, grid.X * grid.Y * grid.Z do
		cells[index] = index - 1
		if index % pauseInterval == 0 then
			parameters:Pause()
		end
	end
	if attributes.RandomPlacement == "Random" then
		random:Shuffle(cells)
	end
	local placed: { Bounds } = {}
	local generatedByTemplate: { [Instance]: number } = {}
	for index, copy in copies do
		local template = copy.Template
		local copyParameters = copy.Parameters
		local copyAttributes = copyParameters.Attributes
		local rotation = CFrame.Angles(
			math.rad(random:NextNumber(copyAttributes.RandomRoll.Min, copyAttributes.RandomRoll.Max)),
			math.rad(random:NextNumber(copyAttributes.RandomPan.Min, copyAttributes.RandomPan.Max)),
			math.rad(random:NextNumber(copyAttributes.RandomTilt.Min, copyAttributes.RandomTilt.Max))
		)
		local scaleRange = copyAttributes.RandomScale
		local randomScale = if scaleRange.Min == scaleRange.Max
			then scaleRange.Min
			else random:NextNumber(scaleRange.Min, scaleRange.Max)
		local instance = SourceUtil.prepareClone(
			template,
			innerCellSize,
			rotation,
			copyAttributes.GeneratedScaleMethod,
			copyAttributes.GeneratedScaleReference,
			randomScale
		)
		local boundsCenter, boundsSize = GeometryUtil.getBounds(instance)
		local cellIndex = cells[index]
		local coordinates = Vector3.new(
			cellIndex % grid.X,
			math.floor(cellIndex / (grid.X * grid.Z)),
			math.floor(cellIndex / grid.X) % grid.Z
		)
		local center = -fullSize / 2 + outerCellSize / 2 + coordinates * outerCellSize

		if attributes.RandomPlacement == "Random" then
			local available = Vector3.new(
				math.max(0, innerCellSize.X - boundsSize.X),
				math.max(0, innerCellSize.Y - boundsSize.Y),
				math.max(0, innerCellSize.Z - boundsSize.Z)
			)
			center += Vector3.new(
				random:NextNumber(-0.5, 0.5) * available.X,
				random:NextNumber(-0.5, 0.5) * available.Y,
				random:NextNumber(-0.5, 0.5) * available.Z
			)
		end
		if copyAttributes.GeneratedAlignment == "Floor" then
			local cellBottom = -fullSize.Y / 2 + coordinates.Y * outerCellSize.Y
			center = Vector3.new(center.X, cellBottom + boundsSize.Y / 2, center.Z)
		end
		table.insert(placed, { Center = center, Size = boundsSize })
		instance:PivotTo(CFrame.new(center - boundsCenter.Position) * instance:GetPivot())
		if fn then
			fn(instance, parameters, targetContainer)
		end
		(instance :: Instance).Parent = targetContainer

		local generated = (generatedByTemplate[template] or 0) + 1
		generatedByTemplate[template] = generated
		if generated % copyAttributes.PauseInterval == 0 then
			copyParameters:Pause()
		end
		do
			if ENV.DEBUG_OUTER_CELL_ENABLED then
				local part, _box = DebugUtil.debugRegion(CFrame.new(center), outerCellSize, Color3.new(1, 0, 0))
				part.Name = `Outer`
				part.Parent = instance
			end
			if ENV.DEBUG_BOUNDS_ENABLED then
				local _templateCenter, instSize = GeometryUtil.getBounds(instance)
				local part, _box = DebugUtil.debugRegion(
					if parameters.Attributes.GeneratedAlignment == "Center"
						then CFrame.new(center.X, 0, center.Z)
						else CFrame.new(center.X, boundsSize.Y / 2 - fullSize.Y / 2, center.Z),
					boundsSize,
					Color3.new(1, 0, 1)
				)
				part.Name = `Bounds`
				part.Parent = instance
			end
			if ENV.DEBUG_TEMPLATE_BOUNDS_ENABLED then
				local _templateCenter, tempateSize = GeometryUtil.getBounds(template)
				local part, _box = DebugUtil.debugRegion(
					if parameters.Attributes.GeneratedAlignment == "Center"
						then CFrame.new(center.X, 0, center.Z)
						else CFrame.new(center.X, tempateSize.Y / 2 - fullSize.Y / 2, center.Z),
					tempateSize,
					Color3.new(0, 1, 1)
				)
				part.Name = `Template`
				part.Parent = instance
			end
			if ENV.DEBUG_INNER_CELL_ENABLED then
				local part, _box = DebugUtil.debugRegion(CFrame.new(center), innerCellSize, Color3.new(0, 0, 1))
				part.Name = `Inner`
				part.Parent = instance
			end
		end
	end
end

return Util
