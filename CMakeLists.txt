
cmake_minimum_required(VERSION 3.27)

project(plasmadock)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(QT_MIN_VERSION "6.4.0")
set(KF6_MIN_VERSION "6.0.0")

find_package(ECM ${KF6_MIN_VERSION} REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

find_package(Qt6 ${QT_MIN_VERSION} REQUIRED COMPONENTS Core DBus Qml Widgets)
find_package(KF6 ${KF6_MIN_VERSION} REQUIRED COMPONENTS I18n Service WindowSystem)
find_package(Plasma ${KF6_MIN_VERSION} REQUIRED)
find_package(PlasmaActivities ${KF6_MIN_VERSION} REQUIRED)

add_subdirectory(plugin)
plasma_install_package(package org.plasmadock)
install(DIRECTORY layout-templates/
        DESTINATION ${KDE_INSTALL_DATADIR}/plasma/layout-templates/org.plasmadock.panel
)

# Add tests (only when building from source, not during installation)
option(BUILD_TESTING "Build unit tests" OFF)
if(BUILD_TESTING)
    message(STATUS "Building tests")
    add_subdirectory(tests)
endif()

