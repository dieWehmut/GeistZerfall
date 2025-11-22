#include "Enemy6.h"
#include "Entity/Projectile/EnemyProjectile/Enemy6Laser.h"
#include <QVariant>
#include <QtMath>

Enemy6::Enemy6(QObject *parent) : Enemy(parent) {
  setSpeed(7);
  setSight(380);
  setMaxHp(1200);
  setHp(getMaxHp());
  setMaxMp(100);
  setMp(100);
  setAttackCooldownMs(2500); // 攻击冷却2.5秒
}

Enemy6::~Enemy6() {}

int Enemy6::performAttack() {
  if (!playerTarget)
    return 0;
  const int cost = qMax(1, getMaxMp() * 35 / 100); // 35% MP
  if (getMp() < cost)
    return 0;

  QPointF p = getPos();
  QPointF t = playerTarget->getPos();

  // 计算朝向玩家的方向
  double dx = t.x() - p.x();
  double dy = t.y() - p.y();
  double len = std::sqrt(dx * dx + dy * dy);
  if (len == 0) {
    dx = 1;
    dy = 0;
  } else {
    dx = dx / len;
    dy = dy / len;
  }

  // 向玩家方向发射一个波形光波
  auto *laser = new Enemy6Laser(this->parent());
  laser->setStartPos(p);
  laser->setDirection(dx, dy);
  laser->setProperty("visualType", QVariant("laser"));
  emit enemyLaserCreated(laser);

  return cost;
}

int Enemy6::mpRegenRatePerSec() const {
  // 每秒恢复 7% MP
  return qMax(1, getMaxMp() * 7 / 100);
}
