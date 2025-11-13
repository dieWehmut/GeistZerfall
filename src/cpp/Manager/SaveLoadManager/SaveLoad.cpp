#include "SaveLoad.h"
#include <QDir>
#include <QFile>
#include <QDataStream>
#include <QCoreApplication>
#include <QStandardPaths>
#include <QDebug>
#include <QFileSystemWatcher>
#include <QImage>
#include <QBuffer>
#include <QGuiApplication>
#include <QScreen>
#include <QQuickWindow>
#include <QPainter>
#include <QUrl>
#include <QFileInfo>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QCoreApplication>
#include <QVariant>

SaveLoad::SaveLoad(QObject *parent) : QObject(parent) {
    // initialize autoExists based on the current file
    QString dirPath = QDir::cleanPath(QCoreApplication::applicationDirPath() + "/" + QString("save"));
    QString filePath = dirPath + "/auto.dat";
    QFile f(filePath);
    m_autoExists = f.exists();
    // setup filesystem watcher to react to external file changes
    m_watcher = new QFileSystemWatcher(this);
    // watch the directory; we'll monitor the specific file path if it exists
    QDir dir(dirPath);
    if (dir.exists()) {
        m_watcher->addPath(dirPath);
    }
    // also add file if exists
    if (f.exists()) {
        m_watcher->addPath(filePath);
    }
    connect(m_watcher, &QFileSystemWatcher::fileChanged, this, [this](const QString &path){
        Q_UNUSED(path)
        // recompute existence
        bool prev = m_autoExists;
        QString dirPathLocal = QDir::cleanPath(QCoreApplication::applicationDirPath() + "/" + QString("save"));
        QString filePathLocal = dirPathLocal + "/auto.dat";
        QFile ff(filePathLocal);
        m_autoExists = ff.exists();
        if (m_autoExists != prev) emit autoExistsChanged();
    });
    connect(m_watcher, &QFileSystemWatcher::directoryChanged, this, [this](const QString &path){
        Q_UNUSED(path)
        bool prev = m_autoExists;
        QString dirPathLocal = QDir::cleanPath(QCoreApplication::applicationDirPath() + "/" + QString("save"));
        QString filePathLocal = dirPathLocal + "/auto.dat";
        QFile ff(filePathLocal);
        m_autoExists = ff.exists();
        if (m_autoExists != prev) emit autoExistsChanged();
    });
}

bool SaveLoad::saveAuto(const QString &folderPath) {
    // For backward compatibility this still saves the same auto.dat but using the new top-level format.
    return savePlayer(folderPath);
}

bool SaveLoad::loadAuto(const QString &folderPath) {
    return loadPlayer(folderPath);
}

bool SaveLoad::savePlayer(const QString &folderPath) {
    QString dirPath = QDir::cleanPath(QCoreApplication::applicationDirPath() + "/" + folderPath);
    QDir dir;
    if (!dir.exists(dirPath)) {
        if (!dir.mkpath(dirPath)) {
            qWarning() << "SaveLoad: failed to create save dir" << dirPath;
            return false;
        }
    }
    QString filePath = dirPath + "/auto.dat"; // currently using auto.dat for player auto-save
    QFile f(filePath);
    if (!f.open(QIODevice::WriteOnly)) {
        qWarning() << "SaveLoad: cannot open file for write:" << filePath;
        return false;
    }
    QDataStream out(&f);
    out.setVersion(QDataStream::Qt_5_15);
    last.write(out);
    f.close();
    emit saved();
    // update internal state and notify only if changed
    bool prev = m_autoExists;
    m_autoExists = true;
    if (m_autoExists != prev) emit autoExistsChanged();
    // ensure watcher tracks the file path now that it exists
    if (m_watcher) {
        if (!m_watcher->files().contains(filePath)) m_watcher->addPath(filePath);
        if (!m_watcher->directories().contains(dirPath)) m_watcher->addPath(dirPath);
    }
    return true;
}

static QString slotDatPath(const QString &folderPath, int slot) {
    // Map UI slot index (0..7) to human-friendly filenames save1..save8 (previously slotN)
    int human = slot + 1;
    QString dirPath = QDir::cleanPath(QCoreApplication::applicationDirPath() + "/" + folderPath);
    return dirPath + QString("/save%1.dat").arg(human);
}

static QString slotPngPath(const QString &folderPath, int slot) {
    int human = slot + 1;
    QString dirPath = QDir::cleanPath(QCoreApplication::applicationDirPath() + "/" + folderPath);
    return dirPath + QString("/save%1.png").arg(human);
}

