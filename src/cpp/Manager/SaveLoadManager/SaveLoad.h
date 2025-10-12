#ifndef SAVELOAD_H
#define SAVELOAD_H

#include <QObject>
#include <QString>
#include "SaveData.h"
class QFileSystemWatcher;

class SaveLoad : public QObject {
    Q_OBJECT
    Q_PROPERTY(double posX READ posX WRITE setPosX NOTIFY posXChanged)
    Q_PROPERTY(double posY READ posY WRITE setPosY NOTIFY posYChanged)
    Q_PROPERTY(double speed READ speed WRITE setSpeed NOTIFY speedChanged)
    Q_PROPERTY(double sight READ sight WRITE setSight NOTIFY sightChanged)
public:
    explicit SaveLoad(QObject *parent = nullptr);

    // Player-specific save/load APIs. Other categories will be added to SaveData later.
    Q_INVOKABLE bool savePlayer(const QString &folderPath = "save");
    Q_INVOKABLE bool loadPlayer(const QString &folderPath = "save");

    // Backwards-compatible generic names that currently act on player data.
    Q_INVOKABLE bool saveAuto(const QString &folderPath = "save");
    Q_INVOKABLE bool loadAuto(const QString &folderPath = "save");
    Q_INVOKABLE bool hasAuto(const QString &folderPath = "save");
    // Save-based save/load: slot index is 0-based (0..7). Filenames are save1..save8
    Q_INVOKABLE bool saveSlot(int slot, const QString &folderPath = "save");
    Q_INVOKABLE bool loadSlot(int slot, const QString &folderPath = "save");
    Q_INVOKABLE bool hasSlot(int slot, const QString &folderPath = "save");
    Q_INVOKABLE QString slotPreviewUrl(int slot, const QString &folderPath = "save");
    // New name for the preview URL reflecting 'save' naming; kept for clarity and future use.
    Q_INVOKABLE QString savePreviewUrl(int slot, const QString &folderPath = "save");
    // Create a default auto save with explicit data (used for START/new game semantics)
    Q_INVOKABLE bool createDefaultAuto(const QString &folderPath, double posX, double posY, double speed, double sight);
    Q_INVOKABLE bool removeAuto(const QString &folderPath = "save");
    // Remove a specific save slot (delete saveN.dat and saveN.png). Returns true if successful or not existing.
    Q_INVOKABLE bool removeSlot(int slot, const QString &folderPath = "save");
    // Capture a temporary preview image (temp.png) by grabbing the main QQuickWindow and saving to folderPath/temp.png
    Q_INVOKABLE bool captureTemp(const QString &folderPath = "save");
    // Reactive property to allow QML bindings to update when auto.dat presence changes
    Q_PROPERTY(bool autoExists READ autoExists NOTIFY autoExistsChanged)

    double posX() const { return last.player.pos.x(); }
    double posY() const { return last.player.pos.y(); }
    double speed() const { return last.player.speed; }
    double sight() const { return last.player.sight; }

    bool autoExists() const;

    void setPosX(double x) { if (last.player.pos.x() != x) { last.player.pos.setX(x); emit posXChanged(); } }
    void setPosY(double y) { if (last.player.pos.y() != y) { last.player.pos.setY(y); emit posYChanged(); } }
    void setSpeed(double s) { if (last.player.speed != s) { last.player.speed = s; emit speedChanged(); } }
    void setSight(double s) { if (last.player.sight != s) { last.player.sight = s; emit sightChanged(); } }

signals:
    void loaded();
    void saved();
    void autoExistsChanged();
    void posXChanged();
    void posYChanged();
    void speedChanged();
    void sightChanged();
private:
    SaveData last;
    bool m_autoExists{false};
    QFileSystemWatcher *m_watcher{nullptr};
};

#endif // SAVELOAD_H
