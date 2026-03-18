# -------------------------------------------------
# 1. ECM and Configuration
# -------------------------------------------------
find_package(ECM REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})
include(ECMQtDeclareLoggingCategory)
include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)

find_package(Qt6 REQUIRED COMPONENTS Core DBus Qml Quick Widgets)

find_package(KF6 REQUIRED COMPONENTS
    CoreAddons
    I18n
    Service
    WindowSystem
    Config
    Notifications
    KIO
)

# Workspace libs
find_package(Plasma REQUIRED)
find_package(PlasmaActivities REQUIRED)
find_package(PlasmaActivitiesStats REQUIRED)
find_package(LibTaskManager REQUIRED)
find_package(LibNotificationManager REQUIRED)
find_package(KSysGuard REQUIRED)

# -------------------------------------------------
# 2. Sources
# -------------------------------------------------
set(plasmadock_source
    plugin.cpp
    backend.cpp
    backend.h
    smartlauncherbackend.cpp
    smartlauncherbackend.h
    smartlauncheritem.cpp
    smartlauncheritem.h
)

ecm_qt_declare_logging_category(plasmadock_LOG_SRCS
    HEADER log_settings.h
    IDENTIFIER PLASMADOCK_DEBUG
    CATEGORY_NAME org.plasmadock
    DESCRIPTION "PlasmaDock plugin"
)

# -------------------------------------------------
# 3. QML Module
# -------------------------------------------------
qt_policy(SET QTP0001 NEW)

# -------------------------------------------------
# 4. KConfig generated files
# -------------------------------------------------
kconfig_add_kcfg_files(plasmadock_source
    kactivitymanagerd_plugins_settings.kcfgc
)

add_library(plasmadock SHARED ${plasmadock_source} ${plasmadock_LOG_SRCS})
set_target_properties(plasmadock PROPERTIES
    AUTOMOC ON
    AUTOUIC ON
    AUTORCC ON
)

qt_add_qml_module(plasmadock
    URI org.plasmadock
    VERSION 1.0
)

# -------------------------------------------------
# 5. Properties and Linking
# -------------------------------------------------
set_target_properties(plasmadock PROPERTIES
    OUTPUT_NAME "plasmadockplugin"
)

target_include_directories(plasmadock PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_BINARY_DIR}
)

target_link_libraries(plasmadock
    PRIVATE
        Qt6::Core Qt6::DBus Qt6::Qml Qt6::Quick Qt6::Widgets
        KF6::CoreAddons KF6::I18n KF6::Service KF6::WindowSystem
        KF6::ConfigCore
        KF6::ConfigGui
        KF6::Notifications
        KF6::KIOCore KF6::KIOGui KF6::KIOFileWidgets
        Plasma::Plasma Plasma::Activities Plasma::ActivitiesStats
        PW::LibTaskManager PW::LibNotificationManager
        KSysGuard::ProcessCore
)

# -------------------------------------------------
# 6. Installation
# -------------------------------------------------
install(TARGETS plasmadock DESTINATION ${KDE_INSTALL_QMLDIR}/org/plasmadock)
install(FILES
    ${CMAKE_CURRENT_BINARY_DIR}/qmldir
    ${CMAKE_CURRENT_BINARY_DIR}/plasmadock.qmltypes
    DESTINATION ${KDE_INSTALL_QMLDIR}/org/plasmadock
)
