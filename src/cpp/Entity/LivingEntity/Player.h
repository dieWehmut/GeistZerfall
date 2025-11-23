#ifndef PLAYER_H
#define PLAYER_H
#include "../Entity.h"
#include "../../Manager/SaveLoadManager/SaveData.h"



class Player : public Entity {
    Q_OBJECT
    Q_PROPERTY(int hp READ getHp WRITE setHp NOTIFY hpChanged)
    Q_PROPERTY(int maxHp READ getMaxHp WRITE setMaxHp NOTIFY maxHpChanged)
    Q_PROPERTY(bool teleportMode READ isTeleportModeActive WRITE setTeleportMode NOTIFY teleportModeChanged)

public:
    explicit Player(QObject *parent = nullptr);
    ~Player();
    // Getters and setters
    int getHp() const{ return hp; };
    void setHp(int value){ if (hp != value) { hp = value; emit hpChanged(); } };
    int getMaxHp() const{ return maxHp; };
    void setMaxHp(int value){ if (maxHp != value) { maxHp = value; emit maxHpChanged(); } };


    Q_INVOKABLE void shoot(double px, double py, double dirx, double diry);// Fire a bullet (called from QML)
    Q_INVOKABLE void snipe(double px, double py, double dirx, double diry);// Fire a laser
    Q_INVOKABLE void wave(double px, double py, double dirx, double diry); // Fire wave spread
    Q_INVOKABLE void snipeStart();
    Q_INVOKABLE void snipeStop();
    Q_INVOKABLE void shootStart();
    Q_INVOKABLE void shootStop();
    Q_INVOKABLE void toggleTeleportMode();
    Q_INVOKABLE void enterTeleportMode();
    Q_INVOKABLE void exitTeleportMode();
    Q_INVOKABLE void teleportTo(double x, double y);

    Q_PROPERTY(bool snipeActive READ isSnipeActive NOTIFY snipeChanged)
    bool isSnipeActive() const { return snipeActive; }
    bool isTeleportModeActive() const { return teleportModeActive; }
    void setTeleportMode(bool enabled);

    // Convert to/from saveable struct. Keeps save/load responsibilities separated.
    PlayerSaveData toSaveData() const;
    void loadFromSaveData(const PlayerSaveData &data);

    Q_INVOKABLE void receiveDamage(int amount) { setHp(qMax(0, hp - qMax(0, amount))); emit damaged(amount); }

signals:
    // Emitted when a new bullet backend object is created. QML should create a bullet visual and bind to it.
    void playerBulletCreated(QObject* bullet);
    // Emitted when a new laser backend object is created. QML should create a laser visual and bind to it.
    void playerLaserCreated(QObject* laser);
    // Emitted when a new wave backend object is created. QML should create a wave visual and bind to it.
    void playerWaveCreated(QObject* wave);
    void hpChanged();
    void maxHpChanged();
    void damaged(int amount);
    void teleportModeChanged();
    void teleported(const QPointF &pos);



private:
    int hp{50000};
    int maxHp{50000};
    bool snipeActive{false};
    bool shootingActive{false};
    double savedSight{0};
    double savedSpeed{0};
    bool teleportModeActive{false};
signals:
    void snipeChanged();
};

#endif // PLAYER_H
