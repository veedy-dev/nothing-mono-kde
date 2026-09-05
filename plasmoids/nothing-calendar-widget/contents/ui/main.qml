import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.workspace.dbus as DBus

PlasmoidItem {
    id: root

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation
    readonly property string edgeGroup: "left"
    readonly property bool edgeVisible: edgeGroupState.properties.LeftVisible ?? true
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

    // ── aktualna data ────────────────────────────────────────────────────────
    property var now:          new Date()
    property int todayDay:     now.getDate()
    property int todayMonth:   now.getMonth()
    property int todayYear:    now.getFullYear()

    // ── widok (nawigacja) ────────────────────────────────────────────────────
    property int viewMonth:    now.getMonth()
    property int viewYear:     now.getFullYear()

    FontLoader {
        id: ndotFont
        source: Qt.resolvedUrl("../fonts/ndot.ttf")
    }

    // odświeżaj datę o północy
    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: {
            root.now       = new Date()
            root.todayDay   = root.now.getDate()
            root.todayMonth = root.now.getMonth()
            root.todayYear  = root.now.getFullYear()
        }
    }

    readonly property var monthNames: [
        "JANUARY","FEBRUARY","MARCH","APRIL","MAY","JUNE",
        "JULY","AUGUST","SEPTEMBER","OCTOBER","NOVEMBER","DECEMBER"
    ]
    readonly property var dayNames: ["MO","TU","WE","TH","FR","SA","SU"]

    // zwraca tablicę 42 elementów (6 tygodni × 7 dni), 0 = puste pole
    function buildGrid(year, month) {
        var first = new Date(year, month, 1).getDay()  // 0=Sun
        // przesuń: chcemy poniedziałek jako pierwszy dzień
        var offset = (first === 0) ? 6 : first - 1
        var days = new Date(year, month + 1, 0).getDate()
        var grid = []
        for (var i = 0; i < offset; i++) grid.push(0)
        for (var d = 1; d <= days; d++) grid.push(d)
        while (grid.length % 7 !== 0) grid.push(0)
        return grid
    }

    function prevMonth() {
        if (viewMonth === 0) { viewMonth = 11; viewYear-- }
        else viewMonth--
    }
    function nextMonth() {
        if (viewMonth === 11) { viewMonth = 0; viewYear++ }
        else viewMonth++
    }

    // ── UI ───────────────────────────────────────────────────────────────────
    fullRepresentation: Item {
        Layout.preferredWidth:  280
        Layout.preferredHeight: 320
        Layout.minimumWidth:    240
        Layout.minimumHeight:   280

        Rectangle {
            anchors.fill: parent
            anchors.margins: 10
            color: "#1a1a1a"
            radius: 0
            clip: true

            Column {
                anchors {
                    fill: parent
                    margins: 18
                }
                spacing: 12

                // ── nagłówek: miesiąc + nawigacja ───────────────────────────
                Item {
                    width: parent.width
                    height: 28

                    // strzałka wstecz
                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        font.family: ndotFont.name
                        text: "‹"
                        color: "#ffffff"
                        font.pixelSize: 20
                        opacity: 0.4
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -8
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.prevMonth()
                        }
                    }

                    // nazwa miesiąca + rok
                    Column {
                        anchors.centerIn: parent
                        spacing: 0

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.monthNames[root.viewMonth]
                            color: "#ffffff"
                            font.pixelSize: 18
                            font.letterSpacing: 1
                            font.weight: Font.Normal
                            font.family: "NType 82 Headline"
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.viewYear
                            color: "#ffffff"
                            font.pixelSize: 12
                            font.letterSpacing: 2
                            font.family: Kirigami.Theme.defaultFont.family
                            opacity: 0.35
                        }
                    }

                    // strzałka naprzód
                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "›"
                        color: "#ffffff"
                        font.pixelSize: 20
                        font.family: ndotFont.name
                        opacity: 0.4
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -8
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.nextMonth()
                        }
                    }
                }

                // ── separator ───────────────────────────────────────────────
                Rectangle {
                    width: parent.width
                    height: 1
                    color: "#2a2a2a"
                }

                // ── nazwy dni tygodnia ───────────────────────────────────────
                Row {
                    width: parent.width
                    spacing: 0

                    Repeater {
                        model: root.dayNames
                        Text {
                            width: parent.width / 7
                            text: modelData
                            color: index >= 5 ? "#555555" : "#444444"
                            font.pixelSize: 10
                            font.letterSpacing: 1
                            font.family: Kirigami.Theme.defaultFont.family
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }

                // ── siatka dni ───────────────────────────────────────────────
                Grid {
                    id: calGrid
                    width: parent.width
                    columns: 7
                    spacing: 0

                    property var grid: root.buildGrid(root.viewYear, root.viewMonth)
                    property int rowCount: Math.max(1, Math.ceil(grid.length / 7))
                    // Keep every week inside the card. Cell width can grow on
                    // the wide layout, but its height must follow the available
                    // vertical space instead of remaining square.
                    property real cellHeight: Math.max(
                        24,
                        (parent.height - y - 16) / rowCount
                    )

                    // przerysuj przy zmianie miesiąca/roku
                    Connections {
                        target: root
                        function onViewMonthChanged() { calGrid.grid = root.buildGrid(root.viewYear, root.viewMonth) }
                        function onViewYearChanged()  { calGrid.grid = root.buildGrid(root.viewYear, root.viewMonth) }
                    }

                    Component.onCompleted: {
                        grid = root.buildGrid(root.viewYear, root.viewMonth)
                    }

                    Repeater {
                        model: calGrid.grid

                        Item {
                            width:  calGrid.width / 7
                            height: calGrid.cellHeight

                            readonly property int day: modelData
                            readonly property bool isToday:
                                day > 0 &&
                                day === root.todayDay &&
                                root.viewMonth === root.todayMonth &&
                                root.viewYear  === root.todayYear

                            // NothingOS-style: dzisiejszy dzień = wypełnione kółko
                            Rectangle {
                                anchors.centerIn: parent
                                width:  Math.min(parent.width, parent.height) * 0.72
                                height: width
                                radius: width / 2
                                color:  isToday ? "#ffffff" : "transparent"
                                visible: day > 0
                            }

                            Text {
                                anchors.centerIn: parent
                                text: day > 0 ? day : ""
                                color: isToday ? "#111111" : "#ffffff"
                                font.pixelSize: 14
                                font.family: Kirigami.Theme.defaultFont.family
                                font.weight: isToday ? Font.DemiBold : Font.Normal
                                opacity: {
                                    if (day === 0) return 0
                                    if (isToday)   return 1
                                    // weekend (SA=col6, SU=col7 — index % 7 >= 5)
                                    var col = index % 7
                                    return col >= 5 ? 0.3 : 0.7
                                }
                            }
                        }
                    }
                }

                // ── trzy kropki NothingOS (dół) ─────────────────────────────
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 5

                    Repeater {
                        model: 3
                        Rectangle {
                            width: 4; height: 4; radius: 2
                            color: index === 1 ? "#ffffff" : "#333333"
                        }
                    }
                }
            }
        }
    }
}
