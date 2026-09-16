/* app.js -- ctf-lab-vagrant scoreboard client (vanilla JS, no dependencies).
 *
 * Loads flags.json (questions + SHA-256 hashes), renders a tab per machine with
 * three level tracks (basic/medium/hard). Within each (machine, level) track,
 * flags unlock sequentially: a flag's input is enabled only once every earlier
 * flag in that track is solved. Correct -> green + unlock next; wrong -> red.
 * Progress persists in localStorage.
 */
"use strict";

const LEVELS = ["basic", "medium", "hard"];
const STORAGE_KEY = "ctf-lab-solved";

let FLAGS = [];
let MACHINES = [];
let solved = loadSolved();

/* ---------- persistence ---------- */
function loadSolved() {
  try { return new Set(JSON.parse(localStorage.getItem(STORAGE_KEY)) || []); }
  catch { return new Set(); }
}
function saveSolved() {
  localStorage.setItem(STORAGE_KEY, JSON.stringify([...solved]));
}

/* ---------- crypto ---------- */
async function sha256Hex(text) {
  if (!(window.crypto && window.crypto.subtle)) {
    throw new Error("SubtleCrypto unavailable — open via the local server (http://127.0.0.1), not file://");
  }
  const buf = await window.crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return [...new Uint8Array(buf)].map(b => b.toString(16).padStart(2, "0")).join("");
}

/* ---------- helpers ---------- */
const trackFlags = (machine, level) =>
  FLAGS.filter(f => f.machine === machine && f.level === level);

// a flag is unlocked iff every earlier flag in its (machine, level) track is solved
function isUnlocked(flag) {
  const track = trackFlags(flag.machine, flag.level);
  const idx = track.findIndex(f => f.id === flag.id);
  return track.slice(0, idx).every(f => solved.has(f.id));
}

const machineSolvedCount = m => FLAGS.filter(f => f.machine === m && solved.has(f.id)).length;
const machineTotal = m => FLAGS.filter(f => f.machine === m).length;

/* ---------- rendering ---------- */
function render() {
  buildTabs();
  buildPanels();
  updateProgress();
  const first = document.querySelector(".tab");
  if (first && !document.querySelector(".tab.active")) activateTab(first.dataset.machine);
}

function buildTabs() {
  const tabs = document.getElementById("tabs");
  tabs.innerHTML = "";
  MACHINES.forEach(m => {
    const done = machineSolvedCount(m);
    const total = machineTotal(m);
    const el = document.createElement("button");
    el.className = "tab" + (done === total && total > 0 ? " done" : "");
    el.dataset.machine = m;
    el.setAttribute("role", "tab");
    el.innerHTML = `${m} <span class="count">${done}/${total}</span>`;
    el.onclick = () => activateTab(m);
    tabs.appendChild(el);
  });
}

function buildPanels() {
  const panels = document.getElementById("panels");
  panels.innerHTML = "";
  MACHINES.forEach(m => {
    const panel = document.createElement("section");
    panel.className = "panel";
    panel.dataset.machine = m;
    LEVELS.forEach(level => {
      const track = trackFlags(m, level);
      if (track.length === 0) return;
      const lvl = document.createElement("div");
      lvl.className = `level ${level}`;
      lvl.innerHTML = `<h2>${level} · ${track.filter(f => solved.has(f.id)).length}/${track.length}</h2>`;
      track.forEach(f => lvl.appendChild(flagCard(f)));
      panel.appendChild(lvl);
    });
    panels.appendChild(panel);
  });
}

