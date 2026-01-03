# Drift 🌊

**Drift** is a minimalist brainwave entrainment application for iOS, designed to help you focus, relax, or sleep using scientifically tuned **Binaural Beats**.

## Features

- **Real-Time Audio Engine**: Generates pure sine waves tailored to specific brainwave frequencies.
- **Binaural Beats**: Uses a 200Hz carrier frequency to create audible "beat" tones for effective entrainment.
    - **Delta (0.5 - 4 Hz)**: Deep Sleep
    - **Theta (4 - 8 Hz)**: Meditation & Creativity
    - **Alpha (8 - 12 Hz)**: Relaxation
    - **Beta (12 - 30 Hz)**: Focus & Alertness
- **Atmospheric Layers**:
    - **Rain**: Gentle brown noise overlay.
    - **Space**: Deep, pulsing ambient drone.
- **Visual Entrainment**: Smooth, real-time sine wave visualization that syncs perfectly with the audio frequency.
- **Minimalist Design**: A clean, distraction-free interface built with SwiftUI.

## Tech Stack

- **Language**: Swift 5
- **UI Framework**: SwiftUI (Canvas, TimelineView for 60fps animations)
- **Audio Framework**: `AVAudioEngine`, `AVAudioSourceNode` (Real-time synthesis)
- **Haptics**: `UIImpactFeedbackGenerator`

## Requirements

- iOS 17.0+
- Xcode 15.0+

## License

This project is created by Jonni Akesson.
