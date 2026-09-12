// Database.js - Pure SQLite LocalStorage for The Eternal Moment
.import QtQuick.LocalStorage 2.0 as LS

var DB_NAME = "TheEternalMomentDB";
var DB_VERSION = "1.0";
var DB_DESCRIPTION = "The Eternal Moment Session Store";
var DB_SIZE = 10000000;

// Strict bounds & cardinality ceilings to protect memory and UI responsiveness
var MAX_SESSIONS_LIST = 100;       // Max rows returned by listSessions
var MAX_ANSWER_LEN = 2000;         // Max characters per question response
var MAX_FEEDBACK_LEN = 4000;       // Max characters for user reflections
var MAX_TAG_LEN = 50;              // Max characters per tag
var MAX_TAGS_COUNT = 20;           // Max tags per session
var MAX_ANSWERS_COUNT = 85;        // Process #4 consists of 81 steps total
var MAX_STRING_COL_LEN = 500;      // Max characters for now_start / final_insight summary columns

function getDb() {
    return LS.LocalStorage.openDatabaseSync(DB_NAME, DB_VERSION, DB_DESCRIPTION, DB_SIZE);
}

function sanitizeString(str, maxLen) {
    if (str === undefined || str === null) return "";
    var s = String(str);
    return s.length > maxLen ? s.substring(0, maxLen) : s;
}

function sanitizeAnswers(answers) {
    if (!answers || !Array.isArray(answers)) return [];
    var safe = [];
    var count = Math.min(answers.length, MAX_ANSWERS_COUNT);
    for (var i = 0; i < count; i++) {
        safe.push(sanitizeString(answers[i], MAX_ANSWER_LEN));
    }
    return safe;
}

function sanitizeTags(tags) {
    if (!tags || !Array.isArray(tags)) return [];
    var safe = [];
    var count = Math.min(tags.length, MAX_TAGS_COUNT);
    for (var i = 0; i < count; i++) {
        var t = sanitizeString(tags[i], MAX_TAG_LEN).trim();
        if (t.length > 0) safe.push(t);
    }
    return safe;
}

function normalizePct(val) {
    if (val === undefined || val === null) return 50;
    val = Number(val);
    if (isNaN(val)) return 50;
    if (val <= 10 && val > 0) return Math.round(val * 10);
    return Math.max(0, Math.min(100, Math.round(val)));
}

function initDb() {
    var db = getDb();
    db.transaction(function(tx) {
        tx.executeSql(`
            CREATE TABLE IF NOT EXISTS sessions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                uuid TEXT UNIQUE NOT NULL,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
                status TEXT NOT NULL DEFAULT 'in_progress',
                current_step INTEGER DEFAULT 0,
                now_start TEXT,
                final_insight TEXT,
                pre_clarity INTEGER DEFAULT 50,
                pre_focus INTEGER DEFAULT 50,
                post_clarity INTEGER DEFAULT 50,
                post_focus INTEGER DEFAULT 50,
                pre_movement INTEGER DEFAULT 50,
                post_movement INTEGER DEFAULT 50,
                answers_json TEXT,
                tags_json TEXT,
                feedback TEXT
            )
        `);

        var res = tx.executeSql("PRAGMA table_info(sessions)");
        var hasPreMov = false;
        var hasPostMov = false;
        for (var i = 0; i < res.rows.length; i++) {
            var col = res.rows.item(i).name;
            if (col === "pre_movement") hasPreMov = true;
            if (col === "post_movement") hasPostMov = true;
        }
        if (!hasPreMov) {
            tx.executeSql("ALTER TABLE sessions ADD COLUMN pre_movement INTEGER DEFAULT 50");
        }
        if (!hasPostMov) {
            tx.executeSql("ALTER TABLE sessions ADD COLUMN post_movement INTEGER DEFAULT 50");
        }
    });
}

function generateUUID() {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
        var r = Math.random() * 16 | 0, v = c == 'x' ? r : (r & 0x3 | 0x8);
        return v.toString(16);
    });
}

function saveSession(session) {
    var db = getDb();
    var recordId = session.id || null;
    var nowIso = new Date().toISOString();

    var preMov = normalizePct(session.pre_movement !== undefined ? session.pre_movement : (session.pre_focus !== undefined ? session.pre_focus : 50));
    var postMov = normalizePct(session.post_movement !== undefined ? session.post_movement : (session.post_focus !== undefined ? session.post_focus : 50));
    var preClar = normalizePct(session.pre_clarity !== undefined ? session.pre_clarity : 50);
    var postClar = normalizePct(session.post_clarity !== undefined ? session.post_clarity : 50);

    // Enforce strict field ceilings before saving
    var safeAnswers = sanitizeAnswers(session.answers);
    var safeTags = sanitizeTags(session.tags);
    var answersJson = JSON.stringify(safeAnswers);
    var tagsJson = JSON.stringify(safeTags);
    var nowStart = sanitizeString(safeAnswers[0] || session.now_start, MAX_STRING_COL_LEN);
    var finalInsight = sanitizeString(session.final_insight || (safeAnswers[80] || safeAnswers[79] || ""), MAX_STRING_COL_LEN);
    var feedback = sanitizeString(session.feedback, MAX_FEEDBACK_LEN);
    var uuid = sanitizeString(session.uuid, 64);
    var status = (session.status === 'completed') ? 'completed' : 'in_progress';
    var currentStep = Math.max(0, Math.min(MAX_ANSWERS_COUNT, Number(session.current_step) || 0));

    db.transaction(function(tx) {
        if (!recordId && uuid) {
            var existing = tx.executeSql("SELECT id FROM sessions WHERE uuid = ? LIMIT 1", [uuid]);
            if (existing && existing.rows && existing.rows.length > 0) {
                recordId = existing.rows.item(0).id;
            }
        }

        if (!recordId) {
            uuid = uuid || generateUUID();
            var res = tx.executeSql(`
                INSERT INTO sessions (
                    uuid, created_at, updated_at, status, current_step,
                    now_start, final_insight, pre_clarity, pre_focus,
                    post_clarity, post_focus, pre_movement, post_movement,
                    answers_json, tags_json, feedback
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            `, [
                uuid, nowIso, nowIso, status, currentStep,
                nowStart, finalInsight, preClar, preMov,
                postClar, postMov, preMov, postMov,
                answersJson, tagsJson, feedback
            ]);
            recordId = res.insertId;
        } else {
            tx.executeSql(`
                UPDATE sessions SET
                    updated_at = ?,
                    status = ?,
                    current_step = ?,
                    now_start = ?,
                    final_insight = ?,
                    pre_clarity = ?,
                    pre_focus = ?,
                    post_clarity = ?,
                    post_focus = ?,
                    pre_movement = ?,
                    post_movement = ?,
                    answers_json = ?,
                    tags_json = ?,
                    feedback = ?
                WHERE id = ?
            `, [
                nowIso, status, currentStep,
                nowStart, finalInsight, preClar, preMov,
                postClar, postMov, preMov, postMov,
                answersJson, tagsJson, feedback,
                recordId
            ]);
        }
    });

    return recordId;
}

