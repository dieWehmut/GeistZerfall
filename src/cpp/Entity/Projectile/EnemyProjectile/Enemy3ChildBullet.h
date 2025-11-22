#ifndef ENEMY3_CHILD_BULLET_H
#define ENEMY3_CHILD_BULLET_H

#include "Entity/Projectile/Projectile.h"
#include <QTimer>

// 敌人3分裂后的小子弹：快速向四周散开
class Enemy3ChildBullet : public Projectile {
  Q_OBJECT
public:
  explicit Enemy3ChildBullet(QObject *parent = nullptr);
  ~Enemy3ChildBullet() override;

  void setStartPos(const QPointF &p) {
    setPos(p);
    origin = p;
  }
  void setDirection(double dx, double dy); // 归一化并设置方向
  Q_INVOKABLE void updateStep();

signals:
  void backendDestroyed(Enemy3ChildBullet *self);

private:
  QPointF origin{0, 0};
  double dirx{0};
  double diry{0};
  double velocity{500}; 
  QTimer *updateTimer{nullptr};
};

#endif // ENEMY3_CHILD_BULLET_H
