--Made by makeart.py: where game A's panel is in art/gamebackgroundgamea.png. The panel is
--twice as wide as at the Game Boy from PANELX on (Game Boy pixels), and ROWS[y + 1] is where its
--Game Boy row y starts. INKTOP and INKBOTTOM are the rows of the font's cells letters and digits
--fill, for centering them.
panel = {
	PANELX = 104, LEFT = 174, FONT = 'fonts/Nontendo-Bold',
	INKTOP = 0, INKBOTTOM = 9,
	ROWS = {0, 1, 3, 4, 6, 8, 10, 12, 14, 15, 17, 18, 20, 22, 24, 25, 27, 29, 31, 33, 34, 35, 37, 39, 40, 42, 43, 45, 47, 48, 50, 51, 53, 55, 57, 59, 60, 62, 63, 65, 67, 68, 70, 71, 73, 75, 77, 79, 81, 82, 84, 85, 87, 89, 90, 92, 94, 95, 97, 98, 100, 102, 103, 105, 107, 109, 111, 113, 114, 115, 117, 119, 121, 122, 124, 125, 127, 129, 130, 132, 134, 135, 137, 138, 140, 142, 143, 145, 147, 149, 151, 153, 154, 156, 157, 159, 160, 162, 163, 165, 167, 169, 171, 173, 174, 176, 177, 179, 181, 182, 184, 185, 187, 189, 190, 192, 194, 195, 197, 198, 200, 202, 203, 205, 206, 208, 210, 211, 213, 215, 216, 218, 219, 221, 223, 224, 226, 228, 230, 232, 234, 236, 237, 238, 240},
}
