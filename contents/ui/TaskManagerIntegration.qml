import QtQuick
import org.kde.taskmanager as TaskManager
import org.kde.plasma.plasma5support as P5Support

Item {
    id: root
    
    // The TaskManager model
    property alias tasksModel: tasksModel
    
    TaskManager.TasksModel {
        id: tasksModel
        groupMode: TaskManager.TasksModel.GroupDisabled
    }
    
    // DataSource for executing applications
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
    
    // Activate an existing window or launch a new application
    function activateOrLaunch(modelAppName, launchCommand, iconGeometry) {
        // Search for a matching window
        for (var i = 0; i < tasksModel.count; i++) {
            var idx = tasksModel.index(i, 0)
            var appName = tasksModel.data(idx, TaskManager.TasksModel.AppId)

            if (appName.endsWith(modelAppName)) {
                // Set the icon geometry hint for the magic lamp effect
                if (iconGeometry) {
                    tasksModel.requestPublishDelegateGeometry(
                        idx,
                        iconGeometry,
                        null
                    )
                }
                
                // Check window state
                var isActive = tasksModel.data(idx, 272)
                var isMinimized = tasksModel.data(idx, 279)
                
                if (isActive) {
                    tasksModel.requestToggleMinimized(idx)
                } else if (isMinimized) {
                    tasksModel.requestActivate(idx)
                } else {
                    tasksModel.requestActivate(idx)
                }
                return
            }
        }
        
        // No matching window found, launch the application
        // Note: For newly launched apps, the magic lamp effect won't work
        // as we can't set geometry hints before the window exists
        executable.exec(launchCommand)
    }
    
    // Simple launch function
    function launch(command) {
        executable.exec(command)
    }
}
