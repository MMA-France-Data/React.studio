-- Pure presentation geometry, also exercised by the headless layout tests.
local Layout = {}
local wide = {
	EggPanel = { size = { 680, 276 }, Info = { 14, 52, 318, 42 }, ReadyGrid = { 14, 102, 318, 160 }, Hatching = { 350, 52, 316, 42 }, HatchGrid = { 350, 102, 316, 160 } },
	PetPanel = { size = { 680, 276 }, Count = { 14, 48, 142, 44 }, AddPlace = { 164, 48, 204, 44 }, PetGrid = { 14, 98, 354, 110 }, Best = { 14, 218, 172, 44 }, None = { 194, 218, 174, 44 }, Sheet = { 382, 52, 284, 210 } },
	BagPanel = { size = { 680, 276 }, Info = { 14, 52, 652, 38 }, BagGrid = { 14, 98, 652, 164 } },
	SwordPanel = { size = { 680, 276 }, Current = { 14, 56, 304, 148 }, Next = { 362, 56, 304, 148 }, Arrow = { 324, 104, 32, 44 }, Buy = { 14, 218, 652, 44 } },
	ShopPanel = { size = { 680, 276 }, SwordRow = { 14, 56, 652, 96 }, PenRow = { 14, 164, 652, 96 } },
}
local portrait = {
	EggPanel = { size = { 340, 560 }, Info = { 14, 52, 312, 50 }, ReadyGrid = { 14, 110, 312, 176 }, Hatching = { 14, 300, 312, 28 }, HatchGrid = { 14, 338, 312, 208 } },
	PetPanel = { size = { 340, 616 }, Count = { 14, 48, 130, 44 }, AddPlace = { 152, 48, 174, 44 }, PetGrid = { 14, 100, 312, 204 }, Best = { 14, 562, 152, 44 }, None = { 174, 562, 152, 44 }, Sheet = { 14, 316, 312, 234 } },
	BagPanel = { size = { 340, 520 }, Info = { 14, 52, 312, 66 }, BagGrid = { 14, 130, 312, 376 } },
	SwordPanel = { size = { 340, 448 }, Current = { 14, 56, 312, 138 }, Next = { 14, 216, 312, 142 }, Arrow = { 154, 194, 32, 22 }, Buy = { 14, 386, 312, 48 } },
	ShopPanel = { size = { 340, 520 }, SwordRow = { 14, 56, 312, 214 }, PenRow = { 14, 284, 312, 222 } },
}
local desktop = {
	EggPanel = { size = { 700, 620 }, Info = { 20, 58, 660, 38 }, ReadyGrid = { 20, 104, 660, 248 }, Hatching = { 20, 364, 660, 30 }, HatchGrid = { 20, 404, 660, 196 } },
	PetPanel = { size = { 820, 614 }, Count = { 20, 58, 200, 30 }, AddPlace = { 258, 54, 232, 44 }, PetGrid = { 20, 104, 470, 432 }, Best = { 20, 550, 226, 48 }, None = { 264, 550, 226, 48 }, Sheet = { 506, 104, 294, 494 } },
	BagPanel = { size = { 700, 520 }, Info = { 20, 58, 660, 46 }, BagGrid = { 20, 114, 660, 386 } },
	SwordPanel = { size = { 680, 440 }, Current = { 20, 64, 296, 290 }, Next = { 364, 64, 296, 290 }, Arrow = { 324, 176, 32, 44 }, Buy = { 20, 370, 640, 50 } },
	ShopPanel = { size = { 700, 358 }, SwordRow = { 20, 64, 660, 126 }, PenRow = { 20, 206, 660, 132 } },
}
function Layout.window(name: string, width: number, height: number, forceCompact: boolean?)
	local mode = if width < 500 then "portrait" elseif forceCompact or height < 560 or width < 820 then "wide" else "desktop"
	local definitions = if mode == "portrait" then portrait elseif mode == "wide" then wide else desktop
	return definitions[name], mode
end
function Layout.hud(width: number, height: number, compact: boolean)
	local portraitMode = width < 500
	local scale = if compact then math.min(1, (width - 28) / 352) else 1
	local buttons = {}
	for index = 1, 5 do
		buttons[index] = if compact then { 14 + (index - 1) * 72 * scale, if portraitMode then 78 else 52, 64, 62, scale }
			else { 20, math.max(16, (height - 416) / 2) + (index - 1) * 84, 72, 72, 1 }
	end
	local walletScale = if compact then 0.8 else 1.15
	local levelWidth = if portraitMode then width - 28 elseif compact then math.min(340, width - 260) else math.min(540, width - 420)
	return {
		menus = buttons,
		wallet = { if compact then width - 14 - 210 * walletScale else 16, if compact then 6 else height - 84, 210, 60, walletScale },
		base = { if portraitMode then 14 else (width - 92) / 2, 4, 92, 36 },
		luck = { 14, if portraitMode then 44 elseif compact then 10 else height - 130, 118, 30 },
		level = { (width - levelWidth) / 2, if portraitMode then 154 else height - 38, levelWidth, 26 },
		attack = if compact then { width - 164, height - 84, 58, 58 } else { width / 2 - 88, height - 134, 76, 76 },
		auto = if compact then { width - 164, height - 150, 58, 58 } else { width / 2 + 12, height - 134, 76, 76 },
	}
end
return Layout
