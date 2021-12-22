function onCreatePost()
	if difficulty > 0 then
		local healthDrain = (1 / 90) * (difficulty / (math.pi / 2))
		local healthDrainCap = (1 / 2) / difficulty

		function opponentNoteHit(id, direction, noteType, isSustainNote)
			if not isSustainNote then
				local health = getHealth()
				if health > healthDrainCap then
					setHealth(math.max(health - healthDrain, healthDrainCap))
				end
				cameraShake("camGame", 1 / 240, 1 / 10, false)
			end
		end
	end
end