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
    var nowCount = 0;
    var pastCount = 0;
    var futureCount = 0;
    var compareCount = 0;

    // Step 0: Starter Now
    nowCount++;
    flat.push({
        id: 0,
        key: "p4_starter",
        set: 1,
        stepNumber: nowCount,
        stepTitle: "Now " + nowCount,
        nowAnchorIndex: 0
    });

    var currentNowAnchor = 0;

    // 6 Sets of explorations
    for (var setNum = 1; setNum <= 6; setNum++) {
        if (setNum > 1) {
            // New 'Now' recognition at start of sets 2-6
            var nowStepIndex = flat.length;
            nowCount++;
            flat.push({
                id: nowStepIndex,
                key: "now",
                set: setNum,
                stepNumber: nowCount,
                stepTitle: "Now " + nowCount,
                nowAnchorIndex: nowStepIndex
            });
            currentNowAnchor = nowStepIndex;
        }

        // 3 iterations of Past -> Compare, Future -> Compare
        for (var r = 0; r < 3; r++) {
            // Past
            var pastIdx = flat.length;
            pastCount++;
            flat.push({
                id: pastIdx,
                key: "awehyb",
                set: setNum,
                stepNumber: pastCount,
                stepTitle: "Past " + pastCount,
                nowAnchorIndex: currentNowAnchor
            });

            // Compare Past to Now
            var ctaPastIdx = flat.length;
            compareCount++;
            flat.push({
                id: ctaPastIdx,
                key: "cta",
                set: setNum,
                stepNumber: compareCount,
                stepTitle: "Compare " + compareCount,
                compareTargetIndex: pastIdx,
                nowAnchorIndex: currentNowAnchor
            });

            // Future
            var futIdx = flat.length;
            futureCount++;
            flat.push({
                id: futIdx,
                key: "awemyb",
                set: setNum,
                stepNumber: futureCount,
                stepTitle: "Future " + futureCount,
                nowAnchorIndex: currentNowAnchor
            });

            // Compare Future to Now
            var ctaFutIdx = flat.length;
            compareCount++;
            flat.push({
                id: ctaFutIdx,
                key: "cta",
                set: setNum,
                stepNumber: compareCount,
                stepTitle: "Compare " + compareCount,
                compareTargetIndex: futIdx,
                nowAnchorIndex: currentNowAnchor
            });
        }
    }

    // Step 79 (index 78): Now 7 - Final Now recognition after 6 complete sets
    var now7Idx = flat.length;
    nowCount++; // nowCount = 7
    flat.push({
        id: now7Idx,
        key: "now",
        set: 6,
        stepNumber: nowCount,
        stepTitle: "Now " + nowCount,
        nowAnchorIndex: now7Idx
    });

    // Step 80 (index 79): 1-7 Temporal Comparison (Compare Now 1 to Now 7)
    var cta1to7Idx = flat.length;
    compareCount++; // compareCount = 37
    flat.push({
        id: cta1to7Idx,
        key: "cta",
        set: 6,
        stepNumber: compareCount,
        stepTitle: "Compare " + compareCount,
        compareTargetIndex: 0, // Now 1 (start)
        nowAnchorIndex: now7Idx // Now 7 (now)
    });

    // Step 81 (index 80): Final Emergent Insight Question
    flat.push({
        id: flat.length,
        key: "awitdbwykatsawykn",
        set: 6,
        stepNumber: 1,
        stepTitle: "Emergent Insight",
        compareTargetIndex: 0, // Now 1 (start)
        nowAnchorIndex: now7Idx // Now 7 (now)
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
        var targetAIdx = (step.compareTargetIndex !== undefined) ? step.compareTargetIndex : (step.id - 1);
        var targetBIdx = (step.nowAnchorIndex !== undefined) ? step.nowAnchorIndex : step.id;

        var prevAns = answers[targetAIdx] || (step.compareTargetIndex === 0 ? "where you started" : "that");
        var nowAns = answers[targetBIdx] || "where you are now";

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
    if (stepKey === "awitdbwykatsawykn" || stepIndex >= 80) return "Finish with Metrics ★";
    if (stepKey === "cta") return "Compare";
    if (stepKey === "now") return "Acknowledge Now";
    if (stepKey === "review") return "Review & Continue";
    return "Continue";
}

function getProgressSubtitle(stepKey, step) {
    if (step && step.key === "cta" && step.compareTargetIndex === 0) return "1-7 Temporal Comparison";
    if (stepKey === "p4_starter" || stepKey === "now") return "Defining the present moment";
    if (stepKey === "awehyb") return "Recalling the past";
    if (stepKey === "awemyb") return "Possibilities of the future";
    if (stepKey === "cta") return "Synthesising connections";
    if (stepKey === "review") return "Reviewing...";
    if (stepKey === "awitdbwykatsawykn") return "Synthesising emergence";
    return "Exploring awareness";
}

function getStepExample(stepKey, step) {
    if (step && step.key === "cta" && step.compareTargetIndex === 0) {
        return "e.g. Compare where you were at the start (Now 1) to where you are now (Now 7). What shifts, echoes, or expansions stand out?";
    }
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
        return "e.g. Grounded on your 1–7 comparison, notice what has emerged across your entire journey from the first Now to where you stand now.";
    }
    return "";
}

