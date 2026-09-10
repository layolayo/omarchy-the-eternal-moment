// Database.js - Pure SQLite LocalStorage for The Eternal Moment
.import QtQuick.LocalStorage 2.0 as LS

var DB_NAME = "TheEternalMomentDB";
var DB_VERSION = "1.0";
var DB_DESCRIPTION = "The Eternal Moment Session Store";
var DB_SIZE = 10000000;

function getDb() {
    return LS.LocalStorage.openDatabaseSync(DB_NAME, DB_VERSION, DB_DESCRIPTION, DB_SIZE);
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
                pre_clarity INTEGER DEFAULT 5,
                pre_focus INTEGER DEFAULT 5,
                post_clarity INTEGER DEFAULT 5,
                post_focus INTEGER DEFAULT 5,
                pre_movement INTEGER DEFAULT 5,
                post_movement INTEGER DEFAULT 5,
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
            tx.executeSql("ALTER TABLE sessions ADD COLUMN pre_movement INTEGER DEFAULT 5");
        }
        if (!hasPostMov) {
            tx.executeSql("ALTER TABLE sessions ADD COLUMN post_movement INTEGER DEFAULT 5");
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

    var preMov = session.pre_movement !== undefined ? session.pre_movement : (session.pre_focus || 5);
    var postMov = session.post_movement !== undefined ? session.post_movement : (session.post_focus || 5);

    db.transaction(function(tx) {
        if (!recordId) {
            var uuid = session.uuid || generateUUID();
            var answersJson = JSON.stringify(session.answers || []);
            var tagsJson = JSON.stringify(session.tags || []);
            var nowStart = session.answers && session.answers[0] ? session.answers[0] : "";
            var finalInsight = session.final_insight || "";

            var res = tx.executeSql(`
                INSERT INTO sessions (
                    uuid, created_at, updated_at, status, current_step,
                    now_start, final_insight, pre_clarity, pre_focus,
                    post_clarity, post_focus, pre_movement, post_movement,
                    answers_json, tags_json, feedback
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            `, [
                uuid, nowIso, nowIso, session.status || 'in_progress', session.current_step || 0,
                nowStart, finalInsight, session.pre_clarity || 5, preMov,
                session.post_clarity || 5, postMov, preMov, postMov,
                answersJson, tagsJson, session.feedback || ""
            ]);
            recordId = res.insertId;
        } else {
            var answersJson = JSON.stringify(session.answers || []);
            var tagsJson = JSON.stringify(session.tags || []);
            var nowStart = session.answers && session.answers[0] ? session.answers[0] : "";
            var finalInsight = session.final_insight || (session.answers && (session.answers[80] || session.answers[79]) ? (session.answers[80] || session.answers[79]) : "");

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
                nowIso, session.status || 'in_progress', session.current_step || 0,
                nowStart, finalInsight, session.pre_clarity || 5, preMov,
                session.post_clarity || 5, postMov, preMov, postMov,
                answersJson, tagsJson, session.feedback || "",
                recordId
            ]);
        }
    });

    return recordId;
}

function listSessions() {
    var db = getDb();
    var list = [];
    db.transaction(function(tx) {
        var rs = tx.executeSql(`
            SELECT id, uuid, created_at, updated_at, status, current_step, now_start, final_insight, pre_clarity, pre_focus, post_clarity, post_focus, pre_movement, post_movement, tags_json
            FROM sessions
            ORDER BY updated_at DESC
        `);
        for (var i = 0; i < rs.rows.length; i++) {
            var item = rs.rows.item(i);
            var tags = [];
            try { tags = JSON.parse(item.tags_json || "[]"); } catch (e) {}
            var pMov = item.pre_movement !== null && item.pre_movement !== undefined ? item.pre_movement : (item.pre_focus || 5);
            var poMov = item.post_movement !== null && item.post_movement !== undefined ? item.post_movement : (item.post_focus || 5);
            list.push({
                id: item.id,
                uuid: item.uuid,
                created_at: item.created_at,
                updated_at: item.updated_at,
                status: item.status,
                current_step: item.current_step,
                now_start: item.now_start || "Untitled Session",
                final_insight: item.final_insight || "",
                pre_clarity: item.pre_clarity,
                pre_focus: pMov,
                pre_movement: pMov,
                post_clarity: item.post_clarity,
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
        var rs = tx.executeSql(`SELECT * FROM sessions WHERE id = ?`, [id]);
        if (rs.rows.length > 0) {
            var row = rs.rows.item(0);
            var answers = [];
            var tags = [];
            try { answers = JSON.parse(row.answers_json || "[]"); } catch (e) {}
            try { tags = JSON.parse(row.tags_json || "[]"); } catch (e) {}
            var pMov = row.pre_movement !== null && row.pre_movement !== undefined ? row.pre_movement : (row.pre_focus || 5);
            var poMov = row.post_movement !== null && row.post_movement !== undefined ? row.post_movement : (row.post_focus || 5);
            session = {
                id: row.id,
                uuid: row.uuid,
                created_at: row.created_at,
                updated_at: row.updated_at,
                status: row.status,
                current_step: row.current_step,
                now_start: row.now_start,
                final_insight: row.final_insight,
                pre_clarity: row.pre_clarity,
                pre_focus: pMov,
                pre_movement: pMov,
                post_clarity: row.post_clarity,
                post_focus: poMov,
                post_movement: poMov,
                answers: answers,
                tags: tags,
                feedback: row.feedback || ""
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
