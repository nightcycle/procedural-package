--!strict
-- Modules
local ENV = require(script.Parent.ENV)
-- Types
local Types = require(script.Parent.Types)
type Parameters = Types.Parameters
type Template = Types.Template
type TemplateGroup = Types.TemplateGroup
type ExtraAttributes = Types.ExtraAttributes
-- Constants
-- Private Functions
-- Class
local Util = {}

Util.print = function(...)
	if ENV.IS_DEBUG_MODE then
		print(...)
	end
end
return Util
