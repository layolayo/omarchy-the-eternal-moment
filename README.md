# The Eternal Moment: Process #4 · 🌌 Omarchy Oracle

An authentic, meditative **Emergent Knowledge: Process #4 ("The Eternal Moment of Now")** bar widget and personal development oracle for the **Omarchy** desktop environment.

Built with **pure QML / Quickshell** and powered by an embedded, zero-dependency **SQLite LocalStorage** engine.

<p align="center">
  <img src="preview.png" alt="The Eternal Moment: Process #4 Preview Artwork" width="100%" />
</p>

---

## What is Process #4?

Adapted from **Universal Conscious Practice by K. Penday** and rooted in the **Emergent Knowledge** and **Clean Space** methodologies pioneered by **David Grove**:

1. **Describe Now**: Anchor awareness into your immediate internal topography (*"And, where are you now?"*).
2. **Locate a Past**: Access a memory, prior state, or historical condition (*"And, where [else] have you been?"*).
3. **Compare to Now**: Observe similarities, differences, and resonances (*"And, compare [A] to [B]"*).
4. **Locate a Future**: Access a projection, possibility, or future state (*"And, where [else] might you be?"*).
5. **Compare to Now**: Re-anchor to the present center (*"And, compare [A] to [B]"*).
6. **Iterative Emergence (The Power of Six)**: Repeat this triad three times per developmental Set. Across six evolutionary Sets, the system naturally shifts.
7. **Harvest the Difference**: The closing inquiry captures the non-linear transformation:
   > *"And, what is the difference between what you knew at the start and what you know now?"*

---

## Features

- **🌌 The Chamber (Guided Inquiry)**:
  - Clean, distraction-free typographic cards for every step.
  - Dynamic question contextualization (auto-inserts previous past/future phrases into comparison questions).
  - Pre-session clarity & focus calibration sliders.
  - Keyboard shortcuts (`Ctrl+Enter` or `Shift+Enter`) for rapid, natural reflection flow.
- **💾 Streamlined Local SQLite Database**:
  - Uses native `QtQuick.LocalStorage` (embedded SQLite3).
  - Zero external servers, daemons, or Python prerequisites.
  - Crash-proof auto-saving at every single step: close your laptop mid-session and resume exactly where you left off.
- **📜 Personal Development Archive**:
  - Browse historical sessions, review past breakthroughs, and inspect how your consciousness evolved over months.
  - Resume in-progress drafts or re-read completed session reports.
- **📋 Clean Markdown Reporting & Export**:
  - One-click `📋 Copy Markdown` to clipboard for Obsidian, Notion, or personal journals.
  - One-click `💾 Save to Docs` (`~/Documents/Process4_EternalMoment_*.md`).
- **🐦 Direct-to-X (Twitter) Sharing**:
  - Zero API tokens or subscription keys required.
  - Opens your default web browser directly into the X composer with a curated reflection snippet and `#EmergentKnowledge #Process4` tags.

---

## Installation

### Via Omarchy CLI
```bash
omarchy plugin add https://github.com/layolayo/omarchy-the-eternal-moment.git --enable
```

### Manual Installation
Clone this repository into your user plugins folder:
```bash
git clone https://github.com/layolayo/omarchy-the-eternal-moment.git ~/.config/omarchy/plugins/io.github.layolayo.eternal-moment
omarchy-shell shell rescanPlugins
omarchy plugin enable io.github.layolayo.eternal-moment --section right
```

---

## License
MIT License © Matthew Hudson
