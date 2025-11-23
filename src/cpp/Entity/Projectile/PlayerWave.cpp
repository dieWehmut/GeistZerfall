#include "PlayerWave.h"
#include <QDebug>
#include <QTimer>
#include <cmath>

PlayerWave::PlayerWave(QObject *parent) : Projectile(parent) {
    setSpeed(8);
    setMaxDist(1200);
    setDamage(waveDamage);
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
        // update rotation (degrees) every tick
        double angleDeg = std::atan2(vy, vx) * 180.0 / M_PI;
        setRotation(angleDeg);
        traveledDist += std::sqrt(dx*dx + dy*dy);
        // Wave only dies when it reaches its max distance
        if (traveledDist >= getMaxDist()) {
            qDebug() << "PlayerWave reached maxDist:" << traveledDist << "/" << getMaxDist() << " deleting" << this;
            stopTick();
            emit backendDestroyed(this);
            this->deleteLater();
        }
    });
}

PlayerWave::~PlayerWave() {
    stopTick();
}

void PlayerWave::setDirection(double dx, double dy) {
    double len = std::sqrt(dx*dx + dy*dy);
    if (len == 0) { vx = 0; vy = -1; }
    else { vx = dx / len; vy = dy / len; }
    // update rotation (degrees)
    double angleDeg = std::atan2(vy, vx) * 180.0 / M_PI;
    setRotation(angleDeg);
    traveledDist = 0;
    startTick();
}

void PlayerWave::setRotation(double value) {
    if (waveRotation == value) return;
    waveRotation = value;
    emit rotationChanged();
}

void PlayerWave::startTick() {
    if (moveTimer && !moveTimer->isActive()) moveTimer->start();
}

void PlayerWave::stopTick() {
    if (moveTimer && moveTimer->isActive()) moveTimer->stop();
}

void PlayerWave::setDamage(int value) {
    if (waveDamage == value) return;
    waveDamage = value;
    emit damageChanged();
}
