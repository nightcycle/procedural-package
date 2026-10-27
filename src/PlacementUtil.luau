--!strict
local ENV = require(script.Parent.ENV)
local Types = require(script.Parent.Types)
local SourceUtil = require(script.Parent.SourceUtil)
local SurfaceUtil = require(script.Parent.SurfaceUtil)
local GeometryUtil = require(script.Parent.GeometryUtil)
local DebugUtil = require(script.Parent.DebugUtil)
local Util = {}

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
	for index, copy in copies do
		local scoped = copy.Parameters
		local attributes = scoped.Attributes
		if index % attributes.Layout_PauseInterval == 0 then
			scoped:Pause()
		end
		local cell = cells[index]
		local rotation = cell.Frame.Rotation
			* CFrame.Angles(
				math.rad(random:NextNumber(attributes.Random_Roll.Min, attributes.Random_Roll.Max)),
				math.rad(random:NextNumber(attributes.Random_Pan.Min, attributes.Random_Pan.Max)),
				math.rad(random:NextNumber(attributes.Random_Tilt.Min, attributes.Random_Tilt.Max))
			)
		local range = attributes.Random_Scale
		local scale = if range.Min == range.Max then range.Min else random:NextNumber(range.Min, range.Max)
		local instance = SourceUtil.prepareForLayout(copy.Template, scoped, scale)
		instance:PivotTo(rotation)
		local center = cell.Frame.Position
		if cell.Offset then
			local _, boundsSize = GeometryUtil.getBounds(instance)
			local available = (cell.Size - boundsSize):Max(Vector3.zero)
			center += cell.Offset * available
		end
		if attributes.Source_Alignment == "Floor" then
			center = Vector3.new(center.X, -parameters.Size.Y / 2, center.Z)
		end
		local initialOrigin = CFrame.new(center) * instance:GetPivot().Rotation
		local origin = if attributes.Layout_Type == "Single"
			then initialOrigin
			else SurfaceUtil.detect(
				instance,
				initialOrigin,
				attributes,
				cell.Frame.Position,
				cell.Size,
				parameters.Size,
				model
			)
		if not origin then
			instance:Destroy()
			continue
		end
		local offset = copy.Template:GetAttribute("PivotOffset")
		if typeof(offset) == "CFrame" then
			origin *= offset
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
