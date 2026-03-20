/*
    SPDX-FileCopyrightText: 2012-2016 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.private.mpris as Mpris
import org.kde.kirigami as Kirigami

import org.kde.plasma.workspace.trianglemousefilter

import org.kde.taskmanager as TaskManager
import org.plasmadock as TaskManagerApplet
import org.kde.plasma.workspace.dbus as DBus

import "code/LayoutMetrics.js" as LayoutMetrics
import "code/TaskTools.js" as TaskTools

PlasmoidItem {
    id: tasks

    // For making a bottom to top layout since qml flow can't do that.
    // We just hang the task manager upside down to achieve that.
    // This mirrors the tasks and group dialog as well, so we un-rotate them
    // to fix that (see Task.qml and GroupDialog.qml).
    rotation: Plasmoid.configuration.reverseMode && Plasmoid.formFactor === PlasmaCore.Types.Vertical ? 180 : 0

    readonly property bool shouldShrinkToZero: tasksModel.count === 0
    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property bool iconsOnly: Plasmoid.pluginName === "org.plasmadock"

    // Magic number constants for spacing and layout
    readonly property int panelZoomPadding: 14
    readonly property int reflectionAllowance: Plasmoid.configuration.showReflection
        ? Plasmoid.configuration.iconSize / 2 + 10 : 0

    property Task toolTipOpenedByClick
    property Task toolTipAreaItem

    readonly property Component contextMenuComponent: Qt.createComponent("ContextMenu.qml")
    readonly property Component pulseAudioComponent: Qt.createComponent("PulseAudio.qml")

    property alias taskList: taskList

    preferredRepresentation: fullRepresentation

  // --- Transparency logic ---
  // NOTE: This is a workaround for Plasma not exposing a proper API for applets
  // to control panel transparency. The ideal solution would be an upstream Plasma
  // API that allows applets to request transparency changes.
  //
  // This code walks the containment hierarchy looking for the panel containment
  // and forcibly sets backgroundHints to disable the panel background behind
  // this applet. This affects the entire panel, not just this applet.
  //
  // Potential issues:
  // - Modifies items this applet doesn't own
  // - Could affect other applets on the same panel
  // - Depends on Plasma internals that may change
  property Item containmentItem: null
  readonly property int depth: 14
  property bool isBackgroundDisabled: true

  function lookForContainer(object, tries) {
      if (tries === 0 || object === null) return;
      // Check for a containment by looking for Plasmoid.backgroundHints property
      if (object.Plasmoid && object.Plasmoid.backgroundHints !== undefined && object !== tasks) {
          tasks.containmentItem = object;
      } else {
          lookForContainer(object.parent, tries - 1);
      }
  }

  function applyBackgroundHint() {
      if (tasks.containmentItem === null) lookForContainer(tasks.parent, depth);
      if (tasks.containmentItem === null) return;

      tasks.containmentItem.Plasmoid.backgroundHints = (isBackgroundDisabled) ? 0 : 1;
      tasks.Plasmoid.backgroundHints = (isBackgroundDisabled) ? 0 : 1;

      ensurePanelFitsZoom();
  }

   // NOTE: This function modifies the panel window and ancestor items,
   // which are not owned by this applet. This is a fragile workaround
   // that could break with Plasma updates or affect other applets.
   //
   // The ideal solution would be:
   // 1. Plasma API for applets to request panel sizing
   // 2. Proper containment hierarchy handling
   // 3. Applet-specific clipping control
   //
   // Limited to 5 levels to avoid walking the entire tree and breaking
   // unrelated components.
   function ensurePanelFitsZoom() {
       let neededHeight = maxZoomedHeight + panelZoomPadding;

       // Try to resize the panel window to fit zoomed icons
       let win = tasks.Window.window;
       if (win && win.height < neededHeight) {
           win.height = neededHeight;
       }

       // Disable clipping on ancestor QML items (limited to 5 levels)
       let item = tasks.parent;
       let depth = 0;
       while (item && depth < 5) {
           if (item.clip !== undefined) {
               item.clip = false;
          }
          item = item.parent;
      }
  }

  // Counter of tasks currently zoomed; avoids iterating all tasks
  property int zoomedTaskCount: 0
  readonly property bool isZoomActive: zoomedTaskCount > 0

  // Maximum icon height when fully zoomed (for panel sizing)
  readonly property real maxZoomedHeight: Plasmoid.configuration.iconSize * (1.0 + Plasmoid.configuration.magnification / 100)

    Plasmoid.onUserConfiguringChanged: {
        if (Plasmoid.userConfiguring && groupDialog !== null) {
            groupDialog.visible = false;
        }
    }

    Layout.fillWidth: vertical ? true : Plasmoid.configuration.fill
    Layout.fillHeight: !vertical ? true : Plasmoid.configuration.fill
    Layout.minimumWidth: {
        if (shouldShrinkToZero) {
            return Kirigami.Units.gridUnit; // For edit mode
        }
        return vertical ? 0 : LayoutMetrics.preferredMinWidth();
    }
    Layout.minimumHeight: {
        if (shouldShrinkToZero) {
            return Kirigami.Units.gridUnit; // For edit mode
        }
        if (!vertical) {
            // Request enough height for zoomed icons + reflection
            return maxZoomedHeight + reflectionAllowance;
        }
        return LayoutMetrics.preferredMinHeight();
    }

    Layout.preferredWidth: {
        if (shouldShrinkToZero) {
            return 0.01;
        }
        if (vertical) {
            return Kirigami.Units.gridUnit * 10;
        }
        return taskList.Layout.maximumWidth
    }
    Layout.preferredHeight: {
        if (shouldShrinkToZero) {
            return 0.01;
        }
        if (vertical) {
            return taskList.Layout.maximumHeight
        }
        // Request enough height for zoomed icons + reflection
        return maxZoomedHeight + reflectionAllowance;
    }

    property Item dragSource

    signal requestLayout

    onDragSourceChanged: {
        if (dragSource === null) {
            tasksModel.syncLaunchers();
        }
    }

    function windowsHovered(winIds: var, hovered: bool): DBus.DBusPendingReply {
        if (!Plasmoid.configuration.highlightWindows) {
            return;
        }
        return DBus.SessionBus.asyncCall({service: "org.kde.KWin.HighlightWindow", path: "/org/kde/KWin/HighlightWindow", iface: "org.kde.KWin.HighlightWindow", member: "highlightWindows", arguments: [hovered ? winIds : []], signature: "(as)"});
    }

    function cancelHighlightWindows(): DBus.DBusPendingReply {
        return DBus.SessionBus.asyncCall({service: "org.kde.KWin.HighlightWindow", path: "/org/kde/KWin/HighlightWindow", iface: "org.kde.KWin.HighlightWindow", member: "highlightWindows", arguments: [[]], signature: "(as)"});
    }

    function activateWindowView(winIds: var): DBus.DBusPendingReply {
        if (!effectWatcher.registered) {
            return;
        }
        cancelHighlightWindows();
        return DBus.SessionBus.asyncCall({service: "org.kde.KWin.Effect.WindowView1", path: "/org/kde/KWin/Effect/WindowView1", iface: "org.kde.KWin.Effect.WindowView1", member: "activate", arguments: [winIds.map(s => String(s))], signature: "(as)"});
    }

    function publishIconGeometries(): void {
        if (TaskTools.taskManagerInstanceCount >= 2) {
            return;
        }
        for (let i = 0; i < taskRepeater.count; ++i) {
            const task = taskRepeater.itemAt(i);

            if (!task || task.model.IsLauncher || task.model.IsStartup) {
                continue;
            }
            tasksModel.requestPublishDelegateGeometry(tasksModel.makeModelIndex(task.index),
                backend.globalRect(task), task);
        }
    }

    readonly property TaskManager.TasksModel tasksModel: TaskManager.TasksModel {
        id: tasksModel

        readonly property int logicalLauncherCount: {
            if (Plasmoid.configuration.separateLaunchers) {
                return launcherCount;
            }

            let startupsWithLaunchers = 0;

            for (let i = 0; i < taskRepeater.count; ++i) {
                const item = taskRepeater.itemAt(i) as Task;

                // During destruction required properties such as item.model can go null for a while,
                // so in paths that can trigger on those moments, they need to be guarded
                if (item?.model?.IsStartup && item.model.HasLauncher) {
                    ++startupsWithLaunchers;
                }
            }

            return launcherCount + startupsWithLaunchers;
        }

        virtualDesktop: virtualDesktopInfo.currentDesktop
        screenGeometry: Plasmoid.containment.screenGeometry
        activity: activityInfo.currentActivity

        filterByVirtualDesktop: Plasmoid.configuration.showOnlyCurrentDesktop
        filterByScreen: Plasmoid.configuration.showOnlyCurrentScreen
        filterByActivity: Plasmoid.configuration.showOnlyCurrentActivity
        filterNotMinimized: Plasmoid.configuration.showOnlyMinimized

        hideActivatedLaunchers: tasks.iconsOnly || Plasmoid.configuration.hideLauncherOnStart
        sortMode: sortModeEnumValue(Plasmoid.configuration.sortingStrategy)
        launchInPlace: tasks.iconsOnly && Plasmoid.configuration.sortingStrategy === 1
        separateLaunchers: {
            if (!tasks.iconsOnly && !Plasmoid.configuration.separateLaunchers
                && Plasmoid.configuration.sortingStrategy === 1) {
                return false;
            }

            return true;
        }

        groupMode: groupModeEnumValue(Plasmoid.configuration.groupingStrategy)
        groupInline: !Plasmoid.configuration.groupPopups && !tasks.iconsOnly
        groupingWindowTasksThreshold: (Plasmoid.configuration.onlyGroupWhenFull && !tasks.iconsOnly
            ? LayoutMetrics.optimumCapacity(tasks.width, tasks.height) + 1 : -1)

        onLauncherListChanged: {
            Plasmoid.configuration.launchers = launcherList;
        }

        onGroupingAppIdBlacklistChanged: {
            Plasmoid.configuration.groupingAppIdBlacklist = groupingAppIdBlacklist;
        }

        onGroupingLauncherUrlBlacklistChanged: {
            Plasmoid.configuration.groupingLauncherUrlBlacklist = groupingLauncherUrlBlacklist;
        }

        function sortModeEnumValue(index: int): int {
            switch (index) {
            case 0:
                return TaskManager.TasksModel.SortDisabled;
            case 1:
                return TaskManager.TasksModel.SortManual;
            case 2:
                return TaskManager.TasksModel.SortAlpha;
            case 3:
                return TaskManager.TasksModel.SortVirtualDesktop;
            case 4:
                return TaskManager.TasksModel.SortActivity;
            // 5 is SortLastActivated, skipped
            case 6:
                return TaskManager.TasksModel.SortWindowPositionHorizontal;
            default:
                return TaskManager.TasksModel.SortDisabled;
            }
        }

        function groupModeEnumValue(index: int): int {
            switch (index) {
            case 0:
                return TaskManager.TasksModel.GroupDisabled;
            case 1:
                return TaskManager.TasksModel.GroupApplications;
            default:
                return TaskManager.TasksModel.GroupDisabled;
            }
        }

        Component.onCompleted: {
            launcherList = Plasmoid.configuration.launchers;
            groupingAppIdBlacklist = Plasmoid.configuration.groupingAppIdBlacklist;
            groupingLauncherUrlBlacklist = Plasmoid.configuration.groupingLauncherUrlBlacklist;

            // Only hook up view only after the above churn is done.
            taskRepeater.model = tasksModel;
        }
    }

    readonly property TaskManagerApplet.Backend backend: TaskManagerApplet.Backend {
        id: backend

        onAddLauncher: url => {
            tasks.addLauncher(url);
        }
    }

    DBus.DBusServiceWatcher {
        id: effectWatcher
        busType: DBus.BusType.Session
        watchedService: "org.kde.KWin.Effect.WindowView1"
    }

    readonly property Component taskInitComponent: Component {
        Timer {
            interval: 200
            running: true

            onTriggered: {
                const task = parent as Task;
                if (task) {
                    tasks.tasksModel.requestPublishDelegateGeometry(task.modelIndex(), tasks.backend.globalRect(task), task);
                }
                destroy();
            }
        }
    }

    Connections {
        target: Plasmoid

        function onLocationChanged(): void {
            if (TaskTools.taskManagerInstanceCount >= 2) {
                return;
            }
            // This is on a timer because the panel may not have
            // settled into position yet when the location prop-
            // erty updates.
            iconGeometryTimer.start();
        }
    }

    Connections {
        target: Plasmoid.containment

        function onScreenGeometryChanged(): void {
            iconGeometryTimer.start();
        }
    }

    Mpris.Mpris2Model {
        id: mpris2Source
    }

    Item {
        anchors.fill: parent

        TaskManager.VirtualDesktopInfo {
            id: virtualDesktopInfo
        }

        TaskManager.ActivityInfo {
            id: activityInfo
            readonly property string nullUuid: "00000000-0000-0000-0000-000000000000"
        }

        Loader {
            id: pulseAudio
            sourceComponent: tasks.pulseAudioComponent
            active: tasks.pulseAudioComponent.status === Component.Ready
        }

        Timer {
            id: iconGeometryTimer

            interval: 500
            repeat: false

            onTriggered: {
                tasks.publishIconGeometries();
            }
        }

        Binding {
            target: Plasmoid
            property: "status"
            value: (tasksModel.anyTaskDemandsAttention && Plasmoid.configuration.unhideOnAttention
                ? PlasmaCore.Types.NeedsAttentionStatus : PlasmaCore.Types.PassiveStatus)
            restoreMode: Binding.RestoreBinding
        }

        Connections {
            target: Plasmoid.configuration

            function onLaunchersChanged(): void {
                tasksModel.launcherList = Plasmoid.configuration.launchers
            }
            function onGroupingAppIdBlacklistChanged(): void {
                tasksModel.groupingAppIdBlacklist = Plasmoid.configuration.groupingAppIdBlacklist;
            }
            function onGroupingLauncherUrlBlacklistChanged(): void {
                tasksModel.groupingLauncherUrlBlacklist = Plasmoid.configuration.groupingLauncherUrlBlacklist;
            }
        }

        Component {
            id: busyIndicator
            PlasmaComponents3.BusyIndicator {}
        }

        // Save drag data
        Item {
            id: dragHelper

            Drag.dragType: Drag.Automatic
            Drag.supportedActions: Qt.CopyAction | Qt.MoveAction | Qt.LinkAction
            Drag.onDragFinished: dropAction => {
                tasks.dragSource = null;
            }
        }

        MouseHandler {
            id: mouseHandler

            anchors.fill: parent

            target: dockContainer

            onUrlsDropped: urls => {
                // If all dropped URLs point to application desktop files, we'll add a launcher for each of them.
                const createLaunchers = urls.every(item => tasks.backend.isApplication(item));

                if (createLaunchers) {
                    urls.forEach(item => addLauncher(item));
                    return;
                }

                if (!hoveredItem) {
                    return;
                }

                // Otherwise we'll just start a new instance of the application with the URLs as argument,
                // as you probably don't expect some of your files to open in the app and others to spawn launchers.
                tasksModel.requestOpenUrls((hoveredItem as Task).modelIndex(), urls);
            }
        }

        ToolTipDelegate {
            id: openWindowToolTipDelegate
            visible: false
        }

        ToolTipDelegate {
            id: pinnedAppToolTipDelegate
            visible: false
        }

        TriangleMouseFilter {
            id: tmf
            filterTimeOut: 300
            active: false
            blockFirstEnter: false

            edge: {
                switch (Plasmoid.location) {
                case PlasmaCore.Types.BottomEdge:
                    return Qt.TopEdge;
                case PlasmaCore.Types.TopEdge:
                    return Qt.BottomEdge;
                case PlasmaCore.Types.LeftEdge:
                    return Qt.RightEdge;
                case PlasmaCore.Types.RightEdge:
                    return Qt.LeftEdge;
                default:
                    return Qt.TopEdge;
                }
            }

            LayoutMirroring.enabled: tasks.shouldBeMirrored(Plasmoid.configuration.reverseMode, Application.layoutDirection, tasks.vertical)
            anchors {
                left: parent.left
                top: parent.top
            }

            height: taskList.height
            width: taskList.width

            TaskList {
                id: taskList

                // Extra width to prevent side clipping when edge icons zoom.
                // The zoom translate shifts the entire group outward by up to
                // half the total visual expansion, so we need enough overflow
                // on each side to accommodate that.
                readonly property real zoomOverflow: {
                    let iconSize = Plasmoid.configuration.iconSize;
                    let amplitude = Plasmoid.configuration.magnification / 100;
                    let baseWidth = iconSize + 6;
                    let sigma = iconSize * 1.8;
                    // Sum the Gaussian expansion across all tasks (worst case: mouse at center)
                    let n = taskRepeater.count;
                    let totalExpansion = 0;
                    for (let i = 0; i < n; ++i) {
                        let dist = Math.abs(i - (n - 1) / 2) * baseWidth;
                        if (dist < sigma * 3) {
                            totalExpansion += amplitude * Math.exp(-(dist * dist) / (2 * sigma * sigma)) * baseWidth;
                        }
                    }
                    // Each side needs half the total expansion, plus the scaled icon overhang
                    return totalExpansion / 2 + iconSize * amplitude;
                }

                width: Math.ceil(taskRepeater.count * (Plasmoid.configuration.iconSize + panelZoomPadding)) + zoomOverflow
                height: tasks.height

                // Total width of all icons for centering (constant — width no longer varies with zoom)
                readonly property real iconsTotalWidth: taskRepeater.count * (Plasmoid.configuration.iconSize + 6)

                // Offset needed to center the icon block
                readonly property real centerOffset: (width - iconsTotalWidth) / 2

                // Cumulative X offsets — stable since task widths are constant.
                // Only recomputed when task count or config changes.
                property var taskOffsets: {
                    let baseWidth = Plasmoid.configuration.iconSize + 6;
                    let offsets = new Array(taskRepeater.count + 1);
                    offsets[0] = centerOffset;
                    for (let i = 0; i < taskRepeater.count; ++i) {
                        offsets[i + 1] = offsets[i] + baseWidth;
                    }
                    return offsets;
                }

                Layout.maximumWidth: width

                flow: {
                    if (tasks.vertical) {
                        return Plasmoid.configuration.forceStripes ? Grid.LeftToRight : Grid.TopToBottom
                    }
                    return Plasmoid.configuration.forceStripes ? Grid.TopToBottom : Grid.LeftToRight
                }

                onAnimatingChanged: {
                    if (!animating) {
                        tasks.publishIconGeometries();
                    }
                }

                Item {
                    id: dockContainer
                    width: taskList.width
                    height: taskList.height

                    property real smoothMouseX: -1
                    property bool insideDock: false
                    property alias animating: taskList.animating
                    property int taskCount: taskRepeater.count
                    property alias taskRepeater: taskRepeater

                    // Precomputed per-task X translation for zoom visual expansion.
                    // Reads each task's animated zoomFactor so translate and scale
                    // stay perfectly in sync (no separate Behavior needed).
                    // O(N) single pass, recomputed when any zoomFactor changes.
                    readonly property var zoomTranslates: {
                        let baseWidth = Plasmoid.configuration.iconSize + 6;
                        let n = taskRepeater.count;
                        let expansions = new Array(n);
                        let totalExpansion = 0;
                        for (let i = 0; i < n; ++i) {
                            let item = taskRepeater.itemAt(i);
                            let e = item ? (item.zoomFactor - 1) * baseWidth : 0;
                            expansions[i] = e;
                            totalExpansion += e;
                        }
                        let halfExpansion = totalExpansion / 2;
                        let offsets = new Array(n);
                        let cumulative = 0;
                        for (let i = 0; i < n; ++i) {
                            // Center the expansion: shift left by half, then add
                            // cumulative expansion of all tasks before this one,
                            // plus half this task's own expansion (center anchor).
                            offsets[i] = -halfExpansion + cumulative + expansions[i] / 2;
                            cumulative += expansions[i];
                        }
                        return offsets;
                    }

                    HoverHandler {
                        id: dockHoverHandler

                        onPointChanged: {
                            let x = point.position.x;
                            if (dockContainer.smoothMouseX < 0) {
                                dockContainer.smoothMouseX = x;
                            } else {
                                dockContainer.smoothMouseX += (x - dockContainer.smoothMouseX) * 0.3;
                            }
                            dockContainer.insideDock = true;
                        }

                        onHoveredChanged: {
                            if (hovered) {
                                dockContainer.insideDock = true;
                            } else {
                                exitTimer.restart();
                            }
                        }
                    }

                    Timer {
                        id: exitTimer
                        interval: 40
                        repeat: false
                        onTriggered: {
                            if (!dockHoverHandler.hovered) {
                                dockContainer.insideDock = false;
                                dockContainer.smoothMouseX = -1;
                            }
                        }
                    }

                    Repeater {
                        id: taskRepeater
                        model: tasksModel

                        delegate: Task {
                            id: taskItem
                            tasksRoot: tasks
                            dockRef: dockContainer

                            x: taskList.taskOffsets[index] ?? taskList.centerOffset

                            // Animate non-dragged tasks sliding into their new position during reorder
                            Behavior on x {
                                enabled: !taskItem.taskDragActive && tasks.dragSource !== null
                                NumberAnimation {
                                    duration: 250
                                    easing.type: Easing.OutCubic
                                }
                            }

                            // Constant width — zoom is purely visual via iconBox.scale
                            // and dockContainer.zoomTranslates (GPU transforms, no relayout)
                            width: Plasmoid.configuration.iconSize + 6
                        }
                    }
                }
            }
        }
    }

    readonly property Component groupDialogComponent: Qt.createComponent("GroupDialog.qml")
    property GroupDialog groupDialog

    readonly property bool supportsLaunchers: true

    function hasLauncher(url: url): bool {
        return tasksModel.launcherPosition(url) !== -1;
    }

    function addLauncher(url: url): void {
        if (Plasmoid.immutability !== PlasmaCore.Types.SystemImmutable) {
            tasksModel.requestAddLauncher(url);
        }
    }

    function removeLauncher(url: url): void {
        if (Plasmoid.immutability !== PlasmaCore.Types.SystemImmutable) {
            tasksModel.requestRemoveLauncher(url);
        }
    }

    // This is called by plasmashell in response to a Meta+number shortcut.
    function activateTaskAtIndex(index: int): void {
        const task = taskRepeater.itemAt(index) as Task;
        if (task) {
            TaskTools.activateTask(task.modelIndex(), task.model, null, task, Plasmoid, this, effectWatcher.registered);
        }
    }

    function createContextMenu(rootTask, modelIndex, args = {}) {
        const initialArgs = Object.assign(args, {
            visualParent: rootTask,
            modelIndex,
            tasksModel,
            mpris2Source,
            backend,
            virtualDesktopInfo,
            activityInfo,
        });
        return contextMenuComponent.createObject(rootTask, initialArgs);
    }

    function shouldBeMirrored(reverseMode, layoutDirection, vertical): bool {
        // LayoutMirroring is only horizontal
        if (vertical) {
            return layoutDirection === Qt.RightToLeft;
        }

        if (layoutDirection === Qt.LeftToRight) {
            return reverseMode;
        }
        return !reverseMode;
    }

    Component.onCompleted: {
        TaskTools.taskManagerInstanceCount += 1;
        requestLayout.connect(iconGeometryTimer.restart);
        applyBackgroundHint();
    }

    Component.onDestruction: {
        TaskTools.taskManagerInstanceCount -= 1;
    }

    // Retry timer for applying transparent panel background
    Timer {
        id: initializeAppletTimer
        interval: 1200
        repeat: true
        running: true

        property int step: 0
        readonly property int maxStep: 5

        onTriggered: {
            applyBackgroundHint();

            if (tasks.containmentItem !== null || step >= maxStep) {
                stop();
            }
            step++;
        }
    }
}
