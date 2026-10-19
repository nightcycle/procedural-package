# procedural-package

Using ProceduralModels to get flexible source referencing.

## usage

Within the ProceduralModel set the ModuleScript to this:
```luau
return require(game.ReplicatedStorage.Packages.LocalPackage).Generator.new()
```

You can also append to it. I recommend storing the edited version in some central location then having the modules require a constructor from there, instead of littering bespoke ModuleScripts throughout the workspace.
```luau
return function()
	return require(game.ReplicatedStorage.Packages.LocalPackage).Generator.append({
		Color = Color3.new(1,0,0)
	}, function(generatedInstance: Model | BasePart, parameters: GenerationFunctionParams<DefaultAttributes & { Color: Color3 }>, targetContainer: GeneratedFolder)
		if generatedInstance:IsA("BasePart") then
			generatedInstance.Color = parameters.Attributes.Color
		end
	end)
end
```

## source configuration

In order to connect to a template you must use the "SourcePath" attribute, or whatever attribute you like as they're all configurable at `LocalPackage.ENV` as well as through the `_G` variable with a `__LOCALPACKAGE__` prefix. When a source is a folder it will randomly select a valid (any BasePart or Model) descendant. If you'd like to restrict an attribute, most can also be embedded into the source as an ovveride. It also supports a "Size" attribute and "PivotOffset" attribute for overriding the inputs regarding the placement math.
