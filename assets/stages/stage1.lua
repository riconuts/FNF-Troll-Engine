function onCreate()
	local offX = -1000/2
	local offY = -500/2

	makeLuaSprite("sky", "", offX, offY)
	makeGraphic('sky', 2560, 2560, '9AD9EA')
	makeLuaSprite("cave", "stage1/stage1 cave", offX + 711, offY + 25)
	makeLuaSprite("ground", "stage1/stage1 ground", offX, offY + 710)
	
	setScrollFactor("sky", 0, 0)
	setScrollFactor("cave", 0.75, 0.75)
	setScrollFactor("ground", 1, 0.95)
	
	addLuaSprite("sky")
	addLuaSprite("cave")
	addLuaSprite("ground")
end