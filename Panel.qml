import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import QtCore
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "ProcessData.js" as ProcessData
import "Database.js" as Database
import "Report.js" as Report
import "PdfReport.js" as PdfReport

Panel {
  id: root

  moduleName: "io.github.layolayo.eternal-moment"
  ipcTarget: "io.github.layolayo.eternal-moment"
  manageIpc: false

  property string activeTab: "chamber" // "chamber", "archive", "report", "lore"
  property int activeSessionId: 0
  property string sessionUuid: ""
  property int currentStepIndex: 0
  property var flatSteps: []
  property var answers: []
  property int preClarity: 50
  property int preMovement: 50
  property int preFocus: preMovement
  property int postClarity: 50
  property int postMovement: 50
  property int postFocus: postMovement
  property bool isCheckinModalOpen: false
  property bool isFinishMetricsModalOpen: false
  property var selectedTags: []
  property string sessionFeedback: ""
  property string copyStatusMessage: ""
  property var historicalSessions: []
  property var viewingSession: null
  property string answerDraft: ""

  readonly property var currentStep: (flatSteps && currentStepIndex >= 0 && currentStepIndex < flatSteps.length) ? flatSteps[currentStepIndex] : null
  readonly property int currentSet: currentStep ? currentStep.set : 1
  readonly property string currentQuestionText: currentStep ? ProcessData.formatQuestionText(currentStep, answers, flatSteps) : "Session Complete"
  readonly property string currentStepType: currentStep ? currentStep.key : ""

  readonly property color foreground: bar ? bar.foreground : Color.popups.text
  readonly property color background: bar ? bar.background : Color.popups.background
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color accentColor: Color.accent
  readonly property color pastColor: "#3b82f6"
  readonly property color futureColor: "#d946ef"
  readonly property color goldColor: "#f59e0b"
  readonly property color cyanColor: "#06b6d4"
  readonly property color mutedColor: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.6)

  Component.onCompleted: {
    Database.initDb();
    flatSteps = ProcessData.buildFlatSteps();
    refreshHistory();
    if (historicalSessions.length === 0) {
      startNewSession();
    } else {
      // If there is an in-progress session, load it; otherwise prepare a fresh one
      var latest = Database.loadSession(historicalSessions[0].id);
      if (latest && latest.status === "in_progress") {
        resumeSession(latest);
      } else {
        startNewSession();
      }
    }
  }

  function refreshHistory() {
    historicalSessions = Database.listSessions();
  }

  function startNewSession() {
    if (!flatSteps || flatSteps.length === 0) {
      flatSteps = ProcessData.buildFlatSteps();
    }
    activeSessionId = 0;
    sessionUuid = Database.generateUUID();
    currentStepIndex = 0;
    answers = new Array(flatSteps.length).fill("");
    preClarity = 50;
    preMovement = 50;
    preFocus = 50;
    postClarity = 50;
    postMovement = 50;
    postFocus = 50;
    selectedTags = [];
    sessionFeedback = "";
    copyStatusMessage = "";
    answerDraft = "";
    activeTab = "chamber";
    viewingSession = null;
    isFinishMetricsModalOpen = false;

    // Persist draft
    try {
      var s = {
        id: 0,
        uuid: sessionUuid,
        status: "in_progress",
        current_step: 0,
        pre_clarity: preClarity,
        pre_movement: preMovement,
        pre_focus: preMovement,
        answers: answers
      };
      activeSessionId = Database.saveSession(s);
      refreshHistory();
    } catch (e) {
      console.error("Error saving new session in Panel:", e);
    }
    isCheckinModalOpen = true;
  }

  function resumeSession(session) {
    if (!session) return;
    activeSessionId = session.id;
    sessionUuid = session.uuid;
    currentStepIndex = session.current_step || 0;
    answers = session.answers || new Array(flatSteps.length).fill("");
    preClarity = session.pre_clarity !== undefined ? session.pre_clarity : 50;
    preMovement = session.pre_movement !== undefined ? session.pre_movement : (session.pre_focus || 50);
    preFocus = preMovement;
    postClarity = session.post_clarity !== undefined ? session.post_clarity : 50;
    postMovement = session.post_movement !== undefined ? session.post_movement : (session.post_focus || 50);
    postFocus = postMovement;
    selectedTags = session.tags || [];
    sessionFeedback = session.feedback || "";
    answerDraft = (answers && answers[currentStepIndex]) ? answers[currentStepIndex] : "";
    copyStatusMessage = "";
    viewingSession = null;
    activeTab = "chamber";
  }

  function openSessionReport(session) {
    viewingSession = session;
    copyStatusMessage = "";
    activeTab = "report";
  }

  function getResolvedReportSession() {
    if (viewingSession) return viewingSession;
    var active = activeSessionId ? Database.loadSession(activeSessionId) : null;
    var hasActiveAnswers = false;
    if (active && active.answers && Array.isArray(active.answers)) {
      for (var i = 0; i < active.answers.length; i++) {
        if (active.answers[i] && String(active.answers[i]).trim().length > 0) {
          hasActiveAnswers = true;
          break;
        }
      }
    }
    if (hasActiveAnswers) {
      return active;
    }
    var recents = (historicalSessions && historicalSessions.length > 0) ? historicalSessions : Database.listSessions(10);
    if (recents && recents.length > 0) {
      for (var h = 0; h < recents.length; h++) {
        var cand = Database.loadSession(recents[h].id);
        if (cand && cand.answers && Array.isArray(cand.answers)) {
          for (var j = 0; j < cand.answers.length; j++) {
            if (cand.answers[j] && String(cand.answers[j]).trim().length > 0) {
              return cand;
            }
          }
        }
      }
      return Database.loadSession(recents[0].id) || active;
    }
    return active;
  }

  function saveFinalMetrics() {
    if (!root.activeSessionId) return;
    var s = {
      id: activeSessionId,
      uuid: sessionUuid,
      status: currentStepIndex >= flatSteps.length ? "completed" : "in_progress",
      current_step: Math.min(currentStepIndex, flatSteps.length),
      final_insight: (answers && answers[flatSteps.length - 1]) ? answers[flatSteps.length - 1] : ((answers && answers[80]) ? answers[80] : ""),
      pre_clarity: preClarity,
      pre_movement: preMovement,
      pre_focus: preMovement,
      post_clarity: postClarity,
      post_movement: postMovement,
      post_focus: postMovement,
      tags: selectedTags,
      feedback: sessionFeedback,
      answers: answers
    };
    activeSessionId = Database.saveSession(s);
    refreshHistory();
  }

  function advanceStep() {
    if (currentStepIndex >= flatSteps.length) {
      saveFinalMetrics();
      isFinishMetricsModalOpen = true;
      return;
    }

    var updated = [];
    for (var i = 0; i < answers.length; i++) updated.push(answers[i]);
    updated[currentStepIndex] = answerDraft.trim();
    answers = updated;

    currentStepIndex++;

    var isDone = currentStepIndex >= flatSteps.length;
    // Auto-save progress
    var s = {
      id: activeSessionId,
      uuid: sessionUuid,
      status: (isDone ? "completed" : "in_progress"),
      current_step: Math.min(currentStepIndex, flatSteps.length),
      final_insight: (answers && answers[flatSteps.length - 1]) ? answers[flatSteps.length - 1] : ((answers && answers[80]) ? answers[80] : ""),
      pre_clarity: preClarity,
      pre_movement: preMovement,
      pre_focus: preMovement,
      post_clarity: postClarity,
      post_movement: postMovement,
      post_focus: postMovement,
      tags: selectedTags,
      feedback: sessionFeedback,
      answers: answers
    };
    activeSessionId = Database.saveSession(s);
    refreshHistory();

    if (isDone) {
      isFinishMetricsModalOpen = true;
    }

    answerDraft = (currentStepIndex < flatSteps.length && answers[currentStepIndex]) ? answers[currentStepIndex] : "";
  }

  function toggleTag(tag) {
    var arr = [];
    var found = false;
    for (var i = 0; i < selectedTags.length; i++) {
      if (selectedTags[i] === tag) {
        found = true;
      } else {
        arr.push(selectedTags[i]);
      }
    }
    if (!found) arr.push(tag);
    selectedTags = arr;
  }

  function isTagSelected(tag) {
    for (var i = 0; i < selectedTags.length; i++) {
      if (selectedTags[i] === tag) return true;
    }
    return false;
  }

  function escapeShell(str) {
    return "'" + String(str).replace(/'/g, "'\\''") + "'";
  }

  function copyReportText() {
    var target = getResolvedReportSession();
    if (!target) return;
    var md = Report.generateMarkdownReport(target, flatSteps, ProcessData.questionLibrary);
    Quickshell.execDetached(["/bin/sh", "-c", "export PATH=/usr/bin:/bin; printf '%s' " + escapeShell(md) + " | wl-copy"]);
    copyStatusMessage = "Report copied to clipboard!";
  }

  function exportReportToFile() {
    var target = getResolvedReportSession();
    if (!target) return;
    var md = Report.generateMarkdownReport(target, flatSteps, ProcessData.questionLibrary);
    var d = new Date();
    var ts = d.getFullYear() + "" + String(d.getMonth() + 1).padStart(2, '0') + "" + String(d.getDate()).padStart(2, '0') + "_" + String(d.getHours()).padStart(2, '0') + "" + String(d.getMinutes()).padStart(2, '0');
    var filename = "Process4_EternalMoment_" + ts + ".md";
    var docsLoc = "";
    try {
      docsLoc = decodeURIComponent(String(StandardPaths.writableLocation(StandardPaths.DocumentsLocation)).replace(/^file:\/\//, ""));
    } catch (e) {}
    if (!docsLoc || docsLoc === "undefined" || docsLoc === "null") {
      try {
        docsLoc = decodeURIComponent(String(StandardPaths.writableLocation(StandardPaths.HomeLocation)).replace(/^file:\/\//, "")) + "/Documents";
      } catch (e2) {}
    }
    if (!docsLoc || docsLoc === "undefined" || docsLoc === "null" || docsLoc === "/Documents") {
      docsLoc = "/tmp";
    }
    var targetPath = docsLoc + "/" + filename;
    var cmd = "export PATH=/usr/bin:/bin; mkdir -p " + escapeShell(docsLoc) + " && printf '%s' " + escapeShell(md) + " > " + escapeShell(targetPath);
    Quickshell.execDetached(["/bin/sh", "-c", cmd]);
    copyStatusMessage = "Saved to " + targetPath;
  }

  function exportPdfToFile() {
    var target = getResolvedReportSession();
    if (!target) return;
    var pdfData = PdfReport.generatePdf(target, flatSteps, ProcessData.questionLibrary);
    var d = new Date();
    var ts = d.getFullYear() + "" + String(d.getMonth() + 1).padStart(2, '0') + "" + String(d.getDate()).padStart(2, '0') + "_" + String(d.getHours()).padStart(2, '0') + "" + String(d.getMinutes()).padStart(2, '0');
    var filename = "Process4_EternalMoment_" + ts + ".pdf";
    var docsLoc = "";
    try {
      docsLoc = decodeURIComponent(String(StandardPaths.writableLocation(StandardPaths.DocumentsLocation)).replace(/^file:\/\//, ""));
    } catch (e) {}
    if (!docsLoc || docsLoc === "undefined" || docsLoc === "null") {
      try {
        docsLoc = decodeURIComponent(String(StandardPaths.writableLocation(StandardPaths.HomeLocation)).replace(/^file:\/\//, "")) + "/Documents";
      } catch (e2) {}
    }
    if (!docsLoc || docsLoc === "undefined" || docsLoc === "null" || docsLoc === "/Documents") {
      docsLoc = "/tmp";
    }
    var targetPath = docsLoc + "/" + filename;
    var cmd = "export PATH=/usr/bin:/bin; mkdir -p " + escapeShell(docsLoc) + " && printf '%s' " + escapeShell(pdfData) + " > " + escapeShell(targetPath);
    Quickshell.execDetached(["/bin/sh", "-c", cmd]);
    copyStatusMessage = "Saved to " + targetPath;
    Qt.openUrlExternally("file://" + targetPath);
  }

  function shareHighlightToX() {
    var target = getResolvedReportSession();
    if (!target) return;
    var url = Report.generateXIntentUrl(target);
    Qt.openUrlExternally(url);
  }

  function stepTypeColor(key) {
    if (key === "awehyb") return root.pastColor;
    if (key === "awemyb") return root.futureColor;
    if (key === "now" || key === "p4_starter") return root.goldColor;
    if (key === "awitdbwykatsawykn") return root.goldColor;
    if (key === "cta") return root.cyanColor;
    return root.accentColor;
  }

  function stepTypeBadge(key) {
    if (root.currentStep && root.currentStep.stepTitle) return root.currentStep.stepTitle.toUpperCase();
    if (key === "awehyb") return "PAST";
    if (key === "awemyb") return "FUTURE";
    if (key === "now" || key === "p4_starter") return "NOW";
    if (key === "cta") return "COMPARE";
    if (key === "review") return "REVIEW";
    if (key === "awitdbwykatsawykn") return "EMERGENCE";
    return "STEP";
  }

  IpcHandler {
    target: root.ipcTarget

    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function newSession(): void { root.startNewSession() }
    function report(): void { root.activeTab = "report" }
  }

  implicitWidth: barButton.implicitWidth
  implicitHeight: barButton.implicitHeight

  BarIconButton {
    id: barButton
    anchors.fill: parent
    bar: root.bar
    text: "⏳"
    fontSize: Style.bar.iconFont
    tooltipText: "The Eternal Moment (Process #4)"
    onPressed: function(button) { root.toggle() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: barButton
    owner: root
    bar: root.bar
    open: root.opened
    centerOnBar: false
    contentWidth: Style.space(480)
    contentHeight: panel.fittedContentHeight(scrollContent.implicitHeight + panel.padding * 2, Style.space(780))

    Controls.ScrollView {
      id: scrollArea
      anchors.fill: parent
      clip: true
      Controls.ScrollBar.horizontal.policy: Controls.ScrollBar.AlwaysOff
      Controls.ScrollBar.vertical.policy: scrollContent.implicitHeight > height
        ? Controls.ScrollBar.AsNeeded
        : Controls.ScrollBar.AlwaysOff

      Column {
        id: scrollContent
        width: scrollArea.availableWidth
        spacing: Style.space(14)

        // ----------------- Header -----------------
        Item {
          width: parent.width
          implicitHeight: Math.max(headerIcon.implicitHeight, headerTextCol.implicitHeight, headerActions.implicitHeight)

          Text {
            id: headerIcon
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "⏳"
            font.pixelSize: Style.space(30)
            color: root.foreground
          }

          Column {
            id: headerTextCol
            anchors.left: headerIcon.right
            anchors.leftMargin: Style.space(12)
            anchors.right: headerActions.left
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              width: parent.width
              text: "The Eternal Moment"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.heading
              font.bold: true
            }

            Text {
              width: parent.width
              text: "Emergent Knowledge · Process #4"
              color: root.goldColor
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }
          }

          Row {
            id: headerActions
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(6)

            Button {
              text: "＋ New"
              accent: root.goldColor
              bordered: true
              onClicked: root.startNewSession()
            }
          }
        }

        // ----------------- Tab Bar -----------------
        Row {
          width: parent.width
          spacing: Style.space(6)

          Button {
            width: (parent.width - Style.space(18)) / 4
            text: "🌌 Chamber"
            accent: root.accentColor
            bordered: root.activeTab === "chamber"
            color: root.activeTab === "chamber" ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.15) : "transparent"
            onClicked: root.activeTab = "chamber"
          }

          Button {
            width: (parent.width - Style.space(18)) / 4
            text: "📜 Archive"
            accent: root.cyanColor
            bordered: root.activeTab === "archive"
            color: root.activeTab === "archive" ? Qt.rgba(root.cyanColor.r, root.cyanColor.g, root.cyanColor.b, 0.15) : "transparent"
            onClicked: {
              root.refreshHistory();
              root.activeTab = "archive";
            }
          }

          Button {
            width: (parent.width - Style.space(18)) / 4
            text: "📋 Report"
            accent: root.goldColor
            bordered: root.activeTab === "report"
            color: root.activeTab === "report" ? Qt.rgba(root.goldColor.r, root.goldColor.g, root.goldColor.b, 0.15) : "transparent"
            onClicked: root.activeTab = "report"
          }

          Button {
            width: (parent.width - Style.space(18)) / 4
            text: "ℹ Lore"
            accent: root.pastColor
            bordered: root.activeTab === "lore"
            color: root.activeTab === "lore" ? Qt.rgba(root.pastColor.r, root.pastColor.g, root.pastColor.b, 0.15) : "transparent"
            onClicked: root.activeTab = "lore"
          }
        }

        // =========================================================
        // ----------------- 1. CHAMBER TAB ------------------------
        // =========================================================
        Column {
          width: parent.width
          spacing: Style.space(12)
          visible: root.activeTab === "chamber"

          // Progress tracker
          BorderSurface {
            width: parent.width
            implicitHeight: progRow.implicitHeight + Style.space(12)
            color: Qt.rgba(root.background.r, root.background.g, root.background.b, 0.5)
            radius: Style.cornerRadius
            borderSpec: Border.flat(Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.1), 1)

            Row {
              id: progRow
              width: parent.width - Style.space(16)
              anchors.centerIn: parent

              Text {
                text: root.currentStepIndex >= root.flatSteps.length ? "Integration" : (root.currentStep && root.currentStep.key === "awitdbwykatsawykn" ? "Emergent Insight" : (root.currentStep && root.currentStep.key === "cta" && root.currentStep.compareTargetIndex === 0 ? "1–7 Comparison" : (root.currentStep && root.currentStep.stepTitle === "Now 7" ? "Now 7" : ("Set " + root.currentSet + " / 6"))))
                color: root.cyanColor
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }

              Item { width: Style.space(10); height: 1 }

              Rectangle {
                width: parent.width - Style.space(180)
                height: Style.space(6)
                anchors.verticalCenter: parent.verticalCenter
                radius: height / 2
                color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.15)

                Rectangle {
                  height: parent.height
                  radius: height / 2
                  width: parent.width * Math.min(1.0, root.currentStepIndex >= root.flatSteps.length ? 1.0 : ((root.currentStepIndex + 1) / Math.max(1, root.flatSteps.length)))
                  color: root.goldColor
                }
              }

              Item { width: Style.space(10); height: 1 }

              Text {
                text: root.currentStepIndex >= root.flatSteps.length ? (root.flatSteps.length + " / " + root.flatSteps.length + " · Complete") : ("Step " + (root.currentStepIndex + 1) + " / " + root.flatSteps.length)
                color: root.mutedColor
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                horizontalAlignment: Text.AlignRight
              }
            }
          }

          // Question Card
          BorderSurface {
            width: parent.width
            implicitHeight: qCol.implicitHeight + Style.space(24)
            color: Qt.rgba(0.02, 0.04, 0.09, 0.85)
            radius: Style.cornerRadius
            borderSpec: Border.flat(root.stepTypeColor(root.currentStepType), 1.5)
            visible: root.currentStepIndex < root.flatSteps.length

            Column {
              id: qCol
              width: parent.width - Style.space(24)
              anchors.centerIn: parent
              spacing: Style.space(10)

              Row {
                width: parent.width
                spacing: Style.space(8)

                Rectangle {
                  height: Style.space(20)
                  width: badgeText.implicitWidth + Style.space(12)
                  radius: Style.space(10)
                  color: Qt.rgba(root.stepTypeColor(root.currentStepType).r, root.stepTypeColor(root.currentStepType).g, root.stepTypeColor(root.currentStepType).b, 0.2)
                  border.width: 1
                  border.color: root.stepTypeColor(root.currentStepType)

                  Text {
                    id: badgeText
                    anchors.centerIn: parent
                    text: root.stepTypeBadge(root.currentStepType)
                    color: root.stepTypeColor(root.currentStepType)
                    font.family: root.fontFamily
                    font.pixelSize: Style.space(10)
                    font.bold: true
                  }
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.currentStep ? (ProcessData.questionLibrary[root.currentStep.key] ? ProcessData.questionLibrary[root.currentStep.key].label : "") : ""
                  color: root.mutedColor
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
              }

              Text {
                width: parent.width
                text: root.currentQuestionText
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.heading - 2
                font.bold: true
                lineHeight: 1.2
                wrapMode: Text.WordWrap
              }

              // Context breadcrumb for comparisons
              Item {
                width: parent.width
                implicitHeight: ctxText.implicitHeight
                visible: root.currentStepType === "cta"

                Text {
                  id: ctxText
                  width: parent.width
                  text: (root.currentStep && root.currentStep.compareTargetIndex === 0) ? "💡 Compare where you stood at the very beginning (Now 1) with where you stand now (Now 7)." : "💡 Notice the subtle resonance, similarities, or contrasts between these two internal reference points."
                  color: root.mutedColor
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  wrapMode: Text.WordWrap
                }
              }

              // 1-7 Temporal Comparison Reference for Emergent Insight
              Rectangle {
                width: parent.width
                implicitHeight: insightRefCol.implicitHeight + Style.space(16)
                radius: Style.cornerRadius - 2
                color: Qt.rgba(root.goldColor.r, root.goldColor.g, root.goldColor.b, 0.08)
                border.width: 1
                border.color: Qt.rgba(root.goldColor.r, root.goldColor.g, root.goldColor.b, 0.3)
                visible: root.currentStep && root.currentStep.key === "awitdbwykatsawykn"

                Column {
                  id: insightRefCol
                  width: parent.width - Style.space(16)
                  anchors.centerIn: parent
                  spacing: Style.space(4)

                  Text {
                    text: "⚡ Grounded on 1–7 Temporal Comparison:"
                    color: root.goldColor
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption - 1
                    font.bold: true
                  }

                  Text {
                    width: parent.width
                    text: "• Start (Now 1): " + ((root.answers && root.answers[0]) ? root.answers[0] : "...")
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption - 1
                    wrapMode: Text.WordWrap
                  }

                  Text {
                    width: parent.width
                    text: "• Now (Now 7): " + ((root.answers && root.answers[78]) ? root.answers[78] : "...")
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption - 1
                    wrapMode: Text.WordWrap
                  }

                  Text {
                    width: parent.width
                    text: "• Comparison (Step 80): " + ((root.answers && root.answers[79]) ? root.answers[79] : "...")
                    color: "#c4b5fd"
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption - 1
                    font.italic: true
                    wrapMode: Text.WordWrap
                    visible: (root.answers && root.answers[79]) ? true : false
                  }
                }
              }

            }
          }

          // Answer Input Area
          BorderSurface {
            width: parent.width
            implicitHeight: inputCol.implicitHeight + Style.space(20)
            color: Qt.rgba(root.background.r, root.background.g, root.background.b, 0.7)
            radius: Style.cornerRadius
            borderSpec: Border.flat(Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.3), 1)
            visible: root.currentStepIndex < root.flatSteps.length

            Column {
              id: inputCol
              width: parent.width - Style.space(20)
              anchors.centerIn: parent
              spacing: Style.space(8)

              Controls.TextArea {
                id: answerInput
                width: parent.width
                implicitHeight: Style.space(90)
                text: root.answerDraft
                placeholderText: "Describe your awareness, location, state, or insight..."
                placeholderTextColor: root.mutedColor
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                wrapMode: Controls.TextArea.Wrap
                background: null
                onTextChanged: root.answerDraft = text

                Keys.onReturnPressed: function(event) {
                  if (event.modifiers & Qt.ControlModifier || event.modifiers & Qt.ShiftModifier) {
                    root.advanceStep();
                    event.accepted = true;
                  }
                }
              }

              RowLayout {
                width: parent.width

                Text {
                  Layout.alignment: Qt.AlignVCenter
                  text: "Ctrl+Enter or Shift+Enter to advance"
                  color: root.mutedColor
                  font.family: root.fontFamily
                  font.pixelSize: Style.space(11)
                }

                Item { Layout.fillWidth: true }

                Button {
                  id: btnAdv
                  text: ProcessData.getButtonText(root.currentStepIndex, root.currentStepType)
                  accent: root.goldColor
                  bordered: true
                  onClicked: root.advanceStep()
                }
              }
            }
          }

          // Session Complete Card (Clean sidebar status when 81 inquiry steps complete)
          BorderSurface {
            width: parent.width
            implicitHeight: compCol.implicitHeight + Style.space(24)
            color: Qt.rgba(0.09, 0.05, 0.17, 0.95)
            radius: Style.cornerRadius
            borderSpec: Border.flat(root.goldColor, 1.5)
            visible: root.currentStepIndex >= root.flatSteps.length

            Column {
              id: compCol
              width: parent.width - Style.space(24)
              anchors.centerIn: parent
              spacing: Style.space(12)

              Row {
                width: parent.width
                Text {
                  text: "✨ Session Complete"
                  color: root.goldColor
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }
                Item { width: Math.max(Style.space(10), parent.width - Style.space(200)); height: 1 }
                Text {
                  text: "81 / 81 Steps"
                  color: "#10b981"
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption - 1
                  font.bold: true
                }
              }

              // Final emergent insight harvest display
              Rectangle {
                width: parent.width
                height: compInsCol.implicitHeight + Style.space(16)
                radius: Style.cornerRadius - 2
                color: Qt.rgba(root.goldColor.r, root.goldColor.g, root.goldColor.b, 0.08)
                border.width: 1
                border.color: Qt.rgba(root.goldColor.r, root.goldColor.g, root.goldColor.b, 0.3)

                Column {
                  id: compInsCol
                  width: parent.width - Style.space(16)
                  anchors.centerIn: parent
                  spacing: Style.space(4)

                  Text {
                    width: parent.width
                    text: "Emergent Insight:"
                    color: root.goldColor
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption - 2
                    font.bold: true
                  }

                  Text {
                    width: parent.width
                    text: {
                      var lastAns = (root.answers && root.answers[root.flatSteps.length - 1]) ? root.answers[root.flatSteps.length - 1] : ((root.answers && (root.answers[80] || root.answers[79])) ? (root.answers[80] || root.answers[79]) : "");
                      return lastAns ? lastAns : "Breakthrough insight recorded.";
                    }
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    wrapMode: Text.WordWrap
                  }
                }
              }

              // Open Metrics Modal Button
              Button {
                width: parent.width
                text: "✨ Calibrate Metrics Modal ★"
                accent: root.goldColor
                bordered: true
                onClicked: root.isFinishMetricsModalOpen = true
              }

              // View Session Report Button
              Button {
                width: parent.width
                text: "📋 View Session Report"
                accent: root.cyanColor
                bordered: true
                onClicked: {
                  root.saveFinalMetrics();
                  root.viewingSession = Database.loadSession(root.activeSessionId);
                  root.activeTab = "report";
                }
              }

              // New Session Button
              Button {
                width: parent.width
                text: "🌀 Start New Session"
                bordered: true
                onClicked: root.startNewSession()
              }
            }
          }
        }

        // =========================================================
        // ----------------- 2. ARCHIVE TAB ------------------------
        // =========================================================
        Column {
          width: parent.width
          spacing: Style.space(10)
          visible: root.activeTab === "archive"

          Text {
            text: "Personal Development History"
            color: root.cyanColor
            font.family: root.fontFamily
            font.pixelSize: Style.font.heading - 4
            font.bold: true
          }

          Text {
            width: parent.width
            text: "Review past psychological trajectories, breakthroughs, and emergent shifts."
            color: root.mutedColor
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }

          Repeater {
            model: root.historicalSessions

            delegate: BorderSurface {
              required property var modelData
              width: parent ? parent.width : 0
              implicitHeight: itemCol.implicitHeight + Style.space(16)
              color: Qt.rgba(root.background.r, root.background.g, root.background.b, 0.6)
              radius: Style.cornerRadius
              borderSpec: Border.flat(modelData.status === "completed" ? Qt.rgba(root.goldColor.r, root.goldColor.g, root.goldColor.b, 0.3) : Qt.rgba(root.cyanColor.r, root.cyanColor.g, root.cyanColor.b, 0.3), 1)

              Column {
                id: itemCol
                width: parent.width - Style.space(18)
                anchors.centerIn: parent
                spacing: Style.space(6)

                RowLayout {
                  width: parent.width

                  Text {
                    text: modelData.created_at ? modelData.created_at.replace("T", " ").substring(0, 16) : "Date"
                    color: root.mutedColor
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }

                  Rectangle {
                    height: Style.space(16)
                    width: stText.implicitWidth + Style.space(8)
                    radius: Style.space(8)
                    color: modelData.status === "completed" ? Qt.rgba(16/255, 185/255, 129/255, 0.2) : Qt.rgba(6/255, 182/255, 212/255, 0.2)
                    border.width: 1
                    border.color: modelData.status === "completed" ? "#10b981" : "#06b6d4"

                    Text {
                      id: stText
                      anchors.centerIn: parent
                      text: modelData.status === "completed" ? "COMPLETED" : "STEP " + (modelData.current_step + 1) + "/81"
                      color: modelData.status === "completed" ? "#10b981" : "#06b6d4"
                      font.pixelSize: Style.space(9)
                      font.bold: true
                    }
                  }

                  Item { Layout.fillWidth: true }

                  Row {
                    id: btnRow
                    spacing: Style.space(6)

                    Button {
                      text: modelData.status === "completed" ? "Report" : "Resume"
                      accent: modelData.status === "completed" ? root.goldColor : root.cyanColor
                      bordered: true
                      onClicked: {
                        var full = Database.loadSession(modelData.id);
                        if (modelData.status === "completed") {
                          root.openSessionReport(full);
                        } else {
                          root.resumeSession(full);
                        }
                      }
                    }

                    Button {
                      text: "✕"
                      accent: "#ef4444"
                      bordered: true
                      onClicked: {
                        Database.deleteSession(modelData.id);
                        root.refreshHistory();
                      }
                    }
                  }
                }

                Text {
                  width: parent.width
                  text: "Initial: " + (modelData.now_start || "...")
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.bold: true
                  elide: Text.ElideRight
                }

                Text {
                  width: parent.width
                  visible: !!modelData.final_insight
                  text: "Emergence: " + modelData.final_insight
                  color: root.goldColor
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.italic: true
                  elide: Text.ElideRight
                }
              }
            }
          }

          Item {
            width: parent.width
            implicitHeight: Style.space(40)
            visible: root.historicalSessions.length === 0

            Text {
              anchors.centerIn: parent
              text: "No previous sessions saved yet. Start your first journey above!"
              color: root.mutedColor
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }
        }

        // =========================================================
        // ----------------- 3. REPORT TAB -------------------------
        // =========================================================
        Column {
          id: panelReportCol
          width: parent.width
          spacing: Style.space(12)
          visible: root.activeTab === "report"

          property var targetSession: (visible && root.activeTab === "report") ? root.getResolvedReportSession() : null

          Text {
            text: "Session Review & Record"
            color: root.goldColor
            font.family: root.fontFamily
            font.pixelSize: Style.font.heading - 4
            font.bold: true
          }

          // Status message
          Text {
            width: parent.width
            visible: !!root.copyStatusMessage
            text: root.copyStatusMessage
            color: "#10b981"
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
          }

          // Action Toolbar (3 clean export buttons)
          Grid {
            width: parent.width
            columns: 2
            spacing: Style.space(8)

            Button {
              width: (parent.width - Style.space(8)) / 2
              text: "💾 Save to Docs"
              accent: root.cyanColor
              bordered: true
              onClicked: root.exportReportToFile()
            }

            Button {
              width: (parent.width - Style.space(8)) / 2
              text: "📄 Export PDF"
              accent: root.pastColor
              bordered: true
              onClicked: root.exportPdfToFile()
            }

            Button {
              width: parent.width
              text: "🐦 Share on X"
              accent: "#38bdf8"
              bordered: true
              onClicked: root.shareHighlightToX()
            }
          }

          // Highlight Card: The Difference
          BorderSurface {
            width: parent.width
            implicitHeight: diffCol.implicitHeight + Style.space(20)
            color: Qt.rgba(root.goldColor.r, root.goldColor.g, root.goldColor.b, 0.08)
            radius: Style.cornerRadius
            borderSpec: Border.flat(root.goldColor, 1.5)

            Column {
              id: diffCol
              width: parent.width - Style.space(20)
              anchors.centerIn: parent
              spacing: Style.space(8)

              Text {
                text: "✨ The Emergent Difference"
                color: root.goldColor
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }

              Text {
                width: parent.width
                text: {
                  var t = panelReportCol.targetSession;
                  return (t && t.final_insight) ? t.final_insight : (t && t.answers && t.answers[80] ? t.answers[80] : "Complete the final question to harvest the emergent shift.");
                }
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.bold: true
                lineHeight: 1.25
                wrapMode: Text.WordWrap
              }
            }
          }

          // Progress Made & Metric Shift Callout Card
          BorderSurface {
            width: parent.width
            implicitHeight: progCol.implicitHeight + Style.space(20)
            color: Qt.rgba(root.cyanColor.r, root.cyanColor.g, root.cyanColor.b, 0.08)
            radius: Style.cornerRadius
            borderSpec: Border.flat(root.cyanColor, 1.2)

            Column {
              id: progCol
              width: parent.width - Style.space(20)
              anchors.centerIn: parent
              spacing: Style.space(8)

              Row {
                width: parent.width
                Text {
                  text: "📈 Progress Made · Attentional & Cognitive Shift"
                  color: root.cyanColor
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }
              }

              Row {
                width: parent.width
                spacing: Style.space(12)

                // Clarity Block
                Rectangle {
                  width: (parent.width - Style.space(12)) / 2
                  height: Style.space(48)
                  radius: Style.cornerRadius - 2
                  color: Qt.rgba(root.background.r, root.background.g, root.background.b, 0.5)
                  border.width: 1
                  border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.1)

                  Row {
                    anchors.fill: parent
                    anchors.margins: Style.space(8)
                    spacing: Style.space(8)

                    Column {
                      width: parent.width - Style.space(70)
                      anchors.verticalCenter: parent.verticalCenter
                      Text {
                        text: "Clarity"
                        color: root.mutedColor
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 2
                        font.bold: true
                      }
                      Text {
                        property var s: panelReportCol.targetSession
                        property int preVal: s ? (s.pre_clarity !== undefined ? s.pre_clarity : 50) : 50
                        property int postVal: s ? (s.post_clarity !== undefined ? s.post_clarity : 50) : 50
                        text: preVal + "% → " + postVal + "%"
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: true
                      }
                    }

                    Rectangle {
                      anchors.verticalCenter: parent.verticalCenter
                      property var s: panelReportCol.targetSession
                      property int preVal: s ? (s.pre_clarity !== undefined ? s.pre_clarity : 50) : 50
                      property int postVal: s ? (s.post_clarity !== undefined ? s.post_clarity : 50) : 50
                      property int diff: postVal - preVal
                      width: Style.space(60)
                      height: Style.space(24)
                      radius: 4
                      color: diff > 0 ? Qt.rgba(16/255, 185/255, 129/255, 0.2) : (diff < 0 ? Qt.rgba(239/255, 68/255, 68/255, 0.2) : Qt.rgba(148/255, 163/255, 184/255, 0.15))
                      border.width: 1
                      border.color: diff > 0 ? "#10b981" : (diff < 0 ? "#ef4444" : "#64748b")

                      Text {
                        anchors.centerIn: parent
                        property var s: panelReportCol.targetSession
                        property int preVal: s ? (s.pre_clarity !== undefined ? s.pre_clarity : 50) : 50
                        property int postVal: s ? (s.post_clarity !== undefined ? s.post_clarity : 50) : 50
                        property int diff: postVal - preVal
                        text: (diff >= 0 ? "+" : "") + diff + "%"
                        color: diff > 0 ? "#10b981" : (diff < 0 ? "#ef4444" : root.mutedColor)
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 1
                        font.bold: true
                      }
                    }
                  }
                }

                // Movement Block
                Rectangle {
                  width: (parent.width - Style.space(12)) / 2
                  height: Style.space(48)
                  radius: Style.cornerRadius - 2
                  color: Qt.rgba(root.background.r, root.background.g, root.background.b, 0.5)
                  border.width: 1
                  border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.1)

                  Row {
                    anchors.fill: parent
                    anchors.margins: Style.space(8)
                    spacing: Style.space(8)

                    Column {
                      width: parent.width - Style.space(70)
                      anchors.verticalCenter: parent.verticalCenter
                      Text {
                        text: "Movement"
                        color: root.mutedColor
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 2
                        font.bold: true
                      }
                      Text {
                        property var s: panelReportCol.targetSession
                        property int preVal: s ? (s.pre_movement !== undefined ? s.pre_movement : (s.pre_focus || 50)) : 50
                        property int postVal: s ? (s.post_movement !== undefined ? s.post_movement : (s.post_focus || 50)) : 50
                        text: preVal + "% → " + postVal + "%"
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: true
                      }
                    }

                    Rectangle {
                      anchors.verticalCenter: parent.verticalCenter
                      property var s: panelReportCol.targetSession
                      property int preVal: s ? (s.pre_movement !== undefined ? s.pre_movement : (s.pre_focus || 50)) : 50
                      property int postVal: s ? (s.post_movement !== undefined ? s.post_movement : (s.post_focus || 50)) : 50
                      property int diff: postVal - preVal
                      width: Style.space(60)
                      height: Style.space(24)
                      radius: 4
                      color: diff > 0 ? Qt.rgba(16/255, 185/255, 129/255, 0.2) : (diff < 0 ? Qt.rgba(239/255, 68/255, 68/255, 0.2) : Qt.rgba(148/255, 163/255, 184/255, 0.15))
                      border.width: 1
                      border.color: diff > 0 ? "#10b981" : (diff < 0 ? "#ef4444" : "#64748b")

                      Text {
                        anchors.centerIn: parent
                        property var s: panelReportCol.targetSession
                        property int preVal: s ? (s.pre_movement !== undefined ? s.pre_movement : (s.pre_focus || 50)) : 50
                        property int postVal: s ? (s.post_movement !== undefined ? s.post_movement : (s.post_focus || 50)) : 50
                        property int diff: postVal - preVal
                        text: (diff >= 0 ? "+" : "") + diff + "%"
                        color: diff > 0 ? "#10b981" : (diff < 0 ? "#ef4444" : root.mutedColor)
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 1
                        font.bold: true
                      }
                    }
                  }
                }
              }
            }
          }

          // Full Markdown Transcript Preview
          BorderSurface {
            width: parent.width
            implicitHeight: Math.min(Style.space(350), repText.implicitHeight + Style.space(20))
            color: Qt.rgba(root.background.r, root.background.g, root.background.b, 0.7)
            radius: Style.cornerRadius
            borderSpec: Border.flat(Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.15), 1)

            Controls.ScrollView {
              anchors.fill: parent
              anchors.margins: Style.space(10)
              clip: true

              Text {
                id: repText
                width: parent.width
                text: {
                  var target = panelReportCol.targetSession;
                  return Report.generateMarkdownReport(target, root.flatSteps, ProcessData.questionLibrary);
                }
                color: root.foreground
                textFormat: Text.MarkdownText
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                lineHeight: 1.3
                wrapMode: Text.WordWrap
              }
            }
          }
        }

        // =========================================================
        // ----------------- 4. LORE TAB ---------------------------
        // =========================================================
        BorderSurface {
          width: parent.width
          visible: root.activeTab === "lore"
          implicitHeight: loreCol.implicitHeight + Style.space(24)
          color: Qt.rgba(root.pastColor.r, root.pastColor.g, root.pastColor.b, 0.06)
          radius: Style.cornerRadius
          borderSpec: Border.flat(Qt.rgba(root.pastColor.r, root.pastColor.g, root.pastColor.b, 0.25), 1)

          Column {
            id: loreCol
            width: parent.width - Style.space(24)
            anchors.centerIn: parent
            spacing: Style.space(12)

            Text {
              text: "🌌 Origin, Emergent Knowledge & Process #4"
              color: root.cyanColor
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: true
            }

            Text {
              width: parent.width
              text: "• Process #4 — The Eternal Moment of Now:\nAdapted from Universal Conscious Practice by K. Penday and grounded in David Grove's Emergent Knowledge cosmology.\n\n• The Power of Six & Iterative Geometry:\nRather than seeking immediate solutions, Process #4 gently oscillates awareness between the current state of 'Now', memories of the Past, and projections of the Future. After six comparative iterations, a new 'Now' is naturally recognized.\n\n• Clean Space & Non-Interference:\nThe facilitator asks minimal, unpolluted Clean Language questions. By allowing the client to compare space-time coordinates without external interpretation, the mind self-organizes.\n\n• The Final Emergence:\nAcross 6 developmental Sets, the internal topography shifts. The closing question captures this non-linear leap: 'And, what is the difference between what you knew at the start and what you know now?'"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              lineHeight: 1.25
              wrapMode: Text.WordWrap
            }

            Button {
              width: parent.width
              text: "← Return to Chamber"
              accent: root.cyanColor
              bordered: true
              onClicked: root.activeTab = "chamber"
            }
          }
        }

      }
    }

    // -------------------------------------------------------------
    // QUICK CHECK-IN MODAL OVERLAY (Ekology Metric Calibration)
    // -------------------------------------------------------------
    Rectangle {
      id: quickCheckinModalOverlay
      anchors.fill: parent
      z: 9998
      visible: root.isCheckinModalOpen
      color: Qt.rgba(root.background.r, root.background.g, root.background.b, 0.95)

      MouseArea {
        anchors.fill: parent
        // block clicks behind modal
      }

      BorderSurface {
        anchors.centerIn: parent
        width: Math.min(Style.space(440), parent.width - Style.space(24))
        implicitHeight: checkinCol.implicitHeight + Style.space(36)
        radius: Style.cornerRadius
        color: root.background
        borderSpec: Border.flat(Qt.rgba(root.cyanColor.r, root.cyanColor.g, root.cyanColor.b, 0.4), 1.5)

        Column {
          id: checkinCol
          width: parent.width - Style.space(32)
          anchors.centerIn: parent
          spacing: Style.space(16)

          // Header
          Column {
            width: parent.width
            spacing: Style.space(4)

            Row {
              spacing: Style.space(8)
              Text { text: "🎯"; font.pixelSize: Style.space(20) }
              Text {
                text: "Quick Check-in"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.heading - 2
                font.bold: true
              }
            }

            Text {
              width: parent.width
              text: "Take a moment to notice where you are right now."
              color: root.mutedColor
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
          }

          Rectangle { width: parent.width; height: 1; color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.1) }

          // Clarity Slider Group (Foggy -> Clear)
          Column {
            width: parent.width
            spacing: Style.space(6)

            Text {
              text: "Clarity"
              color: root.cyanColor
              font.family: root.fontFamily
              font.bold: true
              font.pixelSize: Style.font.caption
            }

            Row {
              width: parent.width
              spacing: Style.space(8)

              Text {
                text: "Foggy"
                color: root.mutedColor
                font.family: root.fontFamily
                font.italic: true
                font.pixelSize: Style.space(11)
                width: Style.space(44)
              }

              Controls.Slider {
                width: parent.width - Style.space(100)
                from: 0
                to: 100
                stepSize: 1
                value: root.preClarity
                onValueChanged: {
                  root.preClarity = Math.round(value);
                  if (root.currentStepIndex === 0) root.postClarity = root.preClarity;
                }
              }

              Text {
                text: "Clear"
                color: root.mutedColor
                font.family: root.fontFamily
                font.italic: true
                font.pixelSize: Style.space(11)
                horizontalAlignment: Text.AlignRight
                width: Style.space(44)
              }
            }
          }

          // Movement Slider Group (Stuck -> Flowing)
          Column {
            width: parent.width
            spacing: Style.space(6)

            Text {
              text: "Movement"
              color: root.cyanColor
              font.family: root.fontFamily
              font.bold: true
              font.pixelSize: Style.font.caption
            }

            Row {
              width: parent.width
              spacing: Style.space(8)

              Text {
                text: "Stuck"
                color: root.mutedColor
                font.family: root.fontFamily
                font.italic: true
                font.pixelSize: Style.space(11)
                width: Style.space(44)
              }

              Controls.Slider {
                width: parent.width - Style.space(100)
                from: 0
                to: 100
                stepSize: 1
                value: root.preMovement
                onValueChanged: {
                  root.preMovement = Math.round(value);
                  root.preFocus = root.preMovement;
                  if (root.currentStepIndex === 0) {
                    root.postMovement = root.preMovement;
                    root.postFocus = root.preMovement;
                  }
                }
              }

              Text {
                text: "Flowing"
                color: root.mutedColor
                font.family: root.fontFamily
                font.italic: true
                font.pixelSize: Style.space(11)
                horizontalAlignment: Text.AlignRight
                width: Style.space(44)
              }
            }
          }

          Item { height: Style.space(4); width: 1 }

          // Begin Session Button
          Button {
            width: parent.width
            text: "Begin Session →"
            accent: root.goldColor
            bordered: true
            onClicked: {
              root.isCheckinModalOpen = false;
              root.saveFinalMetrics();
            }
          }
        }
      }
    }

    // -------------------------------------------------------------
    // FINISHING THE METRICS MODAL OVERLAY
    // -------------------------------------------------------------
    Rectangle {
      id: finishMetricsModalOverlay
      anchors.fill: parent
      z: 9998
      visible: root.isFinishMetricsModalOpen
      color: Qt.rgba(root.background.r, root.background.g, root.background.b, 0.95)

      MouseArea {
        anchors.fill: parent
        // block clicks behind modal
      }

      BorderSurface {
        anchors.centerIn: parent
        width: Math.min(Style.space(460), parent.width - Style.space(24))
        implicitHeight: modalFinishCol.implicitHeight + Style.space(36)
        radius: Style.cornerRadius
        color: root.background
        borderSpec: Border.flat(Qt.rgba(root.goldColor.r, root.goldColor.g, root.goldColor.b, 0.6), 1.5)

        Column {
          id: modalFinishCol
          width: parent.width - Style.space(32)
          anchors.centerIn: parent
          spacing: Style.space(16)

          // Header
          Row {
            width: parent.width
            spacing: Style.space(8)

            Text { text: "✨"; font.pixelSize: Style.space(20) }

            Column {
              width: parent.width - Style.space(60)
              spacing: Style.space(2)

              Text {
                text: "Finishing The Metrics"
                color: root.goldColor
                font.family: root.fontFamily
                font.pixelSize: Style.font.heading - 2
                font.bold: true
              }

              Text {
                text: "Session Complete · All 81 steps integrated"
                color: "#10b981"
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 1
                font.bold: true
              }
            }

            Rectangle {
              width: Style.space(24)
              height: Style.space(24)
              radius: Style.space(12)
              color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)

              Text {
                anchors.centerIn: parent
                text: "✕"
                color: root.mutedColor
                font.pixelSize: Style.font.caption - 2
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.isFinishMetricsModalOpen = false
              }
            }
          }

          Rectangle { width: parent.width; height: 1; color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.1) }

          // Emergent Insight Harvest Card
          Rectangle {
            width: parent.width
            height: modalInsTextCol.implicitHeight + Style.space(16)
            radius: Style.cornerRadius - 2
            color: Qt.rgba(root.goldColor.r, root.goldColor.g, root.goldColor.b, 0.08)
            border.width: 1
            border.color: Qt.rgba(root.goldColor.r, root.goldColor.g, root.goldColor.b, 0.3)

            Column {
              id: modalInsTextCol
              width: parent.width - Style.space(16)
              anchors.centerIn: parent
              spacing: Style.space(4)

              Text {
                width: parent.width
                text: "And, what is the difference between what you knew at the start and what you know now?"
                color: root.mutedColor
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 2
                font.italic: true
                wrapMode: Text.WordWrap
              }

              Text {
                width: parent.width
                text: {
                  var lastAns = (root.answers && root.answers[root.flatSteps.length - 1]) ? root.answers[root.flatSteps.length - 1] : ((root.answers && (root.answers[80] || root.answers[79])) ? (root.answers[80] || root.answers[79]) : "");
                  return lastAns ? lastAns : "Breakthrough insight recorded.";
                }
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                wrapMode: Text.WordWrap
              }
            }
          }

          // Clarity Slider Group (Foggy -> Clear) with Ghost Mark of Session Start
          Column {
            width: parent.width
            spacing: Style.space(6)

            Row {
              width: parent.width

              Text {
                text: "Clarity"
                color: root.cyanColor
                font.family: root.fontFamily
                font.bold: true
                font.pixelSize: Style.font.caption
              }

              Item { width: Math.max(Style.space(10), parent.width - Style.space(160)); height: 1 }

              Row {
                spacing: Style.space(4)
                Rectangle {
                  width: Style.space(8)
                  height: Style.space(8)
                  radius: Style.space(4)
                  color: Qt.rgba(root.cyanColor.r, root.cyanColor.g, root.cyanColor.b, 0.25)
                  border.width: 1.5
                  border.color: root.cyanColor
                  anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                  text: "Start: " + root.preClarity + "%"
                  color: root.mutedColor
                  font.family: root.fontFamily
                  font.pixelSize: Style.space(10)
                  font.italic: true
                  anchors.verticalCenter: parent.verticalCenter
                }
              }
            }

            Row {
              width: parent.width
              spacing: Style.space(8)

              Text {
                text: "Foggy"
                color: root.mutedColor
                font.family: root.fontFamily
                font.italic: true
                font.pixelSize: Style.space(11)
                width: Style.space(44)
              }

              Item {
                width: parent.width - Style.space(100)
                height: clarityPostSlider.implicitHeight || Style.space(28)

                Controls.Slider {
                  id: clarityPostSlider
                  anchors.fill: parent
                  from: 0
                  to: 100
                  stepSize: 1
                  value: root.postClarity
                  onMoved: {
                    root.postClarity = Math.round(value);
                    root.saveFinalMetrics();
                  }
                }

                // Ghost Mark (Session Start Position)
                Item {
                  id: ghostMarkClarity
                  property real hw: (clarityPostSlider.handle ? clarityPostSlider.handle.width : Style.space(14))
                  property real hh: (clarityPostSlider.handle ? clarityPostSlider.handle.height : Style.space(14))
                  width: hw
                  height: hh
                  anchors.verticalCenter: clarityPostSlider.verticalCenter
                  x: Math.round(clarityPostSlider.leftPadding + (root.preClarity / 100.0) * (clarityPostSlider.availableWidth - hw))
                  enabled: false
                  z: 0

                  Rectangle {
                    width: 2
                    height: parent.height + Style.space(8)
                    radius: 1
                    anchors.centerIn: parent
                    color: Qt.rgba(root.cyanColor.r, root.cyanColor.g, root.cyanColor.b, 0.6)
                  }

                  Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Qt.rgba(root.cyanColor.r, root.cyanColor.g, root.cyanColor.b, 0.2)
                    border.width: 1.5
                    border.color: root.cyanColor
                  }
                }
              }

              Text {
                text: "Clear"
                color: root.mutedColor
                font.family: root.fontFamily
                font.italic: true
                font.pixelSize: Style.space(11)
                horizontalAlignment: Text.AlignRight
                width: Style.space(44)
              }
            }
          }

          // Movement Slider Group (Stuck -> Flowing) with Ghost Mark of Session Start
          Column {
            width: parent.width
            spacing: Style.space(6)

            Row {
              width: parent.width

              Text {
                text: "Movement"
                color: root.cyanColor
                font.family: root.fontFamily
                font.bold: true
                font.pixelSize: Style.font.caption
              }

              Item { width: Math.max(Style.space(10), parent.width - Style.space(160)); height: 1 }

              Row {
                spacing: Style.space(4)
                Rectangle {
                  width: Style.space(8)
                  height: Style.space(8)
                  radius: Style.space(4)
                  color: Qt.rgba(root.cyanColor.r, root.cyanColor.g, root.cyanColor.b, 0.25)
                  border.width: 1.5
                  border.color: root.cyanColor
                  anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                  text: "Start: " + root.preMovement + "%"
                  color: root.mutedColor
                  font.family: root.fontFamily
                  font.pixelSize: Style.space(10)
                  font.italic: true
                  anchors.verticalCenter: parent.verticalCenter
                }
              }
            }

            Row {
              width: parent.width
              spacing: Style.space(8)

              Text {
                text: "Stuck"
                color: root.mutedColor
                font.family: root.fontFamily
                font.italic: true
                font.pixelSize: Style.space(11)
                width: Style.space(44)
              }

              Item {
                width: parent.width - Style.space(100)
                height: movementPostSlider.implicitHeight || Style.space(28)

                Controls.Slider {
                  id: movementPostSlider
                  anchors.fill: parent
                  from: 0
                  to: 100
                  stepSize: 1
                  value: root.postMovement
                  onMoved: {
                    root.postMovement = Math.round(value);
                    root.postFocus = root.postMovement;
                    root.saveFinalMetrics();
                  }
                }

                // Ghost Mark (Session Start Position)
                Item {
                  id: ghostMarkMovement
                  property real hw: (movementPostSlider.handle ? movementPostSlider.handle.width : Style.space(14))
                  property real hh: (movementPostSlider.handle ? movementPostSlider.handle.height : Style.space(14))
                  width: hw
                  height: hh
                  anchors.verticalCenter: movementPostSlider.verticalCenter
                  x: Math.round(movementPostSlider.leftPadding + (root.preMovement / 100.0) * (movementPostSlider.availableWidth - hw))
                  enabled: false
                  z: 0

                  Rectangle {
                    width: 2
                    height: parent.height + Style.space(8)
                    radius: 1
                    anchors.centerIn: parent
                    color: Qt.rgba(root.cyanColor.r, root.cyanColor.g, root.cyanColor.b, 0.6)
                  }

                  Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Qt.rgba(root.cyanColor.r, root.cyanColor.g, root.cyanColor.b, 0.2)
                    border.width: 1.5
                    border.color: root.cyanColor
                  }
                }
              }

              Text {
                text: "Flowing"
                color: root.mutedColor
                font.family: root.fontFamily
                font.italic: true
                font.pixelSize: Style.space(11)
                horizontalAlignment: Text.AlignRight
                width: Style.space(44)
              }
            }
          }

          Item { height: Style.space(4); width: 1 }

          // Action Buttons
          Row {
            width: parent.width
            spacing: Style.space(10)

            Button {
              width: parent.width - Style.space(130)
              text: "📋 View Session Report ★"
              accent: root.goldColor
              bordered: true
              onClicked: {
                root.isFinishMetricsModalOpen = false;
                root.saveFinalMetrics();
                root.viewingSession = Database.loadSession(root.activeSessionId);
                root.activeTab = "report";
              }
            }

            Button {
              width: Style.space(120)
              text: "🌀 New Session"
              accent: root.cyanColor
              bordered: true
              onClicked: {
                root.isFinishMetricsModalOpen = false;
                root.startNewSession();
              }
            }
          }
        }
      }
    }
  }
}
