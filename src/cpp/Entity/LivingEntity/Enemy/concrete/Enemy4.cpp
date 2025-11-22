#include "Enemy4.h"
#include "Entity/Projectile/EnemyProjectile/Enemy4Bullet.h"
#include <QTimer>
#include <QVariant>
#include <QtMath>

Enemy4::Enemy4(QObject *parent) : Enemy(parent) {
  setSpeed(6);
  setSight(360);
  setMaxHp(2000);
  setHp(getMaxHp());
  setMaxMp(100);
  setMp(100);
  setAttackCooldownMs(2000); // 机关枪攻击冷却2秒
}

Enemy4::~Enemy4() {}

int Enemy4::performAttack() {
  if (!playerTarget)
    return 0;
  const int cost = qMax(1, getMaxMp() * 30 / 100); // 30% MP
  if (getMp() < cost)
    return 0;

  // 计算朝向玩家的向量
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

  // 机关枪：连续射出5个子弹，每个子弹间隔100ms
  const int bulletCount = 5;
  const int intervalMs = 100;

  for (int i = 0; i < bulletCount; ++i) {
    // 使用QTimer延迟发射，创建子弹
    QTimer::singleShot(i * intervalMs, this, [this, p, dx, dy, i]() {
      auto *b = new Enemy4Bullet(this->parent());
      b->setStartPos(p);
      b->setDirection(dx, dy);
      b->setSpriteIndex(i + 1); // 图片 (1-5)
      b->setProperty("visualType", QVariant("bullet"));
      emit enemyProjectileCreated(b);
    });
  }

  return cost;
}

int Enemy4::mpRegenRatePerSec() const {
  // 每秒恢复 8% MP
  return qMax(1, getMaxMp() * 8 / 100);
}
