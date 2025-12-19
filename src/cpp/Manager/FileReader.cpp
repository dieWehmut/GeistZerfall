#include "FileReader.h"
#include <QDebug>
#include <QDir>
#include <QStandardPaths>
#include <QCoreApplication>


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

QString FileReader::ensureAssetFile(const QString& assetOrPath)
{
    QString in = assetOrPath;
    if (in.isEmpty()) return QString();

    // If already a normal local file path, return as-is
    if (in.startsWith("file:/")) {
        // Strip schema and return local path if needed
        // But MediaPlayer accepts file:/// URLs, so keep as-is
        return in;
    }

    // If it's a Qt resource or Android assets path, read content and dump to cache
    bool isQrc = in.startsWith("qrc:/");
    bool isAssets = in.startsWith("assets:/");
    if (!isQrc && !isAssets) {
        // Not a special schema; return original (could be relative path)
        return in;
    }

    // Map to QFile-compatible path: Qt can open both qrc:/ and assets:/ via QFile
    QString qfilePath = in;

    QFile src(qfilePath);
    if (!src.open(QIODevice::ReadOnly)) {
        qDebug() << "FileReader: ensureAssetFile open failed:" << qfilePath;
        return QString();
    }

    QByteArray data = src.readAll();
    src.close();

    // Build cache directory
    QString appData = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    if (appData.isEmpty()) {
        appData = QStandardPaths::writableLocation(QStandardPaths::TempLocation);
    }
    QDir dir(appData);
    QString cacheDir = dir.filePath("assets_cache");
    QDir().mkpath(cacheDir);

    // Use filename component
    QString baseName = in;
    int slash = baseName.lastIndexOf('/');
    if (slash >= 0) baseName = baseName.mid(slash + 1);
    QString outPath = QDir(cacheDir).filePath(baseName);

    QFile out(outPath);
    if (!out.open(QIODevice::WriteOnly)) {
        qDebug() << "FileReader: ensureAssetFile write failed:" << outPath;
        return QString();
    }
    out.write(data);
    out.close();

    // Return absolute local path (MediaPlayer can take this via file:///, QML can also pass path)
    return outPath;
}

QString FileReader::getApplicationDirPath()
{
    return QCoreApplication::applicationDirPath();
}
