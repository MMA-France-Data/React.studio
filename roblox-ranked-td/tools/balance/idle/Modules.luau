-- Les vrais modules du jeu (copiés depuis src/shared par run.ps1 dans gen/shared).
-- Aucune valeur n'est recopiée à la main : si tu changes un réglage dans src/shared,
-- relance run.ps1 et le simulateur l'utilise tout de suite.
return {
	IdleConfig = require("./gen/shared/IdleConfig"),
	IdleTowers = require("./gen/shared/IdleTowers"),
	PlotLayout = require("./gen/shared/PlotLayout"),
	Enemies = require("./gen/shared/Enemies"),
	NumberFormat = require("./gen/shared/NumberFormat"),
}
