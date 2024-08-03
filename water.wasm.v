fn JS.canvas_x () int
fn JS.canvas_y () int
fn JS.setpixel ( x int, y int, c u8 )
fn JS.settitle ( t &string )
fn JS.test ( r &Rect )
fn JS.teststr ( s &string )
fn JS.init ( app &App )
fn JS.line ( x0 u32, y0 u32, x1 u32, y1 u32, c u32)
fn JS.showptr( p &i32 )

const width = i32(480)
const height = i32(270)
const half_width = i32(width/2)
const half_height = i32(height/2)
const size = width*(height+2)*2

@[heap]
struct App{
	mut: old_idx i32 = width
	new_idx i32 = i32(width*(height+3))
	frame [480*270]u8
	texture [480*270]u8
	ripple_map [480*(270+3)*2]i16
	last_map [480*(270+3)]i16
}

struct Rect{
 x i32
 y i32
 w i32
 h i32
}

__global(
	rnd_next=u32(0x04030201)
	app=App{}
)

fn rand() u32 { // RAND_MAX assumed to be 32767
    rnd_next = rnd_next * 1103515245 + 12345
    return (rnd_next>>16) & 0x7fff
}

fn srand ( seed u32 ) {
    rnd_next = seed
}


pub fn (mut this App) draw () {
	mut i:= i32(0)
    
        i = this.old_idx
        this.old_idx = this.new_idx
        this.new_idx = i
	i=0
	// Initialize the looping values - each will be incremented
        mut map_idx := this.old_idx

        for y:=0; y < height; y+=1 {
		map_idx+=1
	        i+=1
                for x:=1; x < width-1; x+=1 {
		    // Use ripple_map to set data value, map_idx = oldIdx
		    // Use averaged values of pixels: above, below, left and right of current	
		    mut data:= this.ripple_map [ map_idx - 1]
		    data += this.ripple_map [ map_idx + 1]
		    data += this.ripple_map [ map_idx - width]
		    data += this.ripple_map [ map_idx + width]			
                    data >>= 1    // right shift 1 is same as divide by 2
		    // Subtract 'previous' value (we are about to overwrite rippleMap[newIdx+i])
		    data -= this.ripple_map[this.new_idx + i]
		    
		    // Reduce value more -- for damping
		    // data = data - (data / 32)
                    data -= data >> 5
		    
		    // Set new value
		    ii := this.new_idx + i
		    this.ripple_map[ii] = data

                    // If data = 0 then water is flat/still,
		    // If data > 0 then water has a wave
                    data = (1<<10) - data  // zawsze dodatnie
        
		    old_data := this.last_map[i]
		    this.last_map[i] = data
        
                    if old_data != data { // if no change no need to alter image
                        // Calculate pixel offsets
                        mut a := (i32((x - half_width) * data)>>10) + half_width
                        mut b := (i32((y - half_height) * data)>>10) + half_height
                        
                        // Don't go outside the image (i.e. boundary check)
                        if a >= width { a = width - 1 }
                        if a < 0 { a = 0 }
                        if b >= height { b = height - 1 }
                        if b < 0 { b = 0 }
			
			// Apply values
			this.frame[i] = this.texture[a + (b * width)]
                    }
                    map_idx += 1
                    i += 1
                }
		map_idx+=1
		i+=1
            }
}

pub fn (mut this App)mousedown(x u32,y u32) {
}

pub fn (mut this App)mouseup(x u32, y u32){
}

const ripple_r = 3

pub fn (mut this App)mousemove(x u32, y u32){
    // Our ripple effect area is actually a square, not a circle
    xmr := i32(x - ripple_r)
    ymr := i32(y - ripple_r)
    xpr := x + ripple_r
    ypr := y + ripple_r
	
    for j:= ymr; j < ypr; j+=1 {
        if j<0 { j=0 }
	if j>=height { break }
        for k:=xmr; k < xpr; k+=1 {	    
	    if k<1 { k=1 }
	    if k>=width-1 { break }
	    i:= this.old_idx + ((j * i32(width)) + k)
	    this.ripple_map[i] += 512
        }
    }
}

const key_1 = '1\000'
const key_2 = '2\000'
const key_shift = 'Shift\000'

pub fn (mut app App)keydown(key &u8, code &u8) {
   println('V: keydown')
   unsafe{
   }
}


fn cmp( a &u8, b &u8 ) bool {  
   unsafe {
        for *a>0 && *b>0 {
		if *a!=*b { break }
		a+=1
		b+=1
        }
	return *a==*b
   }
}

const code_backspace = 'Backspace\000'
const code_shift_left = 'ShiftLeft\000'
const code_shift_right = 'ShiftRight\000'

pub fn (mut app App)keyup( key &u8, code &u8) {
	if cmp ( code, code_shift_left.str ) {
		println ( code_shift_left )
	}
	if cmp ( code, code_shift_right.str ) {
		println ( code_shift_right )
	}
	println ( 'up' )
}

// `main` must be public!
pub fn main() {
	vwasm_memory_grow(10)

	title := "V WASM Water demo"
	JS.settitle ( title )
	JS.init( app )

	for y:=0; y<height; y+=1 {
	    for x:=0; x<width; x+=1 {
		if (x%50 < 25) == (y%50 < 25) { 
		    app.texture[x+y*width] = 128
		} else {
		    app.texture[x+y*width] = 0
		}
	    }
	}

	app.draw()
}
