import QtQuick
import QtQuick.Controls
import org.kde.kirigami as Kirigami
import org.kde.taskmanager 0.1 as TaskManager

Rectangle {
    id: dockArea
    
    // Properties
    property real dockWidth: 300
    property real dockHeight: 60
    property var appModel
    property real iconSpacing: 1
    property bool showDebug: false
    property var tasksModel
    property real iconsOpacity: 1.0
    
    // Icon properties passed to delegates
    property real iconSize: 48
    property real maxScale: 1.4
    property bool anyIconBeingDragged: false
    
    // Signals
    signal dropReceived(string url)
    signal mousePositionChanged(real x)
    signal hoverChanged(bool hovered)
    signal removeIcon(int index)
    signal launchIcon(string appName, string command, string desktopFile, var iconGeometry)
    signal moveIcon(int from, int to)
    signal iconDraggedOutside(bool outside)
    signal iconHoverChanged(bool hovered, string tooltipText, var visualParent)
    
    width: dockWidth
    height: dockHeight
    color: Qt.rgba(0, 0, 0, 0.22)
    radius: 12
    border.color: Qt.rgba(1, 1, 1, 0.15)
    border.width: 1
    clip: false
    
    // Debug overlay (only shown when enabled)
    Loader {
        active: showDebug
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 10
        z: 1000
        
        sourceComponent: Rectangle {
            width: 350
            height: 400
            color: "black"
            opacity: 0.9
            
            Flickable {
                anchors.fill: parent
                anchors.margins: 5
                contentWidth: width
                contentHeight: debugText.height
                clip: true
                
                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AlwaysOn
                }
                
                Text {
                    id: debugText
                    width: parent.width - 15
                    color: "white"
                    font.pixelSize: 10
                    wrapMode: Text.Wrap
                    text: {
                        var debug = "AppModel: " + (appModel ? "exists" : "null") + "\n"
                        
                        if (appModel) {
                            debug += "Dock icons: " + appModel.count + "\n"
                            for (var j = 0; j < Math.min(appModel.count, 3); j++) {
                                var item = appModel.get(j)
                                debug += j + ": " + item.name + "\n"
                                debug += "   cmd: " + item.launchCommand + "\n"
                            }
                        }
                        
                        debug += "\n"
                        if (!tasksModel) return debug + "No tasks model"
                        
                        debug += "Tasks: " + tasksModel.count + "\n"
                        for (var i = 0; i < Math.min(tasksModel.count, 5); i++) {
                            var idx = tasksModel.index(i, 0)
                            var appId = tasksModel.data(idx, TaskManager.TasksModel.AppId)
                            var appName = tasksModel.data(idx, TaskManager.TasksModel.AppName)
                            debug += i + ": " + appName + "\n"
                            debug += "   AppId: " + appId + "\n"
                        }
                        
                        return debug
                    }
                }
            }
        }
    }

    HoverHandler {
        id: dockHoverHandler
        onPointChanged: {
            iconList.globalMouseX = point.position.x
            dockArea.mousePositionChanged(point.position.x)
        }
        onHoveredChanged: {
            if (hovered) {
                dockArea.hoverChanged(true)
            } else {
                iconList.globalMouseX = -1
                dockArea.hoverChanged(false)
            }
        }
    }

    ListView {
        id: iconList
        anchors.centerIn: parent
        width: contentWidth
        height: parent.height
        orientation: Qt.Horizontal
        spacing: dockArea.iconSpacing
        model: appModel
        clip: false

        property real globalMouseX: -1
        
        delegate: DockIcon {
            iconSize: dockArea.iconSize
            iconSpacing: dockArea.iconSpacing
            maxScale: dockArea.maxScale
            anyIconBeingDragged: dockArea.anyIconBeingDragged
            tasksModel: dockArea.tasksModel
            globalMouseX: iconList.globalMouseX
            opacity: dockArea.iconsOpacity
            
            Behavior on opacity {
                NumberAnimation {
                    duration: 250
                    easing.type: Easing.OutCubic
                }
            }
            
            onRemoveRequested: {
                dockArea.removeIcon(index)
            }
            
            onLaunchRequested: function(command, desktopFile, iconGeometry) {
                dockArea.launchIcon(model.name, command, desktopFile, iconGeometry)
            }
            
            onOrderChanged: function(from, to) {
                dockArea.moveIcon(from, to)
            }
            
            onDraggedOutside: function(outside) {
                dockArea.iconDraggedOutside(outside)
            }
            
            onHoverChanged: function(hovered, tooltipText, visualParent) {
                dockArea.iconHoverChanged(hovered, tooltipText, visualParent)
            }
            
            Component.onCompleted: {
                isBeingDraggedChanged.connect(function() {
                    dockArea.anyIconBeingDragged = isBeingDragged
                })
            }
        }
        
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
                var url = drop.urls[0].toString()
                url = url.replace(/^file:\/\//, "")
                if (url.endsWith(".desktop")) {
                    dockArea.dropReceived(url)
                }
            }
        }
    }

    // Use HoverHandler which doesn't block child HoverHandlers
    HoverHandler {
        id: dockHover
        
        onPointChanged: {
            iconList.globalMouseX = point.position.x
            dockArea.mousePositionChanged(point.position.x)
        }
        
        onHoveredChanged: {
            if (hovered) {
                dockArea.hoverChanged(true)
            } else {
                iconList.globalMouseX = -1
                dockArea.hoverChanged(false)
            }
        }
    }
}
