#include "Enemy1.h"
#include "Entity/Projectile/EnemyProjectile/Enemy1Bullet.h"
#include <QtMath>
#include <QVariant>

Enemy1::Enemy1(QObject *parent) : Enemy(parent) {
	setSpeed(6);
	setSight(360);
	setMaxHp(80);
	setHp(80);
	setMaxMp(100);
	setMp(100);
	setAttackCooldownMs(1200);
}

Enemy1::~Enemy1() {}

int Enemy1::performAttack() {
	if (!playerTarget) return 0;
	const int cost = qMax(1, getMaxMp() * 25 / 100); // 25%
	if (getMp() < cost) return 0;

	// 计算朝向玩家的向量
	QPointF p = getPos();
	QPointF t = playerTarget->getPos();
	double dx = t.x() - p.x();
	double dy = t.y() - p.y();
	double baseAngle = std::atan2(dy, dx); // 弧度

	const double angleOffsetsDeg[9] = { 0.0, 7.5, 15.0, 22.5, 30.0, -7.5, -15.0, -22.5, -30.0 };
	for (int i = 0; i < 9; ++i) {
		double angleRad = baseAngle + qDegreesToRadians(angleOffsetsDeg[i]);
		double dirx = std::cos(angleRad);
		double diry = std::sin(angleRad);
		auto *b = new Enemy1Bullet(this->parent());
		b->setStartPos(p);
		b->setDirection(dirx, diry);
		b->setSpriteIndex(i + 1);
		b->setProperty("visualType", QVariant("bullet"));
		emit enemyProjectileCreated(b);
	}
	return cost;
}

int Enemy1::mpRegenRatePerSec() const {
	// 1s 恢复 5%
	return qMax(1, getMaxMp() * 5 / 100);
}
