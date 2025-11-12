#include "SaveData.h"

#include <QDebug>
#include <QIODevice>

// PlayerSaveData serialization: versioned per-player block.
void PlayerSaveData::write(QDataStream &out) const {
    // bump to version 3 to include hp/maxHp/mp/maxMp
    quint32 version = 3;
    out << version;
    out << pos.x();
    out << pos.y();
    out << speed;
    out << sight;
    out << hp;
    out << maxHp;
    out << mp;
    out << maxMp;
}

bool PlayerSaveData::read(QDataStream &in) {
    quint32 version = 0;
    in >> version;
    if (in.status() != QDataStream::Ok) return false;
    if (version == 1) {
        // old flat format: (version, x, y, speed, sight) but version==1 indicates original SaveData layout
        double x = 0, y = 0;
        in >> x;
        in >> y;
        in >> speed;
        in >> sight;
        if (in.status() != QDataStream::Ok) return false;
        pos.setX(x);
        pos.setY(y);
        return true;
    } else if (version == 2) {
        double x = 0, y = 0;
        in >> x;
        in >> y;
        in >> speed;
        in >> sight;
        if (in.status() != QDataStream::Ok) return false;
        pos.setX(x);
        pos.setY(y);
        return true;
    } else if (version == 3) {
        double x = 0, y = 0;
        in >> x;
        in >> y;
        in >> speed;
        in >> sight;
        in >> hp;
        in >> maxHp;
        in >> mp;
        in >> maxMp;
        if (in.status() != QDataStream::Ok) return false;
        pos.setX(x);
        pos.setY(y);
        return true;
    }
    // unknown version
    qWarning() << "PlayerSaveData: unknown version" << version;
    return false;
}

void SaveData::write(QDataStream &out) const {
    // bump top-level version to 4 to include battleId in addition to previous fields
    quint32 topVersion = 4;
    out << topVersion;
    // write player block
    player.write(out);
    // write view/lore metadata
    out << view;
    out << loreChapter;
    out << loreNode;
    out << loreIndex;
    out << battleId;
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
    if (topVersion == 1) {
        // In version 1 we expect the same sequence as original SaveData (player-only), but
        // original files started with version==1 followed by x,y,speed,sight. To remain
        // compatible, we'll treat this as a player block with version==1 already consumed.
        // However older files had only a single version number then values; our PlayerSaveData
        // reader expects a player-subversion next. To handle both cases, we peek the next
        // value and decide. We'll attempt to read using PlayerSaveData::read which expects a
        // player-version value next; but old files will have x (double) instead. So we need
        // to handle that case: if next token is a double we assume old layout and reconstruct.

        // Try to read next as quint32 (player version) safely by peeking raw buffer state.
        // QDataStream doesn't provide a direct peek; instead we'll read into a quint32 and check
        // status; if reading as quint32 fails, assume old layout and reset stream by recreating
        // an error state — simpler approach: since original files wrote version(1) then x (double),
        // reading next as quint32 will reinterpret the double bits; but that's unsafe. Instead,
        // we detect file size: if there are exactly 4 values after top version, treat as old format.

        // Practical approach: attempt to read a quint32 (playerVersion). If playerVersion is 1 or 2
        // we'll proceed. If it looks obviously invalid (very large), we'll fallback treating it
        // as old layout where that quint32 is actually the double x's bit pattern. To avoid
        // complex heuristics, we'll assume authors saved with the original simple format and thus
        // that next value is actually double. We'll check stream.device()->bytesAvailable() to
        // roughly decide. Simpler: try reading playerVersion, then if reading subsequent doubles
        // fails, we'll reset and parse old-style manually. For simplicity in Qt without resetting,
        // we'll implement a best-effort: read a quint32, if it's 1 or 2 use it, otherwise treat as
        // old-format where we've already consumed part; can't robustly rewind here, so instead we
        // will fallback to older behaviour by assuming the first quint32 we read was actually the
        // double's bit pattern. To keep code simple and reliable, prefer to detect old-format by
        // checking remaining bytes: old-format after topVersion contains 4 doubles (x,y,speed,sight)
        // => 4 * sizeof(double) bytes. New-format contains a quint32 + 4 doubles => sizeof(quint32) + 4*sizeof(double).

        // Determine remaining bytes in device if possible
        QIODevice *dev = in.device();
        qint64 bytesAvailable = dev ? dev->bytesAvailable() : -1;
        const qint64 oldBytes = 4 * (qint64)sizeof(double);
        if (bytesAvailable == oldBytes) {
            // old layout: read x,y,speed,sight directly
            double x=0,y=0;
            in >> x;
            in >> y;
            in >> player.speed;
            in >> player.sight;
            if (in.status() != QDataStream::Ok) return false;
            player.pos.setX(x);
            player.pos.setY(y);
            return true;
        } else {
            // assume player sub-block with its own version
            // read player block via PlayerSaveData::read
            // Note: PlayerSaveData::read expects to read a quint32 version first
            // so we simply call it.
            bool ok = player.read(in);
            return ok;
        }
    }
    else if (topVersion == 2) {
        // New top-level: player sub-block followed by enemy list
        if (!player.read(in)) return false;
        // v2 had no view/lore: default to game
        view = "game";
        loreChapter.clear();
        loreNode.clear();
        loreIndex = 0;
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
    } else if (topVersion == 3) {
        // v3: player, view/lore, enemies (no battleId)
        if (!player.read(in)) return false;
        in >> view;
        in >> loreChapter;
        in >> loreNode;
        in >> loreIndex;
        if (in.status() != QDataStream::Ok) return false;
        battleId.clear();
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
    } else if (topVersion == 4) {
        if (!player.read(in)) return false;
        in >> view;
        in >> loreChapter;
        in >> loreNode;
        in >> loreIndex;
        in >> battleId;
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