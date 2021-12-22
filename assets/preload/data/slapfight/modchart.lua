function onCreatePost()
	if difficulty > 0 then
		local healthDrain = (1 / 45) * (difficulty / (math.pi / 2))
		local healthDrainCap = (1 / 2) / difficulty

		function opponentNoteHit(id, direction, noteType, isSustainNote)
			if not isSustainNote then
				local health = getHealth()
				if health > healthDrainCap then
					setHealth(math.max(health - healthDrain, healthDrainCap))
				end
			end

			cameraShake("game", 1 / 120, 1 / 5, false)
			characterPlayAnim("gf", "scared", "true")

			if characterFinishedAnim("bf") or not string.match(characterGetAnim("bf"), "^sing") then
				characterPlayAnim("bf", "scared", true)
			end
		end
		if difficulty > 1 then
			local hitBeat = false
			local updateBeat = 16

			function onBeatHit()
				if (curBeat >= updateBeat) and not hitBeat then
					hitBeat = true
					if flashingLights then
						cameraFlash("other", "FF0000", 1, true)
					end
				end
			end
		end
	end
end