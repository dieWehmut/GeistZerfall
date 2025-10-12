#include "Entity.h"
#include <cmath>

Entity::Entity(QObject *parent) : QObject(parent), pos(0, 0), speed(0) {
	
}
Entity::~Entity() {}

void Entity::setPos(const QPointF &newPos) {
	if (pos != newPos) {
		pos = newPos;
		emit posChanged();
	}
}
void Entity::move(int dx, int dy) {
	dirX = dx;
	dirY = dy;
	if (dirX == 0 && dirY == 0) {
		if (moveTimer && moveTimer->isActive()) moveTimer->stop();
		return;
	}

	if (!moveTimer) {
		moveTimer = new QTimer(this);
		moveTimer->setInterval(moveIntervalMs);
		connect(moveTimer, &QTimer::timeout, this, [this]() {
			QPointF p = getPos();
			double dirLen = std::sqrt(double(dirX*dirX + dirY*dirY));
			double ndx = 0, ndy = 0;
			if (dirLen > 0) {
				ndx = dirX / dirLen;
				ndy = dirY / dirLen;
			}
			QPointF np(p.x() + ndx * speed, p.y() + ndy * speed);
			double clampedX = np.x();
			double clampedY = np.y();
			if (mapWidth > 0) {
				if (clampedX < 0) clampedX = 0;
				if (clampedX > mapWidth) clampedX = mapWidth;
			}
			if (mapHeight > 0) {
				if (clampedY < 0) clampedY = 0;
				if (clampedY > mapHeight) clampedY = mapHeight;
			}
			setPos(QPointF(clampedX, clampedY));
		});
	}

	if (moveTimer && !moveTimer->isActive()) moveTimer->start();
}