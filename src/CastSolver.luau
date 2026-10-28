--!strict
local Types = require(script.Parent.Types)

local function new(world: WorldRoot, raycastParams: RaycastParams?, overlapParams: OverlapParams?): Types.CastSolver
	local function castParams(
		model: ProceduralModel,
		target: GeneratedFolder,
		castingInternally: boolean
	): RaycastParams
		if raycastParams and not castingInternally then
			return raycastParams
		end
		local params = RaycastParams.new()
		if castingInternally then
			params.FilterType = Enum.RaycastFilterType.Include
			params.FilterDescendantsInstances = { target }
			if raycastParams then
				params.BruteForceAllSlow = raycastParams.BruteForceAllSlow
				params.CollisionGroup = raycastParams.CollisionGroup
				params.IgnoreWater = raycastParams.IgnoreWater
				params.RespectCanCollide = raycastParams.RespectCanCollide
			end
		else
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { model, target }
		end
		return params
	end
	local function boundsParams(
		model: ProceduralModel,
		target: GeneratedFolder,
		castingInternally: boolean
	): OverlapParams
		if overlapParams and not castingInternally then
			return overlapParams
		end
		local params = OverlapParams.new()
		if castingInternally then
			params.FilterType = Enum.RaycastFilterType.Include
			params.FilterDescendantsInstances = { target }
			if overlapParams then
				params.BruteForceAllSlow = overlapParams.BruteForceAllSlow
				params.CollisionGroup = overlapParams.CollisionGroup
				params.MaxParts = overlapParams.MaxParts
				params.RespectCanCollide = overlapParams.RespectCanCollide
				params.Tolerance = overlapParams.Tolerance
			end
		else
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { model, target }
		end
		return params
	end

	local solver: Types.CastSolver = {
		raycast = function(
			model: ProceduralModel,
			_parameters: Types.Parameters,
			target: GeneratedFolder,
			castingInternally: boolean,
			origin: Vector3,
			direction: Vector3
		): RaycastResult?
			return world:Raycast(origin, direction, castParams(model, target, castingInternally))
		end,
		spherecast = function(
			model: ProceduralModel,
			_parameters: Types.Parameters,
			target: GeneratedFolder,
			castingInternally: boolean,
			origin: Vector3,
			radius: number,
			direction: Vector3
		): RaycastResult?
			return world:Spherecast(origin, radius, direction, castParams(model, target, castingInternally))
		end,
		blockcast = function(
			model: ProceduralModel,
			_parameters: Types.Parameters,
			target: GeneratedFolder,
			castingInternally: boolean,
			origin: CFrame,
			size: Vector3,
			direction: Vector3
		): RaycastResult?
			return world:Blockcast(origin, size, direction, castParams(model, target, castingInternally))
		end,
		shapecast = function(
			model: ProceduralModel,
			_parameters: Types.Parameters,
			target: GeneratedFolder,
			castingInternally: boolean,
			shape: BasePart,
			direction: Vector3,
			cf: CFrame?,
			size: Vector3?
		): RaycastResult?
			return world:Shapecast(shape, direction, castParams(model, target, castingInternally), cf, size)
		end,
		getPartBoundsInBox = function(
			model: ProceduralModel,
			_parameters: Types.Parameters,
			target: GeneratedFolder,
			castingInternally: boolean,
			cf: CFrame,
			size: Vector3
		): { BasePart }
			return world:GetPartBoundsInBox(cf, size, boundsParams(model, target, castingInternally))
		end,
		getPartBoundsInRadius = function(
			model: ProceduralModel,
			_parameters: Types.Parameters,
			target: GeneratedFolder,
			castingInternally: boolean,
			position: Vector3,
			radius: number
		): { BasePart }
			return world:GetPartBoundsInRadius(position, radius, boundsParams(model, target, castingInternally))
		end,
		getPartBoundsInPart = function(
			model: ProceduralModel,
			_parameters: Types.Parameters,
			target: GeneratedFolder,
			castingInternally: boolean,
			shape: BasePart
		): { BasePart }
			return world:GetPartsInPart(shape, boundsParams(model, target, castingInternally))
		end,
	}
	return solver
end

-- Explicit query contexts let custom solvers and stories own their filters.
local CastSolver = new(workspace)
return table.freeze({
	new = new,
	raycast = CastSolver.raycast,
	spherecast = CastSolver.spherecast,
	blockcast = CastSolver.blockcast,
	shapecast = CastSolver.shapecast,
	getPartBoundsInBox = CastSolver.getPartBoundsInBox,
	getPartBoundsInRadius = CastSolver.getPartBoundsInRadius,
	getPartBoundsInPart = CastSolver.getPartBoundsInPart,
})
