#include "Enemy1.h"
#include "Entity/Projectile/EnemyProjectile/Enemy1Bullet.h"
#include <QtMath>
#include <QVariant>
#include <QDebug>

Enemy1::Enemy1(QObject *parent) : Enemy(parent) {
	setSpeed(6);
	setSight(360);
	setMaxHp(1000);
	setHp(getMaxHp());
	setMaxMp(100);
	setMp(100);
	setAttackCooldownMs(1200);

	// create a teleport-behind-player timer (fires every 5s)
	teleportTimer = new QTimer(this);
	teleportTimer->setInterval(5000);
	connect(teleportTimer, &QTimer::timeout, this, &Enemy1::initiateMoveBehind);
	teleportTimer->start();

	// create an owning logic timer so we can temporarily direct movement to behindTarget
	// stop base logicTimer (created in Enemy) to avoid duplicate movement; then provide equivalent behavior
	if (logicTimer && logicTimer->isActive()) logicTimer->stop();
	ownLogicTimer = new QTimer(this);
	ownLogicTimer->setInterval(20);
	connect(ownLogicTimer, &QTimer::timeout, this, [this]() {
		if (!alive) return;
		// if currently moving to behind target, move towards it
		if (movingToBehind) {
			QPointF p = getPos();
			double dx = behindTarget.x() - p.x();
			double dy = behindTarget.y() - p.y();
			double dist = std::sqrt(dx*dx + dy*dy);
			if (dist <= 8.0) {
				// reached target
				movingToBehind = false;
				if (behindStopTimer && behindStopTimer->isActive()) behindStopTimer->stop();
			} else {
				// request movement toward behindTarget
				move(int(std::round(dx)), int(std::round(dy)));
			}
		} else {
			// default chase behavior
			chasePlayerStep();
		}
		// attack attempts run regardless
		tryAttack();
	});
	ownLogicTimer->start();

	behindStopTimer = new QTimer(this);
	behindStopTimer->setSingleShot(true);
	connect(behindStopTimer, &QTimer::timeout, this, [this]() { movingToBehind = false; });
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

void Enemy1::initiateMoveBehind() {
	if (!playerTarget) return;
	// Instant teleport: compute the symmetric point across the player (reflection)
	// newPos = 2 * playerPos - enemyPos, which lies on the extension of the line and
	// is at the same distance from the player as the enemy currently is.
	QPointF p = getPos();
	QPointF t = playerTarget->getPos();
	double newX = 2.0 * t.x() - p.x();
	double newY = 2.0 * t.y() - p.y();
	// clamp to map boundaries
	if (getMapWidth() > 0) {
		if (newX < 0) newX = 0;
		if (newX > getMapWidth()) newX = getMapWidth();
	}
	if (getMapHeight() > 0) {
		if (newY < 0) newY = 0;
		if (newY > getMapHeight()) newY = getMapHeight();
	}

	setPos(QPointF(newX, newY));
	qDebug() << "Enemy1: teleported to" << QPointF(newX, newY);
}
