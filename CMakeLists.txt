cmake_minimum_required(VERSION 3.16)

project(GeistZerfall VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick Multimedia Core Qml)

qt_standard_project_setup(REQUIRES 6.8)

qt_add_resources(RESOURCES src/resource.qrc)

qt_add_executable(GeistZerfall
    src/main.cpp
    ${RESOURCES}
)

qt_add_qml_module(GeistZerfall
    URI GeistZerfall
    VERSION 1.0
    QML_FILES
        src/Main.qml
        src/qml/window/Config.qml
        src/qml/window/Extra.qml
        src/qml/window/GameView.qml
        src/qml/window/MainMenu.qml
        src/qml/window/SaveLoad.qml
    SOURCES
        src/cpp/Entity/Entity.cpp src/cpp/Entity/Entity.h
        src/cpp/Entity/LivingEntity/Player.cpp src/cpp/Entity/LivingEntity/Player.h
        src/cpp/Manager/MapManager/TileManager.cpp src/cpp/Manager/MapManager/TileManager.h
        QML_FILES src/qml/Map/Tile.qml
        QML_FILES src/qml/Entity/Player.qml
        QML_FILES src/qml/window/windowState.js
        SOURCES src/cpp/Manager/SaveLoadManager/SaveData.cpp src/cpp/Manager/SaveLoadManager/SaveData.h src/cpp/Manager/SaveLoadManager/SaveLoad.cpp src/cpp/Manager/SaveLoadManager/SaveLoad.h
        QML_FILES
        QML_FILES src/qml/window/Splash.qml
        QML_FILES src/qml/Entity/PlayerBullet.qml src/qml/Entity/PlayerLaser.qml
        SOURCES src/cpp/Entity/Projectile/PlayerBullet.cpp src/cpp/Entity/Projectile/PlayerBullet.h src/cpp/Entity/Projectile/PlayerLaser.cpp src/cpp/Entity/Projectile/PlayerLaser.h src/cpp/Entity/Projectile/Projectile.cpp src/cpp/Entity/Projectile/Projectile.h






)

set_target_properties(GeistZerfall PROPERTIES
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(GeistZerfall
    PRIVATE Qt6::Quick
    Qt6::Multimedia
    Qt6::Core
    Qt6::Qml
)

include(GNUInstallDirs)
install(TARGETS GeistZerfall
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
