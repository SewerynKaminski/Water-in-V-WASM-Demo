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

//@[heap]
struct App{
	mut: old_idx i32 = width
	new_idx i32 = width*(height+3)
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
	/*mut i:=0
	for i<480*270 {unsafe{ 
			pd := &this.frame[0]+i
			ps := &this.texture[0]+i
			*pd = *ps // GOOD!
			// *(&this.frame[0]+i) = u8(rand())// BAD!
		}i+=1}
	*/
	
	unsafe{
	mut i:= i32(0)
    
        i = this.old_idx
        this.old_idx = this.new_idx
        this.new_idx = i
	i=0
	// Initialize the looping values - each will be incremented
        mut map_idx := this.old_idx

	ripple_map := &this.ripple_map[0]
	mut y:= i32(0)
        for y < height {
		mut x:= i32(0)
                for x < width {
		    // Use ripple_map to set data value, map_idx = oldIdx
		    // Use averaged values of pixels: above, below, left and right of current
		    mut p:= ripple_map + (map_idx - 1)*2
		    mut data := *p
			p = ripple_map + (map_idx + 1)*2
                    data += *p
			p = ripple_map + (map_idx - width)*2
		    data += *p
			p = ripple_map + (map_idx + width)*2
		    data += *p
                    data >>= 1    // right shift 1 is same as divide by 2
		    // Subtract 'previous' value (we are about to overwrite rippleMap[newIdx+i])
		    p = ripple_map + (this.new_idx + i)*2
		    data -= *p
		    
		    // Reduce value more -- for damping
		    // data = data - (data / 32)
                    data -= data >> 5
		    
		    // Set new value
		    //p = ripple_map + this.new_idx + i
                    *p = data

                    // If data = 0 then water is flat/still,
		    // If data > 0 then water has a wave
                    data = (1<<10) - data  // zawsze dodatnie
        
		    p = &this.last_map[0] + i*2
                    old_data := *p
                    *p = data
        
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
			ps:= &this.texture[0] + a + (b * width)
			pd:= &this.frame[0] + i
                        *pd = *ps
                    }
                    map_idx += 1
                    i += 1
		
		    x+=1
                }
		y+=1
            }
	}
}

pub fn (mut this App)mousedown(x u32,y u32) {
}

pub fn (mut this App)mouseup(x u32, y u32){
}

const ripple_r = 3

pub fn (mut this App)mousemove(x u32, y u32){
    // Our ripple effect area is actually a square, not a circle
    mut j:= i32(y-ripple_r)
    for j < y + ripple_r {
	mut k:=i32(x - ripple_r)
        for k < x + ripple_r {
	    unsafe {
	    p:= &this.ripple_map[0] + this.old_idx*2
	    p+= ((j * i32(width)) + k)*2
            *p += 512 }
	    k+=1
        }
	j+=1
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
		//println( string{a,1} )
		a+=1
		b+=1
		//println(".")
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

	title := "V WASM Fire demo"
	JS.settitle ( title )
	JS.init( app )

	mut y:=0
	for y<height {
		mut x:=0
		for x<width {
			unsafe{
			p := &app.texture[0]+x+y*width
			if (x%50 < 25) == (y%50 < 25) { *p = 128 }
			else { *p = 0 }
			}
			x+=1
		}
		y+=1
	}

	JS.showptr ( &app.old_idx )
	JS.showptr ( &app.new_idx )
	//fire( &app.frame[0] )
	app.draw()
}
