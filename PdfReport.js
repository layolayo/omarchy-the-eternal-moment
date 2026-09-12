// PdfReport.js - Pure JavaScript Vector PDF Generator for The Eternal Moment
// Standards-compliant PDF 1.4 output with zero external dependencies

var PAGE_WIDTH = 595;
var PAGE_HEIGHT = 842; // A4 standard in points (72 points/inch)
var MARGIN_LEFT = 50;
var MARGIN_RIGHT = 50;
var MARGIN_TOP = 50;
var MARGIN_BOTTOM = 55;
var CONTENT_WIDTH = PAGE_WIDTH - MARGIN_LEFT - MARGIN_RIGHT; // 495
var MAX_PAGES = 25;

function escapePdfText(str) {
    if (!str) return "";
    return String(str)
        .replace(/\\/g, "\\\\")
        .replace(/\(/g, "\\(")
        .replace(/\)/g, "\\)")
        .replace(/[\r\n]+/g, " ")
        .replace(/[^\x20-\x7E]/g, function(ch) {
            if (ch === '’' || ch === '‘') return "'";
            if (ch === '“' || ch === '”') return '"';
            if (ch === '—' || ch === '–') return '-';
            if (ch === '•') return '*';
            if (ch === '…') return '...';
            if (ch === '·') return '-';
            return ' ';
        });
}

function wrapText(text, maxChars) {
    if (!text) return [];
    var words = String(text).split(/\s+/);
    var lines = [];
    var current = "";
    for (var i = 0; i < words.length; i++) {
        var word = words[i];
        if (!word) continue;
        if (!current) {
            current = word;
        } else if ((current.length + 1 + word.length) <= maxChars) {
            current += " " + word;
        } else {
            lines.push(current);
            current = word;
        }
    }
    if (current) lines.push(current);
    return lines;
}

function normalizePct(val) {
    if (val === undefined || val === null) return 50;
    val = Number(val);
    if (isNaN(val)) return 50;
    if (val <= 10 && val > 0) return Math.round(val * 10);
    return Math.max(0, Math.min(100, Math.round(val)));
}

