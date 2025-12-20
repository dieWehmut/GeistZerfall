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
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QJsonParseError>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QCoreApplication>
#include <QVariant>

// Resolve the writable app data directory for saves, with desktop fallback
static QString resolveSaveDir(const QString &folderPath) {
    QString base = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    if (base.isEmpty()) {
        base = QCoreApplication::applicationDirPath();
    }
    // Normalize duplicate trailing components: if base ends with .../X/X, collapse to .../X
    QFileInfo baseInfo(base);
    QString leaf = baseInfo.fileName();
    QString parentPath = baseInfo.dir().absolutePath();
    QString parentLeaf;
    if (!parentPath.isEmpty()) parentLeaf = QFileInfo(parentPath).fileName();
    if (!leaf.isEmpty() && leaf == parentLeaf) {
        base = QDir::cleanPath(parentPath);
    }
    return QDir::cleanPath(base + "/" + folderPath);
}

SaveLoad::SaveLoad(QObject *parent) : QObject(parent) {
    // initialize autoExists based on the current file under AppDataLocation
    QString dirPath = resolveSaveDir(QString("save"));
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
        QString dirPathLocal = resolveSaveDir(QString("save"));
        QString filePathLocal = dirPathLocal + "/auto.dat";
        QFile ff(filePathLocal);
        m_autoExists = ff.exists();
        if (m_autoExists != prev) emit autoExistsChanged();
    });
    connect(m_watcher, &QFileSystemWatcher::directoryChanged, this, [this](const QString &path){
        Q_UNUSED(path)
        bool prev = m_autoExists;
        QString dirPathLocal = resolveSaveDir(QString("save"));
        QString filePathLocal = dirPathLocal + "/auto.dat";
        QFile ff(filePathLocal);
        m_autoExists = ff.exists();
        if (m_autoExists != prev) emit autoExistsChanged();
    });
}

bool SaveLoad::saveSystem(const QVariantMap &settings, const QString &folderPath) {
    QString dirPath = QDir::cleanPath(QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + "/" + folderPath);
    QDir dir;
    if (!dir.exists(dirPath)) {
        if (!dir.mkpath(dirPath)) {
            qWarning() << "SaveLoad::saveSystem: cannot create dir" << dirPath;
            return false;
        }
    }
    QString filePath = dirPath + "/system.dat";
    QFile f(filePath);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        qWarning() << "SaveLoad::saveSystem: cannot open file for write:" << filePath;
        return false;
    }
    QJsonObject obj = QJsonObject::fromVariantMap(settings);
    QJsonDocument doc(obj);
    QByteArray bytes = doc.toJson(QJsonDocument::Compact);
    qint64 written = f.write(bytes);
    f.close();
    return written == bytes.size();
}

QVariantMap SaveLoad::loadSystem(const QString &folderPath) {
    QVariantMap out;
    QString base = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    if (base.isEmpty()) base = QCoreApplication::applicationDirPath();
    QString dirPath = QDir::cleanPath(base + "/" + folderPath);
    QString filePath = dirPath + "/system.dat";
    QFile f(filePath);
    if (!f.exists()) return out;
    if (!f.open(QIODevice::ReadOnly)) {
        qWarning() << "SaveLoad::loadSystem: cannot open file for read:" << filePath;
        return out;
    }
    QByteArray data = f.readAll();
    f.close();
    QJsonParseError perr;
    QJsonDocument doc = QJsonDocument::fromJson(data, &perr);
    if (perr.error != QJsonParseError::NoError) {
        qWarning() << "SaveLoad::loadSystem: parse error" << perr.errorString();
        return out;
    }
    if (!doc.isObject()) return out;
    out = doc.object().toVariantMap();
    return out;
}

