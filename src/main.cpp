#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQmlEngine>
#include <QIcon>
#include "cpp/Manager/MapManager/TileManager.h"
#include "cpp/Entity/LivingEntity/Player.h"
#include "cpp/Manager/SaveLoadManager/SaveLoad.h"
#include "cpp/Manager/EventManager/Transition.h"
#include "cpp/Manager/EventManager/SeparationManager.h"
#include "cpp/Manager/FileReader.h"
#include "cpp/Entity/LivingEntity/Enemy/concrete/Enemy1.h"
#include "cpp/Entity/LivingEntity/Enemy/concrete/Enemy2.h"
#include "cpp/Entity/LivingEntity/Enemy/concrete/Enemy3.h"
#include "cpp/Entity/LivingEntity/Enemy/concrete/Enemy4.h"
#include "cpp/Entity/LivingEntity/Enemy/concrete/Enemy5.h"
#include "cpp/Entity/LivingEntity/Enemy/concrete/Enemy6.h"
#include "cpp/Entity/LivingEntity/Enemy/concrete/Enemy7.h"
#include "cpp/Entity/Projectile/EnemyProjectile/Enemy1Bullet.h"
#include "cpp/Entity/Projectile/EnemyProjectile/Enemy2Laser.h"
#include "cpp/Entity/Projectile/EnemyProjectile/Enemy3MotherBullet.h"
#include "cpp/Entity/Projectile/EnemyProjectile/Enemy3ChildBullet.h"
#include "cpp/Entity/Projectile/EnemyProjectile/Enemy4Bullet.h"
#include "cpp/Entity/Projectile/EnemyProjectile/Enemy5Bullet.h"
#include "cpp/Entity/Projectile/EnemyProjectile/Enemy6Laser.h"
#include "cpp/Entity/Projectile/EnemyProjectile/Enemy7Bullet.h"
#include "cpp/Entity/Projectile/PlayerBullet.h"
#include "cpp/Entity/Projectile/PlayerLaser.h"
#include "cpp/Entity/Projectile/PlayerWave.h"

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
    qmlRegisterType<Enemy3>("GeistZerfall.Game", 1, 0, "BackendEnemy3");
    qmlRegisterType<Enemy4>("GeistZerfall.Game", 1, 0, "BackendEnemy4");
    qmlRegisterType<Enemy5>("GeistZerfall.Game", 1, 0, "BackendEnemy5");
    qmlRegisterType<Enemy6>("GeistZerfall.Game", 1, 0, "BackendEnemy6");
    qmlRegisterType<Enemy7>("GeistZerfall.Game", 1, 0, "BackendEnemy7");
    qmlRegisterType<Enemy1Bullet>("GeistZerfall.Game", 1, 0, "BackendEnemy1Bullet");
    qmlRegisterType<Enemy2Laser>("GeistZerfall.Game", 1, 0, "BackendEnemy2Laser");
    qmlRegisterType<Enemy3MotherBullet>("GeistZerfall.Game", 1, 0, "BackendEnemy3MotherBullet");
    qmlRegisterType<Enemy3ChildBullet>("GeistZerfall.Game", 1, 0, "BackendEnemy3ChildBullet");
    qmlRegisterType<Enemy4Bullet>("GeistZerfall.Game", 1, 0, "BackendEnemy4Bullet");
    qmlRegisterType<Enemy5Bullet>("GeistZerfall.Game", 1, 0, "BackendEnemy5Bullet");
    qmlRegisterType<Enemy6Laser>("GeistZerfall.Game", 1, 0, "BackendEnemy6Laser");
    qmlRegisterType<Enemy7Bullet>("GeistZerfall.Game", 1, 0, "BackendEnemy7Bullet");
    qmlRegisterType<PlayerBullet>("GeistZerfall.Game", 1, 0, "BackendPlayerBullet");
    qmlRegisterType<PlayerLaser>("GeistZerfall.Game", 1, 0, "BackendPlayerLaser");
    qmlRegisterType<PlayerWave>("GeistZerfall.Game", 1, 0, "BackendPlayerWave");
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
    // expose the global SeparationManager singleton to QML so QML visuals can interact / query if needed
    SeparationManager *sepMgr = SeparationManager::instance();
    engine.rootContext()->setContextProperty("separationManager", sepMgr);
    FileReader *fileReader = new FileReader(&engine);
    engine.rootContext()->setContextProperty("fileReader", fileReader);
    engine.loadFromModule("GeistZerfall", "Main");
    return app.exec();
}
