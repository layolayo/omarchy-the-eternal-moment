// Report.js - Markdown report generator and social sharing helper

var MAX_ANSWER_REPORT_LEN = 1500;   // Bounded answer length per step in markdown
var MAX_TOTAL_REPORT_LEN = 48000;   // Overall markdown report size ceiling (48KB)
var MAX_FEEDBACK_REPORT_LEN = 2000; // Reflections text ceiling
var MAX_TWEET_INSIGHT_LEN = 180;    // Social share text ceiling

function sanitizeString(str, maxLen) {
    if (str === undefined || str === null) return "";
    var s = String(str);
    return s.length > maxLen ? s.substring(0, maxLen) : s;
}

function normalizePct(val) {
    if (val === undefined || val === null) return 50;
    val = Number(val);
    if (isNaN(val)) return 50;
    if (val <= 10 && val > 0) return Math.round(val * 10);
    return Math.max(0, Math.min(100, Math.round(val)));
}

function generateMarkdownReport(session, flatSteps, questionLibrary) {
    if (!session) return "";

    var lines = [];
    lines.push("# The Eternal Moment: Process #4 · Session Record");
    lines.push("");
    lines.push("**Session ID**: `" + sanitizeString(session.uuid || ("session-" + session.id), 64) + "`");
    lines.push("**Recorded**: " + sanitizeString(session.created_at || new Date().toISOString(), 40));
    var totalSteps = (flatSteps && flatSteps.length > 0) ? Math.min(flatSteps.length, 85) : 80;
    lines.push("**Status**: " + (session.status === "completed" ? "✅ Completed" : "⏳ In Progress (Step " + Math.min(totalSteps, (session.current_step || 0) + 1) + "/" + totalSteps + ")"));
    lines.push("");

    var preClar = normalizePct(session.pre_clarity);
    var postClar = normalizePct(session.post_clarity);
    var preMov = normalizePct(session.pre_movement !== undefined ? session.pre_movement : session.pre_focus);
    var postMov = normalizePct(session.post_movement !== undefined ? session.post_movement : session.post_focus);

    lines.push("### 1. Initial State & Calibration");
    lines.push("- **Where are you now?**: *" + sanitizeString(session.now_start || "(Unanswered)", MAX_ANSWER_REPORT_LEN) + "*");
    lines.push("- **Pre-Session Calibration**:");
    lines.push("  - Clarity: `" + preClar + "%` (Foggy → Clear)");
    lines.push("  - Movement: `" + preMov + "%` (Stuck → Flowing)");
    lines.push("");

    lines.push("### 2. The Evolutionary Cycle (Sets 1 to 6)");
    lines.push("");

    var currentSet = 0;
    var answers = session.answers || [];
    var stepsCount = flatSteps ? Math.min(flatSteps.length, 85) : 0;

    for (var i = 0; i < stepsCount; i++) {
        var step = flatSteps[i];
        if (!step) continue;
        if (step.key === "review") continue;

        if (step.set !== currentSet && step.set <= 6) {
            currentSet = step.set;
            lines.push("#### Set " + currentSet);
        }

        var rawAns = answers[step.id];
        if (!rawAns) continue;
        var ans = sanitizeString(rawAns, MAX_ANSWER_REPORT_LEN);
        if (ans.length === 0) continue;

        var qDef = (questionLibrary && questionLibrary[step.key]) ? questionLibrary[step.key] : { label: step.key, text: step.key };
        
        if (step.key === "now" || step.key === "p4_starter") {
            lines.push("> **" + (step.stepTitle || qDef.label) + "**: *" + ans + "*");
        } else if (step.key === "awehyb") {
            lines.push("- **Past**: " + ans);
        } else if (step.key === "awemyb") {
            lines.push("- **Future**: " + ans);
        } else if (step.key === "cta") {
            if (step.compareTargetIndex === 0) {
                lines.push("");
                lines.push("### 3. The 1–7 Temporal Comparison (Now 1 vs Now 7)");
                lines.push("**And, compare what you knew at the start to where you are now:**");
                lines.push("> *" + ans + "*");
                lines.push("");
            } else {
                lines.push("  - *Comparison*: " + ans);
            }
        } else if (step.key === "awitdbwykatsawykn") {
            lines.push("");
            lines.push("### 4. The Emergent Difference");
            lines.push("**And, what is the difference between what you knew at the start and what you know now?**");
            lines.push("");
            lines.push("> ### *" + ans + "*");
            lines.push("");
        }
    }

    lines.push("### 5. Integration & Metrics Shift");
    var dClarity = postClar - preClar;
    var dMovement = postMov - preMov;
    var fmtDiff = function(n) { return (n >= 0 ? "+" + n : "" + n) + "%"; };

    lines.push("- **Post-Session Metrics**:");
    lines.push("  - Clarity: `" + postClar + "%` (Shift: `" + fmtDiff(dClarity) + "`, Foggy → Clear)");
    lines.push("  - Movement: `" + postMov + "%` (Shift: `" + fmtDiff(dMovement) + "`, Stuck → Flowing)");

    if (session.tags && Array.isArray(session.tags) && session.tags.length > 0) {
        var safeTags = [];
        for (var t = 0; t < Math.min(session.tags.length, 20); t++) {
            var tagStr = sanitizeString(session.tags[t], 50).trim();
            if (tagStr) safeTags.push(tagStr);
        }
        if (safeTags.length > 0) {
            lines.push("- **Emergence Themes**: `" + safeTags.join("`, `") + "`");
        }
    }

    if (session.feedback) {
        lines.push("- **Session Reflections**: " + sanitizeString(session.feedback, MAX_FEEDBACK_REPORT_LEN));
    }

    lines.push("");
    lines.push("---");
    lines.push("*Facilitated via The Eternal Moment (Process #4) · Emergent Knowledge*");

    var report = lines.join("\n");
    if (report.length > MAX_TOTAL_REPORT_LEN) {
        report = report.substring(0, MAX_TOTAL_REPORT_LEN - 60) + "\n\n[Report truncated to 48KB ceiling]";
    }
    return report;
}

function generateTweetText(session) {
    if (!session) return "";
    var rawInsight = session.final_insight || (session.answers && (session.answers[80] || session.answers[79]) ? (session.answers[80] || session.answers[79]) : "");
    var insight = sanitizeString(rawInsight, MAX_TWEET_INSIGHT_LEN);
    if (insight.length > 175) {
        insight = insight.substring(0, 172) + "...";
    }

    var text = "Process #4 Emergence:\n\"" + (insight || "The space between what I knew at the start and what I know now.") + "\"\n\n#EmergentKnowledge #Process4 #CleanLanguage";
    return text;
}

function generateXIntentUrl(session) {
    var tweet = generateTweetText(session);
    return "https://x.com/intent/post?text=" + encodeURIComponent(tweet);
}
