/*
    SPDX-FileCopyrightText: 2013 Sebastian Kügler <sebas@kde.org>
    SPDX-FileCopyrightText: 2014 Martin Gräßlin <mgraesslin@kde.org>
    SPDX-FileCopyrightText: 2016 Kai Uwe Broulik <kde@privat.broulik.de>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

pragma ComponentBehavior: Bound

import QtQuick

MouseArea {
    required property var modelIndex // QModelIndex from C++
    required property var winId // WId (int|string) or undefined
    required property Task rootTask

    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
    hoverEnabled: true
    enabled: winId !== undefined

    onClicked: (mouse) => {
        switch (mouse.button) {
        case Qt.LeftButton:
            rootTask.tasksRoot.tasksModel.requestActivate(modelIndex);
            rootTask.hideImmediately();
            rootTask.tasksRoot.cancelHighlightWindows();
            break;
        case Qt.MiddleButton:
            rootTask.tasksRoot.cancelHighlightWindows();
            rootTask.tasksRoot.tasksModel.requestClose(modelIndex);
            break;
        case Qt.RightButton:
            rootTask.tasksRoot.createContextMenu(rootTask, modelIndex).show();
            break;
        }
    }

    onContainsMouseChanged: {
        rootTask.tasksRoot.windowsHovered([String(winId)], containsMouse);
    }
}
