# procedural-package

Using ProceduralModels to get flexible source referencing.

## usage

Within the ProceduralModel set the ModuleScript to this:
```luau
return require(game.ReplicatedStorage.Packages.ProceduralPackage).Generator.new()
```

You can also append to it. I recommend storing the edited version in some central location then having the modules require a constructor from there, instead of littering bespoke ModuleScripts throughout the workspace.
```luau
return function()
	return require(game.ReplicatedStorage.Packages.ProceduralPackage).Generator.append({
		Color = Color3.new(1,0,0)
	}, function(generatedInstance: Model | BasePart, parameters: GenerationFunctionParams<DefaultAttributes & { Color: Color3 }>, targetContainer: GeneratedFolder)
		if generatedInstance:IsA("BasePart") then
			generatedInstance.Color = parameters.Attributes.Color
		end
	end)
end
```

## source configuration

In order to connect to a template you must use the "SourcePath" attribute, or whatever attribute you like as they're all configurable at `ProceduralPackage.ENV` as well as through the `_G` variable with a `__PROCEDURALPACKAGE__` prefix. When a source is a folder it will randomly select a valid (any BasePart or Model) descendant. If you'd like to restrict an attribute, most can also be embedded into the source as an ovveride. It also supports a "Size" attribute and "PivotOffset" attribute for overriding the inputs regarding the placement math.

## setting pivots

This package assumes the pivots are set at the base, feel free to use this script to mass set them:

```luau
for i, v in game.Workspace.lib.vegetation.tree.partial:GetChildren() do
	if v:IsA("Model") then
		v.WorldPivot = CFrame.fromMatrix(v.WorldPivot.Position*Vector3.new(1,0,1), v.WorldPivot.XVector, v.WorldPivot.YVector, v.WorldPivot.ZVector)
	elseif v:IsA("BasePart") then
		local worldCF = v.CFrame * v.PivotOffset
		local goalCF = CFrame.fromMatrix(worldCF.Position*Vector3.new(1,0,1), worldCF.XVector, worldCF.YVector, worldCF.ZVector)
		local offset = goalCF:ToObjectSpace(worldCF)
		v.PivotOffset = v.PivotOffset * offset:Inverse()
	end
end
```