# Osprey Copyright (C) 2018 M. Rawcliffe
# This program comes with ABSOLUTELY NO WARRANTY;
# This is free software, and you are welcome to redistribute it
# under certain conditions; see LICENSE.txt for details.

import os
import strutils
import json
import threadpool
import gintro / [ gtk, glib, gobject, gio, gdk ]
import matrix

var
  chan: Channel[string]
  sendChan: Channel[string]
  textChatData: string

proc initConnection =
  # start the matrix connection on another thread
  let config: JsonNode = parseFile("config.json")
  var connection: MatrixClient = newMatrixClient(config)
  # send the room name back to the ui
  chan.send(connection.config.roomName())
  connection.login()
  connection.join()
  let initialData = connection.sync()
  let initialMessages = connection.extractMessages(initialData)
  chan.send(messagesToLines(initialMessages))

  while true:
    # send msgs on the chan (prioritise this over receiving)
    let (res, msg) = sendChan.tryRecv()
    if res:
      connection.sendMessage(msg)

    # TODO perhaps this should tie in to the timeout and not run
    # as often
    let data = connection.sync()
    let messages = connection.extractMessages(data)
    if messages.len > 0:
      chan.send(messagesToLines(messages))

    sleep(0)


var chatRowCount = 0

proc updateChat(chatGrid: Grid): bool =
  let (res, msg) = chan.tryRecv()
  if res:
    # TODO make a proc for a more elaborate layout
    let msgLabel = newLabel(msg)
    msgLabel.setSelectable(true)
    msgLabel.setXAlign(0)
    chatGrid.attach(msgLabel, 0, chatRowCount, 1, 1)
    chatRowCount.inc
    showAll(chatGrid)

  return SOURCE_CONTINUE


proc sendMessage(w: Entry) =
  let msg = w.getText()
  if msg.len > 0:
    sendChan.send(w.getText())
    w.setText("")

proc onSendMessage(b: Button; w: Entry) = sendMessage(w)

proc onSendMessage(w: Entry) = sendMessage(w)


proc appActivate(app: Application) =
  spawn initConnection()

  let cssProvider = newCssProvider()
  discard cssProvider.loadFromData("")

  let window = newApplicationWindow(app)
  window.title = "Osprey Client"
  window.defaultSize = (640, 480)
  addProvider(window.getStyleContext, cssProvider,
              STYLE_PROVIDER_PRIORITY_USER)

  # main layout box
  let box = newBox(Orientation.vertical, 0)

  let notebook = newNotebook()
  # chat box
  # TODO make sure the scroller always sticks to the bottom
  let chatScroller = newScrolledWindow(nil, nil)

  let chatText = newGrid()
  discard timeoutAdd(1000, updateChat, chatText)
  chatScroller.add(chatText)

  # TODO should probably do something with the page id
  discard notebook.appendPage(chatScroller, newLabel(chan.recv()))

  box.packStart(notebook, true, true, 0)

  # text entry
  let boxInput = newBox(Orientation.horizontal, 0)

  let inputText = newEntry()
  inputText.addEvents(cast[EventMask](EventFlag.buttonRelease))
  inputText.connect("activate", onSendMessage)
  addProvider(inputText.getStyleContext, cssProvider,
              STYLE_PROVIDER_PRIORITY_USER)

  boxInput.packStart(inputText, true, true, 0)

  let inputButton = newButton("Send")
  inputButton.connect("clicked", onSendMessage, inputText)
  addProvider(inputButton.getStyleContext, cssProvider,
              STYLE_PROVIDER_PRIORITY_USER)
  boxInput.packStart(inputButton, false, false, 0)

  box.packStart(boxInput, false, false, 0)

  window.add(box)
  showAll(window)

proc main =
  chan.open()
  sendChan.open()
  defer:
    chan.close()
    sendChan.close()

  let app = newApplication("re.b5.osprey")
  connect(app, "activate", appActivate)
  discard run(app)


when isMainModule:
  main()
