--!strict
local LayoutStory = require(game:GetService("ReplicatedStorage").DebugStories.Components.LayoutStory)
local Fixtures = require(game:GetService("ReplicatedStorage").DebugStories.Components.Fixtures)
local Curve = require(script.Parent)
return LayoutStory.create("SurfaceCurvedLine", Curve, function(scene, parameters)
	local start, handle0, handle1, finish = Curve.GetControlPoints(
		parameters.Size,
		parameters.Attributes.Layout_CurveSize0,
		parameters.Attributes.Layout_CurveSize1
	)
	scene.Line(start, handle0, Fixtures.Gold, 0.2)
	scene.Line(finish, handle1, Fixtures.Gold, 0.2)
	scene.Marker(CFrame.new(handle0), 1.3)
	scene.Marker(CFrame.new(handle1), 1.3)
end)
