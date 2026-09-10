// SpiralEngine.js - 3D Evolving Helix Spiral Engine for The Eternal Moment
// Reconstructed authentically from ekology/js/eternity_spiral.js and eternity_engine.js
.pragma library

var nodes = [];
var connections = [];
var rotationX = 0.22; // Default tilt
var rotationY = 0.0;
var zoom = 1.0;
var helixRadius = 260; // Distance from central spine
var verticalSpacing = 55;
var activeNodeId = null;
var hoveredNodeId = null;
var currentNowIndex = 1.0;
var targetNowIndex = 1.0;
var maxNowIndex = 1;
var showHelix = true;
var comparisonMode = null;
var draggedNode = null;
var isRotating = false;
var currentCompression = 0.45;

// Stars for the integrated cosmic backdrop
var stars = [];
var starsInitialized = false;

function initStars(w, h) {
    stars = [];
    for (var i = 0; i < 160; i++) {
        stars.push({
            x: Math.random() * (w || 1920),
            y: Math.random() * (h || 1080),
            size: Math.random() * 1.8 + 0.4,
            speed: Math.random() * 0.25 + 0.05,
            opacity: Math.random() * 0.7 + 0.3
        });
    }
    starsInitialized = true;
}

function reset(resetCamera) {
    nodes = [];
    connections = [];
    if (resetCamera !== false) {
        rotationX = 0.22;
        rotationY = 0.0;
        zoom = 1.0;
        currentNowIndex = 1.0;
        targetNowIndex = 1.0;
    }
    maxNowIndex = 1;
    activeNodeId = null;
    hoveredNodeId = null;
    comparisonMode = null;
    draggedNode = null;
    isRotating = false;
}

function addNode(type, id, label, nowIdx, stepTitle, stepNumber) {
    var node = {
        type: type, // 'now', 'past', 'future', 'insight'
        id: id,
        label: label || "",
        stepTitle: stepTitle || (type.toUpperCase() + " " + (stepNumber || (id + 1))),
        stepNumber: stepNumber || 1,
        nowIndex: nowIdx,
        opacity: 0.0,
        dragOffset: { x: 0, y: 0, z: 0 },
        orbitY: ((id * 37) % 60) - 30, // deterministic pleasant orbit variation
        lastRenderedX: 0,
        lastRenderedY: 0,
        lastRenderedScale: 1.0
    };
    if (nowIdx > maxNowIndex) maxNowIndex = nowIdx;
    nodes.push(node);
    return node;
}

function addConnection(fromId, toId, label, stepId, stepTitle, stepNumber) {
    connections.push({
        id: (stepId !== undefined) ? stepId : -1,
        fromId: fromId,
        toId: toId,
        label: label || "",
        stepTitle: stepTitle || ("Compare " + (stepNumber || 1)),
        stepNumber: stepNumber || 1,
        type: "compare",
        midX: 0,
        midY: 0,
        midScale: 1.0
    });
}

function setComparisonMode(id1, id2) {
    var n1 = null;
    var n2 = null;
    for (var i = 0; i < nodes.length; i++) {
        if (nodes[i].id === id1) n1 = nodes[i];
        if (nodes[i].id === id2) n2 = nodes[i];
    }
    if (n1 && n2) {
        comparisonMode = { node1: n1, node2: n2 };
    }
}

function clearComparisonMode() {
    comparisonMode = null;
}

function setActiveNode(id) {
    activeNodeId = id;
}

function setNowIndex(idx) {
    targetNowIndex = idx;
}

function toggleHelix(show) {
    showHelix = show;
}

function project(w, h, x, y, z) {
    // Rotate around Y (Yaw)
    var cosY = Math.cos(rotationY);
    var sinY = Math.sin(rotationY);
    var x1 = x * cosY - z * sinY;
    var z1 = x * sinY + z * cosY;

    // Rotate around X (Pitch)
    var cosX = Math.cos(rotationX);
    var sinX = Math.sin(rotationX);
    var y1 = y * cosX - z1 * sinX;
    var z2 = y * sinX + z1 * cosX;

    // Perspective factor + Zoom
    var perspective = (800 * zoom) / (800 + z2);
    if (800 + z2 < 50) perspective = 0;
    if (perspective > 20) perspective = 20;

    var centerX = w / 2;
    var centerY = h / 2;

    var screenX = centerX + x1 * perspective;
    var verticalRange = h * 0.45;
    var compressionFactor = verticalRange / 800;
    currentCompression = compressionFactor;
    var screenY = centerY + (y1 * perspective * compressionFactor);

    return { x: screenX, y: screenY, z: z2, scale: perspective };
}

