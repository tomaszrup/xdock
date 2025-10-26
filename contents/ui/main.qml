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
import org.kde.taskmanager 0.1 as TaskManager

PlasmoidItem {
    id: root
    toolTipMainText: ""
    toolTipSubText: ""
    Layout.topMargin: 100
    property real iconsWidth: 400
    property real iconSize: parent.height * 0.5
    property real iconSpacing: 1
    property real maxScale: 1.5
    property int iconsOutsideDock: 0
    property bool anyIconBeingDragged: false
    property real baseContainerWidth: {
        var count = appModel.count - iconsOutsideDock
        var baseWidth = count * iconSize
        var spacingWidth = Math.max(0, count - 1) * iconSpacing
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
                    
                    displaced: Transition {
                        NumberAnimation {
                            properties: "x,y"
                            duration: 250
                            easing.type: Easing.OutCubic
                        }
                    }
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

    Layout.preferredHeight: parent.height
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
    
    // TaskManager to track running applications
    TaskManager.TasksModel {
        id: tasksModel
        groupMode: TaskManager.TasksModel.GroupDisabled
    }
    
    function activateOrLaunch(modelAppName, launchCommand) {
        // Search for a matching window
        for (var i = 0; i < tasksModel.count; i++) {
            var appName = tasksModel.data(tasksModel.index(i, 0), TaskManager.TasksModel.AppId)

            if (appName.endsWith(modelAppName)) {
                tasksModel.requestActivate(tasksModel.index(i, 0))
                return
            }
        }
        
        // No matching window found, launch the application
        runApplication(launchCommand)
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
        property string wmClass: ""

        function readDesktopFile(path) {
            currentPath = path
            iconName = ""
            appName = ""
            wmClass = ""
            connectSource("kreadconfig5 --file " + path + " --group 'Desktop Entry' --key 'Icon'")
        }

        onNewData: {
            var output = data["stdout"].trim()
            if (sourceName.indexOf("--key 'Icon'") !== -1) {
                iconName = output
                connectSource("kreadconfig5 --file " + currentPath + " --group 'Desktop Entry' --key 'Name'")
            } else if (sourceName.indexOf("--key 'Name'") !== -1) {
                appName = output
                connectSource("kreadconfig5 --file " + currentPath + " --group 'Desktop Entry' --key 'StartupWMClass'")
            } else if (sourceName.indexOf("--key 'StartupWMClass'") !== -1) {
                wmClass = output
                connectSource("kreadconfig5 --file " + currentPath + " --group 'Desktop Entry' --key 'Exec'")
            } else if (sourceName.indexOf("--key 'Exec'") !== -1) {
                var command = output.split(" ")[0]
                appModel.append({
                    "iconName": iconName,
                    "name": appName,
                    "launchCommand": command,
                    "desktopFile": currentPath,
                    "wmClass": wmClass
                })
                root.savePinnedApps()
            }
            disconnectSource(sourceName)
        }
    }

    Component {
        id: appDelegate

        Item {
            id: wrapper
            antialiasing: true
            clip: false

            readonly property real maxScale: 1.4
            property bool isBeingDragged: false
            property bool isOutsideDock: false
            property int targetIndex: -1
            property int originalIndex: -1
            property real visualDisplacement: 0
            
            // Check if this app is running
            readonly property bool isRunning: {                
                for (var i = 0; i < tasksModel.count; i++) {
                    var taskName = tasksModel.data(tasksModel.index(i, 0), TaskManager.TasksModel.AppId)
                    
                    if (taskName.endsWith(model.name)) {
                        return true
                    }
                }
                return false
            }

            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: - root.iconSize / maxScale / 2

            readonly property real myCenter: ListView.view.mapToItem(ListView.view.parent, x + width/2, 0).x
            readonly property real distance: Math.abs(myCenter - ListView.view.globalMouseX)
            readonly property real influenceRadius: 80

            readonly property real calculatedScale: {
                if (root.anyIconBeingDragged || ListView.view.globalMouseX < 0 || distance > influenceRadius) {
                    return 1.0;
                }
                var proximity = 1.0 - (distance / influenceRadius);
                var baseScale = 1.0 + (maxScale - 1.0) * Math.sin(proximity * Math.PI / 2);
                
                // Apply pressed effect
                if (dragArea.pressed && !dragArea.wasDragged) {
                    return baseScale * 0.9;
                }
                
                return baseScale;
            }

            height: root.iconSize - 4
            width: isOutsideDock ? 0 : root.iconSize * calculatedScale

            z: scale > 1.0 ? 1 : 0
            
            transform: Translate {
                x: wrapper.visualDisplacement
                
                Behavior on x {
                    NumberAnimation {
                        duration: 250
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Behavior on width {
                NumberAnimation {
                    duration: 100
                    easing.type: Easing.OutQuad
                }
            }

            // Invisible placeholder when dragging
            Rectangle {
                id: placeholder
                anchors.fill: parent
                color: "transparent"
                visible: wrapper.isBeingDragged && !wrapper.isOutsideDock
                opacity: 0
                radius: 4
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
                drag.target: iconItem
                drag.threshold: 10
                z: 15
                clip: false
                
                property string tooltipText: model.name || (model.launchCommand.charAt(0).toUpperCase() + model.launchCommand.slice(1))
                property bool wasDragged: false
            
                onPressed: function(mouse) {
                    wasDragged = false
                    wrapper.isOutsideDock = false
                    wrapper.originalIndex = index
                    wrapper.targetIndex = -1
                }
                
                onPositionChanged: function(mouse) {
                    if (drag.active && !wasDragged) {
                        wasDragged = true
                        wrapper.isBeingDragged = true
                        root.anyIconBeingDragged = true
                        wrapper.originalIndex = index
                    }
                    
                    // Check if icon is outside the dock
                    if (wasDragged) {
                        var iconGlobalPos = iconItem.mapToItem(null, iconItem.width/2, iconItem.height/2)
                        var dockGlobalBounds = wrapper.ListView.view.parent.mapToItem(null, 0, 0)
                        var dockWidth = wrapper.ListView.view.parent.width
                        var dockHeight = wrapper.ListView.view.parent.height
                        var margin = 30
                        
                        var isOutside = (iconGlobalPos.y < dockGlobalBounds.y - margin || 
                                        iconGlobalPos.y > dockGlobalBounds.y + dockHeight + margin ||
                                        iconGlobalPos.x < dockGlobalBounds.x - margin ||
                                        iconGlobalPos.x > dockGlobalBounds.x + dockWidth + margin)
                        
                        console.log("Icon pos:", iconGlobalPos.y, "Dock bounds:", dockGlobalBounds.y, dockHeight, "Outside:", isOutside)
                        
                        // Update counter when icon crosses the boundary
                        if (isOutside && !wrapper.isOutsideDock) {
                            root.iconsOutsideDock++
                        } else if (!isOutside && wrapper.isOutsideDock) {
                            root.iconsOutsideDock--
                        }
                        
                        wrapper.isOutsideDock = isOutside
                        
                        // Handle reordering when inside the dock - only if this item is being dragged
                        if (!isOutside && wrapper.isBeingDragged) {
                            // Get icon position relative to ListView
                            var iconListPos = iconItem.mapToItem(wrapper.ListView.view, iconItem.width/2, iconItem.height/2)
                            
                            // Find which position the icon should be in
                            var currentIndex = wrapper.originalIndex
                            var targetIndex = 0
                            var minDistance = Number.MAX_VALUE
                            
                            // Find the closest slot by checking distances to all items
                            for (var i = 0; i < appModel.count; i++) {
                                var item = wrapper.ListView.view.itemAtIndex(i)
                                if (item) {
                                    var itemX = item.x + item.width / 2
                                    var distance = Math.abs(iconListPos.x - itemX)
                                    
                                    if (distance < minDistance) {
                                        minDistance = distance
                                        targetIndex = i
                                    }
                                }
                            }
                            
                            // Store target index and update visual displacements
                            wrapper.targetIndex = targetIndex
                            
                            // Update displacements for all items
                            for (var j = 0; j < appModel.count; j++) {
                                var otherItem = wrapper.ListView.view.itemAtIndex(j)
                                if (otherItem && j !== currentIndex) {
                                    // Calculate if this item should be displaced
                                    if (currentIndex < targetIndex && j > currentIndex && j <= targetIndex) {
                                        // Moving right, shift items left
                                        otherItem.visualDisplacement = -(root.iconSize + root.iconSpacing)
                                    } else if (currentIndex > targetIndex && j < currentIndex && j >= targetIndex) {
                                        // Moving left, shift items right
                                        otherItem.visualDisplacement = (root.iconSize + root.iconSpacing)
                                    } else {
                                        otherItem.visualDisplacement = 0
                                    }
                                }
                            }
                        } else {
                            // Reset all displacements when outside
                            for (var k = 0; k < appModel.count; k++) {
                                var itemToReset = wrapper.ListView.view.itemAtIndex(k)
                                if (itemToReset && k !== wrapper.originalIndex) {
                                    itemToReset.visualDisplacement = 0
                                }
                            }
                        }
                    }
                }
                
                onReleased: function(mouse) {
                    if (wasDragged) {
                        // Decrement counter if icon was outside
                        if (wrapper.isOutsideDock) {
                            root.iconsOutsideDock--
                        }
                        
                        // Check if icon was dragged outside the dock area
                        // Get the icon's global position
                        var iconGlobalPos = iconItem.mapToItem(null, iconItem.width/2, iconItem.height/2)
                        var dockGlobalBounds = wrapper.ListView.view.parent.mapToItem(null, 0, 0)
                        var dockWidth = wrapper.ListView.view.parent.width
                        var dockHeight = wrapper.ListView.view.parent.height
                        
                        console.log("Icon pos:", iconGlobalPos.x, iconGlobalPos.y)
                        console.log("Dock bounds:", dockGlobalBounds.x, dockGlobalBounds.y, dockWidth, dockHeight)
                        
                        // If dropped outside dock (with some margin), remove it
                        var margin = 30
                        if (iconGlobalPos.y < dockGlobalBounds.y - margin || 
                            iconGlobalPos.y > dockGlobalBounds.y + dockHeight + margin ||
                            iconGlobalPos.x < dockGlobalBounds.x - margin ||
                            iconGlobalPos.x > dockGlobalBounds.x + dockWidth + margin) {
                            console.log("Icon dropped outside, removing")
                            appModel.remove(index)
                            root.savePinnedApps()
                        } else {
                            console.log("Icon dropped inside, restoring")
                            
                            // Reset all displacements immediately before applying the move
                            for (var m = 0; m < appModel.count; m++) {
                                var itemToReset = wrapper.ListView.view.itemAtIndex(m)
                                if (itemToReset) {
                                    itemToReset.visualDisplacement = 0
                                }
                            }
                            wrapper.visualDisplacement = 0
                            
                            // Apply reordering if target index changed
                            if (wrapper.targetIndex >= 0 && wrapper.targetIndex !== wrapper.originalIndex) {
                                appModel.move(wrapper.originalIndex, wrapper.targetIndex, 1)
                            }
                            
                            // Dropped back in dock, restore it and save new order
                            wrapper.isBeingDragged = false
                            wrapper.isOutsideDock = false
                            root.savePinnedApps()
                        }
                        
                        root.anyIconBeingDragged = false
                        
                        // Reset icon position
                        iconItem.x = 0
                        iconItem.y = 0
                    } else if (mouse.button === Qt.LeftButton) {
                        if (model.launchCommand) {
                            activateOrLaunch(model.name, model.launchCommand)
                        }
                    } else if (mouse.button === Qt.RightButton) {
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
                anchors.centerIn: wrapper.isBeingDragged ? undefined : parent
                x: wrapper.isBeingDragged ? x : 0
                y: wrapper.isBeingDragged ? y : 0
                source: model.iconName
                smooth: true
                transformOrigin: Item.Bottom
                clip: false
                scale: calculatedScale * (root.iconSize / (root.iconSize * root.maxScale)) - 0.1
                z: wrapper.isBeingDragged ? 1000 : 0
            

                Behavior on scale {
                    NumberAnimation {
                        duration: 100
                        easing.type: Easing.OutQuad
                    }
                }
            }
            
            // Running indicator dot
            Rectangle {
                width: 6
                height: 6
                radius: 3
                color: Qt.rgba(0.7, 0.7, 0.7, 1)
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: -iconSize * 0.39
                visible: wrapper.isRunning
                opacity: 0.9
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