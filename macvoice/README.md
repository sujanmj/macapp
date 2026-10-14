# MacVoice v0.1

Native voice typing and AI text editing inspired by [Voicy at usevoicy.com](https://usevoicy.com/). Independent implementation, not a rebrand or an exact reproduction of its proprietary service.

Start/stop from a text field with **Control–Option–Space**. Settings also offers Control–Shift–Space or Command–Shift–D presets. A visible transcript panel shows recording state and elapsed time. Local sessions are bounded to 55 seconds; cloud sessions to ten minutes. Cancel stops capture, invalidates pending results and prevents insertion. Microphone access is requested only on start.

**Local mode:** uses Apple's on-device speech recognition with selected language, live partial transcript, automatic punctuation where supported and vocabulary hints. Requests Speech Recognition permission. It refuses to silently fall back to Apple cloud recognition when the selected on-device model is unavailable.

**Cloud mode:** explicitly enable audio/text upload consent and configure your own OpenAI API key in Settings. Records a temporary AAC file, then submits it to `gpt-4o-transcribe` after stopping, with automatic language detection and optional vocabulary hints. No live cloud insertion. Audio is removed after completion/error/cancel; transcripts remain in memory until quit. API usage/billing and provider data policies apply. No audio/API request was made during build verification.

**Insertion:** optional automatic paste requests Cmd-V only when the original accessible, non-password text field and its selection remain unchanged. It never presses Enter or Send. Accessibility permission is required. Original clipboard contents are restored after 1.5 seconds only if the clipboard hasn't changed meanwhile. Secure/custom/inaccessible fields and changed focus use manual Copy Text. App-specific paste behavior is not guaranteed.

**Automatic polishing:** optionally enable grammar polishing after dictation. This sends the transcript to OpenAI and follows your auto-paste setting only if the original text field/selection remains unchanged. It requires cloud consent/key even when recognition is local. Polishing errors keep the original text for manual review.

**AI editing:** select text in your app and use **Control–Option–E** or Use Selected Text in the menu bar to import it for review. Set an instruction (grammar, punctuation, formal tone, shorten, translate, etc.), then click AI Edit Transcript to send only that text/instruction through the OpenAI Responses API. These explicit AI Edit results are shown for review and copied manually; they are never auto-pasted. Keys are stored in a per-app Keychain entry. Responses use `store=false`; no background API requests/retries.

## Parity and verification limits

Voicy's advertised accuracy and mixed-language performance are not reproduced or verified by this release. It does not include unrestricted recording, streaming cloud dictation, a bundled offline multilingual model, unrestricted hotkey customization, dictation history, or desktop/mobile account sync. Local language availability depends on macOS models; cloud recognition/AI quality depends on the selected provider/models. These are actual first-version gaps, not working features.

`bash scripts/package-utility.sh MacVoice`; requires Xcode/XcodeGen, macOS 14+. Produces a universal Apple Silicon/Intel DMG plus checksum. Ad-hoc signed and unnotarized. CI publishes beta installers only after all four builds/checks pass; see [downloads](downloads/README.md).

Device tests: microphone/speech/Accessibility allow and deny; selected local languages and unsupported models; local transcript finalization/timeouts; cloud consent off; offline/invalid-key failures; stop/cancel during permissions, recording and network requests; no audio files after cancel; focus/selection changes and secure fields; original clipboard preservation; selected-text import and AI review; text remains unsubmitted in messaging apps. Live API accuracy, latency and billing were not tested without a user's key.
