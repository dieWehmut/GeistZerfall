#include "FileReader.h"
#include <QDebug>

FileReader::FileReader(QObject *parent)
    : QObject(parent)
{
}

QString FileReader::readTextFile(const QString& filePath)
{
    QFile file(filePath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qDebug() << "FileReader: Failed to open file:" << filePath;
        return QString();
    }
    
    QString content = file.readAll();
    file.close();
    return content;
}

QJsonObject FileReader::readJsonFile(const QString& filePath)
{
    QString jsonString = readTextFile(filePath);
    if (jsonString.isEmpty()) {
        return QJsonObject();
    }
    
    QJsonDocument doc = QJsonDocument::fromJson(jsonString.toUtf8());
    if (doc.isNull() || !doc.isObject()) {
        qDebug() << "FileReader: Invalid JSON in file:" << filePath;
        return QJsonObject();
    }
    
    return doc.object();
}
