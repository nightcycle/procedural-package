--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
return {
	name = "Procedural Package · Visual Debug",
	storyRoots = { ReplicatedStorage.Packages.ProceduralPackage, script.Parent.Attributes },
	groupRoots = true,
}
