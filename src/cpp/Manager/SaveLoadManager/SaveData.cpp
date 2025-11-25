#include "SaveData.h"

#include <QDebug>
#include <QIODevice>

// PlayerSaveData serialization: versioned per-player block.
void PlayerSaveData::write(QDataStream &out) const {
    // player sub-version: 4 = includes hp/maxHp and two mp fields (mp1/maxMp1, mp2/maxMp2)
    quint32 version = 4;
    out << version;
    out << pos.x();
    out << pos.y();
    out << speed;
    out << sight;
    out << hp;
    out << maxHp;
    out << mp1;
    out << maxMp1;
    out << mp2;
    out << maxMp2;
}

bool PlayerSaveData::read(QDataStream &in) {
    quint32 version = 0;
    in >> version;
    if (in.status() != QDataStream::Ok) return false;

    if (version == 1 || version == 2) {
        // old flat format: (version, x, y, speed, sight)
        double x = 0, y = 0;
        in >> x;
        in >> y;
        in >> speed;
        in >> sight;
        if (in.status() != QDataStream::Ok) return false;
        pos.setX(x);
        pos.setY(y);
        // defaults for newer fields
        hp = 10000; maxHp = 10000;
        mp1 = mp2 = 0; maxMp1 = maxMp2 = 0;
        return true;
    } else if (version == 3) {
        // v3: added hp/maxHp and a single mp field
        double x = 0, y = 0;
        in >> x;
        in >> y;
        in >> speed;
        in >> sight;
        in >> hp;
        in >> maxHp;
        int oldMp = 0, oldMaxMp = 0;
        in >> oldMp;
        in >> oldMaxMp;
        if (in.status() != QDataStream::Ok) return false;
        pos.setX(x);
        pos.setY(y);
        // map single mp into mp1
        mp1 = oldMp; maxMp1 = oldMaxMp;
        mp2 = 0; maxMp2 = 0;
        return true;
    } else if (version == 4) {
        double x = 0, y = 0;
        in >> x;
        in >> y;
        in >> speed;
        in >> sight;
        in >> hp;
        in >> maxHp;
        in >> mp1;
        in >> maxMp1;
        in >> mp2;
        in >> maxMp2;
        if (in.status() != QDataStream::Ok) return false;
        pos.setX(x);
        pos.setY(y);
        return true;
    }

    qWarning() << "PlayerSaveData: unknown version" << version;
    return false;
}

void SaveData::write(QDataStream &out) const {
    // bump top-level version to 7 to include player sub-version 4 and loreHistory
    quint32 topVersion = 7;
    out << topVersion;
    // write player block
    player.write(out);
    // write view/lore metadata
    out << view;
    out << loreChapter;
    out << loreNode;
    out << loreIndex;
    out << battleId;
    out << loreMusic;
    out << loreMusicLoops;
    out << static_cast<quint8>(loreMusicStopped ? 1 : 0);
    // write lore history JSON (may be empty)
    out << loreHistory;
    // write enemy list
    quint32 enemyCount = static_cast<quint32>(enemies.size());
    out << enemyCount;
    for (const EnemySaveData &e : enemies) {
        e.write(out);
    }
}

