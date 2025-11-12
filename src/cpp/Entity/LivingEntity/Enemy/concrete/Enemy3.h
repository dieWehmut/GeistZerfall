#ifndef ENEMY3_H
#define ENEMY3_H

#include "../Enemy.h"

// 敌人3：会发射一颗大型"母弹"，母弹飞行2秒后，会"分裂"成小型子弹，朝四周散开
class Enemy3 : public Enemy {
  Q_OBJECT
public:
  explicit Enemy3(QObject *parent = nullptr);
  ~Enemy3() override;

protected:
  int performAttack() override;           // 发射母弹
  int mpRegenRatePerSec() const override; // 每秒恢复的MP
};

#endif // ENEMY3_H
