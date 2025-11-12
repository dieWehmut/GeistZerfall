#ifndef ENEMY3_MOTHER_BULLET_H
#define ENEMY3_MOTHER_BULLET_H

#include "Entity/Projectile/Projectile.h"
#include <QTimer>

// 敌人3的母弹：飞行2秒后分裂成多个小子弹
class Enemy3MotherBullet : public Projectile {
  Q_OBJECT
public:
  explicit Enemy3MotherBullet(QObject *parent = nullptr);
  ~Enemy3MotherBullet() override;

  void setStartPos(const QPointF &p) {
    setPos(p);
    origin = p;
  }
  void setDirection(double dx, double dy); // 归一化并设置方向
  Q_INVOKABLE void updateStep();

signals:
  void backendDestroyed(Enemy3MotherBullet *self);
  void childBulletsCreated(QObject *childBullet); // 分裂时创建的小子弹信号

private:
  void performSplit(); // 执行分裂

  QPointF origin{0, 0};
  double dirx{0};
  double diry{0};
  double velocity{180}; // 每秒像素，母弹速度较慢
  QTimer *updateTimer{nullptr};
  int flightTimeMs{0};                 // 已飞行时间（毫秒）
  static const int splitTimeMs = 2000; // 2秒后分裂
};

#endif // ENEMY3_MOTHER_BULLET_H
