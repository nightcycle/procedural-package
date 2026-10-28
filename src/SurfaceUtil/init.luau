--!strict
local ENV = require(script.Parent.ENV)
local GeometryUtil = require(script.Parent.GeometryUtil)
local Types = require(script.Parent.Types)
local CastSolver = require(script.Parent.CastSolver)
local IndexUtil = require(script.Parent.Parent.IndexUtil)
local requireSolver: (ModuleScript) -> unknown = require

local Util = {}

function Util.getSolver(parameters: Types.Parameters): Types.CastSolver
	local attributes = parameters.Attributes
	local path = attributes.Solver_Cast_Path
	if path == "" then
		return CastSolver
	end
	local module = IndexUtil.waitForPath(path, attributes.Source_MaxYield, attributes.Source_PathDelimiter)
	assert(module, `failed to find cast solver at path: {path}`)
	assert(module:IsA("ModuleScript"), `Solver_Cast_Path must reference a ModuleScript: {path}`)
	local solver = requireSolver(module)
	assert(typeof(solver) == "table", `cast solver at {path} must return a table`)
	for _, name in
		{
			"raycast",
			"spherecast",
			"blockcast",
			"shapecast",
			"getPartBoundsInBox",
			"getPartBoundsInRadius",
			"getPartBoundsInPart",
		}
	do
		assert(typeof((solver :: { [string]: unknown })[name]) == "function", `cast solver at {path} is missing {name}`)
	end
	-- ModuleScript exports are validated at this boundary.
	return solver :: Types.CastSolver
end

-- Output remains in generation space; only the queries use world coordinates.
function Util.detect(
	instance: Types.Template,
	origin: CFrame,
	parameters: Types.Parameters,
	cellCenter: Vector3,
	cellSize: Vector3,
	target: GeneratedFolder,
	model: ProceduralModel?,
	castSolver: Types.CastSolver?
): CFrame?
	local attributes = parameters.Attributes
	local method = attributes.Layout_SurfaceDetectionMethod
	if method == "None" then
		return origin
	end
	assert(model, "Surface detection requires the ProceduralModel passed to Generator.new or Generator.append")
	local frame, scale = model:GetPivot(), model:GetScale()
	local solver = castSolver or Util.getSolver(parameters)
	local fullSize = parameters.Size
	local height = if attributes.Source_Alignment == "Floor" then fullSize.Y else cellSize.Y
	local top = if attributes.Source_Alignment == "Floor" then fullSize.Y / 2 else cellCenter.Y + cellSize.Y / 2
	local direction = frame:VectorToWorldSpace(Vector3.new(0, -(height + ENV.SMALL * 2) * scale, 0))
	if method == "Raycast" then
		local start = Vector3.new(origin.X, top + ENV.SMALL, origin.Z)
		local result =
			solver.raycast(model, parameters, target, false, frame:PointToWorldSpace(start * scale), direction)
		if not result then
			return nil
		end
		local position = frame:PointToObjectSpace(result.Position) / scale
		return CFrame.new(position) * origin.Rotation
	end
	assert(method == "Shapecast", `unknown surface detection method: {method}`)
	instance:PivotTo(origin)
	local boundsFrame, boundsSize = GeometryUtil.getBounds(instance)
	-- Begin with the entire shape above the cell to avoid starting inside its support.
	local lift = Vector3.new(0, top + ENV.SMALL - (boundsFrame.Y - boundsSize.Y / 2), 0)
	local distance: number? = nil
	local function cast(part: BasePart)
		local localFrame = part.CFrame + lift
		local worldFrame = frame * (CFrame.new(localFrame.Position * scale) * localFrame.Rotation)
		local result =
			solver.shapecast(model, parameters, target, false, part, direction, worldFrame, part.Size * scale)
		if result and (distance == nil or result.Distance < distance) then
			distance = result.Distance
		end
	end
	if instance:IsA("BasePart") then
		cast(instance)
	end
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("BasePart") then
			cast(descendant)
		end
	end
	if distance == nil then
		return nil
	end
	return origin + lift - Vector3.new(0, distance / scale, 0)
end

return Util
