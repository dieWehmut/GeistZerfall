#ifndef ENEMY7_H
#define ENEMY7_H

#include "../Enemy.h"

class Enemy7 : public Enemy {
    Q_OBJECT
public:
    explicit Enemy7(QObject *parent = nullptr);
    ~Enemy7() override;

protected:
    int performAttack() override;           // 高频发射散射子弹
    int mpRegenRatePerSec() const override; // 更高的MP恢复效率
};

#endif // ENEMY7_H