function generatePdf(session, flatSteps, questionLibrary) {
    if (!session) return "";

    var pagesOps = [];
    var currentOps = [];
    var currentY = PAGE_HEIGHT - MARGIN_TOP;

    function newPage() {
        if (currentOps.length > 0) {
            pagesOps.push(currentOps.join("\n"));
        }
        currentOps = [];
        currentY = PAGE_HEIGHT - MARGIN_TOP;
        if (pagesOps.length > 0) {
            currentOps.push("BT /F3 8 Tf 0.5 0.5 0.5 rg " + MARGIN_LEFT + " 805 Td (The Eternal Moment: Process #4 -- Session Record) Tj ET");
            currentOps.push("0.8 0.8 0.8 RG 0.5 w " + MARGIN_LEFT + " 798 m " + (PAGE_WIDTH - MARGIN_RIGHT) + " 798 l S");
            currentY = 780;
        }
    }

    function checkSpace(needed) {
        if (currentY - needed < MARGIN_BOTTOM) {
            newPage();
        }
    }

    function drawText(text, font, size, x, r, g, b) {
        r = r !== undefined ? r : 0.1;
        g = g !== undefined ? g : 0.1;
        b = b !== undefined ? b : 0.1;
        var safe = escapePdfText(text);
        currentOps.push("BT /" + font + " " + size + " Tf " + r + " " + g + " " + b + " rg " + x + " " + currentY + " Td (" + safe + ") Tj ET");
    }

    function addLine(r, g, b, lineWidth) {
        r = r !== undefined ? r : 0.7;
        g = g !== undefined ? g : 0.7;
        b = b !== undefined ? b : 0.7;
        lineWidth = lineWidth || 0.5;
        currentOps.push(r + " " + g + " " + b + " RG " + lineWidth + " w " + MARGIN_LEFT + " " + currentY + " m " + (PAGE_WIDTH - MARGIN_RIGHT) + " " + currentY + " l S");
    }

    newPage();

    // Top Brand Title Banner
    currentOps.push("0.05 0.08 0.15 rg " + MARGIN_LEFT + " " + (currentY - 45) + " " + CONTENT_WIDTH + " 55 re f");
    currentOps.push("BT /F2 18 Tf 0.95 0.85 0.45 rg " + (MARGIN_LEFT + 15) + " " + (currentY - 22) + " Td (The Eternal Moment: Process #4) Tj ET");
    currentOps.push("BT /F1 9.5 Tf 0.85 0.9 0.95 rg " + (MARGIN_LEFT + 15) + " " + (currentY - 37) + " Td (Emergent Knowledge & Clean Language -- Session Record) Tj ET");
    currentY -= 65;

    // Session Metadata
    var sessUuid = session.uuid || ("session-" + session.id);
    var dateStr = session.created_at || new Date().toISOString();
    var statusStr = session.status === "completed" ? "Completed" : "In Progress";
    drawText("Session ID: " + sessUuid, "F2", 9, MARGIN_LEFT, 0.3, 0.3, 0.4);
    currentY -= 13;
    drawText("Recorded: " + dateStr + "   |   Status: " + statusStr, "F1", 8.5, MARGIN_LEFT, 0.4, 0.4, 0.45);
    currentY -= 12;

    // Calibration Shift Box
    var preClar = normalizePct(session.pre_clarity);
    var postClar = normalizePct(session.post_clarity);
    var preMov = normalizePct(session.pre_movement !== undefined ? session.pre_movement : session.pre_focus);
    var postMov = normalizePct(session.post_movement !== undefined ? session.post_movement : session.post_focus);
    var dClar = postClar - preClar;
    var dMov = postMov - preMov;
    var fmtDiff = function(n) { return (n >= 0 ? "+" + n : "" + n) + "%"; };

    currentOps.push("0.96 0.97 0.99 rg " + MARGIN_LEFT + " " + (currentY - 35) + " " + CONTENT_WIDTH + " 38 re f");
    currentOps.push("0.85 0.88 0.92 RG 1 w " + MARGIN_LEFT + " " + (currentY - 35) + " " + CONTENT_WIDTH + " 38 re S");
    
    currentOps.push("BT /F2 9.5 Tf 0.15 0.25 0.4 rg " + (MARGIN_LEFT + 12) + " " + (currentY - 15) + " Td (Calibration Metrics Shift:) Tj ET");
    var metricsLine = "Pre: Clarity " + preClar + "% / Flow " + preMov + "%   -->   Post: Clarity " + postClar + "% / Flow " + postMov + "%   (Shift: Clarity " + fmtDiff(dClar) + ", Flow " + fmtDiff(dMov) + ")";
    currentOps.push("BT /F1 9 Tf 0.2 0.3 0.35 rg " + (MARGIN_LEFT + 12) + " " + (currentY - 28) + " Td (" + escapePdfText(metricsLine) + ") Tj ET");
    currentY -= 50;

    // Initial Starter Question
    checkSpace(40);
    drawText("1. INITIAL THRESHOLD: WHERE ARE YOU NOW?", "F2", 11, MARGIN_LEFT, 0.1, 0.2, 0.35);
    currentY -= 14;
    var starterAns = session.now_start || (session.answers && session.answers[0]) || "(Unanswered)";
    var starterLines = wrapText(starterAns, 80);
    for (var s = 0; s < starterLines.length; s++) {
        checkSpace(14);
        drawText(starterLines[s], "F3", 9.5, MARGIN_LEFT + 12, 0.2, 0.25, 0.35);
        currentY -= 13;
    }
    currentY -= 10;
    addLine(0.85, 0.85, 0.9, 0.5);
    currentY -= 12;

    // Sets 1 to 6
    var currentSet = 0;
    var answers = session.answers || [];
    var stepsCount = flatSteps ? Math.min(flatSteps.length, 85) : 0;

    for (var i = 0; i < stepsCount; i++) {
        var step = flatSteps[i];
        if (!step) continue;
        if (step.key === "review") continue;

        if (step.set !== currentSet && step.set <= 6) {
            currentSet = step.set;
            checkSpace(35);
            currentY -= 6;
            drawText("SET " + currentSet, "F2", 11, MARGIN_LEFT, 0.15, 0.35, 0.55);
            currentY -= 13;
            addLine(0.88, 0.9, 0.94, 0.75);
            currentY -= 10;
        }

        var rawAns = answers[step.id];
        if (!rawAns) continue;
        var ansStr = String(rawAns).trim();
        if (ansStr.length === 0) continue;

        var qDef = (questionLibrary && questionLibrary[step.key]) ? questionLibrary[step.key] : { label: step.key, text: step.key };
        var qLabel = (step.stepTitle || qDef.label);
        var isSpecial = (step.key === "cta" && step.compareTargetIndex === 0) || (step.key === "awitdbwykatsawykn");

        if (isSpecial) {
            checkSpace(55);
            currentY -= 4;
            var ansWrapped = wrapText(ansStr, 76);
            var boxHeight = 24 + ansWrapped.length * 13;
            currentOps.push("0.99 0.97 0.92 rg " + MARGIN_LEFT + " " + (currentY - boxHeight + 8) + " " + CONTENT_WIDTH + " " + boxHeight + " re f");
            currentOps.push("0.9 0.75 0.3 RG 1 w " + MARGIN_LEFT + " " + (currentY - boxHeight + 8) + " " + CONTENT_WIDTH + " " + boxHeight + " re S");
            
            var highlightTitle = step.key === "cta" ? "TEMPORAL COMPARISON (Now 1 vs Now 7):" : "THE EMERGENT DIFFERENCE:";
            currentOps.push("BT /F2 9.5 Tf 0.6 0.4 0.05 rg " + (MARGIN_LEFT + 10) + " " + (currentY - 6) + " Td (" + escapePdfText(highlightTitle) + ") Tj ET");
            currentY -= 18;
            for (var h = 0; h < ansWrapped.length; h++) {
                drawText(ansWrapped[h], "F2", 9.5, MARGIN_LEFT + 15, 0.15, 0.15, 0.2);
                currentY -= 13;
            }
            currentY -= 10;
        } else {
            checkSpace(28);
            var tagPrefix = step.key === "awehyb" ? "[Past] " : (step.key === "awemyb" ? "[Future] " : (step.key === "cta" ? "[Compare] " : ""));
            drawText(tagPrefix + qLabel, "F2", 9, MARGIN_LEFT + 4, 0.25, 0.3, 0.4);
            currentY -= 12;

            var wrapped = wrapText(ansStr, 80);
            for (var w = 0; w < wrapped.length; w++) {
                checkSpace(14);
                drawText(wrapped[w], "F1", 9, MARGIN_LEFT + 16, 0.15, 0.15, 0.2);
                currentY -= 12;
            }
            currentY -= 4;
        }
    }

    // Integration & Reflections
    if ((session.tags && session.tags.length > 0) || session.feedback) {
        checkSpace(50);
        currentY -= 8;
        drawText("INTEGRATION & REFLECTIONS", "F2", 11, MARGIN_LEFT, 0.1, 0.2, 0.35);
        currentY -= 14;
        addLine(0.85, 0.85, 0.9, 0.5);
        currentY -= 10;

        if (session.tags && session.tags.length > 0) {
            checkSpace(18);
            drawText("Emergence Themes: " + session.tags.join(", "), "F2", 9, MARGIN_LEFT + 8, 0.2, 0.4, 0.5);
            currentY -= 14;
        }

        if (session.feedback) {
            checkSpace(25);
            drawText("User Reflections:", "F2", 9, MARGIN_LEFT + 8, 0.3, 0.3, 0.35);
            currentY -= 12;
            var fWrapped = wrapText(session.feedback, 80);
            for (var fb = 0; fb < fWrapped.length; fb++) {
                checkSpace(14);
                drawText(fWrapped[fb], "F3", 9, MARGIN_LEFT + 16, 0.2, 0.2, 0.25);
                currentY -= 12;
            }
        }
    }

    if (currentOps.length > 0) {
        pagesOps.push(currentOps.join("\n"));
    }

    var totalPages = Math.min(pagesOps.length, MAX_PAGES);
    var finalPagesContent = [];

    for (var p = 0; p < totalPages; p++) {
        var pageNum = p + 1;
        var footerOps = [];
        footerOps.push("0.8 0.8 0.8 RG 0.5 w " + MARGIN_LEFT + " 45 m " + (PAGE_WIDTH - MARGIN_RIGHT) + " 45 l S");
        footerOps.push("BT /F3 8 Tf 0.5 0.5 0.5 rg " + MARGIN_LEFT + " 32 Td (Facilitated via The Eternal Moment (Process #4) -- ekology.co.uk) Tj ET");
        var pageStr = "Page " + pageNum + " of " + totalPages;
        footerOps.push("BT /F1 8 Tf 0.5 0.5 0.5 rg " + (PAGE_WIDTH - MARGIN_RIGHT - 55) + " 32 Td (" + pageStr + ") Tj ET");
        finalPagesContent.push(pagesOps[p] + "\n" + footerOps.join("\n"));
    }

    var pageCount = finalPagesContent.length;
    var fontF1 = 3 + pageCount * 2;
    var fontF2 = fontF1 + 1;
    var fontF3 = fontF1 + 2;

    var body = [];
    var offsets = {};

    function addObj(num, content) {
        offsets[num] = body.join("").length;
        body.push(num + " 0 obj\n" + content + "\nendobj\n");
    }

    body.push("%PDF-1.4\n");
    addObj(1, "<< /Type /Catalog /Pages 2 0 R >>");
    var kids = [];
    for (var k = 0; k < pageCount; k++) {
        kids.push((3 + k * 2) + " 0 R");
    }
    addObj(2, "<< /Type /Pages /Kids [" + kids.join(" ") + "] /Count " + pageCount + " >>");

    for (var pg = 0; pg < pageCount; pg++) {
        var pageObj = 3 + pg * 2;
        var streamObj = pageObj + 1;
        addObj(pageObj, "<<\n  /Type /Page\n  /Parent 2 0 R\n  /MediaBox [0 0 595 842]\n  /Resources <<\n    /Font <<\n      /F1 " + fontF1 + " 0 R\n      /F2 " + fontF2 + " 0 R\n      /F3 " + fontF3 + " 0 R\n    >>\n  >>\n  /Contents " + streamObj + " 0 R\n>>");
        var streamStr = finalPagesContent[pg];
        addObj(streamObj, "<< /Length " + streamStr.length + " >>\nstream\n" + streamStr + "\nendstream");
    }

    addObj(fontF1, "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>");
    addObj(fontF2, "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>");
    addObj(fontF3, "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Oblique /Encoding /WinAnsiEncoding >>");

    var xrefOffset = body.join("").length;
    var totalObjs = fontF3 + 1;
    var xref = ["xref\n0 " + totalObjs + "\n0000000000 65535 f \n"];
    for (var n = 1; n < totalObjs; n++) {
        var offStr = String(offsets[n]);
        while (offStr.length < 10) offStr = "0" + offStr;
        xref.push(offStr + " 00000 n \n");
    }
    var trailer = "trailer\n<<\n  /Size " + totalObjs + "\n  /Root 1 0 R\n>>\nstartxref\n" + xrefOffset + "\n%%EOF\n";
    return body.join("") + xref.join("") + trailer;
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = { generatePdf: generatePdf };
}
