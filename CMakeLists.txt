cmake_minimum_required(VERSION 3.16)

project(GeistZerfall VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick Multimedia Core Qml)

qt_standard_project_setup(REQUIRES 6.8)

file(GLOB QRC_FILES RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} "src/resources_qrc/*.qrc")
qt_add_resources(RESOURCES ${QRC_FILES})

qt_add_executable(GeistZerfall
    src/main.cpp
    ${RESOURCES}
        src/cpp/Entity/LivingEntity/Enemy/concrete/Enemy5.cpp
        src/cpp/Entity/LivingEntity/Enemy/concrete/Enemy5.h
        src/cpp/Entity/Projectile/EnemyProjectile/Enemy5Bullet.cpp
        src/cpp/Entity/Projectile/EnemyProjectile/Enemy5Bullet.h
        src/cpp/Entity/LivingEntity/Enemy/concrete/Enemy4.cpp
        src/cpp/Entity/LivingEntity/Enemy/concrete/Enemy4.h
        src/cpp/Entity/LivingEntity/Enemy/concrete/Enemy6.cpp
        src/cpp/Entity/LivingEntity/Enemy/concrete/Enemy6.h
        src/cpp/Entity/LivingEntity/Enemy/concrete/Enemy7.cpp
        src/cpp/Entity/LivingEntity/Enemy/concrete/Enemy7.h
        src/cpp/Entity/Projectile/EnemyProjectile/Enemy4Bullet.cpp
        src/cpp/Entity/Projectile/EnemyProjectile/Enemy4Bullet.h
        src/cpp/Entity/Projectile/EnemyProjectile/Enemy6Laser.cpp
        src/cpp/Entity/Projectile/EnemyProjectile/Enemy6Laser.h
        src/cpp/Entity/Projectile/EnemyProjectile/Enemy7Bullet.cpp
        src/cpp/Entity/Projectile/EnemyProjectile/Enemy7Bullet.h
)

