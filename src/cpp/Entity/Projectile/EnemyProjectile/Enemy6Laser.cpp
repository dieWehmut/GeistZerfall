#include "Enemy6Laser.h"
#include <QtMath>

Enemy6Laser::Enemy6Laser(QObject *parent) : Projectile(parent) {
  setMaxDist(750);
  setTraveledDist(0);
  updateTimer = new QTimer(this);
  updateTimer->setInterval(16);
  connect(updateTimer, &QTimer::timeout, this, &Enemy6Laser::updateStep);
  updateTimer->start();
}

Enemy6Laser::~Enemy6Laser() { emit backendDestroyed(this); }

void Enemy6Laser::setDirection(double dx, double dy) {
  double len = std::sqrt(dx * dx + dy * dy);
  if (len == 0) {
    dirx_ = 1;
    diry_ = 0;
  } else {
    dirx_ = dx / len;
    diry_ = dy / len;
  }
  emit directionChanged();
}

void Enemy6Laser::updateStep() {
  // 每 tick 移动 velocity * dt
  const double dt = 0.016; // 假定 ~60FPS

  // 更新时间
  currentTime += dt;
  emit waveTimeChanged();

  // 波形光波沿着主方向移动，波形效果在视觉上体现（QML绘制）
  // 这里只计算沿主方向的移动距离
  QPointF p = getPos();
  double distTraveled = velocity * currentTime;

  // 计算沿主方向的新位置（不考虑波形偏移，波形在QML中绘制）
  QPointF np(origin.x() + dirx_ * distTraveled,
             origin.y() + diry_ * distTraveled);

  setPos(np);
  setTraveledDist(distTraveled);

  if (distTraveled >= getMaxDist()) {
    updateTimer->stop();
    deleteLater();
  }
}

void Enemy6Laser::setWaveFrequency(double value) {
  if (qAbs(waveFreq - value) < 0.001)
    return;
  waveFreq = value;
  emit waveFrequencyChanged();
}

void Enemy6Laser::setWaveAmplitude(double value) {
  if (qAbs(waveAmp - value) < 0.001)
    return;
  waveAmp = value;
  emit waveAmplitudeChanged();
}
