import QtQuick
import Quickshell

Item {
  id: root
  property var shell: null

  function open(payloadJson) {
    Quickshell.execDetached([
      "bash", "-c",
      'for dir in "$HOME/.config/omarchy/plugins/io.github.layolayo.eternal-moment" "$HOME/Projects/omarchy-the-eternal-moment"; do if [ -x "$dir/launch.sh" ]; then exec "$dir/launch.sh"; fi; done'
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
