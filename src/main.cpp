#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QIcon>
#include "cpp/Manager/MapManager/TileManager.h"
#include "cpp/Entity/LivingEntity/Player.h"
#include "cpp/Manager/SaveLoadManager/SaveLoad.h"
#include <QtQml/qqml.h>

int main(int argc, char *argv[])
{
    qputenv("QT_IM_MODULE", QByteArray("qtvirtualkeyboard"));
    QGuiApplication app(argc, argv);
    app.setWindowIcon(QIcon(":/resource/image/PhantomGenesis.ico"));
    QQmlApplicationEngine engine;
    qmlRegisterType<TileManager>("GeistZerfall.Game", 1, 0, "TileManager");
    qmlRegisterType<Player>("GeistZerfall.Game", 1, 0, "BackendPlayer");
    qmlRegisterType<SaveLoad>("GeistZerfall.Game", 1, 0, "SaveLoad");
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    // also create an instance and expose as context property so QML can access it during component creation
    SaveLoad *saver = new SaveLoad(&engine);
    engine.rootContext()->setContextProperty("SaveLoadManager", saver);
    engine.loadFromModule("GeistZerfall", "Main");
    return app.exec();
}
