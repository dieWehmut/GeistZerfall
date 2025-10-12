#ifndef PROJECTILE_H
#define PROJECTILE_H

#include "../Entity.h"

class Projectile : public Entity {
    Q_OBJECT
public:
    explicit Projectile(QObject *parent = nullptr);
    ~Projectile();
    
    double getMaxDist() const{ return maxDist; };
    void setMaxDist(double value){ maxDist = value; };
    double getTraveledDist() const{ return traveledDist; };
    void setTraveledDist(double value){ traveledDist = value; };
protected:
    double maxDist{0};
    double traveledDist{0};
};

#endif // PROJECTILE_H
