--!strict
local ENV = require(script.Parent.Parent.ENV)
local Schema = require(script.Parent.Parent.ParameterSchema)
local GeometryUtil = require(script.Parent.Parent.GeometryUtil)
local Types = require(script.Parent.Parent.Types)
local Util = require(script.Parent.Util)

-- Rational quadratic halves: zero corner weight gives a triangle;
-- increasing the weight approaches vertical legs and a flat roof.
local function getPath(parameters: Types.Parameters): { Vector3 }
	local shape = parameters.Attributes.Layout_ArchShape
	local start, corner, crown = Vector3.new(-0.5, 0, 0), Vector3.new(-0.5, 1, 0), Vector3.yAxis
	if shape == 0 then
		return { start, crown, Vector3.new(0.5, 0, 0) }
	elseif shape == 1 then
		return { start, corner, crown, Vector3.new(0.5, 1, 0), Vector3.new(0.5, 0, 0) }
	end
	local function point(t: number): Vector3
		local a, b, c = (1 - shape) * (1 - t) ^ 2, 2 * shape * (1 - t) * t, (1 - shape) * t ^ 2
		return (start * a + corner * b + crown * c) / (a + b + c)
	end
	local path = { start }
	local function subdivide(t0: number, p0: Vector3, t1: number, p1: Vector3, depth: number)
		local t = (t0 + t1) / 2
		local middle = point(t)
		local a, b, c = p0 * parameters.Size, middle * parameters.Size, p1 * parameters.Size
		if depth < 16 and (b - a).Magnitude + (c - b).Magnitude - (c - a).Magnitude > 0.00001 then
			subdivide(t0, p0, t, middle, depth + 1)
			subdivide(t, middle, t1, p1, depth + 1)
		else
			table.insert(path, p1)
			Util.pause(parameters, #path)
		end
	end
	subdivide(0, start, 1, crown, 0)
	for index = #path - 1, 1, -1 do
		local p = path[index]
		table.insert(path, Vector3.new(-p.X, p.Y, 0))
		Util.pause(parameters, #path)
	end
	return path
end

local function measure(path: { Vector3 }, width: number, height: number): ({ Vector3 }, { number }, number)
	local points: { Vector3 } = {}
	local distances = { 0 }
	local length = 0
	for index, point in path do
		points[index] = point * Vector3.new(width, height, 1)
		if index > 1 then
			length += (points[index] - points[index - 1]).Magnitude
			distances[index] = length
		end
	end
	return points, distances, length
end

local Layout: Types.Layout = {
	Parameters = {
		Layout_PopulationLimit = Util.Population,
		Layout_BasePadding = Util.BasePadding,
		Layout_TopPadding = Util.TopPadding,
		Layout_ArchShape = Schema.field(function()
			return ENV.DEFAULT_LAYOUT_ARCH_SHAPE
		end, function(value)
			return Schema.finite(value) and (value :: number) >= 0 and (value :: number) <= 1
		end),
	},
	GetCells = function(parameters: Types.Parameters, sourceSize: Vector3, _random: Random): { Types.Cell }
		local size = parameters.Size
		local path = getPath(parameters)
		local _, _, length = measure(path, size.X, size.Y)
		local count = Util.clampDimension(length / sourceSize.Y, parameters.Attributes.Layout_PopulationLimit)
		if count == 0 then
			return {}
		elseif count == 1 then
			-- A single segment cannot form an opening; fill the generation box.
			local fit = Util.insetXZ(size, Util.taperPadding(parameters, 1))
			return { { Frame = CFrame.identity, Size = fit, FitSize = fit } }
		end
		local thickness = math.min(sourceSize.X, size.X / 4, size.Y / 2)
		local width, height = size.X, size.Y
		local cells: { Types.Cell } = {}
		local center = Vector3.zero
		-- Solve the inner path from rotated outer bounds independently on X and Y.
		for iteration = 1, 40 do
			local points, distances, arcLength = measure(path, width, height)
			local segment = 2
			local function at(distance: number): Vector3
				while segment < #points and distances[segment] < distance do
					segment += 1
				end
				local from, to = distances[segment - 1], distances[segment]
				return points[segment - 1]:Lerp(points[segment], math.clamp((distance - from) / (to - from), 0, 1))
			end
			cells = {}
			local minimum, maximum = Vector3.one * math.huge, -Vector3.one * math.huge
			local start = at(0)
			for index = 1, count do
				local finish = at(arcLength * index / count)
				local up = (finish - start).Unit
				local right = Vector3.new(up.Y, -up.X, 0)
				local frame = CFrame.fromMatrix((start + finish) / 2, right, up, Vector3.zAxis)
				local alpha = 1 - math.abs((index - 1) / (count - 1) * 2 - 1)
				local fit = Util.insetXZ(
					Vector3.new(thickness, (finish - start).Magnitude, size.Z),
					Util.taperPadding(parameters, alpha)
				)
				local bounds = GeometryUtil.axisAlignedSize(frame, fit)
				minimum, maximum = minimum:Min(frame.Position - bounds / 2), maximum:Max(frame.Position + bounds / 2)
				table.insert(cells, { Frame = frame, Size = fit, FitSize = fit })
				start = finish
				Util.pause(parameters, index)
			end
			center = (minimum + maximum) / 2
			local error = size - (maximum - minimum)
			if math.abs(error.X) < 0.00001 and math.abs(error.Y) < 0.00001 then
				break
			end
			width = math.max(width + error.X, size.X * 0.0001)
			height = math.max(height + error.Y, size.Y * 0.0001)
			Util.pause(parameters, iteration)
		end
		for index, cell in cells do
			cell.Frame -= center
			Util.pause(parameters, index)
		end
		return cells
	end,
}
return Layout
