import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtCore
import "ProcessData.js" as ProcessData
import "Database.js" as Database
import "Report.js" as Report
import "SpiralEngine.js" as SpiralEngine

ApplicationWindow {
    id: appWindow

    visible: true
    width: 1280
    height: 860
    minimumWidth: 1000
    minimumHeight: 700
    title: "The Eternal Moment: Process #4 · Emergent Knowledge"
    color: "#020617"

    // State properties
    property string activeTab: "chamber" // "chamber", "archive", "report", "manual"
    property int activeSessionId: 0
    property string sessionUuid: ""
    property int currentStepIndex: 0
    property var flatSteps: []
    property var answers: []
    property int preClarity: 5
    property int preMovement: 5
    property int preFocus: preMovement
    property int postClarity: 5
    property int postMovement: 5
    property int postFocus: postMovement
    property bool isCheckinModalOpen: false
    property var selectedTags: []
    property string sessionFeedback: ""
    property string copyStatusMessage: ""
    property var historicalSessions: []
    property var viewingSession: null
    property string answerDraft: ""
    property bool isFullscreen: false
    property bool isSidebarOpen: true

    property bool shareModalVisible: false
    property string sharePreviewPath: ""
    property string sharePreviewUrl: ""
    property string shareCaption: ""
    property string canvasToastMessage: ""

    Timer {
        id: canvasToastTimer
        interval: 4000
        repeat: false
        onTriggered: canvasToastMessage = ""
    }

    readonly property var currentStep: (flatSteps && currentStepIndex >= 0 && currentStepIndex < flatSteps.length) ? flatSteps[currentStepIndex] : null
    readonly property int currentSet: currentStep ? currentStep.set : 1
    readonly property string currentQuestionText: currentStep ? ProcessData.formatQuestionText(currentStep, answers, flatSteps) : "Session Complete"
    readonly property string currentStepType: currentStep ? currentStep.key : ""

    // Theme Palette
    readonly property color colBg: "#020617"
    readonly property color colCardBg: "#090d1f"
    readonly property color colSidebarBg: "#060919"
    readonly property color colForeground: "#f8fafc"
    readonly property color colMuted: "#94a3b8"
    readonly property color colPast: "#3b82f6"
    readonly property color colFuture: "#d946ef"
    readonly property color colGold: "#f59e0b"
    readonly property color colCyan: "#06b6d4"
    readonly property color colBorder: "#1e293b"

    Component.onCompleted: {
        Database.initDb();
        flatSteps = ProcessData.buildFlatSteps();
        refreshHistory();
        if (historicalSessions.length === 0) {
            startNewSession();
        } else {
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
        preMovement = 5;
        preFocus = 5;
        postClarity = 5;
        postMovement = 5;
        postFocus = 5;
        selectedTags = [];
        sessionFeedback = "";
        copyStatusMessage = "";
        answerDraft = "";
        activeTab = "chamber";
        viewingSession = null;

        var s = {
            uuid: sessionUuid,
            status: "in_progress",
            current_step: 0,
            pre_clarity: preClarity,
            pre_movement: preMovement,
            pre_focus: preMovement,
            answers: answers
        };
        activeSessionId = Database.saveSession(s);
        SpiralEngine.rebuildFromSession(flatSteps, answers, 0, false);
        refreshHistory();
        isCheckinModalOpen = true;
    }

    function resumeSession(session) {
        if (!session) return;
        activeSessionId = session.id;
        sessionUuid = session.uuid;
        currentStepIndex = session.current_step || 0;
        answers = session.answers || new Array(flatSteps.length).fill("");
        preClarity = session.pre_clarity || 5;
        preMovement = session.pre_movement !== undefined ? session.pre_movement : (session.pre_focus || 5);
        preFocus = preMovement;
        postClarity = session.post_clarity || 5;
        postMovement = session.post_movement !== undefined ? session.post_movement : (session.post_focus || 5);
        postFocus = postMovement;
        selectedTags = session.tags || [];
        sessionFeedback = session.feedback || "";
        answerDraft = (answers && answers[currentStepIndex]) ? answers[currentStepIndex] : "";
        copyStatusMessage = "";
        viewingSession = null;
        activeTab = "chamber";
        SpiralEngine.rebuildFromSession(flatSteps, answers, currentStepIndex);
    }

    function openSessionReport(session) {
        viewingSession = session;
        copyStatusMessage = "";
        activeTab = "report";
        if (session && session.answers) {
            SpiralEngine.rebuildFromSession(flatSteps, session.answers, (session.answers ? session.answers.length - 1 : 0));
        }
    }

    function saveFinalMetrics() {
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
            viewingSession = Database.loadSession(activeSessionId);
            activeTab = "report";
            return;
        }

        var updated = [];
        for (var i = 0; i < answers.length; i++) updated.push(answers[i]);
        updated[currentStepIndex] = answerDraft.trim();
        answers = updated;

        currentStepIndex++;

        var isDone = currentStepIndex >= flatSteps.length;
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
        SpiralEngine.rebuildFromSession(flatSteps, answers, Math.min(currentStepIndex, flatSteps.length - 1));
        refreshHistory();

        answerDraft = (currentStepIndex < flatSteps.length && answers[currentStepIndex]) ? answers[currentStepIndex] : "";
    }

    function toggleFullscreen() {
        isFullscreen = !isFullscreen;
        if (isFullscreen) {
            appWindow.showFullScreen();
        } else {
            appWindow.showNormal();
        }
    }

    function toggleSidebar() {
        isSidebarOpen = !isSidebarOpen;
    }

    function executeShellCommand(cmd) {
        try {
            var proc = Qt.createQmlObject('import Quickshell.Io; Process {}', appWindow, "shellProc_" + Date.now());
            proc.command = ["bash", "-c", cmd];
            proc.running = true;
            return true;
        } catch (e1) {
            try {
                var proc2 = Qt.createQmlObject('import Quickshell.Io 1.0; Process {}', appWindow, "shellProc_" + Date.now());
                proc2.command = ["bash", "-c", cmd];
                proc2.running = true;
                return true;
            } catch (e2) {
                console.warn("Process not available in this environment:", e1);
                return false;
            }
        }
    }

    function showCanvasToast(msg) {
        canvasToastMessage = msg;
        copyStatusMessage = msg;
        canvasToastTimer.restart();
    }

    function copyReportToClipboard() {
        var target = viewingSession || Database.loadSession(activeSessionId);
        if (!target) return;
        var md = Report.generateMarkdownReport(target, flatSteps, ProcessData.questionLibrary);
        executeShellCommand("printf %s " + escapeShell(md) + " | wl-copy || printf %s " + escapeShell(md) + " | xclip -selection clipboard");
        showCanvasToast("Full report copied to clipboard!");
    }

    function getPicturesDirectory() {
        var loc = String(StandardPaths.writableLocation(StandardPaths.PicturesLocation)).replace(/^file:\/\//, "");
        if (!loc || loc === "undefined") {
            loc = String(StandardPaths.writableLocation(StandardPaths.HomeLocation)).replace(/^file:\/\//, "") + "/Pictures";
        }
        return loc + "/TheEternalMoment";
    }

    function getDocumentsDirectory() {
        var loc = String(StandardPaths.writableLocation(StandardPaths.DocumentsLocation)).replace(/^file:\/\//, "");
        if (!loc || loc === "undefined") {
            loc = String(StandardPaths.writableLocation(StandardPaths.HomeLocation)).replace(/^file:\/\//, "") + "/Documents";
        }
        return loc;
    }

    function exportReportToFile() {
        var target = viewingSession || Database.loadSession(activeSessionId);
        if (!target) return;
        var md = Report.generateMarkdownReport(target, flatSteps, ProcessData.questionLibrary);
        var d = new Date();
        var ts = d.getFullYear() + "" + String(d.getMonth() + 1).padStart(2, '0') + "" + String(d.getDate()).padStart(2, '0') + "_" + String(d.getHours()).padStart(2, '0') + "" + String(d.getMinutes()).padStart(2, '0');
        var filename = "Process4_EternalMoment_" + ts + ".md";
        var docsDir = getDocumentsDirectory();
        executeShellCommand("mkdir -p " + escapeShell(docsDir) + " && cat << 'EOF' > " + escapeShell(docsDir + "/" + filename) + "\n" + md + "\nEOF");
        showCanvasToast("Report saved to " + filename);
    }

    function captureSpiralSnapshot(callback) {
        var dir = getPicturesDirectory();
        executeShellCommand("mkdir -p " + escapeShell(dir));

        var d = new Date();
        var dateStr = d.getFullYear() + "" + String(d.getMonth() + 1).padStart(2, '0') + "" + String(d.getDate()).padStart(2, '0') + "_" + String(d.getHours()).padStart(2, '0') + "" + String(d.getMinutes()).padStart(2, '0') + "" + String(d.getSeconds()).padStart(2, '0');
        var filename = "eternity-" + dateStr + ".png";
        var permanentPath = dir + "/" + filename;
        var tmpLoc = String(StandardPaths.writableLocation(StandardPaths.TempLocation)).replace(/^file:\/\//, "");
        if (!tmpLoc || tmpLoc === "undefined") tmpLoc = "/tmp";
        var tmpPath = tmpLoc + "/eternal_spiral_share.png";

        spiralCanvas.grabToImage(function(result) {
            result.saveToFile(tmpPath);
            result.saveToFile(permanentPath);
            executeShellCommand("mkdir -p " + escapeShell(dir) + " && cp -f " + escapeShell(tmpPath) + " " + escapeShell(permanentPath));
            if (callback) {
                callback(tmpPath, permanentPath, filename);
            }
        });
    }

    function openShareModal() {
        captureSpiralSnapshot(function(tmpPath, permanentPath, filename) {
            sharePreviewPath = permanentPath;
            sharePreviewUrl = "file://" + tmpPath + "?v=" + Date.now();

            var target = viewingSession || Database.loadSession(activeSessionId);
            var insight = (target && (target.final_insight || (target.answers && target.answers[80]))) ? (target.final_insight || target.answers[80]) : "";
            if (insight && insight.length > 160) insight = insight.substring(0, 157) + "...";

            var insightPart = insight ? "\n\"" + insight + "\"\n\n" : "\n";
            shareCaption = "Process #4 Emergence:" + insightPart + "#Ekology #CleanLanguage #EmergentKnowledge #Process4";

            // Pre-load clipboard with image
            executeShellCommand("wl-copy -t image/png < " + escapeShell(permanentPath));

            shareModalVisible = true;
        });
    }

    function submitPostToX() {
        if (sharePreviewPath) {
            executeShellCommand("wl-copy -t image/png < " + escapeShell(sharePreviewPath));
        }
        var tweet = shareCaption.trim();
        var intentUrl = "https://x.com/intent/post?text=" + encodeURIComponent(tweet);
        Qt.openUrlExternally(intentUrl);

        showCanvasToast("📷 Spiral image copied to clipboard! Press Ctrl+V in X to attach.");
        shareModalVisible = false;
    }

    function takeCanvasSnapshot() {
        captureSpiralSnapshot(function(tmpPath, permanentPath, filename) {
            executeShellCommand("wl-copy -t image/png < " + escapeShell(permanentPath));
            showCanvasToast("Snapshot Saved");
        });
    }

    function shareHighlightToX() {
        openShareModal();
    }

    function escapeShell(str) {
        return "'" + str.replace(/'/g, "'\\''") + "'";
    }

    function stepTypeColor(key) {
        if (key === "awehyb") return colPast;
        if (key === "awemyb") return colFuture;
        if (key === "now" || key === "p4_starter") return colGold;
        if (key === "awitdbwykatsawykn") return colGold;
        if (key === "cta") return colCyan;
        return colCyan;
    }

    function stepTypeBadge(key) {
        if (currentStep && currentStep.stepTitle) return currentStep.stepTitle.toUpperCase();
        if (key === "awehyb") return "PAST";
        if (key === "awemyb") return "FUTURE";
        if (key === "now" || key === "p4_starter") return "NOW";
        if (key === "cta") return "COMPARE";
        if (key === "review") return "REVIEW";
        if (key === "awitdbwykatsawykn") return "EMERGENCE";
        return "STEP";
    }

    // Keyboard Shortcuts
    Shortcut {
        sequence: "F11"
        onActivated: toggleFullscreen()
    }

    Shortcut {
        sequence: "Escape"
        enabled: isFullscreen
        onActivated: {
            if (isFullscreen) toggleFullscreen();
        }
    }

    Shortcut {
        sequence: "Ctrl+B"
        onActivated: toggleSidebar()
    }

    Shortcut {
        sequence: "F10"
        onActivated: toggleSidebar()
    }

    // Background Animated Starfield
    Canvas {
        id: starfieldCanvas
        anchors.fill: parent
        z: 0

        property var stars: []

        Component.onCompleted: {
            stars = [];
            for (var i = 0; i < 180; i++) {
                stars.push({
                    x: Math.random() * 1920,
                    y: Math.random() * 1080,
                    size: Math.random() * 2 + 0.5,
                    speed: Math.random() * 0.3 + 0.05,
                    opacity: Math.random() * 0.7 + 0.3
                });
            }
            requestPaint();
        }

        Timer {
            interval: 40
            running: true
            repeat: true
            onTriggered: {
                for (var i = 0; i < starfieldCanvas.stars.length; i++) {
                    var s = starfieldCanvas.stars[i];
                    s.x -= s.speed;
                    if (s.x < 0) s.x = starfieldCanvas.width;
                }
                starfieldCanvas.requestPaint();
            }
        }

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            // Subtle gradient
            var grad = ctx.createLinearGradient(0, 0, width, height);
            grad.addColorStop(0, "#020617");
            grad.addColorStop(0.5, "#060a22");
            grad.addColorStop(1, "#020617");
            ctx.fillStyle = grad;
            ctx.fillRect(0, 0, width, height);

            // Stars
            for (var i = 0; i < stars.length; i++) {
                var star = stars[i];
                ctx.fillStyle = "rgba(255, 255, 255, " + star.opacity + ")";
                ctx.beginPath();
                ctx.arc(star.x, star.y, star.size, 0, Math.PI * 2);
                ctx.fill();
            }
        }
    }

    // Main App Layout
    RowLayout {
        anchors.fill: parent
        spacing: 0
        z: 1

        // ==========================================
        // LEFT SIDEBAR (Sliding Drawer)
        // ==========================================
        Rectangle {
            id: leftSidebar
            Layout.fillHeight: true
            Layout.preferredWidth: isSidebarOpen ? 260 : 0
            clip: true
            color: colSidebarBg
            border.width: isSidebarOpen ? 1 : 0
            border.color: colBorder

            Behavior on Layout.preferredWidth {
                NumberAnimation { duration: 240; easing.type: Easing.InOutCubic }
            }

            Item {
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                width: 260

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 16

                    // App Brand with Collapse Button
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            text: "⏳"
                            font.pixelSize: 32
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: "The Eternal Moment"
                                color: colForeground
                                font.pixelSize: 15
                                font.bold: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                text: "Process #4 · Ekology"
                                color: colGold
                                font.pixelSize: 11
                                font.bold: true
                            }
                        }

                        // Collapse Sidebar Button
                        Rectangle {
                            width: 28
                            height: 28
                            radius: 6
                            color: collapseBtnHover.containsMouse ? "#26ffffff" : "#12ffffff"
                            border.width: 1
                            border.color: collapseBtnHover.containsMouse ? colCyan : "#334155"

                            Text {
                                anchors.centerIn: parent
                                text: "◀"
                                color: collapseBtnHover.containsMouse ? colCyan : colMuted
                                font.pixelSize: 11
                            }

                            ToolTip.visible: collapseBtnHover.containsMouse
                            ToolTip.text: "Slide sidebar out (Ctrl+B)"
                            ToolTip.delay: 400

                            MouseArea {
                                id: collapseBtnHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: toggleSidebar()
                            }
                        }
                    }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: colBorder
                }

                // New Session Button
                Rectangle {
                    Layout.fillWidth: true
                    height: 44
                    radius: 8
                    color: Qt.rgba(colGold.r, colGold.g, colGold.b, 0.15)
                    border.width: 1.5
                    border.color: colGold

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8
                        Text { text: "＋"; color: colGold; font.bold: true; font.pixelSize: 16 }
                        Text { text: "New Reflection Journey"; color: colGold; font.bold: true; font.pixelSize: 13 }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: startNewSession()
                    }
                }

                // Nav Items
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    // Nav helper component
                    component NavItem: Rectangle {
                        id: navBtn
                        required property string tabKey
                        required property string iconText
                        required property string labelText
                        required property color activeCol

                        Layout.fillWidth: true
                        height: 42
                        radius: 8
                        color: activeTab === tabKey ? Qt.rgba(activeCol.r, activeCol.g, activeCol.b, 0.2) : "transparent"
                        border.width: activeTab === tabKey ? 1 : 0
                        border.color: activeCol

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            spacing: 12

                            Text {
                                text: navBtn.iconText
                                font.pixelSize: 16
                            }
                            Text {
                                text: navBtn.labelText
                                color: activeTab === navBtn.tabKey ? colForeground : colMuted
                                font.pixelSize: 13
                                font.bold: activeTab === navBtn.tabKey
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (navBtn.tabKey === "archive") refreshHistory();
                                activeTab = navBtn.tabKey;
                            }
                        }
                    }

                    NavItem {
                        tabKey: "chamber"
                        iconText: "🌌"
                        labelText: "Reflection Chamber"
                        activeCol: colCyan
                    }

                    NavItem {
                        tabKey: "archive"
                        iconText: "📜"
                        labelText: "Personal Archive"
                        activeCol: colPast
                    }

                    NavItem {
                        tabKey: "report"
                        iconText: "📋"
                        labelText: "Session Report"
                        activeCol: colGold
                    }

                    NavItem {
                        tabKey: "manual"
                        iconText: "📖"
                        labelText: "Manual & Ekology"
                        activeCol: colFuture
                    }
                }

                Item { Layout.fillHeight: true }

                // Sidebar Footer / Ekology Reference
                Rectangle {
                    Layout.fillWidth: true
                    height: 100
                    radius: 8
                    color: Qt.rgba(colPast.r, colPast.g, colPast.b, 0.08)
                    border.width: 1
                    border.color: Qt.rgba(colPast.r, colPast.g, colPast.b, 0.25)

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 4

                        Text {
                            text: "🌿 ekology.co.uk"
                            color: colCyan
                            font.bold: true
                            font.pixelSize: 12
                        }
                        Text {
                            text: "Created by Matthew Hudson.\nBased on David Grove's Emergent Knowledge."
                            color: colMuted
                            font.pixelSize: 10
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }
                        Text {
                            text: "Click to visit ekology.co.uk ↗"
                            color: colGold
                            font.pixelSize: 10
                            font.underline: true
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Qt.openUrlExternally("https://ekology.co.uk")
                    }
                }

                    // Quick Controls Footer (Sidebar Collapse & Fullscreen)
                    RowLayout {
                        Layout.fillWidth: true
                        height: 28
                        spacing: 8

                        Rectangle {
                            Layout.fillWidth: true
                            height: 28
                            color: "transparent"
                            RowLayout {
                                anchors.fill: parent
                                spacing: 4
                                Text {
                                    text: "◀ Hide (Ctrl+B)"
                                    color: sidebarHideHover.containsMouse ? colCyan : colMuted
                                    font.pixelSize: 11
                                }
                            }
                            MouseArea {
                                id: sidebarHideHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: toggleSidebar()
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 28
                            color: "transparent"
                            RowLayout {
                                anchors.fill: parent
                                spacing: 4
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: isFullscreen ? "⛶ Exit" : "⛶ Fullscreen"
                                    color: fsFooterHover.containsMouse ? colCyan : colMuted
                                    font.pixelSize: 11
                                }
                            }
                            MouseArea {
                                id: fsFooterHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: toggleFullscreen()
                            }
                        }
                    }
                }
            }
        }

        // ==========================================
        // MAIN CONTENT AREA
        // ==========================================
        Rectangle {
            id: mainContentArea
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"

            // Top-Left Floating Sidebar Toggle Button (Slide In/Out)
            Rectangle {
                id: sidebarToggleBtn
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.margins: 16
                width: 34
                height: 34
                radius: 8
                z: 100
                visible: !isSidebarOpen
                color: sidebarToggleHover.containsMouse ? "#26ffffff" : "#181f38"
                border.width: 1
                border.color: sidebarToggleHover.containsMouse ? colCyan : "#334155"

                Text {
                    anchors.centerIn: parent
                    text: "☰"
                    color: sidebarToggleHover.containsMouse ? colCyan : colForeground
                    font.pixelSize: 16
                }

                ToolTip.visible: sidebarToggleHover.containsMouse
                ToolTip.text: "Slide in navigation sidebar (Ctrl+B)"
                ToolTip.delay: 400

                MouseArea {
                    id: sidebarToggleHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: toggleSidebar()
                }
            }

            // Top-Right Fullscreen / Float Quick Control
            Rectangle {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 16
                width: 34
                height: 34
                radius: 8
                z: 100
                color: fullscreenHover.containsMouse ? "#26ffffff" : "#12ffffff"
                border.width: 1
                border.color: fullscreenHover.containsMouse ? colCyan : "#334155"

                Text {
                    anchors.centerIn: parent
                    text: isFullscreen ? "🗗" : "⛶"
                    color: fullscreenHover.containsMouse ? colCyan : colMuted
                    font.pixelSize: 15
                }

                ToolTip.visible: fullscreenHover.containsMouse
                ToolTip.text: isFullscreen ? "Exit Fullscreen (F11 / Esc)" : "Fullscreen Immersion Mode (F11)"

                MouseArea {
                    id: fullscreenHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: toggleFullscreen()
                }
            }

            // -------------------------------------------------------------
            // 1. CHAMBER TAB (The Active Guided Session & 3D Evolving Spiral)
            // -------------------------------------------------------------
            RowLayout {
                anchors.fill: parent
                spacing: 0
                visible: activeTab === "chamber"

                // ---------------------------------------------------------
                // 1A. LEFT / CENTER: THE 3D EVOLVING HELIX SPIRAL CANVAS
                // ---------------------------------------------------------
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    Canvas {
                        id: spiralCanvas
                        anchors.fill: parent

                        Timer {
                            interval: 33 // ~30 FPS smooth rendering
                            running: appWindow.activeTab === "chamber" && appWindow.visible
                            repeat: true
                            onTriggered: {
                                SpiralEngine.update(spiralCanvas.width, spiralCanvas.height);
                                spiralCanvas.requestPaint();
                            }
                        }

                        onPaint: {
                            var ctx = getContext("2d");
                            SpiralEngine.render(ctx, width, height, spiralMouse.mouseX, spiralMouse.mouseY);
                        }
                    }

                    // Interactive Drag & Zoom MouseArea for 3D Spiral
                    MouseArea {
                        id: spiralMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: pressed ? (SpiralEngine.isDraggingNode() ? Qt.SizeAllCursor : Qt.ClosedHandCursor) : (SpiralEngine.hasNodeAt(mouseX, mouseY) ? Qt.PointingHandCursor : Qt.OpenHandCursor)

                        property real lastX: 0
                        property real lastY: 0

                        onPressed: function(mouse) {
                            lastX = mouse.x;
                            lastY = mouse.y;
                            SpiralEngine.startDrag(mouse.x, mouse.y);
                            spiralCanvas.requestPaint();
                        }

                        onReleased: function(mouse) {
                            SpiralEngine.endDrag();
                            spiralCanvas.requestPaint();
                        }

                        onPositionChanged: function(mouse) {
                            if (pressed) {
                                var dx = mouse.x - lastX;
                                var dy = mouse.y - lastY;
                                var isShift = (mouse.modifiers & Qt.ShiftModifier) !== 0;
                                SpiralEngine.handleDrag(dx, dy, isShift);
                                lastX = mouse.x;
                                lastY = mouse.y;
                                spiralCanvas.requestPaint();
                            } else {
                                spiralCanvas.requestPaint();
                            }
                        }

                        onWheel: function(wheel) {
                            SpiralEngine.handleWheel(wheel.angleDelta.y);
                            spiralCanvas.requestPaint();
                        }
                    }

                    // Authentic Watermark
                    Text {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.margins: 20
                        text: "ekology.co.uk · #ETERNITY"
                        color: Qt.rgba(colCyan.r, colCyan.g, colCyan.b, 0.45)
                        font.pixelSize: 11
                        font.bold: true
                        font.letterSpacing: 1.5
                    }

                    // Floating Action Controls (Snapshot, Share on X)
                    RowLayout {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 16
                        spacing: 10
                        z: 10

                        // 1. Snapshot Button (Mirroring Ekology #snapshot-btn-eternity)
                        Rectangle {
                            Layout.preferredHeight: 32
                            Layout.preferredWidth: snapRow.implicitWidth + 26
                            height: 32
                            width: snapRow.implicitWidth + 26
                            radius: 16
                            color: snapMouse.containsMouse ? Qt.rgba(colCyan.r, colCyan.g, colCyan.b, 0.25) : Qt.rgba(15/255, 23/255, 42/255, 0.8)
                            border.width: 1
                            border.color: snapMouse.containsMouse ? colCyan : "#334155"

                            Row {
                                id: snapRow
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    text: "📷"
                                    font.pixelSize: 13
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    id: snapBtnTxt
                                    text: "Snapshot"
                                    color: snapMouse.containsMouse ? colCyan : colForeground
                                    font.pixelSize: 11
                                    font.bold: true
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: snapMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: takeCanvasSnapshot()
                            }
                        }

                        // 2. Share to X Button (Mirroring Ekology #share-x-btn-eternity)
                        Rectangle {
                            Layout.preferredHeight: 32
                            Layout.preferredWidth: shareRow.implicitWidth + 26
                            height: 32
                            width: shareRow.implicitWidth + 26
                            radius: 16
                            color: shareXMouse.containsMouse ? "#18181b" : "#000000"
                            border.width: 1
                            border.color: shareXMouse.containsMouse ? "#ffffff" : "#475569"

                            Row {
                                id: shareRow
                                anchors.centerIn: parent
                                spacing: 6

                                Text {
                                    text: "𝕏"
                                    color: "#ffffff"
                                    font.pixelSize: 14
                                    font.bold: true
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    id: shareBtnTxt
                                    text: "Share on X"
                                    color: "#ffffff"
                                    font.pixelSize: 11
                                    font.bold: true
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            MouseArea {
                                id: shareXMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: openShareModal()
                            }
                        }
                    }

                    // Floating Canvas Toast Notification
                    Rectangle {
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.topMargin: 16
                        height: 32
                        width: canvasToastTxt.implicitWidth + 28
                        radius: 16
                        visible: !!canvasToastMessage
                        color: "#0f172a"
                        border.width: 1
                        border.color: colCyan
                        z: 20

                        Text {
                            id: canvasToastTxt
                            anchors.centerIn: parent
                            text: canvasToastMessage
                            color: colForeground
                            font.pixelSize: 11
                            font.bold: true
                        }
                    }

                    // Rotational Hint Pill
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.margins: 18
                        height: 28
                        width: rotHintText.implicitWidth + 24
                        radius: 14
                        color: "#020617"
                        border.width: 1
                        border.color: "#334155"

                        Text {
                            id: rotHintText
                            anchors.centerIn: parent
                            text: "🖱️ Drag background to rotate • Drag nodes to reposition • Wheel to zoom • Shift+Drag for time travel"
                            color: colMuted
                            font.pixelSize: 11
                        }
                    }
                }

                // ---------------------------------------------------------
                // 1B. RIGHT: AUTHENTIC CONTROL PANEL & GUIDED INQUIRY
                // ---------------------------------------------------------
                Rectangle {
                    Layout.preferredWidth: 420
                    Layout.fillHeight: true
                    color: colSidebarBg
                    border.width: 1
                    border.color: colBorder

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 12

                        // Top scrollable guided inquiry section
                        ScrollView {
                            id: rightPanelScroll
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            contentWidth: availableWidth
                            clip: true

                            Column {
                                width: rightPanelScroll.availableWidth
                                spacing: 12

                                // Subtitle & Header
                                Item {
                                    width: parent.width
                                    height: headerCol.implicitHeight

                                    Column {
                                        id: headerCol
                                        width: parent.width
                                        spacing: 2

                                        Text {
                                            text: "EMERGENT KNOWLEDGE | PROCESS #4"
                                            color: colCyan
                                            font.pixelSize: 10
                                            font.bold: true
                                            font.letterSpacing: 1.2
                                        }

                                        Text {
                                            text: "THE ETERNAL MOMENT"
                                            color: colForeground
                                            font.pixelSize: 18
                                            font.bold: true
                                            font.family: "Outfit, Inter, sans-serif"
                                        }
                                    }
                                }

                                // Authentic Guidance Box (from eternity_app.php)
                                Rectangle {
                                    width: parent.width
                                    implicitHeight: guideCol.implicitHeight + 20
                                    radius: 10
                                    color: "#090d22"
                                    border.width: 1
                                    border.color: "#1e293b"

                                    Column {
                                        id: guideCol
                                        anchors.top: parent.top
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.margins: 10
                                        spacing: 4

                                        Text {
                                            width: parent.width
                                            text: "‘Where’ can signify any, some or all of these:"
                                            color: colForeground
                                            font.bold: true
                                            font.pixelSize: 11
                                            wrapMode: Text.WordWrap
                                        }
                                        Text { width: parent.width; text: "• A situation, state or condition"; color: colMuted; font.pixelSize: 11 }
                                        Text { width: parent.width; text: "• A place or viewpoint"; color: colMuted; font.pixelSize: 11 }
                                        Text { width: parent.width; text: "• An identity or attitude"; color: colMuted; font.pixelSize: 11 }
                                        Text { width: parent.width; text: "• A mood or emotion"; color: colMuted; font.pixelSize: 11 }
                                        Text {
                                            width: parent.width
                                            text: "in that moment of time."
                                            color: colCyan
                                            font.pixelSize: 10
                                            font.italic: true
                                        }
                                    }
                                }

                                // Show Outer Helix Toggle Checkbox
                                Row {
                                    width: parent.width
                                    height: 26
                                    spacing: 8

                                    CheckBox {
                                        id: helixToggle
                                        checked: true
                                        anchors.verticalCenter: parent.verticalCenter
                                        onCheckedChanged: {
                                            SpiralEngine.toggleHelix(checked);
                                            spiralCanvas.requestPaint();
                                        }
                                    }
                                    Text {
                                        text: "Show Outer Helix Ribbon"
                                        color: colMuted
                                        font.pixelSize: 11
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                // Step & Set Tracker
                                Row {
                                    width: parent.width
                                    height: 26
                                    spacing: 10

                                    Rectangle {
                                        height: 22
                                        width: setBadge.implicitWidth + 14
                                        radius: 11
                                        color: "#0e2238"
                                        border.width: 1
                                        border.color: colCyan
                                        anchors.verticalCenter: parent.verticalCenter

                                        Text {
                                            id: setBadge
                                            anchors.centerIn: parent
                                            text: currentStepIndex >= flatSteps.length ? "INTEGRATION" : (currentStep && currentStep.key === "awitdbwykatsawykn" ? "EMERGENT INSIGHT" : (currentStep && currentStep.key === "cta" && currentStep.compareTargetIndex === 0 ? "1–7 COMPARISON" : (currentStep && currentStep.stepTitle === "Now 7" ? "NOW 7" : ("SET " + currentSet + " OF 6"))))
                                            color: colCyan
                                            font.bold: true
                                            font.pixelSize: 10
                                        }
                                    }

                                    Item {
                                        width: Math.max(20, parent.width - (setBadge.implicitWidth + 14) - stepCountText.implicitWidth - 28)
                                        height: 6
                                        anchors.verticalCenter: parent.verticalCenter

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 3
                                            color: "#1e293b"

                                            Rectangle {
                                                height: parent.height
                                                radius: 3
                                                width: parent.width * Math.min(1.0, currentStepIndex >= flatSteps.length ? 1.0 : ((currentStepIndex + 1) / Math.max(1, flatSteps.length)))
                                                color: colGold
                                            }
                                        }
                                    }

                                    Text {
                                        id: stepCountText
                                        text: currentStepIndex >= flatSteps.length ? ("Step " + flatSteps.length + "/" + flatSteps.length + " · Complete") : ("Step " + (currentStepIndex + 1) + "/" + flatSteps.length)
                                        color: colMuted
                                        font.pixelSize: 11
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                // Inquiry Card
                                Rectangle {
                                    width: parent.width
                                    implicitHeight: inqCol.implicitHeight + 24
                                    radius: 12
                                    color: colCardBg
                                    border.width: 1.5
                                    border.color: stepTypeColor(currentStepType)
                                    visible: currentStepIndex < flatSteps.length

                                    Column {
                                        id: inqCol
                                        anchors.top: parent.top
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.margins: 12
                                        spacing: 8

                                        Row {
                                            spacing: 8
                                            Rectangle {
                                                height: 20
                                                width: badgeLabel.implicitWidth + 14
                                                radius: 10
                                                color: "#131b38"
                                                border.width: 1
                                                border.color: stepTypeColor(currentStepType)

                                                Text {
                                                    id: badgeLabel
                                                    anchors.centerIn: parent
                                                    text: stepTypeBadge(currentStepType)
                                                    color: stepTypeColor(currentStepType)
                                                    font.bold: true
                                                    font.pixelSize: 10
                                                }
                                            }

                                            Text {
                                                text: currentStep ? (ProcessData.questionLibrary[currentStep.key] ? ProcessData.questionLibrary[currentStep.key].label : "") : ""
                                                color: colMuted
                                                font.pixelSize: 11
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }

                                        Text {
                                            width: parent.width
                                            text: currentQuestionText
                                            color: colForeground
                                            font.pixelSize: 16
                                            font.bold: true
                                            font.family: "Outfit, Inter, sans-serif"
                                            wrapMode: Text.WordWrap
                                        }

                                        // Authentic Precursor / Example Text
                                        Text {
                                            width: parent.width
                                            text: ProcessData.getStepExample(currentStepType, currentStep)
                                            color: colCyan
                                            font.pixelSize: 11
                                            font.italic: true
                                            wrapMode: Text.WordWrap
                                            visible: text !== ""
                                        }

                                        // 1-7 Temporal Comparison Reference for Emergent Insight
                                        Rectangle {
                                            width: parent.width
                                            implicitHeight: insightRefCol.implicitHeight + 16
                                            radius: 8
                                            color: Qt.rgba(colGold.r, colGold.g, colGold.b, 0.08)
                                            border.width: 1
                                            border.color: Qt.rgba(colGold.r, colGold.g, colGold.b, 0.3)
                                            visible: currentStep && currentStep.key === "awitdbwykatsawykn"

                                            Column {
                                                id: insightRefCol
                                                width: parent.width - 16
                                                anchors.centerIn: parent
                                                spacing: 6

                                                Text {
                                                    text: "⚡ Grounded on 1–7 Temporal Comparison:"
                                                    color: colGold
                                                    font.bold: true
                                                    font.pixelSize: 11
                                                }

                                                Text {
                                                    width: parent.width
                                                    text: "• Start (Now 1): \"" + ((answers && answers[0]) ? answers[0] : "...") + "\""
                                                    color: colForeground
                                                    font.pixelSize: 11
                                                    wrapMode: Text.WordWrap
                                                }

                                                Text {
                                                    width: parent.width
                                                    text: "• Now (Now 7): \"" + ((answers && answers[78]) ? answers[78] : "...") + "\""
                                                    color: colForeground
                                                    font.pixelSize: 11
                                                    wrapMode: Text.WordWrap
                                                }

                                                Text {
                                                    width: parent.width
                                                    text: "• Comparison (Step 80): \"" + ((answers && answers[79]) ? answers[79] : "...") + "\""
                                                    color: "#c4b5fd"
                                                    font.pixelSize: 11
                                                    font.italic: true
                                                    wrapMode: Text.WordWrap
                                                    visible: (answers && answers[79]) ? true : false
                                                }
                                            }
                                        }

                                        // Quick Check-in trigger pill (on Step 0)
                                        Rectangle {
                                            width: parent.width
                                            height: 32
                                            radius: 8
                                            color: checkinPillHover.containsMouse ? "#2606b6d4" : "#1406b6d4"
                                            border.width: 1
                                            border.color: colCyan
                                            visible: currentStepIndex === 0

                                            RowLayout {
                                                anchors.centerIn: parent
                                                spacing: 8
                                                Text { text: "🎯"; font.pixelSize: 13 }
                                                Text { text: "Quick Check-in:"; color: colCyan; font.bold: true; font.pixelSize: 11 }
                                                Text { text: "Clarity (Foggy — Clear) • Movement (Stuck — Flowing)"; color: colForeground; font.pixelSize: 11 }
                                                Text { text: "✎"; color: colGold; font.bold: true; font.pixelSize: 11 }
                                            }

                                            MouseArea {
                                                id: checkinPillHover
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: isCheckinModalOpen = true
                                            }
                                        }
                                    }
                                }

                                // Answer Input Card
                                Rectangle {
                                    width: parent.width
                                    height: 115
                                    radius: 12
                                    color: "#090d1f"
                                    border.width: 1
                                    border.color: colBorder
                                    visible: currentStepIndex < flatSteps.length

                                    ScrollView {
                                        id: answerScroll
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        clip: true
                                        contentWidth: availableWidth
                                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                                        TextArea {
                                            id: answerInputBox
                                            width: answerScroll.availableWidth
                                            text: answerDraft
                                            placeholderText: ProcessData.getPlaceholder(currentStepType)
                                            placeholderTextColor: "#64748b"
                                            color: colForeground
                                            font.pixelSize: 13
                                            font.family: "Inter, sans-serif"
                                            wrapMode: TextArea.Wrap
                                            background: null
                                            onTextChanged: answerDraft = text

                                            Keys.onReturnPressed: function(event) {
                                                if (event.modifiers & Qt.ShiftModifier) {
                                                    event.accepted = false;
                                                } else {
                                                    advanceStep();
                                                    event.accepted = true;
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Pinned Bottom Section: Launch button and all controls below it in exact order
                        Column {
                            Layout.fillWidth: true
                            spacing: 10

                            // Dynamic Action Button
                            Rectangle {
                                width: parent.width
                                height: 38
                                radius: 8
                                color: colGold
                                visible: currentStepIndex < flatSteps.length

                                Text {
                                    anchors.centerIn: parent
                                    text: ProcessData.getButtonText(currentStepIndex, currentStepType)
                                    color: "#020617"
                                    font.bold: true
                                    font.pixelSize: 13
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: advanceStep()
                                }
                            }

                            // Progress Track (Dynamic Step indicator + Step Subtitle)
                            Rectangle {
                                width: parent.width
                                height: 32
                                radius: 8
                                color: "#0a0f25"
                                border.width: 1
                                border.color: "#1e293b"
                                visible: currentStepIndex < flatSteps.length

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 8

                                    Rectangle {
                                        width: 8
                                        height: 8
                                        radius: 4
                                        color: currentStep ? stepTypeColor(currentStepType) : colGold
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: currentStep ? (currentStep.stepTitle || ("Step " + (currentStepIndex + 1))) : "Complete"
                                        color: currentStep ? stepTypeColor(currentStepType) : colGold
                                        font.bold: true
                                        font.pixelSize: 11
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: "• " + (currentStep ? ((currentStep.set <= 6 && currentStep.key !== "awitdbwykatsawykn" && currentStep.compareTargetIndex !== 0 ? ("Set " + currentStep.set + " • ") : "") + ProcessData.getProgressSubtitle(currentStepType, currentStep)) : "")
                                        color: colMuted
                                        font.pixelSize: 11
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }



                            // Dedicated Finishing The Metrics Screen (When 80 inquiry steps complete)
                            Rectangle {
                                width: parent.width
                                implicitHeight: finishMetricsCol.implicitHeight + 24
                                radius: 12
                                color: "#160d2b"
                                border.width: 1.5
                                border.color: colGold
                                visible: currentStepIndex >= flatSteps.length

                                Column {
                                    id: finishMetricsCol
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.margins: 12
                                    spacing: 12

                                    RowLayout {
                                        width: parent.width
                                        Text {
                                            text: "✨ FINISHING THE METRICS"
                                            color: colGold
                                            font.bold: true
                                            font.pixelSize: 11
                                            font.letterSpacing: 0.8
                                        }
                                        Item { Layout.fillWidth: true }
                                        Text {
                                            text: "Session Complete"
                                            color: "#10b981"
                                            font.bold: true
                                            font.pixelSize: 10
                                        }
                                    }

                                    // Final emergent insight harvest display
                                    Rectangle {
                                        width: parent.width
                                        implicitHeight: insTextCol.implicitHeight + 16
                                        radius: 8
                                        color: Qt.rgba(colGold.r, colGold.g, colGold.b, 0.08)
                                        border.width: 1
                                        border.color: Qt.rgba(colGold.r, colGold.g, colGold.b, 0.3)

                                        Column {
                                            id: insTextCol
                                            anchors.top: parent.top
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.margins: 10
                                            spacing: 4

                                            Text {
                                                text: "And, what is the difference between what you knew at the start and what you know now?"
                                                color: colMuted
                                                font.pixelSize: 11
                                                font.italic: true
                                                width: parent.width
                                                wrapMode: Text.WordWrap
                                            }

                                            Text {
                                                width: parent.width
                                                text: {
                                                    var lastAns = (answers && answers[flatSteps.length - 1]) ? answers[flatSteps.length - 1] : ((answers && (answers[80] || answers[79])) ? (answers[80] || answers[79]) : "");
                                                    return lastAns ? ("\"" + lastAns + "\"") : "Breakthrough insight recorded.";
                                                }
                                                color: colForeground
                                                font.bold: true
                                                font.pixelSize: 13
                                                wrapMode: Text.WordWrap
                                            }
                                        }
                                    }

                                    // Live shift indicator
                                    RowLayout {
                                        width: parent.width
                                        Text {
                                            text: "Calibrate where you are now:"
                                            color: "#c4b5fd"
                                            font.bold: true
                                            font.pixelSize: 11
                                        }
                                        Item { Layout.fillWidth: true }
                                        Text {
                                            text: "Shift: " + ((postClarity - preClarity >= 0 ? "+" : "") + (postClarity - preClarity)) + " Clarity • " + ((postMovement - preMovement >= 0 ? "+" : "") + (postMovement - preMovement)) + " Movement"
                                            color: colGold
                                            font.bold: true
                                            font.pixelSize: 11
                                        }
                                    }

                                    // Clarity Slider (Foggy -> Clear)
                                    Column {
                                        width: parent.width
                                        spacing: 2

                                        Text { text: "Clarity"; color: colForeground; font.bold: true; font.pixelSize: 11 }

                                        RowLayout {
                                            width: parent.width
                                            spacing: 6

                                            Text { text: "Foggy"; color: colMuted; font.italic: true; font.pixelSize: 10 }
                                            Slider {
                                                Layout.fillWidth: true
                                                from: 1
                                                to: 10
                                                stepSize: 1
                                                value: postClarity
                                                onValueChanged: {
                                                    postClarity = Math.round(value);
                                                    saveFinalMetrics();
                                                }
                                            }
                                            Text { text: "Clear"; color: colMuted; font.italic: true; font.pixelSize: 10 }
                                        }
                                    }

                                    // Movement Slider (Stuck -> Flowing)
                                    Column {
                                        width: parent.width
                                        spacing: 4

                                        Text { text: "Movement"; color: colForeground; font.bold: true; font.pixelSize: 11 }

                                        RowLayout {
                                            width: parent.width
                                            spacing: 6

                                            Text { text: "Stuck"; color: colMuted; font.italic: true; font.pixelSize: 10 }
                                            Slider {
                                                Layout.fillWidth: true
                                                from: 1
                                                to: 10
                                                stepSize: 1
                                                value: postMovement
                                                onValueChanged: {
                                                    postMovement = Math.round(value);
                                                    postFocus = postMovement;
                                                    saveFinalMetrics();
                                                }
                                            }
                                            Text { text: "Flowing"; color: colMuted; font.italic: true; font.pixelSize: 10 }
                                        }
                                    }

                                    // Action Buttons: View Report / New Session
                                    RowLayout {
                                        width: parent.width
                                        spacing: 10

                                        Rectangle {
                                            Layout.fillWidth: true
                                            height: 38
                                            radius: 8
                                            color: colGold

                                            Text {
                                                anchors.centerIn: parent
                                                text: "📋 View Session Report ★"
                                                color: "#020617"
                                                font.bold: true
                                                font.pixelSize: 12
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    saveFinalMetrics();
                                                    viewingSession = Database.loadSession(activeSessionId);
                                                    activeTab = "report";
                                                }
                                            }
                                        }

                                        Rectangle {
                                            Layout.preferredWidth: 120
                                            height: 38
                                            radius: 8
                                            color: Qt.rgba(colCyan.r, colCyan.g, colCyan.b, 0.15)
                                            border.width: 1
                                            border.color: colCyan

                                            Text {
                                                anchors.centerIn: parent
                                                text: "🌀 New Session"
                                                color: colCyan
                                                font.bold: true
                                                font.pixelSize: 12
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: startNewSession()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // -------------------------------------------------------------
            // 2. ARCHIVE TAB (Personal Development History)
            // -------------------------------------------------------------
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 40
                spacing: 20
                visible: activeTab === "archive"

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Personal Development Archive"
                        color: colForeground
                        font.pixelSize: 24
                        font.bold: true
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: historicalSessions.length + " Saved Sessions"
                        color: colCyan
                        font.bold: true
                        font.pixelSize: 13
                    }
                }

                Text {
                    text: "Review past sessions, observe psychological shifts across time, and track breakthroughs."
                    color: colMuted
                    font.pixelSize: 13
                }

                ScrollView {
                    id: archiveScroll
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: availableWidth
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                    ColumnLayout {
                        width: archiveScroll.availableWidth
                        spacing: 12

                        Repeater {
                            model: historicalSessions

                            delegate: Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                height: 96
                                radius: 12
                                color: colCardBg
                                border.width: 1
                                border.color: modelData.status === "completed" ? Qt.rgba(colGold.r, colGold.g, colGold.b, 0.3) : colBorder

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 16
                                    spacing: 16

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        RowLayout {
                                            spacing: 10
                                            Text {
                                                text: modelData.created_at ? modelData.created_at.replace("T", " ").substring(0, 16) : "Date"
                                                color: colMuted
                                                font.pixelSize: 12
                                            }

                                            Rectangle {
                                                height: 18
                                                width: stTxt.implicitWidth + 12
                                                radius: 9
                                                color: modelData.status === "completed" ? Qt.rgba(16/255, 185/255, 129/255, 0.2) : Qt.rgba(6/255, 182/255, 212/255, 0.2)
                                                border.width: 1
                                                border.color: modelData.status === "completed" ? "#10b981" : colCyan

                                                Text {
                                                    id: stTxt
                                                    anchors.centerIn: parent
                                                    text: modelData.status === "completed" ? "COMPLETED" : "STEP " + (modelData.current_step + 1) + "/81"
                                                    color: modelData.status === "completed" ? "#10b981" : colCyan
                                                    font.pixelSize: 10
                                                    font.bold: true
                                                }
                                            }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: "Initial Now: \"" + (modelData.now_start || "...") + "\""
                                            color: colForeground
                                            font.pixelSize: 14
                                            font.bold: true
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            visible: !!modelData.final_insight
                                            text: "Emergent Shift: \"" + modelData.final_insight + "\""
                                            color: colGold
                                            font.pixelSize: 12
                                            font.italic: true
                                            elide: Text.ElideRight
                                        }
                                    }

                                    RowLayout {
                                        spacing: 8

                                        Rectangle {
                                            height: 36
                                            width: 80
                                            radius: 6
                                            color: modelData.status === "completed" ? Qt.rgba(colGold.r, colGold.g, colGold.b, 0.2) : Qt.rgba(colCyan.r, colCyan.g, colCyan.b, 0.2)
                                            border.width: 1
                                            border.color: modelData.status === "completed" ? colGold : colCyan

                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData.status === "completed" ? "Report" : "Resume"
                                                color: modelData.status === "completed" ? colGold : colCyan
                                                font.bold: true
                                                font.pixelSize: 12
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    var full = Database.loadSession(modelData.id);
                                                    if (modelData.status === "completed") {
                                                        openSessionReport(full);
                                                    } else {
                                                        resumeSession(full);
                                                    }
                                                }
                                            }
                                        }

                                        Rectangle {
                                            height: 36
                                            width: 86
                                            radius: 6
                                            color: Qt.rgba(colPast.r, colPast.g, colPast.b, 0.2)
                                            border.width: 1
                                            border.color: colPast

                                            Text {
                                                anchors.centerIn: parent
                                                text: "Spiral 3D"
                                                color: colPast
                                                font.bold: true
                                                font.pixelSize: 12
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    var full = Database.loadSession(modelData.id);
                                                    if (full) {
                                                        activeSessionId = full.id;
                                                        sessionUuid = full.uuid;
                                                        currentStepIndex = full.current_step || 0;
                                                        answers = full.answers || [];
                                                        activeTab = "chamber";
                                                        var targetLimit = (full.status === "completed" || !full.answers) ? (full.answers ? full.answers.length - 1 : 0) : currentStepIndex;
                                                        SpiralEngine.rebuildFromSession(flatSteps, answers, targetLimit);
                                                    }
                                                }
                                            }
                                        }

                                        Rectangle {
                                            height: 36
                                            width: 36
                                            radius: 6
                                            color: Qt.rgba(239/255, 68/255, 68/255, 0.15)
                                            border.width: 1
                                            border.color: "#ef4444"

                                            Text {
                                                anchors.centerIn: parent
                                                text: "✕"
                                                color: "#ef4444"
                                                font.bold: true
                                                font.pixelSize: 12
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    Database.deleteSession(modelData.id);
                                                    refreshHistory();
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // -------------------------------------------------------------
            // 3. REPORT TAB (Structured Record & Export)
            // -------------------------------------------------------------
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 40
                spacing: 20
                visible: activeTab === "report"

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Session Record & Emergence Report"
                        color: colForeground
                        font.pixelSize: 24
                        font.bold: true
                    }
                    Item { Layout.fillWidth: true }

                    RowLayout {
                        spacing: 12

                        Rectangle {
                            height: 38
                            width: 150
                            radius: 6
                            color: Qt.rgba(colPast.r, colPast.g, colPast.b, 0.15)
                            border.width: 1.5
                            border.color: colPast

                            Text {
                                anchors.centerIn: parent
                                text: "🌀 Explore 3D Spiral"
                                color: colPast
                                font.bold: true
                                font.pixelSize: 12
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    activeTab = "chamber";
                                }
                            }
                        }

                        Rectangle {
                            height: 38
                            width: 150
                            radius: 6
                            color: Qt.rgba(colGold.r, colGold.g, colGold.b, 0.15)
                            border.width: 1.5
                            border.color: colGold

                            Text {
                                anchors.centerIn: parent
                                text: "📋 Copy Markdown"
                                color: colGold
                                font.bold: true
                                font.pixelSize: 12
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: copyReportToClipboard()
                            }
                        }

                        Rectangle {
                            height: 38
                            width: 140
                            radius: 6
                            color: Qt.rgba(colCyan.r, colCyan.g, colCyan.b, 0.15)
                            border.width: 1.5
                            border.color: colCyan

                            Text {
                                anchors.centerIn: parent
                                text: "💾 Save to Docs"
                                color: colCyan
                                font.bold: true
                                font.pixelSize: 12
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: exportReportToFile()
                            }
                        }

                        Rectangle {
                            height: 38
                            width: 130
                            radius: 6
                            color: Qt.rgba(56/255, 189/255, 248/255, 0.15)
                            border.width: 1.5
                            border.color: "#38bdf8"

                            Text {
                                anchors.centerIn: parent
                                text: "🐦 Share on X"
                                color: "#38bdf8"
                                font.bold: true
                                font.pixelSize: 12
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: shareHighlightToX()
                            }
                        }
                    }
                }

                // Status Toast Message
                Text {
                    visible: !!copyStatusMessage
                    text: copyStatusMessage
                    color: "#10b981"
                    font.bold: true
                    font.pixelSize: 13
                }

                // Emergent Difference Callout
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 110
                    radius: 12
                    color: Qt.rgba(colGold.r, colGold.g, colGold.b, 0.1)
                    border.width: 1.5
                    border.color: colGold

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 6

                        Text {
                            text: "✨ THE EMERGENT DIFFERENCE"
                            color: colGold
                            font.bold: true
                            font.pixelSize: 11
                            font.letterSpacing: 1
                        }

                        Text {
                            Layout.fillWidth: true
                            text: {
                                var t = viewingSession || Database.loadSession(activeSessionId);
                                return (t && t.final_insight) ? ("\"" + t.final_insight + "\"") : (t && t.answers && t.answers[80] ? ("\"" + t.answers[80] + "\"") : "Reflect on the final question to harvest your breakthrough.");
                            }
                            color: colForeground
                            font.pixelSize: 16
                            font.bold: true
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                // Progress Made & Metric Shift Callout
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: progressCol.implicitHeight + 24
                    radius: 12
                    color: Qt.rgba(colCyan.r, colCyan.g, colCyan.b, 0.08)
                    border.width: 1.5
                    border.color: colCyan

                    ColumnLayout {
                        id: progressCol
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: 16
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "📈 PROGRESS MADE · ATTENTIONAL & COGNITIVE SHIFT"
                                color: colCyan
                                font.bold: true
                                font.pixelSize: 11
                                font.letterSpacing: 1
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: "Pre vs Post Calibration"
                                color: "#94a3b8"
                                font.pixelSize: 11
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 16

                            // Clarity Metric Block
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 62
                                radius: 8
                                color: Qt.rgba(colCardBg.r, colCardBg.g, colCardBg.b, 0.6)
                                border.width: 1
                                border.color: colBorder

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 10

                                    ColumnLayout {
                                        spacing: 2
                                        Text {
                                            text: "Mental Clarity"
                                            color: "#94a3b8"
                                            font.pixelSize: 11
                                            font.bold: true
                                        }
                                        Text {
                                            property var sessionData: viewingSession || Database.loadSession(activeSessionId)
                                            property int preVal: sessionData ? (sessionData.pre_clarity || 5) : 5
                                            property int postVal: sessionData ? (sessionData.post_clarity || 5) : 5
                                            text: preVal + "/10 → " + postVal + "/10"
                                            color: colForeground
                                            font.pixelSize: 15
                                            font.bold: true
                                        }
                                    }

                                    Item { Layout.fillWidth: true }

                                    Rectangle {
                                        property var sessionData: viewingSession || Database.loadSession(activeSessionId)
                                        property int diff: (sessionData ? (sessionData.post_clarity || 5) : 5) - (sessionData ? (sessionData.pre_clarity || 5) : 5)
                                        radius: 6
                                        implicitWidth: clarityDiffText.implicitWidth + 16
                                        implicitHeight: 28
                                        color: diff > 0 ? Qt.rgba(16/255, 185/255, 129/255, 0.2) : (diff < 0 ? Qt.rgba(239/255, 68/255, 68/255, 0.2) : Qt.rgba(148/255, 163/255, 184/255, 0.15))
                                        border.width: 1
                                        border.color: diff > 0 ? "#10b981" : (diff < 0 ? "#ef4444" : "#64748b")

                                        Text {
                                            id: clarityDiffText
                                            anchors.centerIn: parent
                                            property var sessionData: viewingSession || Database.loadSession(activeSessionId)
                                            property int diff: (sessionData ? (sessionData.post_clarity || 5) : 5) - (sessionData ? (sessionData.pre_clarity || 5) : 5)
                                            text: (diff >= 0 ? "+" : "") + diff + " Shift"
                                            color: diff > 0 ? "#10b981" : (diff < 0 ? "#ef4444" : "#94a3b8")
                                            font.bold: true
                                            font.pixelSize: 11
                                        }
                                    }
                                }
                            }

                            // Movement Metric Block
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 62
                                radius: 8
                                color: Qt.rgba(colCardBg.r, colCardBg.g, colCardBg.b, 0.6)
                                border.width: 1
                                border.color: colBorder

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 10

                                    ColumnLayout {
                                        spacing: 2
                                        Text {
                                            text: "Movement Flow"
                                            color: "#94a3b8"
                                            font.pixelSize: 11
                                            font.bold: true
                                        }
                                        Text {
                                            property var sessionData: viewingSession || Database.loadSession(activeSessionId)
                                            property int preVal: sessionData ? (sessionData.pre_movement !== undefined ? sessionData.pre_movement : (sessionData.pre_focus || 5)) : 5
                                            property int postVal: sessionData ? (sessionData.post_movement !== undefined ? sessionData.post_movement : (sessionData.post_focus || 5)) : 5
                                            text: preVal + "/10 → " + postVal + "/10"
                                            color: colForeground
                                            font.pixelSize: 15
                                            font.bold: true
                                        }
                                    }

                                    Item { Layout.fillWidth: true }

                                    Rectangle {
                                        property var sessionData: viewingSession || Database.loadSession(activeSessionId)
                                        property int preVal: sessionData ? (sessionData.pre_movement !== undefined ? sessionData.pre_movement : (sessionData.pre_focus || 5)) : 5
                                        property int postVal: sessionData ? (sessionData.post_movement !== undefined ? sessionData.post_movement : (sessionData.post_focus || 5)) : 5
                                        property int diff: postVal - preVal
                                        radius: 6
                                        implicitWidth: movementDiffText.implicitWidth + 16
                                        implicitHeight: 28
                                        color: diff > 0 ? Qt.rgba(16/255, 185/255, 129/255, 0.2) : (diff < 0 ? Qt.rgba(239/255, 68/255, 68/255, 0.2) : Qt.rgba(148/255, 163/255, 184/255, 0.15))
                                        border.width: 1
                                        border.color: diff > 0 ? "#10b981" : (diff < 0 ? "#ef4444" : "#64748b")

                                        Text {
                                            id: movementDiffText
                                            anchors.centerIn: parent
                                            property var sessionData: viewingSession || Database.loadSession(activeSessionId)
                                            property int preVal: sessionData ? (sessionData.pre_movement !== undefined ? sessionData.pre_movement : (sessionData.pre_focus || 5)) : 5
                                            property int postVal: sessionData ? (sessionData.post_movement !== undefined ? sessionData.post_movement : (sessionData.post_focus || 5)) : 5
                                            property int diff: postVal - preVal
                                            text: (diff >= 0 ? "+" : "") + diff + " Shift"
                                            color: diff > 0 ? "#10b981" : (diff < 0 ? "#ef4444" : "#94a3b8")
                                            font.bold: true
                                            font.pixelSize: 11
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Full Markdown Preview
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 12
                    color: colCardBg
                    border.width: 1
                    border.color: colBorder

                    ScrollView {
                        id: reportScrollView
                        anchors.fill: parent
                        anchors.margins: 20
                        clip: true
                        contentWidth: availableWidth
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                        Text {
                            id: reportText
                            width: reportScrollView.availableWidth
                            text: {
                                var target = viewingSession || Database.loadSession(activeSessionId);
                                return Report.generateMarkdownReport(target, flatSteps, ProcessData.questionLibrary);
                            }
                            color: colForeground
                            font.pixelSize: 13
                            font.family: "monospace"
                            lineHeight: 1.4
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }

            // -------------------------------------------------------------
            // 4. MANUAL & LORE TAB (Complete Instruction & Ekology Guide)
            // -------------------------------------------------------------
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 40
                spacing: 20
                visible: activeTab === "manual"

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "The Eternal Moment: Process #4 · Instruction Manual"
                        color: colForeground
                        font.pixelSize: 24
                        font.bold: true
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: "By Matthew Hudson"
                        color: colGold
                        font.bold: true
                        font.pixelSize: 13
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 12
                    color: colCardBg
                    border.width: 1
                    border.color: colBorder

                    ScrollView {
                        id: manualScrollView
                        anchors.fill: parent
                        anchors.margins: 24
                        clip: true
                        contentWidth: availableWidth
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                        ColumnLayout {
                            width: manualScrollView.availableWidth
                            spacing: 18

                            Text {
                                text: "1. Origin & The Ekology Cosmology"
                                color: colCyan
                                font.pixelSize: 18
                                font.bold: true
                            }
                            Text {
                                Layout.fillWidth: true
                                text: "Process #4 — The Eternal Moment of Now was adapted from Universal Conscious Practice by K. Penday and grounded within David Grove's Emergent Knowledge philosophy.\n\nCreated and published by Matthew Hudson as part of the ekology.co.uk platform, this process externalizes internal psychological topography into an iterative, spiraling trajectory of time and attention.\n\nOfficial Website: https://ekology.co.uk"
                                color: colForeground
                                font.pixelSize: 13
                                lineHeight: 1.4
                                wrapMode: Text.WordWrap
                            }

                            Rectangle { Layout.fillWidth: true; height: 1; color: colBorder }

                            Text {
                                text: "2. The Core Architecture & The Power of Six"
                                color: colCyan
                                font.pixelSize: 18
                                font.bold: true
                            }
                            Text {
                                Layout.fillWidth: true
                                text: "Unlike analytical therapy or intellectual problem-solving which often loops in rumination, Process #4 gently oscillates attention between three temporal coordinates:\n\n• The Present Anchor ('Where are you now?'): The sovereign reference point.\n• The Past Memory ('Where else have you been?'): Retrieving historical conditions.\n• Comparison 1 ('Compare [A] to [B]'): Linking past to present.\n• The Future Projection ('Where else might you be?'): Accessing emerging potential.\n• Comparison 2 ('Compare [A] to [B]'): Linking future to present.\n\nThis triad is repeated three times per Set. After six comparisons, the participant's awareness shifts naturally, and a NEW 'Now' is recognized. Across 6 developmental Sets (47 core steps), deep cognitive structures reorganize."
                                color: colForeground
                                font.pixelSize: 13
                                lineHeight: 1.4
                                wrapMode: Text.WordWrap
                            }

                            Rectangle { Layout.fillWidth: true; height: 1; color: colBorder }

                            Text {
                                text: "3. Clean Language & Definitions"
                                color: colCyan
                                font.pixelSize: 18
                                font.bold: true
                            }
                            Text {
                                Layout.fillWidth: true
                                text: "When reflecting on the inquiries, understand the specific non-interpretive meanings:\n\n• WHERE: Can refer to any situation, emotional state, viewpoint, physical place, identity, or mood.\n• MIGHT: Expresses possibility, openness, and non-prescriptive futures.\n• COMPARE: Simply observe similarities and dissimilarities without judgment.\n• SINCERITY: Write whatever comes naturally without editing, polishing, or intellectual filtering."
                                color: colForeground
                                font.pixelSize: 13
                                lineHeight: 1.4
                                wrapMode: Text.WordWrap
                            }

                            Rectangle { Layout.fillWidth: true; height: 1; color: colBorder }

                            Text {
                                text: "4. The Closing Question: Harvesting The Emergent Shift"
                                color: colGold
                                font.pixelSize: 18
                                font.bold: true
                            }
                            Text {
                                Layout.fillWidth: true
                                text: "Following the completion of Set 6, the journey culminates in three transformative integration steps:\n\n• Step 79 (Now 7): 'And, where are you now?' — The 7th and final present anchor, capturing where your awareness has arrived.\n• Step 80 (Compare 37): 'And, compare [Now 1] to [Now 7]' — Directly bridging where you stood at the very start to where you stand now.\n• Step 81 (Emergent Insight): 'And, what is the difference between what you knew at the start and what you know now?' — Synthesising the entire spiral into an indelible realization based on the 1–7 comparison.\n\nFinally, the session concludes with Finishing the Metrics, calibrating your post-session Clarity and Movement shifts."
                                color: colForeground
                                font.pixelSize: 13
                                lineHeight: 1.4
                                wrapMode: Text.WordWrap
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 48
                                radius: 8
                                color: Qt.rgba(colCyan.r, colCyan.g, colCyan.b, 0.15)
                                border.width: 1
                                border.color: colCyan

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 8
                                    Text { text: "🌐 Visit Ekology.co.uk"; color: colCyan; font.bold: true; font.pixelSize: 14 }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Qt.openUrlExternally("https://ekology.co.uk")
                                }
                            }
                        }
                }
            }
        }
    }
    }

    // -------------------------------------------------------------
    // SHARE ON X / SNAPSHOT MODAL OVERLAY (Ekology Mirror)
    // -------------------------------------------------------------
    Rectangle {
        id: shareModalOverlay
        anchors.fill: parent
        z: 9999
        visible: shareModalVisible
        color: Qt.rgba(2/255, 6/255, 23/255, 0.92)

        MouseArea {
            anchors.fill: parent
            onClicked: shareModalVisible = false
        }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(620, parent.width - 40)
            height: modalContentCol.implicitHeight + 48
            radius: 20
            color: "#0f172a"
            border.width: 1
            border.color: Qt.rgba(colCyan.r, colCyan.g, colCyan.b, 0.4)

            MouseArea {
                anchors.fill: parent
                // absorb click
            }

            ColumnLayout {
                id: modalContentCol
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 24
                spacing: 16

                // Header
                RowLayout {
                    Layout.fillWidth: true
                    ColumnLayout {
                        spacing: 2
                        Text {
                            text: "Share Eternal Moment"
                            color: colForeground
                            font.pixelSize: 18
                            font.bold: true
                        }
                        Text {
                            text: "Emergent Knowledge • Process #4 Spiral Map"
                            color: colCyan
                            font.pixelSize: 11
                            font.letterSpacing: 0.5
                        }
                    }
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        height: 28; width: 28; radius: 14
                        color: closeShareMouse.containsMouse ? Qt.rgba(239/255, 68/255, 68/255, 0.25) : "transparent"
                        Text { anchors.centerIn: parent; text: "✕"; color: closeShareMouse.containsMouse ? "#ef4444" : colMuted; font.pixelSize: 14 }
                        MouseArea {
                            id: closeShareMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: shareModalVisible = false
                        }
                    }
                }

                // Live Spiral Snapshot Preview
                Rectangle {
                    Layout.fillWidth: true
                    height: 220
                    radius: 12
                    color: "#020617"
                    border.width: 1
                    border.color: Qt.rgba(colCyan.r, colCyan.g, colCyan.b, 0.25)
                    clip: true

                    Image {
                        id: sharePreviewImg
                        anchors.fill: parent
                        anchors.margins: 4
                        fillMode: Image.PreserveAspectFit
                        source: sharePreviewUrl
                        smooth: true
                        cache: false
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.right: parent.right
                        anchors.margins: 10
                        height: 22
                        width: badgeTxt.implicitWidth + 16
                        radius: 11
                        color: Qt.rgba(2/255, 6/255, 23/255, 0.85)
                        border.width: 1
                        border.color: Qt.rgba(colCyan.r, colCyan.g, colCyan.b, 0.4)
                        Text {
                            id: badgeTxt
                            anchors.centerIn: parent
                            text: "3D Spiral Snapshot"
                            color: colCyan
                            font.pixelSize: 10
                            font.bold: true
                        }
                    }
                }

                // Caption / Tweet Text
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "Post Commentary (Pre-filled with Emergence):"
                            color: colMuted
                            font.pixelSize: 11
                            font.bold: true
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: shareCaptionArea.text.length + " chars"
                            color: shareCaptionArea.text.length > 280 ? "#ef4444" : colMuted
                            font.pixelSize: 11
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 80
                        radius: 8
                        color: "#020617"
                        border.width: 1
                        border.color: shareCaptionArea.activeFocus ? colCyan : "#334155"

                        ScrollView {
                            anchors.fill: parent
                            anchors.margins: 6
                            clip: true

                            TextArea {
                                id: shareCaptionArea
                                text: shareCaption
                                color: colForeground
                                font.pixelSize: 12
                                wrapMode: TextEdit.Wrap
                                background: null
                                onTextChanged: shareCaption = text
                            }
                        }
                    }
                }

                // Actions
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Rectangle {
                        height: 38
                        width: cancelTxt.implicitWidth + 28
                        radius: 8
                        color: cancelShareMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.08) : Qt.rgba(255, 255, 255, 0.04)
                        border.width: 1
                        border.color: "#334155"
                        Text { id: cancelTxt; anchors.centerIn: parent; text: "Cancel"; color: colMuted; font.pixelSize: 12 }
                        MouseArea {
                            id: cancelShareMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: shareModalVisible = false
                        }
                    }

                    Rectangle {
                        height: 38
                        width: copyImgTxt.implicitWidth + 28
                        radius: 8
                        color: copyImgMouse.containsMouse ? Qt.rgba(colCyan.r, colCyan.g, colCyan.b, 0.2) : Qt.rgba(colCyan.r, colCyan.g, colCyan.b, 0.1)
                        border.width: 1
                        border.color: colCyan
                        Text { id: copyImgTxt; anchors.centerIn: parent; text: "📋 Copy Image"; color: colCyan; font.bold: true; font.pixelSize: 12 }
                        MouseArea {
                            id: copyImgMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (sharePreviewPath) {
                                    executeShellCommand("wl-copy -t image/png < " + escapeShell(sharePreviewPath));
                                    showCanvasToast("📋 Image copied to clipboard!");
                                }
                            }
                        }
                    }

                    Rectangle {
                        height: 38
                        width: saveImgTxt.implicitWidth + 28
                        radius: 8
                        color: saveImgMouse.containsMouse ? Qt.rgba(colPast.r, colPast.g, colPast.b, 0.2) : Qt.rgba(colPast.r, colPast.g, colPast.b, 0.1)
                        border.width: 1
                        border.color: colPast
                        Text { id: saveImgTxt; anchors.centerIn: parent; text: "💾 Save PNG"; color: colPast; font.bold: true; font.pixelSize: 12 }
                        MouseArea {
                            id: saveImgMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                showCanvasToast("💾 Saved to " + getPicturesDirectory());
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        height: 38
                        width: postXRow.implicitWidth + 32
                        radius: 8
                        color: postXMouse.containsMouse ? "#18181b" : "#000000"
                        border.width: 1.5
                        border.color: "#ffffff"

                        Row {
                            id: postXRow
                            anchors.centerIn: parent
                            spacing: 8
                            Text {
                                text: "𝕏"
                                color: "#ffffff"
                                font.pixelSize: 15
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: "Post to X"
                                color: "#ffffff"
                                font.bold: true
                                font.pixelSize: 13
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: postXMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: submitPostToX()
                        }
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
        visible: isCheckinModalOpen
        color: Qt.rgba(2/255, 6/255, 23/255, 0.92)

        MouseArea {
            anchors.fill: parent
            // block clicks behind modal
        }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(520, parent.width - 40)
            height: checkinCol.implicitHeight + 48
            radius: 20
            color: "#0b1226"
            border.width: 1.5
            border.color: Qt.rgba(colCyan.r, colCyan.g, colCyan.b, 0.4)

            ColumnLayout {
                id: checkinCol
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 28
                spacing: 20

                // Header
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    RowLayout {
                        spacing: 8
                        Text { text: "🎯"; font.pixelSize: 22 }
                        Text {
                            text: "Quick Check-in"
                            color: colForeground
                            font.pixelSize: 20
                            font.bold: true
                        }
                    }

                    Text {
                        text: "Take a moment to notice where you are right now."
                        color: colMuted
                        font.pixelSize: 13
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: colBorder }

                // Clarity Slider Group (Foggy -> Clear)
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: "Clarity"
                        color: colCyan
                        font.bold: true
                        font.pixelSize: 14
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            text: "Foggy"
                            color: colMuted
                            font.italic: true
                            font.pixelSize: 12
                            Layout.preferredWidth: 44
                        }

                        Slider {
                            Layout.fillWidth: true
                            from: 1
                            to: 10
                            stepSize: 1
                            value: preClarity
                            onValueChanged: {
                                preClarity = Math.round(value);
                                if (currentStepIndex === 0) postClarity = preClarity;
                            }
                        }

                        Text {
                            text: "Clear"
                            color: colMuted
                            font.italic: true
                            font.pixelSize: 12
                            horizontalAlignment: Text.AlignRight
                            Layout.preferredWidth: 44
                        }
                    }
                }

                // Movement Slider Group (Stuck -> Flowing)
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: "Movement"
                        color: colCyan
                        font.bold: true
                        font.pixelSize: 14
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            text: "Stuck"
                            color: colMuted
                            font.italic: true
                            font.pixelSize: 12
                            Layout.preferredWidth: 44
                        }

                        Slider {
                            Layout.fillWidth: true
                            from: 1
                            to: 10
                            stepSize: 1
                            value: preMovement
                            onValueChanged: {
                                preMovement = Math.round(value);
                                preFocus = preMovement;
                                if (currentStepIndex === 0) {
                                    postMovement = preMovement;
                                    postFocus = preMovement;
                                }
                            }
                        }

                        Text {
                            text: "Flowing"
                            color: colMuted
                            font.italic: true
                            font.pixelSize: 12
                            horizontalAlignment: Text.AlignRight
                            Layout.preferredWidth: 44
                        }
                    }
                }

                Item { height: 6 }

                // Begin Session Button
                Rectangle {
                    Layout.fillWidth: true
                    height: 44
                    radius: 10
                    color: colGold

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8
                        Text {
                            text: "Begin Session →"
                            color: "#020617"
                            font.bold: true
                            font.pixelSize: 14
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            isCheckinModalOpen = false;
                            saveFinalMetrics();
                        }
                    }
                }
            }
        }
    }
}
