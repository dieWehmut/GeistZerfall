#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQmlEngine>
#include <QIcon>
#include "cpp/Manager/MapManager/TileManager.h"
#include "cpp/Entity/LivingEntity/Player.h"
#include "cpp/Manager/SaveLoadManager/SaveLoad.h"
#include "cpp/Manager/EventManager/Transition.h"
#include "cpp/Manager/FileReader.h"
#include "cpp/Entity/LivingEntity/Enemy/concrete/Enemy1.h"
#include "cpp/Entity/LivingEntity/Enemy/concrete/Enemy2.h"
#include "cpp/Entity/Projectile/EnemyProjectile/Enemy1Bullet.h"
#include "cpp/Entity/Projectile/EnemyProjectile/Enemy2Laser.h"
#include "cpp/Entity/Projectile/PlayerBullet.h"
#include "cpp/Entity/Projectile/PlayerLaser.h"

int main(int argc, char *argv[])
{
    qputenv("QT_IM_MODULE", QByteArray("qtvirtualkeyboard"));
    QGuiApplication app(argc, argv);
    app.setWindowIcon(QIcon(":/resource/image/PhantomGenesis.ico"));
    QQmlApplicationEngine engine;
    qmlRegisterType<TileManager>("GeistZerfall.Game", 1, 0, "TileManager");
    qmlRegisterType<Player>("GeistZerfall.Game", 1, 0, "BackendPlayer");
    qmlRegisterType<Enemy1>("GeistZerfall.Game", 1, 0, "BackendEnemy1");
    qmlRegisterType<Enemy2>("GeistZerfall.Game", 1, 0, "BackendEnemy2");
    // Projectiles are created from C++ and only used as QObject backends in QML visuals,
    // but registering them is harmless and can help for debugging.
    qmlRegisterType<Enemy1Bullet>("GeistZerfall.Game", 1, 0, "BackendEnemy1Bullet");
    qmlRegisterType<Enemy2Laser>("GeistZerfall.Game", 1, 0, "BackendEnemy2Laser");
    qmlRegisterType<PlayerBullet>("GeistZerfall.Game", 1, 0, "BackendPlayerBullet");
    qmlRegisterType<PlayerLaser>("GeistZerfall.Game", 1, 0, "BackendPlayerLaser");
    qmlRegisterType<SaveLoad>("GeistZerfall.Game", 1, 0, "SaveLoad");
    qmlRegisterType<Transition>("GeistZerfall.Game", 1, 0, "Transition");
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    // also create an instance and expose as context property so QML can access it during component creation
    SaveLoad *saver = new SaveLoad(&engine);
    engine.rootContext()->setContextProperty("SaveLoadManager", saver);
    Transition *transitionMgr = new Transition(&engine);
    engine.rootContext()->setContextProperty("transitionManager", transitionMgr);
    FileReader *fileReader = new FileReader(&engine);
    engine.rootContext()->setContextProperty("fileReader", fileReader);
    engine.loadFromModule("GeistZerfall", "Main");
    return app.exec();
}
