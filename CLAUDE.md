# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

GoldenKick is an iOS SwiftUI app. It is currently a fresh Xcode template project (single `WindowGroup` showing a placeholder view) — no custom features are implemented yet. The intended product is a "Personal Trainer" voice-assistant app that announces workout phases (warm-up walk, alternating run/walk intervals, cool-down walk) and auto-advances through them, started by a single Start button.

- Deployment target: iOS 27.0
- Single Xcode target/scheme: `GoldenKick` (application)
- No Swift packages or external dependencies yet
- No test target exists yet

## Working in Xcode

This repo is driven through the Xcode MCP tools rather than the filesystem/CLI:
- Build: use `BuildProject`.
- Quick compiler-error checks while editing a file: use `XcodeRefreshCodeIssuesInFile`.
- Try out a snippet/API without a full build: use `RunCodeSnippet`.
- Run on simulator/device: use `RunProject` / `DeviceInteraction*` tools.
- Browse/edit files via `XcodeRead`, `XcodeWrite`, `XcodeGlob`, `XcodeGrep` (the project organization paths shown in the environment reminder, e.g. `GoldenKick/GoldenKick/ContentView.swift`, are not filesystem paths).

There is no test target yet, so there is no test command to run. When tests are added, use the `GetTestList` / `RunAllTests` / `RunSomeTests` MCP tools rather than `xcodebuild` directly.

## Architecture notes

- `GoldenKick/GoldenKickApp.swift` — `@main` App entry point, hosts a single `WindowGroup { ContentView() }`.
- `GoldenKick/ContentView.swift` — placeholder root view (template default).

As the workout-assistant feature is built out, expect the architecture to grow around: a workout plan/step sequencer (warm-up → repeated run/walk intervals → cool-down → auto-finish), a timer driving phase transitions, and a speech-synthesis layer (`AVSpeechSynthesizer`) that announces each phase change. Since no such code exists yet, don't assume specific types or file names — check current files before referencing them.
