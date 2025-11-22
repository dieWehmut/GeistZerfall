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
	// teleport-behind-player feature
	void initiateMoveBehind(); // compute behind target and start moving toward it

private:
	QTimer *teleportTimer{nullptr};
	QTimer *teleportDelayTimer{nullptr};
	bool teleportPending{false};
	QTimer *ownLogicTimer{nullptr};
	QPointF behindTarget{0,0};
	bool movingToBehind{false};
	int behindMoveTimeoutMs{3000}; // stop trying after this time
	QTimer *behindStopTimer{nullptr};

signals:
	void aboutToTeleport(const QPointF &target);
	void teleported(const QPointF &newPos);
};

#endif // ENEMY1_H
