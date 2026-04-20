import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import SddmComponents 2.0

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "#020604"

    // ─── Matrix rain canvas ───────────────────────────────────────
    Canvas {
        id: matrix
        anchors.fill: parent
        opacity: 0.55
        property var columns: []
        property int fontSize: 16

        onPaint: {
            var ctx = getContext("2d")
            ctx.fillStyle = "rgba(2, 6, 4, 0.08)"
            ctx.fillRect(0, 0, width, height)
            ctx.fillStyle = "#00ff88"
            ctx.font = fontSize + "px monospace"
            var chars = "01アイウエオカキクケコサシスセソタチツテトナニヌネノ"
            var colCount = Math.floor(width / fontSize)
            if (columns.length !== colCount) {
                columns = new Array(colCount).fill(0)
            }
            for (var i = 0; i < colCount; i++) {
                var ch = chars.charAt(Math.floor(Math.random() * chars.length))
                ctx.fillText(ch, i * fontSize, columns[i] * fontSize)
                if (columns[i] * fontSize > height && Math.random() > 0.975)
                    columns[i] = 0
                columns[i]++
            }
        }

        Timer {
            interval: 60
            running: true
            repeat: true
            onTriggered: matrix.requestPaint()
        }
    }

    // ─── Dark vignette ───────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#00000000" }
            GradientStop { position: 1.0; color: "#cc000000" }
        }
    }

    // ─── Login card ──────────────────────────────────────────────
    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 420
        height: 340
        color: "#0a1810"
        radius: 8
        border.color: "#00ff88"
        border.width: 1
        opacity: 0.95

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 30
            spacing: 20

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "BalOS"
                color: "#00ff88"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 36
                font.bold: true
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "[ hack · play · evade · endure ]"
                color: "#b580ff"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
            }

            ComboBox {
                id: userBox
                Layout.fillWidth: true
                model: userModel
                textRole: "name"
                currentIndex: userModel.lastIndex
                background: Rectangle { color: "#020604"; border.color: "#00ff88"; radius: 4 }
                contentItem: Text {
                    text: userBox.displayText
                    color: "#b8ffce"
                    font.family: "JetBrainsMono Nerd Font"
                    leftPadding: 10
                    verticalAlignment: Text.AlignVCenter
                }
            }

            TextField {
                id: pwBox
                Layout.fillWidth: true
                echoMode: TextInput.Password
                placeholderText: "▶ password"
                color: "#b8ffce"
                placeholderTextColor: "#3a7040"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 14
                background: Rectangle { color: "#020604"; border.color: "#00ff88"; radius: 4 }
                Keys.onReturnPressed: sddm.login(userBox.currentText, pwBox.text, sessionBox.currentIndex)
            }

            ComboBox {
                id: sessionBox
                Layout.fillWidth: true
                model: sessionModel
                textRole: "name"
                currentIndex: sessionModel.lastIndex
                background: Rectangle { color: "#020604"; border.color: "#3a7040"; radius: 4 }
                contentItem: Text {
                    text: sessionBox.displayText
                    color: "#55ffaa"
                    font.family: "JetBrainsMono Nerd Font"
                    leftPadding: 10
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Button {
                Layout.fillWidth: true
                text: "► AUTHENTICATE"
                font.family: "JetBrainsMono Nerd Font"
                font.bold: true
                onClicked: sddm.login(userBox.currentText, pwBox.text, sessionBox.currentIndex)
                background: Rectangle {
                    color: parent.hovered ? "#00ff88" : "#0f2015"
                    border.color: "#00ff88"
                    radius: 4
                }
                contentItem: Text {
                    text: parent.text
                    color: parent.hovered ? "#020604" : "#00ff88"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }

    // ─── Bottom status bar ───────────────────────────────────────
    Row {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 20
        spacing: 30

        Text {
            text: Qt.formatDateTime(new Date(), "ddd · MMM d yyyy · hh:mm:ss")
            color: "#3a7040"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 11

            Timer {
                interval: 1000; running: true; repeat: true
                onTriggered: parent.text = Qt.formatDateTime(new Date(), "ddd · MMM d yyyy · hh:mm:ss")
            }
        }

        Text {
            text: "F1 session · F2 reboot · F3 shutdown"
            color: "#3a7040"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 11
        }
    }

    // Keyboard shortcuts
    Shortcut { sequence: "F2"; onActivated: sddm.reboot() }
    Shortcut { sequence: "F3"; onActivated: sddm.powerOff() }

    Connections {
        target: sddm
        function onLoginFailed() { pwBox.text = ""; pwBox.focus = true }
    }
}
