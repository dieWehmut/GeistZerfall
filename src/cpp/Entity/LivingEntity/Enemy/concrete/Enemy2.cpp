#include "Enemy2.h"
#include "Entity/Projectile/EnemyProjectile/Enemy2Laser.h"
#include <QtMath>
#include <QVariant>

Enemy2::Enemy2(QObject *parent) : Enemy(parent) {
	setSpeed(10);
	setSight(340);
	setMaxHp(1000);
	setHp(getMaxHp());
	setMaxMp(100);
	setMp(100);
	setAttackCooldownMs(1800); // 激光稍慢
	// aura damage per second (can be read from QML via backend.auraDPS or backend.auraDPS())
	setProperty("auraDPS", QVariant(20)); // 20 HP per second by default
}

Enemy2::~Enemy2() {}

int Enemy2::performAttack() {
	if (!playerTarget) return 0;
	int cost = qMax(1, getMaxMp() * 50 / 100); // 50%
	if (getMp() < cost) return 0;

	// 8 方向：上下左右 + 四个对角
	struct Dir { double x; double y; } dirs[8] = {
		{1,0},{-1,0},{0,1},{0,-1},{1,1},{-1,1},{1,-1},{-1,-1}
	};
	QPointF p = getPos();
	for (auto &d : dirs) {
		double len = std::sqrt(d.x*d.x + d.y*d.y);
		double nx = d.x / len;
		double ny = d.y / len;
		auto *laser = new Enemy2Laser(this->parent());
		laser->setStartPos(p);
		laser->setDirection(nx, ny);
		laser->setProperty("visualType", QVariant("laser"));
		emit enemyLaserCreated(laser);
	}
	return cost;
}

int Enemy2::mpRegenRatePerSec() const {
	return qMax(1, getMaxMp() * 10 / 100); // 每秒 10%
}

int Enemy2::auraDPS() const {
	// keep simple: return the same default as the dynamic property
	return 20;
}
