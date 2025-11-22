#include "Enemy5.h"
#include "Entity/Projectile/EnemyProjectile/Enemy5Bullet.h"
#include <QtMath>
#include <QVariant>

Enemy5::Enemy5(QObject *parent) : Enemy(parent) {
    setSpeed(6);
    setSight(600);
    setMaxHp(1000);
    setHp(getMaxHp());
    setMaxMp(100);
    setMp(100);
    setAttackCooldownMs(1000);
}

Enemy5::~Enemy5() {}

int Enemy5::performAttack() {
    if (!playerTarget) return 0; // 无目标时不攻击

    // 攻击消耗：最大 MP 的 20%（低于 Enemy1，适配单颗子弹）
    const int cost = qMax(1, getMaxMp() * 20 / 100);
    if (getMp() < cost) return 0;

    // 计算朝向玩家的初始方向
    QPointF enemyPos = getPos();
    QPointF playerPos = playerTarget->getPos();
    double dx = playerPos.x() - enemyPos.x();
    double dy = playerPos.y() - enemyPos.y();

    // 创建单颗追踪子弹
    auto *bullet = new Enemy5Bullet(this->parent());
    bullet->setStartPos(enemyPos);
    bullet->setDirection(dx, dy); // 直接使用原始向量，内部会归一化
    bullet->setTarget(playerTarget); // 关键：设置追踪目标
    bullet->setSpriteIndex(1); // 单颗子弹固定使用第1帧（或按需求调整）
    bullet->setProperty("visualType", QVariant("bullet"));

    emit enemyProjectileCreated(bullet);

    return cost; // 返回 MP 消耗
}

int Enemy5::mpRegenRatePerSec() const {
    return qMax(1, getMaxMp() * 6 / 100);
}