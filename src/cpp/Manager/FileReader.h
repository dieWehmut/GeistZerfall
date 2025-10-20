#ifndef FILEREADER_H
#define FILEREADER_H

#include <QObject>
#include <QString>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>

class FileReader : public QObject
{
    Q_OBJECT
public:
    explicit FileReader(QObject *parent = nullptr);
    
    Q_INVOKABLE QString readTextFile(const QString& filePath);
    Q_INVOKABLE QJsonObject readJsonFile(const QString& filePath);
};

#endif // FILEREADER_H