bool SaveLoad::saveSlot(int slot, const QString &folderPath) {
    if (slot < 0 || slot > 7) return false;
    QString dirPath = QDir::cleanPath(QCoreApplication::applicationDirPath() + "/" + folderPath);
    QDir dir;
    if (!dir.exists(dirPath)) {
        if (!dir.mkpath(dirPath)) {
            qWarning() << "SaveLoad: failed to create save dir" << dirPath;
            return false;
        }
    }
    QString filePath = slotDatPath(folderPath, slot);
    QFile f(filePath);
    if (!f.open(QIODevice::WriteOnly)) {
        qWarning() << "SaveLoad: cannot open slot file for write:" << filePath;
        return false;
    }
    QDataStream out(&f);
    out.setVersion(QDataStream::Qt_5_15);
    last.write(out);
    f.close();

    qDebug() << "SaveLoad: saved slot" << slot << "to" << filePath << "pos=" << last.player.pos << "speed=" << last.player.speed << "sight=" << last.player.sight;

    // try to capture a screenshot of the main window if available
    // If a temporary preview exists (temp.png), use it and overwrite slot preview; otherwise fall back to grabbing window
    QString tempPng = QDir::cleanPath(QCoreApplication::applicationDirPath() + "/" + folderPath + "/temp.png");
    QString slotPng = slotPngPath(folderPath, slot);
    QFileInfo tempInfo(tempPng);
    if (tempInfo.exists() && tempInfo.isFile()) {
        // copy temp.png -> saveN.png (overwrite)
        if (!QFile::remove(slotPng)) {
            // ignore remove failure; we'll attempt copy anyway
        }
        if (!QFile::copy(tempPng, slotPng)) {
            qWarning() << "SaveLoad: failed to copy temp.png to slot preview" << slotPng;
        }
        // Also update the auto.dat so existing auto-load code will pick up this save's data
        bool savedAuto = savePlayer(folderPath);
        if (savedAuto) qDebug() << "SaveLoad: updated auto.dat from save" << slot << "(used temp.png)";
    } else {
        QQuickWindow *win = nullptr;
        for (QWindow *w : QGuiApplication::allWindows()) {
            QQuickWindow *qw = qobject_cast<QQuickWindow*>(w);
            if (qw) { win = qw; break; }
        }
        if (win) {
            QImage img = win->grabWindow();
            if (!img.isNull()) {
                if (!img.save(slotPng)) {
                    qWarning() << "SaveLoad: failed to save slot preview" << slotPng;
                }
            }
            // Also update the auto.dat so existing auto-load code will pick up this save's data
            bool savedAuto = savePlayer(folderPath);
            if (savedAuto) qDebug() << "SaveLoad: updated auto.dat from save" << slot;
        }
    }

    emit saved();
    return true;
}

bool SaveLoad::captureTemp(const QString &folderPath) {
    QString dirPath = QDir::cleanPath(QCoreApplication::applicationDirPath() + "/" + folderPath);
    QDir dir;
    if (!dir.exists(dirPath)) {
        if (!dir.mkpath(dirPath)) {
            qWarning() << "SaveLoad: failed to create save dir for temp" << dirPath;
            return false;
        }
    }
    QString tempPng = dirPath + "/temp.png";
    QQuickWindow *win = nullptr;
    for (QWindow *w : QGuiApplication::allWindows()) {
        QQuickWindow *qw = qobject_cast<QQuickWindow*>(w);
        if (qw) { win = qw; break; }
    }
    if (!win) {
        qWarning() << "SaveLoad: no QQuickWindow found to capture temp";
        return false;
    }
    QImage img = win->grabWindow();
    if (img.isNull()) {
        qWarning() << "SaveLoad: grabbed image is null";
        return false;
    }
    if (!img.save(tempPng)) {
        qWarning() << "SaveLoad: failed to save temp preview" << tempPng;
        return false;
    }
    qDebug() << "SaveLoad: captured temp preview" << tempPng;
    return true;
}

