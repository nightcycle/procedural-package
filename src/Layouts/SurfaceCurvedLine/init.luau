--!strict
local ENV = require(script.Parent.Parent.ENV)
local Schema = require(script.Parent.Parent.ParameterSchema)
local Types = require(script.Parent.Parent.Types)
local Util = require(script.Parent.Util)
local GeometryUtil = require(script.Parent.Parent.GeometryUtil)

type ArcSample = { T: number, Distance: number }

local function getControlPoints(size: Vector3, curveSize0: UDim, curveSize1: UDim): (Vector3, Vector3, Vector3, Vector3)
	-- Front is local -Z; right is local +X. Only endpoint footprints are inset before placement.
	local start = Vector3.new(-size.X / 2, 0, -size.Z / 2)
	local finish = Vector3.new(size.X / 2, 0, size.Z / 2)
	local length0 = size.Z * curveSize0.Scale + curveSize0.Offset
	local length1 = size.X * curveSize1.Scale + curveSize1.Offset
	-- Enter from the front along +Z, and leave through the right along +X.
	return start, start + Vector3.zAxis * length0, finish - Vector3.xAxis * length1, finish
end

local function positionAt(start: Vector3, control0: Vector3, control1: Vector3, finish: Vector3, t: number): Vector3
	return (1 - t) ^ 3 * start + 3 * (1 - t) ^ 2 * t * control0 + 3 * (1 - t) * t ^ 2 * control1 + t ^ 3 * finish
end

local function measureArc(
	parameters: Types.Parameters,
	start: Vector3,
	control0: Vector3,
	control1: Vector3,
	finish: Vector3
): ({ ArcSample }, number)
	local samples: { ArcSample } = { { T = 0, Distance = 0 } }
	local length = 0
	local previous = start
	local tolerance = math.max(
		ENV.SMALL,
		((control0 - start).Magnitude + (control1 - control0).Magnitude + (finish - control1).Magnitude) * 0.00001
	)
	local function subdivide(a: Vector3, b: Vector3, c: Vector3, d: Vector3, t0: number, t1: number, depth: number)
		-- Also bound parameter nonlinearity, so even straight curves get uniform distance spacing.
		local error = (b - a:Lerp(d, 1 / 3)).Magnitude + (c - a:Lerp(d, 2 / 3)).Magnitude
		if error <= tolerance or depth == 12 then
			length += (d - previous).Magnitude
			previous = d
			table.insert(samples, { T = t1, Distance = length })
			Util.pause(parameters, #samples)
			return
		end
		local ab, bc, cd = (a + b) / 2, (b + c) / 2, (c + d) / 2
		local abc, bcd = (ab + bc) / 2, (bc + cd) / 2
		local middle, t = (abc + bcd) / 2, (t0 + t1) / 2
		subdivide(a, ab, abc, middle, t0, t, depth + 1)
		subdivide(middle, bcd, cd, d, t, t1, depth + 1)
	end
	subdivide(start, control0, control1, finish, 0, 1, 0)
	return samples, length
end

local function parameterAtDistance(samples: { ArcSample }, length: number, fraction: number): number
	if length == 0 then
		return 0.5
	end
	if fraction == 0 or fraction == 1 then
		return fraction
	end
	local distance = fraction * length
	local low, high = 2, #samples
	while low < high do
		local middle = math.floor((low + high) / 2)
		if samples[middle].Distance < distance then
			low = middle + 1
		else
			high = middle
		end
	end
	local before, after = samples[low - 1], samples[low]
	local span = after.Distance - before.Distance
	return if span > 0 then before.T + (after.T - before.T) * (distance - before.Distance) / span else after.T
end

local Layout: Types.Layout & { GetControlPoints: typeof(getControlPoints) } = {
	GetControlPoints = getControlPoints,
	Parameters = {
		Layout_SurfaceDetectionMethod = Util.SurfaceDetection,
		Layout_PopulationLimit = Util.Population,
		Layout_CurveSize0 = Schema.field(function()
			return ENV.DEFAULT_LAYOUT_CURVE_SIZE_0
		end, Schema.udim),
		Layout_CurveSize1 = Schema.field(function()
			return ENV.DEFAULT_LAYOUT_CURVE_SIZE_1
		end, Schema.udim),
	},
	GetCells = function(parameters: Types.Parameters, sourceSize: Vector3, _random: Random): { Types.Cell }
		local attributes = parameters.Attributes
		if math.floor(attributes.Layout_PopulationLimit.Max) == 0 then
			return {}
		end
		local size = parameters.Size
		local cellSize = Vector3.new(sourceSize.X, size.Y, sourceSize.Z)
		local start, control0, control1, finish =
			getControlPoints(size, attributes.Layout_CurveSize0, attributes.Layout_CurveSize1)
		local samples, length = measureArc(parameters, start, control0, control1, finish)
		-- Local X follows the curve tangent; use its post-scaling, padded extent.
		local padding = attributes.Source_Padding
		local footprint = sourceSize.X / (1 - padding.Scale * 2) + padding.Offset * 2
		local paddedSize =
			Vector3.new(footprint, sourceSize.Y, sourceSize.Z / (1 - padding.Scale * 2) + padding.Offset * 2)
		local count = Util.clampDimension(length / footprint, attributes.Layout_PopulationLimit)
		local cells: { Types.Cell } = {}
		for index = 1, count do
			local t = parameterAtDistance(samples, length, if count == 1 then 0.5 else (index - 1) / (count - 1))
			local position = positionAt(start, control0, control1, finish, t)
			local tangent = 3 * (1 - t) ^ 2 * (control0 - start)
				+ 6 * (1 - t) * t * (control1 - control0)
				+ 3 * t ^ 2 * (finish - control1)
			-- Zero-length handles still face along the diagonal at the endpoints.
			local horizontal = if tangent.Magnitude > ENV.SMALL then tangent else finish - start
			local rotation = if horizontal.Magnitude > ENV.SMALL
				then CFrame.Angles(0, -math.atan2(horizontal.Z, horizontal.X), 0)
				else CFrame.identity
			local isEndpoint = count > 1 and (index == 1 or index == count)
			local center = if isEndpoint
				then GeometryUtil.clampSurfaceCenter(position, GeometryUtil.axisAlignedSize(rotation, paddedSize), size)
				else position
			table.insert(cells, { Frame = CFrame.new(center) * rotation, Size = cellSize })
			Util.pause(parameters, index)
		end
		return cells
	end,
}
return Layout
