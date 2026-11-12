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
            width: 640; height: 360
            fillMode: Image.PreserveAspectFit
            anchors.centerIn: parent
        }
        Text {
            anchors.horizontalCenter: background1.horizontalCenter
            anchors.top: background1.bottom
            anchors.topMargin: 12
            text: qsTr("Present day, present time.<br/>"+
                  "Copland OS Enterprise is being installed. The rest is automated and takes a few minutes.")
            wrapMode: Text.WordWrap
            width: 600
            horizontalAlignment: Text.Center
        }
    }

    Slide {
        Image {
            id: background2
            source: "slide2.png"
            width: 640; height: 360
            fillMode: Image.PreserveAspectFit
            anchors.centerIn: parent
        }
        Text {
            anchors.horizontalCenter: background2.horizontalCenter
            anchors.top: background2.bottom
            anchors.topMargin: 12
            text: qsTr("Four layers, Layer:01 to Layer:04: press Windows+1 to 4 to switch.<br/>"+
                  "Updates come through one icon in the top bar.")
            wrapMode: Text.WordWrap
            width: 600
            horizontalAlignment: Text.Center
        }
    }
}
