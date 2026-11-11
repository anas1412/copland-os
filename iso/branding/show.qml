/* Copland OS installer slideshow. Based on Debian's calamares-settings-debian show.qml
 * (GPL-3.0-or-later, Teo Mrnjavac, Jonathan Carter). */

import QtQuick 2.0;
import calamares.slideshow 1.0;

Presentation
{
    id: presentation

    Timer {
        interval: 20000
        repeat: true
        onTriggered: presentation.goToNextSlide()
    }

    Slide {
        Image {
            id: background1
            source: "slide1.png"
            width: 467; height: 293
            fillMode: Image.PreserveAspectFit
            anchors.centerIn: parent
        }
        Text {
            anchors.horizontalCenter: background1.horizontalCenter
            anchors.top: background1.bottom
            text: qsTr("Present day, present time.<br/>"+
                  "Copland OS Enterprise is being installed. The rest is automated and takes a few minutes.")
            wrapMode: Text.WordWrap
            width: 600
            horizontalAlignment: Text.Center
        }
    }
}
