; ID: 2756
; Author: TWH
; Date: 2010-08-23 14:06:09
; Title: Marching Squares
; Description: traces the contours of a bitmap image

'written by TWH aka Torbjoern
'25. aug 
'-fixed multiplie out-of-bounds errors, added getOutlinePixmap( Tpixmap )
'-only the current pixel (pos.x,pos.y) is marked as tracked/visited,

superstrict
graphics 640,480,0,0,2

global fpsCounter:TFPSCounter= new TFPSCounter

type TUIState
	field activeItem:int = -1
	field hotItem:int = -1
end type

global uistate:TUIState = new TUIState
global lowerColor:TColor = TColor.Create(0,0,0)
global upperColor:TColor = TColor.Create(255,255,255)

function mainloop()
	local msquares:TMarchingSquares = new TMarchingSquares
	
	local width:int = 320
	local height:int = 240
	local screen:int[,] = new int[width,height]
	local pointList:tlist = null
	local brushSiz# = 10
	
	local pixmap:TPixmap = LoadPixmap("fry.png")

	
	while not appterminate() and not keyhit(KEY_ESCAPE)
		cls
		'draw our painting surface
		local i:int, j:int
		for i=0 until width
		for j=0 until height
			if( screen[i,j] )
				setcolorARGB( screen[i,j] )
				plot i,j
			endif
		next
		next
	
		'Draw a bitmap using the mouse:
		brushSiz :+ MouseZSpeed() 'change brush size using scrollwheel
		brushSiz = min(30.0, max(2.0, brushSiz) )
		drawCircle(mousex(), mousey(), brushSiz) 'draw our brush
		if mousedown(1) then paintbrush(mousex(), mousey(), brushSiz, $00ffff00, screen)
		
		if keydown(KEY_1) 
			msquares.animated = false
			pointList = msquares.getOutline(screen) 'get a list of outline points
		endif
		
		if keydown(KEY_2) 
			msquares.animated = true 'animate the process
			pointList = msquares.getOutline(screen) 
		endif
		
		if keyhit(KEY_3) 
			msquares.animated = false
			if pixmap then pointList = msquares.getOutlinePixmap(pixmap, lowerColor, upperColor) 
		endif
		
		'Draw all points generated by marching squares
		if pointList<>null
			setcolor 0,255,0
			for local p:vec2 = eachin pointList
				plot p.x, p.y
			next
		endif
		
		setcolor 255,255,255
		DrawLineRect(0,0,width,height)
		if pixmap then drawpixmap(pixmap,width+10,0)
		
		'Begin slider code (lower and upper color threshold for pixmap)
		local sliderLen:int = 255
		local slider_x:int = 15
		local lo_r% = lowerColor.r
		local lo_g% = lowerColor.g 
		local lo_b% = lowerColor.b
		
		local hi_r% = upperColor.r
		local hi_g% = upperColor.g 
		local hi_b% = upperColor.b
		Slider(0, slider_x + (sliderLen+15)*0, height+15*4, sliderLen, $ff0000, lo_r)
		Slider(1, slider_x + (sliderLen+15)*1, height+15*4, sliderLen, $ff0000, hi_r)
		Slider(2, slider_x + (sliderLen+15)*0, height+15*5, sliderLen, $00ff00, lo_g)
		Slider(3, slider_x + (sliderLen+15)*1, height+15*5, sliderLen, $00ff00, hi_g)
		Slider(4, slider_x + (sliderLen+15)*0, height+15*6, sliderLen, $0000ff, lo_b)
		Slider(5, slider_x + (sliderLen+15)*1, height+15*6, sliderLen, $0000ff, hi_b)
		lowerColor.set(lo_r, lo_g, lo_b)
		upperColor.set(hi_r, hi_g, hi_b)
		'End sliders

		local text_y_pos:int = height+100
		drawtext "getOutline()-test, draw here",15, text_y_pos+15*+0
		drawtext "getOutlinePixmap()-test ",15+width*1,  text_y_pos+15*+0
		drawtext "press key 1 update outline",15, text_y_pos+15*+1
		drawtext "press key 2 to see marching squares working",15, text_y_pos+15*+2
		drawtext "Sliders adjust lower lower/upper color threshold for pixmap",15, text_y_pos+15*+3

		drawtext "fps: "+fpsCounter.fps, 15,graphicsheight()-30
		
		fpsCounter.update()
		
	flip
	wend
end function
mainloop()

