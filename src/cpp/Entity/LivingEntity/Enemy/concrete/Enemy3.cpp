#include "Enemy3.h"
#include "Entity/Projectile/EnemyProjectile/Enemy3MotherBullet.h"
#include <QVariant>
#include <QtMath>
#include <cmath>

Enemy3::Enemy3(QObject *parent) : Enemy(parent) {
  setSpeed(5);
  setSight(420);
  setMaxHp(130);
  setHp(130);
  setMaxMp(100);
  setMp(100);
  setAttackCooldownMs(3000); // 母弹攻击冷却3秒
}

Enemy3::~Enemy3() {}

int Enemy3::performAttack() {
  if (!playerTarget)
    return 0;
  const int cost = qMax(1, getMaxMp() * 45 / 100); // 消耗45%MP
  if (getMp() < cost)
    return 0;

  // 计算朝向玩家的方向
  QPointF p = getPos();
  QPointF t = playerTarget->getPos();
  double dx = t.x() - p.x();
  double dy = t.y() - p.y();
  double len = std::sqrt(dx * dx + dy * dy);
  if (len == 0) {
    dx = 1;
    dy = 0;
  } else {
    dx /= len;
    dy /= len;
  }

  // 创建母弹
  auto *mother = new Enemy3MotherBullet(this->parent());
  mother->setStartPos(p);
  mother->setDirection(dx, dy);
  mother->setProperty("visualType", QVariant("motherBullet"));
  emit enemyProjectileCreated(mother);

  return cost;
}

int Enemy3::mpRegenRatePerSec() const {
  // 每秒恢复6%MP
  return qMax(1, getMaxMp() * 6 / 100);
}
