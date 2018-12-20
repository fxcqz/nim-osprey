import strutils
import nimx / [ window, text_field, layout, formatted_text, types,
                button, scroll_view ]

import matrix

proc startApp() =
  var wnd = newWindow(newRect(40, 40, 800, 600))
  wnd.title = "Opsrey Matrix Client"
  wnd.makeLayout:
    - Label as titleLabel:
      top == 20
      leading == 20
      height == 20
      text: "Sett"
      textColor: newColor(0.0, 0.0, 1.0)
    - ScrollView as bodyPanel:
      top == prev.bottom + 5
      leading == 10
      width == super.width - 20
      height == super.height - 100
      - TextField as body:
        editable: false
        multiline: true
        width == super.width
    - TextField:
      top == prev.bottom + 5
      leading == 10
      width == super.width - 20 - 50
      height == 30
    - Button:
      top == prev.top
      height == 30
      leading == prev.width + 10
      width == 50
      title: "Send"

  let messages = @[
    "<foo> lol",
    "<bar> this is dumb",
    "<foo> yeah dunno why im bothering",
    "<foo> scrolling is hard af too",
    "<bar> use a deque idiot",
    "<other> spam",
    "<other> spam",
    "<other> spam",
    "<other> spam",
    "<other> spam",
    "<other> spam",
    "<other> spam",
    "<other> spam",
    "<other> spam",
    "<other> spam",
    "<other> spam",
    "<other> spam",
    "<other> spam",
    "<other> spam",
    "<other> spam",
    "<other> spam",
    "<other> spam",
    "<other> spam",
    "<other> spam",
    "<other> spam",
    "<other> spam",
    "<other> spam",
    "<other> spam",
    "<other> spam",
    "<other> spam",
    "<other> spam",
    "<other> spam",
    "<other> spam",
    "<other> spam",
    "<other> spam",
    "<other> spam",
    "<other> spam",
    "<other> spam",
    "<other> spam",
    "<other> spam",
    "<other> spam",
    "<other> spam",
    "<other> spam",
    "<other> spam",
    "<other> spam",
    "<other> spam",
    "<other> spam",
    "<other> spam",
    "<other> spam",
    "<other> spam",
    "<other> spam",
    "<other> spam",
    "<other> spam",
    "<other> spam",
    "<other> spam",
    "<other> spam",
  ]
  var mainText = newFormattedText(messages.join("\n"))
  mainText.verticalAlignment = vaBottom
  body.formattedText = mainText


runApplication:
  startApp()

