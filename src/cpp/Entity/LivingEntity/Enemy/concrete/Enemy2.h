#ifndef ENEMY2_H
#define ENEMY2_H

#include "../Enemy.h"

class Enemy2 : public Enemy {
	Q_OBJECT
public:
	explicit Enemy2(QObject *parent = nullptr);
	~Enemy2() override;

    Q_INVOKABLE int auraDPS() const;
protected:
	int performAttack() override;            // 8 方向激光
	int mpRegenRatePerSec() const override;  // 1s 恢复 10%
};

#endif // ENEMY2_H
