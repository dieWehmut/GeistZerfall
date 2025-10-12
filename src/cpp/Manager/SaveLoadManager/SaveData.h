#ifndef SAVEDATA_H
#define SAVEDATA_H

#include <QPointF>
#include <QDataStream>

// Player-specific save data. Versioned so it can evolve independently.
struct PlayerSaveData {
    QPointF pos{0,0};
    double speed{0};
    double sight{0};

    void write(QDataStream &out) const;
    bool read(QDataStream &in);
};

// Top-level SaveData. In future this can contain other categories (enemies, map, etc.).
struct SaveData {
    PlayerSaveData player;

    void write(QDataStream &out) const;
    bool read(QDataStream &in);
};

#endif // SAVEDATA_H
