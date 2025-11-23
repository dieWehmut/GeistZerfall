#ifndef PLAYERWAVE_H
#define PLAYERWAVE_H

#include "Projectile.h"

class PlayerWave : public Projectile {
    Q_OBJECT
    Q_PROPERTY(double rotation READ rotation WRITE setRotation NOTIFY rotationChanged)
    Q_PROPERTY(int damage READ damage WRITE setDamage NOTIFY damageChanged)
public:
    explicit PlayerWave(QObject *parent = nullptr);
    ~PlayerWave();

    void setDirection(double dx, double dy);
    double rotation() const { return waveRotation; }
    void setRotation(double value);
    void setStartPos(const QPointF &p) { setPos(p); }

    int damage() const { return waveDamage; }
    void setDamage(int value);

signals:
    void backendDestroyed(PlayerWave* self);
    void damageChanged();
    void rotationChanged();

private:
    double vx{0};
    double vy{0};
    double waveRotation{0};
    int waveDamage{80};
    void startTick();
    void stopTick();
};

#endif // PLAYERWAVE_H
