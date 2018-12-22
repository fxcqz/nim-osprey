# Osprey Copyright (C) 2018 M. Rawcliffe
# This program comes with ABSOLUTELY NO WARRANTY;
# This is free software, and you are welcome to redistribute it
# under certain conditions; see LICENSE.txt for details.

import os
import strutils
import json
import threadpool
import gintro / [ gtk, glib, gobject, gio ]
import matrix

var chan: Channel[string]

proc initConnection =
  # start the matrix connection on another thread
  let config: JsonNode = parseFile("config.json")
  var connection: MatrixClient = newMatrixClient(config)
  connection.login()
  connection.join()
  let initialData = connection.sync()
  let initialMessages = connection.extractMessages(initialData)
  chan.send(messagesToLines(initialMessages))

  while true:
    let data = connection.sync()
    let messages = connection.extractMessages(data)
    if messages.len > 0:
      chan.send(messagesToLines(messages))
    sleep(0)


proc updateChat(w: TextView): bool =
  let buf = w.getBuffer()
  let (res, msg) = chan.tryRecv()
  if res:
    #let content = buf.getText() & "\n" & msg
    buf.setText(msg, msg.len)

  return SOURCE_CONTINUE


proc appActivate(app: Application) =
  spawn initConnection()

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

  box.packStart(chatScroller, true, true, 0)

  # text entry
  let boxInput = newBox(Orientation.horizontal, 0)

  let inputText = newEntry()
  boxInput.packStart(inputText, true, true, 0)

  let inputButton = newButton("Send")
  boxInput.packStart(inputButton, false, false, 0)

  box.packStart(boxInput, false, false, 0)

  discard timeoutAdd(1000, updateChat, chatText)

  window.add(box)
  showAll(window)

proc main =
  chan.open()
  defer: chan.close()

  let app = newApplication("re.b5.osprey")
  connect(app, "activate", appActivate)
  discard run(app)


when isMainModule:
  main()
