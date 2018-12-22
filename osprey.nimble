# Package

version       = "0.1.0"
author        = "fxcqz"
description   = "Matrix Chat Client"
license       = "GPL-3.0"
srcDir        = "src"
bin           = @["osprey"]


# Dependencies

requires "nim >= 0.19.0"
requires "gintro"


task run, "Run the program":
  exec "nim c -r --threads:on -d:ssl src/osprey.nim"
