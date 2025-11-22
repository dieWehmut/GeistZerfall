#ifndef ENEMY5_BULLET_H
#define ENEMY5_BULLET_H

#include "Entity/Projectile/Projectile.h"
#include <QTimer>
#include <QPointer>
#include "Entity/LivingEntity/Player.h" // 引入玩家类用于追踪

class Enemy5Bullet : public Projectile {
    Q_OBJECT
    Q_PROPERTY(int spriteIndex READ spriteIndex WRITE setSpriteIndex NOTIFY spriteIndexChanged)
public:
    explicit Enemy5Bullet(QObject *parent = nullptr);
    ~Enemy5Bullet() override;

    void setStartPos(const QPointF &p) { setPos(p); origin = p; }
    void setDirection(double dx, double dy);
    // 新增：设置追踪目标（玩家）
    void setTarget(Player* target) { playerTarget = target; }
    Q_INVOKABLE void updateStep();

    int spriteIndex() const { return spriteIdx; }
    void setSpriteIndex(int value);

    signals:
            void backendDestroyed(Enemy5Bullet* self);
    void spriteIndexChanged();

private:
    QPointF origin{0,0};
    double dirx{0};
    double diry{0};
    double velocity{800};
    double trackingStrength{0.2}; // 追踪强度（0-1，值越小转向越平滑）
    QTimer *updateTimer{nullptr};
    int spriteIdx{1};
    QPointer<Player> playerTarget; // 追踪目标（自动处理空指针）
};

#endif // ENEMY5_BULLET_H