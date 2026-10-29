--!strict
local ENV = require(script.Parent.ENV)
local Types = require(script.Parent.Types)
local SourceUtil = require(script.Parent.SourceUtil)
local SurfaceUtil = require(script.Parent.SurfaceUtil)
local GeometryUtil = require(script.Parent.GeometryUtil)
local DebugUtil = require(script.Parent.DebugUtil)
local Layouts = require(script.Parent.Layouts)
local Util = {}

local function containSurfaceOrigin(instance: Types.Template, origin: CFrame, areaSize: Vector3): CFrame
	instance:PivotTo(origin)
	local frame, size = GeometryUtil.getBounds(instance)
	return origin + GeometryUtil.clampSurfaceCenter(frame.Position, size, areaSize) - frame.Position
end

-- Layouts own cell positions; this shared pipeline owns source transforms and output.
function Util.run(
	parameters: Types.Parameters,
	copies: { Types.TemplateGroup },
	cells: { Types.Cell },
	random: Random,
	target: GeneratedFolder,
	callback: Types.CallbackFn<Types.PackageAttributes & Types.ExtraAttributes>?,
	model: ProceduralModel?
)
	local areaAttributes = parameters.Attributes
	local surface = Layouts[areaAttributes.Layout_Type].Surface == true
	local solver = if #copies > 0
			and surface
			and areaAttributes.Layout_SurfaceDetectionMethod ~= "None"
		then SurfaceUtil.getSolver(parameters)
		else nil
	for index, copy in copies do
		local scoped = copy.Parameters
		local attributes = scoped.Attributes
		if index % attributes.Layout_PauseInterval == 0 then
			scoped:Pause()
		end
		local cell = cells[index]
		local isCurveEndpoint = attributes.Layout_Type == "SurfaceCurvedLine"
			and #cells > 1
			and (index == 1 or index == #cells)
		local rotation = cell.Frame.Rotation
			* CFrame.Angles(
				math.rad(random:NextNumber(attributes.Random_Roll.Min, attributes.Random_Roll.Max)),
				math.rad(random:NextNumber(attributes.Random_Pan.Min, attributes.Random_Pan.Max)),
				math.rad(random:NextNumber(attributes.Random_Tilt.Min, attributes.Random_Tilt.Max))
			)
		local range = attributes.Random_Scale
		local scale = if range.Min == range.Max then range.Min else random:NextNumber(range.Min, range.Max)
		local instance = SourceUtil.prepareForLayout(copy.Template, scoped, scale, cell.FitSize)
		instance:PivotTo(rotation * instance:GetPivot().Rotation)
		local center = cell.Frame.Position
		if cell.Offset then
			local _, boundsSize = GeometryUtil.getBounds(instance)
			local available = (cell.Size - boundsSize):Max(Vector3.zero)
			center += cell.Offset * available
		end
		if attributes.Source_Alignment == "Floor" and (surface or attributes.Layout_Type == "Single") then
			center = Vector3.new(center.X, -parameters.Size.Y / 2, center.Z)
		end
		if not surface and attributes.Layout_Type ~= "Single" then
			-- Volume and solid-shape cells position geometry centers, independent of source pivots.
			local frame, size = GeometryUtil.getBounds(instance)
			if Layouts[attributes.Layout_Type].Volume then
				local available = (parameters.Size - size):Max(Vector3.zero) / 2
				center = center:Max(-available):Min(available)
			end
			center -= frame.Position - instance:GetPivot().Position
		end
		local initialOrigin = CFrame.new(center) * instance:GetPivot().Rotation
		if isCurveEndpoint then
			initialOrigin = containSurfaceOrigin(instance, initialOrigin, parameters.Size)
		end
		local origin = if surface
			then SurfaceUtil.detect(
				instance,
				initialOrigin,
				scoped,
				cell.Frame.Position,
				cell.Size,
				target,
				model,
				solver
			)
			else initialOrigin
		if not origin then
			instance:Destroy()
			continue
		end
		local offset = copy.Template:GetAttribute("PivotOffset")
		if typeof(offset) == "CFrame" then
			origin *= offset
		end
		if isCurveEndpoint then
			origin = containSurfaceOrigin(instance, origin, parameters.Size)
		end
		instance:PivotTo(origin)
		if callback then
			callback(instance, scoped, target)
		end
		(instance :: Instance).Parent = target

		if ENV.DEBUG_OUTER_CELL_ENABLED then
			local part = DebugUtil.debugRegion(cell.Frame, cell.Size, Color3.new(1, 0, 0))
			part.Name = "Outer"
			part.Parent = instance
		end
		if ENV.DEBUG_TEMPLATE_BOUNDS_ENABLED then
			local _, size = GeometryUtil.getBounds(copy.Template)
			local part = DebugUtil.debugRegion(origin, size, Color3.new(0, 1, 1))
			part.Name = "Template"
			part.Parent = instance
		end
		if ENV.DEBUG_BOUNDS_ENABLED or ENV.DEBUG_INNER_CELL_ENABLED then
			local frame, size = GeometryUtil.getBounds(instance)
			local part = DebugUtil.debugRegion(frame, size, Color3.new(1, 0, 1))
			part.Name = "Inner"
			part.Parent = instance
		end
	end
end

return Util
