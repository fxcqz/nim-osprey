import nimx / [ window, text_field, layout, formatted_text, types,
                button ]

proc startApp() =
  var wnd = newWindow(newRect(40, 40, 800, 600))
  wnd.makeLayout:
    - Label as titleLabel:
      top == 20
      leading == 20
      height == 20
      text: "Sett"
      textColor: newColor(0.0, 0.0, 1.0)
    - TextField as body:
      top == prev.bottom + 5
      leading == 10
      width == super.width - 20
      height == super.height - 100
      editable: false
      multiline: true
      hasBezel: true
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

  var mainText = newFormattedText("""<Foo> lol
<Bar> this is dumb
<Foo> yeah dunno why im bothering""")
  mainText.verticalAlignment = vaTop
  body.formattedText = mainText

runApplication:
  startApp()
