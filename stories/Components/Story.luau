--!strict
local UILabs = require(game:GetService("ReplicatedStorage").DevPackages.UILabs)
local Controls = require(script.Parent.Controls)
local Viewport = require(script.Parent.Viewport)
local Story = {}

function Story.create(
	name: string,
	summary: string,
	controls: { [string]: unknown },
	build: (Viewport.Scene, Controls.Values) -> ()
): UILabs.GenericStory
	return UILabs.CreateGenericStory(
		{ name = name, summary = summary, controls = controls },
		function(props: UILabs.GenericProps)
			local scene = Viewport.new(props.target, name, summary)
			local alive = true
			local function update(values: Controls.Values)
				if not alive then
					return
				end
				scene.Clear()
				local ok, problem = xpcall(function()
					build(scene, values)
				end, debug.traceback)
				if not ok then
					scene.SetStatus(`ERROR: {problem}`)
				end
				scene.Status.TextColor3 = if ok then Color3.fromRGB(220, 231, 247) else Color3.fromRGB(255, 102, 120)
				scene.Fit()
			end
			update(props.controls)
			local unsubscribe = props.subscribe(function(values)
				update(values)
			end)
			return function()
				alive = false
				unsubscribe()
				scene.Destroy()
			end
		end
	)
end

return Story
