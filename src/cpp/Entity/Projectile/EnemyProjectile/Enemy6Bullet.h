#ifndef ENEMY6_BULLET_H
#define ENEMY6_BULLET_H

#include "Entity/Projectile/Projectile.h"
#include <QElapsedTimer>
#include <QTimer>

class Enemy6Bullet : public Projectile {
  Q_OBJECT
  Q_PROPERTY(int spriteIndex READ spriteIndex WRITE setSpriteIndex NOTIFY
                 spriteIndexChanged)
public:
  explicit Enemy6Bullet(QObject *parent = nullptr);
  ~Enemy6Bullet() override;

  void setStartPos(const QPointF &p) {
    setPos(p);
    origin = p;
  }
  void setDirection(double dx, double dy); // 归一化并设置
  Q_INVOKABLE void updateStep();

  int spriteIndex() const { return spriteIdx; }
  void setSpriteIndex(int value);

signals:
  void backendDestroyed(Enemy6Bullet *self);
  void spriteIndexChanged();

private:
  QPointF origin{0, 0};
  double dirx{0};
  double diry{0};
  double velocity{1000}; // 每秒像素
  QTimer *updateTimer{nullptr};
  int spriteIdx{1};
};

#endif // ENEMY6_BULLET_H
