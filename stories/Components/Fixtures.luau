--!strict
local Types = require(game:GetService("ReplicatedStorage").Packages.ProceduralPackage.Types)
local Fixtures = {}
Fixtures.Blue = Color3.fromRGB(80, 166, 255)
Fixtures.Gold = Color3.fromRGB(255, 193, 72)
Fixtures.Green = Color3.fromRGB(75, 219, 156)
Fixtures.Red = Color3.fromRGB(255, 102, 120)

function Fixtures.part(name: string, size: Vector3, frame: CFrame, color: Color3, parent: Instance?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = frame
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

function Fixtures.template(asModel: boolean, primary: boolean?): Types.Template
	if not asModel then
		local part = Fixtures.part("AsymmetricPart", Vector3.new(5, 8, 3), CFrame.identity, Fixtures.Blue, nil)
		part.PivotOffset = CFrame.new(1, -2, 0) * CFrame.Angles(0, math.rad(20), 0)
		return part
	end
	local model = Instance.new("Model")
	model.Name = "AsymmetricModel"
	local stem = Fixtures.part("Stem", Vector3.new(2, 8, 2), CFrame.new(-1, 0, 0), Fixtures.Blue, model)
	Fixtures.part("Arm", Vector3.new(7, 2, 3), CFrame.new(1.5, 3, 0), Fixtures.Green, model)
	stem.PivotOffset = CFrame.new(0, -4, 0) * CFrame.Angles(0, math.rad(20), 0)
	if primary then
		model.PrimaryPart = stem
	else
		model.WorldPivot = CFrame.new(-2, -4, 0)
	end
	return model
end

function Fixtures.tint(template: Types.Template, color: Color3, transparency: number?)
	local function apply(part: BasePart)
		part.Color = color
		part.Transparency = transparency or 0
	end
	if template:IsA("BasePart") then
		apply(template)
	end
	for _, child in template:GetDescendants() do
		if child:IsA("BasePart") then
			apply(child)
		end
	end
end

return Fixtures
