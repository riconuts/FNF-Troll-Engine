function onCreate()
	local offX = -1000/2
	local offY = -500/2

	makeLuaSprite("sky", "extra2/extra2 sky", offX, offY)
	makeLuaSprite("back", "extra2/extra2 back", offX, offY + 500)
	makeLuaSprite("ground", "extra2/extra2 ground", offX + 500, offY + 710)
	
	setScrollFactor("sky", 0.3, 0)
	setScrollFactor("back", 0.8, 0.8)
	setScrollFactor("ground", 1, 0.95)
	
	addLuaSprite("sky")
	addLuaSprite("back")
	addLuaSprite("ground")
end