# Osprey Copyright (C) 2018 M. Rawcliffe
# This program comes with ABSOLUTELY NO WARRANTY;
# This is free software, and you are welcome to redistribute it
# under certain conditions; see LICENSE.txt for details.

import strutils
import gintro / [ gtk, glib, gobject, gio ]
import matrix

proc appActivate(app: Application) =
  let window = newApplicationWindow(app)
  window.title = "Osprey Client"
  window.defaultSize = (640, 480)

  # main layout box
  let box = newBox(Orientation.vertical, 10)

  # header
  let roomTitle = newLabel("Sett")
  roomTitle.setXalign(0)
  # header css
  let cssProvider = newCssProvider()
  discard cssProvider.loadFromData("label { font-size: 18pt; padding: .2em }")
  let styleContext = roomTitle.getStyleContext
  addProvider(styleContext, cssProvider, STYLE_PROVIDER_PRIORITY_USER)

  box.packStart(roomTitle, false, false, 0)
  # end header

  # chat box
  let chatScroller = newScrolledWindow(nil, nil)

  let chatText = newTextView()
  chatText.setWrapMode(WrapMode.word)
  chatText.setEditable(false)
  chatText.setCanFocus(false)
  chatScroller.add(chatText)

  let buf = chatText.getBuffer()
  buf.setText("<foo> yo\n".repeat(100), 900)
  box.packStart(chatScroller, true, true, 0)

  # text entry
  let boxInput = newBox(Orientation.horizontal, 0)

  let inputText = newEntry()
  boxInput.packStart(inputText, true, true, 0)

  let inputButton = newButton("Send")
  boxInput.packStart(inputButton, false, false, 0)

  box.packStart(boxInput, false, false, 0)

  window.add(box)
  showAll(window)

proc main =
  let app = newApplication("re.b5.osprey")
  connect(app, "activate", appActivate)
  discard run(app)


when isMainModule:
  main()



