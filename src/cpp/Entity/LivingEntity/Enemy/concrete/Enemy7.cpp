#include "Enemy7.h"
#include "Entity/Projectile/EnemyProjectile/Enemy7Bullet.h"
#include <QtMath>
#include <QVariant>
#include <cstdlib>

Enemy7::Enemy7(QObject *parent) : Enemy(parent) {
    setSpeed(16);
    setSight(450);         // 视野略大，更早开始攻击
    setMaxHp(1500);         // 生命值略高，提升生存能力
    setHp(getMaxHp());
    setMaxMp(250);         // 更高的MP上限支撑更密集火力
    setMp(250);
    setAttackCooldownMs(300);
}

Enemy7::~Enemy7() {}

int Enemy7::performAttack() {
    if (!playerTarget) return 0;

    // 单次攻击消耗4% MP（更低消耗，维持高频）
    const int cost = qMax(1, getMaxMp() * 4 / 100);
    if (getMp() < cost) return 0;

    QPointF enemyPos = getPos();
    QPointF playerPos = playerTarget->getPos();
    double dx = playerPos.x() - enemyPos.x();
    double dy = playerPos.y() - enemyPos.y();
    double baseAngle = std::atan2(dy, dx); // 基础朝向玩家


    const int bulletCount = 4;
    const double maxAngleOffset = qDegreesToRadians(12.0);

    for (int i = 0; i < bulletCount; ++i) {
        // 随机偏移角度（-12度到+12度）
        double randomOffset = (rand() % 100) / 100.0 * 2 * maxAngleOffset - maxAngleOffset;
        double angle = baseAngle + randomOffset;

        // 计算单位方向向量
        double dirx = std::cos(angle);
        double diry = std::sin(angle);

        // 创建并发射子弹
        auto *bullet = new Enemy7Bullet(this->parent());
        bullet->setStartPos(enemyPos);
        bullet->setDirection(dirx, diry);
        bullet->setSpriteIndex(2); // 使用不同的精灵索引区分外观
        bullet->setProperty("visualType", QVariant("bullet"));

        emit enemyProjectileCreated(bullet);
    }

    return cost;
}

int Enemy7::mpRegenRatePerSec() const {
    // 每秒恢复20% MP（比Enemy6更高，支撑更密集的消耗）
    return qMax(1, getMaxMp() * 20 / 100);
}