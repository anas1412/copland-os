/* Copland OS installer slideshow: a short tour of the system while Calamares installs.
 * Started from Debian's calamares-settings-debian show.qml (GPL-3.0-or-later, Teo
 * Mrnjavac, Jonathan Carter); the timer follows Calamares' own example slideshow.
 *
 * One topic per slide, like Ubuntu's and EndeavourOS's installer slides. Every line is
 * true of the installed system (docs/DESIGN.md, "Installer slideshow"). The pictures are
 * real screenshots, made by tools/artwork.py. Colours and fonts are the palette tokens.
 */

import QtQuick 2.15
import calamares.slideshow 1.0

Presentation
{
    id: presentation

    // palette (docs/DESIGN.md)
    readonly property color navyDeep: "#101838"
    readonly property color cyan: "#46baef"
    readonly property color white: "#ffffff"
    readonly property color ink: "#ccddff"      // text
    readonly property color dotIdle: "#4a5c9a"  // term8

    // Qt's Timer does not run by default: it runs while Calamares shows this page.
    // 25 s a slide: two lines read in about 10 s, so nobody is cut off mid-sentence.
    Timer {
        id: advanceTimer
        interval: 25000
        running: presentation.activatedInCalamares
        repeat: true
        onTriggered: presentation.goToNextSlide()
    }
    // a click or a key moves on: give that slide its full time too
    onCurrentSlideChanged: if (advanceTimer.running) advanceTimer.restart()

    // the panel is white by default: navy-deep like the sidebar
    Rectangle {
        anchors.fill: parent
        color: presentation.navyDeep
        z: -1
    }

    // one slide: a heading, an optional picture, one or two lines. Fills the whole
    // panel (Slide's default sits 20 % down, which cut the text off) and scales the
    // picture down to whatever room the heading and text leave.
    component Page: Slide {
        id: page
        property string heading
        property string body
        property url picture
        property string code    // a command, in the terminal's font (StyledText has no font face)

        x: 0; y: 0
        width: presentation.width
        height: presentation.height

        Column {
            id: col
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -dots.height / 2
            width: parent.width - 48
            spacing: 14

            Text {
                id: head
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: page.heading
                color: presentation.white
                font.family: "C059"
                font.bold: true
                font.italic: true
                font.pixelSize: 24
                wrapMode: Text.WordWrap
            }
            Image {
                id: pic
                visible: page.picture != ""
                anchors.horizontalCenter: parent.horizontalCenter
                source: page.picture
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
                // never larger than the screenshot itself, never taller than the room left
                width: Math.min(sourceSize.width, parent.width)
                height: Math.min(sourceSize.height,
                                 page.height - 96 - dots.height - head.height - words.height - cmd.height,
                                 sourceSize.height * width / Math.max(1, sourceSize.width))
            }
            Text {
                id: words
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: page.body
                textFormat: Text.StyledText
                color: presentation.ink
                linkColor: presentation.cyan
                font.family: "Nimbus Sans"
                font.pixelSize: page.picture == "" ? 18 : 15
                lineHeight: 1.15
                wrapMode: Text.WordWrap
            }
            Text {
                id: cmd
                visible: page.code != ""
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: page.code
                textFormat: Text.PlainText
                color: presentation.cyan
                font.family: "DejaVu Sans Mono"
                font.pixelSize: 16
                wrapMode: Text.WrapAnywhere
            }
        }
    }

    Page {
        heading: qsTr("Welcome to Copland OS Enterprise")
        picture: "slide-welcome.png"
        body: qsTr("Copland OS, built on Debian @DEBIAN_VERSION@, is being installed. It runs by itself and takes a few minutes. Meanwhile, a short tour.")
    }
    Page {
        heading: qsTr("Four layers")
        picture: "slide-layers.png"
        body: qsTr("Layer:01 to Layer:04 are four separate desktops. <b>Super+1</b> to <b>4</b> switches layer, <b>Super+Shift+1</b> to <b>4</b> moves the window you are using. Super is the Windows key.")
    }
    Page {
        heading: qsTr("The menu")
        picture: "slide-menu.png"
        body: qsTr("<b>Super</b> opens the Copland OS menu: Firefox, the file manager, a text editor, an image viewer, a PDF reader and the terminal are already there.")
    }
    Page {
        heading: qsTr("Updates")
        body: qsTr("The system checks for updates once a day and tells you when there are some, with a notification and an icon in the top bar. Click the icon to install them: Debian's security fixes and new Copland OS versions come together. Or, in a terminal:")
        code: "sudo apt update && sudo apt upgrade"
    }
    Page {
        heading: qsTr("More software")
        picture: "slide-software.png"
        body: qsTr("Every program in Debian is one command away, for example LibreOffice, GIMP and VLC.")
    }
    Page {
        heading: qsTr("The terminal")
        picture: "slide-terminal.png"
        body: qsTr("Every new terminal opens with a system summary, and btop shows what the machine is doing. Both in the Copland colours.")
    }
    Page {
        heading: qsTr("Help")
        body: qsTr("Copland OS: anas.cyberia.tn/copland-os<br/>Questions and bugs: github.com/anas1412/copland-os/issues<br/>Everything else is Debian: debian.org/doc<br/><br/><i>Close the world, Open the nExt.</i>")
    }

    // where you are in the tour; a dot is also a way back to a slide
    Row {
        id: dots
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 14
        spacing: 10
        height: 10
        z: 1
        Repeater {
            model: presentation.slides.length
            Rectangle {
                width: 10; height: 10; radius: 5
                color: index === presentation.currentSlide ? presentation.cyan : presentation.dotIdle
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -5
                    onClicked: presentation.currentSlide = index
                }
            }
        }
    }

    // Calamares (slideshowAPI 2) calls these when the install page opens and closes
    function onActivate() {
        presentation.currentSlide = 0;
    }
    function onLeave() {
    }
}
