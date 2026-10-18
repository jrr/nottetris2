function menu_load()
	gamestate = "logo"
	creditstext = {
	"'Tm and C2011 sy,not",
	"tetris 2 licensed to",
	"  stabyourself.net  ",
	"         and        ",
	"  sub-licensed to   ",
	"      maurice.      ",
	"                    ",
	" C2011 stabyourself ",
	"       dot net.     ",
	"                    ",
	"                    ",
	"all rights reserved.",
	"                    ",
	"  original concept, ",
	" design and program ",
	"by alexey pazhitnov#"
	}
	logotime = 0
	bootsoundplayed = false
	oldtime = platform.gettime()
end

function menu_draw()
	if gamestate == "logo" then		
		if logotime <= logoduration then
			platform.draw(stabyourselflogo, 7*scale, math.floor(-22*scale + 80*(logotime/logoduration)*scale), 0, scale, scale)
		else
			platform.draw(stabyourselflogo, 7*scale, math.floor(58*scale), 0, scale, scale)
		end

	elseif gamestate == "credits" and platform.drawcredits then --lettered by the platform, its own way
		platform.drawcredits(creditstext)
	
	elseif gamestate == "credits" then------------		
		for i, v in pairs(creditstext) do
			platform.print( v, 0, i*8*scale, 0, scale)
		end
		platform.draw(logo, 32*scale, 80*scale, 0, scale)
	------------------------------------------
	
	elseif gamestate == "title" then----------
		if platform.drawtitle then --the title and its cursor, drawn by the platform, its own way
			platform.drawtitle()
		else
			platform.draw(title, 0, 0, 0, scale)
			platform.print(">", 1*scale, 124*scale, 0, scale)
		end
	------------------------------------------
	
	elseif (gamestate == "menu" or gamestate == "highscoreentry") and platform.drawmenu then
		--the menu drawn by the platform, its own way: which choices are lettered black (1-6: normal,
		--stack, a-type, b-type, c-type, off), the top scores, and the name being entered
		local shown = {}
		if selection > 2 then
			shown[gameno] = true
		else
			shown[musicno + 2] = true
		end
		if selectblink == true then
			shown[selection] = true
		end
		platform.drawmenu(shown, highscorename, highscore, gamestate == "highscoreentry" and highscoreno, cursorblink)
	
	elseif gamestate == "menu" or gamestate == "highscoreentry" then
		platform.draw(gametype, 0, 0, 0, scale)
		if selection > 2 then
			if gameno == 1 then
				platform.print( "normal", 24*scale, 26*scale, 0, scale)
			else
				platform.print( "stack ", 88*scale, 26*scale, 0, scale)
			end
		else
			if musicno == 1 then
				platform.print( "a-type", 24*scale, 60*scale, 0, scale)
			elseif musicno == 2 then
				platform.print( "b-type", 88*scale, 60*scale, 0, scale)
			elseif musicno == 3 then
				platform.print( "c-type", 24*scale, 76*scale, 0, scale)
			else
				platform.print( " off  ", 88*scale, 76*scale, 0, scale)
			end
		end
		
		if selectblink == true then
			if selection ==1 then
				platform.print( "normal", 24*scale, 26*scale, 0, scale)
			elseif selection == 2 then
				platform.print( "stack ", 88*scale, 26*scale, 0, scale)
			elseif selection == 3 then
				platform.print( "a-type", 24*scale, 60*scale, 0, scale)
			elseif selection == 4 then
				platform.print( "b-type", 88*scale, 60*scale, 0, scale)
			elseif selection == 5 then
				platform.print( "c-type", 24*scale, 76*scale, 0, scale)
			elseif selection == 6 then
				platform.print( " off  ", 88*scale, 76*scale, 0, scale)
			end
		end
	----------------------------------------------
	
	end
	
	if (gamestate == "menu" or gamestate == "highscoreentry") and not platform.drawmenu then
		for i = 1, 3 do
			if tonumber(highscore[i]) > 0 then
				--name
				platform.print(string.lower(string.sub(highscorename[i], 1, 6)), 33*scale, 110*scale+8*scale*(i-1), 0, scale)
				--score
				offsetX = 0
				for i = 1, string.sub(tostring(highscore[i]), 1, 6):len() - 1 do
					offsetX = offsetX - 8*scale
				end
				platform.print(string.sub(tostring(highscore[i]), 1, 6), 137*scale+offsetX, 110*scale+8*scale*(i-1), 0, scale)
			end
		end
	end
	
	if gamestate == "highscoreentry" and not platform.drawmenu then
		if highscorename[highscoreno]:len() < 6 then
			offsetX = 0
			for i = 1, highscorename[highscoreno]:len() do
				offsetX = offsetX + 8*scale
			end
			if cursorblink == true then
				platform.print("_", 33*scale+offsetX, 110*scale+8*scale*(highscoreno-1), 0, scale)
			else
				platform.print(" ", 33*scale+offsetX, 110*scale+8*scale*(highscoreno-1), 0, scale)
			end
		else
			if cursorblink == true then
				platform.print("_", 33*scale+8*scale*5, 110*scale+8*scale*(highscoreno-1), 0, scale)
			end
		end
	end
	
	------------------------------------------
end

function menu_update(dt)
	if gamestate == "logo" then
		logotime = logotime + dt
		
		if logotime >= logoduration and bootsoundplayed == false then			
			platform.stop(boot)
			platform.play(boot)
			
			bootsoundplayed = true
		end
		
		if logotime >= logoduration + logodelay then
			oldtime = platform.gettime()
			gamestate = "credits"
		end
	end

	if gamestate == "credits" then
		currenttime = platform.gettime()
		if currenttime - oldtime > creditsdelay then
			gamestate = "title"
			platform.setbackgroundcolor( 0, 0, 0)
			platform.play(musictitle)
		end
	end
	
	if gamestate == "menu" then
		currenttime = platform.gettime()
		if currenttime - oldtime > selectblinkrate then
			selectblink = not selectblink
			oldtime = currenttime
		end
	end
	
	if gamestate == "highscoreentry" then
		currenttime = platform.gettime()
		if currenttime - oldtime > cursorblinkrate then
			cursorblink = not cursorblink
			oldtime = currenttime
		end
		if currenttime - highscoremusicstart > 1.2 then
			if musicchanged == false then
				musicchanged = true
				platform.stop(highscoreintro)
				platform.play(musichighscore)
			end
		end
	end
end