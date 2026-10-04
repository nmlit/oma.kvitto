import QtQuick
import Quickshell
import qs.Ui

BarWidget {
  id: root
  moduleName: "oma.kvitto"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function toggleOverlay() {
    Quickshell.execDetached(["omarchy-shell", "shell", "toggle", "oma.kvitto", "{}"])
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "Kvitto"
    tooltipText: "Öppna kvittoutskrift"
    onPressed: function(b) {
      if (b === Qt.LeftButton) root.toggleOverlay()
    }
  }
}
