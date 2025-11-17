#ifndef ENEMY6_H
#define ENEMY6_H

#include "../Enemy.h"

// 敌人6：向周围6个方向发射子弹，每个方向两个子弹
class Enemy6 : public Enemy {
  Q_OBJECT
public:
  explicit Enemy6(QObject *parent = nullptr);
  ~Enemy6() override;

protected:
  int performAttack() override;           // 返回消耗的 MP
  int mpRegenRatePerSec() const override; // 每秒恢复的MP
};

#endif // ENEMY6_H
