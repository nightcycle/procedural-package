--!strict
-- Modules
local ENV = require(script.Parent.ENV)
local SourceUtil = require(script.Parent.SourceUtil)
local GeometryUtil = require(script.Parent.GeometryUtil)
local SurfaceUtil = require(script.Parent.SurfaceUtil)
local DebugUtil = require(script.Parent.DebugUtil)
-- Types
local Types = require(script.Parent.Types)
type Parameters = Types.Parameters
type TemplateGroup = Types.TemplateGroup
type Bounds = Types.Bounds
-- Constants
-- Private Functions
function solveInstance(copy: TemplateGroup, size: Vector3, random: Random, padding: UDim)
	local template = copy.Template

	local rotation = CFrame.Angles(
		math.rad(
			(random:NextNumber(copy.Parameters.Attributes.RandomRoll.Min, copy.Parameters.Attributes.RandomRoll.Max))
		),
		(
			math.rad(
				random:NextNumber(copy.Parameters.Attributes.RandomPan.Min, copy.Parameters.Attributes.RandomPan.Max)
			)
		),
		(
			math.rad(
				random:NextNumber(copy.Parameters.Attributes.RandomTilt.Min, copy.Parameters.Attributes.RandomTilt.Max)
			)
		)
	)
	local scaleRange = copy.Parameters.Attributes.RandomScale
	local randomScale = if scaleRange.Min == scaleRange.Max
		then scaleRange.Min
		else random:NextNumber(scaleRange.Min, scaleRange.Max)
	return SourceUtil.prepareClone(
		template,
		size,
		rotation,
		copy.Parameters.Attributes.GeneratedScaleMethod,
		copy.Parameters.Attributes.GeneratedScaleReference,
		randomScale,
		padding,
		copy.Parameters.Attributes.GeneratedPivotMethod
	)
end
function getGridDimensions(size: Vector3, count: number, parameters: Parameters): Vector3
	if parameters.Attributes.RandomPlacement == "Line" then
		return Vector3.new(count, 1, 1)
	end
	local x, y, z = 1, 1, 1
	local iterations = 0
	while x * y * z < count do
		local width = size.X / x
		local height = if parameters.Attributes.GeneratedAlignment == "Center" then size.Y / y else 0
		local depth = size.Z / z
		iterations += 1

		if width >= height and width >= depth then
			x += 1
		elseif height >= depth then
			y += 1
		else
			z += 1
		end
		if iterations % parameters.Attributes.PauseInterval == 0 then
			parameters:Pause()
		end
	end
	return Vector3.new(x, y, z)
end

-- Class
local Util = {}

function Util.runGrid(
	parameters: Types.Parameters,
	copies: { TemplateGroup },
	random: Random,
	targetContainer: GeneratedFolder,
	fn: Types.CallbackFn<any>?,
	model: ProceduralModel?
): ()
	local attributes = parameters.Attributes
	local fullSize = parameters.Size
	local pauseInterval = parameters.Attributes.PauseInterval
	local grid = getGridDimensions(fullSize, #copies, parameters)
	local outerCellSize = fullSize / grid

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
	local generatedByTemplate: { [Instance]: number } = {}

	for index, copy in copies do
		-- Count attempts so an all-miss generation still yields cooperatively.
		local generated = (generatedByTemplate[copy.Template] or 0) + 1
		generatedByTemplate[copy.Template] = generated
		if generated % copy.Parameters.Attributes.PauseInterval == 0 then
			copy.Parameters:Pause()
		end
		local copyAttributes = copy.Parameters.Attributes
		local instance = solveInstance(copy, outerCellSize, random, parameters.Attributes.GeneratedPadding)
		local innerCellCenter, innerCellSize = GeometryUtil.getBounds(instance)
		local cellIndex = cells[index]
		local coordinates = Vector3.new(
			cellIndex % grid.X,
			math.floor(cellIndex / (grid.X * grid.Z)),
			math.floor(cellIndex / grid.X) % grid.Z
		)
		local outerCellCenter = -fullSize / 2 + outerCellSize / 2 + coordinates * outerCellSize
		local center = outerCellCenter
		if attributes.RandomPlacement == "Random" then
			local available = Vector3.new(
				math.max(0, outerCellSize.X - innerCellSize.X),
				math.max(0, outerCellSize.Y - innerCellSize.Y),
				math.max(0, outerCellSize.Z - innerCellSize.Z)
			)
			center += Vector3.new(
				random:NextNumber(-0.5, 0.5) * available.X,
				if copyAttributes.GeneratedAlignment ~= "Floor" then random:NextNumber(-0.5, 0.5) * available.Y else 0,
				random:NextNumber(-0.5, 0.5) * available.Z
			)
		end
		local detectionCellCenter = outerCellCenter
		if copyAttributes.GeneratedAlignment == "Floor" then
			center = Vector3.new(center.X, -fullSize.Y / 2, center.Z)
			outerCellCenter -= Vector3.new(0, outerCellSize.Y / 2, 0)
		end
		local origin = CFrame.new(center) * instance:GetPivot().Rotation
		local detectedOrigin =
			SurfaceUtil.detect(instance, origin, copyAttributes, detectionCellCenter, outerCellSize, fullSize, model)
		if not detectedOrigin then
			instance:Destroy()
			continue
		end
		origin = detectedOrigin
		local pivotOffset = copy.Template:GetAttribute("PivotOffset")
		if typeof(pivotOffset) == "CFrame" then
			origin *= pivotOffset
		end
		center = origin.Position
		instance:PivotTo(origin)
		if fn then
			fn(instance, parameters, targetContainer)
		end
		(instance :: Instance).Parent = targetContainer

		do
			if ENV.DEBUG_OUTER_CELL_ENABLED then
				local part, _box =
					DebugUtil.debugRegion(CFrame.new(outerCellCenter), outerCellSize, Color3.new(1, 0, 0))
				part.Name = `Outer`
				part.Parent = instance
			end
			if ENV.DEBUG_TEMPLATE_BOUNDS_ENABLED then
				local _templateCenter, tempateSize = GeometryUtil.getBounds(copy.Template)
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
			if ENV.DEBUG_BOUNDS_ENABLED then
				local part, _box = DebugUtil.debugRegion(
					CFrame.fromMatrix(center, innerCellCenter.XVector, innerCellCenter.YVector, innerCellCenter.ZVector),
					innerCellSize,
					Color3.new(1, 0, 1)
				)
				part.Name = `Inner`
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
