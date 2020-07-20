My Attempt At Using FPGAs
=========================

I've never used an FPGA before. Here we go! I'm using [TinyFPGA](https://tinyfpga.com/).

I'm making a LED matrix (64 x 32, RGB) driver. You can ignore the tinyfpga_a directory - that was a failure.
I started out trying to do it with a TinyFPGA A2. Due to my inexperience and lack of knowledge with FPGAs,
I (like incorrectly) assumed that the A2 wouldn't work for me since the Verilog I wrote wouldn't fit on the
number of logic elements. I didn't know FPGAs often contain embedded block RAM, and I didn't know it was
dumb to try to store the amount of data I needed in the logic elements alone. By the way that amount of data
is

```
(width of LED matrix) * (height of LED matrix) * (# LEDs per "pixel") * (bit depth of color) = (# bits of memory required)
64 * 32 * 3 * 8 = 49152 bits
```

I had a feeling I was probably doing something very wrong, but I wasn't really sure. I had looked up what
other people had done for similar projects and saw that they were using external memory modules or other
solutions. I was like screw that I don't want to add any more circuitry - this should be possible with just
one of these off the shelf boards! It's 2020!

So then I bought a TinyFPGA BX, which has over 6x the number of logic elements! That should work, right?
After buying the BX, I decided it might make sense to take a deeper look at FPGAs first and learn more
about how they really work. This is when I learned that they contain RAM. The A2 I originally bought has
64 kbit of block RAM, and the BX has 128 kbit. 
