/* Copland OS installer: the Apps page (packagechooserq@apps, iso/calamares/).
 * The ids are copland-extras' (core/bin/copland-extras --list). */
import QtQuick 2.15

CoplandChooser {
    heading: qsTr("Apps")
    intro: qsTr("Click the ones you want. They download at the end of the install (internet needed).")
    onChanged: function(ids) { config.packageChoice = ids }
    items: [
        { id: "brave", name: "Brave Origin", from: qsTr("Brave's repository"),
          what: qsTr("Web browser with ad blocking"),
          about: qsTr("Brave without its AI, Rewards, Wallet and VPN; ad and tracker blocking stays. Becomes the default browser, in the Copland colour. Firefox stays installed."),
          icon: "extras/brave-icon.png", picture: "extras/brave-shot.png" },
        { id: "libreoffice", name: "LibreOffice", from: "Debian",
          what: qsTr("Documents, spreadsheets, presentations"),
          about: qsTr("Writer, Calc and Impress. Opens and saves Microsoft Office files."),
          icon: "extras/libreoffice-icon.png", picture: "extras/libreoffice-shot.png" },
        { id: "thunderbird", name: "Thunderbird", from: "Debian",
          what: qsTr("Mail, calendar and contacts"),
          about: qsTr("Mail, calendar and contacts, from the makers of Firefox."),
          icon: "extras/thunderbird-icon.png", picture: "extras/thunderbird-shot.png" },
        { id: "gimp", name: "GIMP", from: "Debian",
          what: qsTr("Photo and image editor"),
          about: qsTr("Photo retouching, drawing and image editing, set to the desktop's colours."),
          icon: "extras/gimp-icon.png", picture: "extras/gimp-shot.png" },
        { id: "vlc", name: "VLC", from: "Debian",
          what: qsTr("Video and music player"),
          about: qsTr("Plays almost any video and music file, DVDs and streams."),
          icon: "extras/vlc-icon.png", picture: "extras/vlc-shot.png" },
        { id: "obs", name: "OBS Studio", from: "Debian",
          what: qsTr("Screen recording and streaming"),
          about: qsTr("Records your screen and streams live, with a Copland theme."),
          icon: "extras/obs-icon.png", picture: "extras/obs-shot.png" },
        { id: "keepassxc", name: "KeePassXC", from: "Debian",
          what: qsTr("Password manager"),
          about: qsTr("Keeps your passwords in one encrypted file on this computer."),
          icon: "extras/keepassxc-icon.png", picture: "extras/keepassxc-shot.png" },
        { id: "flatpak", name: "Flatpak and Flathub", from: qsTr("Debian, apps from Flathub"),
          what: qsTr("More apps: Steam, Discord, Spotify..."),
          about: qsTr("Adds Flathub, where apps like Steam, Discord and Spotify install in one click, each in its own sandbox. Flathub is run by the Flatpak project, not by Debian."),
          icon: "extras/flatpak-icon.png", picture: "extras/flatpak-shot.png" }
    ]
}
