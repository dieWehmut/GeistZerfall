#include "TileManager.h"
#include <QDebug>


TileManager::TileManager(QObject* parent)
	: QObject(parent)
{
}

QVector<QVector<int>> TileManager::curMapData() const
{
	if (m_curMapId >= 0 && m_curMapId < mapData.size())
		return mapData[m_curMapId];
	return {};
}

int TileManager::getTileType(int r, int c) const
{
	if (m_curMapId >= 0 && m_curMapId < mapData.size()) {
		const auto& map = mapData[m_curMapId];
		if (r >= 0 && r < map.size() && c >= 0 && c < map[0].size())
			return map[r][c];
	}
	return -1;
}

void TileManager::setTileType(int r, int c, int type)
{
	if (m_curMapId >= 0 && m_curMapId < mapData.size()) {
		auto& map = mapData[m_curMapId];
		if (r >= 0 && r < map.size() && c >= 0 && c < map[0].size()) {
			map[r][c] = type;
            emit curMapDataChanged();
		}
	}
}

void TileManager::setCurMapId(int id)
{
	if (id >= 0 && id < mapData.size() && id != m_curMapId) {
		m_curMapId = id;
		emit curMapIdChanged();
        emit curMapDataChanged();
	}
}

void TileManager::setMapData(const QVector<QVector<int>>& newMapData)
{
	if (newMapData.isEmpty()) {
		qDebug() << "TileManager::setMapData: empty map data";
		return;
	}
	
	// 更新行列数
	row = newMapData.size();
	col = newMapData[0].size();
	
	// 替换当前地图数据
	if (m_curMapId >= 0 && m_curMapId < mapData.size()) {
		mapData[m_curMapId] = newMapData;
	} else {
		// 如果当前地图 ID 无效，添加为新地图
		mapData.append(newMapData);
		m_curMapId = mapData.size() - 1;
		emit curMapIdChanged();
	}
	
	qDebug() << "TileManager::setMapData: loaded map" << row << "x" << col;
	emit curMapDataChanged();
}
