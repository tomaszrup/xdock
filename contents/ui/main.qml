import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.coreaddons as KCoreAddons
import org.kde.plasma.plasma5support 2.0 as P5Support

PlasmoidItem {
    id: root
    toolTipMainText: ""
    toolTipSubText: ""
    Layout.topMargin: 100
    property real iconsWidth: 400
    property real iconSize: parent.height * 0.5
    property real iconSpacing: 1
    property real maxScale: 1.5
    property real baseContainerWidth: {
        var count = appModel.count
        var baseWidth = count * iconSize
        var spacingWidth = (count - 1) * iconSpacing
        var padding = 20
        if(baseWidth < 60) {
            baseWidth = 60
        }
        return baseWidth + spacingWidth + padding
    }
    property real animatedDockWidth: isHovered ? baseContainerWidth + 40 : baseContainerWidth
    property real animatedDockHeight: isHovered ? iconSize + 8: iconSize + 10
    property bool isHovered: false
    property var activeContextMenu: null
    
    // Tooltip overlay properties
    property string currentTooltipText: ""
    property var tooltipVisualParent: null
    property bool showTooltip: false
    
    Behavior on animatedDockWidth {
        NumberAnimation {
            duration: 250
            easing.type: Easing.OutCubic
        }
    }
    
    Behavior on animatedDockHeight {
        NumberAnimation {
            duration: 250
            easing.type: Easing.OutCubic
        }
    }

    compactRepresentation: Component {
        Item {
            anchors.fill: parent
            clip: false

            Rectangle {
                id: dockArea
                width: root.animatedDockWidth
                height: animatedDockHeight
                anchors.centerIn: parent
                color: Qt.rgba(0, 0, 0, 0.22)
                radius: 12
                border.color: Qt.rgba(1, 1, 1, 0.15)
                border.width: 1
                clip: false

                HoverHandler {
                    id: dockHoverHandler
                    onPointChanged: {
                        iconList.globalMouseX = point.position.x
                    }
                    onHoveredChanged: {
                        if (hovered) {
                            root.isHovered = true
                            tooltipWindow.visible = true
                            menuCloseTimer.stop()
                        } else {
                            iconList.globalMouseX = -1
                            root.isHovered = false
                            tooltipWindow.visible = false
                        }
                    }
                }

                ListView {
                    id: iconList
                    anchors.centerIn: parent
                    width: contentWidth
                    height: parent.height
                    orientation: Qt.Horizontal
                    spacing: root.iconSpacing
                    model: appModel
                    delegate: appDelegate
                    clip: false

                    property real globalMouseX: -1
                }

                DropArea {
                    anchors.fill: parent
                    onDropped: {
                        if (drop.hasUrls) {
                            var url = drop.urls[0].toString();
                            url = url.replace(/^file:\/\//,"");
                            if (url.endsWith(".desktop")) {
                                desktopFileReader.readDesktopFile(url);
                            }
                        }
                    }
                }
            }
        }
    }

    fullRepresentation: Component {
        Item {
            anchors.fill: parent

            Rectangle {
                id: dockArea
                width: root.animatedDockWidth
                height: animatedDockHeight
                anchors.centerIn: parent
                color: Qt.rgba(0, 0, 0, 0.4)
                radius: 12
                border.color: Qt.rgba(1, 1, 1, 0.15)
                border.width: 1
                z: 1

                ListView {
                    id: iconList
                    anchors.centerIn: parent
                    width: contentWidth
                    height: parent.height
                    orientation: Qt.Horizontal
                    spacing: root.iconSpacing
                    model: appModel
                    delegate: appDelegate
                    clip: false
                    z: 2
                    property real globalMouseX: -1
                }

                DropArea {
                    anchors.fill: parent
                    onDropped: {
                        if (drop.hasUrls) {
                            var url = drop.urls[0].toString();
                            url = url.replace(/^file:\/\//,"");
                            if (url.endsWith(".desktop")) {
                                desktopFileReader.readDesktopFile(url);
                            }
                        }
                    }
                }

                MouseArea {
                    clip: false
                    id: listMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    propagateComposedEvents: true
                    acceptedButtons: Qt.NoButton
                    onPositionChanged: function(mouse) {
                        iconList.globalMouseX = mouse.x
                        mouse.accepted = false
                    }
                    onEntered: {
                        root.plasmoid.toolTip = ""
                        root.isReallyHovered = true
                        root.isHovered = true
                    }

                    onExited: {
                        iconList.globalMouseX = -1
                        root.isReallyHovered = false
                    }
                }
            }
        }
    }

    Layout.minimumWidth: 60
    Layout.minimumHeight: 48

    Layout.fillWidth: true
    Layout.preferredWidth: -1
    Layout.maximumWidth: -1

    property var pinnedApps: []

    function savePinnedApps() {
        var apps = []
        for (var i = 0; i < appModel.count; i++) {
            var item = appModel.get(i)
            apps.push({
                iconName: item.iconName,
                name: item.name,
                launchCommand: item.launchCommand
            })
        }
        Plasmoid.configuration.pinnedApps = JSON.stringify(apps)
    }

    function loadPinnedApps() {
        try {
            var apps = JSON.parse(Plasmoid.configuration.pinnedApps)
            appModel.clear()
            for (var i = 0; i < apps.length; i++) {
                appModel.append(apps[i])
            }
        } catch (e) {
            console.log("Failed to load pinned apps, using defaults")
            appModel.clear()
            appModel.append({"iconName": "applications-system", "name": "System Settings", "launchCommand": "systemsettings"})
            appModel.append({"iconName": "system-file-manager", "name": "Dolphin", "launchCommand": "dolphin"})
            appModel.append({"iconName": "org.kde.konsole", "name": "Konsole", "launchCommand": "konsole"})
        }
    }

    KCoreAddons.KUser {
        id: kuser
    }

    function runApplication(command) {
        executable.exec(command);
    }

    P5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []

        function exec(cmd) {
            connectSource(cmd)
        }

        onNewData: {
            disconnectSource(sourceName)
        }
    }

    P5Support.DataSource {
        id: desktopFileReader
        engine: "executable"
        connectedSources: []
        property string currentPath: ""
        property string iconName: ""
        property string appName: ""

        function readDesktopFile(path) {
            currentPath = path
            connectSource("kreadconfig5 --file " + path + " --group 'Desktop Entry' --key 'Icon'")
        }

        onNewData: {
            var output = data["stdout"].trim()
            if (sourceName.indexOf("--key 'Icon'") !== -1) {
                iconName = output
                connectSource("kreadconfig5 --file " + currentPath + " --group 'Desktop Entry' --key 'Name'")
            } else if (sourceName.indexOf("--key 'Name'") !== -1) {
                appName = output
                connectSource("kreadconfig5 --file " + currentPath + " --group 'Desktop Entry' --key 'Exec'")
            } else if (sourceName.indexOf("--key 'Exec'") !== -1) {
                var command = output.split(" ")[0]
                appModel.append({
                    "iconName": iconName,
                    "name": appName,
                    "launchCommand": command
                })
                root.savePinnedApps()
            }
            disconnectSource(sourceName)
        }
    }

    function addApplicationFromDesktopFile(path) {
        const process = Qt.createQmlObject(`
            import QtCore
            Process {
                property var iconName: ""
                property var execCommand: ""

                function readDesktopFile() {
                    start("kreadconfig5", ["--file", "${path}", "--group", "Desktop Entry", "--key", "Icon"]);
                    start("kreadconfig5", ["--file", "${path}", "--group", "Desktop Entry", "--key", "Exec"]);
                }

                onReadyRead: {
                    const output = readAll().toString().trim();
                    if (execCommand === "") {
                        execCommand = output;
                        if (iconName) {
                            appModel.append({
                                "iconName": iconName,
                                "launchCommand": execCommand.split(" ")[0]
                            });
                        }
                    } else {
                        iconName = output;
                        if (execCommand) {
                            appModel.append({
                                "iconName": iconName,
                                "launchCommand": execCommand.split(" ")[0]
                            });
                        }
                    }
                }
            }
        `, root);

        process.readDesktopFile();
    }

    Component {
        id: appDelegate

        Item {
            id: wrapper
            antialiasing: true
            clip: false

            readonly property real maxScale: 1.4

            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: - root.iconSize / maxScale / 2

            readonly property real myCenter: ListView.view.mapToItem(ListView.view.parent, x + width/2, 0).x
            readonly property real distance: Math.abs(myCenter - ListView.view.globalMouseX)
            readonly property real influenceRadius: 80

            readonly property real calculatedScale: {
                if (ListView.view.globalMouseX < 0 || distance > influenceRadius) {
                    return 1.0;
                }
                var proximity = 1.0 - (distance / influenceRadius);
                return 1.0 + (maxScale - 1.0) * Math.sin(proximity * Math.PI / 2);
            }

            height: root.iconSize - 4
            width: root.iconSize * calculatedScale

            z: scale > 1.0 ? 1 : 0

            Behavior on width {
                NumberAnimation {
                    duration: 100
                    easing.type: Easing.OutQuad
                }
            }

            // Drag and drop for reordering
            Drag.active: dragArea.drag.active
            Drag.source: wrapper
            Drag.hotSpot.x: width / 2
            Drag.hotSpot.y: height / 2

            states: State {
                when: dragArea.drag.active
                ParentChange { target: wrapper; parent: root }
                AnchorChanges {
                    target: wrapper
                    anchors.verticalCenter: undefined
                }
            }

            DropArea {
                anchors.fill: parent
                onEntered: {
                    if (drag.source !== wrapper) {
                        var from = drag.source.DelegateModel.itemsIndex
                        var to = wrapper.DelegateModel.itemsIndex
                        appModel.move(from, to, 1)
                        root.savePinnedApps()
                    }
                }
            }

            MouseArea {
                id: dragArea
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: -iconSize * 0.25
                height: parent.height * calculatedScale
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                propagateComposedEvents: false
                z: 15
                clip: false
                
                property string tooltipText: model.name || (model.launchCommand.charAt(0).toUpperCase() + model.launchCommand.slice(1))
            
                onClicked: function(mouse) {
                    console.log("MouseArea clicked! Button:", mouse.button)
                    if (mouse.button === Qt.LeftButton) {
                        if (model.launchCommand) {
                            runApplication(model.launchCommand)
                        }
                    } else if (mouse.button === Qt.RightButton) {
                        console.log("Right click detected, showing menu")
                        contextMenu.popup(wrapper, mouse.x + 5, 5)
                    }
                }
                
                onContainsMouseChanged: {
                    if (containsMouse) {
                        root.tooltipVisualParent = wrapper
                        root.currentTooltipText = tooltipText
                        // Close any open context menu when hovering over a different icon
                        if (root.activeContextMenu && root.activeContextMenu !== contextMenu) {
                            root.activeContextMenu.close()
                            root.activeContextMenu = null
                        }
                    }
                }
            }

            Kirigami.Icon {
                id: iconItem
                width: root.iconSize * root.maxScale
                height: root.iconSize * root.maxScale
                anchors.centerIn: parent
                source: model.iconName
                smooth: true
                transformOrigin: Item.Bottom
                clip: false
                scale: calculatedScale * (root.iconSize / (root.iconSize * root.maxScale)) - 0.1
            

                Behavior on scale {
                    NumberAnimation {
                        duration: 100
                        easing.type: Easing.OutQuad
                    }
                }
            }
        }
    }
    
    // Global tooltip overlay - renders outside panel bounds
    PlasmaCore.PopupPlasmaWindow {
        id: tooltipWindow
        visible: false
        popupDirection: Qt.TopEdge
        floating: true
        animated: false
        margin: 6
        visualParent: root.tooltipVisualParent
        width: tooltipRect.width
        height: tooltipRect.height
        flags: Qt.ToolTip | Qt.WindowDoesNotAcceptFocus | Qt.WindowStaysOnTopHint

        // The content rectangle shown in the popup
        Rectangle {
            id: tooltipRect
            width: globalTooltipLabel.width + 16
            height: globalTooltipLabel.height + 12
            color: Kirigami.Theme.backgroundColor
            border.color: Kirigami.Theme.textColor
            border.width: 1
            radius: 4

            PlasmaComponents.Label {
                id: globalTooltipLabel
                anchors.centerIn: parent
                text: root.currentTooltipText
                color: Kirigami.Theme.textColor
            }
        }
    }

    ListModel {
        id: appModel
        Component.onCompleted: {
            root.loadPinnedApps()
        }

    }
}