function listSessions(limit) {
    var maxRows = (limit && typeof limit === "number" && limit > 0) ? Math.min(limit, MAX_SESSIONS_LIST) : MAX_SESSIONS_LIST;
    var db = getDb();
    var list = [];
    db.transaction(function(tx) {
        var rs = tx.executeSql(`
            SELECT id, uuid, created_at, updated_at, status, current_step, now_start, final_insight, pre_clarity, pre_focus, post_clarity, post_focus, pre_movement, post_movement, tags_json
            FROM sessions
            ORDER BY updated_at DESC
            LIMIT ?
        `, [maxRows]);
        for (var i = 0; i < rs.rows.length; i++) {
            var item = rs.rows.item(i);
            var tags = [];
            try {
                var rawTags = JSON.parse(item.tags_json || "[]");
                tags = sanitizeTags(rawTags);
            } catch (e) {}
            var pClar = normalizePct(item.pre_clarity);
            var poClar = normalizePct(item.post_clarity);
            var pMov = normalizePct(item.pre_movement !== null && item.pre_movement !== undefined ? item.pre_movement : item.pre_focus);
            var poMov = normalizePct(item.post_movement !== null && item.post_movement !== undefined ? item.post_movement : item.post_focus);
            list.push({
                id: item.id,
                uuid: sanitizeString(item.uuid, 64),
                created_at: sanitizeString(item.created_at, 40),
                updated_at: sanitizeString(item.updated_at, 40),
                status: (item.status === 'completed') ? 'completed' : 'in_progress',
                current_step: Math.max(0, Math.min(MAX_ANSWERS_COUNT, Number(item.current_step) || 0)),
                now_start: sanitizeString(item.now_start || "Untitled Session", MAX_STRING_COL_LEN),
                final_insight: sanitizeString(item.final_insight || "", MAX_STRING_COL_LEN),
                pre_clarity: pClar,
                pre_focus: pMov,
                pre_movement: pMov,
                post_clarity: poClar,
                post_focus: poMov,
                post_movement: poMov,
                tags: tags
            });
        }
    });
    return list;
}

function loadSession(id) {
    var db = getDb();
    var session = null;
    db.transaction(function(tx) {
        var rs = tx.executeSql(`SELECT * FROM sessions WHERE id = ? LIMIT 1`, [id]);
        if (rs.rows.length > 0) {
            var row = rs.rows.item(0);
            var answers = [];
            var tags = [];
            try {
                var rawAnswers = JSON.parse(row.answers_json || "[]");
                answers = sanitizeAnswers(rawAnswers);
            } catch (e) {}
            try {
                var rawTags = JSON.parse(row.tags_json || "[]");
                tags = sanitizeTags(rawTags);
            } catch (e) {}
            var pClar = normalizePct(row.pre_clarity);
            var poClar = normalizePct(row.post_clarity);
            var pMov = normalizePct(row.pre_movement !== null && row.pre_movement !== undefined ? row.pre_movement : row.pre_focus);
            var poMov = normalizePct(row.post_movement !== null && row.post_movement !== undefined ? row.post_movement : row.post_focus);
            session = {
                id: row.id,
                uuid: sanitizeString(row.uuid, 64),
                created_at: sanitizeString(row.created_at, 40),
                updated_at: sanitizeString(row.updated_at, 40),
                status: (row.status === 'completed') ? 'completed' : 'in_progress',
                current_step: Math.max(0, Math.min(MAX_ANSWERS_COUNT, Number(row.current_step) || 0)),
                now_start: sanitizeString(row.now_start, MAX_STRING_COL_LEN),
                final_insight: sanitizeString(row.final_insight, MAX_STRING_COL_LEN),
                pre_clarity: pClar,
                pre_focus: pMov,
                pre_movement: pMov,
                post_clarity: poClar,
                post_focus: poMov,
                post_movement: poMov,
                answers: answers,
                tags: tags,
                feedback: sanitizeString(row.feedback, MAX_FEEDBACK_LEN)
            };
        }
    });
    return session;
}

function deleteSession(id) {
    var db = getDb();
    db.transaction(function(tx) {
        tx.executeSql(`DELETE FROM sessions WHERE id = ?`, [id]);
    });
}
