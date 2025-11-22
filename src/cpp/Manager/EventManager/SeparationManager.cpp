#include "SeparationManager.h"
#include "Entity/LivingEntity/Enemy/Enemy.h"
#include "Entity/LivingEntity/Player.h"
#include <QVector2D>
#include <cmath>

SeparationManager* SeparationManager::instance() {
    static SeparationManager* inst = new SeparationManager();
    return inst;
}

SeparationManager::SeparationManager(QObject* parent) : QObject(parent) {
    m_updateTimer = new QTimer(this);
    connect(m_updateTimer, &QTimer::timeout, this, &SeparationManager::updateSeparation);
    m_updateTimer->start(16); // ~60 FPS
}

SeparationManager::~SeparationManager() {
}

void SeparationManager::registerEnemy(Enemy* enemy) {
    if (enemy && !m_enemies.contains(enemy)) {
        m_enemies.append(enemy);
    }
}

void SeparationManager::unregisterEnemy(Enemy* enemy) {
    if (enemy) {
        m_enemies.removeAll(enemy);
    }
}

void SeparationManager::setPlayer(Player* player) {
    m_player = player;
}

void SeparationManager::updateSeparation() {
    // Enemy-Enemy Separation
    const double enemySeparationDist = 600.0;
    const double playerSeparationDist = 400.0;
    const double separationFactor = 0.05; // Smooth separation

    for (int i = 0; i < m_enemies.size(); ++i) {
        Enemy* e1 = m_enemies[i];
        if (!e1 || !e1->isAlive()) continue;

        QVector2D pos1(e1->getPos());
        QVector2D totalForce(0, 0);

        // Check against other enemies
        for (int j = 0; j < m_enemies.size(); ++j) {
            if (i == j) continue;
            Enemy* e2 = m_enemies[j];
            if (!e2 || !e2->isAlive()) continue;

            QVector2D pos2(e2->getPos());
            QVector2D diff = pos1 - pos2;
            double dist = diff.length();

            if (dist > 0 && dist <= enemySeparationDist) {
                diff.normalize();
                // Force is stronger the closer they are
                totalForce += diff * (enemySeparationDist - dist);
            }
        }

        // Check against player
        if (m_player) {
            QVector2D playerPos(m_player->getPos());
            QVector2D diff = pos1 - playerPos;
            double dist = diff.length();

            if (dist > 0 && dist <= playerSeparationDist) {
                diff.normalize();
                totalForce += diff * (playerSeparationDist - dist);
            }
        }

        if (!totalForce.isNull()) {
             QPointF newPos = e1->getPos() + (totalForce * separationFactor).toPointF();
             
             // Clamp to map bounds if available
             int mw = e1->getMapWidth();
             int mh = e1->getMapHeight();
             if (mw > 0) {
                 if (newPos.x() < 0) newPos.setX(0);
                 if (newPos.x() > mw) newPos.setX(mw);
             }
             if (mh > 0) {
                 if (newPos.y() < 0) newPos.setY(0);
                 if (newPos.y() > mh) newPos.setY(mh);
             }

             e1->setPos(newPos);
        }
    }
}
