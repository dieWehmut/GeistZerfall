#ifndef PLAYER_H
#define PLAYER_H
#include "../Entity.h"
#include "../../Manager/SaveLoadManager/SaveData.h"



class Player : public Entity {
    Q_OBJECT
    Q_PROPERTY(int hp READ getHp WRITE setHp NOTIFY hpChanged)
    Q_PROPERTY(int maxHp READ getMaxHp WRITE setMaxHp NOTIFY maxHpChanged)

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
    Q_INVOKABLE void snipeStart();
    Q_INVOKABLE void snipeStop();
    Q_INVOKABLE void shootStart();
    Q_INVOKABLE void shootStop();

    Q_PROPERTY(bool snipeActive READ isSnipeActive NOTIFY snipeChanged)
    bool isSnipeActive() const { return snipeActive; }

    // Convert to/from saveable struct. Keeps save/load responsibilities separated.
    PlayerSaveData toSaveData() const;
    void loadFromSaveData(const PlayerSaveData &data);

    Q_INVOKABLE void receiveDamage(int amount) { setHp(qMax(0, hp - qMax(0, amount))); emit damaged(amount); }

signals:
    // Emitted when a new bullet backend object is created. QML should create a bullet visual and bind to it.
    void playerBulletCreated(QObject* bullet);
    // Emitted when a new laser backend object is created. QML should create a laser visual and bind to it.
    void playerLaserCreated(QObject* laser);
    void hpChanged();
    void maxHpChanged();
    void damaged(int amount);



private:
    int hp{10000};
    int maxHp{10000};
    bool snipeActive{false};
    bool shootingActive{false};
    double savedSight{0};
    double savedSpeed{0};
signals:
    void snipeChanged();
};

#endif // PLAYER_H
