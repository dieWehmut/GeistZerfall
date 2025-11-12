#include "Enemy3MotherBullet.h"
#include "Enemy3ChildBullet.h"
#include <QVariant>
#include <QtMath>
#include <cmath>

Enemy3MotherBullet::Enemy3MotherBullet(QObject *parent) : Projectile(parent) {
  setMaxDist(1500);
  setTraveledDist(0);
  flightTimeMs = 0;
  updateTimer = new QTimer(this);
  updateTimer->setInterval(16);
  connect(updateTimer, &QTimer::timeout, this, &Enemy3MotherBullet::updateStep);
  updateTimer->start();
}

Enemy3MotherBullet::~Enemy3MotherBullet() { emit backendDestroyed(this); }

void Enemy3MotherBullet::setDirection(double dx, double dy) {
  double len = std::sqrt(dx * dx + dy * dy);
  if (len == 0) {
    dirx = 1;
    diry = 0;
  } else {
    dirx = dx / len;
    diry = dy / len;
  }
}

void Enemy3MotherBullet::updateStep() {
  flightTimeMs += 16;

  // 检查是否到达分裂时间
  if (flightTimeMs >= splitTimeMs && flightTimeMs < splitTimeMs + 16) {
    performSplit();
    updateTimer->stop();
    deleteLater();
    return;
  }

  // 每tick移动velocity * dt
  const double dt = 0.016; // 假定~60FPS
  QPointF p = getPos();
  QPointF np(p.x() + dirx * velocity * dt, p.y() + diry * velocity * dt);
  setPos(np);
  double dx = np.x() - origin.x();
  double dy = np.y() - origin.y();
  double dist = std::sqrt(dx * dx + dy * dy);
  setTraveledDist(dist);

  // 如果超出最大距离，也删除
  if (dist >= getMaxDist()) {
    updateTimer->stop();
    deleteLater();
  }
}

void Enemy3MotherBullet::performSplit() {
  QPointF splitPos = getPos();
  // 分裂成16个方向的小子弹
  const int childCount = 16;
  const double angleStep = 360.0 / childCount;

  for (int i = 0; i < childCount; ++i) {
    double angleDeg = i * angleStep;
    double angleRad = qDegreesToRadians(angleDeg);
    double dirx = std::cos(angleRad);
    double diry = std::sin(angleRad);
    auto *child = new Enemy3ChildBullet(this->parent());
    child->setStartPos(splitPos);
    child->setDirection(dirx, diry);
    child->setProperty("visualType", QVariant("childBullet"));
    emit childBulletsCreated(child);
  }
}
