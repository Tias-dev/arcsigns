local arcsigns = require("arcsigns")
if _G.ArcSignsLoaded then
	return arcsigns
end
_G.ArcSignsLoaded = true
arcsigns.setup({})
return arcsigns
