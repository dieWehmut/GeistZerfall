#include "Enemy2Laser.h"
#include <QtMath>

Enemy2Laser::Enemy2Laser(QObject *parent) : Projectile(parent) {
	// 对于激光，将 maxDist 视为可渲染长度
	setMaxDist(length);
	setTraveledDist(0);
	timer = new QTimer(this);
	connect(timer, &QTimer::timeout, this, &Enemy2Laser::onTick);
	timer->start(30);
}

Enemy2Laser::~Enemy2Laser() {
	emit backendDestroyed(this);
}

void Enemy2Laser::setDirection(double dx, double dy) {
	double len = std::sqrt(dx*dx + dy*dy);
	if (len == 0) { dirx = 1; diry = 0; }
	else { dirx = dx/len; diry = dy/len; }
	emit beamChanged();
}

void Enemy2Laser::onTick() {
	durationMs -= 30;
	if (durationMs <= 0) {
		timer->stop();
		deleteLater();
		return;
	}
	// 对于激光，我们维持起点不变；QML 根据 dir 绘制
	emit beamChanged();
}
