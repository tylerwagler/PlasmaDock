/*
    SPDX-FileCopyrightText: 2012-2013 Eike Hein <hein@kde.org>
    SPDX-FileCopyrightText: 2024 Nate Graham <nate@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.core as PlasmaCore
import org.kde.ksvg as KSvg
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.components as PlasmaComponents3
import org.kde.kirigami as Kirigami
import org.plasmadock as TaskManagerApplet
import org.kde.plasma.plasmoid
import org.kde.taskmanager as TaskManager

import "code/LayoutMetrics.js" as LayoutMetrics
import "code/TaskTools.js" as TaskTools

PlasmaCore.ToolTipArea {
    id: task

    activeFocusOnTab: true

    // To achieve a bottom-to-top layout on vertical panels, the task manager
    // is rotated by 180 degrees(see main.qml). This makes the tasks rotated,
    // so un-rotate them here to fix that.
    rotation: Plasmoid.configuration.reverseMode && Plasmoid.formFactor === PlasmaCore.Types.Vertical ? 180 : 0

    // Internal drag reordering is handled by taskDragHandler + _dragLocalX below.
    // Qt's Drag attached type is NOT used for internal moves (Drag.Internal would
    // physically relocate the item, breaking the x-offset binding and zoom).

    implicitHeight: inPopup
                    ? LayoutMetrics.preferredHeightInPopup()
                    : (tasksRoot.vertical
                        ? LayoutMetrics.preferredMinHeight()
                        : Math.max(tasksRoot.height / Plasmoid.configuration.maxStripes,
                             LayoutMetrics.preferredMinHeight()))
    implicitWidth: tasksRoot.vertical
        ? Math.max(LayoutMetrics.preferredMinWidth(), Math.min(LayoutMetrics.preferredMaxWidth(), tasksRoot.width / Plasmoid.configuration.maxStripes))
        : 0

    Layout.fillWidth: true
    Layout.fillHeight: !inPopup
    Layout.maximumWidth: tasksRoot.vertical
        ? -1
        : ((model.IsLauncher && !tasksRoot.iconsOnly) ? tasksRoot.height / taskList.rows : LayoutMetrics.preferredMaxWidth())
    Layout.maximumHeight: tasksRoot.vertical ? LayoutMetrics.preferredMaxHeight() : -1

    required property var model
    required property int index
    required property /*main.qml*/ Item tasksRoot

    readonly property int pid: model.AppPid
    readonly property string appName: model.AppName
    readonly property string appId: model.AppId.replace(/\.desktop/, '')
    readonly property bool isIcon: tasksRoot.iconsOnly || model.IsLauncher
    property bool toolTipOpen: false
    property bool inPopup: false
    property bool isWindow: model.IsWindow
    property int childCount: model.ChildCount
    property int previousChildCount: 0
    property alias labelText: label.text
    property QtObject contextMenu: null
    readonly property bool smartLauncherEnabled: !inPopup
    property QtObject smartLauncherItem: null

    property Item audioStreamIcon: null
    property var audioStreams: []
    property bool delayAudioStreamIndicator: false
    property bool completed: false
    readonly property bool audioIndicatorsEnabled: Plasmoid.configuration.indicateAudioStreams
    readonly property bool tooltipControlsEnabled: Plasmoid.configuration.tooltipControls
    readonly property bool hasAudioStream: audioStreams.length > 0
    readonly property bool playingAudio: hasAudioStream && audioStreams.some(item => !item.corked)
    readonly property bool muted: hasAudioStream && audioStreams.every(item => item.muted)

    readonly property bool highlighted: (inPopup && activeFocus) || (!inPopup && containsMouse)
        || (task.contextMenu && task.contextMenu.status === PlasmaExtras.Menu.Open)
        || (!!tasksRoot.groupDialog && tasksRoot.groupDialog.visualParent === task)

    active: !inPopup && !tasksRoot.groupDialog && task.contextMenu?.status !== PlasmaExtras.Menu.Open
    interactive: model.IsWindow || mainItem.playerData
    location: Plasmoid.location
    mainItem: !Plasmoid.configuration.showToolTips || !model.IsWindow ? pinnedAppToolTipDelegate : openWindowToolTipDelegate

    width: Plasmoid.configuration.iconSize
    height: tasksRoot.height

    // Disable clipping so zoom and reflection can extend outside bounds
    clip: false

    property bool isHovered: false

    property Item dockRef: null

    // Magic number constants for task layout and zoom
    readonly property real _baseSize: Plasmoid.configuration.iconSize
    readonly property real _sigma: _baseSize * 1.8
    readonly property real _amplitude: Plasmoid.configuration.magnification / 100
    readonly property int _taskWidthPadding: 6
    readonly property int _iconBottomOffset: -5
    readonly property int _reflectionHorizontalOffset: -4

    // Lift the dragged task above its siblings and translate it with the cursor.
    // Uses scene coordinates so the visual position stays stable across model
    // reorders and zoom-driven offset changes.
    z: taskDragHandler.active ? 1000 : 0
    property real _dragStartSceneX: 0
    property real _dragStartTaskX: 0
    transform: Translate {
        x: taskDragHandler.active
            ? taskDragHandler.centroid.scenePosition.x - task._dragStartSceneX + task._dragStartTaskX - task.x
            : 0
    }

    // macOS-style zoom effect using Gaussian curve
    property real zoomFactor: {
        if (!dockRef || _amplitude <= 0) return 1.0;
        if (!dockRef.insideDock) return 1.0;

        let mX = dockRef.smoothMouseX;
        if (mX < 0) return 1.0;

        let centerInDock = task.mapToItem(dockRef, _baseSize / 2, 0).x;
        let distance = Math.abs(mX - centerInDock);

        if (distance > _sigma * 3) return 1.0;

        return 1.0 + _amplitude * Math.exp(-(Math.pow(distance, 2) / (2 * Math.pow(_sigma, 2))));
    }

    property bool _wasZoomed: false
    onZoomFactorChanged: {
        let zoomed = zoomFactor > 1.01;
        if (zoomed !== _wasZoomed) {
            _wasZoomed = zoomed;
            tasksRoot.zoomedTaskCount += zoomed ? 1 : -1;
        }
    }

    // Smooth transition when mouse leaves the dock
    Behavior on zoomFactor {
        NumberAnimation {
            duration: 200
            easing.type: Easing.OutCubic
        }
    }
    Accessible.name: model.display
    Accessible.description: {
        if (!model.display) {
            return "";
        }

        if (model.IsLauncher) {
            return i18nc("@info:usagetip %1 application name", "Launch %1", model.display)
        }

        let smartLauncherDescription = "";
        if (iconBox.active) {
            smartLauncherDescription += i18ncp("@info:tooltip", "There is %1 new message.", "There are %1 new messages.", task.smartLauncherItem.count);
        }

        if (model.IsGroupParent) {
            switch (Plasmoid.configuration.groupedTaskVisualization) {
            case 0:
                break; // Use the default description
            case 1: {
                return `${i18nc("@info:usagetip %1 task name", "Show Task tooltip for %1", model.display)}; ${smartLauncherDescription}`;
            }
            case 2: {
                if (effectWatcher.registered) {
                    return `${i18nc("@info:usagetip %1 task name", "Show windows side by side for %1", model.display)}; ${smartLauncherDescription}`;
                }
                // fallthrough
            }
            default:
                return `${i18nc("@info:usagetip %1 task name", "Open textual list of windows for %1", model.display)}; ${smartLauncherDescription}`;
            }
        }

        return `${i18nc("@info:usagetip %1 task name", "Activate %1", model.display)}; ${smartLauncherDescription}`;
    }
    Accessible.role: Accessible.Button
    Accessible.onPressAction: leftTapHandler.leftClick()

    onToolTipVisibleChanged: toolTipVisible => {
        task.toolTipOpen = toolTipVisible;
        if (!toolTipVisible) {
            tasksRoot.toolTipOpenedByClick = null;
        } else {
            tasksRoot.toolTipAreaItem = task;
        }
    }

    onContainsMouseChanged: {
        if (containsMouse) {
            task.forceActiveFocus(Qt.MouseFocusReason);
            task.updateMainItemBindings();
        } else {
            tasksRoot.toolTipOpenedByClick = null;
        }
    }

    onHighlightedChanged: {
        // ensure it doesn't get stuck with a window highlighted
        tasksRoot.cancelHighlightWindows();
    }

    onPidChanged: updateAudioStreams({delay: false})
    onAppNameChanged: updateAudioStreams({delay: false})

    onIsWindowChanged: {
        if (model.IsWindow) {
            taskInitComponent.createObject(task);
            updateAudioStreams({delay: false});
        }
    }

    onChildCountChanged: {
        if (TaskTools.taskManagerInstanceCount < 2 && childCount > previousChildCount) {
            tasksRoot.tasksModel.requestPublishDelegateGeometry(modelIndex(), backend.globalRect(task), task);
        }

        previousChildCount = childCount;
    }

    onIndexChanged: {
        hideToolTip();

        if (!inPopup && !tasksRoot.vertical
                && !Plasmoid.configuration.separateLaunchers) {
            tasksRoot.requestLayout();
        }
    }

    onSmartLauncherEnabledChanged: {
        if (smartLauncherEnabled && !smartLauncherItem) {
            const component = Qt.createComponent("org.plasmadock", "SmartLauncherItem");
            const smartLauncher = component.createObject(task);
            component.destroy();

            smartLauncher.launcherUrl = Qt.binding(() => model.LauncherUrlWithoutIcon);

            smartLauncherItem = smartLauncher;
        }
    }

    onHasAudioStreamChanged: {
        const audioStreamIconActive = hasAudioStream && audioIndicatorsEnabled;
        if (!audioStreamIconActive) {
            if (audioStreamIcon !== null) {
                audioStreamIcon.destroy();
                audioStreamIcon = null;
            }
            return;
        }
        // Create item on demand instead of using Loader to reduce memory consumption,
        // because only a few applications have audio streams.
        const component = Qt.createComponent("AudioStream.qml");
        audioStreamIcon = component.createObject(task);
        component.destroy();
    }
    onAudioIndicatorsEnabledChanged: task.hasAudioStreamChanged()

    Keys.onMenuPressed: event => contextMenuTimer.start()
    Keys.onReturnPressed: event => TaskTools.activateTask(modelIndex(), model, event.modifiers, task, Plasmoid, tasksRoot, effectWatcher.registered)
    Keys.onEnterPressed: event => Keys.returnPressed(event);
    Keys.onSpacePressed: event => Keys.returnPressed(event);
    Keys.onUpPressed: event => Keys.leftPressed(event)
    Keys.onDownPressed: event => Keys.rightPressed(event)
    Keys.onLeftPressed: event => {
        if (!inPopup && (event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.ShiftModifier)) {
            tasksRoot.tasksModel.move(task.index, task.index - 1);
        } else {
            event.accepted = false;
        }
    }
    Keys.onRightPressed: event => {
        if (!inPopup && (event.modifiers & Qt.ControlModifier) && (event.modifiers & Qt.ShiftModifier)) {
            tasksRoot.tasksModel.move(task.index, task.index + 1);
        } else {
            event.accepted = false;
        }
    }

    function modelIndex(): var { // returns QModelIndex
        return inPopup
            ? tasksRoot.tasksModel.makeModelIndex(groupDialog.visualParent.index, index)
            : tasksRoot.tasksModel.makeModelIndex(index);
    }

    function showContextMenu(args: var): void {
        task.hideImmediately();
        contextMenu = tasksRoot.createContextMenu(task, modelIndex(), args) as ContextMenu;
        contextMenu.show();
    }

    function updateAudioStreams(args: var): void {
        if (args) {
            // When the task just appeared (e.g. virtual desktop switch), show the audio indicator
            // right away. Only when audio streams change during the lifetime of this task, delay
            // showing that to avoid distraction.
            delayAudioStreamIndicator = !!args.delay;
        }

        var pa = pulseAudio.item;
        if (!pa || !task.isWindow) {
            task.audioStreams = [];
            return;
        }

        // Check appid first for app using portal
        // https://docs.pipewire.org/page_portal.html
        var streams = pa.streamsForAppId(task.appId);
        if (!streams.length) {
            streams = pa.streamsForPid(model.AppPid);
            if (streams.length) {
                pa.registerPidMatch(model.AppName);
            } else {
                // We only want to fall back to appName matching if we never managed to map
                // a PID to an audio stream window. Otherwise if you have two instances of
                // an application, one playing and the other not, it will look up appName
                // for the non-playing instance and erroneously show an indicator on both.
                if (!pa.hasPidMatch(model.AppName)) {
                    streams = pa.streamsForAppName(model.AppName);
                }
            }
        }

        task.audioStreams = streams;
    }

    function toggleMuted(): void {
        if (muted) {
            task.audioStreams.forEach(item => item.unmute());
        } else {
            task.audioStreams.forEach(item => item.mute());
        }
    }

    // Will also be called in activateTaskAtIndex(index)
    function updateMainItemBindings(): void {
        if ((mainItem.parentTask === this && mainItem.rootIndex.row === index)
            || (tasksRoot.toolTipOpenedByClick === null && !active)
            || (tasksRoot.toolTipOpenedByClick !== null && tasksRoot.toolTipOpenedByClick !== this)) {
            return;
        }

        mainItem.blockingUpdates = (mainItem.isGroup !== model.IsGroupParent); // BUG 464597 Force unload the previous component

        mainItem.parentTask = this;
        mainItem.rootIndex = tasksRoot.tasksModel.makeModelIndex(index, -1);

        mainItem.appName = Qt.binding(() => model.AppName);
        mainItem.pidParent = Qt.binding(() => model.AppPid);
        mainItem.windows = Qt.binding(() => model.WinIdList);
        mainItem.isGroup = Qt.binding(() => model.IsGroupParent);
        mainItem.icon = Qt.binding(() => model.decoration);
        mainItem.launcherUrl = Qt.binding(() => model.LauncherUrlWithoutIcon);
        mainItem.isLauncher = Qt.binding(() => model.IsLauncher);
        mainItem.isMinimized = Qt.binding(() => model.IsMinimized);
        mainItem.display = Qt.binding(() => model.display);
        mainItem.genericName = Qt.binding(() => model.GenericName);
        mainItem.virtualDesktops = Qt.binding(() => model.VirtualDesktops);
        mainItem.isOnAllVirtualDesktops = Qt.binding(() => model.IsOnAllVirtualDesktops);
        mainItem.activities = Qt.binding(() => model.Activities);

        mainItem.smartLauncherCountVisible = Qt.binding(() => smartLauncherItem?.countVisible ?? false);
        mainItem.smartLauncherCount = Qt.binding(() => mainItem.smartLauncherCountVisible ? (smartLauncherItem?.count ?? 0) : 0);

        mainItem.blockingUpdates = false;
        tasksRoot.toolTipAreaItem = this;
    }

    Connections {
        target: pulseAudio.item
        ignoreUnknownSignals: true // Plasma-PA might not be available
        function onStreamsChanged(): void {
            task.updateAudioStreams({delay: true})
        }
    }

    DragHandler {
        id: taskDragHandler
        target: null // Don't physically move the item
        grabPermissions: PointerHandler.TakeOverForbidden
        onActiveChanged: {
            if (active) {
                task._dragStartSceneX = centroid.scenePosition.x;
                task._dragStartTaskX = task.x;
                tasksRoot.dragSource = task;
            } else {
                tasksRoot.dragSource = null;
            }
        }
    }

    // Track drag position in dockContainer coordinates for reordering
    property bool _moveCooldown: false
    readonly property real _dragLocalX: {
        if (!taskDragHandler.active) return -1;
        let scenePos = taskDragHandler.centroid.scenePosition;
        let local = dockRef.mapFromItem(null, scenePos.x, scenePos.y);
        return local.x;
    }
    on_DragLocalXChanged: {
        if (_dragLocalX < 0 || _moveCooldown) return;
        if (tasksRoot.tasksModel?.sortMode !== TaskManager.TasksModel.SortManual) return;
        let target = dockRef.childAt(_dragLocalX, task.height / 2);
        if (target && target !== task && target.index !== undefined && target.index !== index) {
            tasksRoot.tasksModel.move(index, target.index);
            _moveCooldown = true;
            _moveCooldownTimer.restart();
        }
    }
    Timer {
        id: _moveCooldownTimer
        interval: 200
        onTriggered: task._moveCooldown = false
    }

    TapHandler {
        id: menuTapHandler
        acceptedButtons: Qt.LeftButton
        acceptedDevices: PointerDevice.TouchScreen | PointerDevice.Stylus
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onLongPressed: {
            // When we're a launcher, there's no window controls, so we can show all
            // places without the menu getting super huge.
            if (task.model.IsLauncher) {
                task.showContextMenu({showAllPlaces: true})
            } else {
                task.showContextMenu();
            }
        }
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad | PointerDevice.Stylus
        gesturePolicy: TapHandler.WithinBounds // Release grab when menu appears
        onPressedChanged: if (pressed) contextMenuTimer.start()
    }

    Timer {
        id: contextMenuTimer
        interval: 0
        onTriggered: menuTapHandler.longPressed()
    }

    TapHandler {
        id: leftTapHandler
        acceptedButtons: Qt.LeftButton
        onTapped: (eventPoint, button) => leftClick()

        function leftClick(): void {
            if (task.active) {
                task.hideToolTip();
            }
            TaskTools.activateTask(modelIndex(), model, point.modifiers, task, Plasmoid, tasksRoot, effectWatcher.registered);
        }
    }

    TapHandler {
        acceptedButtons: Qt.MiddleButton | Qt.BackButton | Qt.ForwardButton
        onTapped: (eventPoint, button) => {
            if (button === Qt.MiddleButton) {
                if (Plasmoid.configuration.middleClickAction === TaskManagerApplet.Backend.NewInstance) {
                    tasksRoot.tasksModel.requestNewInstance(modelIndex());
                } else if (Plasmoid.configuration.middleClickAction === TaskManagerApplet.Backend.Close) {
                    tasksRoot.tasksModel.requestClose(modelIndex());
                } else if (Plasmoid.configuration.middleClickAction === TaskManagerApplet.Backend.ToggleMinimized) {
                    tasksRoot.tasksModel.requestToggleMinimized(modelIndex());
                } else if (Plasmoid.configuration.middleClickAction === TaskManagerApplet.Backend.ToggleGrouping) {
                    tasksRoot.tasksModel.requestToggleGrouping(modelIndex());
                } else if (Plasmoid.configuration.middleClickAction === TaskManagerApplet.Backend.BringToCurrentDesktop) {
                    tasksRoot.tasksModel.requestVirtualDesktops(modelIndex(), [virtualDesktopInfo.currentDesktop]);
                }
            } else if (button === Qt.BackButton || button === Qt.ForwardButton) {
                const playerData = mpris2Source.playerForLauncherUrl(task.model.LauncherUrlWithoutIcon, task.model.AppPid);
                if (playerData) {
                    if (button === Qt.BackButton) {
                        playerData.Previous();
                    } else {
                        playerData.Next();
                    }
                } else {
                    eventPoint.accepted = false;
                }
            }

            task.tasksRoot.cancelHighlightWindows();
        }
    }

    KSvg.FrameSvgItem {
        id: frame

        anchors {
            fill: parent

            topMargin: (!task.tasksRoot.vertical && taskList.rows > 1) ? LayoutMetrics.iconMargin : 0
            bottomMargin: (!task.tasksRoot.vertical && taskList.rows > 1) ? LayoutMetrics.iconMargin : 0
            leftMargin: ((task.inPopup || task.tasksRoot.vertical) && taskList.columns > 1) ? LayoutMetrics.iconMargin : 0
            rightMargin: ((task.inPopup || task.tasksRoot.vertical) && taskList.columns > 1) ? LayoutMetrics.iconMargin : 0
        }

        property bool isHovered: task.highlighted && Plasmoid.configuration.taskHoverEffect
        property string basePrefix: "normal"
        prefix: isHovered ? TaskTools.taskPrefixHovered(basePrefix, Plasmoid.location) : TaskTools.taskPrefix(basePrefix, Plasmoid.location)
    }

    Loader {
        id: taskProgressOverlayLoader

        anchors.fill: frame
        asynchronous: true
        active: task.smartLauncherItem && task.smartLauncherItem.progressVisible

        source: "TaskProgressOverlay.qml"
    }

    Loader {
        id: iconBox

        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenterOffset: _iconBottomOffset
        anchors.bottomMargin: 0

        width: Plasmoid.configuration.iconSize
        height: Plasmoid.configuration.iconSize

        scale: zoomFactor
        transformOrigin: Item.Bottom

        z: highlighted ? 100 : 1

        asynchronous: true
        active: task.smartLauncherItem && task.smartLauncherItem.countVisible
        source: "TaskBadgeOverlay.qml"

        function adjustMargin(isVertical: bool, size: real, margin: real): real {
            if (!size) {
                return margin;
            }

            // LayoutMetrics.horizontalMargins() and verticalMargins() removed (always 0)
            var margins = 0;

            if ((size - margins) < Kirigami.Units.iconSizes.small) {
                return Math.ceil((margin * (Kirigami.Units.iconSizes.small / size)) / 2);
            }

            return margin;
        }

        Kirigami.Icon {
            id: icon
            width: Plasmoid.configuration.iconSize
            height: Plasmoid.configuration.iconSize

            smooth: true
            antialiasing: true
            source: model.decoration

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
        }

        states: [
            // Using a state transition avoids a binding loop between label.visible and
            // the text label margin, which derives from the icon width.
            State {
                name: "standalone"
                when: !label.visible && task.parent

                AnchorChanges {
                    target: iconBox
                    anchors.left: undefined
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                PropertyChanges {
                    target: iconBox
                    anchors.leftMargin: 0
                    width: Math.min(task.parent.minimumWidth, tasks.height)
                    - adjustMargin(true, task.width, frame.margins.left)
                    - adjustMargin(true, task.width, frame.margins.right)
                }
            }
        ]

        // Icon reflection
        Item {
            id: reflectionContainer
            anchors.top: icon.bottom
            anchors.horizontalCenter: icon.horizontalCenter
            anchors.horizontalCenterOffset: _reflectionHorizontalOffset

            width: Plasmoid.configuration.iconSize
            height: Plasmoid.configuration.iconSize / 2
            clip: true
            opacity: 0.5
            z: -1
            visible: Plasmoid.configuration.showReflection

            Kirigami.Icon {
                id: reflectionIcon
                width: Plasmoid.configuration.iconSize
                height: Plasmoid.configuration.iconSize
                source: icon.source
                active: icon.active
                smooth: true

                y: -height
                anchors.horizontalCenter: parent.horizontalCenter

                transform: Scale {
                    yScale: -1
                    origin.y: Plasmoid.configuration.iconSize
                }
            }
        }

        Loader {
            anchors.centerIn: parent
            width: Plasmoid.configuration.iconSize
            height: Plasmoid.configuration.iconSize
            active: model.IsStartup
            sourceComponent: busyIndicator
        }
    }
    PlasmaComponents3.Label {
        id: label

        visible: (task.inPopup || !task.tasksRoot.iconsOnly && !task.model.IsLauncher
            && (parent.width - iconBox.height - Kirigami.Units.smallSpacing) >= LayoutMetrics.spaceRequiredToShowText())

        anchors {
            fill: parent
            leftMargin: frame.margins.left + iconBox.width + LayoutMetrics.labelMargin
            topMargin: frame.margins.top
            rightMargin: frame.margins.right + (task.audioStreamIcon !== null && task.audioStreamIcon.visible ? (task.audioStreamIcon.width + LayoutMetrics.labelMargin) : 0)
            bottomMargin: frame.margins.bottom
        }

        wrapMode: (maximumLineCount === 1) ? Text.NoWrap : Text.Wrap
        elide: Text.ElideRight
        textFormat: Text.PlainText
        verticalAlignment: Text.AlignVCenter
        maximumLineCount: Plasmoid.configuration.maxTextLines || undefined

        // The accessible item of this element is only used for debugging
        // purposes, and it will never gain focus (thus it won't interfere
        // with screenreaders).
        Accessible.ignored: !visible
        Accessible.name: parent.Accessible.name + "-labelhint"

        // use State to avoid unnecessary re-evaluation when the label is invisible
        states: State {
            name: "labelVisible"
            when: label.visible

            PropertyChanges {
                label.text: task.model.display
            }
        }
    }

    states: [
        State {
            name: "launcher"
            when: task.model.IsLauncher

            PropertyChanges {
                frame.basePrefix: ""
            }
        },
        State {
            name: "attention"
            when: task.model.IsDemandingAttention || (task.smartLauncherItem && task.smartLauncherItem.urgent)

            PropertyChanges {
                frame.basePrefix: "attention"
            }
        },
        State {
            name: "minimized"
            when: task.model.IsMinimized

            PropertyChanges {
                frame.basePrefix: "minimized"
            }
        },
        State {
            name: "active"
            when: task.model.IsActive

            PropertyChanges {
                frame.basePrefix: "focus"
            }
        }
    ]

    Component.onCompleted: {
        if (!inPopup && model.IsWindow) {
            const component = Qt.createComponent("GroupExpanderOverlay.qml");
            component.createObject(task);
            component.destroy();
            updateAudioStreams({delay: false});
        }

        if (!inPopup && !model.IsWindow) {
            taskInitComponent.createObject(task);
        }
        completed = true;
    }
    Component.onDestruction: {
        if (_wasZoomed) {
            tasksRoot.zoomedTaskCount -= 1;
        }
    }
}