bool SaveData::read(QDataStream &in) {
    quint32 topVersion = 0;
    in >> topVersion;
    if (in.status() != QDataStream::Ok) return false;

    // Top-level backward compatibility handling
    if (topVersion == 1) {
        // old layout: directly player simple block (no player sub-version)
        QIODevice *dev = in.device();
        qint64 bytesAvailable = dev ? dev->bytesAvailable() : -1;
        const qint64 oldBytes = 4 * static_cast<qint64>(sizeof(double));
        if (bytesAvailable == oldBytes) {
            double x=0,y=0;
            in >> x;
            in >> y;
            in >> player.speed;
            in >> player.sight;
            if (in.status() != QDataStream::Ok) return false;
            player.pos.setX(x);
            player.pos.setY(y);
            // defaults
            player.hp = 10000; player.maxHp = 10000;
            player.mp1 = player.mp2 = 0; player.maxMp1 = player.maxMp2 = 0;
            return true;
        } else {
            if (!player.read(in)) return false;
            view = "game";
            loreChapter.clear(); loreNode.clear(); loreIndex = 0; battleId.clear(); loreMusic.clear(); loreMusicLoops = -1; loreMusicStopped = false;
            enemies.clear();
            return true;
        }
    }

    if (topVersion == 2) {
        if (!player.read(in)) return false;
        view = "game";
        loreChapter.clear(); loreNode.clear(); loreIndex = 0;
        quint32 enemyCount = 0;
        in >> enemyCount;
        if (in.status() != QDataStream::Ok) return false;
        enemies.clear();
        for (quint32 i=0;i<enemyCount;++i) {
            EnemySaveData e;
            if (!e.read(in)) return false;
            enemies.append(e);
        }
        return true;
    }

    if (topVersion == 3) {
        if (!player.read(in)) return false;
        in >> view;
        in >> loreChapter;
        in >> loreNode;
        in >> loreIndex;
        if (in.status() != QDataStream::Ok) return false;
        battleId.clear(); loreMusic.clear(); loreMusicLoops = -1; loreMusicStopped = false;
        quint32 enemyCount = 0;
        in >> enemyCount;
        if (in.status() != QDataStream::Ok) return false;
        enemies.clear();
        for (quint32 i=0;i<enemyCount;++i) {
            EnemySaveData e;
            if (!e.read(in)) return false;
            enemies.append(e);
        }
        return true;
    }

    if (topVersion == 4) {
        if (!player.read(in)) return false;
        in >> view;
        in >> loreChapter;
        in >> loreNode;
        in >> loreIndex;
        in >> battleId;
        if (in.status() != QDataStream::Ok) return false;
        loreMusic.clear(); loreMusicLoops = -1; loreMusicStopped = false;
        quint32 enemyCount = 0;
        in >> enemyCount;
        if (in.status() != QDataStream::Ok) return false;
        enemies.clear();
        for (quint32 i=0;i<enemyCount;++i) {
            EnemySaveData e;
            if (!e.read(in)) return false;
            enemies.append(e);
        }
        return true;
    }

    if (topVersion >= 7) {
        // v7+ includes loreHistory
        if (!player.read(in)) return false;
        in >> view;
        in >> loreChapter;
        in >> loreNode;
        in >> loreIndex;
        in >> battleId;
        in >> loreMusic;
        in >> loreMusicLoops;
        quint8 stoppedByte = 0;
        in >> stoppedByte;
        loreMusicStopped = (stoppedByte != 0);
        in >> loreHistory;
        if (in.status() != QDataStream::Ok) return false;
        quint32 enemyCount = 0;
        in >> enemyCount;
        if (in.status() != QDataStream::Ok) return false;
        enemies.clear();
        for (quint32 i=0;i<enemyCount;++i) {
            EnemySaveData e;
            if (!e.read(in)) return false;
            enemies.append(e);
        }
        return true;
    }

    if (topVersion >= 5) {
        // v5 and v6: include lore music fields but no loreHistory
        if (!player.read(in)) return false;
        in >> view;
        in >> loreChapter;
        in >> loreNode;
        in >> loreIndex;
        in >> battleId;
        in >> loreMusic;
        in >> loreMusicLoops;
        quint8 stoppedByte = 0;
        in >> stoppedByte;
        loreMusicStopped = (stoppedByte != 0);
        if (in.status() != QDataStream::Ok) return false;
        quint32 enemyCount = 0;
        in >> enemyCount;
        if (in.status() != QDataStream::Ok) return false;
        enemies.clear();
        for (quint32 i=0;i<enemyCount;++i) {
            EnemySaveData e;
            if (!e.read(in)) return false;
            enemies.append(e);
        }
        loreHistory.clear();
        return true;
    }

    qWarning() << "SaveData: unknown top-level version" << topVersion;
    return false;
}

// EnemySaveData serialization
void SaveData::EnemySaveData::write(QDataStream &out) const {
    out << type;
    out << pos.x();
    out << pos.y();
    out << hp;
    out << maxHp;
    out << mp;
    out << maxMp;
    out << alive;
}

bool SaveData::EnemySaveData::read(QDataStream &in) {
    in >> type;
    double x=0,y=0;
    in >> x;
    in >> y;
    in >> hp;
    in >> maxHp;
    in >> mp;
    in >> maxMp;
    in >> alive;
    if (in.status() != QDataStream::Ok) return false;
    pos.setX(x);
    pos.setY(y);
    return true;
}