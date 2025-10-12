#include "PlayerBullet.h"
#include <QDebug>
#include <cmath>

PlayerBullet::PlayerBullet(QObject *parent) : Projectile(parent) {
    setSpeed(16);
    setMaxDist(400);
    // reuse inherited moveTimer (from Entity) to avoid duplicating timers
    if (!moveTimer) {
        moveTimer = new QTimer(this);
        moveTimer->setInterval(16);
    }
    connect(moveTimer, &QTimer::timeout, this, [this]() {
        // move according to vx, vy and speed
        double dx = vx * getSpeed();
        double dy = vy * getSpeed();
        QPointF p = getPos();
        QPointF np(p.x() + dx, p.y() + dy);
        setPos(np);
        traveledDist += std::sqrt(dx*dx + dy*dy);
        if (traveledDist >= getMaxDist()) {
            qDebug() << "PlayerBullet reached maxDist:" << traveledDist << "/" << getMaxDist() << " deleting" << this;
            stopTick();
            emit backendDestroyed(this);
            this->deleteLater();
        }
    });
}

PlayerBullet::~PlayerBullet() {
    stopTick();
}

void PlayerBullet::setDirection(double dx, double dy) {
    double len = std::sqrt(dx*dx + dy*dy);
    if (len == 0) { vx = 0; vy = -1; }
    else { vx = dx / len; vy = dy / len; }
    traveledDist = 0;
    // start movement
    startTick();
}

void PlayerBullet::startTick() {
    if (moveTimer && !moveTimer->isActive()) moveTimer->start();
}

void PlayerBullet::stopTick() {
    if (moveTimer && moveTimer->isActive()) moveTimer->stop();
}