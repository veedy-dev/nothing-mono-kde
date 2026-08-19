/*
 * SPDX-FileCopyrightText: 2026 Veedy
 *
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

import org.kde.kcmutils // KCMLauncher
import org.kde.config as KConfig
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmaComponents3.ItemDelegate {
    id: root

    property bool hdrAvailable: false
    property bool hdrEnabled: false
    property bool busy: true
    property string outputName: ""
    property string errorText: ""

    background.visible: highlighted
    highlighted: activeFocus
    hoverEnabled: false

    Accessible.description: status.text
    KeyNavigation.tab: hdrSwitch

    function refresh() {
        busy = true;
        commandRunner.exec("/usr/bin/kscreen-doctor -j", result => {
            try {
                const config = JSON.parse(result.stdout);
                const outputs = config.outputs ?? [];
                const output = outputs.find(candidate => candidate.connected && candidate.enabled && candidate.priority === 1)
                    ?? outputs.find(candidate => candidate.connected && candidate.enabled);
                if (!output || typeof output.hdr !== "boolean") {
                    throw new Error(i18n("No active HDR-capable display"));
                }
                outputName = output.name;
                hdrEnabled = output.hdr;
                hdrAvailable = true;
                errorText = "";
            } catch (error) {
                hdrAvailable = false;
                errorText = error.message;
            }
            busy = false;
        });
    }

    function setHdrEnabled(shouldEnable) {
        busy = true;
        errorText = "";
        const action = shouldEnable ? "enable" : "disable";
        const command = `/usr/bin/kscreen-doctor output.activeOutput.hdr.${action} output.activeOutput.wcg.${action}`;
        commandRunner.exec(command, result => {
            if (result.exitCode !== 0) {
                errorText = result.stderr.trim() || i18n("Could not change HDR mode");
                busy = false;
                return;
            }
            refreshTimer.restart();
        });
    }

    contentItem: RowLayout {
        spacing: Kirigami.Units.gridUnit

        Kirigami.Icon {
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: Kirigami.Units.iconSizes.medium
            Layout.preferredHeight: Kirigami.Units.iconSizes.medium
            source: "brightness-high-symbolic"
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: Kirigami.Units.smallSpacing

            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents3.Label {
                    text: root.text
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                PlasmaComponents3.Label {
                    id: status
                    text: root.busy ? i18nc("HDR state", "Checking…")
                        : root.errorText ? i18nc("HDR state", "Unavailable")
                        : root.hdrEnabled ? i18nc("HDR state", "Enabled")
                        : i18nc("HDR state", "Disabled")
                    textFormat: Text.PlainText
                    color: root.errorText ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
                    opacity: root.errorText ? 1 : 0.75
                }
            }

            RowLayout {
                spacing: Kirigami.Units.smallSpacing

                QQC2.Switch {
                    id: hdrSwitch
                    Layout.fillWidth: true
                    text: i18nc("@action:button", "High Dynamic Range")
                    checked: root.hdrEnabled
                    enabled: root.hdrAvailable && !root.busy
                    onClicked: root.setHdrEnabled(checked)
                }

                PlasmaComponents3.Button {
                    visible: KConfig.KAuthorized.authorizeControlModule("kcm_kscreen")
                    icon.name: "configure"
                    text: i18n("Configure…")
                    Layout.alignment: Qt.AlignRight
                    KeyNavigation.up: root.KeyNavigation.up
                    KeyNavigation.backtab: hdrSwitch
                    KeyNavigation.left: hdrSwitch
                    onClicked: KCMLauncher.openSystemSettings("kcm_kscreen")
                }
            }

            PlasmaComponents3.Label {
                text: root.errorText || (root.outputName
                    ? i18n("HDR and wide color gamut on %1", root.outputName)
                    : i18n("HDR and wide color gamut"))
                textFormat: Text.PlainText
                color: root.errorText ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
                opacity: root.errorText ? 1 : 0.75
                font: Kirigami.Theme.smallFont
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }
    }

    P5Support.DataSource {
        id: commandRunner

        property var callbacks: ({})
        engine: "executable"
        connectedSources: []

        function exec(command, callback) {
            callbacks[command] = callback;
            connectSource(command);
        }

        onNewData: function (source, data) {
            const callback = callbacks[source];
            disconnectSource(source);
            delete callbacks[source];
            if (callback) {
                callback({
                    exitCode: data["exit code"],
                    stdout: data.stdout ?? "",
                    stderr: data.stderr ?? ""
                });
            }
        }
    }

    Timer {
        id: refreshTimer
        interval: 500
        onTriggered: root.refresh()
    }

    Component.onCompleted: refresh()
}
