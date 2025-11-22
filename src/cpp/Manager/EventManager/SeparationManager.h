#ifndef SEPARATIONMANAGER_H
#define SEPARATIONMANAGER_H

#include <QObject>
#include <QList>
#include <QTimer>
#include <QPointF>

class Enemy;
class Player;

class SeparationManager : public QObject {
    Q_OBJECT
public:
    static SeparationManager* instance();

    void registerEnemy(Enemy* enemy);
    void unregisterEnemy(Enemy* enemy);
    void setPlayer(Player* player);

private:
    explicit SeparationManager(QObject* parent = nullptr);
    ~SeparationManager();

    QList<Enemy*> m_enemies;
    Player* m_player = nullptr;
    QTimer* m_updateTimer;

    void updateSeparation();
};

#endif // SEPARATIONMANAGER_H
