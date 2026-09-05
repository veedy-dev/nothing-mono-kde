import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.workspace.dbus as DBus

PlasmoidItem {
    id: root
    readonly property string edgeGroup: "right"
    readonly property bool edgeVisible: edgeGroupState.properties.RightVisible ?? true
    opacity: edgeVisible ? 1 : 0

    Behavior on opacity {
        NumberAnimation { duration: 300; easing.type: Easing.InOutCubic }
    }

    DBus.Properties {
        id: edgeGroupState
        busType: DBus.BusType.Session
        service: "org.nothingos.EdgeGroups"
        path: "/EdgeGroups"
        iface: "org.nothingos.EdgeGroups"
    }

    function reportEdgeHover(hovered) {
        DBus.SessionBus.asyncCall({
            service: "org.nothingos.EdgeGroups",
            path: "/EdgeGroups",
            iface: "org.nothingos.EdgeGroups",
            member: "SetHovered",
            arguments: [root.edgeGroup, String(plasmoid.id), hovered],
            signature: "ssb"
        })
    }

    HoverHandler {
        onHoveredChanged: root.reportEdgeHover(hovered)
    }

    Component.onDestruction: root.reportEdgeHover(false)

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    property real cpu: 0.0
    property var _prevCpu: null

    // historia ostatnich N próbek (0.0 – 1.0)
    property var history: []
    readonly property int maxHistory: 40

    FontLoader {
        id: ndotFont
        source: Qt.resolvedUrl("../fonts/ndot.ttf")
    }

    P5Support.DataSource {
        id: ds
        engine: "executable"
        connectedSources: []

        onNewData: (sourceName, data) => {
            if (data && data["exit code"] === 0) {
                root._handleCpu(data.stdout || "");
            }
            disconnectSource(sourceName);
        }

        function refresh() {
            connectSource("cat /proc/stat | head -1");
        }
    }

    function _handleCpu(raw) {
        var line = raw.split("\n")[0];
        var parts = line.trim().split(/\s+/).slice(1).map(Number);
        if (parts.length < 4) return;

        var idle    = parts[3] + (parts[4] || 0);
        var nonIdle = parts[0] + parts[1] + parts[2]
                    + (parts[5] || 0) + (parts[6] || 0) + (parts[7] || 0);
        var total = idle + nonIdle;

        if (_prevCpu) {
            var dt = total - _prevCpu.total;
            var di = idle  - _prevCpu.idle;
            if (dt > 0) {
                cpu = (dt - di) / dt;
                // dodaj do historii
                var h = history.slice();
                h.push(cpu);
                if (h.length > maxHistory) h.shift();
                history = h;
                
            }
        }
        _prevCpu = { total: total, idle: idle };
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: ds.refresh()
    }

    fullRepresentation: Item {
        Layout.preferredWidth:  260
        Layout.preferredHeight: 130
        Layout.minimumWidth:    200
        Layout.minimumHeight:   100

        Rectangle {
            anchors.fill: parent
            anchors.margins: 10
            color: "#1a1a1a"
            radius: 0
            clip: true

            Column {
                anchors {
                    fill: parent
                    margins: 16
                }
                spacing: 10

                // ── nagłówek ────────────────────────────────────────────────
                Row {
                    width: parent.width
                    spacing: 0

                    Text {
                        text: "CPU"
                        color: "#ffffff"
                        font.pixelSize: 12
                        font.letterSpacing: 3
                        font.weight: Font.Medium
                        font.family: Kirigami.Theme.defaultFont.family
                        opacity: 0.5
                        width: parent.width / 2
                    }

                    Text {
                        text: Math.round(root.cpu * 100) + "%"
                        color: "#ffffff"
                        font.pixelSize: 12
                        font.letterSpacing: 1
                        font.family: ndotFont.name
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignRight
                        width: parent.width / 2
                    }
                }

                // ── wykres kropkowany ────────────────────────────────────────
                Canvas {
                    id: chart
                    width: parent.width
                    height: parent.height - 30   // reszta po nagłówku

                    // przerysuj przy każdej zmianie historii

                    Connections {
                        target: root
                        function onHistoryChanged() {
                            chart.requestPaint()
                        }
                    }
                    Component.onCompleted: requestPaint()

                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);

                        var cols = root.maxHistory;   // liczba kolumn kropek
                        var rows = 10;                // liczba wierszy kropek

                        var dotR   = 2.0;             // promień kropki
                        var gapX   = width  / cols;
                        var gapY   = height / rows;

                        var hist = root.history;

                        for (var col = 0; col < cols; col++) {
                            // wartość dla tej kolumny (wyrównaj do prawej)
                            var histIdx = hist.length - cols + col;
                            var val = (histIdx >= 0 && histIdx < hist.length)
                                      ? hist[histIdx] : 0;

                            // ile wierszy od dołu ma być zapalonych
                            var lit = Math.round(val * rows);

                            for (var row = 0; row < rows; row++) {
                                var cx = gapX * col + gapX / 2;
                                var cy = height - (gapY * row + gapY / 2);

                                // wiersz 0 = dół, zapalamy od dołu
                                var isLit = row < lit;

                                ctx.beginPath();
                                ctx.arc(cx, cy, dotR, 0, Math.PI * 2);

                                if (isLit) {
                                    // kolor zależy od wartości
                                    if (val > 0.85)
                                        ctx.fillStyle = "#FF3B30";
                                    else if (val > 0.6)
                                        ctx.fillStyle = "#FF9F0A";
                                    else
                                        ctx.fillStyle = "#ffffff";
                                } else {
                                    ctx.fillStyle = "rgba(255,255,255,0.08)";
                                }

                                ctx.fill();
                            }
                        }
                    }
                }
            }
        }
    }
}
