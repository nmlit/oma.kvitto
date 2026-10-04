import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui

Item {
  id: root

  property var shell: null
  property var manifest: null
  property bool opened: false
  property string draft: ""
  property string statusText: ""

  readonly property string pluginDir: (manifest && manifest.__sourceDir)
    ? String(manifest.__sourceDir)
    : (Quickshell.env("HOME") + "/.config/omarchy/plugins/oma.kvitto")
  readonly property string printScript: pluginDir + "/print.sh"
  readonly property color bg: Color.menu ? Color.menu.background : "#1a1a1a"
  readonly property color fg: Color.menu ? Color.menu.text : "#eeeeee"
  readonly property color scrim: Color.menu && Color.menu.scrim ? Color.menu.scrim : Qt.rgba(0, 0, 0, 0.45)
  readonly property string fontFamily: Style.font && Style.font.family ? Style.font.family : "sans-serif"
  readonly property int editorMin: 120
  readonly property int editorMax: 360

  function open(payload) {
    root.opened = true
    root.statusText = ""
    Qt.callLater(function() {
      if (input) input.forceActiveFocus()
    })
  }

  function close() {
    root.opened = false
  }

  function dismiss() {
    root.close()
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide("oma.kvitto")
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open("{}")
  }

  function printReceipt() {
    var t = String(root.draft).replace(/\s+$/g, "")
    if (!t) {
      root.statusText = "Skriv något först."
      return
    }
    printProc.command = ["bash", root.printScript, t]
    printProc.running = true
    root.statusText = "Skriver ut…"
  }

  Process {
    id: printProc
    stdout: StdioCollector { waitForEnd: true }
    stderr: StdioCollector {
      id: errOut
      waitForEnd: true
    }
    onExited: function(code) {
      if (code === 0)
        root.statusText = "Utskrivet."
      else
        root.statusText = errOut.text.trim() !== "" ? errOut.text.trim() : ("Felkod " + code)
    }
  }

  IpcHandler {
    target: "oma.kvitto"
    function open(): void { root.open("{}") }
    function close(): void { root.dismiss() }
    function show(): void { root.open("{}") }
    function hide(): void { root.dismiss() }
    function toggle(): void { root.toggle() }
  }

  PanelWindow {
    id: win
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "oma-kvitto"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      z: 0
      onClicked: root.dismiss()
    }

    Rectangle {
      id: card
      z: 1
      width: 460
      height: contentCol.implicitHeight + 32
      radius: 12
      anchors.centerIn: parent
      color: root.bg
      border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.2)
      border.width: 1

      Column {
        id: contentCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 16
        spacing: 10

        Text {
          text: "Kvitto"
          color: root.fg
          font.family: root.fontFamily
          font.pixelSize: 18
          font.bold: true
          textFormat: Text.PlainText
        }

        Rectangle {
          id: editorBox
          width: parent.width
          height: Math.min(root.editorMax, Math.max(root.editorMin, input.contentHeight + 20))
          radius: 8
          clip: true
          color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08)
          border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.18)
          border.width: 1
          layer.enabled: true

          Flickable {
            id: flick
            anchors.fill: parent
            anchors.margins: 10
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick
            interactive: input.contentHeight > height
            contentWidth: width
            contentHeight: Math.max(height, input.contentHeight)

            TextEdit {
              id: input
              width: flick.width
              height: Math.max(flick.height, contentHeight)
              wrapMode: TextEdit.Wrap
              selectByMouse: true
              color: root.fg
              font.family: root.fontFamily
              font.pixelSize: 14
              textFormat: TextEdit.PlainText
              text: root.draft
              onTextChanged: root.draft = text
              onContentHeightChanged: Qt.callLater(ensureCursorVisible)
              onCursorRectangleChanged: ensureCursorVisible()

              function ensureCursorVisible() {
                var top = cursorRectangle.y
                var bot = cursorRectangle.y + cursorRectangle.height
                if (top < flick.contentY)
                  flick.contentY = Math.max(0, top)
                else if (bot > flick.contentY + flick.height)
                  flick.contentY = Math.max(0, bot - flick.height)
              }

              Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) {
                  root.dismiss()
                  event.accepted = true
                }
              }
            }
          }
        }

        Row {
          spacing: 8

          Repeater {
            model: [
              { label: "Skriv ut", action: "print" },
              { label: "Rensa", action: "clear" },
              { label: "Stäng", action: "close" }
            ]
            delegate: Rectangle {
              required property var modelData
              width: 90
              height: 32
              radius: 8
              color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, mouse.containsMouse ? 0.22 : 0.12)

              Text {
                anchors.centerIn: parent
                text: modelData.label
                color: root.fg
                font.family: root.fontFamily
                font.pixelSize: 13
                textFormat: Text.PlainText
              }

              MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (modelData.action === "print") root.printReceipt()
                  else if (modelData.action === "clear") {
                    root.draft = ""
                    root.statusText = ""
                    flick.contentY = 0
                  } else {
                    root.dismiss()
                  }
                }
              }
            }
          }
        }

        Text {
          width: parent.width
          text: root.statusText
          wrapMode: Text.WordWrap
          color: root.fg
          font.family: root.fontFamily
          font.pixelSize: 12
          textFormat: Text.PlainText
        }
      }
    }
  }
}
