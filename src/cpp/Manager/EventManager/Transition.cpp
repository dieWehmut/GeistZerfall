#include "Transition.h"

Transition::Transition(QObject *parent)
    : QObject(parent)
    , m_currentView("MainMenu")
{
}

void Transition::setCurrentView(const QString &view)
{
    if (m_currentView != view) {
        m_currentView = view;
        emit currentViewChanged();
    }
}

void Transition::startBattle(const QString &battleId)
{
    setCurrentView("GameView");
    emit switchToGameView(battleId);
}

void Transition::returnToLore(const QString &chapterId, const QString &nodeId)
{
    setCurrentView("LoreView");
    emit switchToLoreView(chapterId, nodeId);
}

void Transition::startLore(const QString &chapterId)
{
    setCurrentView("LoreView");
    // 传递空字符串让 LoreView 从章节的 meta.startNode 读取初始节点
    emit switchToLoreView(chapterId, "");
}
