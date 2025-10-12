#include "Player.h"
#include <QDebug>
#include <QtCore/QTimer>
#include <QVariant>
#include <cmath>
#include "../../Manager/SaveLoadManager/SaveData.h"
#include "../Projectile/PlayerBullet.h"
#include "../Projectile/PlayerLaser.h"
Player::Player(QObject *parent) : Entity(parent) {
	setSpeed(36);
	setSight(400);
	setMaxHp(100);
	setHp(getMaxHp());
	// Initialize cooldowns explicitly here (so defaults are set in C++ source)
}

Player::~Player() {
}

void Player::shoot(double px, double py, double dirx, double diry) {
	// create backend bullet and notify QML to create visual bound to it
	qDebug() << "Player::shoot called px,py,dir:" << px << py << dirx << diry;
	PlayerBullet *b = new PlayerBullet(this->parent());
	// use provided world coordinates as start pos
	b->setStartPos(QPointF(px, py));
	b->setDirection(dirx, diry);
	qDebug() << "Player::shoot created bullet" << b << "start pos" << QPointF(px, py);
	// when backend bullet is destroyed, we don't need to do extra cleanup here
	connect(b, &PlayerBullet::backendDestroyed, this, [this](PlayerBullet* self){ Q_UNUSED(self); qDebug() << "Player::shoot: backendDestroyed for" << self; });
	// tag visual type so QML can create appropriate visual
	b->setProperty("visualType", QVariant("bullet"));
	emit playerBulletCreated(b);
}

// removed obsolete no-arg snipe() implementation; use snipe(px,py,dirx,diry) instead

void Player::snipeStart() {
	if (snipeActive) return;
	snipeActive = true;
	savedSight = getSight();
	setSight(savedSight * 2.0);
	// save and reduce speed to half while snipe is active
	savedSpeed = getSpeed();
	setSpeed(savedSpeed * 0.25);
	emit snipeChanged();
}

void Player::shootStart() {
	if (shootingActive) return;
	shootingActive = true;
	savedSpeed = getSpeed();
	setSpeed(savedSpeed * 0.25);
}

void Player::shootStop() {
	if (!shootingActive) return;
	shootingActive = false;
	setSpeed(savedSpeed);
}

void Player::snipeStop() {
	if (!snipeActive) return;
	snipeActive = false;
	setSight(savedSight);
	// restore speed when snipe stops
	setSpeed(savedSpeed);
	emit snipeChanged();
}

void Player::snipe(double px, double py, double dirx, double diry) {
	qDebug() << "Player::snipe called px,py,dir:" << px << py << dirx << diry;
	PlayerLaser *l = new PlayerLaser(this->parent());
	l->setStartPos(QPointF(px, py));
	l->setDirection(dirx, diry);
	// expose start coordinates so QML visuals can draw beam from origin to current pos
	l->setProperty("startX", QVariant(px));
	l->setProperty("startY", QVariant(py));
	connect(l, &PlayerLaser::backendDestroyed, this, [this](PlayerLaser* self){ Q_UNUSED(self); qDebug() << "Player::snipe: backendDestroyed for" << self; });
	l->setProperty("visualType", QVariant("laser"));
	emit playerLaserCreated(l);
}

PlayerSaveData Player::toSaveData() const {
	PlayerSaveData d;
	d.pos = getPos();
	d.speed = getSpeed();
	d.sight = getSight();
	return d;
}

void Player::loadFromSaveData(const PlayerSaveData &data) {
	setPos(data.pos);
	setSpeed(data.speed);
	setSight(data.sight);
}




