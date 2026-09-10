import QtQuick
import Quickshell

Item {
  id: root
  property var shell: null

  function open(payloadJson) {
    Quickshell.execDetached([
      "bash", "-c",
      "exec \"$HOME/Projects/omarchy-the-eternal-moment/launch.sh\""
    ])
    Qt.callLater(requestClose)
  }

  function close() {}

  function requestClose() {
    if (shell && typeof shell.hide === "function") {
      shell.hide("io.github.layolayo.eternal-moment")
    }
  }
}
