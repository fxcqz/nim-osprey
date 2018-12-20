import strutils
import gintro / [ gtk, gobject ]
import matrix

proc bye(w: Window) =
  mainQuit()
  echo "Bye..."

proc main =
  gtk.init()
  let window = newWindow()
  window.title = "First test"
  window.connect("destroy", bye)
  window.showAll
  gtk.main()



when isMainModule:
  main()

