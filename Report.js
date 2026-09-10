// Report.js - Markdown report generator and social sharing helper

function generateMarkdownReport(session, flatSteps, questionLibrary) {
    if (!session) return "";

    var lines = [];
    lines.push("# The Eternal Moment: Process #4 · Session Record");
    lines.push("");
    lines.push("**Session ID**: `" + (session.uuid || "session-" + session.id) + "`");
    lines.push("**Recorded**: " + (session.created_at || new Date().toISOString()));
    var totalSteps = flatSteps ? flatSteps.length : 80;
    lines.push("**Status**: " + (session.status === "completed" ? "✅ Completed" : "⏳ In Progress (Step " + Math.min(totalSteps, (session.current_step || 0) + 1) + "/" + totalSteps + ")"));
    lines.push("");

    lines.push("### 1. Initial State & Calibration");
    lines.push("- **Where are you now?**: *" + (session.now_start || "(Unanswered)") + "*");
    lines.push("- **Pre-Session Calibration**:");
    lines.push("  - Clarity: `" + (session.pre_clarity || 5) + "/10`");
    lines.push("  - Present Focus: `" + (session.pre_focus || 5) + "/10`");
    lines.push("");

    lines.push("### 2. The Evolutionary Cycle (Sets 1 to 6)");
    lines.push("");

    var currentSet = 0;
    var answers = session.answers || [];

    for (var i = 0; i < flatSteps.length; i++) {
        var step = flatSteps[i];
        if (!step) continue;
        if (step.key === "review") continue;

        if (step.set !== currentSet && step.set <= 6) {
            currentSet = step.set;
            lines.push("#### Set " + currentSet);
        }

        var ans = answers[step.id];
        if (!ans) continue;

        var qDef = questionLibrary[step.key] || { label: step.key, text: step.key };
        
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
    var dClarity = (session.post_clarity || 5) - (session.pre_clarity || 5);
    var dFocus = (session.post_focus || 5) - (session.pre_focus || 5);
    var fmtDiff = function(n) { return (n >= 0 ? "+" + n : "" + n); };

    lines.push("- **Post-Session Metrics**:");
    lines.push("  - Clarity: `" + (session.post_clarity || 5) + "/10` (Shift: `" + fmtDiff(dClarity) + "`)");
    lines.push("  - Present Focus: `" + (session.post_focus || 5) + "/10` (Shift: `" + fmtDiff(dFocus) + "`)");

    if (session.tags && session.tags.length > 0) {
        lines.push("- **Emergence Themes**: `" + session.tags.join("`, `") + "`");
    }

    if (session.feedback) {
        lines.push("- **Session Reflections**: " + session.feedback);
    }

    lines.push("");
    lines.push("---");
    lines.push("*Facilitated via The Eternal Moment (Process #4) · Emergent Knowledge*");

    return lines.join("\n");
}

function generateTweetText(session) {
    if (!session) return "";
    var insight = session.final_insight || (session.answers && (session.answers[80] || session.answers[79]) ? (session.answers[80] || session.answers[79]) : "");
    if (insight.length > 180) {
        insight = insight.substring(0, 177) + "...";
    }

    var text = "Process #4 Emergence:\n\"" + (insight || "The space between what I knew at the start and what I know now.") + "\"\n\n#EmergentKnowledge #Process4 #CleanLanguage";
    return text;
}

function generateXIntentUrl(session) {
    var tweet = generateTweetText(session);
    return "https://x.com/intent/post?text=" + encodeURIComponent(tweet);
}
