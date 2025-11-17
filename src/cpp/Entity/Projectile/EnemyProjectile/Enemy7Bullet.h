#ifndef ENEMY7_BULLET_H
#define ENEMY7_BULLET_H

#include "Entity/Projectile/Projectile.h"
#include <QTimer>

// Enemy7的子弹：速度更快，射程稍短，强化近距离压制
class Enemy7Bullet : public Projectile {
    Q_OBJECT
    Q_PROPERTY(int spriteIndex READ spriteIndex WRITE setSpriteIndex NOTIFY spriteIndexChanged)
public:
    explicit Enemy7Bullet(QObject *parent = nullptr);
    ~Enemy7Bullet() override;

    void setStartPos(const QPointF &p) { setPos(p); origin = p; }
    void setDirection(double dx, double dy);
    Q_INVOKABLE void updateStep();

    int spriteIndex() const { return spriteIdx; }
    void setSpriteIndex(int value);

    signals:
            void backendDestroyed(Enemy7Bullet* self);
    void spriteIndexChanged();

private:
    QPointF origin{0,0};
    double dirx{0};
    double diry{0};
    double velocity{350};
    QTimer *updateTimer{nullptr};
    int spriteIdx{2};
};

#endif // ENEMY7_BULLET_H