void SaveLoad::setEnemies(const QVariantList &list) {
    last.enemies.clear();
    for (const QVariant &v : list) {
        if (!v.canConvert<QVariantMap>()) continue;
        QVariantMap m = v.toMap();
        SaveData::EnemySaveData e;
        e.type = m.value("type").toString();
        e.pos.setX(m.value("x").toDouble());
        e.pos.setY(m.value("y").toDouble());
        e.hp = m.value("hp").toInt();
        e.maxHp = m.value("maxHp").toInt();
        e.mp = m.value("mp").toInt();
        e.maxMp = m.value("maxMp").toInt();
    // QVariant::toBool() does not accept a default parameter. Use QVariantMap::value(key, default)
    // so missing keys default to true.
    e.alive = m.value("alive", true).toBool();
        last.enemies.append(e);
    }
}

QVariantList SaveLoad::enemiesAsVariantList() const {
    QVariantList out;
    for (const SaveData::EnemySaveData &e : last.enemies) {
        QVariantMap m;
        m["type"] = e.type;
        m["x"] = e.pos.x();
        m["y"] = e.pos.y();
        m["hp"] = e.hp;
        m["maxHp"] = e.maxHp;
        m["mp"] = e.mp;
        m["maxMp"] = e.maxMp;
        m["alive"] = e.alive;
        out.append(m);
    }
    return out;
}

bool SaveLoad::loadSlot(int slot, const QString &folderPath) {
    if (slot < 0 || slot > 7) return false;
    QString filePath = slotDatPath(folderPath, slot);
    QFile f(filePath);
    if (!f.exists()) {
        qDebug() << "SaveLoad: slot file not found" << filePath;
        return false;
    }
    if (!f.open(QIODevice::ReadOnly)) {
        qWarning() << "SaveLoad: cannot open slot file for read:" << filePath;
        return false;
    }
    QDataStream in(&f);
    in.setVersion(QDataStream::Qt_5_15);
    bool ok = last.read(in);
    f.close();
    if (ok) {
        // update properties so QML bindings can read them
        qDebug() << "SaveLoad: loaded slot" << slot << "from" << filePath << "pos=" << last.player.pos << "speed=" << last.player.speed << "sight=" << last.player.sight;
        // emit signals so QML properties update
        emit posXChanged();
        emit posYChanged();
        emit speedChanged();
        emit sightChanged();
        emit hpChanged();
        emit maxHpChanged();
        emit mpChanged();
        emit maxMpChanged();
        emit viewChanged();
        emit loreChapterChanged();
        emit loreNodeChanged();
        emit loreIndexChanged();
        emit loreMusicChanged();
        emit loreMusicLoopsChanged();
        emit loreMusicStoppedChanged();
        emit battleIdChanged();
        emit loaded();
    }
    return ok;
}

bool SaveLoad::hasSlot(int slot, const QString &folderPath) {
    if (slot < 0 || slot > 7) return false;
    QString filePath = slotDatPath(folderPath, slot);
    QFile f(filePath);
    return f.exists();
}

QString SaveLoad::slotPreviewUrl(int slot, const QString &folderPath) {
    QString pngPath = slotPngPath(folderPath, slot);
    QFile f(pngPath);
    if (!f.exists()) return QString();
    // return file:// URL for QML Image
    return QUrl::fromLocalFile(pngPath).toString();
}

QString SaveLoad::savePreviewUrl(int slot, const QString &folderPath) {
    // compatibility wrapper for the new naming
    return slotPreviewUrl(slot, folderPath);
}

bool SaveLoad::loadPlayer(const QString &folderPath) {
    QString dirPath = QDir::cleanPath(QCoreApplication::applicationDirPath() + "/" + folderPath);
    QString filePath = dirPath + "/auto.dat";
    QFile f(filePath);
    if (!f.exists()) {
        qDebug() << "SaveLoad: auto file not found" << filePath;
        return false;
    }
    if (!f.open(QIODevice::ReadOnly)) {
        qWarning() << "SaveLoad: cannot open file for read:" << filePath;
        return false;
    }
    QDataStream in(&f);
    in.setVersion(QDataStream::Qt_5_15);
    bool ok = last.read(in);
    f.close();
    if (ok) {
        emit posXChanged();
        emit posYChanged();
        emit speedChanged();
        emit sightChanged();
        emit hpChanged();
        emit maxHpChanged();
        emit mpChanged();
        emit maxMpChanged();
        emit viewChanged();
        emit loreChapterChanged();
        emit loreNodeChanged();
        emit loreIndexChanged();
        emit loreMusicChanged();
        emit loreMusicLoopsChanged();
        emit loreMusicStoppedChanged();
        emit battleIdChanged();
        emit loaded();
    }
    return ok;
}

