import QtQuick
import QtQuick.Controls as Controls
import QtCore
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "ProcessData.js" as ProcessData
import "Database.js" as Database
import "Report.js" as Report

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
  property int preClarity: 5
  property int preFocus: 5
  property int postClarity: 5
  property int postFocus: 5
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
    activeSessionId = 0;
    sessionUuid = Database.generateUUID();
    currentStepIndex = 0;
    answers = new Array(flatSteps.length).fill("");
    preClarity = 5;
    preFocus = 5;
    postClarity = 5;
    postFocus = 5;
    selectedTags = [];
    sessionFeedback = "";
    copyStatusMessage = "";
    answerDraft = "";
    activeTab = "chamber";
    viewingSession = null;

    // Persist draft
    var s = {
      uuid: sessionUuid,
      status: "in_progress",
      current_step: 0,
      pre_clarity: preClarity,
      pre_focus: preFocus,
      answers: answers
    };
    activeSessionId = Database.saveSession(s);
    refreshHistory();
  }

  function resumeSession(session) {
    if (!session) return;
    activeSessionId = session.id;
    sessionUuid = session.uuid;
    currentStepIndex = session.current_step || 0;
    answers = session.answers || new Array(flatSteps.length).fill("");
    preClarity = session.pre_clarity || 5;
    preFocus = session.pre_focus || 5;
    postClarity = session.post_clarity || 5;
    postFocus = session.post_focus || 5;
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

  function advanceStep() {
    if (currentStepIndex >= flatSteps.length) return;

    var updated = [];
    for (var i = 0; i < answers.length; i++) updated.push(answers[i]);
    updated[currentStepIndex] = answerDraft.trim();
    answers = updated;

    currentStepIndex++;

    // Auto-save progress
    var s = {
      id: activeSessionId,
      uuid: sessionUuid,
      status: (currentStepIndex >= flatSteps.length ? "completed" : "in_progress"),
      current_step: currentStepIndex,
      pre_clarity: preClarity,
      pre_focus: preFocus,
      post_clarity: postClarity,
      post_focus: postFocus,
      tags: selectedTags,
      feedback: sessionFeedback,
      answers: answers
    };
    activeSessionId = Database.saveSession(s);
    refreshHistory();

    answerDraft = (currentStepIndex < flatSteps.length && answers[currentStepIndex]) ? answers[currentStepIndex] : "";

    if (currentStepIndex >= flatSteps.length) {
      viewingSession = Database.loadSession(activeSessionId);
      activeTab = "report";
    }
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

  function copyReportText() {
    var target = viewingSession || Database.loadSession(activeSessionId);
    if (!target) return;
    var md = Report.generateMarkdownReport(target, flatSteps, ProcessData.questionLibrary);
    Quickshell.execDetached(["bash", "-c", "printf %s " + Util.shellQuote(md) + " | wl-copy"]);
    copyStatusMessage = "Report copied to clipboard!";
  }

  function exportReportToFile() {
    var target = viewingSession || Database.loadSession(activeSessionId);
    if (!target) return;
    var md = Report.generateMarkdownReport(target, flatSteps, ProcessData.questionLibrary);
    var d = new Date();
    var ts = d.getFullYear() + "" + String(d.getMonth() + 1).padStart(2, '0') + "" + String(d.getDate()).padStart(2, '0') + "_" + String(d.getHours()).padStart(2, '0') + "" + String(d.getMinutes()).padStart(2, '0');
    var filename = "Process4_EternalMoment_" + ts + ".md";
    var docsLoc = String(StandardPaths.writableLocation(StandardPaths.DocumentsLocation)).replace(/^file:\/\//, "");
    if (!docsLoc || docsLoc === "undefined") {
      docsLoc = String(StandardPaths.writableLocation(StandardPaths.HomeLocation)).replace(/^file:\/\//, "") + "/Documents";
    }
    var targetPath = docsLoc + "/" + filename;
    var cmd = "mkdir -p '" + docsLoc.replace(/'/g, "'\\''") + "' && cat << 'EOF' > '" + targetPath.replace(/'/g, "'\\''") + "'\n" + md + "\nEOF";
    Quickshell.execDetached(["bash", "-c", cmd]);
    copyStatusMessage = "Saved to " + targetPath;
  }

  function shareHighlightToX() {
    var target = viewingSession || Database.loadSession(activeSessionId);
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
                text: "Set " + root.currentSet + " / 6"
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
                  width: parent.width * Math.min(1.0, (root.currentStepIndex + 1) / Math.max(1, root.flatSteps.length))
                  color: root.goldColor
                }
              }

              Item { width: Style.space(10); height: 1 }

              Text {
                text: "Step " + (root.currentStepIndex + 1) + " / " + root.flatSteps.length
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
                  text: "💡 Notice the subtle resonance, similarities, or contrasts between these two internal reference points."
                  color: root.mutedColor
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  wrapMode: Text.WordWrap
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

              Row {
                width: parent.width

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: "Ctrl+Enter or Shift+Enter to advance"
                  color: root.mutedColor
                  font.family: root.fontFamily
                  font.pixelSize: Style.space(11)
                }

                Item { Layout.fillWidth: true; height: 1; width: parent.width - btnAdv.implicitWidth - Style.space(220) }

                Button {
                  id: btnAdv
                  text: (root.currentStepIndex + 1 >= root.flatSteps.length ? "Complete Session ★" : "Reflect & Next →")
                  accent: root.goldColor
                  bordered: true
                  onClicked: root.advanceStep()
                }
              }
            }
          }

          // Pre-metrics calibration (Collapsible card during Step 0)
          BorderSurface {
            width: parent.width
            visible: root.currentStepIndex === 0
            implicitHeight: calibCol.implicitHeight + Style.space(18)
            color: Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.05)
            radius: Style.cornerRadius
            borderSpec: Border.flat(Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 0.2), 1)

            Column {
              id: calibCol
              width: parent.width - Style.space(20)
              anchors.centerIn: parent
              spacing: Style.space(8)

              Text {
                text: "🎯 Pre-Session Calibration"
                color: root.accentColor
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }

              Row {
                width: parent.width
                spacing: Style.space(8)

                Text {
                  width: Style.space(90)
                  anchors.verticalCenter: parent.verticalCenter
                  text: "Clarity: " + root.preClarity + "/10"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }

                Controls.Slider {
                  width: parent.width - Style.space(100)
                  from: 1
                  to: 10
                  stepSize: 1
                  value: root.preClarity
                  onValueChanged: root.preClarity = Math.round(value)
                }
              }

              Row {
                width: parent.width
                spacing: Style.space(8)

                Text {
                  width: Style.space(90)
                  anchors.verticalCenter: parent.verticalCenter
                  text: "Focus: " + root.preFocus + "/10"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }

                Controls.Slider {
                  width: parent.width - Style.space(100)
                  from: 1
                  to: 10
                  stepSize: 1
                  value: root.preFocus
                  onValueChanged: root.preFocus = Math.round(value)
                }
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

                Row {
                  width: parent.width

                  Text {
                    text: modelData.created_at ? modelData.created_at.replace("T", " ").substring(0, 16) : "Date"
                    color: root.mutedColor
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }

                  Item { width: Style.space(10); height: 1 }

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

                  Item { Layout.fillWidth: true; height: 1; width: parent.width - btnRow.implicitWidth - Style.space(180) }

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
                  text: "Initial: \"" + (modelData.now_start || "...") + "\""
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.bold: true
                  elide: Text.ElideRight
                }

                Text {
                  width: parent.width
                  visible: !!modelData.final_insight
                  text: "Emergence: \"" + modelData.final_insight + "\""
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
          width: parent.width
          spacing: Style.space(12)
          visible: root.activeTab === "report"

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

          // Action Toolbar
          Row {
            width: parent.width
            spacing: Style.space(8)

            Button {
              width: (parent.width - Style.space(16)) / 3
              text: "📋 Copy Markdown"
              accent: root.goldColor
              bordered: true
              onClicked: root.copyReportText()
            }

            Button {
              width: (parent.width - Style.space(16)) / 3
              text: "💾 Save to Docs"
              accent: root.cyanColor
              bordered: true
              onClicked: root.exportReportToFile()
            }

            Button {
              width: (parent.width - Style.space(16)) / 3
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
                  var t = root.viewingSession || Database.loadSession(root.activeSessionId);
                  return (t && t.final_insight) ? ("\"" + t.final_insight + "\"") : (t && t.answers && t.answers[80] ? ("\"" + t.answers[80] + "\"") : "Complete the final question to harvest the emergent shift.");
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
                  var target = root.viewingSession || Database.loadSession(root.activeSessionId);
                  return Report.generateMarkdownReport(target, root.flatSteps, ProcessData.questionLibrary);
                }
                color: root.foreground
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
  }
}
