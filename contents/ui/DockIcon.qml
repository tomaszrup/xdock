import QtQuick
import QtQuick.Controls
import org.kde.kirigami as Kirigami
import org.kde.taskmanager 0.1 as TaskManager

Item {
    id: wrapper
    antialiasing: true
    clip: false

    // Required properties passed from parent
    required property var model
    required property int index
    required property var tasksModel
    
    // Signals
    signal removeRequested()
    signal launchRequested(string command, string desktopFile)
    signal orderChanged(int from, int to)
    signal draggedOutside(bool outside)
    signal visualDisplacementRequested()
    signal hoverChanged(bool hovered, string tooltipText, var visualParent)
    
    // Drag state properties
    property bool isBeingDragged: false
    property bool isOutsideDock: false
    property int targetIndex: -1
    property int originalIndex: -1
    property real visualDisplacement: 0
    
    // Visual properties - passed from root
    property real iconSize: 48
    property real iconSpacing: 1
    property real maxScale: 1.4
    property bool anyIconBeingDragged: false
    property real globalMouseX: -1
    
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

    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    anchors.verticalCenterOffset: -iconSize / maxScale / 2

    // Use fixed icon size for center calculation to avoid feedback loop
    readonly property real myCenter: ListView.view ? ListView.view.mapToItem(ListView.view.parent, x + iconSize/2, 0).x : 0
    readonly property real distance: Math.abs(myCenter - globalMouseX)
    readonly property real influenceRadius: 80

    readonly property real calculatedScale: {
        if (anyIconBeingDragged || globalMouseX < 0 || distance > influenceRadius) {
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

    height: iconSize - 4
    width: isOutsideDock ? 0 : iconSize * calculatedScale
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
                wrapper.orderChanged(from, to)
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
                
                // Update outside state
                if (isOutside !== wrapper.isOutsideDock) {
                    wrapper.isOutsideDock = isOutside
                    wrapper.draggedOutside(isOutside)
                }
                
                // Handle reordering when inside the dock
                if (!isOutside && wrapper.isBeingDragged) {
                    // Get icon position relative to ListView
                    var iconListPos = iconItem.mapToItem(wrapper.ListView.view, iconItem.width/2, iconItem.height/2)
                    
                    // Find which position the icon should be in
                    var currentIndex = wrapper.originalIndex
                    var targetIdx = 0
                    var minDistance = Number.MAX_VALUE
                    
                    // Find the closest slot by checking distances to all items
                    for (var i = 0; i < wrapper.ListView.view.count; i++) {
                        var item = wrapper.ListView.view.itemAtIndex(i)
                        if (item) {
                            var itemX = item.x + item.width / 2
                            var distance = Math.abs(iconListPos.x - itemX)
                            
                            if (distance < minDistance) {
                                minDistance = distance
                                targetIdx = i
                            }
                        }
                    }
                    
                    // Store target index and update visual displacements
                    wrapper.targetIndex = targetIdx
                    
                    // Update displacements for all items
                    for (var j = 0; j < wrapper.ListView.view.count; j++) {
                        var otherItem = wrapper.ListView.view.itemAtIndex(j)
                        if (otherItem && j !== currentIndex) {
                            // Calculate if this item should be displaced
                            if (currentIndex < targetIdx && j > currentIndex && j <= targetIdx) {
                                // Moving right, shift items left
                                otherItem.visualDisplacement = -(iconSize + iconSpacing)
                            } else if (currentIndex > targetIdx && j < currentIndex && j >= targetIdx) {
                                // Moving left, shift items right
                                otherItem.visualDisplacement = (iconSize + iconSpacing)
                            } else {
                                otherItem.visualDisplacement = 0
                            }
                        }
                    }
                } else {
                    // Reset all displacements when outside
                    for (var k = 0; k < wrapper.ListView.view.count; k++) {
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
                // Check if icon was dragged outside the dock area
                var iconGlobalPos = iconItem.mapToItem(null, iconItem.width/2, iconItem.height/2)
                var dockGlobalBounds = wrapper.ListView.view.parent.mapToItem(null, 0, 0)
                var dockWidth = wrapper.ListView.view.parent.width
                var dockHeight = wrapper.ListView.view.parent.height
                
                // If dropped outside dock (with some margin), remove it
                var margin = 30
                if (iconGlobalPos.y < dockGlobalBounds.y - margin || 
                    iconGlobalPos.y > dockGlobalBounds.y + dockHeight + margin ||
                    iconGlobalPos.x < dockGlobalBounds.x - margin ||
                    iconGlobalPos.x > dockGlobalBounds.x + dockWidth + margin) {
                    wrapper.removeRequested()
                } else {
                    // Icon dropped inside - ensure counter is decremented if it was outside
                    if (wrapper.isOutsideDock) {
                        wrapper.draggedOutside(false)
                    }
                    
                    // Reset all displacements immediately before applying the move
                    for (var m = 0; m < wrapper.ListView.view.count; m++) {
                        var itemToReset = wrapper.ListView.view.itemAtIndex(m)
                        if (itemToReset) {
                            itemToReset.visualDisplacement = 0
                        }
                    }
                    wrapper.visualDisplacement = 0
                    
                    // Apply reordering if target index changed
                    if (wrapper.targetIndex >= 0 && wrapper.targetIndex !== wrapper.originalIndex) {
                        wrapper.orderChanged(wrapper.originalIndex, wrapper.targetIndex)
                    }
                }
                
                // Reset drag state
                wrapper.isBeingDragged = false
                wrapper.isOutsideDock = false
                
                // Reset icon position
                iconItem.x = 0
                iconItem.y = 0
            } else if (mouse.button === Qt.LeftButton) {
                if (model.launchCommand) {
                    wrapper.launchRequested(model.launchCommand, model.desktopFile)
                }
            } else if (mouse.button === Qt.RightButton) {
                contextMenu.popup(wrapper, mouse.x + 5, 5)
            }
        }
        
        onContainsMouseChanged: {
            if (containsMouse && !wrapper.isBeingDragged) {
                wrapper.hoverChanged(true, tooltipText, wrapper)
            } else {
                wrapper.hoverChanged(false, "", null)
            }
        }
    }
    
    // Separate hover handler for tooltip (doesn't interfere with drag)
    // Use an Item positioned to match the icon's actual position
    Item {
        anchors.fill: parent
        anchors.topMargin: iconSize / maxScale / 2  // Offset to match icon position
        
        HoverHandler {
            id: iconHoverHandler
            enabled: !wrapper.isBeingDragged
            
            onHoveredChanged: {
                if (hovered) {
                    wrapper.hoverChanged(true, dragArea.tooltipText, wrapper)
                } else {
                    wrapper.hoverChanged(false, "", null)
                }
            }
        }
    }

    Kirigami.Icon {
        id: iconItem
        width: iconSize * maxScale
        height: iconSize * maxScale
        anchors.centerIn: wrapper.isBeingDragged ? undefined : parent
        x: wrapper.isBeingDragged ? x : 0
        y: wrapper.isBeingDragged ? y : 0
        source: model.iconName
        smooth: true
        transformOrigin: Item.Bottom
        clip: false
        scale: calculatedScale * (iconSize / (iconSize * maxScale)) - 0.1
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
        anchors.bottomMargin: -iconSize * 0.36
        visible: wrapper.isRunning
        opacity: 0.9
    }
    
    // Context menu (simplified - to be connected by parent)
    Menu {
        id: contextMenu
        
        MenuItem {
            text: "Remove " + (model.name || model.launchCommand)
            onTriggered: wrapper.removeRequested()
        }
    }
}
