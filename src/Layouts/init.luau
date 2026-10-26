--!strict
local Types = require(script.Parent.Types)
local Layouts: { [Types.LayoutType]: Types.Layout } = {
	Single = require(script.Single),
	SurfaceGrid = require(script.SurfaceGrid),
	SurfaceRandom = require(script.SurfaceRandom),
	SurfaceCurvedLine = require(script.SurfaceCurvedLine),
}
return Layouts
