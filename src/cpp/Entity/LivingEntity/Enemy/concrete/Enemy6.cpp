#include "Enemy6.h"
#include "Entity/Projectile/EnemyProjectile/Enemy6Bullet.h"
#include <QVariant>
#include <QtMath>

Enemy6::Enemy6(QObject *parent) : Enemy(parent) {
  setSpeed(5);
  setSight(380);
  setMaxHp(110);
  setHp(110);
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

  // 6个方向：每60度一个方向（0°, 60°, 120°, 180°, 240°, 300°）
  const int directions = 6;
  const double angleStep = 360.0 / directions; // 60度
  const double spreadAngle = 15.0; // 每个方向两个子弹之间的角度差（15度）

  int bulletIndex = 1;
  for (int i = 0; i < directions; ++i) {
    double baseAngle = qDegreesToRadians(i * angleStep);

    // 每个方向发射两个子弹，带角度差
    for (int j = 0; j < 2; ++j) {
      double offset = (j == 0) ? -spreadAngle / 2 : spreadAngle / 2;
      double angleRad = baseAngle + qDegreesToRadians(offset);
      double dirx = std::cos(angleRad);
      double diry = std::sin(angleRad);

      auto *b = new Enemy6Bullet(this->parent());
      b->setStartPos(p);
      b->setDirection(dirx, diry);
      b->setSpriteIndex(bulletIndex); //图片 (1-12)
      b->setProperty("visualType", QVariant("bullet"));
      emit enemyProjectileCreated(b);
      bulletIndex++;
    }
  }

  return cost;
}

int Enemy6::mpRegenRatePerSec() const {
  // 每秒恢复 7% MP
  return qMax(1, getMaxMp() * 7 / 100);
}
