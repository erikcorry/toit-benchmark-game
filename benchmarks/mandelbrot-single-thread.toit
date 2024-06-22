// Copyright (C) 2024 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the top level LICENSE file.

// The Computer Language Benchmarks game
// https://salsa.debian.org/benchmarksgame-team/benchmarksgame/
//
// The actual Mandelbrot calculation was transliterated from Greg Buchholz's C
// program by Isaac Gouy.  The parallel implementation is by Toitware ApS.
// 
// (Toit is for live-programming low-power microcontrollers over WiFi.)   

// Using a Toit service to calculate the Mandelbrot set in parallel.

import host.file
import host.pipe
import monitor

// Takes a single argument, the width/height of the image.
// Produces a PPM image of the Mandelbrot set on stdout.
// The standard benchmark size is 16000 x 16000.
main args/List:
  if args.size < 1:
    print "Usage: mandelbrot-single-threaded <size> [<filename>"
    print "eg:    mandelbrot-single-threaded 3000 out.ppm"
    return
  h ::= args.size >= 1 ? int.parse args[0] : 1600
  w ::= h

  filename := args.size >= 2 ? args[1] : null

  out := ?
  if filename:
    out = file.Stream.for-write filename
  else:
    out = pipe.stdout
  out.write "P4\n$w $h\n"

  h.repeat: | y |
    imaginary := 2.0 * y / h - 1.0
    line := generate-line imaginary 2.0 -1.5 w
    out.write line
  out.close

generate-line imaginary/float scale/float offset/float width/int -> ByteArray:
  now := Time.monotonic-us

  ITER ::= 50
  LIMIT-SQUARED ::= 4.0
  result := ByteArray width >> 3
  (width >> 3).repeat: | x1 |
    8.repeat: | x2 |
      x := (x1 << 3) + x2
      zr := 0.0
      zi := 0.0
      tr := 0.0
      ti := 0.0
      cr := scale * x / width + offset
      ci := imaginary
      for i := 0; i < ITER and (tr + ti <= LIMIT-SQUARED); ++i:
        zi *= zr
        zi += zi + ci
        zr = tr - ti + cr
        tr = zr * zr
        ti = zi * zi
        
      if tr + ti <= 4.0:
        result[x1] |= 128 >> x2
  return result
