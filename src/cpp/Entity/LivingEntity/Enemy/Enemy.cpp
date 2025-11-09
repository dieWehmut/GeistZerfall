#include "Enemy.h"
#include <QtMath>

Enemy::Enemy(QObject *parent) : Entity(parent) {
	setSpeed(24);      // 默认比玩家慢一些
	setSight(350);     // 默认视野
	setMaxHp(100);
	setHp(100);
	setMaxMp(100);
	setMp(100);
	lastAttackTimer.invalidate();

	// 逻辑循环：20ms 更新一次（移动与攻击判定）
	logicTimer = new QTimer(this);
	logicTimer->setInterval(20);
	connect(logicTimer, &QTimer::timeout, this, [this](){
		if (!alive) return;
		chasePlayerStep();
		tryAttack();
	});
	logicTimer->start();

	// MP 恢复计时（100ms tick 以累积到每秒）
	mpRegenTimer = new QTimer(this);
	mpRegenTimer->setInterval(100);
	connect(mpRegenTimer, &QTimer::timeout, this, [this](){
		if (!alive) return;
		// 基于每秒 X 点 MP，换算 100ms 增量（带小数累积）
		int perSec = mpRegenRatePerSec();
		if (perSec <= 0) return;
		mpRegenAccum += (double)perSec / 10.0;
		int delta = (int)std::floor(mpRegenAccum);
		if (delta > 0) {
			mpRegenAccum -= delta;
			setMp(mp + delta);
		}
	});
	mpRegenTimer->start();
}

Enemy::~Enemy() {
}

void Enemy::startLogicLoop() {
	if (logicTimer && !logicTimer->isActive()) logicTimer->start();
}

bool Enemy::canAttackNow() const {
	if (!alive) return false;
	if (!playerTarget) return false;
	if (getSight() <= 0) return false;
	// 冷却
	if (lastAttackTimer.isValid()) {
		if (lastAttackTimer.elapsed() < attackCooldownMs) return false;
	}
	// 距离
	QPointF p = getPos();
	QPointF t = playerTarget->getPos();
	double dx = t.x() - p.x();
	double dy = t.y() - p.y();
	double dist = std::sqrt(dx*dx + dy*dy);
	if (dist > getSight()) return false;
	return true;
}

void Enemy::tryAttack() {
	if (!canAttackNow()) return;
	// 由子类执行攻击，返回 MP 消耗
	int cost = performAttack();
	if (cost > 0 && mp >= cost) {
		setMp(mp - cost);
		lastAttackTimer.start();
		emit attacked();
	}
}

void Enemy::chasePlayerStep() {
	if (!playerTarget) return;
	QPointF p = getPos();
	QPointF t = playerTarget->getPos();
	double dx = t.x() - p.x();
	double dy = t.y() - p.y();
	// 朝向玩家移动（使用 Entity 的 move 定时器推进）
	// 这里持续设置方向，由 Entity 的 moveTimer 推动位置变化
	move(int(std::round(dx)), int(std::round(dy)));
}

void Enemy::receiveDamage(int amount) {
	if (!alive) return;
	setHp(hp - qMax(0, amount));
}

