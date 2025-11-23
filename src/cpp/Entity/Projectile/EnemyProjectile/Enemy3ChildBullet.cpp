#include "Enemy3ChildBullet.h"
#include <QtMath>
#include <cmath>

Enemy3ChildBullet::Enemy3ChildBullet(QObject *parent) : Projectile(parent) {
  setMaxDist(500);
  setTraveledDist(0);
  updateTimer = new QTimer(this);
  updateTimer->setInterval(16);
  connect(updateTimer, &QTimer::timeout, this, &Enemy3ChildBullet::updateStep);
  updateTimer->start();
}

Enemy3ChildBullet::~Enemy3ChildBullet() { emit backendDestroyed(this); }

void Enemy3ChildBullet::setDirection(double dx, double dy) {
  double len = std::sqrt(dx * dx + dy * dy);
  if (len == 0) {
    dirx = 1;
    diry = 0;
  } else {
    dirx = dx / len;
    diry = dy / len;
  }
}

void Enemy3ChildBullet::updateStep() {
  const double dt = 0.016; // 假定~60FPS
  QPointF p = getPos();
  QPointF np(p.x() + dirx * velocity * dt, p.y() + diry * velocity * dt);
  setPos(np);
  double dx = np.x() - origin.x();
  double dy = np.y() - origin.y();
  double dist = std::sqrt(dx * dx + dy * dy);
  setTraveledDist(dist);
  if (dist >= getMaxDist()) {
    updateTimer->stop();
    deleteLater();
  }
}
