#ifndef ENEMY1_BULLET_H
#define ENEMY1_BULLET_H

#include "Entity/Projectile/Projectile.h"
#include <QElapsedTimer>
#include <QTimer>

class Enemy1Bullet : public Projectile {
	Q_OBJECT
	Q_PROPERTY(int spriteIndex READ spriteIndex WRITE setSpriteIndex NOTIFY spriteIndexChanged)
public:
	explicit Enemy1Bullet(QObject *parent = nullptr);
	~Enemy1Bullet() override;

	void setStartPos(const QPointF &p) { setPos(p); origin = p; }
	void setDirection(double dx, double dy); // 归一化并设置
	Q_INVOKABLE void updateStep();

	int spriteIndex() const { return spriteIdx; }
	void setSpriteIndex(int value);

signals:
	void backendDestroyed(Enemy1Bullet* self);
	void spriteIndexChanged();

private:
	QPointF origin{0,0};
	double dirx{0};
	double diry{0};
	double velocity{800}; // 每秒像素
	QTimer *updateTimer{nullptr};
	int spriteIdx{1};
};

#endif // ENEMY1_BULLET_H
