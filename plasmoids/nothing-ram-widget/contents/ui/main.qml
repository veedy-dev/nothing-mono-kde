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

    property real ram: 0.0
    property var totalRam: 0
    property var usedRam: 0
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
                root._handleRam(data.stdout || "");
            }
            disconnectSource(sourceName);
        }

        function refresh() {
            connectSource("cat /proc/meminfo | head -5");
        }
    }

    function _handleRam(raw) {
        var lines = raw.split("\n");
        var total = 0, avail = 0;
        for (var i = 0; i < lines.length; i++) {
            if (lines[i].indexOf("MemTotal:") === 0)
                total = parseInt((lines[i].match(/\d+/) || [0])[0]);
            if (lines[i].indexOf("MemAvailable:") === 0)
                avail = parseInt((lines[i].match(/\d+/) || [0])[0]);
        }
        if (total > 0) {
            ram = 1 - (avail / total);

            usedRam = (total - avail) / 1024 / 1024;
            totalRam = total / 1024 / 1024;

            var h = history.slice();
            h.push(ram);
            if (h.length > maxHistory) h.shift();
            history = h;

        }
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

                Row {
                    width: parent.width

                    Text {
                        text: "RAM"
                        color: "#ffffff"
                        font.family: Kirigami.Theme.defaultFont.family
                        font.pixelSize: 12
                        font.letterSpacing: 3
                        font.weight: Font.Bold
                        opacity: 0.5
                        width: parent.width / 2
                    }

                    Text {
                        text: Math.round(root.ram * 100) + "% " + `( ${root.usedRam.toFixed(1)}  / ${root.totalRam.toFixed(1)} )`
                        color: "#ffffff"
                        font.family: ndotFont.name
                        font.pixelSize: 12
                        font.letterSpacing: 1
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignRight
                        width: parent.width / 2
                    }
                }

                Canvas {
                    id: chart
                    width: parent.width
                    height: parent.height - 30

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

                        var cols = root.maxHistory;
                        var rows = 10;
                        var dotR = 2.0;
                        var gapX = width  / cols;
                        var gapY = height / rows;
                        var hist = root.history;

                        for (var col = 0; col < cols; col++) {
                            var histIdx = hist.length - cols + col;
                            var val = (histIdx >= 0 && histIdx < hist.length)
                                      ? hist[histIdx] : 0;
                            var lit = Math.round(val * rows);

                            for (var row = 0; row < rows; row++) {
                                var cx = gapX * col + gapX / 2;
                                var cy = height - (gapY * row + gapY / 2);
                                ctx.beginPath();
                                ctx.arc(cx, cy, dotR, 0, Math.PI * 2);
                                ctx.fillStyle = row < lit
                                    ? (val > 0.85 ? "#FF3B30" : val > 0.6 ? "#FF9F0A" : "#ffffff")
                                    : "rgba(255,255,255,0.08)";
                                ctx.fill();
                            }
                        }
                    }
                }
            }
        }
    }
}
