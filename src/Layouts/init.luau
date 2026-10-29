--!strict
local Types = require(script.Parent.Types)
local Layouts: { [Types.LayoutType]: Types.Layout } = {
	Single = require(script.Single),
	SurfaceGrid = require(script.SurfaceGrid),
	SurfaceRandom = require(script.SurfaceRandom),
	SurfaceCurvedLine = require(script.SurfaceCurvedLine),
	Stack = require(script.Stack),
	Arch = require(script.Arch),
	NGon = require(script.NGon),
	Grid = require(script.Grid),
	Random = require(script.Random),
}
return Layouts
