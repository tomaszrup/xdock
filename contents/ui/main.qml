import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root
    
    // Disable default tooltip
    toolTipMainText: ""
    toolTipSubText: ""
    toolTipTextFormat: Text.PlainText
    
    // Configuration properties
    property real iconSize: parent.height * 0.5
    property real iconSpacing: 1
    property real maxScale: 1.5
    property int iconsOutsideDock: 0
    property bool anyIconBeingDragged: false
    
    // Expose these for Components
    property alias appModel: appModel
    property alias taskManager: taskManager
    property alias desktopFileReader: desktopFileReader
    
    // Computed dock dimensions
    property real baseContainerWidth: {
        var count = appModel.count - iconsOutsideDock
        var baseWidth = count * iconSize
        var spacingWidth = Math.max(0, count - 1) * iconSpacing
        var padding = 20
        return Math.max(60, baseWidth + spacingWidth + padding)
    }
    
    property real animatedDockWidth: isHovered ? baseContainerWidth + 40 : baseContainerWidth
    property real animatedDockHeight: isHovered ? iconSize + 8 : iconSize + 10
    property bool isHovered: false
    
    // Tooltip properties
    property string currentTooltipText: ""
    property var tooltipVisualParent: null
    property bool showTooltip: false
    
    // Tooltip show/hide timers to prevent rapid changes
    Timer {
        id: tooltipShowTimer
        interval: 500
        onTriggered: {
            if (root.showTooltip && root.tooltipVisualParent) {
                tooltipWindow.visible = true
            }
        }
    }
    
    Timer {
        id: tooltipHideTimer
        interval: 100
        onTriggered: {
            tooltipWindow.visible = false
        }
    }
    
    Layout.minimumWidth: 60
    Layout.minimumHeight: 48
    Layout.preferredHeight: parent.height
    Layout.preferredWidth: iconSize * appModel.count + iconSpacing * Math.max(0, appModel.count - 1) + 80
    
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
    
    // Task Manager Integration
    TaskManagerIntegration {
        id: taskManager
    }
    
    // Desktop File Reader
    DesktopFileReader {
        id: desktopFileReader
        
        onAppInfoReady: function(iconName, appName, launchCommand, desktopFile, wmClass) {
            appModel.append({
                "iconName": iconName,
                "name": appName,
                "launchCommand": launchCommand,
                "desktopFile": desktopFile,
                "wmClass": wmClass
            })
            savePinnedApps()
        }
    }
    
    // App Model
    ListModel {
        id: appModel
        Component.onCompleted: {
            loadPinnedApps()
        }
    }
    
    // Persistence functions
    function savePinnedApps() {
        var apps = []
        for (var i = 0; i < appModel.count; i++) {
            var item = appModel.get(i)
            apps.push({
                iconName: item.iconName,
                name: item.name,
                launchCommand: item.launchCommand,
                desktopFile: item.desktopFile,
                wmClass: item.wmClass
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
        }
    }
    
    // Compact representation (panel mode)
    compactRepresentation: Component {
        Item {
            anchors.fill: parent
            clip: false
            
            DockContainer {
                id: compactDock
                anchors.centerIn: parent
                dockWidth: root.animatedDockWidth
                dockHeight: root.animatedDockHeight
                appModel: root.appModel
                iconSpacing: root.iconSpacing
                iconSize: root.iconSize
                maxScale: root.maxScale
                showDebug: false // Set to true to enable debug overlay
                tasksModel: root.taskManager.tasksModel
                
                onDropReceived: function(url) {
                    root.desktopFileReader.readDesktopFile(url)
                }
                
                onHoverChanged: function(hovered) {
                    root.isHovered = hovered
                    // Don't hide tooltip here - let icon hover handle it
                }
                
                onRemoveIcon: function(idx) {
                    root.appModel.remove(idx)
                    root.savePinnedApps()
                }
                
                onLaunchIcon: function(appName, command, desktopFile) {
                    root.taskManager.activateOrLaunch(appName, command)
                }
                
                onMoveIcon: function(from, to) {
                    root.appModel.move(from, to, 1)
                    root.savePinnedApps()
                }
                
                onIconDraggedOutside: function(outside) {
                    if (outside) {
                        root.iconsOutsideDock++
                    } else {
                        root.iconsOutsideDock--
                    }
                }
                
                onIconHoverChanged: function(hovered, tooltipText, visualParent) {
                    tooltipShowTimer.stop()
                    tooltipHideTimer.stop()
                    
                    if (hovered) {
                        root.currentTooltipText = tooltipText
                        root.tooltipVisualParent = visualParent
                        root.showTooltip = true
                        tooltipShowTimer.start()
                    } else {
                        root.showTooltip = false
                        tooltipHideTimer.start()
                    }
                }
                
                Binding {
                    target: compactDock
                    property: "anyIconBeingDragged"
                    value: root.anyIconBeingDragged
                }
            }
        }
    }

    // Full representation (when clicked/expanded)
    fullRepresentation: Component {
        Item {
            anchors.fill: parent
            
            DockContainer {
                id: fullDock
                anchors.centerIn: parent
                dockWidth: root.animatedDockWidth
                dockHeight: root.animatedDockHeight
                appModel: root.appModel
                iconSpacing: root.iconSpacing
                iconSize: root.iconSize
                maxScale: root.maxScale
                showDebug: false // Set to true to enable debug overlay
                tasksModel: root.taskManager.tasksModel
                color: Qt.rgba(0, 0, 0, 0.4)
                
                onDropReceived: function(url) {
                    root.desktopFileReader.readDesktopFile(url)
                }
                
                onHoverChanged: function(hovered) {
                    root.isHovered = hovered
                }
                
                onRemoveIcon: function(idx) {
                    root.appModel.remove(idx)
                    root.savePinnedApps()
                }
                
                onLaunchIcon: function(appName, command, desktopFile) {
                    root.taskManager.activateOrLaunch(appName, command)
                }
                
                onMoveIcon: function(from, to) {
                    root.appModel.move(from, to, 1)
                    root.savePinnedApps()
                }
                
                onIconDraggedOutside: function(outside) {
                    if (outside) {
                        root.iconsOutsideDock++
                    } else {
                        root.iconsOutsideDock--
                    }
                }
                
                onIconHoverChanged: function(hovered, tooltipText, visualParent) {
                    tooltipShowTimer.stop()
                    tooltipHideTimer.stop()
                    
                    if (hovered) {
                        root.currentTooltipText = tooltipText
                        root.tooltipVisualParent = visualParent
                        root.showTooltip = true
                        tooltipShowTimer.start()
                    } else {
                        root.showTooltip = false
                        tooltipHideTimer.start()
                    }
                }
                
                Binding {
                    target: fullDock
                    property: "anyIconBeingDragged"
                    value: root.anyIconBeingDragged
                }
            }
        }
    }
    
    // Global tooltip window
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
}
