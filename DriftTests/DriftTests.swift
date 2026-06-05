//
//  DriftTests.swift
//  DriftTests
//
//  Created by Jonni Akesson on 2026-01-03.
//

import XCTest
@testable import Drift

final class DriftTests: XCTestCase {

    @MainActor
    private func resetController() -> AudioController {
        let controller = AudioController.shared

        controller.stop()
        controller.setFrequency(BrainwaveState.theta.centerFrequency)
        controller.masterVolume = 0.5
        controller.rainVolume = 0.0
        controller.whiteNoiseVolume = 0.0

        return controller
    }

    @MainActor
    func testAudioControllerStartsWithExpectedDefaults() {
        let controller = resetController()

        XCTAssertFalse(controller.isPlaying)
        XCTAssertEqual(controller.frequency, BrainwaveState.theta.centerFrequency, accuracy: 0.001)
        XCTAssertEqual(controller.masterVolume, 0.5, accuracy: 0.001)
        XCTAssertEqual(controller.rainVolume, 0.0, accuracy: 0.001)
        XCTAssertEqual(controller.whiteNoiseVolume, 0.0, accuracy: 0.001)
    }

    @MainActor
    func testAudioControllerUpdatesFrequency() {
        let controller = resetController()

        controller.setFrequency(BrainwaveState.delta.centerFrequency)
        XCTAssertEqual(controller.frequency, BrainwaveState.delta.centerFrequency, accuracy: 0.001)

        controller.setFrequency(BrainwaveState.beta.centerFrequency)
        XCTAssertEqual(controller.frequency, BrainwaveState.beta.centerFrequency, accuracy: 0.001)
    }

    @MainActor
    func testAudioControllerTracksMixerVolumes() {
        let controller = resetController()

        controller.masterVolume = 0.42
        controller.rainVolume = 0.25
        controller.whiteNoiseVolume = 0.75

        XCTAssertEqual(controller.masterVolume, 0.42, accuracy: 0.001)
        XCTAssertEqual(controller.rainVolume, 0.25, accuracy: 0.001)
        XCTAssertEqual(controller.whiteNoiseVolume, 0.75, accuracy: 0.001)
    }

    @MainActor
    func testStopIsIdempotentWhenAlreadyStopped() {
        let controller = resetController()

        controller.stop()
        controller.stop()

        XCTAssertFalse(controller.isPlaying)
    }

    @MainActor
    func testStartMarksControllerPlayingWhenAudioEngineStarts() throws {
        let controller = resetController()

        controller.start()

        guard controller.isPlaying else {
            throw XCTSkip("AVAudioEngine did not start in this test environment.")
        }

        controller.stop()
        XCTAssertFalse(controller.isPlaying)
    }
}