qt_add_qml_module(GeistZerfall
    URI GeistZerfall
    VERSION 1.0
    QML_FILES
        src/Main.qml
        src/qml/components/AppButton.qml
        src/qml/components/BottomButtonBar.qml
        src/qml/components/ConfirmDialog.qml
        src/qml/window/Config.qml
        src/qml/window/Extra.qml
        src/qml/window/MainMenu.qml
        src/qml/window/SaveLoad.qml
        src/qml/window/Splash.qml
        src/qml/window/windowState.js
        src/qml/window/Game/GameView.qml
        
        src/qml/window/Game/Map/Tile.qml
        
        src/qml/window/Game/Entity/Player.qml
        src/qml/window/Game/Entity/PlayerBullet.qml
        src/qml/window/Game/Entity/PlayerLaser.qml
        src/qml/window/Game/Entity/PlayerWave.qml
        src/qml/window/Game/Entity/TeleportCircle.qml
        src/qml/window/Game/Entity/TeleportOverlay.qml
        src/qml/window/Game/Entity/Enemy/Enemy1.qml
        src/qml/window/Game/Entity/Enemy/Enemy2.qml
        src/qml/window/Game/Entity/Enemy/Enemy3.qml
        src/qml/window/Game/Entity/Enemy/Enemy4.qml
        src/qml/window/Game/Entity/Enemy/Enemy5.qml
        src/qml/window/Game/Entity/Enemy/Enemy6.qml
        src/qml/window/Game/Entity/Enemy/Enemy7.qml
        src/qml/window/Game/Entity/Enemy/Enemy1Bullet.qml
        src/qml/window/Game/Entity/Enemy/Enemy2Laser.qml
        src/qml/window/Game/Entity/Enemy/Enemy3ChildBullet.qml
        src/qml/window/Game/Entity/Enemy/Enemy3MontherBullet.qml
        src/qml/window/Game/Entity/Enemy/Enemy4Bullet.qml
        src/qml/window/Game/Entity/Enemy/Enemy5Bullet.qml
        src/qml/window/Game/Entity/Enemy/Enemy6Laser.qml
        src/qml/window/Game/Entity/Enemy/Enemy7Bullet.qml
        src/qml/window/Lore/loreState.js
        src/qml/window/Lore/LoreView.qml
        src/qml/window/Lore/contentShow/Animation.qml
        src/qml/window/Lore/contentShow/ContentImage.qml
        src/qml/window/Lore/contentShow/ContentText.qml
        src/qml/window/Lore/components/ChoiceDialog.qml
        src/qml/window/Lore/components/ContentLoader.qml
        src/qml/window/Lore/components/DynamicCircle.qml
        src/qml/window/Lore/components/VisualScene.qml
        src/qml/window/Lore/components/HistoryPanel.qml
        src/qml/window/Lore/components/LoreControlBar.qml
        src/qml/window/Lore/components/ConfigSlider.qml
        src/qml/window/Lore/components/LoreControlButton.qml
        src/qml/window/Lore/components/characterImageMap.js
        src/qml/window/Lore/effects/AudioEffect.qml
        src/qml/window/Lore/effects/ParticleEffect.qml
    SOURCES
        src/cpp/Entity/Entity.cpp
        src/cpp/Entity/Entity.h
        src/cpp/Entity/LivingEntity/Player.cpp
        src/cpp/Entity/LivingEntity/Player.h
        src/cpp/Entity/LivingEntity/Enemy/Enemy.cpp
        src/cpp/Entity/LivingEntity/Enemy/Enemy.h
        src/cpp/Entity/LivingEntity/Enemy/concrete/Enemy1.cpp
        src/cpp/Entity/LivingEntity/Enemy/concrete/Enemy1.h
        src/cpp/Entity/LivingEntity/Enemy/concrete/Enemy2.cpp
        src/cpp/Entity/LivingEntity/Enemy/concrete/Enemy2.h
        src/cpp/Entity/LivingEntity/Enemy/concrete/Enemy3.cpp
        src/cpp/Entity/LivingEntity/Enemy/concrete/Enemy3.h
        src/cpp/Entity/LivingEntity/Enemy/concrete/Enemy4.cpp
        src/cpp/Entity/LivingEntity/Enemy/concrete/Enemy4.h
        src/cpp/Entity/LivingEntity/Enemy/concrete/Enemy5.cpp
        src/cpp/Entity/LivingEntity/Enemy/concrete/Enemy5.h
        src/cpp/Entity/LivingEntity/Enemy/concrete/Enemy6.cpp
        src/cpp/Entity/LivingEntity/Enemy/concrete/Enemy6.h
        src/cpp/Entity/LivingEntity/Enemy/concrete/Enemy7.cpp
        src/cpp/Entity/LivingEntity/Enemy/concrete/Enemy7.h
        src/cpp/Entity/Projectile/PlayerBullet.cpp
        src/cpp/Entity/Projectile/PlayerBullet.h
        src/cpp/Entity/Projectile/PlayerLaser.cpp
        src/cpp/Entity/Projectile/PlayerLaser.h
        src/cpp/Entity/Projectile/PlayerWave.cpp
        src/cpp/Entity/Projectile/PlayerWave.h
        src/cpp/Entity/Projectile/Projectile.cpp
        src/cpp/Entity/Projectile/Projectile.h
        src/cpp/Entity/Projectile/EnemyProjectile/Enemy1Bullet.cpp
        src/cpp/Entity/Projectile/EnemyProjectile/Enemy1Bullet.h
        src/cpp/Entity/Projectile/EnemyProjectile/Enemy2Laser.cpp
        src/cpp/Entity/Projectile/EnemyProjectile/Enemy2Laser.h
        src/cpp/Entity/Projectile/EnemyProjectile/Enemy3MotherBullet.cpp
        src/cpp/Entity/Projectile/EnemyProjectile/Enemy3MotherBullet.h
        src/cpp/Entity/Projectile/EnemyProjectile/Enemy3ChildBullet.cpp
        src/cpp/Entity/Projectile/EnemyProjectile/Enemy3ChildBullet.h
        src/cpp/Entity/Projectile/EnemyProjectile/Enemy4Bullet.cpp
        src/cpp/Entity/Projectile/EnemyProjectile/Enemy4Bullet.h
        src/cpp/Entity/Projectile/EnemyProjectile/Enemy5Bullet.cpp
        src/cpp/Entity/Projectile/EnemyProjectile/Enemy5Bullet.h
        src/cpp/Entity/Projectile/EnemyProjectile/Enemy6Laser.cpp
        src/cpp/Entity/Projectile/EnemyProjectile/Enemy6Laser.h
        src/cpp/Entity/Projectile/EnemyProjectile/Enemy7Bullet.cpp
        src/cpp/Entity/Projectile/EnemyProjectile/Enemy7Bullet.h
        src/cpp/Manager/MapManager/TileManager.cpp
        src/cpp/Manager/MapManager/TileManager.h
        src/cpp/Manager/SaveLoadManager/SaveData.cpp
        src/cpp/Manager/SaveLoadManager/SaveData.h
        src/cpp/Manager/SaveLoadManager/SaveLoad.cpp
        src/cpp/Manager/SaveLoadManager/SaveLoad.h
        src/cpp/Manager/EventManager/Transition.cpp
        src/cpp/Manager/EventManager/Transition.h
        src/cpp/Manager/EventManager/SeparationManager.cpp
        src/cpp/Manager/EventManager/SeparationManager.h
        src/cpp/Manager/FileReader.cpp
        src/cpp/Manager/FileReader.h
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

target_include_directories(GeistZerfall PRIVATE src/cpp)

include(GNUInstallDirs)
install(TARGETS GeistZerfall
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
