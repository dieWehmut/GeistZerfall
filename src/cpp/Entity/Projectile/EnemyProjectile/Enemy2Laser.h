#ifndef ENEMY2_LASER_H
#define ENEMY2_LASER_H

#include "Entity/Projectile/Projectile.h"
#include <QTimer>

// 简化：激光为短暂存在的“瞬发直线”，存在一个持续时间，并不断更新其末端点。
class Enemy2Laser : public Projectile {
	Q_OBJECT
public:
	explicit Enemy2Laser(QObject *parent = nullptr);
	~Enemy2Laser() override;

	void setStartPos(const QPointF &p) { setPos(p); origin = p; }
	void setDirection(double dx, double dy);

	Q_PROPERTY(double startX READ startX NOTIFY beamChanged)
	Q_PROPERTY(double startY READ startY NOTIFY beamChanged)
	Q_PROPERTY(double dirx READ dirxProp NOTIFY beamChanged)
	Q_PROPERTY(double diry READ diryProp NOTIFY beamChanged)
	Q_PROPERTY(double maxDist READ maxDistProp NOTIFY beamChanged)
	double startX() const { return origin.x(); }
	double startY() const { return origin.y(); }
	double dirxProp() const { return dirx; }
	double diryProp() const { return diry; }
	double maxDistProp() const { return getMaxDist(); }

signals:
	void backendDestroyed(Enemy2Laser* self);
	void beamChanged();

private:
	void onTick();
	QPointF origin{0,0};
	double dirx{1};
	double diry{0};
	double length{5000};
	int durationMs{350};
	QTimer *timer{nullptr};
};

#endif // ENEMY2_LASER_H
