#ifndef ENEMY1_H
#define ENEMY1_H

#include "../Enemy.h"

class Enemy1 : public Enemy {
	Q_OBJECT
public:
	explicit Enemy1(QObject *parent = nullptr);
	~Enemy1() override;

protected:
	int performAttack() override;           // 返回消耗的 MP
	int mpRegenRatePerSec() const override; // 1s 恢复 5%
};

#endif // ENEMY1_H
