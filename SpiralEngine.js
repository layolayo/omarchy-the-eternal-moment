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

function reset() {
    nodes = [];
    connections = [];
    rotationX = 0.22;
    rotationY = 0.0;
    zoom = 1.0;
    currentNowIndex = 1.0;
    targetNowIndex = 1.0;
    maxNowIndex = 1;
    activeNodeId = null;
    hoveredNodeId = null;
    comparisonMode = null;
    draggedNode = null;
    isRotating = false;
}

function addNode(type, id, label, nowIdx) {
    var node = {
        type: type, // 'now', 'past', 'future', 'insight'
        id: id,
        label: label || "",
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

function addConnection(fromId, toId, label) {
    connections.push({
        fromId: fromId,
        toId: toId,
        label: label || ""
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

function rebuildFromSession(flatSteps, answers, currentStepIndex) {
    reset();
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
            addNode(nodeType, step.id, ansText, nodeNowIndex);
        } else if (step.key === "cta") {
            var fromId = step.id - 1;
            var nowStep = null;
            for (var k = i - 1; k >= 0; k--) {
                if (flatSteps[k].key === "now" || flatSteps[k].key === "p4_starter") {
                    nowStep = flatSteps[k];
                    break;
                }
            }
            if (nowStep) {
                addConnection(fromId, nowStep.id, ansText);
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
                targetLevel = flatSteps[m].set || 1;
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

                    var curX = Math.sin(curPhase) * helixRadius;
                    var curZ = Math.cos(curPhase) * helixRadius;

                    var pt = project(w, h, curX, y3d, curZ);
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
            ctx.beginPath();
            ctx.strokeStyle = (fromNode.type === "past") ? "rgba(59, 130, 246, 0.45)" : "rgba(217, 70, 239, 0.45)";
            if (ctx.setLineDash) ctx.setLineDash([4, 4]);

            var dist = Math.sqrt((toNode.x - fromNode.x) * (toNode.x - fromNode.x) + (toNode.y - fromNode.y) * (toNode.y - fromNode.y));
            var angle = Math.atan2(toNode.y - fromNode.y, toNode.x - fromNode.x);
            var amplitude = 25 * fromNode.scale;
            var cSegments = 24;

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

        // Pulsing Selection Ring around active node
        if (rNode.id === activeNodeId) {
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
                labelText = rNode.type.toUpperCase() + " " + (rNode.id + 1);
            }
            if (labelText.length > 26) labelText = labelText.substring(0, 23) + "...";
            ctx.fillText(labelText, rNode.x, rNode.y + ((rNode.type === "insight" ? 36 : 22) * rNode.scale));
        }
    }

    // 7. Hover Tooltip
    if (hoveredNodeObj) {
        ctx.save();
        var typeLabel = hoveredNodeObj.type.toUpperCase();
        var tipText = "[" + typeLabel + "] " + (hoveredNodeObj.label || "(No response recorded yet)");
        ctx.font = "12px sans-serif";
        var tWidth = Math.min(300, ctx.measureText(tipText).width + 20);

        ctx.fillStyle = "rgba(15, 23, 42, 0.9)";
        ctx.strokeStyle = "rgba(6, 182, 212, 0.5)";
        ctx.lineWidth = 1;
        var boxX = Math.min(w - tWidth - 10, Math.max(10, mouseX + 15));
        var boxY = Math.min(h - 40, Math.max(10, mouseY + 15));

        ctx.fillRect(boxX, boxY, tWidth, 26);
        ctx.strokeRect(boxX, boxY, tWidth, 26);

        ctx.fillStyle = "#f8fafc";
        ctx.textAlign = "left";
        var displayStr = tipText;
        if (displayStr.length > 38) displayStr = displayStr.substring(0, 35) + "...";
        ctx.fillText(displayStr, boxX + 10, boxY + 17);
        ctx.restore();
    }
}

function handleDrag(dx, dy, isShift) {
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

function handleWheel(delta) {
    var factor = delta > 0 ? 1.06 : 0.94;
    zoom *= factor;
    zoom = Math.max(0.4, Math.min(2.8, zoom));
}
