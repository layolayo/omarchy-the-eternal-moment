// ProcessData.js - The Eternal Moment (Process #4) Engine Definition

var questionLibrary = {
    p4_starter: {
        text: "And, where are you now?",
        label: "Initial Now",
        type: "now"
    },
    now: {
        text: "And, where are you now?",
        label: "Now Shift",
        type: "now"
    },
    awehyb: {
        text: "And, where [else] have you been?",
        label: "Past Location / Memory",
        type: "past"
    },
    awemyb: {
        text: "And, where [else] might you be?",
        label: "Future Possibility",
        type: "future"
    },
    cta: {
        text: "And, compare [A] to [B]",
        label: "Comparative Reflection",
        type: "compare"
    },
    review: {
        text: "Please review your session reflections before the final inquiry.",
        label: "Session Review",
        type: "review"
    },
    awitdbwykatsawykn: {
        text: "And, what is the difference between what you knew at the start and what you know now?",
        label: "Emergent Difference",
        type: "insight"
    }
};

function buildFlatSteps() {
    var flat = [];

    // Step 0: Starter Now
    flat.push({
        id: 0,
        key: "p4_starter",
        set: 1,
        nowAnchorIndex: 0
    });

    var currentNowAnchor = 0;

    // 6 Sets of explorations
    for (var setNum = 1; setNum <= 6; setNum++) {
        if (setNum > 1) {
            // New 'Now' recognition at start of sets 2-6
            var nowStepIndex = flat.length;
            flat.push({
                id: nowStepIndex,
                key: "now",
                set: setNum,
                nowAnchorIndex: nowStepIndex
            });
            currentNowAnchor = nowStepIndex;
        }

        // 3 iterations of Past -> Compare, Future -> Compare
        for (var r = 0; r < 3; r++) {
            // Past
            var pastIdx = flat.length;
            flat.push({
                id: pastIdx,
                key: "awehyb",
                set: setNum,
                nowAnchorIndex: currentNowAnchor
            });

            // Compare Past to Now
            flat.push({
                id: flat.length,
                key: "cta",
                set: setNum,
                compareTargetIndex: pastIdx,
                nowAnchorIndex: currentNowAnchor
            });

            // Future
            var futIdx = flat.length;
            flat.push({
                id: futIdx,
                key: "awemyb",
                set: setNum,
                nowAnchorIndex: currentNowAnchor
            });

            // Compare Future to Now
            flat.push({
                id: flat.length,
                key: "cta",
                set: setNum,
                compareTargetIndex: futIdx,
                nowAnchorIndex: currentNowAnchor
            });
        }
    }

    // Step 79: Review bridge
    flat.push({
        id: flat.length,
        key: "review",
        set: 6,
        nowAnchorIndex: currentNowAnchor
    });

    // Step 80: Final Insight Question
    flat.push({
        id: flat.length,
        key: "awitdbwykatsawykn",
        set: 6,
        nowAnchorIndex: 0, // Compares start to end
        compareTargetIndex: currentNowAnchor
    });

    return flat;
}

function truncateWords(str, maxWords) {
    if (!str) return "";
    var words = str.trim().split(/\s+/);
    if (words.length > maxWords) {
        return words.slice(0, maxWords).join(" ") + "...";
    }
    return str;
}

function formatQuestionText(step, answers, flatSteps) {
    var qDef = questionLibrary[step.key];
    if (!qDef) return "";
    var text = qDef.text;

    // Handle [else]
    var prevKeyCount = 0;
    for (var i = 0; i < step.id; i++) {
        if (flatSteps[i] && flatSteps[i].key === step.key && answers[i]) {
            prevKeyCount++;
        }
    }
    text = text.replace("[else]", prevKeyCount > 0 ? "else " : "");

    // Handle [A] and [B]
    if (step.key === "cta") {
        var prevAns = answers[step.id - 1] || "that";
        var nowAns = answers[step.nowAnchorIndex] || "where you are now";

        var cleanA = truncateWords(prevAns, 6);
        var cleanB = truncateWords(nowAns, 6);

        text = text.replace("[A]", "'" + cleanA + "'");
        text = text.replace("[B]", "'" + cleanB + "'");
    }

    return text;
}

function getPlaceholder(stepKey) {
    if (stepKey === "awehyb" || stepKey === "awemyb") {
        return "who, what, where and when...";
    } else if (stepKey === "cta") {
        return "Note similarities and differences...";
    } else if (stepKey === "review") {
        return "";
    } else {
        return "write your answer...";
    }
}

function getButtonText(stepIndex, stepKey) {
    if (stepIndex === 0) return "Launch";
    if (stepKey === "cta") return "Compare";
    if (stepKey === "now") return "Acknowledge Now";
    if (stepKey === "review") return "Review & Continue";
    return "Continue";
}

function getProgressSubtitle(stepKey) {
    if (stepKey === "p4_starter" || stepKey === "now") return "Defining the present moment";
    if (stepKey === "awehyb") return "Recalling the past";
    if (stepKey === "awemyb") return "Possibilities of the future";
    if (stepKey === "cta") return "Synthesising connections";
    if (stepKey === "review") return "Reviewing...";
    if (stepKey === "awitdbwykatsawykn") return "Synthesising emergence";
    return "Exploring awareness";
}

function getStepExample(stepKey) {
    if (stepKey === "p4_starter" || stepKey === "now") {
        return "e.g. In life, where are you now? (a situation, state or condition, place, identity, or mood)";
    }
    if (stepKey === "awehyb") {
        return "e.g. In the past / earlier in life: who was there, what happened, where were you, and when?";
    }
    if (stepKey === "awemyb") {
        return "e.g. In the future / later in life: what possibilities, directions, or choices might open up?";
    }
    if (stepKey === "cta") {
        return "e.g. Notice what is similar and what is different between that time and where you are now.";
    }
    if (stepKey === "awitdbwykatsawykn") {
        return "e.g. Notice what has shifted or emerged across the journey from your first 'Now' to where you stand now.";
    }
    return "";
}

