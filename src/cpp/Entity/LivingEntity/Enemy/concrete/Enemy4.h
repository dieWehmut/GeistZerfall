#ifndef ENEMY4_H
#define ENEMY4_H

#include "../Enemy.h"

// 敌人4：机关枪，连续射出几个子弹
class Enemy4 : public Enemy {
  Q_OBJECT
public:
  explicit Enemy4(QObject *parent = nullptr);
  ~Enemy4() override;

protected:
  int performAttack() override;           // 返回消耗的 MP
  int mpRegenRatePerSec() const override; // 每秒恢复的MP
};

#endif // ENEMY4_H
