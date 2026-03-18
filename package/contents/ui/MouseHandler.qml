/*
    SPDX-FileCopyrightText: 2012-2016 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

import QtQuick

import org.kde.taskmanager as TaskManager
import org.kde.plasma.plasmoid

import "code/TaskTools.js" as TaskTools

DropArea {
    id: dropArea
    signal urlsDropped(list<url> urls)

    property Item target
    property Item ignoredItem
    property Item hoveredItem
    property bool isGroupDialog: false
    property bool moved: false
    property Item tasks

    property alias handleWheelEvents: wheelHandler.handleWheelEvents

    onEntered: event => {
        if (event.formats.indexOf("text/x-plasmoidservicename") >= 0) {
            event.accepted = false;
        }
        if (target.animating) {
            target.animating = false;
        }
    }

    onPositionChanged: event => {
        if (target.animating) {
            return;
        }

        let above;
        if (isGroupDialog) {
            above = target.itemAt(event.x, event.y);
        } else {
            above = target.childAt(event.x, event.y);
        }

        if (!above) {
            hoveredItem = null;
            activationTimer.stop();
            return;
        }

        // If we're mixing launcher tasks with other tasks and are moving
        // a (small) launcher task across a non-launcher task, don't allow
        // the latter to be the move target twice in a row for a while.
        if (!Plasmoid.configuration.separateLaunchers
                && tasks.dragSource?.model.IsLauncher
                && !above.model.IsLauncher
                && above === ignoredItem) {
            return;
        } else {
            ignoredItem = null;
        }

        if (tasks.tasksModel?.sortMode === TaskManager.TasksModel.SortManual && tasks.dragSource) {
            // Reject drags between different TaskList instances.
            if (tasks.dragSource.parent !== above.parent) {
                return;
            }

            const insertAt = above.index;

            if (tasks.dragSource !== above && tasks.dragSource.index !== insertAt) {
                if (tasks.groupDialog) {
                    tasks.tasksModel.move(tasks.dragSource.index, insertAt,
                        tasks.tasksModel.makeModelIndex(tasks.groupDialog.visualParent.index));
                } else {
                    tasks.tasksModel.move(tasks.dragSource.index, insertAt);
                }

                ignoredItem = above;
                ignoreItemTimer.restart();
            }
        } else if (!tasks.dragSource && hoveredItem !== above) {
            hoveredItem = above;
            activationTimer.restart();
        }
    }

    onDropped: event => {
        // Accept internal drops - reordering happens in onPositionChanged
        if (event.formats.indexOf("application/x-orgkdeplasmataskmanager_taskbuttonitem") >= 0) {
            event.accepted = true;
            return;
        }

        // Reject plasmoid drops.
        if (event.formats.indexOf("text/x-plasmoidservicename") >= 0) {
            event.accepted = false;
            return;
        }

        if (event.hasUrls) {
            urlsDropped(event.urls);
            return;
        }
    }

    Connections {
        target: tasks

        function onDragSourceChanged(): void {
            if (!tasks.dragSource) {
                dropArea.ignoredItem = null;
                ignoreItemTimer.stop();
            }
        }
    }

    Timer {
        id: ignoreItemTimer

        repeat: false
        interval: 750

        onTriggered: {
            dropArea.ignoredItem = null;
        }
    }

    Timer {
        id: activationTimer

        interval: 250
        repeat: false

        onTriggered: {
            if (parent.hoveredItem.model.IsGroupParent) {
                TaskTools.createGroupDialog(parent.hoveredItem, tasks);
            } else if (!parent.hoveredItem.model.IsLauncher) {
                tasks.tasksModel.requestActivate(parent.hoveredItem.modelIndex());
            }
        }
    }

    WheelHandler {
        id: wheelHandler

        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

        property bool handleWheelEvents: true

        enabled: handleWheelEvents && Plasmoid.configuration.wheelEnabled !== 0

        onWheel: event => {
            let increment = 0;
            while (rotation >= 15) {
                rotation -= 15;
                increment++;
            }
            while (rotation <= -15) {
                rotation += 15;
                increment--;
            }
            const anchor = dropArea.target.childAt(event.x, event.y);
            if (Plasmoid.configuration.wheelEnabled === 3) {
                const loudest = anchor?.audioStreams?.reduce((loudest, stream) => Math.max(loudest, stream.volume), 0)
                const step = (pulseAudio.item.normalVolume - pulseAudio.item.minimalVolume) * pulseAudio.item.globalConfig.volumeStep / 100;
                anchor?.audioStreams?.forEach((stream) => {
                    let delta = step * increment;
                    if (loudest > 0) {
                        delta *= stream.volume / loudest;
                    }
                    const volume = stream.volume + delta;
                    stream.model.Volume = Math.max(pulseAudio.item.minimalVolume, Math.min(volume, pulseAudio.item.normalVolume));
                    stream.model.Muted = volume === 0
                })
            return;
            }
            while (increment !== 0) {
                TaskTools.activateNextPrevTask(anchor, increment < 0, Plasmoid.configuration.wheelSkipMinimized, Plasmoid.configuration.wheelEnabled, tasks);
                increment += (increment < 0) ? 1 : -1;
            }
        }
    }
}
