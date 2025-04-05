-- Environment
for _, Service in pairs({
	"CoreGui",
	"TweenService",
	"Players",
	"ContentProvider",
	"RunService",
}) do
	wax.shared[Service] = cloneref(game:GetService(Service))
end

-- UI
wax.shared.Interface = require("Utils/Interface")
wax.shared.Icons = require("Utils/Icons")
wax.shared.Sonner = require("Utils/Sonner")

-- Variables
wax.shared.LocalPlayer = wax.shared.Players.LocalPlayer

-- Functions
wax.shared.gethui = gethui or function()
	return wax.shared.CoreGui
end

-- Load UI
require("Window")
