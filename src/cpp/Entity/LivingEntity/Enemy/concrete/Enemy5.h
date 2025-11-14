#ifndef ENEMY5_H
#define ENEMY5_H

#include "../Enemy.h"

class Enemy5 : public Enemy {
    Q_OBJECT
public:
    explicit Enemy5(QObject *parent = nullptr);
    ~Enemy5() override;

protected:
    int performAttack() override;           // 发射追踪子弹
    int mpRegenRatePerSec() const override; // MP 恢复速率
};

#endif // ENEMY5_H