/*
 * SPDX-FileCopyrightText: 2026 XMB Waves Contributors
 * SPDX-License-Identifier: MIT
 */

import QtQuick
import QtQuick.Window
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.taskmanager as TaskManager
import org.kde.kwindowsystem

import "ColorSchemes.js" as ColorSchemes

WallpaperItem {
    id: root

    // Configuration bindings with safe fallbacks
    readonly property int fpsLimit: root.configuration.FpsLimit ?? 0
    readonly property real speedMultiplier: root.configuration.SpeedMultiplier ?? 1.0
    readonly property bool smartPause: root.configuration.SmartPause ?? true
    readonly property int colorMode: root.configuration.ColorMode ?? 0
    readonly property string presetScheme: root.configuration.PresetScheme || "celestial_silk"
    readonly property color harmonyBaseColor: root.configuration.HarmonyBaseColor || "#5b8dd9"
    readonly property int harmonyStyle: root.configuration.HarmonyStyle ?? 0

    readonly property var activePalette: ColorSchemes.resolvePalette(
        root.colorMode,
        root.presetScheme,
        root.harmonyBaseColor,
        root.harmonyStyle,
        {
            bgStart: root.configuration.BgColorStart || "#c9d6e8",
            bgMid:   root.configuration.BgColorMid   || "#b8c8df",
            bgEnd:   root.configuration.BgColorEnd   || "#c4d0e4",
            wave1:   root.configuration.Wave1Color   || "#8fb0e8",
            wave2:   root.configuration.Wave2Color   || "#9a8fe0",
            wave3:   root.configuration.Wave3Color   || "#7aa2e6",
            wave4:   root.configuration.Wave4Color   || "#3f58b0"
        }
    )

    // Expose dominant ribbon color to Plasma's "Accent color from wallpaper" system
    accentColor: activePalette.wave1

    function colorToVec4(c) {
        var col = Qt.color(c);
        return Qt.vector4d(col.r, col.g, col.b, col.a);
    }

    // --- Smart Pause: Detect maximized/fullscreen windows on this screen ---
    // Only active inside plasmashell so that applying the wallpaper to the
    // KDE Lock Screen (kscreenlocker_greet) is unaffected by desktop windows.
    readonly property bool isDesktopShell: Qt.application.name === "plasmashell"
    readonly property bool hasValidScreen: (root.Screen.width > 0 && root.Screen.height > 0)

    Loader {
        id: windowMonitorLoader
        active: root.smartPause && root.isDesktopShell
        sourceComponent: Item {
            readonly property bool covered: !KWindowSystem.showingDesktop && maximizedWindowsModel.count > 0

            TaskManager.VirtualDesktopInfo {
                id: virtualDesktopInfo
            }

            TaskManager.ActivityInfo {
                id: activityInfo
            }

            TaskManager.TasksModel {
                id: maximizedWindowsModel
                filterByVirtualDesktop: true
                virtualDesktop: virtualDesktopInfo.currentDesktop
                filterByActivity: true
                activity: activityInfo.currentActivity
                filterByScreen: root.hasValidScreen
                screenGeometry: root.hasValidScreen
                    ? Qt.rect(root.Screen.virtualX, root.Screen.virtualY, root.Screen.width, root.Screen.height)
                    : Qt.rect(0, 0, 0, 0)
                filterMinimized: true
                filterNotMaximized: true
                filterHidden: true
                groupMode: TaskManager.TasksModel.GroupDisabled
            }
        }
    }

    readonly property bool coveredByMaximizedWindow: windowMonitorLoader.item
        ? windowMonitorLoader.item.covered
        : false

    readonly property bool shouldAnimate: root.visible
        && (root.Window.visibility !== Window.Hidden)
        && (root.fpsLimit >= 0)
        && (root.speedMultiplier > 0.0)
        && !root.coveredByMaximizedWindow

    // --- Phase accumulator (wrapped in [0, 1) and [0, 2) to prevent float32 drift
    //     across weeks of uptime or suspend/resume cycles) ---
    property double sPhase1: 0.0
    property double sPhase2: 0.0
    property double sPhase3: 0.0
    property double sPhase4: 0.0

    property double bPhase1: 0.0
    property double bPhase2: 0.0
    property double bPhase3: 0.0
    property double bPhase4: 0.0

    function wrapPos(val, period) {
        var r = val % period;
        return r < 0.0 ? r + period : r;
    }

    function advanceAnimation(rawDtSeconds) {
        // Clamp dt to at most 0.25s so waking from DPMS screen-off or suspend-to-RAM
        // resumes seamlessly from the exact current wave position without jumping.
        var dt = Math.min(Math.max(rawDtSeconds, 0.0), 0.25) * root.speedMultiplier;
        if (dt <= 0.0) {
            return;
        }

        sPhase1 = wrapPos(sPhase1 + dt * (1.0 / 45.0), 1.0);
        sPhase2 = wrapPos(sPhase2 - dt * (1.0 / 62.0), 1.0);
        sPhase3 = wrapPos(sPhase3 + dt * (1.0 / 80.0), 1.0);
        sPhase4 = wrapPos(sPhase4 - dt * (1.0 / 100.0), 1.0);

        bPhase1 = wrapPos(bPhase1 + dt * (1.0 / 11.0), 2.0);
        bPhase2 = wrapPos(bPhase2 + dt * (1.0 / 14.0), 2.0);
        bPhase3 = wrapPos(bPhase3 + dt * (1.0 / 17.0), 2.0);
        bPhase4 = wrapPos(bPhase4 + dt * (1.0 / 20.0), 2.0);

        shader.u_slidePhases = Qt.vector4d(sPhase1, sPhase2, sPhase3, sPhase4);
        shader.u_bobPhases   = Qt.vector4d(bPhase1, bPhase2, bPhase3, bPhase4);
    }

    // --- Display-synced Frame Clock + DPMS-aware FPS Limiter ---
    // In VSync mode (fpsLimit == 0), FrameAnimation runs every Wayland/X11 display frame.
    // In Capped FPS mode (fpsLimit > 0), FrameAnimation renders 1 frame, then pauses
    // while the one-shot Timer waits for the next frame interval.
    // If the monitor turns off (DPMS) on the lock screen or desktop, the compositor stops
    // firing FrameAnimation, so BOTH VSync and Capped FPS modes automatically drop to
    // 0 FPS / 0 timer wakeups (0% CPU & GPU) until the display turns back on.
    property bool waitingForNextInterval: false
    property double lastRenderMs: 0

    onShouldAnimateChanged: {
        if (shouldAnimate) {
            waitingForNextInterval = false;
            lastRenderMs = Date.now();
        }
    }

    onFpsLimitChanged: {
        waitingForNextInterval = false;
        lastRenderMs = Date.now();
    }

    FrameAnimation {
        id: frameClock
        running: root.shouldAnimate && !root.waitingForNextInterval
        onTriggered: {
            var now = Date.now();
            var dt = (root.fpsLimit === 0)
                ? frameTime
                : ((root.lastRenderMs > 0) ? (now - root.lastRenderMs) * 0.001 : frameTime);
            root.lastRenderMs = now;
            root.advanceAnimation(dt);

            if (root.fpsLimit > 0) {
                root.waitingForNextInterval = true;
                fpsLimiterTimer.interval = Math.max(4, Math.round(1000.0 / root.fpsLimit));
                fpsLimiterTimer.restart();
            }
        }
    }

    Timer {
        id: fpsLimiterTimer
        repeat: false
        running: false
        onTriggered: {
            root.waitingForNextInterval = false;
        }
    }

    // --- Single-pass GPU Fragment Shader ---
    ShaderEffect {
        id: shader
        anchors.fill: parent
        blending: false

        property real u_time: 0.0
        property real u_width: Math.max(width, 1.0)
        property real u_height: Math.max(height, 1.0)

        property vector4d u_slidePhases: Qt.vector4d(0.0, 0.0, 0.0, 0.0)
        property vector4d u_bobPhases: Qt.vector4d(0.0, 0.0, 0.0, 0.0)

        property vector4d u_bgStart: root.colorToVec4(root.activePalette.bgStart)
        property vector4d u_bgMid:   root.colorToVec4(root.activePalette.bgMid)
        property vector4d u_bgEnd:   root.colorToVec4(root.activePalette.bgEnd)

        property vector4d u_wave1:   root.colorToVec4(root.activePalette.wave1)
        property vector4d u_wave2:   root.colorToVec4(root.activePalette.wave2)
        property vector4d u_wave3:   root.colorToVec4(root.activePalette.wave3)
        property vector4d u_wave4:   root.colorToVec4(root.activePalette.wave4)

        vertexShader: Qt.resolvedUrl("shaders/xmb.vert.qsb")
        fragmentShader: Qt.resolvedUrl("shaders/xmb.frag.qsb")

        Component.onCompleted: {
            // Subtly randomize initial wave phases on load
            root.sPhase1 = Math.random() * 0.5;
            root.sPhase2 = Math.random() * 0.5;
            root.sPhase3 = Math.random() * 0.5;
            root.sPhase4 = Math.random() * 0.5;

            root.bPhase1 = Math.random() * 2.0;
            root.bPhase2 = Math.random() * 2.0;
            root.bPhase3 = Math.random() * 2.0;
            root.bPhase4 = Math.random() * 2.0;

            u_slidePhases = Qt.vector4d(root.sPhase1, root.sPhase2, root.sPhase3, root.sPhase4);
            u_bobPhases   = Qt.vector4d(root.bPhase1, root.bPhase2, root.bPhase3, root.bPhase4);

            root.lastRenderMs = Date.now();
            root.loading = false;
        }
    }
}
