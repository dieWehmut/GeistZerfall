#ifndef ENTITY_H
#define ENTITY_H
#include <QObject>
#include <QTimer>
#include <QPointF>
#include <QtCore/QTimer>
class Entity : public QObject {
    Q_OBJECT
    Q_PROPERTY(QPointF pos READ getPos WRITE setPos NOTIFY posChanged)
    Q_PROPERTY(int mapWidth READ getMapWidth WRITE setMapWidth)
    Q_PROPERTY(int mapHeight READ getMapHeight WRITE setMapHeight)
    Q_PROPERTY(double sight READ getSight WRITE setSight NOTIFY sightChanged)
public:
    explicit Entity(QObject *parent = nullptr);
    virtual~Entity();
    QPointF getPos() const { return pos; }
    void setPos(const QPointF &newPos);
    double getSpeed() const { return speed; }
    Q_INVOKABLE void setSpeed(double newSpeed) { speed = newSpeed; }
    double getSight() const { return sight; }
    void setSight(double s) { if (sight != s) { sight = s; emit sightChanged(); } }
    Q_INVOKABLE void move(int dx, int dy);
    void setMoveInterval(int ms) { moveIntervalMs = ms; if (moveTimer) moveTimer->setInterval(moveIntervalMs); }
    int getMoveInterval() const { return moveIntervalMs; }
    void setMapWidth(int w) { mapWidth = w; }
    void setMapHeight(int h) { mapHeight = h; }
    int getMapWidth() const { return mapWidth; }
    int getMapHeight() const { return mapHeight; }
signals:
    void posChanged();
    void sightChanged();

protected:
    QPointF pos{0, 0};
    double speed{0};
    double sight{0};
    QTimer *moveTimer{nullptr};
    int dirX{0};
    int dirY{0};
    int moveIntervalMs{16};
    int mapWidth{0};
    int mapHeight{0};
};

#endif // ENTITY_H