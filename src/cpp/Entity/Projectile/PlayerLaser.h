#ifndef PLAYERLASER_H
#define PLAYERLASER_H


#include "Projectile.h"

class PlayerLaser : public Projectile {
    Q_OBJECT
    Q_PROPERTY(int damage READ damage WRITE setDamage NOTIFY damageChanged)
    Q_PROPERTY(int spreadIndex READ spreadIndex WRITE setSpreadIndex NOTIFY spreadIndexChanged)
    // How far the laser knocks enemies back (world units)
    Q_PROPERTY(double knockbackDistance READ knockbackDistance WRITE setKnockbackDistance NOTIFY knockbackDistanceChanged)
    // Interval (ms) between repeated knockbacks while enemy remains in contact
    Q_PROPERTY(int knockIntervalMs READ knockIntervalMs WRITE setKnockIntervalMs NOTIFY knockIntervalMsChanged)
public:
    explicit PlayerLaser(QObject *parent = nullptr);
    ~PlayerLaser();
    void setDirection(double dx, double dy);
    void setStartPos(const QPointF &p) { setPos(p); }

    int damage() const { return laserDamage; }
    void setDamage(int value);
    double knockbackDistance() const;
    void setKnockbackDistance(double d);
    int knockIntervalMs() const;
    void setKnockIntervalMs(int ms);
    int spreadIndex() const;
    void setSpreadIndex(int idx);
signals:
    void backendDestroyed(PlayerLaser* self);
    void damageChanged();
    void knockbackDistanceChanged();
    void knockIntervalMsChanged();
    void spreadIndexChanged();
private:
    double vx{0};
    double vy{0};
    int laserDamage{250};
    int _spreadIndex{0};
    double _knockbackDistance{300.0};
    int _knockIntervalMs{1000};
    void startTick();
    void stopTick();
};

#endif // PLAYERLASER_H
