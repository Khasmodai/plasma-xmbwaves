/*
 * SPDX-FileCopyrightText: 2026 XMB Waves Contributors
 * SPDX-License-Identifier: MIT
 */

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kquickcontrols as KQuickControls
import org.kde.kirigami as Kirigami

import "ColorSchemes.js" as ColorSchemes

Kirigami.FormLayout {
    id: root

    // Standard Plasma 6 Wallpaper KCM / ConfigurationContainmentAppearance properties
    property var configDialog
    property var wallpaperConfiguration
    property var parentLayout
    property var screenSize

    twinFormLayouts: parentLayout

    signal configurationChanged()

    function tr(text) {
        return typeof i18nd === "function"
            ? i18nd("plasma_wallpaper_org.kde.plasma.xmbwaves", text)
            : text;
    }

    // NOTE: Do NOT declare `property alias formLayout: root` or `property alias cfg_*`.
    // In Qt 6 QML, an alias to the root item (`formLayout: root`) has no notify signal
    // and shifts the notify signal table indices of all subsequent `property alias`
    // declarations by -1, causing KCM signal handlers to receive the wrong property's
    // changed signal. Explicit properties below ensure 1:1 notify signals in both
    // Desktop Wallpaper settings and Lock Screen (kcm_screenlocker) settings.
    property int cfg_FpsLimit: 0
    property int cfg_FpsLimitDefault: 0
    property double cfg_SpeedMultiplier: 1.0
    property double cfg_SpeedMultiplierDefault: 1.0
    property bool cfg_SmartPause: true
    property bool cfg_SmartPauseDefault: true

    property int cfg_ColorMode: 0
    property int cfg_ColorModeDefault: 0
    property string cfg_PresetScheme: "celestial_silk"
    property string cfg_PresetSchemeDefault: "celestial_silk"
    property color cfg_HarmonyBaseColor: "#5b8dd9"
    property color cfg_HarmonyBaseColorDefault: "#5b8dd9"
    property int cfg_HarmonyStyle: 0
    property int cfg_HarmonyStyleDefault: 0

    property color cfg_BgColorStart: "#c9d6e8"
    property color cfg_BgColorStartDefault: "#c9d6e8"
    property color cfg_BgColorMid: "#b8c8df"
    property color cfg_BgColorMidDefault: "#b8c8df"
    property color cfg_BgColorEnd: "#c4d0e4"
    property color cfg_BgColorEndDefault: "#c4d0e4"

    property color cfg_Wave1Color: "#8fb0e8"
    property color cfg_Wave1ColorDefault: "#8fb0e8"
    property color cfg_Wave2Color: "#9a8fe0"
    property color cfg_Wave2ColorDefault: "#9a8fe0"
    property color cfg_Wave3Color: "#7aa2e6"
    property color cfg_Wave3ColorDefault: "#7aa2e6"
    property color cfg_Wave4Color: "#3f58b0"
    property color cfg_Wave4ColorDefault: "#3f58b0"

    readonly property var previewPalette: ColorSchemes.resolvePalette(
        root.cfg_ColorMode,
        root.cfg_PresetScheme,
        root.cfg_HarmonyBaseColor,
        root.cfg_HarmonyStyle,
        {
            bgStart: root.cfg_BgColorStart,
            bgMid:   root.cfg_BgColorMid,
            bgEnd:   root.cfg_BgColorEnd,
            wave1:   root.cfg_Wave1Color,
            wave2:   root.cfg_Wave2Color,
            wave3:   root.cfg_Wave3Color,
            wave4:   root.cfg_Wave4Color
        }
    )

    function colorToVec4(c) {
        var col = Qt.color(c);
        return Qt.vector4d(col.r, col.g, col.b, col.a);
    }

    function notifySettingModified(key, val) {
        root["cfg_" + key] = val;
        // In kcm_screenlocker (where configDialog.applyWallpaper is undefined),
        // also ensure wallpaperConfiguration is updated and configurationChanged()
        // is emitted (KDE Bug 438585 workaround in WallpaperConfig.qml).
        if (root.wallpaperConfiguration && (!root.configDialog || root.configDialog.applyWallpaper === undefined)) {
            root.wallpaperConfiguration[key] = val;
        }
        root.configurationChanged();
    }

    function copyPaletteToCustom(pal) {
        root.notifySettingModified("BgColorStart", Qt.color(pal.bgStart));
        root.notifySettingModified("BgColorMid",   Qt.color(pal.bgMid));
        root.notifySettingModified("BgColorEnd",   Qt.color(pal.bgEnd));
        root.notifySettingModified("Wave1Color",   Qt.color(pal.wave1));
        root.notifySettingModified("Wave2Color",   Qt.color(pal.wave2));
        root.notifySettingModified("Wave3Color",   Qt.color(pal.wave3));
        root.notifySettingModified("Wave4Color",   Qt.color(pal.wave4));
    }

    // --- Live Shader Preview Banner ---
    Item {
        Kirigami.FormData.label: root.tr("Live Preview:")
        Layout.fillWidth: true
        Layout.preferredHeight: Kirigami.Units.gridUnit * 7
        Layout.maximumWidth: Kirigami.Units.gridUnit * 24

        Rectangle {
            id: previewFrame
            anchors.fill: parent
            radius: Kirigami.Units.smallSpacing
            border.color: Kirigami.Theme.textColor
            border.width: 1
            color: "transparent"
            clip: true

            ShaderEffect {
                id: previewShader
                anchors.fill: parent
                anchors.margins: 1
                blending: false

                property real u_time: 12.0
                property real u_width: Math.max(width, 1.0)
                property real u_height: Math.max(height, 1.0)
                property vector4d u_slidePhases: Qt.vector4d(0.12, 0.31, 0.05, 0.42)
                property vector4d u_bobPhases: Qt.vector4d(0.3, 1.1, 0.7, 1.5)

                property vector4d u_bgStart: root.colorToVec4(root.previewPalette.bgStart)
                property vector4d u_bgMid:   root.colorToVec4(root.previewPalette.bgMid)
                property vector4d u_bgEnd:   root.colorToVec4(root.previewPalette.bgEnd)
                property vector4d u_wave1:   root.colorToVec4(root.previewPalette.wave1)
                property vector4d u_wave2:   root.colorToVec4(root.previewPalette.wave2)
                property vector4d u_wave3:   root.colorToVec4(root.previewPalette.wave3)
                property vector4d u_wave4:   root.colorToVec4(root.previewPalette.wave4)

                vertexShader: Qt.resolvedUrl("shaders/xmb.vert.qsb")
                fragmentShader: Qt.resolvedUrl("shaders/xmb.frag.qsb")
            }

            Timer {
                interval: 33
                repeat: true
                running: root.visible && root.cfg_FpsLimit >= 0 && root.cfg_SpeedMultiplier > 0
                onTriggered: {
                    previewShader.u_time += 0.033 * root.cfg_SpeedMultiplier * 2.5;
                }
            }
        }
    }

    // ========================================================================
    // Section 1: Performance & Animation
    // ========================================================================
    Kirigami.Separator {
        Kirigami.FormData.isSection: true
        Kirigami.FormData.label: root.tr("Performance & Animation")
    }

    QQC2.ComboBox {
        id: fpsCombo
        Kirigami.FormData.label: root.tr("Frame Rate Limit:")
        textRole: "text"
        valueRole: "value"
        model: [
            { text: root.tr("VSync (Native Monitor Refresh Rate)"), value: 0 },
            { text: root.tr("60 FPS"), value: 60 },
            { text: root.tr("30 FPS (Recommended for Power Saving)"), value: 30 },
            { text: root.tr("24 FPS (Cinematic)"), value: 24 },
            { text: root.tr("15 FPS (Ultra Low Power)"), value: 15 },
            { text: root.tr("Static / Paused (0% GPU)"), value: -1 }
        ]
        onActivated: root.notifySettingModified("FpsLimit", currentValue)
        Component.onCompleted: currentIndex = Math.max(0, indexOfValue(root.cfg_FpsLimit))
    }

    Connections {
        target: root
        function onCfg_FpsLimitChanged() {
            var idx = fpsCombo.indexOfValue(root.cfg_FpsLimit);
            if (idx >= 0 && fpsCombo.currentIndex !== idx) {
                fpsCombo.currentIndex = idx;
            }
        }
    }

    RowLayout {
        Kirigami.FormData.label: root.tr("Animation Speed:")
        spacing: Kirigami.Units.smallSpacing

        QQC2.Slider {
            id: speedSlider
            from: 0.1
            to: 3.0
            stepSize: 0.05
            value: root.cfg_SpeedMultiplier
            Layout.preferredWidth: Kirigami.Units.gridUnit * 12
            onMoved: root.notifySettingModified("SpeedMultiplier", Math.round(value * 20.0) / 20.0)
        }

        QQC2.Label {
            text: Number(root.cfg_SpeedMultiplier).toFixed(2) + "x"
            Layout.minimumWidth: Kirigami.Units.gridUnit * 3
        }

        QQC2.ToolButton {
            icon.name: "edit-reset"
            enabled: Math.abs(root.cfg_SpeedMultiplier - 1.0) > 0.01
            onClicked: root.notifySettingModified("SpeedMultiplier", 1.0)
            QQC2.ToolTip.visible: hovered
            QQC2.ToolTip.text: root.tr("Reset speed to 1.00x")
        }
    }

    QQC2.CheckBox {
        id: smartPauseCheck
        Kirigami.FormData.label: root.tr("Smart Pause:")
        text: root.tr("Pause when screen is covered by a maximized window")
        checked: root.cfg_SmartPause
        onToggled: root.notifySettingModified("SmartPause", checked)
    }

    Connections {
        target: root
        function onCfg_SmartPauseChanged() {
            if (smartPauseCheck.checked !== root.cfg_SmartPause) {
                smartPauseCheck.checked = root.cfg_SmartPause;
            }
        }
    }

    // ========================================================================
    // Section 2: Color Scheme & Customization
    // ========================================================================
    Kirigami.Separator {
        Kirigami.FormData.isSection: true
        Kirigami.FormData.label: root.tr("Colors & Theme")
    }

    QQC2.ComboBox {
        id: colorModeCombo
        Kirigami.FormData.label: root.tr("Color Mode:")
        textRole: "text"
        valueRole: "value"
        model: [
            { text: root.tr("Preset"), value: 0 },
            { text: root.tr("Harmonized"), value: 1 },
            { text: root.tr("Custom"), value: 2 }
        ]
        onActivated: root.notifySettingModified("ColorMode", currentValue)
        Component.onCompleted: currentIndex = Math.max(0, indexOfValue(root.cfg_ColorMode))
    }

    Connections {
        target: root
        function onCfg_ColorModeChanged() {
            var idx = colorModeCombo.indexOfValue(root.cfg_ColorMode);
            if (idx >= 0 && colorModeCombo.currentIndex !== idx) {
                colorModeCombo.currentIndex = idx;
            }
        }
    }

    // --- Mode 0: Curated Preset Picker ---
    QQC2.ComboBox {
        id: presetCombo
        visible: root.cfg_ColorMode === 0
        Kirigami.FormData.label: root.tr("Preset Scheme:")
        textRole: "name"
        valueRole: "id"
        model: ColorSchemes.PRESETS
        onActivated: root.notifySettingModified("PresetScheme", currentValue)
        Component.onCompleted: currentIndex = Math.max(0, indexOfValue(root.cfg_PresetScheme))
    }

    Connections {
        target: root
        function onCfg_PresetSchemeChanged() {
            var idx = presetCombo.indexOfValue(root.cfg_PresetScheme);
            if (idx >= 0 && presetCombo.currentIndex !== idx) {
                presetCombo.currentIndex = idx;
            }
        }
    }

    // --- Mode 1: Auto-Harmony (Single Seed Color + Background Style) ---
    KQuickControls.ColorButton {
        id: harmonyBaseButton
        visible: root.cfg_ColorMode === 1
        Kirigami.FormData.label: root.tr("Base Theme Color:")
        dialogTitle: root.tr("Select Base Color for Harmonious Scheme")
        showAlphaChannel: false
        color: root.cfg_HarmonyBaseColor
        onAccepted: selectedColor => root.notifySettingModified("HarmonyBaseColor", selectedColor)
    }

    Connections {
        target: root
        function onCfg_HarmonyBaseColorChanged() {
            if (harmonyBaseButton.color !== root.cfg_HarmonyBaseColor) {
                harmonyBaseButton.color = root.cfg_HarmonyBaseColor;
            }
        }
    }

    QQC2.ComboBox {
        id: harmonyStyleCombo
        visible: root.cfg_ColorMode === 1
        Kirigami.FormData.label: root.tr("Harmony Style:")
        textRole: "text"
        valueRole: "value"
        model: [
            { text: root.tr("Soft Silk (Light)"), value: 0 },
            { text: root.tr("Deep XMB (Midnight Dark)"), value: 1 },
            { text: root.tr("Rich Dusk (Twilight)"), value: 2 }
        ]
        onActivated: root.notifySettingModified("HarmonyStyle", currentValue)
        Component.onCompleted: currentIndex = Math.max(0, indexOfValue(root.cfg_HarmonyStyle))
    }

    Connections {
        target: root
        function onCfg_HarmonyStyleChanged() {
            var idx = harmonyStyleCombo.indexOfValue(root.cfg_HarmonyStyle);
            if (idx >= 0 && harmonyStyleCombo.currentIndex !== idx) {
                harmonyStyleCombo.currentIndex = idx;
            }
        }
    }

    // Active Swatch Bar + "Customize in Individual Mode" shortcut for Modes 0 & 1
    RowLayout {
        visible: root.cfg_ColorMode !== 2
        Kirigami.FormData.label: root.tr("Generated Palette:")
        spacing: Kirigami.Units.smallSpacing

        Repeater {
            model: [
                root.previewPalette.bgStart,
                root.previewPalette.bgMid,
                root.previewPalette.bgEnd,
                root.previewPalette.wave1,
                root.previewPalette.wave2,
                root.previewPalette.wave3,
                root.previewPalette.wave4
            ]
            Rectangle {
                width: Kirigami.Units.gridUnit * 1.4
                height: Kirigami.Units.gridUnit * 1.4
                radius: 4
                color: modelData
                border.color: Kirigami.Theme.textColor
                border.width: 1
            }
        }

        QQC2.Button {
            icon.name: "color-picker"
            text: root.tr("Customize Individual Colors...")
            onClicked: {
                root.copyPaletteToCustom(root.previewPalette);
                root.notifySettingModified("ColorMode", 2);
            }
        }
    }

    // --- Mode 2: Individual Custom Color Pickers ---
    RowLayout {
        visible: root.cfg_ColorMode === 2
        Kirigami.FormData.label: root.tr("Background Gradient (135°):")
        spacing: Kirigami.Units.mediumSpacing

        RowLayout {
            spacing: Kirigami.Units.smallSpacing
            QQC2.Label { text: root.tr("Start:") }
            KQuickControls.ColorButton {
                id: bgStartButton
                dialogTitle: root.tr("Background Start Color (Top-Left)")
                showAlphaChannel: false
                color: root.cfg_BgColorStart
                onAccepted: selectedColor => root.notifySettingModified("BgColorStart", selectedColor)
            }
        }

        RowLayout {
            spacing: Kirigami.Units.smallSpacing
            QQC2.Label { text: root.tr("Middle:") }
            KQuickControls.ColorButton {
                id: bgMidButton
                dialogTitle: root.tr("Background Middle Color (50%)")
                showAlphaChannel: false
                color: root.cfg_BgColorMid
                onAccepted: selectedColor => root.notifySettingModified("BgColorMid", selectedColor)
            }
        }

        RowLayout {
            spacing: Kirigami.Units.smallSpacing
            QQC2.Label { text: root.tr("End:") }
            KQuickControls.ColorButton {
                id: bgEndButton
                dialogTitle: root.tr("Background End Color (Bottom-Right)")
                showAlphaChannel: false
                color: root.cfg_BgColorEnd
                onAccepted: selectedColor => root.notifySettingModified("BgColorEnd", selectedColor)
            }
        }
    }

    Connections {
        target: root
        function onCfg_BgColorStartChanged() {
            if (bgStartButton.color !== root.cfg_BgColorStart) {
                bgStartButton.color = root.cfg_BgColorStart;
            }
        }
        function onCfg_BgColorMidChanged() {
            if (bgMidButton.color !== root.cfg_BgColorMid) {
                bgMidButton.color = root.cfg_BgColorMid;
            }
        }
        function onCfg_BgColorEndChanged() {
            if (bgEndButton.color !== root.cfg_BgColorEnd) {
                bgEndButton.color = root.cfg_BgColorEnd;
            }
        }
    }

    KQuickControls.ColorButton {
        id: wave1Button
        visible: root.cfg_ColorMode === 2
        Kirigami.FormData.label: root.tr("Wave 1 (Top Ribbon):")
        dialogTitle: root.tr("Select Wave 1 Color")
        showAlphaChannel: false
        color: root.cfg_Wave1Color
        onAccepted: selectedColor => root.notifySettingModified("Wave1Color", selectedColor)
    }

    KQuickControls.ColorButton {
        id: wave2Button
        visible: root.cfg_ColorMode === 2
        Kirigami.FormData.label: root.tr("Wave 2 (Upper-Mid Ribbon):")
        dialogTitle: root.tr("Select Wave 2 Color")
        showAlphaChannel: false
        color: root.cfg_Wave2Color
        onAccepted: selectedColor => root.notifySettingModified("Wave2Color", selectedColor)
    }

    KQuickControls.ColorButton {
        id: wave3Button
        visible: root.cfg_ColorMode === 2
        Kirigami.FormData.label: root.tr("Wave 3 (Lower-Mid Ribbon):")
        dialogTitle: root.tr("Select Wave 3 Color")
        showAlphaChannel: false
        color: root.cfg_Wave3Color
        onAccepted: selectedColor => root.notifySettingModified("Wave3Color", selectedColor)
    }

    KQuickControls.ColorButton {
        id: wave4Button
        visible: root.cfg_ColorMode === 2
        Kirigami.FormData.label: root.tr("Wave 4 (Deep Bottom Ribbon):")
        dialogTitle: root.tr("Select Wave 4 Color")
        showAlphaChannel: false
        color: root.cfg_Wave4Color
        onAccepted: selectedColor => root.notifySettingModified("Wave4Color", selectedColor)
    }

    Connections {
        target: root
        function onCfg_Wave1ColorChanged() {
            if (wave1Button.color !== root.cfg_Wave1Color) {
                wave1Button.color = root.cfg_Wave1Color;
            }
        }
        function onCfg_Wave2ColorChanged() {
            if (wave2Button.color !== root.cfg_Wave2Color) {
                wave2Button.color = root.cfg_Wave2Color;
            }
        }
        function onCfg_Wave3ColorChanged() {
            if (wave3Button.color !== root.cfg_Wave3Color) {
                wave3Button.color = root.cfg_Wave3Color;
            }
        }
        function onCfg_Wave4ColorChanged() {
            if (wave4Button.color !== root.cfg_Wave4Color) {
                wave4Button.color = root.cfg_Wave4Color;
            }
        }
    }

    RowLayout {
        visible: root.cfg_ColorMode === 2
        Kirigami.FormData.label: root.tr("Seed Custom Colors:")
        spacing: Kirigami.Units.smallSpacing

        QQC2.Button {
            icon.name: "edit-copy"
            text: root.tr("Load Selected Preset Colors")
            onClicked: root.copyPaletteToCustom(ColorSchemes.getPresetById(root.cfg_PresetScheme))
        }

        QQC2.Button {
            icon.name: "color-management"
            text: root.tr("Load Harmonized Colors")
            onClicked: root.copyPaletteToCustom(ColorSchemes.generateHarmonyPalette(root.cfg_HarmonyBaseColor, root.cfg_HarmonyStyle))
        }
    }
}
