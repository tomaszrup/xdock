import QtQuick
import org.kde.plasma.plasma5support 2.0 as P5Support

QtObject {
    id: root
    
    // Signal emitted when a desktop file is successfully read
    signal appInfoReady(string iconName, string appName, string launchCommand, string desktopFile, string wmClass)
    
    // The DataSource for executing kreadconfig5
    property var dataSource: P5Support.DataSource {
        engine: "executable"
        connectedSources: []
        
        property string currentPath: ""
        property string iconName: ""
        property string appName: ""
        property string wmClass: ""

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
                root.appInfoReady(iconName, appName, command, currentPath, wmClass)
                // Reset state
                iconName = ""
                appName = ""
                wmClass = ""
                currentPath = ""
            }
            disconnectSource(sourceName)
        }
    }
    
    // Public function to read a desktop file
    function readDesktopFile(path) {
        dataSource.currentPath = path
        dataSource.iconName = ""
        dataSource.appName = ""
        dataSource.wmClass = ""
        dataSource.connectSource("kreadconfig5 --file " + path + " --group 'Desktop Entry' --key 'Icon'")
    }
}
