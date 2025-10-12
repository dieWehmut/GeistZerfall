#ifndef PLAYERBULLET_H
#define PLAYERBULLET_H

#include "Projectile.h"

class PlayerBullet : public Projectile {
    Q_OBJECT
public:
    explicit PlayerBullet(QObject *parent = nullptr);
    ~PlayerBullet();

    // Set normalized direction vector (will be normalized internally)
    void setDirection(double dx, double dy);
    void setStartPos(const QPointF &p) { setPos(p); }

signals:
    // Emitted when backend bullet decides to be destroyed (max distance reached)
    void backendDestroyed(PlayerBullet* self);

private:
    double vx{0};
    double vy{0};
    void startTick();
    void stopTick();
};

#endif // PLAYERBULLET_H
