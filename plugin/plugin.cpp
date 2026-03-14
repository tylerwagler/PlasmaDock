/*
    SPDX-FileCopyrightText: 2024-2026 Victor Calles <victor.calles@gmail.com>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

#include <QtQml/QQmlExtensionPlugin>

class org_vicko_wavetaskPlugin : public QQmlExtensionPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID "org.qt-project.Qt.QQmlExtensionInterface")

public:
    void registerTypes(const char * /*uri*/) override
    {
        // Qt6 handles automatic registration of Backend and Item
        // based on the generated .qmltypes file.
    }
};

#include "plugin.moc"
