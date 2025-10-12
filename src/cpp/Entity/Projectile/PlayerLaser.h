#ifndef PLAYERLASER_H
#define PLAYERLASER_H


#include "Projectile.h"

class PlayerLaser : public Projectile {
    Q_OBJECT
public:
    explicit PlayerLaser(QObject *parent = nullptr);
    ~PlayerLaser();
    void setDirection(double dx, double dy);
    void setStartPos(const QPointF &p) { setPos(p); }
signals:
    void backendDestroyed(PlayerLaser* self);
private:
    double vx{0};
    double vy{0};
    void startTick();
    void stopTick();
};

#endif // PLAYERLASER_H
