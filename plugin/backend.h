/*
    SPDX-FileCopyrightText: 2013-2016 Eike Hein <hein@kde.org>

    SPDX-License-Identifier: GPL-2.0-or-later
*/

#pragma once

#include <KConfigWatcher>

#include <QObject>
#include <QRect>

#include <qqmlregistration.h>
#include <qwindowdefs.h>

#include "kactivitymanagerd_plugins_settings.h"

class QAction;
class QActionGroup;
class QQuickItem;
class QQuickWindow;
class QJsonArray;

/**
 * @brief Core backend for PlasmaDock task manager functionality
 * 
 * Provides integration with KDE Plasma's task management system, including:
 * - Jump list actions for applications
 * - Places (bookmarks) integration for file managers
 * - Recent document actions
 * - Application launching and management
 * - Process hierarchy tracking
 * 
 * This class is exposed to QML as TaskManagerApplet.Backend
 */
class Backend : public QObject
{
    Q_OBJECT
    QML_ELEMENT

public:
    /**
     * @brief Middle-click action types
     */
    enum MiddleClickAction {
        None = 0,           ///< No action
        Close,              ///< Close the application
        NewInstance,        ///< Launch a new instance
        ToggleMinimized,    ///< Toggle minimized state
        ToggleGrouping,     ///< Toggle task grouping
        BringToCurrentDesktop ///< Bring window to current desktop
    };

    Q_ENUM(MiddleClickAction)

    /**
     * @brief Construct a new Backend object
     * @param parent Parent QObject
     */
    explicit Backend(QObject *parent = nullptr);
    
    /**
     * @brief Destroy the Backend object
     */
    ~Backend() override;

    /**
     * @brief Get jump list actions for an application
     * @param launcherUrl URL of the launcher (applications:// or file://)
     * @param parent Parent QObject for created actions
     * @return List of QAction objects representing jump list actions
     */
    Q_INVOKABLE QVariantList jumpListActions(const QUrl &launcherUrl, QObject *parent);
    
    /**
     * @brief Get places (bookmarks) actions for a file manager
     * @param launcherUrl URL of the file manager launcher
     * @param showAllPlaces Whether to show all places or limit to recent
     * @param parent Parent QObject for created actions
     * @return List of QAction objects representing places
     */
    Q_INVOKABLE QVariantList placesActions(const QUrl &launcherUrl, bool showAllPlaces, QObject *parent);
    
    /**
     * @brief Get recent document actions for an application
     * @param launcherUrl URL of the launcher
     * @param parent Parent QObject for created actions
     * @return List of QAction objects representing recent documents
     */
    Q_INVOKABLE QVariantList recentDocumentActions(const QUrl &launcherUrl, QObject *parent);
    
    /**
     * @brief Set the action group for menu items
     * @param action Action to set the group on
     */
    Q_INVOKABLE void setActionGroup(QAction *action) const;

    /**
     * @brief Get the global rectangle for a QQuickItem
     * @param item The QQuickItem to get the rectangle for
     * @return QRect in global coordinates
     */
    Q_INVOKABLE QRect globalRect(QQuickItem *item) const;

    /**
     * @brief Check if a URL represents an application
     * @param url URL to check
     * @return true if the URL points to an application desktop file
     */
    Q_INVOKABLE bool isApplication(const QUrl &url) const;

    /**
     * @brief Get the parent process ID
     * @param pid Process ID to query
     * @return Parent PID, or -1 if not found/invalid
     */
    Q_INVOKABLE qint64 parentPid(qint64 pid) const;

    /**
     * @brief Decode an applications:// URL to a file:// URL
     * @param launcherUrl URL to decode
     * @return Decoded URL or original if invalid
     */
    Q_INVOKABLE static QUrl tryDecodeApplicationsUrl(const QUrl &launcherUrl);
    
    /**
     * @brief Get application categories from a desktop file
     * @param launcherUrl URL of the desktop file
     * @return List of category strings
     */
    Q_INVOKABLE static QStringList applicationCategories(const QUrl &launcherUrl);

Q_SIGNALS:
    /**
     * @brief Emitted when a new launcher should be added
     * @param url URL of the launcher to add
     */
    void addLauncher(const QUrl &url) const;

    /**
     * @brief Emitted to request showing all places
     */
    void showAllPlaces();

private Q_SLOTS:
    /**
     * @brief Handle recent document action trigger
     */
    void handleRecentDocumentAction() const;

private:
    /**
     * @brief Get system settings actions
     * @param parent Parent QObject
     * @return List of actions for system settings modules
     */
    QVariantList systemSettingsActions(QObject *parent) const;

    QActionGroup *m_actionGroup = nullptr;

    KActivityManagerdPluginsSettings m_activityManagerPluginsSettings;
    KConfigWatcher::Ptr m_activityManagerPluginsSettingsWatcher;
};
