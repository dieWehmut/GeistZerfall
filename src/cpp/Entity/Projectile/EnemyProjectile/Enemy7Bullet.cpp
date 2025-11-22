#include "Enemy7Bullet.h"
#include <QtMath>

Enemy7Bullet::Enemy7Bullet(QObject *parent) : Projectile(parent) {
    setMaxDist(600);
    setTraveledDist(0);
    updateTimer = new QTimer(this);
    updateTimer->setInterval(16); // 60FPS更新
    connect(updateTimer, &QTimer::timeout, this, &Enemy7Bullet::updateStep);
    updateTimer->start();
}

Enemy7Bullet::~Enemy7Bullet() {
    emit backendDestroyed(this);
}

void Enemy7Bullet::setDirection(double dx, double dy) {
    double len = std::sqrt(dx*dx + dy*dy);
    if (len == 0) {
        dirx = 1;
        diry = 0;
    } else {
        dirx = dx / len;
        diry = dy / len;
    }
}

void Enemy7Bullet::updateStep() {
    const double dt = 0.016; // 16ms步长
    QPointF p = getPos();
    QPointF np(p.x() + dirx * velocity * dt, p.y() + diry * velocity * dt);
    setPos(np);

    // 更新已移动距离
    double dx = np.x() - origin.x();
    double dy = np.y() - origin.y();
    double dist = std::sqrt(dx*dx + dy*dy);
    setTraveledDist(dist);

    // 超出射程销毁
    if (dist >= getMaxDist()) {
        updateTimer->stop();
        deleteLater();
    }
}

void Enemy7Bullet::setSpriteIndex(int value) {
    int clamped = value;
    if (clamped < 1) clamped = 1;
    else if (clamped > 9) clamped = 9;
    if (spriteIdx == clamped) return;
    spriteIdx = clamped;
    emit spriteIndexChanged();
}