bool SaveLoad::saveProgress(const QVariantMap &progress, const QString &folderPath) {
    QString dirPath = QDir::cleanPath(QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + "/" + folderPath);
    QDir dir;
    if (!dir.exists(dirPath)) {
        if (!dir.mkpath(dirPath)) {
            qWarning() << "SaveLoad::saveProgress: cannot create dir" << dirPath;
            return false;
        }
    }
    QString filePath = dirPath + "/progress.dat";
    QFile f(filePath);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        qWarning() << "SaveLoad::saveProgress: cannot open file for write:" << filePath;
        return false;
    }
    // Merge extraUnlocked map if the caller only provided readProgress
    QVariantMap toWrite = progress;
    QVariantMap existing = loadProgress(folderPath);
    if (existing.contains("extraUnlocked") && !toWrite.contains("extraUnlocked")) {
        toWrite["extraUnlocked"] = existing["extraUnlocked"];
    }
    QJsonObject obj = QJsonObject::fromVariantMap(toWrite);
    QJsonDocument doc(obj);
    QByteArray bytes = doc.toJson(QJsonDocument::Compact);
    qint64 written = f.write(bytes);
    f.close();
    if (written == bytes.size()) {
        qDebug() << "SaveLoad::saveProgress wrote" << written << "bytes to" << filePath << "data:" << QString(bytes);
    } else {
        qWarning() << "SaveLoad::saveProgress write mismatch" << written << "expected" << bytes.size() << "file:" << filePath;
    }
    return written == bytes.size();
}

QVariantMap SaveLoad::loadProgress(const QString &folderPath) {
    QVariantMap out;
    QString dirPath = QDir::cleanPath(QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + "/" + folderPath);
    QString filePath = dirPath + "/progress.dat";
    QFile f(filePath);
    if (!f.exists()) return out;
    if (!f.open(QIODevice::ReadOnly)) {
        qWarning() << "SaveLoad::loadProgress: cannot open file for read:" << filePath;
        return out;
    }
    QByteArray data = f.readAll();
    f.close();
    QJsonParseError perr;
    QJsonDocument doc = QJsonDocument::fromJson(data, &perr);
    if (perr.error != QJsonParseError::NoError) {
        qWarning() << "SaveLoad::loadProgress: parse error" << perr.errorString();
        return out;
    }
    if (!doc.isObject()) return out;
    out = doc.object().toVariantMap();
    // Ensure extraUnlocked map exists and initialize default battles to false if absent
    if (!out.contains("extraUnlocked") || !out["extraUnlocked"].canConvert<QVariantMap>()) {
        QVariantMap extras;
        // default set for battle01..battle06
        for (int i=1;i<=6;++i) {
            QString bid = QString("battle%1").arg(i, 2, 10, QChar('0'));
            extras[bid] = false;
        }
        out["extraUnlocked"] = extras;
        // Persist initial structure so future reads clearly indicate default values
        try {
            QString base = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
            if (base.isEmpty()) base = QCoreApplication::applicationDirPath();
            QString dirPath = QDir::cleanPath(base + "/" + folderPath);
            QString filePath = dirPath + "/progress.dat";
            QFile f(filePath);
            if (f.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
                QJsonObject obj = QJsonObject::fromVariantMap(out);
                QJsonDocument docOut(obj);
                f.write(docOut.toJson(QJsonDocument::Compact));
                f.close();
            }
        } catch (...) { }
    }
    qDebug() << "SaveLoad::loadProgress read from" << filePath << "data:" << QString(data) << "parsed keys:" << out.keys();
    return out;
}
bool SaveLoad::saveAuto(const QString &folderPath) {
    // For backward compatibility this still saves the same auto.dat but using the new top-level format.
    return savePlayer(folderPath);
}

bool SaveLoad::loadAuto(const QString &folderPath) {
    return loadPlayer(folderPath);
}

bool SaveLoad::savePlayer(const QString &folderPath) {
    QString base = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    if (base.isEmpty()) base = QCoreApplication::applicationDirPath();
    QString dirPath = QDir::cleanPath(base + "/" + folderPath);
    QString filePath = dirPath + "/auto.dat"; // compute early for logging
    qDebug() << "SaveLoad::savePlayer base=" << base << "dirPath=" << dirPath << "filePath=" << filePath;
    QDir dir;
    if (!dir.exists(dirPath)) {
        if (!dir.mkpath(dirPath)) {
            qWarning() << "SaveLoad: failed to create save dir" << dirPath;
            return false;
        }
    }
    
    QFile f(filePath);
    if (!f.open(QIODevice::WriteOnly)) {
        qWarning() << "SaveLoad: cannot open file for write:" << filePath;
        return false;
    }
    QDataStream out(&f);
    out.setVersion(QDataStream::Qt_5_15);
    last.write(out);
    // append remaining countdown seconds for compatibility (written after SaveData block)
    out << static_cast<qint32>(last.timeLeftSeconds);
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
    QString base = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    if (base.isEmpty()) base = QCoreApplication::applicationDirPath();
    QString dirPath = QDir::cleanPath(base + "/" + folderPath);
    return dirPath + QString("/save%1.dat").arg(human);
}

