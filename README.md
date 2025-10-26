# Custom Dock for KDE Plasma 6

A sleek, customizable dock plasmoid for KDE Plasma 6 with macOS-like icon magnification effects, drag-and-drop icon management, and intelligent window tracking.

![Custom Dock](screenshot.png)

## Features

### Core Functionality
- **Icon Magnification**: Smooth scaling animation when hovering over icons with configurable influence radius
- **Drag & Drop**: Add applications by dragging `.desktop` files from your application menu or file manager
- **Icon Reordering**: Drag icons left or right to rearrange them in the dock
- **Remove Icons**: Drag icons out of the dock to remove them
- **Persistent Configuration**: Your pinned applications are saved and restored across sessions

### Window Management
- **Running Indicators**: Gray dots appear below icons of running applications
- **Smart Launch**: Click an icon to launch the app, or focus its window if already running
- **Window Activation**: Automatically detects and focuses existing windows instead of launching duplicates

### Visual Design
- **Smooth Animations**: Buttery-smooth scaling, displacement, and transition effects
- **Adaptive Sizing**: Dock automatically adjusts width based on number of icons
- **Tooltips**: Application names appear on hover with proper positioning
- **Context Menu**: Right-click icons to remove them

## Installation

### From Source

1. Clone or download this repository
2. Copy to your local plasmoids directory:
```bash
cp -r org.kde.plasma.customdock ~/.local/share/plasma/plasmoids/
```

3. Restart Plasma Shell:
```bash
kquitapp6 plasmashell && plasmashell --replace &
```

4. Add the widget:
   - Right-click on your panel → "Add Widgets"
   - Search for "Custom Dock"
   - Drag it to your panel

## Usage

### Adding Applications
- **Method 1**: Drag `.desktop` files from Application Menu onto the dock
- **Method 2**: Drag `.desktop` files from `/usr/share/applications/` using Dolphin

### Managing Icons
- **Reorder**: Click and drag an icon horizontally to reposition it
- **Remove**: Drag an icon away from the dock and drop it outside
- **Launch**: Click an icon to launch the application
- **Focus**: Click a running application's icon to bring its window to focus

### Configuration
The dock stores your pinned applications in:
```
~/.config/plasma-org.kde.plasma.desktop-appletsrc
```

## Architecture

The codebase is organized into modular, reusable components:

```
contents/ui/
├── main.qml                      # Root component, orchestration & persistence
├── DockContainer.qml             # Visual container, ListView, animations
├── DockIcon.qml                  # Individual icon with drag/scale/hover logic
├── TaskManagerIntegration.qml    # Window tracking & app launching
└── DesktopFileReader.qml         # .desktop file parser
```

### Component Responsibilities

**main.qml** (270 lines)
- Configuration properties and state management
- Persistence functions (save/load pinned apps)
- Tooltip window management with debouncing timers
- Compact and full representation definitions

**DockContainer.qml** (200 lines)
- Dock visual styling and layout
- ListView with icon delegates
- Drop area for external .desktop files
- Optional debug overlay for development

**DockIcon.qml** (346 lines)
- Icon rendering and visual effects
- Drag & drop with position tracking
- Hover detection and tooltip triggers
- Running indicator dot
- Context menu

**TaskManagerIntegration.qml** (52 lines)
- TasksModel integration for window tracking
- Application launcher via P5Support.DataSource
- activateOrLaunch() logic for smart window management

**DesktopFileReader.qml** (55 lines)
- Sequential .desktop file parsing with kreadconfig5
- Extracts: Icon, Name, StartupWMClass, Exec
- Emits appInfoReady signal with parsed data

## Technical Details

### Dependencies
- KDE Plasma 6
- Qt 6 (QtQuick, QtQuick.Controls)
- org.kde.taskmanager 0.1
- org.kde.plasma.plasma5support 2.0
- kreadconfig5

### Key Technologies
- **QML/QtQuick**: Modern declarative UI framework
- **TasksModel**: KDE's window/task management API
- **HoverHandler**: Non-blocking hover detection
- **Property Bindings**: Reactive data flow
- **Transform.Translate**: Hardware-accelerated animations
- **PlasmaCore.PopupPlasmaWindow**: Native tooltip rendering

### Performance Optimizations
- Fixed icon size in center calculations prevents feedback loops
- Visual displacement instead of real-time model updates during drag
- Debounced tooltip showing (500ms delay) to prevent KWin crashes
- Hardware-accelerated transformations for smooth 60fps animations

## Configuration

### Adjustable Properties (in main.qml)
```qml
property real iconSize: parent.height * 0.5    // Base icon size
property real iconSpacing: 1                    // Spacing between icons
property real maxScale: 1.5                     // Maximum magnification
property real influenceRadius: 80               // Hover effect range
```

### Tooltip Timing
```qml
tooltipShowTimer.interval: 500   // Delay before showing tooltip
tooltipHideTimer.interval: 100   // Delay before hiding tooltip
```

### Debug Mode
Enable debug overlay in `DockContainer.qml`:
```qml
showDebug: true  // Shows running tasks and dock icon info
```

## Troubleshooting

### Icons Not Showing
- Ensure `.desktop` files are valid and contain `Icon=` field
- Check Plasmoid configuration: `~/.config/plasma-org.kde.plasma.desktop-appletsrc`
- Look for `pinnedApps` JSON in the configuration

### Running Indicators Not Working
- Verify TaskManager integration: Enable debug overlay
- Check if `AppId` matches application's desktop file name
- Some apps use non-standard window class names

### Drag & Drop Not Working
- Ensure you're dragging actual `.desktop` files
- Check file permissions on dragged files
- Try dragging from Application Menu instead of file manager

### Tooltip Issues
- If tooltips cause KWin crashes, increase `tooltipShowTimer.interval`
- Verify `visualParent` is being set correctly in hover handler

## Development

### Testing Changes
```bash
# Restart Plasma Shell to reload
kquitapp6 plasmashell && plasmashell --replace &

# Or reload just the widget
qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript 'string:
var allDesktops = desktops();
for (i=0;i<allDesktops.length;i++) {
    d = allDesktops[i];
    d.currentActivity.reloadConfig();
}'
```

### Debug Logging
Enable console output:
```bash
journalctl --user -f | grep plasmashell
```

### Adding Features
1. Keep components modular and single-responsibility
2. Use signals for cross-component communication
3. Prefer property bindings over imperative updates
4. Test drag operations and animations thoroughly

## License

This project is free software; you can redistribute it and/or modify it under the terms of your preferred open source license.

## Credits

- Inspired by macOS Dock and KDE's default task manager
- Built with KDE Plasma Framework
- Uses TaskManager for window tracking

## Contributing

Contributions welcome! Areas for improvement:
- [ ] Add configuration UI for customization
- [ ] Support for badge notifications
- [ ] Application menus on right-click
- [ ] Multi-monitor support improvements
- [ ] Custom icon size per application
- [ ] Folder stacks support
- [ ] Export/import dock configuration

---

**Author**: Tomasz Rup  
**Version**: 1.0  
**KDE Plasma**: 6.x  
**Repository**: https://github.com/tomaszrup/xdock
