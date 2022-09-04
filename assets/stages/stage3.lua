function onCreate()
	local offX = -1000/2
	local offY = -500/2

	setProperty("camGame.bgColor", getColorFromHex("3F47CC"));

	---
	makeLuaSprite("back", "stage3/stage3 back", offX + 200, offY + 25)
	setScrollFactor("back", 0.75, 0.75)
	addLuaSprite("back")

	makeLuaSprite("back1", "stage3/stage3 back", offX + 200 - 2876, offY + 25)
	setScrollFactor("back1", 0.75, 0.75)
	setProperty("back1.flipX", true)
	addLuaSprite("back1")
	
	makeLuaSprite("back2", "stage3/stage3 back", offX + 200 + 2876, offY + 25)
	setScrollFactor("back2", 0.75, 0.75)
	setProperty("back2.flipX", true)
	addLuaSprite("back2")
	
	----
	makeLuaSprite("ground", "stage3/stage3 ground", offX, offY + 741)
	setScrollFactor("ground", 1, 0.95)
	addLuaSprite("ground")
	
	makeLuaSprite("ground1", "stage3/stage3 ground", offX - 2876, offY + 741)
	setScrollFactor("ground1", 1, 0.95)
	setProperty("ground1.flipX", true)
	addLuaSprite("ground1")

	makeLuaSprite("ground2", "stage3/stage3 ground", offX + 2876, offY + 741)
	setScrollFactor("ground2", 1, 0.95)
	setProperty("ground2.flipX", true)
	addLuaSprite("ground2")
end