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
import system.services show ServiceClient ServiceSelector ServiceResourceProxy
import system.services show ServiceProvider ServiceHandler ServiceResource

THREADS ::= 4

// Takes a single argument, the width/height of the image.
// Produces a PPM image of the Mandelbrot set on stdout.
// The standard benchmark size is 16000 x 16000.
main args/List:
  if args.size < 1:
    print "Usage: mandelbrot <size> [<filename> [<threads>]]"
    print "eg:    mandelbrot 3000 out.ppm 8"
    return
  h ::= args.size >= 1 ? int.parse args[0] : 1600
  w ::= h

  filename := args.size >= 2 ? args[1] : null
  threads := args.size >= 3 ? (int.parse args[2]) : THREADS

  threads.repeat: | index |
    spawn::
      service := MandelbrotServiceProvider index
      print_ "Service $index created"
      service.install
      print_ "Service $index started"
      service.uninstall --wait
      print_ "Service $index stopped"

  out := ?
  if filename:
    out = file.Stream.for-write filename
  else:
    out = pipe.stdout
  out.write "P4\n$w $h\n"

  calculated-y := 0

  channel := monitor.Channel 30

  results := Map

  threads.repeat: | index |
    task::
      client := null
      while not client:
        catch --trace:
          c := MandelbrotServiceClient index
          c.open --timeout=(Duration --s=30)
          client = c
      while calculated-y < h:
        my-y := calculated-y
        calculated-y++
        imaginary := 2.0 * my-y / h - 1.0
        line := client.line imaginary 2.0 -1.5 w
        channel.send [my-y, line]
      client.close

  print_ "Clients started"

  h.repeat: | y |
    while not results.contains y:
      packet := channel.receive
      y2 := packet[0]
      print_ y2
      results[y2] = packet[1]
    out.write results[y]
    results.remove y

  out.close

interface MandelbrotService:
  static SELECTOR ::= ServiceSelector
      --uuid="92a27db8-2ec1-4d24-bfbc-3932cd71c145"
      --major=1
      --minor=0

  line imaginary/float scale/float offset/float width/int -> ByteArray
  static LINE-INDEX /int ::= 0

class MandelbrotServiceClient extends ServiceClient implements MandelbrotService:
  static SELECTOR ::= MandelbrotService.SELECTOR

  constructor index/int:
    selective-selector := MandelbrotService.SELECTOR.restrict.allow --tag="$index"
    assert: selective-selector.matches SELECTOR
    super selective-selector

  line imaginary/float scale/float offset/float width/int -> ByteArray:
    return invoke_ MandelbrotService.LINE-INDEX [imaginary, scale, offset, width]

class MandelbrotServiceProvider extends ServiceProvider
    implements ServiceHandler:

  index/int

  constructor .index/int:
    super "benchmark/mandelbrot" --major=1 --minor=0
    provides MandelbrotService.SELECTOR --handler=this --tags=["$index"]

  handle index/int arguments/any --gid/int --client/int -> any:
    if index == MandelbrotService.LINE-INDEX:
      return line arguments[0] arguments[1] arguments[2] arguments[3]
    unreachable

  line imaginary/float scale/float offset/float width/int -> ByteArray:
    now := Time.monotonic-us
    print_ "Start calculating $imaginary"

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
    print_ "Done calculating $imaginary"
    return result
