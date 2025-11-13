#ifndef SAVELOAD_H
#define SAVELOAD_H

#include <QObject>
#include <QString>
#include "SaveData.h"
class QFileSystemWatcher;
#include <QVariant>

class SaveLoad : public QObject {
    Q_OBJECT
    Q_PROPERTY(double posX READ posX WRITE setPosX NOTIFY posXChanged)
    Q_PROPERTY(double posY READ posY WRITE setPosY NOTIFY posYChanged)
    Q_PROPERTY(double speed READ speed WRITE setSpeed NOTIFY speedChanged)
    Q_PROPERTY(double sight READ sight WRITE setSight NOTIFY sightChanged)
    Q_PROPERTY(int hp READ hp WRITE setHp NOTIFY hpChanged)
    Q_PROPERTY(int maxHp READ maxHp WRITE setMaxHp NOTIFY maxHpChanged)
    Q_PROPERTY(int mp READ mp WRITE setMp NOTIFY mpChanged)
    Q_PROPERTY(int maxMp READ maxMp WRITE setMaxMp NOTIFY maxMpChanged)
    // View and Lore metadata
    Q_PROPERTY(QString view READ view WRITE setView NOTIFY viewChanged)
    Q_PROPERTY(QString loreChapter READ loreChapter WRITE setLoreChapter NOTIFY loreChapterChanged)
    Q_PROPERTY(QString loreNode READ loreNode WRITE setLoreNode NOTIFY loreNodeChanged)
    Q_PROPERTY(int loreIndex READ loreIndex WRITE setLoreIndex NOTIFY loreIndexChanged)
    Q_PROPERTY(QString loreMusic READ loreMusic WRITE setLoreMusic NOTIFY loreMusicChanged)
    Q_PROPERTY(int loreMusicLoops READ loreMusicLoops WRITE setLoreMusicLoops NOTIFY loreMusicLoopsChanged)
    Q_PROPERTY(bool loreMusicStopped READ loreMusicStopped WRITE setLoreMusicStopped NOTIFY loreMusicStoppedChanged)
    Q_PROPERTY(QString battleId READ battleId WRITE setBattleId NOTIFY battleIdChanged)
public:
    explicit SaveLoad(QObject *parent = nullptr);

    // Player-specific save/load APIs. Other categories will be added to SaveData later.
    Q_INVOKABLE bool savePlayer(const QString &folderPath = "save");
    Q_INVOKABLE bool loadPlayer(const QString &folderPath = "save");

    // Backwards-compatible generic names that currently act on player data.
    Q_INVOKABLE bool saveAuto(const QString &folderPath = "save");
    Q_INVOKABLE bool loadAuto(const QString &folderPath = "save");
    Q_INVOKABLE bool hasAuto(const QString &folderPath = "save");
    // Return true if any save exists (auto or any save1..save8)
    Q_INVOKABLE bool hasAnySave(const QString &folderPath = "save");
    // Save-based save/load: slot index is 0-based (0..7). Filenames are save1..save8
    Q_INVOKABLE bool saveSlot(int slot, const QString &folderPath = "save");
    Q_INVOKABLE bool loadSlot(int slot, const QString &folderPath = "save");
    Q_INVOKABLE bool hasSlot(int slot, const QString &folderPath = "save");
    Q_INVOKABLE QString slotPreviewUrl(int slot, const QString &folderPath = "save");
    // New name for the preview URL reflecting 'save' naming; kept for clarity and future use.
    Q_INVOKABLE QString savePreviewUrl(int slot, const QString &folderPath = "save");
    // Load the most recently modified save among auto.dat and save1..save8.dat
    Q_INVOKABLE bool loadLatest(const QString &folderPath = "save");
    // Create a default auto save with explicit data (used for START/new game semantics)
    Q_INVOKABLE bool createDefaultAuto(const QString &folderPath, double posX, double posY, double speed, double sight);
    Q_INVOKABLE bool removeAuto(const QString &folderPath = "save");
    // Remove a specific save slot (delete saveN.dat and saveN.png). Returns true if successful or not existing.
    Q_INVOKABLE bool removeSlot(int slot, const QString &folderPath = "save");
    // Capture a temporary preview image (temp.png) by grabbing the main QQuickWindow and saving to folderPath/temp.png
    Q_INVOKABLE bool captureTemp(const QString &folderPath = "save");
    // Populate the internal enemy list from a QVariantList of maps. Each map should contain:
    // { "type": QString, "x": double, "y": double, "hp": int, "maxHp": int, "mp": int, "maxMp": int, "alive": bool }
    Q_INVOKABLE void setEnemies(const QVariantList &list);
    Q_INVOKABLE QVariantList enemiesAsVariantList() const;
    // Reactive property to allow QML bindings to update when auto.dat presence changes
    Q_PROPERTY(bool autoExists READ autoExists NOTIFY autoExistsChanged)

