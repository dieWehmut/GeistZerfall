#ifndef PLAYERLASER_H
#define PLAYERLASER_H


#include "Projectile.h"

class PlayerLaser : public Projectile {
    Q_OBJECT
    Q_PROPERTY(int damage READ damage WRITE setDamage NOTIFY damageChanged)
public:
    explicit PlayerLaser(QObject *parent = nullptr);
    ~PlayerLaser();
    void setDirection(double dx, double dy);
    void setStartPos(const QPointF &p) { setPos(p); }

    int damage() const { return laserDamage; }
    void setDamage(int value);
signals:
    void backendDestroyed(PlayerLaser* self);
    void damageChanged();
private:
    double vx{0};
    double vy{0};
    int laserDamage{250};
    void startTick();
    void stopTick();
};

#endif // PLAYERLASER_H
