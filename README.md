<div align="center">

# 🎙️ Auris

**Record, transcribe, and summarize your meetings — privately, on your Mac.**

Auris listens to your microphone and system audio, transcribes the conversation on-device with macOS's native speech engine, and turns it into a clean, GPT-powered summary with action items. Bring your own OpenAI key. Open source.

[![Platform](https://img.shields.io/badge/platform-macOS%2026%2B-blue)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-6.3-orange)](https://swift.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-green)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen)](#contributing)

</div>

> **Status:** 🚧 Early development. The product design (UI/UX) is complete; native implementation is in progress. Star the repo to follow along.

## Screenshots

_Coming soon._

## Why Auris?

Most meeting-notes tools upload your audio to the cloud. Auris keeps the heavy lifting **on your device**: recording and transcription never leave your Mac. Only the final text transcript — plus any images you choose to attach — is sent to OpenAI to generate the summary, using a key you control.

## Features

- 🎧 **Dual capture** — records the microphone and system audio (Zoom, Meet, Teams) into a single track.
- 📝 **On-device transcription** — powered by Apple's native Speech framework. No audio leaves your Mac.
- 🌍 **Multi-language** — transcribe in any locale Apple supports; get summaries in the language you choose.
- 🗣️ **Speaker labels** — name who's speaking and reuse the label throughout the transcript.
- ✨ **GPT summaries** — executive summary, key topics, decisions, and action items, generated with your OpenAI key.
- 🖼️ **Attachments** — drop screenshots or images into the conversation; they're sent along as context for the summary.
- 🔊 **Replayable audio** — every meeting is saved, so you can listen back with a synced player.
- 🏷️ **Tags & colors** — organize and filter your meeting library by colored tags.
- 🪟 **Widgets & menu bar** — start a meeting or check recording status from a WidgetKit widget or the menu-bar popover.
- ⏯️ **Dead-simple controls** — start, pause, stop. That's the whole loop.
- 🔒 **Private by default** — local storage, on-device transcription, bring-your-own API key.

## How it works

1. **Capture** — `ScreenCaptureKit` (system audio) + `AVAudioEngine` (microphone) → one recording.
2. **Transcribe** — the Apple `Speech` framework streams text on-device, in real time.
3. **Summarize** — the transcript (and any attached images) is sent to the OpenAI API to produce the summary and action items.
4. **Keep** — audio, transcript, and summary are stored locally and stay browsable in your library.

## Requirements

- macOS 14 (Sonoma) or later
- An OpenAI API key (for summaries)
- Permissions: **Microphone** + **Screen Recording** (the latter is required to capture system audio)

## Installation

**Homebrew** _(coming soon)_

```bash
brew install --cask auris
```

**Build from source**

```bash
git clone https://github.com/<your-username>/auris.git
cd auris
open Auris.xcodeproj
```

Build & run with Xcode 16+ (macOS 14+ deployment target). On first launch, set your signing
team in **Signing & Capabilities** if codesigning fails. The UI is localized in **English,
Portuguese (BR), and Spanish** — it follows your system language, with an override in Settings.

## Setup

1. Launch Auris and grant **Microphone** and **Screen Recording** permissions.
2. Open **Settings → AI** and paste your **OpenAI API key** (stored locally, in your Keychain).
3. Choose your transcription locale and summary language.

## Usage

- Click **New meeting**, confirm the consent prompt, and hit **Start**.
- **Pause** or **Stop** at any time — from the window, the menu-bar popover, or a widget.
- Attach a screenshot mid-meeting to give the summary extra context.
- When you stop, Auris transcribes the audio and generates the summary automatically.
- Rename, tag, and color your meetings; filter the library by tag.

## Privacy & consent

- Recording and transcription happen **on your device**. Audio is never uploaded.
- Only the **text transcript** and images you **explicitly attach** are sent to OpenAI, using your own API key.
- **You are responsible for obtaining consent.** Recording laws vary by country and state — make sure every participant is aware and agrees before you record.

## Roadmap

- [x] Core loop: capture → transcribe → summarize
- [x] Audio recording & playback
- [x] Manual speaker labeling
- [x] Image attachments as summary context
- [x] Tags, colors & filtering
- [x] WidgetKit widgets + menu-bar indicator
- [ ] Automatic speaker diarization
- [ ] Full-text & semantic search across meetings
- [ ] "Chat with this meeting"
- [ ] Calendar auto-detect & auto-record
- [ ] Custom summary templates (1:1, standup, sales call…)
- [ ] Export (Markdown, PDF, `.srt`/`.vtt`)
- [ ] Integrations (Notion, Slack, …)

> **Note on diarization:** Apple's native speech engine transcribes but does **not** separate speakers. The MVP ships with _manual_ speaker labeling; automatic diarization is on the roadmap.

## Tech stack

Swift · SwiftUI · ScreenCaptureKit · AVFoundation · Speech · WidgetKit · OpenAI API

## Contributing

Contributions are welcome! Open an issue to discuss a change before sending a large PR. A `CONTRIBUTING.md` will land soon.

## License

[MIT](LICENSE) © Juliano Bazzi

---

<div align="center">
Built for people who'd rather listen than take notes.
</div>
