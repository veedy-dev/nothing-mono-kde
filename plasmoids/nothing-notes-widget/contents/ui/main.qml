import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
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

    property var notes: []
    property int activeIndex: 0

    function loadNotes() {
        try {
            var parsed = JSON.parse(plasmoid.configuration.notesData)
            notes = parsed.length > 0 ? parsed : defaultNotes()
        } catch(e) {
            notes = defaultNotes()
        }
        activeIndex = Math.min(plasmoid.configuration.activeNoteId, notes.length - 1)
    }

    function saveNotes() {
        plasmoid.configuration.notesData = JSON.stringify(notes)
        plasmoid.configuration.activeNoteId = activeIndex
    }

    function defaultNotes() {
        return [{ id: 1, title: "Note", body: "", createdAt: Date.now() }]
    }

    function addNote() {
        var n = notes.slice()
        var newId = Date.now()
        n.push({ id: newId, title: "Note", body: "", createdAt: newId })
        notes = n
        activeIndex = n.length - 1
        saveNotes()
    }

    function deleteNote(idx) {
        if (notes.length <= 1) return
        var n = notes.slice()
        n.splice(idx, 1)
        notes = n
        if (activeIndex >= n.length) activeIndex = n.length - 1
        saveNotes()
    }

    function updateTitle(idx, val) {
        var n = notes.slice()
        n[idx] = Object.assign({}, n[idx], { title: val })
        notes = n
        saveNotes()
    }

    function updateBody(idx, val) {
        var n = notes.slice()
        n[idx] = Object.assign({}, n[idx], { body: val })
        notes = n
        saveNotes()
    }

    Component.onCompleted: loadNotes()

    fullRepresentation: Item {
        Layout.preferredWidth:  340
        Layout.preferredHeight: 260
        Layout.minimumWidth:    100
        Layout.minimumHeight:   100

        // ── karta notatki ────────────────────────────────────────────────────
        Rectangle {
            id: card
            anchors.fill: parent
            anchors.margins: 10
            color: "#1a1a1a"
            radius: 0

            // ── zagięty róg (prawy dolny) ────────────────────────────────────
            Canvas {
                id: cornerCanvas
                width: 28
                height: 28
                anchors.right: parent.right
                anchors.bottom: parent.bottom

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                }
            }

            Column {
                anchors {
                    fill: parent
                    margins: 0
                }
                spacing: 0

                // ── nagłówek ─────────────────────────────────────────────────
                Item {
                    width: parent.width
                    height: 54

                    // tytuł
                    QQC2.TextField {
                        id: titleField
                        anchors {
                            left: parent.left
                            right: btnRow.left
                            verticalCenter: parent.verticalCenter
                            leftMargin: 20
                            rightMargin: 8
                        }
                        text: root.notes.length > 0 ? root.notes[root.activeIndex].title : ""
                        placeholderText: "Title"
                        font.pixelSize: 20
                        font.family: Kirigami.Theme.defaultFont.family
                        font.letterSpacing: 1
                        color: "#ffffff"
                        placeholderTextColor: "#444"
                        background: null
                        leftPadding: 0

                        onTextChanged: {
                            if (root.notes.length > 0 && text !== root.notes[root.activeIndex].title)
                                root.updateTitle(root.activeIndex, text)
                        }

                        Connections {
                            target: root
                            function onActiveIndexChanged() {
                                titleField.text = root.notes.length > 0
                                    ? root.notes[root.activeIndex].title : ""
                            }
                            function onNotesChanged() {
                                if (root.notes.length > 0)
                                    titleField.text = root.notes[root.activeIndex].title
                            }
                        }
                    }

                    // knopciki + i -
                    Row {
                        id: btnRow
                        anchors {
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            rightMargin: 16
                        }
                        spacing: 4

                        Rectangle {
                            width: 26; height: 26; radius: 13
                            color: addMa.containsMouse ? "#2a2a2a" : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: "+"
                                font.pixelSize: 17
                                color: Qt.rgba(255,255,255,0.5)
                            }
                            MouseArea {
                                id: addMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.addNote()
                            }
                        }

                        Rectangle {
                            width: 26; height: 26; radius: 13
                            visible: root.notes.length > 1
                            color: delMa.containsMouse ? "#2a2a2a" : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: "−"
                                font.pixelSize: 17
                                color: "#FF3B30"
                                opacity: 0.8
                            }
                            MouseArea {
                                id: delMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.deleteNote(root.activeIndex)
                            }
                        }
                    }
                }

                // ── separator ─────────────────────────────────────────────────
                Rectangle {
                    width: parent.width
                    height: 1
                    color: "#252525"
                }

                // ── treść notatki ────────────────────────────────────────────
                QQC2.ScrollView {
                    width: parent.width
                    height: parent.height - 55 - 1 - 38

                    QQC2.TextArea {
                        id: bodyArea
                        width: parent.width
                        wrapMode: TextEdit.Wrap
                        text: root.notes.length > 0 ? root.notes[root.activeIndex].body : ""
                        placeholderText: "Start typing...\n\nTip: use • for bullet points"
                        font.pixelSize: 13
                        font.family: Kirigami.Theme.defaultFont.family
                        color: "#dddddd"
                        placeholderTextColor: "#333"
                        leftPadding: 20
                        rightPadding: 36
                        topPadding: 12
                        bottomPadding: 12
                        background: null

                        // koloruj linie zaczynające się od •
                        textFormat: TextEdit.PlainText

                        onTextChanged: {
                            if (root.notes.length > 0 && text !== root.notes[root.activeIndex].body)
                                root.updateBody(root.activeIndex, text)
                        }

                        Connections {
                            target: root
                            function onActiveIndexChanged() {
                                bodyArea.text = root.notes.length > 0
                                    ? root.notes[root.activeIndex].body : ""
                            }
                        }
                    }
                }

                // ── separator ─────────────────────────────────────────────────
                Rectangle {
                    width: parent.width
                    height: 1
                    color: "#252525"
                }

                // ── zakładki ─────────────────────────────────────────────────
                Item {
                    width: parent.width
                    height: 37

                    Flickable {
                        anchors {
                            fill: parent
                            leftMargin: 16
                            rightMargin: 16
                        }
                        contentWidth: tabRow.implicitWidth
                        clip: true
                        flickableDirection: Flickable.HorizontalFlick

                        Row {
                            id: tabRow
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 5

                            Repeater {
                                model: root.notes

                                Rectangle {
                                    height: 24
                                    width: tabTxt.implicitWidth + 18
                                    radius: 12
                                    color: index === root.activeIndex ? "#ffffff" : "#1e1e1e"

                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    Text {
                                        id: tabTxt
                                        anchors.centerIn: parent
                                        text: modelData.title || "Note"
                                        font.pixelSize: 12
                                        font.family: Kirigami.Theme.defaultFont.family
                                        font.letterSpacing: 1
                                        color: index === root.activeIndex ? "#111111" : "#555555"
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.activeIndex = index
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
