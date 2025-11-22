#include "Enemy5Bullet.h"
#include <QtMath>

Enemy5Bullet::Enemy5Bullet(QObject *parent) : Projectile(parent) {
    setMaxDist(800);
    setTraveledDist(0);
    updateTimer = new QTimer(this);
    updateTimer->setInterval(16); // 相同的更新频率
    connect(updateTimer, &QTimer::timeout, this, &Enemy5Bullet::updateStep);
    updateTimer->start();
}

Enemy5Bullet::~Enemy5Bullet() {
    emit backendDestroyed(this);
}

void Enemy5Bullet::setDirection(double dx, double dy) {
    double len = std::sqrt(dx*dx + dy*dy);
    if (len == 0) {
        dirx = 1;
        diry = 0;
    } else {
        dirx = dx / len;
        diry = dy / len;
    }
}

void Enemy5Bullet::updateStep() {
    if (playerTarget) {
        // 计算出子弹到玩家的向量
        QPointF currentPos = getPos();
        QPointF targetPos = playerTarget->getPos();
        double toTargetX = targetPos.x() - currentPos.x();
        double toTargetY = targetPos.y() - currentPos.y();
        double toTargetLen = std::sqrt(toTargetX*toTargetX + toTargetY*toTargetY);

        // 归一化目标方向
        if (toTargetLen > 0) {
            toTargetX /= toTargetLen;
            toTargetY /= toTargetLen;
        }

        // 平滑调整方向（追踪强度控制转向灵敏度）
        dirx = dirx * (1 - trackingStrength) + toTargetX * trackingStrength;
        diry = diry * (1 - trackingStrength) + toTargetY * trackingStrength;

        // 重新归一化方向向量（防止速度异常）
        double newDirLen = std::sqrt(dirx*dirx + diry*diry);
        if (newDirLen > 0) {
            dirx /= newDirLen;
            diry /= newDirLen;
        }
    }

    const double dt = 0.016;
    QPointF p = getPos();
    QPointF np(p.x() + dirx * velocity * dt, p.y() + diry * velocity * dt);
    setPos(np);

    double dx = np.x() - origin.x();
    double dy = np.y() - origin.y();
    double dist = std::sqrt(dx*dx + dy*dy);
    setTraveledDist(dist);

    if (dist >= getMaxDist()) {
        updateTimer->stop();
        deleteLater();
    }
}

void Enemy5Bullet::setSpriteIndex(int value) {
    int clamped = value;
    if (clamped < 1) clamped = 1;
    else if (clamped > 9) clamped = 9;
    if (spriteIdx == clamped) return;
    spriteIdx = clamped;
    emit spriteIndexChanged();
}