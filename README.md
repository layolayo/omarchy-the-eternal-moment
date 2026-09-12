# The Eternal Moment: Process #4 · 🌌 Personal Development Tool

An authentic, immersive, full-screen **Emergent Knowledge: Process #4 ("The Eternal Moment of Now")** personal development and mindfulness application for the **Omarchy** desktop environment.

Created by **Matthew Hudson** and adapted from **Universal Conscious Practice by K. Penday**, grounded in **David Grove's Emergent Knowledge & Clean Space** cosmology.

Official Reference & Platform: [ekology.co.uk](https://ekology.co.uk)

<p align="center">
  <img src="preview.png" alt="The Eternal Moment: Process #4 Preview Artwork" width="100%" />
</p>

---

## Why a Full-Screen Application?

Process #4 is not a quick status indicator—it is an expansive journey of consciousness across the axis of time. By externalizing your internal landscape into a spacious full-screen space-time environment, your awareness can oscillate cleanly between the sovereign present, retrieved past memories, and emerging future potential without desktop distractions.

---

## Key Features

- **🌌 The Chamber (Spacious Guided Session)**:
  - Expansive typographic layout optimized for contemplation.
  - Dynamic question contextualization (auto-inserts previous past and future phrases into comparison inquiries).
  - Pre-session and post-session focus, clarity, and movement calibration sliders with delta metrics (+% / -%).
  - Rapid keyboard flow: `Ctrl+Enter` or `Shift+Enter` to reflect and advance.
  - Press `F11` anytime to toggle full-screen immersion.
- **🌀 Interactive 3D Emergent Spiral**:
  - Live spatial visualization of the 81 steps expanding in real-time as your journey unfolds.
  - Interactive camera control: drag to rotate, scroll wheel to zoom, and pan through your timeline of thoughts.
- **💾 100% Private & Offline SQLite Store**:
  - Powered by native `QtQuick.LocalStorage` (embedded SQLite3).
  - Zero telemetry, zero cloud tracking, zero external server dependencies.
  - Crash-proof auto-saving: close the app anytime and resume seamlessly.
- **📜 Personal Development Archive**:
  - Browse your history of completed sessions with timestamps, initial states, and emergent shifts.
  - Track how your clarity, movement flow, and emergent themes evolve over time.
  - Re-read past breakthrough transcripts or resume unfinished sessions.
- **📄 Publication-Grade PDF & Markdown Reports**:
  - `📄 Export PDF`: Generates a self-contained, publication-grade vector PDF document to `~/Documents/Process4_EternalMoment_*.pdf` with zero external dependencies (pure JavaScript PDF 1.4 vector generator—no headless browsers, pandoc, or Python engines required). Automatically opens in your system PDF viewer.
  - `💾 Save to Docs`: Exports a clean, timestamped Markdown report (`~/Documents/Process4_EternalMoment_*.md`) formatted for Obsidian, Logseq, Notion, or personal archives.
  - **Visual In-App Review**: View your complete session record rendered directly with rich proportional typography, formatted headings, and metric delta badges.
- **🐦 Curated Reflection Sharing**:
  - `🐦 Share on X`: Automatically copies your 3D spiral snapshot to clipboard and opens the X composer with your emergent insight and `#EmergentKnowledge #Process4 #CleanLanguage` tags.
- **📖 Comprehensive Built-in Instruction Manual & Ekology Reference**:
  - Full documentation of the 6-Set cycle and the Power of Six.
  - Clean Language definitions for *Where*, *Might*, and *Compare*.
  - Historical attribution and direct links to Matthew Hudson's [ekology.co.uk](https://ekology.co.uk).

---

## Installation & Management

### Install from Git / Marketplace
Install and enable directly via the Omarchy CLI:
```bash
omarchy plugin add https://github.com/layolayo/omarchy-the-eternal-moment.git --enable
```

### Update Plugin
Fetch and merge the latest upstream release:
```bash
omarchy plugin update io.github.layolayo.eternal-moment
```

### Removal / Uninstall
Remove the plugin and disable its registration:
```bash
omarchy plugin remove io.github.layolayo.eternal-moment
```

---

## How to Launch

### 1. Application Launcher (Super Key)
Search for **The Eternal Moment** in your Omarchy application menu (Rofi, Walker, or Omarchy menu).

### 2. Command Line / Direct Execution
Run directly via the included launcher script:
```bash
~/.config/omarchy/plugins/io.github.layolayo.eternal-moment/launch.sh
```

### 3. Summon via Omarchy Shell IPC
```bash
omarchy-shell shell summon io.github.layolayo.eternal-moment
```

---

## License
MIT License © Matthew Hudson · [ekology.co.uk](https://ekology.co.uk)
