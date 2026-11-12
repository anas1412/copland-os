/* Copland OS installer: the Developer tools page (packagechooserq@dev, iso/calamares/).
 * The ids are copland-extras' (core/bin/copland-extras --list). Every version is a
 * current, supported one (docs/DESIGN.md, "Installer extras"). */
import QtQuick 2.15

CoplandChooser {
    heading: qsTr("Developer tools")
    intro: qsTr("Click the ones you work with. Git and curl are already installed.")
    onChanged: function(ids) { config.packageChoice = ids }
    items: [
        { id: "vscode", name: "Visual Studio Code", from: qsTr("Microsoft's repository"),
          what: qsTr("Code editor"),
          about: qsTr("Code editor, in the Copland colours and window frame, telemetry off."),
          icon: "extras/vscode-icon.png", picture: "extras/vscode-shot.png" },
        { id: "python", name: "Python", from: "Debian",
          what: qsTr("Python 3 with pip, venv and pipx"),
          about: qsTr("Python 3 with pip, venv and pipx, for scripts, apps and projects."),
          icon: "extras/python-icon.png", picture: "" },
        { id: "node", name: "Node.js", from: qsTr("NodeSource's repository"),
          what: qsTr("Current LTS release, with npm"),
          about: qsTr("The current long-term release with npm. Debian's own Node.js 20 has reached its end of life, so this one comes from NodeSource."),
          icon: "extras/node-icon.png", picture: "" },
        { id: "go", name: "Go", from: qsTr("Debian backports"),
          what: qsTr("Current Go release"),
          about: qsTr("The current Go release, from Debian's backports."),
          icon: "extras/go-icon.png", picture: "" },
        { id: "rust", name: "Rust", from: qsTr("Debian's rustup"),
          what: qsTr("Stable toolchain through rustup"),
          about: qsTr("rustup with the current stable toolchain, installed for your account. Update it any time with rustup update."),
          icon: "extras/rust-icon.png", picture: "" },
        { id: "java", name: "Java", from: "Debian",
          what: qsTr("OpenJDK 25, the current LTS"),
          about: qsTr("OpenJDK 25, the current long-term release."),
          icon: "extras/java-icon.png", picture: "" },
        { id: "cpp", name: "C and C++", from: "Debian",
          what: qsTr("gcc, g++, make, cmake, gdb"),
          about: qsTr("The GNU compilers with make, cmake and the gdb debugger."),
          icon: "extras/cpp-icon.png", picture: "" },
        { id: "docker", name: "Docker", from: qsTr("Docker's repository"),
          what: qsTr("Containers, with Compose and Buildx"),
          about: qsTr("Docker Engine with Compose and Buildx. Your account can use it without sudo after the first login."),
          icon: "extras/docker-icon.png", picture: "" },
        { id: "podman", name: "Podman", from: "Debian",
          what: qsTr("Rootless containers, with podman-compose"),
          about: qsTr("Containers without a background service or root, with podman-compose."),
          icon: "extras/podman-icon.png", picture: "" }
    ]
}