    double posX() const { return last.player.pos.x(); }
    double posY() const { return last.player.pos.y(); }
    double speed() const { return last.player.speed; }
    double sight() const { return last.player.sight; }
    int hp() const { return last.player.hp; }
    int maxHp() const { return last.player.maxHp; }
    int mp() const { return last.player.mp; }
    int maxMp() const { return last.player.maxMp; }
    QString view() const { return last.view; }
    QString loreChapter() const { return last.loreChapter; }
    QString loreNode() const { return last.loreNode; }
    int loreIndex() const { return last.loreIndex; }
    QString loreMusic() const { return last.loreMusic; }
    int loreMusicLoops() const { return last.loreMusicLoops; }
    bool loreMusicStopped() const { return last.loreMusicStopped; }
    QString battleId() const { return last.battleId; }

    bool autoExists() const;

    void setPosX(double x) { if (last.player.pos.x() != x) { last.player.pos.setX(x); emit posXChanged(); } }
    void setPosY(double y) { if (last.player.pos.y() != y) { last.player.pos.setY(y); emit posYChanged(); } }
    void setSpeed(double s) { if (last.player.speed != s) { last.player.speed = s; emit speedChanged(); } }
    void setSight(double s) { if (last.player.sight != s) { last.player.sight = s; emit sightChanged(); } }
    void setHp(int value) { if (last.player.hp != value) { last.player.hp = value; emit hpChanged(); } }
    void setMaxHp(int value) { if (last.player.maxHp != value) { last.player.maxHp = value; emit maxHpChanged(); } }
    void setMp(int value) { if (last.player.mp != value) { last.player.mp = value; emit mpChanged(); } }
    void setMaxMp(int value) { if (last.player.maxMp != value) { last.player.maxMp = value; emit maxMpChanged(); } }
    void setView(const QString &v) { if (last.view != v) { last.view = v; emit viewChanged(); } }
    void setLoreChapter(const QString &c) { if (last.loreChapter != c) { last.loreChapter = c; emit loreChapterChanged(); } }
    void setLoreNode(const QString &n) { if (last.loreNode != n) { last.loreNode = n; emit loreNodeChanged(); } }
    void setLoreIndex(int idx) { if (last.loreIndex != idx) { last.loreIndex = idx; emit loreIndexChanged(); } }
    void setLoreMusic(const QString &m) { if (last.loreMusic != m) { last.loreMusic = m; emit loreMusicChanged(); } }
    void setLoreMusicLoops(int loops) { if (last.loreMusicLoops != loops) { last.loreMusicLoops = loops; emit loreMusicLoopsChanged(); } }
    void setLoreMusicStopped(bool stopped) { if (last.loreMusicStopped != stopped) { last.loreMusicStopped = stopped; emit loreMusicStoppedChanged(); } }
    void setBattleId(const QString &id) { if (last.battleId != id) { last.battleId = id; emit battleIdChanged(); } }

signals:
    void loaded();
    void saved();
    void autoExistsChanged();
    void posXChanged();
    void posYChanged();
    void speedChanged();
    void sightChanged();
    void hpChanged();
    void maxHpChanged();
    void mpChanged();
    void maxMpChanged();
    void viewChanged();
    void loreChapterChanged();
    void loreNodeChanged();
    void loreIndexChanged();
    void loreMusicChanged();
    void loreMusicLoopsChanged();
    void loreMusicStoppedChanged();
    void battleIdChanged();
private:
    SaveData last;
    bool m_autoExists{false};
    QFileSystemWatcher *m_watcher{nullptr};
};

#endif // SAVELOAD_H
