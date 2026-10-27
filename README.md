# NoteBuddy

A tiny macOS menu bar helper that sits beside any notes app. Press **⌘⇧Space**, ask a question, and Claude answers using the note you're currently writing.

- Reads the focused text area **only when you press the hotkey**. Nothing runs in the background.
- No database, no history, no web search. The captured text is dropped when the panel closes.
- Password fields are skipped entirely.
- Note contents and the API key are never logged.

## Requirements

- macOS 13 Ventura or later
- Xcode 15+ (or the Swift 5.9+ command line tools)
- An Anthropic API key

## Build

```bash
./build-app.sh
```

The script compiles with `swiftc` directly (no SwiftPM needed) and produces `NoteBuddy.app` in the project folder. It is ad-hoc signed and has no dock icon (`LSUIElement`). Move it to `/Applications` if you like, then open it.

You can also open `Package.swift` in Xcode to read or edit the code. For real use, run the `.app` built by the script. When Xcode runs the bare executable, macOS gives the Accessibility permission to Xcode instead of NoteBuddy.

## 1. Grant Accessibility permission

On first launch NoteBuddy explains why it needs Accessibility access, then opens the system prompt.

1. Click **Continue**, then **Open System Settings**.
2. In **Privacy & Security → Accessibility**, turn on **NoteBuddy**.
3. NoteBuddy notices within a second and starts working. The menu stops saying "Waiting for Accessibility permission…".

Until permission is granted, the hotkey is not registered and nothing is read.

> **After rebuilding:** ad-hoc signed builds get a new signature each time, so macOS may silently stop trusting the old entry. If the hotkey stops reading text after a rebuild, remove NoteBuddy from the Accessibility list with the **−** button and add it again.

## 2. Set the API key

Pick one:

- **Keychain (recommended):** menu bar icon → **Settings…** → paste your key → **Save to Keychain**. If macOS asks whether NoteBuddy may use the keychain item, click **Always Allow**.
- **Environment variable:** apps opened from Finder don't see your shell environment, so launch the binary from Terminal:
  ```bash
  ANTHROPIC_API_KEY=sk-ant-... ./NoteBuddy.app/Contents/MacOS/NoteBuddy
  ```
  Launched this way, macOS may attribute Accessibility access to Terminal, so you may need to enable Terminal in the Accessibility list as well.

The Keychain key is used first. The environment variable is the fallback.

## 3. Use it

1. Click into a note so the text cursor is in it.
2. Press **⌘⇧Space**. A small panel opens near the mouse. The top line says how many characters were read and from which app, or **Can't read this app**.
3. Type a question and press **Return**. The answer streams in below.
4. Press **Esc** to close. The captured text is discarded.

**Pause reading** (menu bar) keeps the hotkey working but sends only your question, never note text.

## How to test

| App | Steps | Expected |
|---|---|---|
| **TextEdit** | New document, type "Meeting with Dana moved to Thursday 3pm". Press ⌘⇧Space, ask "When is the meeting?" | Status shows TextEdit; answer says Thursday 3pm, from your notes. |
| **Apple Notes** | Open a note with a few lines, click into the body, press ⌘⇧Space, ask "Summarize this note." | Status shows Notes; summary of the note. |
| **Notion (desktop)** | Click into a page's text, press ⌘⇧Space, ask about the page. | Status shows Notion; answer uses the page text. If the first try says "Can't read this app", press the hotkey again (Notion builds its accessibility tree on first request). |
| **General knowledge** | In any note, ask "What is the capital of Peru?" | Answer says it comes from general knowledge, not your notes. |
| **Unreadable app** | Focus Finder or a password field, press ⌘⇧Space, ask anything. | Status shows "Can't read this app"; the question still gets an answer. |
| **Pause** | Menu bar → Pause reading, then press the hotkey in a note. | Status shows reading is paused; answer doesn't know the note. |
| **Esc** | Press Esc while an answer is streaming. | Panel closes and streaming stops. |

## Notes and limits

- Model: `claude-sonnet-5-5`, streaming, low effort for quick answers. If Claude's safety filter declines a request, the API automatically retries it on a fallback model. If that also declines, the panel says so.
- In web-based editors (Notion and other Electron apps), NoteBuddy reads all the text in the window's web view, so sidebar and page titles can be included with the page body. It stops after 5,000 accessibility elements so a huge page can't freeze the hotkey.

## Code layout

```
Sources/NoteBuddy/
  NoteBuddyApp.swift        App entry: menu bar, permission gate, panel + settings windows
  HotkeyManager.swift       Global ⌘⇧Space via Carbon
  AccessibilityReader.swift Reads the focused text area (AXUIElement)
  ClaudeClient.swift        Messages API streaming + Keychain key storage
  PanelView.swift           Floating panel UI, its view model, and the Settings view
Support/Info.plist          Bundle info (LSUIElement = no dock icon)
build-app.sh                Builds and signs NoteBuddy.app
```
