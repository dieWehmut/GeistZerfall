#include "SaveData.h"

#include <QDebug>
#include <QIODevice>

// PlayerSaveData serialization: versioned per-player block.
void PlayerSaveData::write(QDataStream &out) const {
    // player block version 2: wrap as (version, x, y, speed, sight)
    quint32 version = 2;
    out << version;
    out << pos.x();
    out << pos.y();
    out << speed;
    out << sight;
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
    }
    // unknown version
    qWarning() << "PlayerSaveData: unknown version" << version;
    return false;
}

// Top-level SaveData write: write a top-level version and then sub-blocks. Use version 1 for top-level.
void SaveData::write(QDataStream &out) const {
    quint32 topVersion = 1;
    out << topVersion;
    // write player block
    player.write(out);
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
    qWarning() << "SaveData: unknown top-level version" << topVersion;
    return false;
}