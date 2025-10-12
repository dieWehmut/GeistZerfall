#ifndef TILEMANAGER_H
#define TILEMANAGER_H

#include <QObject>
#include <QVector>
#include <QPoint>

class TileManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int rowCnt READ rowCnt CONSTANT)
    Q_PROPERTY(int colCnt READ colCnt CONSTANT)
    Q_PROPERTY(int mapCnt READ mapCnt CONSTANT)
    Q_PROPERTY(int curMapId READ curMapId WRITE setCurMapId NOTIFY curMapIdChanged)
    Q_PROPERTY(QVector<QVector<int>> curMapData READ curMapData NOTIFY curMapDataChanged)
public:
	explicit TileManager(QObject* parent = nullptr);
	int rowCnt() const { return row; }
	int colCnt() const { return col; }
	int mapCnt() const { return mapData.size(); }
	int curMapId() const { return m_curMapId; }
	void setCurMapId(int id);

    QVector<QVector<int>> curMapData() const;

    Q_INVOKABLE int getTileType(int row, int col) const;
    Q_INVOKABLE void setTileType(int row, int col, int type);

signals:
    void curMapIdChanged();
    void curMapDataChanged();

private:
    int row = 21;
    int col = 25;
    int m_curMapId = 0;
    QVector<QVector<QVector<int>>> mapData;
};

#endif // TILEMANAGER_H