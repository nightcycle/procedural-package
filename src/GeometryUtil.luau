--!strict
-- Modules
local ENV = require(script.Parent.ENV)
-- Types
local Types = require(script.Parent.Types)
type Parameters = Types.Parameters
type Template = Types.Template
type TemplateGroup = Types.TemplateGroup
type ExtraAttributes = Types.ExtraAttributes
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
function Util.getBounds(instance: Template): (Vector3, Vector3)
	local frame: CFrame
	local size: Vector3
	if instance:IsA("BasePart") then
		frame, size = instance.CFrame, instance.Size
	else
		frame, size = instance:GetBoundingBox()
	end
	return frame.Position, Util.axisAlignedSize(frame, size)
end

return Util
