#include "Enemy4Bullet.h"
#include <QtMath>

Enemy4Bullet::Enemy4Bullet(QObject *parent) : Projectile(parent) {
  setMaxDist(1000);
  setTraveledDist(0);
  updateTimer = new QTimer(this);
  updateTimer->setInterval(16);
  connect(updateTimer, &QTimer::timeout, this, &Enemy4Bullet::updateStep);
  updateTimer->start();
}

Enemy4Bullet::~Enemy4Bullet() { emit backendDestroyed(this); }

void Enemy4Bullet::setDirection(double dx, double dy) {
  double len = std::sqrt(dx * dx + dy * dy);
  if (len == 0) {
    dirx = 1;
    diry = 0;
  } else {
    dirx = dx / len;
    diry = dy / len;
  }
}

void Enemy4Bullet::updateStep() {
  // 每 tick 移动 velocity * dt
  const double dt = 0.016; 
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

void Enemy4Bullet::setSpriteIndex(int value) {
  int clamped = value;
  if (clamped < 1)
    clamped = 1;
  else if (clamped > 5)
    clamped = 5;
  if (spriteIdx == clamped)
    return;
  spriteIdx = clamped;
  emit spriteIndexChanged();
}