function flagCard(flag) {
  const done = solved.has(flag.id);
  const unlocked = done || isUnlocked(flag);

  const card = document.createElement("div");
  card.className = "flag" + (done ? " solved correct" : (unlocked ? "" : " locked"));
  card.dataset.id = flag.id;

  const head = document.createElement("div");
  head.className = "flag-head";
  head.innerHTML =
    `<span class="flag-id">${flag.id} <span class="status-icon">${done ? "✅" : (unlocked ? "🔓" : "🔒")}</span></span>` +
    `<span class="flag-cat">${flag.category}</span>`;
  card.appendChild(head);

  const q = document.createElement("div");
  q.className = "flag-q";
  q.textContent = flag.question;
  card.appendChild(q);

  const row = document.createElement("div");
  row.className = "flag-row";
  const input = document.createElement("input");
  input.className = "flag-input";
  input.type = "text";
  input.placeholder = done ? "solved" : (unlocked ? "enter flag / answer…" : "locked — solve the previous flag first");
  input.disabled = !unlocked || done;
  if (done) input.value = "•".repeat(12);
  const btn = document.createElement("button");
  btn.className = "submit-btn";
  btn.textContent = done ? "done" : "submit";
  btn.disabled = !unlocked || done;
  row.appendChild(input);
  row.appendChild(btn);
  card.appendChild(row);

  const msg = document.createElement("div");
  msg.className = "msg";
  card.appendChild(msg);

  if (flag.hint) {
    const hintBtn = document.createElement("button");
    hintBtn.className = "hint-toggle";
    hintBtn.textContent = "› hint";
    const hint = document.createElement("div");
    hint.className = "hint";
    hint.textContent = flag.hint;
    hintBtn.onclick = () => {
      hint.classList.toggle("show");
      hintBtn.textContent = hint.classList.contains("show") ? "▾ hide hint" : "› hint";
    };
    card.appendChild(hintBtn);
    card.appendChild(hint);
  }

  if (!done && unlocked) {
    const submit = async () => {
      const guess = input.value.trim();
      if (!guess) return;
      let hex;
      try { hex = await sha256Hex(guess); }
      catch (e) { msg.className = "msg err"; msg.textContent = e.message; return; }
      if (hex === flag.answer_sha256) {
        solved.add(flag.id);
        saveSolved();
        card.classList.remove("wrong");
        card.classList.add("correct");
        const active = document.querySelector(".panel.active")?.dataset.machine;
        buildPanels(); buildTabs(); updateProgress();
        if (active) activateTab(active);
      } else {
        card.classList.remove("correct");
        card.classList.add("wrong");
        msg.className = "msg err";
        msg.textContent = "✗ incorrect — the next flag stays locked";
        input.select();
      }
    };
    btn.onclick = submit;
    input.addEventListener("keydown", e => { if (e.key === "Enter") submit(); });
  }

  return card;
}

function activateTab(machine) {
  document.querySelectorAll(".tab").forEach(t =>
    t.classList.toggle("active", t.dataset.machine === machine));
  document.querySelectorAll(".panel").forEach(p =>
    p.classList.toggle("active", p.dataset.machine === machine));
}

function updateProgress() {
  const total = FLAGS.length;
  const done = FLAGS.filter(f => solved.has(f.id)).length;
  document.getElementById("solved-count").textContent = done;
  document.getElementById("total-count").textContent = total;
  document.getElementById("progress-fill").style.width =
    total ? `${(done / total * 100).toFixed(1)}%` : "0%";
}

/* ---------- boot ---------- */
document.getElementById("reset-btn").onclick = () => {
  if (confirm("Clear all saved progress?")) {
    solved = new Set(); saveSolved();
    const active = document.querySelector(".panel.active")?.dataset.machine;
    render(); if (active) activateTab(active);
  }
};

fetch("flags.json")
  .then(r => { if (!r.ok) throw new Error("flags.json not found"); return r.json(); })
  .then(data => {
    FLAGS = data.flags || [];
    MACHINES = data.machines || [...new Set(FLAGS.map(f => f.machine))];
    render();
  })
  .catch(err => {
    document.getElementById("panels").innerHTML =
      `<section class="panel active"><div class="level"><h2>error</h2>` +
      `<p class="flag-q">Could not load flags.json (${err.message}).<br>` +
      `Run <code>python generate.py</code>, then start <code>scoreboard/server.py</code>.</p></div></section>`;
  });
