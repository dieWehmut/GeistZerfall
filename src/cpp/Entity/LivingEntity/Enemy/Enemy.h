#ifndef ENEMY_BASE_H
#define ENEMY_BASE_H

#include "Entity/LivingEntity/Player.h" // for interacting with player hp (forward usage) - safe include
#include "Entity/Entity.h"
#include <QPointer>
#include <QElapsedTimer>
#include <QTimer>

// 基础 Enemy 类：具有生命、法力(蓝条)、追踪玩家与攻击逻辑。
// 攻击判定：玩家进入 sight 范围且冷却结束且法力足够。
// 派生类需实现 performAttack() 与 mpRegenRatePerSec()。

class Enemy : public Entity {
	Q_OBJECT
	Q_PROPERTY(int hp READ getHp WRITE setHp NOTIFY hpChanged)
	Q_PROPERTY(int maxHp READ getMaxHp WRITE setMaxHp NOTIFY maxHpChanged)
	Q_PROPERTY(int mp READ getMp WRITE setMp NOTIFY mpChanged)
	Q_PROPERTY(int maxMp READ getMaxMp WRITE setMaxMp NOTIFY maxMpChanged)
	Q_PROPERTY(bool alive READ isAlive NOTIFY aliveChanged)
	Q_PROPERTY(int attackCooldownMs READ getAttackCooldownMs WRITE setAttackCooldownMs)
public:
	explicit Enemy(QObject *parent = nullptr);
	~Enemy() override;

	// HP / MP 基本访问器
	int getHp() const { return hp; }
	void setHp(int value) { 
		if (hp == value) return; 
		hp = value; 
		if (hp <= 0) { hp = 0; if (alive) { alive = false; emit aliveChanged(); emit died(); } }
		emit hpChanged(); 
	}
	int getMaxHp() const { return maxHp; }
	void setMaxHp(int value) { if (maxHp != value) { maxHp = value; emit maxHpChanged(); } }
	int getMp() const { return mp; }
	void setMp(int value) { 
		int clamped = value; 
		if (clamped > maxMp) clamped = maxMp; 
		if (clamped < 0) clamped = 0; 
		if (mp != clamped) { mp = clamped; emit mpChanged(); }
	}
	int getMaxMp() const { return maxMp; }
	void setMaxMp(int value) { if (maxMp != value) { maxMp = value; emit maxMpChanged(); if (mp>maxMp) setMp(maxMp); } }
	bool isAlive() const { return alive; }

	int getAttackCooldownMs() const { return attackCooldownMs; }
	void setAttackCooldownMs(int ms) { attackCooldownMs = ms; }

	// 指定/更新追踪的玩家对象。
	Q_INVOKABLE void setPlayerTarget(Player *p) { playerTarget = p; }
	Player* getPlayerTarget() const { return playerTarget; }

	// 派生类可调用：尝试执行一次攻击；内部检查冷却/法力/距离。
	Q_INVOKABLE void tryAttack();

	// 受击（被玩家或其他来源伤害）。Enemy 之间不会互相伤害，调用前应在外部过滤。
	Q_INVOKABLE void receiveDamage(int amount);

signals:
	void hpChanged();
	void maxHpChanged();
	void mpChanged();
	void maxMpChanged();
	void aliveChanged();
	void attacked();           // 成功触发攻击（派生类 performAttack 已执行）
	void died();               // HP 归零时
	// 由派生类在 performAttack 中发射后触发，供 QML 侧创建对应的可视对象
	void enemyProjectileCreated(QObject* projectile);
	void enemyLaserCreated(QObject* laser);

protected:
	// 派生类必须实现：实际攻击行为（创建弹幕 / 激光等）。返回消耗的 MP 数值；若返回 0 视为未攻击。
	virtual int performAttack() = 0;
	// 派生类定义每秒恢复的 MP 数值。
	virtual int mpRegenRatePerSec() const = 0;

	void startLogicLoop();
	void chasePlayerStep();
	bool canAttackNow() const;

	QPointer<Player> playerTarget; // 追踪的玩家
	int hp{0};
	int maxHp{0};
	int mp{0};
	int maxMp{0};
	bool alive{true};
	int attackCooldownMs{1200};
	QElapsedTimer lastAttackTimer; // 用于冷却判断

	QTimer *logicTimer{nullptr};   // 追踪+判定计时器
	QTimer *mpRegenTimer{nullptr}; // MP 恢复计时器
	double mpRegenAccum{0.0};      // 100ms tick 的累积器
};

#endif // ENEMY_BASE_H

