# procedural-package

Using ProceduralModels to get flexible source referencing.

## demo gallery

Open the place built from `demo.project.json` to explore 140 live examples under `Workspace.examples.Gallery`, alongside the four original examples. The eight labeled sections cover all source collections, Grid/Line/Random placement, Floor/Center alignment, all eight pivot methods, source Model scales of 0.25/1/3 with and without PrimaryParts, every scale method/reference combination, seeds and random ranges, padding, excluded tags/subtrees, custom path delimiters, source overrides, and `Generator.append` callbacks.

Select a numbered ProceduralModel to edit its attributes. Gold markers in the pivot section show the common origin. New examples have their native Generator references assigned and are marked dirty so Studio generates their contents. The gallery uses cloned comparison sources under `ReplicatedStorage.lib.DemoSources`; original sources and original examples are preserved. `demo/gallery.json` lists every example, its settings, source, description, and position.

Rebuild the gallery from the repository root with `lune run scripts/build-demo.luau`, then build the place with `rojo build demo.project.json --output demo.rbxl`. The Lune builder replaces only its own gallery and source fixtures, validates the serialized data before writing, and leaves original content in place.

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

In order to connect to a template you must use the "SourcePath" attribute, or whatever attribute you like as they're all configurable at `ProceduralPackage.ENV` as well as through the `_G` variable with a `__PROCEDURALPACKAGE__` prefix. When a source is a folder it will randomly select a valid (any BasePart or Model) descendant. If you'd like to restrict an attribute, most can also be embedded into the source as an override. A Vector3 "Size" attribute overrides dimensions used for uniform fitting; for Models these dimensions are specified at model scale 1.

## setting pivots

`GeneratedPivotMethod` chooses the origin used to rotate, scale, and place each generated copy. It can also be overridden on a source Model or BasePart.

| Value | Origin |
| --- | --- |
| `"Pivot"` (default) | The Model or BasePart's native pivot. |
| `"Center"` | The Model's bounding box center, or the BasePart's CFrame. |
| `"Bottom"` | The extents center minus half its height along its local Y axis. |
| `"Top"` | The extents center plus half its height along its local Y axis. |
| `"PrimaryPartPivot"` | The assigned PrimaryPart's native pivot; falls back to `"Pivot"`. |
| `"PrimaryPartCenter"` | The assigned PrimaryPart's CFrame; falls back to `"Center"`. |
| `"PrimaryPartBottom"` | The assigned PrimaryPart's center minus half its height along its local Y axis; falls back to `"Bottom"`. |
| `"PrimaryPartTop"` | The assigned PrimaryPart's center plus half its height along its local Y axis; falls back to `"Top"`. |

The PrimaryPart variants fall back to the corresponding default behavior for Models without a PrimaryPart and for BaseParts. They still scale and place the entire generated copy.

`GeneratedAlignment = "Center"` places that origin at the cell center; `"Floor"` places it on the generation box floor. Use `"Bottom"` with `"Floor"` to place upright copies on the floor without editing source pivots. Scaling is relative to the source's current dimensions and Model scale, including `RandomScale`.

A CFrame `"PivotOffset"` **attribute** on the source is applied last as `solvedOrigin * PivotOffset`. Its translation is in studs and is not rescaled. This is separate from a BasePart's native `PivotOffset` property, which is respected by `"Pivot"` and rescaled with the geometry.

## surface detection

`GeneratedSurfaceDetectionMethod` accepts `"None"` (default), `"Raycast"`, or `"Shapecast"`, and can be overridden on a source Model or BasePart. `None` keeps the usual placement. `Raycast` places the selected pivot at the hit position; use a bottom pivot for upright objects. `Shapecast` sweeps the scaled, rotated geometry, checking every BasePart in a Model and stopping the entire copy at its first contact. Misses discard the copy without calling the append callback or adding it to the generated output.

Casts follow the ProceduralModel's local downward axis. `GeneratedAlignment = "Floor"` searches from the generation box ceiling to its floor; `"Center"` searches from the assigned cell's ceiling to its floor. The source's `PivotOffset` attribute is applied after surface placement.

Pass the owning ProceduralModel to `Generator.new(model)`, or as the third argument to `Generator.append(attributes, callback, model)`, so world queries account for its position, rotation, and scale. For a Generator ModuleScript directly inside the model:

```luau
--!strict
local Package = require(game.ReplicatedStorage.Packages.ProceduralPackage)
local model = script.Parent
assert(model:IsA("ProceduralModel"))
return Package.Generator.new(model)
```

Both detection modes use `Package.ENV.RAYCAST_PARAMS`, which defaults to `RaycastParams.new()`. Configure it centrally to select the supporting geometry, for example:

```luau
local params = RaycastParams.new()
params.IncludeInstances = { workspace.Map }
params.IgnoreWater = true
Package.ENV.RAYCAST_PARAMS = params
```

Keep the generated model out of the query filters so regeneration cannot detect its previous output as a supporting surface. ProceduralModels do not automatically regenerate when surrounding surfaces move; regenerate them after changing the supporting geometry.

To keep using `"Pivot"` with native pivots set at the base, you can use this script to mass set them:

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
