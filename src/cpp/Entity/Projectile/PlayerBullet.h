#ifndef PLAYERBULLET_H
#define PLAYERBULLET_H

#include "Projectile.h"

class PlayerBullet : public Projectile {
    Q_OBJECT
    Q_PROPERTY(int damage READ damage WRITE setDamage NOTIFY damageChanged)
public:
    explicit PlayerBullet(QObject *parent = nullptr);
    ~PlayerBullet();

    // Set normalized direction vector (will be normalized internally)
    void setDirection(double dx, double dy);
    void setStartPos(const QPointF &p) { setPos(p); }

    int damage() const { return bulletDamage; }
    void setDamage(int value);

signals:
    // Emitted when backend bullet decides to be destroyed (max distance reached)
    void backendDestroyed(PlayerBullet* self);
    void damageChanged();

private:
    double vx{0};
    double vy{0};
    int bulletDamage{20};
    void startTick();
    void stopTick();
};

#endif // PLAYERBULLET_H
