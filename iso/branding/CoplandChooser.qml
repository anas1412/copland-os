/* Copland OS installer: a checklist of optional software, used by the Apps and Developer
 * tools pages (choose-apps.qml, choose-dev.qml).
 *
 *   left   one row per item: checkbox, icon, name, what it is, where it comes from.
 *          A click anywhere on a row ticks or unticks it. Nothing is ticked at first.
 *   right  the item under the mouse (or last clicked): its real screenshot, or its
 *          logo when it has no window to show, and its full description.
 *
 * "chosen" holds the ticked ids in the page's order, comma-separated; the page passes
 * it to Calamares (config.packageChoice) and the copland-extras job installs them.
 * Pictures: iso/branding/extras/, sources and licences in extras/CREDITS.
 * Colours and fonts are the palette tokens (docs/DESIGN.md).
 */
import QtQuick 2.15

Rectangle {
    id: root
    property string heading
    property string intro
    // each item: { id, name, what, from, about, icon, picture }
    property var items: []
    property string chosen: ""
    property int current: 0
    signal changed(string ids)

    color: "#101838"

    function isTicked(id) { return ("," + chosen + ",").indexOf("," + id + ",") >= 0; }
    function toggle(id) {
        var picked = [];
        for (var i = 0; i < items.length; ++i) {
            var on = isTicked(items[i].id);
            if (items[i].id === id) on = !on;
            if (on) picked.push(items[i].id);
        }
        chosen = picked.join(",");
        changed(chosen);
    }

    Column {
        id: top
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
        spacing: 4
        Text {
            text: root.heading
            color: "#ffffff"
            font { family: "C059"; bold: true; italic: true; pixelSize: 22 }
        }
        Text {
            width: parent.width
            text: root.intro
            color: "#ccddff"
            wrapMode: Text.WordWrap
            font { family: "Nimbus Sans"; pixelSize: 13 }
        }
    }

    // ---------------------------------------------------------------- the list
    // whose pictures these are (sources: extras/CREDITS)
    Text {
        id: owners
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom
                  leftMargin: 16; rightMargin: 16; bottomMargin: 6 }
        text: qsTr("Names, logos and screenshots belong to their owners and only show which program is installed.")
        color: "#738dc1"
        elide: Text.ElideRight
        font { family: "Nimbus Sans"; pixelSize: 10 }
    }

    ListView {
        id: list
        anchors { left: parent.left; top: top.bottom; bottom: owners.top
                  leftMargin: 10; topMargin: 10; bottomMargin: 6 }
        width: Math.round(parent.width * 0.52)
        clip: true
        spacing: 2
        model: root.items
        boundsBehavior: Flickable.StopAtBounds

        delegate: Rectangle {
            id: row
            readonly property bool ticked: root.isTicked(modelData.id)
            width: list.width - 8          // room for the scroll bar
            height: 40
            radius: 3
            color: ticked ? "#1c2852" : (mouse.containsMouse ? "#46baef2e" : "transparent")
            border { width: index === root.current ? 1 : 0; color: "#197aba" }

            Rectangle {
                id: box
                anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                width: 18; height: 18; radius: 3
                color: row.ticked ? "#197aba" : "transparent"
                border { color: row.ticked ? "#46baef" : "#738dc1"; width: 2 }
                Text {
                    anchors.centerIn: parent
                    visible: row.ticked
                    text: "✓"
                    color: "#ffffff"
                    font { family: "DejaVu Sans"; bold: true; pixelSize: 13 }
                }
            }
            Image {
                id: icon
                anchors { left: box.right; leftMargin: 10; verticalCenter: parent.verticalCenter }
                width: 28; height: 28
                source: modelData.icon
                sourceSize { width: 56; height: 56 }
                fillMode: Image.PreserveAspectFit
                smooth: true; mipmap: true
            }
            Column {
                anchors { left: icon.right; leftMargin: 10; right: parent.right; rightMargin: 8
                          verticalCenter: parent.verticalCenter }
                Row {
                    spacing: 8
                    width: parent.width
                    Text {
                        id: name
                        text: modelData.name
                        color: "#ffffff"
                        font { family: "Nimbus Sans"; bold: true; pixelSize: 14 }
                    }
                    Text {
                        anchors.baseline: name.baseline
                        width: parent.width - name.width - 8
                        text: modelData.from
                        color: "#46baef"
                        elide: Text.ElideRight
                        font { family: "Nimbus Sans"; pixelSize: 11 }
                    }
                }
                Text {
                    width: parent.width
                    text: modelData.what
                    color: "#ccddff"
                    elide: Text.ElideRight
                    font { family: "Nimbus Sans"; pixelSize: 12 }
                }
            }
            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.current = index
                onClicked: { root.current = index; root.toggle(modelData.id); }
            }
        }
    }

    // a scroll bar, only when the list is longer than the page (small windows)
    Rectangle {
        visible: list.contentHeight > list.height
        anchors { left: list.right; leftMargin: -4 }
        y: list.y + list.visibleArea.yPosition * list.height
        width: 4; radius: 2
        height: list.visibleArea.heightRatio * list.height
        color: "#46baef"
        opacity: 0.6
    }

    // ------------------------------------------------------------- the preview
    Item {
        id: preview
        readonly property var item: root.items.length ? root.items[root.current] : null
        anchors { left: list.right; right: parent.right; top: top.bottom; bottom: owners.top
                  leftMargin: 14; rightMargin: 14; topMargin: 10; bottomMargin: 6 }

        // the text sits at the bottom, the picture takes the rest (no size loop)
        Rectangle {
            id: frame
            anchors { left: parent.left; right: parent.right; top: parent.top
                      bottom: about.top; bottomMargin: 10 }
            color: "#141c3a"
            border { color: "#197aba"; width: 1 }
            Image {
                anchors { fill: parent; margins: preview.item && preview.item.picture ? 1 : parent.height * 0.22 }
                source: preview.item ? (preview.item.picture || preview.item.icon) : ""
                fillMode: Image.PreserveAspectFit
                smooth: true; mipmap: true
                asynchronous: true
            }
        }
        Text {
            id: about
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: Math.max(implicitHeight, 52)
            verticalAlignment: Text.AlignTop
            text: preview.item ? preview.item.about : ""
            color: "#ccddff"
            wrapMode: Text.WordWrap
            font { family: "Nimbus Sans"; pixelSize: 13 }
        }
    }
}