static QString slotPngPath(const QString &folderPath, int slot) {
    int human = slot + 1;
    QString base = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    if (base.isEmpty()) base = QCoreApplication::applicationDirPath();
    QString dirPath = QDir::cleanPath(base + "/" + folderPath);
    return dirPath + QString("/save%1.png").arg(human);
}

bool SaveLoad::saveSlot(int slot, const QString &folderPath) {
    if (slot < 0 || slot > 7) return false;
    QString dirPath = QDir::cleanPath(QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + "/" + folderPath);
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
    // append remaining countdown seconds for compatibility
    out << static_cast<qint32>(last.timeLeftSeconds);
    f.close();

    qDebug() << "SaveLoad: saved slot" << slot << "to" << filePath << "pos=" << last.player.pos << "speed=" << last.player.speed << "sight=" << last.player.sight;

    // try to capture a screenshot of the main window if available
    // If a temporary preview exists (temp.png), use it and overwrite slot preview; otherwise fall back to grabbing window
    QString tempPng = QDir::cleanPath(QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + "/" + folderPath + "/temp.png");
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
    QString dirPath = QDir::cleanPath(QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + "/" + folderPath);
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
    // attempt to read appended timeLeftSeconds (if present)
    if (ok) {
        // Trim loreHistory stored in this save to the saved progress (chapter/node/index)
        try {
            QString orig = last.loreHistory;
            if (!orig.isEmpty()) {
                QJsonDocument doc = QJsonDocument::fromJson(orig.toUtf8());
                if (doc.isArray()) {
                    QJsonArray arr = doc.array();
                    int target = -1;
                    for (int i = arr.size() - 1; i >= 0; --i) {
                        QJsonObject obj = arr.at(i).toObject();
                        QString b = obj.value("branch").toString("");
                        QString n = obj.value("node").toString("");
                        int idx = obj.value("index").toInt(-1);
                        // Allow matching entries that either explicitly belong to the saved branch
                        // OR have an empty branch (older history entries may not contain branch info).
                        bool branchMatches = (b.isEmpty() || b == last.loreChapter);
                        if (branchMatches && n == last.loreNode && idx == last.loreIndex) {
                            target = i;
                            break;
                        }
                    }
                    if (target >= 0 && target < arr.size() - 1) {
                        QJsonArray newArr;
                        for (int i = 0; i <= target; ++i) newArr.append(arr.at(i));
                        QJsonDocument newDoc(newArr);
                        last.loreHistory = QString::fromUtf8(newDoc.toJson(QJsonDocument::Compact));
                        // rewrite the slot file to store trimmed loreHistory
                        QFile wf(filePath);
                        if (wf.open(QIODevice::WriteOnly)) {
                            QDataStream out(&wf);
                            out.setVersion(QDataStream::Qt_5_15);
                            last.write(out);
                            // append remaining countdown seconds for compatibility
                            out << static_cast<qint32>(last.timeLeftSeconds);
                            wf.close();
                        }
                    }
                }
            }
        } catch (...) { /* ignore errors */ }
        if (in.device()) {
            qint64 available = in.device()->bytesAvailable();
            if (available >= static_cast<qint64>(sizeof(qint32))) {
                qint32 t = 0;
                in >> t;
                last.timeLeftSeconds = static_cast<int>(t);
            }
        }
    }
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
        emit mp2Changed();
        emit maxMp2Changed();
        emit viewChanged();
        emit loreChapterChanged();
        emit loreNodeChanged();
        emit loreIndexChanged();
        emit loreMusicChanged();
        emit loreMusicLoopsChanged();
        emit loreMusicStoppedChanged();
        emit battleIdChanged();
        emit timeLeftSecondsChanged();
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
    QString base = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    if (base.isEmpty()) base = QCoreApplication::applicationDirPath();
    QString dirPath = QDir::cleanPath(base + "/" + folderPath);
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
    // attempt to read appended timeLeftSeconds (if present)
    if (ok) {
        // Trim loreHistory stored in this save to the saved progress (chapter/node/index)
        try {
            QString orig = last.loreHistory;
            if (!orig.isEmpty()) {
                QJsonDocument doc = QJsonDocument::fromJson(orig.toUtf8());
                if (doc.isArray()) {
                    QJsonArray arr = doc.array();
                    int target = -1;
                    for (int i = arr.size() - 1; i >= 0; --i) {
                        QJsonObject obj = arr.at(i).toObject();
                        QString b = obj.value("branch").toString("");
                        QString n = obj.value("node").toString("");
                        int idx = obj.value("index").toInt(-1);
                        bool branchMatches = (b.isEmpty() || b == last.loreChapter);
                        if (branchMatches && n == last.loreNode && idx == last.loreIndex) {
                            target = i;
                            break;
                        }
                    }
                    if (target >= 0 && target < arr.size() - 1) {
                        QJsonArray newArr;
                        for (int i = 0; i <= target; ++i) newArr.append(arr.at(i));
                        QJsonDocument newDoc(newArr);
                        last.loreHistory = QString::fromUtf8(newDoc.toJson(QJsonDocument::Compact));
                        // write back trimmed save file (rewrite auto.dat)
                        QFile wf(filePath);
                        if (wf.open(QIODevice::WriteOnly)) {
                            QDataStream out(&wf);
                            out.setVersion(QDataStream::Qt_5_15);
                            last.write(out);
                            // append remaining countdown seconds for compatibility (preserve previously read value)
                            out << static_cast<qint32>(last.timeLeftSeconds);
                            wf.close();
                        }
                    }
                }
            }
        } catch (...) { /* non-fatal: ignore trimming errors */ }
        if (in.device()) {
            qint64 available = in.device()->bytesAvailable();
            if (available >= static_cast<qint64>(sizeof(qint32))) {
                qint32 t = 0;
                in >> t;
                last.timeLeftSeconds = static_cast<int>(t);
            }
        }
    }
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
        emit mp2Changed();
        emit maxMp2Changed();
        emit viewChanged();
        emit loreChapterChanged();
        emit loreNodeChanged();
        emit loreIndexChanged();
        emit loreMusicChanged();
        emit loreMusicLoopsChanged();
        emit loreMusicStoppedChanged();
        emit battleIdChanged();
        emit timeLeftSecondsChanged();
        emit loaded();
    }
    return ok;
}

