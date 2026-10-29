--!strict
local ENV = require(script.Parent.ENV)
local Geometry = require(script.Parent.GeometryUtil)
local Types = require(script.Parent.Types)

local Placement = {}

function Placement.solve(
	instance: Types.Template,
	parameters: Types.Parameters,
	region: Vector3,
	firstSample: Vector3,
	random: Random,
	target: GeneratedFolder,
	model: ProceduralModel?,
	solver: Types.CastSolver?
): CFrame?
	local attributes = parameters.Attributes
	local pivotOffset = instance:GetAttribute("PivotOffset")
	local baseRotation = instance:GetPivot().Rotation
	if typeof(pivotOffset) == "CFrame" then
		instance:PivotTo(instance:GetPivot() * pivotOffset.Rotation)
	end
	-- Fit the final orientation uniformly, preserving proportions and random scale unless it cannot fit.
	local _, bounds = Geometry.getBounds(instance)
	local fit = math.min(1, region.X / bounds.X, region.Y / bounds.Y, region.Z / bounds.Z)
	if fit < 1 then
		local previousScale = instance:GetAttribute("Scale")
		Geometry.scaleInstance(instance, fit)
		instance:SetAttribute("Scale", (if typeof(previousScale) == "number" then previousScale else 1) * fit)
	end
	if typeof(pivotOffset) == "CFrame" then
		-- Attribute translations remain in studs, independently of the uniform fitting multiplier.
		instance:PivotTo(instance:GetPivot() + baseRotation:VectorToWorldSpace(pivotOffset.Position))
	end
	local frame, size = Geometry.getBounds(instance)
	if size.X > region.X + ENV.SMALL or size.Y > region.Y + ENV.SMALL or size.Z > region.Z + ENV.SMALL then
		-- Engine minimum part/model scales can make a very small volume impossible to fit.
		return nil
	end
	local available = (region - size):Max(Vector3.zero)
	local centered = instance:GetPivot() - frame.Position
	if not attributes.Layout_AvoidOverlap then
		return centered + firstSample * available
	end
	assert(
		model and solver,
		"Random overlap checks require the ProceduralModel passed to Generator.new or Generator.append"
	)
	local worldFrame, worldScale = model:GetPivot(), model:GetScale()
	local parts: { BasePart } = {}
	if instance:IsA("BasePart") then
		table.insert(parts, instance)
	end
	for _, child in instance:GetDescendants() do
		if child:IsA("BasePart") then
			table.insert(parts, child)
		end
	end
	local sample = firstSample
	for attempt = 1, attributes.Layout_PlacementAttempts do
		if attempt % attributes.Layout_PauseInterval == 0 then
			parameters:Pause()
		end
		local origin = centered + sample * available
		instance:PivotTo(origin)
		local blocked = false
		for index, part in parts do
			if index % attributes.Layout_PauseInterval == 0 then
				parameters:Pause()
			end
			local cf = worldFrame * (CFrame.new(part.CFrame.Position * worldScale) * part.CFrame.Rotation)
			-- Query each part instead of the model's enclosing box, preserving holes and concavities.
			if #solver.getPartBoundsInBox(model, parameters, target, true, cf, part.Size * worldScale) > 0 then
				blocked = true
				break
			end
		end
		if not blocked then
			return origin
		end
		if attempt < attributes.Layout_PlacementAttempts then
			sample =
				Vector3.new(random:NextNumber(-0.5, 0.5), random:NextNumber(-0.5, 0.5), random:NextNumber(-0.5, 0.5))
		end
	end
	return nil
end

return Placement