function drawLensFlare(ctx, x, y, size, color) {
    ctx.save();
    var grad = ctx.createRadialGradient(x, y, 0, x, y, size);
    grad.addColorStop(0, "rgba(" + color + ", 0.5)");
    grad.addColorStop(1, "rgba(" + color + ", 0)");
    ctx.fillStyle = grad;

    // Horizontal & vertical streaks
    ctx.fillRect(x - size * 2, y - 1, size * 4, 2);
    ctx.fillRect(x - 1, y - size * 2, 2, size * 4);

    ctx.beginPath();
    ctx.arc(x, y, size, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
}

function update(w, h) {
    if (!starsInitialized && w > 0 && h > 0) {
        initStars(w, h);
    }

    // Smoothly interpolate currentNowIndex towards targetNowIndex
    var diff = targetNowIndex - currentNowIndex;
    if (Math.abs(diff) > 0.001) {
        currentNowIndex += diff * 0.04;
    } else {
        currentNowIndex = targetNowIndex;
    }

    // Update background stars
    if (stars && stars.length > 0) {
        for (var i = 0; i < stars.length; i++) {
            var s = stars[i];
            s.x -= s.speed;
            if (s.x < 0) s.x = w || 1280;
        }
    }
}

function rebuildFromSession(flatSteps, answers, currentStepIndex, preserveOffsets) {
    var savedOffsets = {};
    var shouldPreserve = (preserveOffsets !== false);
    if (shouldPreserve) {
        for (var d = 0; d < nodes.length; d++) {
            var nd = nodes[d];
            if (nd && nd.dragOffset && (nd.dragOffset.x !== 0 || nd.dragOffset.y !== 0 || (nd.dragOffset.z && nd.dragOffset.z !== 0))) {
                savedOffsets[nd.id] = {
                    x: nd.dragOffset.x,
                    y: nd.dragOffset.y,
                    z: nd.dragOffset.z || 0
                };
            }
        }
    }

    // Retain viewing angle (rotationX, rotationY, zoom, currentNowIndex) when updating or adding nodes
    reset(!shouldPreserve);
    if (!flatSteps || flatSteps.length === 0) return;

    var replayNowIndex = 1;
    var limit = Math.min(flatSteps.length, currentStepIndex);

    for (var i = 0; i <= limit; i++) {
        var step = flatSteps[i];
        if (!step) continue;
        var ansText = (answers && answers[i]) ? answers[i] : "";

        var nodeType = "now";
        if (step.key === "awehyb") nodeType = "past";
        if (step.key === "awemyb") nodeType = "future";
        if (step.key === "awitdbwykatsawykn") nodeType = "insight";

        if (step.key !== "cta" && step.key !== "review") {
            var nodeNowIndex = replayNowIndex;
            if (nodeType === "insight") nodeNowIndex = replayNowIndex + 1;
            var newNode = addNode(nodeType, step.id, ansText, nodeNowIndex, step.stepTitle, step.stepNumber);
            if (savedOffsets[step.id]) {
                newNode.dragOffset = {
                    x: savedOffsets[step.id].x,
                    y: savedOffsets[step.id].y,
                    z: savedOffsets[step.id].z
                };
            }
        } else if (step.key === "cta") {
            var fromId = (step.compareTargetIndex !== undefined) ? step.compareTargetIndex : (step.id - 1);
            var nowStepId = (step.nowAnchorIndex !== undefined) ? step.nowAnchorIndex : null;
            if (nowStepId === null) {
                for (var k = i - 1; k >= 0; k--) {
                    if (flatSteps[k].key === "now" || flatSteps[k].key === "p4_starter") {
                        nowStepId = flatSteps[k].id;
                        break;
                    }
                }
            }
            if (fromId !== null && nowStepId !== null) {
                addConnection(fromId, nowStepId, ansText, step.id, step.stepTitle, step.stepNumber);
            }
        }

        // Advance now index for future steps
        var nextStep = flatSteps[i + 1];
        if (nextStep && nextStep.key === "now") {
            replayNowIndex++;
        }
    }

    var activeStep = flatSteps[currentStepIndex];
    if (activeStep) {
        setActiveNode(activeStep.id);
        var targetLevel = 1;
        for (var m = currentStepIndex; m >= 0; m--) {
            if (flatSteps[m].key === "now" || flatSteps[m].key === "p4_starter") {
                targetLevel = flatSteps[m].stepNumber || flatSteps[m].set || 1;
                break;
            }
        }
        setNowIndex(targetLevel);
    }
}

function render(ctx, w, h, mouseX, mouseY) {
    if (!ctx || w <= 0 || h <= 0) return;

    // Responsive Helix Radius
    var scaleFactor = Math.min(w / 1000, h / 700);
    helixRadius = Math.max(160, 270 * scaleFactor);
    verticalSpacing = Math.max(35, 52 * scaleFactor);

    // Clear entire canvas frame
    ctx.clearRect(0, 0, w, h);

    // 1. Deep Space Cosmic Background
    var bgGrad = ctx.createLinearGradient(0, 0, w, h);
    bgGrad.addColorStop(0, "#020617");
    bgGrad.addColorStop(0.5, "#06091e");
    bgGrad.addColorStop(1, "#020617");
    ctx.fillStyle = bgGrad;
    ctx.fillRect(0, 0, w, h);

    // Render twinkling backdrop stars
    if (stars && stars.length > 0) {
        for (var sIdx = 0; sIdx < stars.length; sIdx++) {
            var st = stars[sIdx];
            ctx.fillStyle = "rgba(255, 255, 255, " + st.opacity + ")";
            ctx.beginPath();
            ctx.arc(st.x, st.y, st.size, 0, Math.PI * 2);
            ctx.fill();
        }
    }

    // 2. Project Nodes to 3D Screen Coordinates
    var renderedNodes = [];
    for (var nIdx = 0; nIdx < nodes.length; nIdx++) {
        var node = nodes[nIdx];
        var x = 0, y = 0, z = 0;
        var baseY = (node.nowIndex - currentNowIndex) * verticalSpacing * 6;

        if (node.type === "now" || node.type === "insight") {
            x = 0;
            y = baseY;
            z = 0;
        } else {
            var angleOffset = (node.type === "past") ? 0 : Math.PI;
            var phase = (node.id * 0.4) + angleOffset;
            x = Math.sin(phase) * helixRadius;
            z = Math.cos(phase) * helixRadius;
            y = baseY + (node.orbitY || 0);
        }

        var p = project(w, h, x + node.dragOffset.x, y + node.dragOffset.y, z + (node.dragOffset.z || 0));
        node.lastRenderedX = p.x;
        node.lastRenderedY = p.y;
        node.lastRenderedScale = p.scale;

        renderedNodes.push({
            nodeRef: node,
            type: node.type,
            id: node.id,
            label: node.label,
            stepTitle: node.stepTitle,
            stepNumber: node.stepNumber,
            nowIndex: node.nowIndex,
            orbitY: node.orbitY,
            dragOffset: node.dragOffset,
            x: p.x,
            y: p.y,
            z: p.z,
            scale: p.scale
        });
    }

    // 3. Render Outer Double-Helix Ribbons (Past & Future)
    if (showHelix) {
        var types = ["past", "future"];
        for (var tIdx = 0; tIdx < types.length; tIdx++) {
            var t = types[tIdx];
            var typeNodes = [];
            for (var i = 0; i < renderedNodes.length; i++) {
                if (renderedNodes[i].type === t) typeNodes.push(renderedNodes[i]);
            }
            typeNodes.sort(function(a, b) { return a.id - b.id; });

            var stride = 3;
            ctx.strokeStyle = (t === "past") ? "rgba(59, 130, 246, 0.22)" : "rgba(217, 70, 239, 0.22)";
            ctx.lineWidth = 3;

            for (var k = 0; k < typeNodes.length - stride; k++) {
                var n1 = typeNodes[k];
                var n2 = typeNodes[k + stride];

                ctx.beginPath();
                var segments = 16;
                for (var seg = 0; seg <= segments; seg++) {
                    var frac = seg / segments;
                    var angleOffsetRibbon = (t === "past") ? 0 : Math.PI;
                    var phase1 = (n1.id * 0.4) + angleOffsetRibbon;
                    var phase2 = (n2.id * 0.4) + angleOffsetRibbon + (Math.PI * 2);
                    var curPhase = phase1 + (phase2 - phase1) * frac;

                    var baseY1 = (n1.nowIndex - currentNowIndex) * verticalSpacing * 6 + (n1.orbitY || 0);
                    var baseY2 = (n2.nowIndex - currentNowIndex) * verticalSpacing * 6 + (n2.orbitY || 0);
                    var y3d = baseY1 + (baseY2 - baseY1) * frac;

                    var dragX1 = (n1.dragOffset && n1.dragOffset.x) || 0;
                    var dragY1 = (n1.dragOffset && n1.dragOffset.y) || 0;
                    var dragZ1 = (n1.dragOffset && n1.dragOffset.z) || 0;

                    var dragX2 = (n2.dragOffset && n2.dragOffset.x) || 0;
                    var dragY2 = (n2.dragOffset && n2.dragOffset.y) || 0;
                    var dragZ2 = (n2.dragOffset && n2.dragOffset.z) || 0;

                    var draggingOffsetX = dragX1 * (1 - frac) + dragX2 * frac;
                    var draggingOffsetY = dragY1 * (1 - frac) + dragY2 * frac;
                    var draggingOffsetZ = dragZ1 * (1 - frac) + dragZ2 * frac;

                    var curX = Math.sin(curPhase) * helixRadius;
                    var curZ = Math.cos(curPhase) * helixRadius;

                    var pt = project(w, h, curX + draggingOffsetX, y3d + draggingOffsetY, curZ + draggingOffsetZ);
                    if (pt.scale <= 0) {
                        if (seg > 0) ctx.stroke();
                        ctx.beginPath();
                        continue;
                    }
                    if (seg === 0) ctx.moveTo(pt.x, pt.y);
                    else ctx.lineTo(pt.x, pt.y);
                }
                ctx.stroke();
            }
        }
    }

    // 4. Central Spine (Connecting consecutive 'Now' nodes)
    var spineNodes = [];
    for (var sp = 0; sp < renderedNodes.length; sp++) {
        if (renderedNodes[sp].type === "now" || renderedNodes[sp].type === "insight") {
            spineNodes.push(renderedNodes[sp]);
        }
    }
    spineNodes.sort(function(a, b) { return a.id - b.id; });

    if (spineNodes.length > 1) {
        ctx.beginPath();
        ctx.strokeStyle = "rgba(245, 158, 11, 0.45)"; // Golden spine
        if (ctx.setLineDash) ctx.setLineDash([5, 5]);
        ctx.lineWidth = 2;

        for (var si = 0; si < spineNodes.length - 1; si++) {
            var sn1 = spineNodes[si];
            var sn2 = spineNodes[si + 1];
            if (sn1.scale <= 0 || sn2.scale <= 0) continue;
            ctx.moveTo(sn1.x, sn1.y);
            ctx.lineTo(sn2.x, sn2.y);
        }
        ctx.stroke();
        if (ctx.setLineDash) ctx.setLineDash([]);
    }

    // 5. Comparison Arcs (Sine Wave connectors from Past/Future to Now)
    for (var cIdx = 0; cIdx < connections.length; cIdx++) {
        var conn = connections[cIdx];
        var fromNode = null;
        var toNode = null;
        for (var rn = 0; rn < renderedNodes.length; rn++) {
            if (renderedNodes[rn].id === conn.fromId) fromNode = renderedNodes[rn];
            if (renderedNodes[rn].id === conn.toId) toNode = renderedNodes[rn];
        }

        if (fromNode && toNode && fromNode.scale > 0 && toNode.scale > 0) {
            var midScale = (fromNode.scale + toNode.scale) * 0.5;
            var midX = (fromNode.x + toNode.x) * 0.5;
            var midY = (fromNode.y + toNode.y) * 0.5;
            conn.midX = midX;
            conn.midY = midY;
            conn.midScale = midScale;

            var distToMid = Math.sqrt((mouseX - midX) * (mouseX - midX) + (mouseY - midY) * (mouseY - midY));
            var isConnHovered = (distToMid < Math.max(18, 28 * midScale));

            var dist = Math.sqrt((toNode.x - fromNode.x) * (toNode.x - fromNode.x) + (toNode.y - fromNode.y) * (toNode.y - fromNode.y));
            var angle = Math.atan2(toNode.y - fromNode.y, toNode.x - fromNode.x);
            var amplitude = 25 * fromNode.scale;
            var cSegments = 24;

            // Check along arc segments if not directly over midpoint
            if (!isConnHovered) {
                for (var checkSeg = 4; checkSeg <= 20; checkSeg += 4) {
                    var ctf = checkSeg / 24;
                    var clx = fromNode.x + (toNode.x - fromNode.x) * ctf;
                    var cly = fromNode.y + (toNode.y - fromNode.y) * ctf;
                    var csVal = Math.sin(ctf * Math.PI * 2);
                    if (fromNode.type === "future") csVal *= -1;
                    var coffX = csVal * amplitude * -Math.sin(angle);
                    var coffY = csVal * amplitude * Math.cos(angle);
                    var cPtDist = Math.sqrt((mouseX - (clx + coffX)) * (mouseX - (clx + coffX)) + (mouseY - (cly + coffY)) * (mouseY - (cly + coffY)));
                    if (cPtDist < Math.max(12, 18 * midScale)) {
                        isConnHovered = true;
                        break;
                    }
                }
            }
            conn.isHovered = isConnHovered;

            // Draw Sine Arc
            ctx.beginPath();
            var arcCol = (fromNode.type === "past") ? "59, 130, 246" : "217, 70, 239";
            ctx.strokeStyle = isConnHovered ? "rgba(6, 182, 212, 0.95)" : "rgba(" + arcCol + ", 0.45)";
            ctx.lineWidth = isConnHovered ? 3.0 : 1.5;
            if (ctx.setLineDash) ctx.setLineDash([4, 4]);

            ctx.moveTo(fromNode.x, fromNode.y);
            for (var cs = 1; cs <= cSegments; cs++) {
                var tf = cs / cSegments;
                var lx = fromNode.x + (toNode.x - fromNode.x) * tf;
                var ly = fromNode.y + (toNode.y - fromNode.y) * tf;

                var s = Math.sin(tf * Math.PI * 2);
                if (fromNode.type === "future") s *= -1;

                var offX = s * amplitude * -Math.sin(angle);
                var offY = s * amplitude * Math.cos(angle);

                ctx.lineTo(lx + offX, ly + offY);
            }
            ctx.stroke();
            if (ctx.setLineDash) ctx.setLineDash([]);

            // Draw Midpoint Comparison Nexus Glyph
            ctx.save();
            var nRad = (isConnHovered ? 8 : 5.5) * midScale;
            var nGrad = ctx.createRadialGradient(midX, midY, 0, midX, midY, nRad * 3);
            nGrad.addColorStop(0, isConnHovered ? "rgba(6, 182, 212, 0.9)" : "rgba(" + arcCol + ", 0.7)");
            nGrad.addColorStop(1, "rgba(" + arcCol + ", 0)");
            ctx.fillStyle = nGrad;
            ctx.beginPath();
            ctx.arc(midX, midY, nRad * 3, 0, Math.PI * 2);
            ctx.fill();

            ctx.fillStyle = isConnHovered ? "#ffffff" : "rgba(" + arcCol + ", 0.95)";
            ctx.beginPath();
            ctx.moveTo(midX, midY - nRad);
            ctx.lineTo(midX + nRad, midY);
            ctx.lineTo(midX, midY + nRad);
            ctx.lineTo(midX - nRad, midY);
            ctx.closePath();
            ctx.fill();
            ctx.strokeStyle = isConnHovered ? "#06b6d4" : "#ffffff";
            ctx.lineWidth = 1;
            ctx.stroke();

            if (isConnHovered || midScale > 0.88) {
                ctx.fillStyle = isConnHovered ? "#38bdf8" : "rgba(203, 213, 225, 0.85)";
                ctx.font = "bold " + Math.max(9, Math.round(10 * midScale)) + "px sans-serif";
                ctx.textAlign = "center";
                ctx.fillText(conn.stepTitle, midX, midY - nRad - 4);
            }
            ctx.restore();
        }
    }

    // Sort nodes by Z (back to front painter's algorithm)
    renderedNodes.sort(function(a, b) { return b.z - a.z; });

    // 6. Render Nodes
    hoveredNodeId = null;
    var hoveredNodeObj = null;

    for (var rIdx = 0; rIdx < renderedNodes.length; rIdx++) {
        var rNode = renderedNodes[rIdx];
        if (rNode.scale <= 0) continue;

        // Hit detection
        var mDist = Math.sqrt((mouseX - rNode.x) * (mouseX - rNode.x) + (mouseY - rNode.y) * (mouseY - rNode.y));
        var isHovered = (mDist < 28 * rNode.scale);
        if (isHovered) {
            hoveredNodeId = rNode.id;
            hoveredNodeObj = rNode;
        }

        var colStr = "255, 255, 255";
        if (rNode.type === "past") colStr = "59, 130, 246";       // Past Blue
        if (rNode.type === "future") colStr = "217, 70, 239";    // Future Magenta
        if (rNode.type === "now") colStr = "245, 158, 11";       // Sun/Now Amber
        if (rNode.type === "insight") colStr = "251, 191, 36";   // Golden Emergence

        // Outer Glow
        var baseRad = (rNode.type === "insight") ? 130 : 60;
        var rad = Math.max(0, (isHovered || rNode.id === activeNodeId ? baseRad * 1.4 : baseRad) * rNode.scale);

        if (rad > 0) {
            var grad = ctx.createRadialGradient(rNode.x, rNode.y, 0, rNode.x, rNode.y, rad);
            grad.addColorStop(0, "rgba(" + colStr + ", 0.9)");
            grad.addColorStop(0.2, "rgba(" + colStr + ", 0.4)");
            grad.addColorStop(0.5, "rgba(" + colStr + ", 0.1)");
            grad.addColorStop(1, "rgba(" + colStr + ", 0)");
            ctx.fillStyle = grad;
            ctx.beginPath();
            ctx.arc(rNode.x, rNode.y, rad, 0, Math.PI * 2);
            ctx.fill();
        }

        // Intense Core
        var baseCore = (rNode.type === "insight") ? 22 : 9;
        var coreSize = Math.max(0, (isHovered || rNode.id === activeNodeId ? baseCore * 1.5 : baseCore) * rNode.scale);
        ctx.fillStyle = "rgba(" + colStr + ", 1.0)";
        ctx.beginPath();
        ctx.arc(rNode.x, rNode.y, coreSize, 0, Math.PI * 2);
        ctx.fill();

        // Lens flare for active/hovered node
        if (isHovered || rNode.id === activeNodeId) {
            drawLensFlare(ctx, rNode.x, rNode.y, coreSize * 2.2, colStr);
        }

        // Dragging reposition ring
        if (draggedNode && rNode.id === draggedNode.id) {
            ctx.save();
            ctx.strokeStyle = "#ffffff";
            ctx.lineWidth = 2.5;
            if (ctx.setLineDash) ctx.setLineDash([4, 4]);
            ctx.beginPath();
            ctx.arc(rNode.x, rNode.y, (18 * rNode.scale), 0, Math.PI * 2);
            ctx.stroke();
            if (ctx.setLineDash) ctx.setLineDash([]);
            ctx.restore();
        } else if (rNode.id === activeNodeId) {
            var pulse = (Math.sin(Date.now() * 0.006) + 1.0) * 0.5;
            ctx.strokeStyle = "rgba(" + colStr + ", " + (0.4 + pulse * 0.5) + ")";
            ctx.lineWidth = 2;
            ctx.beginPath();
            ctx.arc(rNode.x, rNode.y, (12 + pulse * 5) * rNode.scale, 0, Math.PI * 2);
            ctx.stroke();
        }

        // Node Label
        if (rNode.scale > 0.75 || rNode.type === "insight") {
            ctx.fillStyle = "rgba(248, 250, 252, 0.95)";
            var fSize = (rNode.type === "insight") ? 14 : 11;
            ctx.font = "bold " + Math.round(fSize * rNode.scale) + "px sans-serif";
            ctx.textAlign = "center";

            var labelText = rNode.label;
            if (!labelText) {
                labelText = rNode.stepTitle || (rNode.type.toUpperCase() + " " + (rNode.stepNumber || (rNode.id + 1)));
            } else {
                labelText = (rNode.stepTitle ? (rNode.stepTitle + ": ") : "") + labelText;
            }
            if (labelText.length > 26) labelText = labelText.substring(0, 23) + "...";
            ctx.fillText(labelText, rNode.x, rNode.y + ((rNode.type === "insight" ? 36 : 22) * rNode.scale));
        }
    }

    // Check hovered connection if no node hovered
    var hoveredConnObj = null;
    if (!hoveredNodeObj) {
        for (var ci = 0; ci < connections.length; ci++) {
            if (connections[ci].isHovered) {
                hoveredConnObj = connections[ci];
                break;
            }
        }
    }

    // 7. Hover Tooltip (Nodes & Compare Connections - shows whole text without title prefixes)
    var activeHover = hoveredNodeObj || hoveredConnObj;
    if (activeHover) {
        var rawText = (activeHover.label && activeHover.label.trim().length > 0)
            ? activeHover.label.trim()
            : "(No response recorded yet)";

        ctx.save();
        ctx.font = "12px sans-serif";
        var maxBoxWidth = Math.min(460, Math.max(180, w - 40));
        var paddingX = 14;
        var paddingY = 10;
        var lineHeight = 18;
        var maxContentWidth = maxBoxWidth - (paddingX * 2);

        // Word wrap lines based on content width
        var paragraphs = rawText.split("\n");
        var wrappedLines = [];
        for (var p = 0; p < paragraphs.length; p++) {
            var para = paragraphs[p];
            if (!para || para.trim().length === 0) {
                if (wrappedLines.length > 0) wrappedLines.push("");
                continue;
            }
            var words = para.split(/\s+/);
            var currentLine = words[0];
            for (var widx = 1; widx < words.length; widx++) {
                var testLine = currentLine + " " + words[widx];
                if (ctx.measureText(testLine).width <= maxContentWidth) {
                    currentLine = testLine;
                } else {
                    wrappedLines.push(currentLine);
                    currentLine = words[widx];
                }
            }
            wrappedLines.push(currentLine);
        }
        if (wrappedLines.length === 0) wrappedLines.push(rawText);

        var maxLineWidth = 0;
        for (var li = 0; li < wrappedLines.length; li++) {
            var lw = ctx.measureText(wrappedLines[li]).width;
            if (lw > maxLineWidth) maxLineWidth = lw;
        }

        var boxWidth = Math.max(60, Math.round(maxLineWidth + paddingX * 2));
        var boxHeight = Math.round(paddingY * 2 + (wrappedLines.length * lineHeight));

        // Tooltip placement near cursor with intelligent screen edge flipping
        var boxX = mouseX + 16;
        if (boxX + boxWidth > w - 12) {
            boxX = mouseX - boxWidth - 16;
        }
        if (boxX < 12) {
            boxX = 12;
        }

        var boxY = mouseY + 16;
        if (boxY + boxHeight > h - 12) {
            boxY = mouseY - boxHeight - 12;
        }
        if (boxY < 12) {
            boxY = 12;
        }

        // Background card with theme-matched border
        ctx.fillStyle = "rgba(10, 15, 30, 0.95)";
        var borderCol = (activeHover.type === "future") ? "rgba(217, 70, 239, 0.85)" :
                        (activeHover.type === "past") ? "rgba(59, 130, 246, 0.85)" :
                        (activeHover.type === "compare") ? "rgba(6, 182, 212, 0.95)" : "rgba(245, 158, 11, 0.85)";
        ctx.strokeStyle = borderCol;
        ctx.lineWidth = 1.5;

        ctx.beginPath();
        if (ctx.roundRect) {
            ctx.roundRect(boxX, boxY, boxWidth, boxHeight, 8);
        } else {
            ctx.rect(boxX, boxY, boxWidth, boxHeight);
        }
        ctx.fill();
        ctx.stroke();

        // Render whole text
        ctx.fillStyle = (activeHover.label && activeHover.label.trim().length > 0) ? "#f8fafc" : "#94a3b8";
        ctx.textAlign = "left";
        for (var tIdx = 0; tIdx < wrappedLines.length; tIdx++) {
            ctx.fillText(wrappedLines[tIdx], boxX + paddingX, boxY + paddingY + 13 + (tIdx * lineHeight));
        }
        ctx.restore();
    }
}

function getNodeAt(mouseX, mouseY) {
    var best = null;
    var bestDepth = 999999;
    for (var i = 0; i < nodes.length; i++) {
        var node = nodes[i];
        if (!node || !node.lastRenderedScale || node.lastRenderedScale <= 0) continue;
        var dx = mouseX - (node.lastRenderedX || -1000);
        var dy = mouseY - (node.lastRenderedY || -1000);
        var dist = Math.sqrt(dx * dx + dy * dy);
        var hitRadius = Math.max(22, 38 * (node.lastRenderedScale || 1));
        if (dist < hitRadius) {
            var depth = -(node.lastRenderedScale || 1);
            if (depth < bestDepth) {
                bestDepth = depth;
                best = node;
            }
        }
    }
    return best;
}

function hasNodeAt(mouseX, mouseY) {
    if (getNodeAt(mouseX, mouseY) !== null) return true;
    for (var i = 0; i < connections.length; i++) {
        var conn = connections[i];
        if (conn.isHovered) return true;
        if (conn.midX !== undefined && conn.midX !== 0) {
            var dx = mouseX - conn.midX;
            var dy = mouseY - conn.midY;
            if (Math.sqrt(dx * dx + dy * dy) < Math.max(18, 28 * (conn.midScale || 1))) return true;
        }
    }
    return false;
}

function isDraggingNode() {
    return draggedNode !== null;
}

function startDrag(mouseX, mouseY) {
    var clickedNode = getNodeAt(mouseX, mouseY);
    if (clickedNode) {
        draggedNode = clickedNode;
        isRotating = false;
        activeNodeId = clickedNode.id;
        return true;
    } else {
        draggedNode = null;
        isRotating = true;
        return false;
    }
}

function handleDrag(dx, dy, isShift) {
    if (draggedNode) {
        // Moving a specific node in 3D space - project screen delta to world space
        var scaling = 1 / (draggedNode.lastRenderedScale || 1);

        var cosY = Math.cos(-rotationY);
        var sinY = Math.sin(-rotationY);

        if (!draggedNode.dragOffset) {
            draggedNode.dragOffset = { x: 0, y: 0, z: 0 };
        }
        draggedNode.dragOffset.x += (dx * cosY) * scaling;
        draggedNode.dragOffset.z = (draggedNode.dragOffset.z || 0) + (dx * sinY) * scaling;
        var comp = (currentCompression > 0) ? currentCompression : 0.45;
        draggedNode.dragOffset.y += (dy * scaling) / comp;
    } else if (isRotating) {
        if (isShift) {
            // Shift + Drag = Time Travel
            targetNowIndex -= dy * 0.02;
            targetNowIndex = Math.max(1, Math.min(maxNowIndex + 1, targetNowIndex));
        } else {
            // Standard Drag = Rotate Camera (Yaw & Pitch)
            rotationY += dx * 0.008;
            rotationX += dy * 0.008;
            // Limit pitch to prevent flipping upside down
            rotationX = Math.max(-1.2, Math.min(1.2, rotationX));
        }
    }
}

function endDrag() {
    isRotating = false;
    draggedNode = null;
}

function resetNodePositions() {
    for (var i = 0; i < nodes.length; i++) {
        if (nodes[i]) {
            nodes[i].dragOffset = { x: 0, y: 0, z: 0 };
        }
    }
}

function resetCameraView() {
    rotationX = 0.22;
    rotationY = 0.0;
    zoom = 1.0;
}

function handleWheel(delta) {
    var factor = delta > 0 ? 1.06 : 0.94;
    zoom *= factor;
    zoom = Math.max(0.4, Math.min(2.8, zoom));
}
