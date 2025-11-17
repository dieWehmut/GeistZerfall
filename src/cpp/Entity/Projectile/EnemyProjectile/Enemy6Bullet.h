#ifndef ENEMY6_BULLET_H
#define ENEMY6_BULLET_H

#include "Entity/Projectile/Projectile.h"
#include <QElapsedTimer>
#include <QTimer>

class Enemy6Bullet : public Projectile {
  Q_OBJECT
  Q_PROPERTY(double waveFrequency READ waveFrequency WRITE setWaveFrequency
                 NOTIFY waveFrequencyChanged)
  Q_PROPERTY(double waveAmplitude READ waveAmplitude WRITE setWaveAmplitude
                 NOTIFY waveAmplitudeChanged)
  Q_PROPERTY(double waveTime READ waveTime NOTIFY waveTimeChanged)
  Q_PROPERTY(double dirx READ dirx NOTIFY directionChanged)
  Q_PROPERTY(double diry READ diry NOTIFY directionChanged)
public:
  explicit Enemy6Bullet(QObject *parent = nullptr);
  ~Enemy6Bullet() override;

  void setStartPos(const QPointF &p) {
    setPos(p);
    origin = p;
  }
  void setDirection(double dx, double dy); // 归一化并设置
  Q_INVOKABLE void updateStep();

  // 波形属性
  double waveFrequency() const { return waveFreq; }
  void setWaveFrequency(double value);
  double waveAmplitude() const { return waveAmp; }
  void setWaveAmplitude(double value);
  double waveTime() const { return currentTime; }
  double dirx() const { return dirx_; }
  double diry() const { return diry_; }

signals:
  void backendDestroyed(Enemy6Bullet *self);
  void waveFrequencyChanged();
  void waveAmplitudeChanged();
  void waveTimeChanged();
  void directionChanged();

private:
  QPointF origin{0, 0};
  double dirx_{0};
  double diry_{0};
  double velocity{260}; // 每秒像素
  QTimer *updateTimer{nullptr};

  // 波形参数
  double waveFreq{2.0};    // 波形频率（每秒周期数）
  double waveAmp{30.0};    // 波形振幅（像素）
  double currentTime{0.0}; // 当前时间（秒）
};

#endif // ENEMY6_BULLET_H