bool SaveLoad::hasAuto(const QString &folderPath) {
    QString base = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    if (base.isEmpty()) base = QCoreApplication::applicationDirPath();
    QString dirPath = QDir::cleanPath(base + "/" + folderPath);
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
        QString base = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
        if (base.isEmpty()) base = QCoreApplication::applicationDirPath();
        QString dirPath = QDir::cleanPath(base + "/" + folderPath);
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
    last.player.maxMp1 = 0;
    last.player.mp1 = 0;
    last.player.maxMp2 = 0;
    last.player.mp2 = 0;
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
    emit mp2Changed();
    emit maxMp2Changed();
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

void SaveLoad::unlockExtra(const QString &battleId, const QString &folderPath) {
    // Mark battle as permanently unlocked under extraUnlocked map
    QVariantMap progress = loadProgress(folderPath);
    QVariantMap extraMap;
    if (progress.contains("extraUnlocked") && progress["extraUnlocked"].canConvert<QVariantMap>()) {
        extraMap = progress["extraUnlocked"].toMap();
    }
    if (!extraMap.value(battleId, false).toBool()) {
        extraMap[battleId] = true;
        progress["extraUnlocked"] = extraMap;
        saveProgress(progress, folderPath);
        qDebug() << "SaveLoad::unlockExtra persisted unlock for" << battleId;
        emit saved();
    } else {
        qDebug() << "SaveLoad::unlockExtra already unlocked" << battleId;
    }
}

bool SaveLoad::hasUnlockedBattle(const QString &battleId, const QString &folderPath) {
    qDebug() << "SaveLoad::hasUnlockedBattle called for" << battleId << "folder" << folderPath;
    // Load progress map
    QVariantMap progress = loadProgress(folderPath);
    qDebug() << "SaveLoad::hasUnlockedBattle progress keys:" << progress.keys();

    // Prefer explicit persistent map extraUnlocked
    if (progress.contains("extraUnlocked") && progress["extraUnlocked"].canConvert<QVariantMap>()) {
        QVariantMap emap = progress["extraUnlocked"].toMap();
        if (emap.value(battleId, false).toBool()) { qDebug() << "hasUnlockedBattle: found in extraUnlocked" << battleId; return true; }
    }

    // Backwards compatibility: direct progress key (legacy boolean flag)
    if (progress.contains(battleId)) { qDebug() << "direct progress contains" << battleId; return true; }

    // Numeric variants: battle1 / battle01
    QString digits;
    for (QChar c : battleId) { if (c.isDigit()) digits.append(c); }
    if (!digits.isEmpty()) {
        bool ok = false;
        int num = digits.toInt(&ok);
        if (ok) {
            QString a = QString("battle%1").arg(num);
            if (progress.contains(a)) return true;
            QString z = num < 10 ? QString("battle0%1").arg(num) : a;
            if (progress.contains(z)) return true;
        }
    }

    // Scan chapter JSON files to find nodes that point to this battle
    QString appDir = QCoreApplication::applicationDirPath();
    QString localDir = QDir::cleanPath(appDir + "/qml/window/Lore/chapters");
    QDir d(localDir);
    QStringList files;
    bool useResource = false;
    if (d.exists()) {
        files = d.entryList(QStringList() << "*.json", QDir::Files);
    } else {
        // try resource path
        QDir rd(":/qml/window/Lore/chapters");
        if (rd.exists()) {
            files = rd.entryList(QStringList() << "*.json", QDir::Files);
            useResource = true;
        }
    }

    qDebug() << "SaveLoad::hasUnlockedBattle scanning files:" << files << "useResource:" << useResource;
    for (const QString &fn : files) {
        QString path;
        if (useResource) path = QString(":/qml/window/Lore/chapters/%1").arg(fn);
        else path = QDir(d).filePath(fn);

        QFile f(path);
        if (!f.open(QIODevice::ReadOnly)) { qDebug() << "SaveLoad::hasUnlockedBattle failed to open" << path; continue; }
        QByteArray data = f.readAll();
        f.close();

        QJsonParseError perr;
        QJsonDocument doc = QJsonDocument::fromJson(data, &perr);
        if (perr.error != QJsonParseError::NoError) continue;
        if (!doc.isObject()) continue;
        QJsonObject ch = doc.object();
        QString chapterId = fn;
        if (chapterId.endsWith('.')) chapterId.chop(1);
        chapterId = chapterId.replace(".json", "");

        QJsonObject nodes = ch.value("nodes").toObject();
        for (auto it = nodes.begin(); it != nodes.end(); ++it) {
            QString nodeId = it.key();
            QJsonObject nodeObj = it.value().toObject();

            // Cases that denote a `battle` is triggered:
            // 1) This node is an explicit battle node (id startsWith battle), and defines next/nextNode/choices that point to the post-battle node
            // 2) This node is a regular node that has action==startBattle with actionParams.battleId matching the target battle; in that case the node's own next/nextNode defines the post-battle node
            // 3) This node has a choice that points to the target battleId
            bool isBattleNode = nodeId.startsWith("battle");
            bool isStartBattleAction = false;
            if (nodeObj.contains("action") && nodeObj.value("action").isString() && nodeObj.value("action").toString() == "startBattle") {
                QJsonObject ap = nodeObj.value("actionParams").toObject();
                if (ap.contains("battleId") && ap.value("battleId").isString()) {
                    QString bid = ap.value("battleId").toString();
                    if (bid == battleId) isStartBattleAction = true;
                }
            }
            bool isChoiceBattle = false;
            if (nodeObj.contains("choices") && nodeObj.value("choices").isArray()) {
                QJsonArray choices = nodeObj.value("choices").toArray();
                for (const QJsonValue &cv : choices) {
                    if (cv.isObject() && cv.toObject().value("next").toString() == battleId) {
                        isChoiceBattle = true;
                        break;
                    }
                }
            }

            if (!isBattleNode && !isStartBattleAction && !isChoiceBattle) continue;

            // Enumerate target nodes that represent the node after this battle
            QStringList targets;
            if (nodeObj.contains("next") && nodeObj.value("next").isString()) {
                QString nxt = nodeObj.value("next").toString();
                if (!nxt.startsWith("battle")) targets.append(nxt);
            }
            if (nodeObj.contains("nextNode") && nodeObj.value("nextNode").isString()) {
                QString nxtn = nodeObj.value("nextNode").toString();
                if (!nxtn.startsWith("battle")) targets.append(nxtn);
            }
            // choices[].next could also point to post-battle nodes (rare but support it)
            if (nodeObj.contains("choices") && nodeObj.value("choices").isArray()) {
                QJsonArray choices = nodeObj.value("choices").toArray();
                for (const QJsonValue &cv : choices) {
                    if (!cv.isObject()) continue;
                    QJsonObject choice = cv.toObject();
                    if (choice.contains("next") && choice.value("next").isString()) {
                        QString cnext = choice.value("next").toString();
                        if (!cnext.startsWith("battle")) targets.append(cnext);
                    }
                }
            }
            if (targets.isEmpty()) continue;

            // For each post-battle target node, check whether it's been read (idx >= 0)
            for (const QString &tgt : targets) {
                QVariant vch = progress.value(chapterId);
                if (!vch.isValid()) continue;
                QVariantMap chapMap = vch.toMap();
                if (!chapMap.contains(tgt)) continue;
                QVariant idxVar = chapMap.value(tgt);
                if (!idxVar.isValid()) continue;
                bool okIdx = false;
                int idx = idxVar.toInt(&okIdx);
                if (!okIdx) continue;
                // as long as any content in the post-battle node has been read (idx >= 0), unlock
                if (idx >= 0) {
                    qDebug() << "unlocked via" << chapterId << nodeId << "->" << tgt << "(idx=" << idx << ")";
                    try { unlockExtra(battleId, folderPath); } catch (...) {}
                    return true;
                }
            }
        }
    }

    // Fallback: check binary save files (auto.dat and save1..save8.dat) for game saves that reference this battle
    QString base = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    if (base.isEmpty()) base = QCoreApplication::applicationDirPath();
    QString dirPath = QDir::cleanPath(base + "/" + folderPath);
    QString autoPath = dirPath + "/auto.dat";
    QFile fa(autoPath);
    if (fa.exists() && fa.open(QIODevice::ReadOnly)) {
        QDataStream in(&fa);
        in.setVersion(QDataStream::Qt_5_15);
        SaveData sd;
        if (sd.read(in)) {
            if (sd.view == "game" && sd.battleId == battleId) { fa.close(); qDebug() << "unlocked via auto.dat"; try { unlockExtra(battleId, folderPath);} catch(...){} return true; }
        }
        fa.close();
    }
    for (int i=0;i<8;++i) {
        QString slotPath = QDir(dirPath).filePath(QString("save%1.dat").arg(i+1));
        QFile fs(slotPath);
        if (!fs.exists()) continue;
        if (!fs.open(QIODevice::ReadOnly)) continue;
        QDataStream in(&fs);
        in.setVersion(QDataStream::Qt_5_15);
        SaveData sd;
        if (sd.read(in)) {
            if (sd.view == "game" && sd.battleId == battleId) { fs.close(); qDebug() << "unlocked via" << slotPath; try { unlockExtra(battleId, folderPath);} catch(...){} return true; }
        }
        fs.close();
    }

    // Not found; return false
    return false;
}


bool SaveLoad::removeAuto(const QString &folderPath) {
    QString base = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    if (base.isEmpty()) base = QCoreApplication::applicationDirPath();
    QString dirPath = QDir::cleanPath(base + "/" + folderPath);
    QString filePath = dirPath + "/auto.dat";
    QFile f(filePath);
    bool existed = f.exists();
    qDebug() << "SaveLoad: removeAuto called for" << filePath << "exists:" << existed;
    if (existed) {
        if (!f.remove()) {
            qWarning() << "SaveLoad: failed to remove auto file" << filePath;
            return false;
        }
        qDebug() << "SaveLoad: removed auto file" << filePath;
    }
    // Also remove any temporary preview image (temp.png) in the save folder for consistency
    QString tempPng = QDir::cleanPath(QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + "/" + folderPath + "/temp.png");
    QFile tp(tempPng);
    if (tp.exists()) {
        if (!tp.remove()) {
            qWarning() << "SaveLoad: failed to remove temp preview" << tempPng;
            // don't treat this as fatal; continue removing auto and update state
        } else {
            qDebug() << "SaveLoad: removed temp preview" << tempPng;
        }
    } else {
        qDebug() << "SaveLoad: temp preview not present at" << tempPng;
    }
    bool prev = m_autoExists;
    m_autoExists = false;
    if (m_watcher) {
        // remove file path from watcher if present
        if (m_watcher->files().contains(filePath)) m_watcher->removePath(filePath);
    }
    // Also ensure the directory watcher no longer lists temp if it was added
    if (m_watcher) {
        if (m_watcher->files().contains(tempPng)) m_watcher->removePath(tempPng);
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
