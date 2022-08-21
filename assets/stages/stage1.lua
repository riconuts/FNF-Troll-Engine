function onCreate()
	local offX = -1000/2
	local offY = -500/2

	setProperty("camGame.bgColor", getColorFromHex("9AD9EA"));

	makeLuaSprite("cave", "stage1/stage1 cave", offX + 711, offY + 25)	
	setScrollFactor("cave", 0.75, 0.75)
	addLuaSprite("cave")

	makeLuaSprite("ground", "stage1/stage1 ground", offX, offY + 710)
	setScrollFactor("ground", 1, 0.95)
	addLuaSprite("ground")
end