function onCreate()
	local offX = -1000/2
	local offY = -500/2

	makeLuaSprite("sky", "extra1/extra1 sky", offX, offY)
	makeLuaSprite("ground", "extra1/extra1 ground", offX, offY + 756)
	
	setScrollFactor("sky", 0.3, 0)
	setScrollFactor("ground", 1, 0.95)
	
	addLuaSprite("sky")
	addLuaSprite("ground")
end