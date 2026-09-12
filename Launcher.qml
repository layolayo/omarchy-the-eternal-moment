import QtQuick
import Quickshell

Item {
  id: root
  property var shell: null

  function open(payloadJson) {
    var appPath = decodeURIComponent(Qt.resolvedUrl("App.qml").toString().replace(/^file:\/\//, ""));
    // Launch exclusively via verified absolute runtime and reviewed plugin entrypoint
    if (typeof Quickshell.execDetached === "function") {
      try {
        Quickshell.execDetached(["/usr/bin/quickshell", "-p", appPath]);
      } catch (e) {
        console.warn("Launch failed:", e);
      }
    }
    Qt.callLater(requestClose);
  }

  function close() {}

  function requestClose() {
    if (shell && typeof shell.hide === "function") {
      shell.hide("io.github.layolayo.eternal-moment");
    }
  }
}