function unpackARGB(argb:int, a% var, r% var, g% var, b% var)
	a = argb shr 24 & $ff
	r = (argb shr 16) & $ff
	g = (argb shr 8) & $ff
	b = argb & $ff
end function

function setColorARGB(argb:int)
	local a:int = argb shr 24 & $ff
	local r:int = argb shr 16 & $ff
	local g:int = argb shr 8 & $ff
	local b:int = argb & $ff
	setcolor r,g,b
end function

'taken from Sol's graphics tutorial at sol.gfxile.net
function paintbrush(x#,y#,r:int,c:int,screen:int[,])
   local i#, j:int
   for i=0 until 2*r step 1
      local length:int = int( sqr( cos(0.5*180*(i-r)/r)) * r * 2 );
      for j=0 until length
         local xp:int = floor(x+j-length/2.0 + 0.5);
         local yp:int = floor(y-r+i + 0.5);
			local width:int = screen.Dimensions()[0]
			local height:int = screen.Dimensions()[1]
         if(xp > 0 and  xp < (width-1) and yp > 0 and  yp < (height-1))
            screen[xp,yp] = c;
         endif
      next
   next
end function


type vec2
  field x:int,y:int

  function create:vec2(x:int,y:int)
    local tmp:vec2 = new vec2
    tmp.x = x; tmp.y = y;
    return tmp
  end function

end type

type TMarchingSquares
	field bmd:int[,]
	field width:int, height:int
	field variations_cw:vec2[16]
	field variations_ccw:vec2[16]
	field tracked:int[,] 'used to remember if we've traced the pixel earlier
	field points:TList 'list of traced points. Might contain dupes
	field animated:int = false
	
	field errCase15:int = 0
	field errCase0:int = 0
	field foundLoop:int = 0

  method new()
    variations_cw[ 0] = vec2.create( 0, 0) 'illegal. No way to find direction.
    variations_cw[ 1] = vec2.create( 1, 0) ' r
    variations_cw[ 2] = vec2.create( 0, 1) ' d
    variations_cw[ 3] = vec2.create( 1, 0) ' r
    variations_cw[ 4] = vec2.create( 0,-1) ' l
    variations_cw[ 5] = vec2.create( 0,-1) ' u
    variations_cw[ 6] = vec2.create( 0,-1) ' u
    variations_cw[ 7] = vec2.create( 0,-1) ' u
    variations_cw[ 8] = vec2.create( 1, 0) ' l
    variations_cw[ 9] = vec2.create( 1, 0) ' r
    variations_cw[10] = vec2.create( 0, 1) ' d
    variations_cw[11] = vec2.create( 1, 0) ' r
    variations_cw[12] = vec2.create(-1, 0) ' l
    variations_cw[13] = vec2.create(-1, 0) ' l
    variations_cw[14] = vec2.create( 0, 1) ' u
    variations_cw[15] = vec2.create( 0, 0) ' illegal. 
  
    variations_ccw[ 0] = vec2.create( 0, 0) ' illegal
    variations_ccw[ 1] = vec2.create( 0, 1) ' d v
    variations_ccw[ 2] = vec2.create(-1, 0) ' l <
    variations_ccw[ 3] = vec2.create(-1, 0) ' l <
    variations_ccw[ 4] = vec2.create( 1, 0) ' r >
    variations_ccw[ 5] = vec2.create( 0, 1) ' d v
    variations_ccw[ 6] = vec2.create(-1, 0) ' l <
    variations_ccw[ 7] = vec2.create(-1, 0) ' l <
    variations_ccw[ 8] = vec2.create( 0,-1) ' u ^
    variations_ccw[ 9] = vec2.create( 0,-1) ' u ^
    variations_ccw[10] = vec2.create( 0,-1) ' u ^
    variations_ccw[11] = vec2.create( 0,-1) ' u ^
    variations_ccw[12] = vec2.create( 1, 0) ' r >
    variations_ccw[13] = vec2.create( 0, 1) ' d v
    variations_ccw[14] = vec2.create( 1, 0) ' r >
    variations_ccw[15] = vec2.create( 0, 0) ' illegal
  end method

	method getOutlinePixmap:TList( bitmapdata:TPixmap, lowerThreshold:TColor, upperThreshold:TColor )
		bmd = new int[bitmapdata.width, bitmapdata.height]
		width = bitmapdata.width
		height = bitmapdata.height
		
		for local x:int = 0 until width
		for local y:int = 0 until height
			local pixel:int = readpixel(bitmapdata,x,y)
			local a:int, r:int, g:int, b:int 'alpha isnt used
			unpackARGB(pixel,a,r,g,b)
			local avgColor:int = (r+g+b) / 3

			local color_rule:int = 1
			select color_rule
				case 1 if avgColor > 128 bmd[x,y] = 1 'trace white-ish parts, worked images with a white background
				case 2 if avgColor < 128 bmd[x,y] = 1 'trace black-ish parts, workd well on shapes with black contours
				case 3
					'all values must be witin threshold
					if r > lowerThreshold.r and r < upperThreshold.r or..
						g > lowerThreshold.g and g < upperThreshold.g or..
						b > lowerThreshold.r and b < upperThreshold.b
						bmd[x,y] = 1
					endif
					'values may be witin on or another threshold
				case 4
					if r > lowerThreshold.r and r < upperThreshold.r or..
						g > lowerThreshold.g and g < upperThreshold.g or..
						b > lowerThreshold.r and b < upperThreshold.b
						bmd[x,y] = 1
					endif
			end select
		next
		next		

		return searchEachPixel()
	end method
	
	method getOutline:TList( bitmapdata:int[,])
		bmd = bitmapdata
		width = bitmapdata.dimensions()[0]
		height = bitmapdata.dimensions()[1]
		
		return searchEachPixel()
 	end method

	method searchEachPixel:TList()
		tracked = new int[width,height]
		'memclear(varptr tracked[0,0], 4*width*height) 'is this good practice? Does bmax init arrays to 0?
		points = new TList

		' reset error status
		errCase15 = 0
		errCase0 = 0
		foundLoop = 0
		
		'find pixels that have something in them and are untracked so far, run marching squares on pixel
		'keep boundries witin image (2x2) marching squares area 
		for local y:int=2 until height-2
		for local x:int=2 until width-2
			if(bmd[x,y] > 0)
				if( not tracked[x,y])
					marchingSquares(x,y);
				endif
			endif
		next
		next
	
		return points
	end method

  method marchingSquares(x:int,y:int)
	local pos:vec2 = vec2.create( x-1, y-1 ) 'move back and up from pixel
	local start:vec2 = vec2.create( pos.x, pos.y )
	local outOfBounds:int = pos.x < 1 or pos.x > (width-2) or pos.y < 1 or pos.y > (height-2)		
	assert not outOfBounds
	
	local iters:int = 0
	
	while(true)
		iters:+1
		tracked[pos.x,pos.y] :+ 1
		local dirTableIndex:int = getNextEdgePoint(pos)
		outOfBounds = pos.x < 1 or pos.x > (width-2) or pos.y < 1 or pos.y > (height-2)		
		if outOfBounds then return
		if( dirTableIndex=0 or dirTableIndex=15 ) then return 'quit if illegal marching squares state
		if( pos.x=start.x and pos.y=start.y ) then return 'were back at start, finished trace
		if( tracked[pos.x,pos.y] > 2 )  'tracked this pixel too many times, prevent inf loops caused by bad pixel configurations.
			foundLoop:+1
			return 
		endif
		
		points.addLast( vec2.create(pos.x, pos.y) )
		
		' Visualize marching squares progress
		if(animated)
			setcolor(0,50+5*iters mod 150,0)
			plot(pos.x,pos.y)
			
			if(iters mod 5 = 0)  
				flip()
				delay(5)
			endif
		endif
		
	wend
	
	end method

	'use marching squares look-up-table to decide where to move next
	method getNextEdgePoint:int(pos:vec2)
		local x:int = pos.x; local y:int = pos.y
		local index:int = 0
		if( bmd[x+1,y+1] > 0 ) index :+ 1;
		if( bmd[x,y+1] > 0 ) index :+ 2;	
		if( bmd[x+1,y] > 0 ) index :+ 4;
		if( bmd[x,y] > 0 ) index :+ 8;

		' Error
		if( index=15 ) then errCase15:+1;  
		if( index=0) then errCase0:+1; 
		
		pos.x :+ variations_ccw[index].x; pos.y :+ variations_ccw[index].y
		'pos.x += variations_cw[index].x; pos.y += variations_cw[index].y
		return index;
	end method  

end type

type TColor
	field r:byte, g:byte, b:byte 
	function Create:TColor(r:byte, g:byte, b:byte)
		local tmp:TColor = new TColor
		tmp.r = r; tmp.g = g; tmp.b = b;
		return tmp
	end function
	
	method set(r:byte, g:byte, b:byte)
		self.r = r; self.g = g; self.b = b;
	end method 
end type


'Immidiate mode slider function
'Inspired by Sols tutorial: http://sol.gfxile.net/imgui/ch05.html
'What it does: Draws a GUI slider and modifies the slideValue sent to it
'To use a slider, specifiy an id (0 upto MAXSLIDERS)

function Slider(id:int, x#, y#, length#, color:int, slideValue:int var)
	const MAXSLIDERS:int = 7
	assert id < MAXSLIDERS-1
	global mouseLock:int[MAXSLIDERS]
	global sliderValue:int[MAXSLIDERS]
	global globCtor:int = false
	
	if globCtor = false
		globCtor = true
		for local i:int = 0 until MAXSLIDERS
			mouseLock[i] = false
			sliderValue[i] = length / 2
		next
	endif
	
	
	local handle_size# = 10
	local handle_x_pos# = x+slideValue-handle_size/2
	local handle_y_pos# = y-handle_size/2
	
	if PointInRect(mousex(), mousey(),handle_x_pos, handle_y_pos, handle_size, handle_size)
		uistate.hotitem = id
		if( uistate.activeitem = -1 and mouseDown(1) )
			uistate.activeitem = id
		endif
	endif
	
	if not mouseDown(1) then uistate.activeitem = -1 'release grip of handle
	
	setcolor 127,127,127
	drawrect(x,y-2,length,4)
	
	if uistate.hotitem = id
		setcolor 255,255,255
	else
		setcolor 127,127,127
	endif
	
	if uistate.activeitem = id then setcolorARGB(color)

	drawrect(handle_x_pos, handle_y_pos, handle_size, handle_size)
	
	if uistate.activeitem = id
		drawtext ""+slideValue ,handle_x_pos-5,handle_y_pos-15
		if( mousex() < x+length and mousex() > x ) 'limit movement to slider line
			slideValue = mousex()-x
		endif
	endif

end function 

function PointInRect:int(testx#,testy#,topleftx#,toplefty#,w#,h#)
   if(testx >= topleftx and testx <= topleftx+w and..
		testy >= toplefty and testy <= toplefty+h)
      return true
	endif
	return false 
end function

Type TFPSCounter
	Field frames:Int=0
	Field fps:Int=0
	Field sec:Long = MilliSecs()
	
	Method update()
		If(sec < MilliSecs() )
			sec = MilliSecs() + 100
			fps = frames*10
			frames = 0
		EndIf
		frames :+1
	End Method
End Type

'circle outline func by ImaginaryHuman
'http://www.blitzbasic.com/codearcs/codearcs.php?code=1476
function drawCircle(xCenter:Int=320, yCenter:Int=240, radius:Int)
	Local p:int,x:int,y:Int
	x=0
	y=radius
	Plot xCenter+x,yCenter+y
	Plot xCenter-x,yCenter+y
	Plot xCenter+x,yCenter-y
	Plot xCenter-x,yCenter-y
	Plot xCenter+y,yCenter+x
	Plot xCenter-y,yCenter+x
	Plot xCenter+y,yCenter-x
	Plot xCenter-y,yCenter-x
	p=1-radius
	While x<y
		If p<0
			x:+1
		Else
			x:+1
			y:-1
		EndIf
		If p<0
			p=p+(x Shl 1)+1
		Else
			p=p+((x-y) Shl 1)+1
		EndIf
		Plot xCenter+x,yCenter+y
		Plot xCenter-x,yCenter+y
		Plot xCenter+x,yCenter-y
		Plot xCenter-x,yCenter-y
		Plot xCenter+y,yCenter+x
		Plot xCenter-y,yCenter+x
		Plot xCenter+y,yCenter-x
		Plot xCenter-y,yCenter-x
	wend
End function

'DrawLineRect by drnmr
'http://www.blitzmax.com/codearcs/codearcs.php?code=1674
Function DrawLineRect(x:Int,y:Int,length:Int,height:Int)
	local lowerlefty% = y+height
	local lowerrightx% = x+length
	local lowerrighty% = y+height
	local upperrightx% = x+length
	DrawLine x,y,x,lowerlefty
	DrawLine x,lowerlefty,lowerrightx,lowerrighty
	DrawLine lowerrightx,lowerrighty,upperrightx,y
	DrawLine upperrightx,y,x,y
EndFunction
