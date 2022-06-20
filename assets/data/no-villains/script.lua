local defaultZoom = 1
local zoomed = false

function onCreatePost()
	defaultZoom = getProperty("defaultCamZoom")
	
	----
	makeLuaSprite("camshit", "", 0, 0)
	setProperty("camshit.y", defaultZoom)
end



function updateCamShit()
	setProperty("defaultCamZoom", getProperty("camshit.y"))
end

function onTweenCompleted(tag)
	onUpdate = nil
end

function onStepHit()
	if not zoomed and curStep >= 1664 and curStep < 1920 then
		zoomed = true
		doTweenY("camshitZoom1", "camshit", 1.3, 1.5, "inOutQuad") -- 1.6
		onUpdate = updateCamShit
	end
	if zoomed and curStep >= 1920 then
		zoomed = false
		doTweenY("camshitZoom2", "camshit", defaultZoom, 1.5, "inOutQuad")
		onUpdate = updateCamShit
	end
end