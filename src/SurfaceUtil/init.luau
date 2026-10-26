--!strict
local ENV = require(script.Parent.ENV)
local GeometryUtil = require(script.Parent.GeometryUtil)
local Types = require(script.Parent.Types)

local Util = {}

-- Output remains in generation space; only the queries use world coordinates.
-- Optional query context supports isolated WorldModels without mutating ENV.
function Util.detect(
	instance: Types.Template,
	origin: CFrame,
	attributes: Types.PackageAttributes,
	cellCenter: Vector3,
	cellSize: Vector3,
	fullSize: Vector3,
	model: ProceduralModel?,
	queryRoot: WorldRoot?,
	queryParams: RaycastParams?
): CFrame?
	local method = attributes.Layout_SurfaceDetectionMethod
	if method == "None" then
		return origin
	end
	assert(model, "Surface detection requires the ProceduralModel passed to Generator.new or Generator.append")
	local frame, scale = model:GetPivot(), model:GetScale()
	local world = queryRoot or workspace
	local params = queryParams or ENV.RAYCAST_PARAMS
	local height = if attributes.Source_Alignment == "Floor" then fullSize.Y else cellSize.Y
	local top = if attributes.Source_Alignment == "Floor" then fullSize.Y / 2 else cellCenter.Y + cellSize.Y / 2
	local direction = frame:VectorToWorldSpace(Vector3.new(0, -(height + ENV.SMALL * 2) * scale, 0))
	if method == "Raycast" then
		local start = Vector3.new(origin.X, top + ENV.SMALL, origin.Z)
		local result = world:Raycast(frame:PointToWorldSpace(start * scale), direction, params)
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
		local result = world:Shapecast(part, direction, params, worldFrame, part.Size * scale)
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
