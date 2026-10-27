--!strict
-- Modules
local ENV = require(script.Parent.ENV)
-- Types
local Types = require(script.Parent.Types)
type Parameters = Types.Parameters
type Template = Types.Template
-- Constants
-- Private Functions

-- Class
local Util = {}
function Util.scaleInstance(instance: Template, scale: number)
	instance:SetAttribute("Scale", scale)
	if instance:IsA("BasePart") then
		instance.Size *= scale
		local offset = instance.PivotOffset
		instance.PivotOffset = CFrame.new(offset.Position * scale) * offset.Rotation
	else
		instance:ScaleTo(math.max(ENV.DEFAULT_MIN_MODEL_SCALE, instance:GetScale() * scale))
	end
end
function Util.axisAlignedSize(frame: CFrame, size: Vector3): Vector3
	local right, up, look = frame.RightVector, frame.UpVector, frame.LookVector
	return Vector3.new(
		math.abs(right.X) * size.X + math.abs(up.X) * size.Y + math.abs(look.X) * size.Z,
		math.abs(right.Y) * size.X + math.abs(up.Y) * size.Y + math.abs(look.Y) * size.Z,
		math.abs(right.Z) * size.X + math.abs(up.Z) * size.Y + math.abs(look.Z) * size.Z
	)
end

-- Keep a horizontal footprint inside the area without changing its scale or height.
-- If a footprint exceeds an axis, center it there as no translation can make it fit.
function Util.clampSurfaceCenter(center: Vector3, size: Vector3, areaSize: Vector3): Vector3
	local available = (areaSize - size):Max(Vector3.zero) / 2
	return Vector3.new(
		math.clamp(center.X, -available.X, available.X),
		center.Y,
		math.clamp(center.Z, -available.Z, available.Z)
	)
end

function Util.getExtents(instance: Template): (CFrame, Vector3)
	if instance:IsA("BasePart") then
		return instance.CFrame, instance.Size
	else
		return instance:GetBoundingBox()
	end
end
function Util.getGeneratedPivot(instance: Template, method: Types.PivotMethod): CFrame
	local primaryMethod: Types.PivotMethod? = if method == "PrimaryPartPivot"
		then "Pivot"
		elseif method == "PrimaryPartCenter" then "Center"
		elseif method == "PrimaryPartBottom" then "Bottom"
		elseif method == "PrimaryPartTop" then "Top"
		else nil
	if primaryMethod then
		if instance:IsA("Model") then
			instance = instance.PrimaryPart or instance
		end
		method = primaryMethod
	end
	if method == "Pivot" then
		return instance:GetPivot()
	end
	local frame, size = Util.getExtents(instance)
	if method == "Bottom" then
		return frame * CFrame.new(0, -size.Y / 2, 0)
	elseif method == "Top" then
		return frame * CFrame.new(0, size.Y / 2, 0)
	end
	return frame
end
function Util.setPivot(instance: Template, frame: CFrame): ()
	if instance:IsA("BasePart") then
		instance.PivotOffset = instance.CFrame:ToObjectSpace(frame)
	else
		local primaryPart = instance.PrimaryPart
		if primaryPart then
			primaryPart.PivotOffset = primaryPart.CFrame:ToObjectSpace(frame)
		else
			instance.WorldPivot = frame
		end
	end
end
function Util.getBounds(instance: Template): (CFrame, Vector3)
	local frame, size = Util.getExtents(instance)
	return frame, Util.axisAlignedSize(frame, size)
end

return Util
