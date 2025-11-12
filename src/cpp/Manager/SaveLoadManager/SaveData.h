#ifndef SAVEDATA_H
#define SAVEDATA_H

#include <QPointF>
#include <QDataStream>
#include <QString>
#include <QList>

// Player-specific save data. Versioned so it can evolve independently.
struct PlayerSaveData {
    QPointF pos{0,0};
    double speed{0};
    double sight{0};
    int hp{100};
    int maxHp{100};
    int mp{0};
    int maxMp{0};

    void write(QDataStream &out) const;
    bool read(QDataStream &in);
};

// Top-level SaveData. In future this can contain other categories (enemies, map, etc.).
struct SaveData {
    PlayerSaveData player;
    // Which view this save belongs to: "game" or "lore" (can be extended later).
    QString view; // empty means unknown/old saves; treat as "game" by default
    // Lore progress (valid when view=="lore")
    QString loreChapter;
    QString loreNode;
    int loreIndex{0};
    // Battle identifier (valid when view=="game"). Empty indicates default map.
    QString battleId;
    // Save a list of enemies present in the scene. Bullets/lasers are intentionally omitted.
    struct EnemySaveData {
        QString type; // class name or identifier (e.g. "Enemy1", "Enemy2")
        QPointF pos{0,0};
        int hp{0};
        int maxHp{0};
        int mp{0};
        int maxMp{0};
        bool alive{true};

        void write(QDataStream &out) const;
        bool read(QDataStream &in);
    };
    QList<EnemySaveData> enemies;

    void write(QDataStream &out) const;
    bool read(QDataStream &in);
};

#endif // SAVEDATA_H
