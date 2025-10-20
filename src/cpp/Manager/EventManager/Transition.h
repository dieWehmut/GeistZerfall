#ifndef TRANSITION_H
#define TRANSITION_H

#include <QObject>
#include <QQmlContext>
#include <QQmlApplicationEngine>
#include <QString>

class Transition : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString currentView READ currentView NOTIFY currentViewChanged)

public:
    explicit Transition(QObject *parent = nullptr);

    QString currentView() const { return m_currentView; }

    // 从 Lore 切换到 GameView（战斗）
    Q_INVOKABLE void startBattle(const QString &battleId);

    // 从 GameView 返回到 Lore（战斗结束后继续剧情）
    Q_INVOKABLE void returnToLore(const QString &chapterId, const QString &nodeId);

    // 从主菜单进入 Lore（序章）
    Q_INVOKABLE void startLore(const QString &chapterId);

signals:
    void currentViewChanged();
    void switchToGameView(const QString &battleId);
    void switchToLoreView(const QString &chapterId, const QString &nodeId);

private:
    QString m_currentView;
    void setCurrentView(const QString &view);
};

#endif // TRANSITION_H