bool SaveLoad::hasAuto(const QString &folderPath) {
    QString dirPath = QDir::cleanPath(QCoreApplication::applicationDirPath() + "/" + folderPath);
    QString filePath = dirPath + "/auto.dat";
    QFile f(filePath);
    return f.exists();
}

bool SaveLoad::autoExists() const {
    return m_autoExists;
}

bool SaveLoad::hasAnySave(const QString &folderPath) {
    if (hasAuto(folderPath)) return true;
    for (int i=0;i<8;++i) {
        if (hasSlot(i, folderPath)) return true;
    }
    return false;
}

bool SaveLoad::loadLatest(const QString &folderPath) {
    // Determine the most recently modified save among auto.dat and save1..save8.dat
    QDateTime bestTs;
    enum Kind { None, Auto, Slot } bestKind = None;
    int bestSlot = -1;

    // Check auto.dat
    {
        QString dirPath = QDir::cleanPath(QCoreApplication::applicationDirPath() + "/" + folderPath);
        QString autoPath = dirPath + "/auto.dat";
        QFileInfo ai(autoPath);
        if (ai.exists()) {
            bestTs = ai.lastModified();
            bestKind = Auto;
        }
    }

    // Check slots
    for (int i=0;i<8;++i) {
        QString p = slotDatPath(folderPath, i);
        QFileInfo si(p);
        if (si.exists()) {
            QDateTime ts = si.lastModified();
            if (bestKind == None || ts > bestTs) {
                bestTs = ts;
                bestKind = Slot;
                bestSlot = i;
            }
        }
    }

    if (bestKind == None) return false;
    if (bestKind == Auto) return loadPlayer(folderPath);
    if (bestKind == Slot) return loadSlot(bestSlot, folderPath);
    return false;
}

bool SaveLoad::createDefaultAuto(const QString &folderPath, double posX, double posY, double speed, double sight) {
    // populate last with provided values and save
    last.player.pos.setX(posX);
    last.player.pos.setY(posY);
    last.player.speed = speed;
    last.player.sight = sight;
    const int defaultMaxHp = 100;
    last.player.maxHp = defaultMaxHp;
    last.player.hp = defaultMaxHp;
    last.player.maxMp = 0;
    last.player.mp = 0;
    last.view = "game";
    last.battleId.clear();
    last.loreMusic.clear();
    last.loreMusicLoops = -1;
    last.loreMusicStopped = false;
    emit posXChanged();
    emit posYChanged();
    emit speedChanged();
    emit sightChanged();
    emit hpChanged();
    emit maxHpChanged();
    emit mpChanged();
    emit maxMpChanged();
    emit viewChanged();
    emit loreChapterChanged();
    emit loreNodeChanged();
    emit loreIndexChanged();
    emit loreMusicChanged();
    emit loreMusicLoopsChanged();
    emit loreMusicStoppedChanged();
    emit battleIdChanged();
    bool ok = savePlayer(folderPath);
    return ok;
}

bool SaveLoad::removeAuto(const QString &folderPath) {
    QString dirPath = QDir::cleanPath(QCoreApplication::applicationDirPath() + "/" + folderPath);
    QString filePath = dirPath + "/auto.dat";
    QFile f(filePath);
    bool existed = f.exists();
    if (existed) {
        if (!f.remove()) {
            qWarning() << "SaveLoad: failed to remove auto file" << filePath;
            return false;
        }
    }
    bool prev = m_autoExists;
    m_autoExists = false;
    if (m_watcher) {
        // remove file path from watcher if present
        if (m_watcher->files().contains(filePath)) m_watcher->removePath(filePath);
    }
    if (m_autoExists != prev) emit autoExistsChanged();
    return true;
}

bool SaveLoad::removeSlot(int slot, const QString &folderPath) {
    if (slot < 0 || slot > 7) return false;
    QString datPath = slotDatPath(folderPath, slot);
    QString pngPath = slotPngPath(folderPath, slot);
    bool ok = true;
    QFile f(datPath);
    if (f.exists()) {
        if (!f.remove()) {
            qWarning() << "SaveLoad: failed to remove slot file" << datPath;
            ok = false;
        }
    }
    QFile p(pngPath);
    if (p.exists()) {
        if (!p.remove()) {
            qWarning() << "SaveLoad: failed to remove slot preview" << pngPath;
            ok = false;
        }
    }
    // also update auto.dat if it pointed at this save (best-effort: remove auto)
    // Not strictly required; leave auto alone.
    emit saved(); // reuse saved signal as a generic notification so QML can refresh
    return ok;
}
