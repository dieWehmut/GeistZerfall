#include "PlayerLaser.h"
#include <QDebug>
#include <QtCore/QTimer>
#include <cmath>

PlayerLaser::PlayerLaser(QObject *parent) : Projectile(parent) {
    // Reduce visual travel speed and increase max distance so the laser remains visible longer
    setSpeed(48);
    setMaxDist(3000);
    setDamage(250);
    moveTimer = nullptr; // Initialize moveTimer
    if (!moveTimer) {
        moveTimer = new QTimer(this);
        moveTimer->setInterval(16);
    }
    connect(moveTimer, &QTimer::timeout, this, [this]() {
        double dx = vx * getSpeed();
        double dy = vy * getSpeed();
        QPointF p = getPos();
        QPointF np(p.x() + dx, p.y() + dy);
        setPos(np);
        traveledDist += std::sqrt(dx*dx + dy*dy);
        if (traveledDist >= getMaxDist()) {
            qDebug() << "PlayerLaser reached maxDist:" << traveledDist << "/" << getMaxDist() << " deleting" << this;
            stopTick();
            emit backendDestroyed(this);
            this->deleteLater();
        }
    });
}

PlayerLaser::~PlayerLaser() {
    stopTick();
}

void PlayerLaser::setDirection(double dx, double dy) {
    double len = std::sqrt(dx*dx + dy*dy);
    if (len == 0) { vx = 0; vy = -1; }
    else { vx = dx / len; vy = dy / len; }
    traveledDist = 0;
    startTick();
}

void PlayerLaser::startTick() {
    if (moveTimer && !moveTimer->isActive()) moveTimer->start();
}

void PlayerLaser::stopTick() {
    if (moveTimer && moveTimer->isActive()) moveTimer->stop();
}

void PlayerLaser::setDamage(int value) {
    if (laserDamage == value) return;
    laserDamage = value;
    emit damageChanged();
}