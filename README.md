# Drift

[![Swift 6](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-blue.svg)](https://developer.apple.com/xcode/swiftui/)
[![Audio](https://img.shields.io/badge/Audio-AVAudioEngine-lightgrey.svg)](https://developer.apple.com/documentation/avfaudio/avaudioengine)
[![Tests](https://img.shields.io/badge/Tests-XCTest-green.svg)](https://developer.apple.com/documentation/xctest)

Drift is a native iOS audio app for focus and relaxation. It generates binaural tones and ambient noise in real time instead of looping pre-recorded audio files, then pairs that sound with a calm SwiftUI interface and a lightweight mixer.

The project is intentionally small, but it touches a few areas that matter in production iOS work: real-time audio, Swift 6 actor isolation, observable UI state, custom drawing, and testable state transitions.

<p align="center">
  <img src="assets/showcase.png" alt="Drift app showcase" width="2000" height="1000">
</p>

## Project Highlights

- Real-time binaural tone synthesis using `AVAudioEngine` and `AVAudioSourceNode`.
- Procedural rain and white-noise layers generated without bundled audio files.
- SwiftUI interface with frequency presets, animated background visuals, waveform drawing, and a mixer sheet.
- Swift 6-ready audio architecture that separates main-actor UI state from Core Audio render callbacks.
- Unit tests for the audio controller's default state, frequency changes, mixer values, and start/stop behavior.
- No accounts, network requests, analytics SDKs, or external services.

## Tech Stack

| Area | Implementation |
| --- | --- |
| Language | Swift 6 |
| UI | SwiftUI |
| State | Swift Observation with `@Observable`, `@Bindable`, and `@State` |
| Concurrency | `@MainActor`, nonisolated render factories, and `Task` loops for fades/LFO updates |
| Audio | `AVAudioEngine`, `AVAudioSourceNode`, `AVAudioMixerNode`, `AVAudioSession` |
| Drawing | `Canvas`, `TimelineView`, and `Animatable` for the waveform |
| Tests | XCTest unit tests for `AudioController` |
| Tooling | Xcode 17 |

Not currently used: SwiftData, remote APIs, dependency injection containers, or persistent storage. Drift does not need those pieces for its current scope, so the code keeps the architecture direct.

## Architecture

Drift is organized around a small SwiftUI app surface and one central audio controller.

- `MainView` owns the primary session UI: frequency tabs, play/pause, the animated wave, and the mixer entry point.
- `MixerView` edits the public mixer values exposed by the audio controller.
- `AudioController` owns audio engine setup, synthesis nodes, playback state, volume fades, and the slow panning LFO.
- `BrainwaveState` defines the preset frequencies shown in the UI.
- `WaveView`, `BackgroundView`, and `SpaceView` keep visual rendering separate from audio logic.

This is not a heavy MVVM implementation with many view models. For this app, the useful separation is simpler: SwiftUI views handle presentation, while `AudioController` acts as the observable model/controller for audio state and engine behavior.

## Engineering Decisions

### Real-Time Audio Instead of Looped Files

The binaural tone is generated sample-by-sample in an `AVAudioSourceNode` render callback. Rain and white noise are procedural too, using small render-thread state objects instead of audio assets. That keeps the app lightweight and avoids loop points.

### Swift 6 Actor Isolation

`AudioController` is `@MainActor` because it drives UI-observed state. The Core Audio render callbacks are created through `nonisolated` factory methods so playback is not accidentally tied to the main actor or UI queue.

Render-thread values are kept outside observation with `@ObservationIgnored`. The current implementation uses small unchecked-sendable render state objects; this keeps Swift 6 strict concurrency happy while preserving the separation between UI state and the audio render path.

### Simple State Surface

The public controller state is intentionally small:

```swift
controller.setFrequency(BrainwaveState.theta.centerFrequency)
controller.rainVolume = 0.25
controller.start()
```

That makes the UI straightforward and gives the unit tests clear behavior to verify.

### Lightweight Animation

The waveform uses `Canvas` and `TimelineView` so the visual can animate independently from the audio engine. `WaveView` conforms to `Animatable`, which lets SwiftUI interpolate frequency and amplitude changes cleanly.

## Privacy And Security

Drift is local-only in its current form.

- No sign-in.
- No network calls.
- No remote API handling.
- No analytics or tracking SDKs.
- No user-generated data storage.
- Audio is generated on device.

The app does configure an iOS playback audio session so sound can continue appropriately for a relaxation/focus experience.

## Testing And Verification

The project includes lightweight XCTest coverage for the audio controller:

- default state
- frequency updates
- mixer volume updates
- idempotent stop behavior
- start/stop behavior when `AVAudioEngine` starts successfully

The current UI test target is intentionally left without app-launching tests because the simulator UI runner is expensive on the development machine used for this project. The unit tests are the practical default for local verification right now.

Latest verification run:

```sh
xcodebuild test \
  -project Drift.xcodeproj \
  -scheme Drift \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.5' \
  -derivedDataPath /tmp/DriftUnitTestsDerivedData \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:DriftTests
```

Result: `TEST SUCCEEDED` with all 5 `DriftTests` passing.

## Setup And Build

1. Open `Drift.xcodeproj` in Xcode 17.
2. Select the `Drift` scheme.
3. Choose an iOS simulator or connected iPhone.
4. Build and run with `Cmd+R`.
5. Run unit tests with `Cmd+U`, or run only `DriftTests` from Xcode's test navigator.

Command-line build:

```sh
xcodebuild build \
  -project Drift.xcodeproj \
  -scheme Drift \
  -configuration Debug \
  -destination generic/platform=iOS \
  CODE_SIGNING_ALLOWED=NO
```

## What This Project Demonstrates

Drift shows that I can take a focused product idea and build it with care across UI, audio, and Swift 6 readiness. The main technical work is not in adding lots of screens; it is in keeping real-time audio separate from UI isolation, using SwiftUI where it fits well, and adding enough tests to protect the controller behavior without overcomplicating a small app.

It is a compact project, but it reflects the kind of engineering judgment I value: understand the platform constraints, keep the architecture honest, and verify the parts most likely to break.
