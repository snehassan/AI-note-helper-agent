# NoteBuddy for iPad

NoteBuddy sits in a narrow column beside **Apple Notes** or **Notability**. Hand it what you just scribbled (handwriting, typed text, a screenshot, or a PDF), ask a question, and Claude answers from your notes. Handwriting is sent as an image, so Claude reads your Pencil writing and sketches directly.

- Only reads what you drag, paste, or drop into it. It never looks at other apps on its own.
- Nothing is saved. **Clear** (or closing the app) drops your notes and the answer.
- Same model and system prompt as the Mac app. The API key is kept in the iPad's Keychain.

## Install

The app is a Swift Playgrounds app package (`NoteBuddy.swiftpm`). Pick one way to run it.

### Option A: Swift Playgrounds on the iPad (no Mac needed)

1. Install **Swift Playgrounds** from the App Store on your iPad.
2. Get the `NoteBuddy.swiftpm` folder onto the iPad. From your Mac: in Finder, right-click `iPad/NoteBuddy.swiftpm` → **Share → AirDrop** to your iPad, or put it in iCloud Drive.
3. Open it in Swift Playgrounds and tap **Run** (▶).

NoteBuddy runs inside the Playgrounds app. Put Playgrounds in Split View next to Notes or Notability.

### Option B: Xcode on your Mac (a real app icon, best for Split View)

1. Plug in your iPad and open `iPad/NoteBuddy.swiftpm` in Xcode 15 or later.
2. Select the **NoteBuddy** target → **Signing & Capabilities** → choose your **Team**. A free personal Apple ID works.
3. Pick your iPad as the run destination and press **Run** (⌘R).
4. The first time, on the iPad open **Settings → General → VPN & Device Management** and trust your developer profile.

With a free Apple ID the app stops opening after 7 days; just run it from Xcode again. A paid developer account removes that limit.

## Set the API key

The Settings sheet opens on first launch. Paste your Anthropic API key and tap **Save to Keychain**. You can change it later with the gear icon.

## Use it next to your notes

1. Open Notes or Notability, then bring in NoteBuddy with Split View or Slide Over (tap the **•••** at the top of the screen).
2. Get your notes into NoteBuddy (see below). Each piece shows as a thumbnail; tap **×** to remove one.
3. Type a question and tap the send arrow. The answer streams in.
4. Tap **Clear** when you start a new idea.

### From Apple Notes

- **Handwriting:** tap the handwriting with your finger and choose **Select**, or circle it with the **lasso** tool. Then press and hold the selection and drag it into NoteBuddy. Or choose **Copy** and tap **Paste** in NoteBuddy.
- **Typed text:** select it and drag it over, or copy and Paste.

### From Notability

- **Handwriting:** circle it with the **lasso** tool, tap **Copy** in the menu that pops up, then tap **Paste** in NoteBuddy. Dragging the lasso selection over may also work.
- **Whole page:** take a screenshot (below), or export the note as a PDF and drag the PDF in from Files.

### Any app: screenshot

Swipe up from a bottom corner of the screen with the Pencil (or press top button + volume up). Press and hold the screenshot thumbnail, then drag it into NoteBuddy. This captures everything on screen, including sketches.

## Test checklist

| Try | Expected |
|---|---|
| Write "call Priya about the Q3 budget Friday" by hand in Notes, drag it in, ask "What do I need to do?" | Answer mentions calling Priya on Friday, from your notes. |
| Lasso a sketch or diagram in Notability, Copy, Paste, ask "Summarize this" | Answer describes the sketch. |
| Screenshot a full Notability page, drag the thumbnail in, ask a question | Answer uses the whole page. |
| Ask "What is the capital of Peru?" with no notes attached | Answer says it comes from general knowledge. |
| Tap Clear | Thumbnails, question and answer are gone. |

## Notes and limits

- **Dark mode ink:** NoteBuddy flattens dropped ink onto a white background. If a thumbnail looks blank (white ink on white), switch the notes app to light mode or use a screenshot.
- **PDFs** up to about 20 MB. For bigger notes, use screenshots of the pages you need.
- **No Share-sheet entry yet.** Use drag and drop, Paste, or a screenshot.
- Model: `claude-sonnet-5-5`, streaming, low effort for quick answers. If Claude's safety filter declines a request, the API automatically retries it on a fallback model.

## Code layout

```
NoteBuddy.swiftpm/
  Package.swift        App package settings (bundle ID, icon, iPad + iPhone)
  NoteBuddyApp.swift   App entry
  ContentView.swift    Drop zone, Paste, question field, streaming answer, Settings sheet
  NotesModel.swift     Session state, loading dropped/pasted items, image prep
  ClaudeClient.swift   Messages API streaming (images, PDFs, text) + Keychain key storage
```
