#include "Enemy6Bullet.h"
#include <QtMath>

Enemy6Bullet::Enemy6Bullet(QObject *parent) : Projectile(parent) {
  setMaxDist(750);
  setTraveledDist(0);
  updateTimer = new QTimer(this);
  updateTimer->setInterval(16);
  connect(updateTimer, &QTimer::timeout, this, &Enemy6Bullet::updateStep);
  updateTimer->start();
}

Enemy6Bullet::~Enemy6Bullet() { emit backendDestroyed(this); }

void Enemy6Bullet::setDirection(double dx, double dy) {
  double len = std::sqrt(dx * dx + dy * dy);
  if (len == 0) {
    dirx = 1;
    diry = 0;
  } else {
    dirx = dx / len;
    diry = dy / len;
  }
}

void Enemy6Bullet::updateStep() {
  // 每 tick 移动 velocity * dt
  const double dt = 0.016; // 假定 ~60FPS
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

void Enemy6Bullet::setSpriteIndex(int value) {
  int clamped = value;
  if (clamped < 1)
    clamped = 1;
  else if (clamped > 12)
    clamped = 12;
  if (spriteIdx == clamped)
    return;
  spriteIdx = clamped;
  emit spriteIndexChanged();
}
