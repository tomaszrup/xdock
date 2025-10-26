import QtQuick
import org.kde.taskmanager 0.1 as TaskManager
import org.kde.plasma.plasma5support 2.0 as P5Support

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
        executable.exec(launchCommand)
    }
    
    // Simple launch function
    function launch(command) {
        executable.exec(command)
    }
}
