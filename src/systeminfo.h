#ifndef SYSTEMINFO_H
#define SYSTEMINFO_H

#include <QObject>
#include <QString>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QStandardPaths>
#include <QSysInfo>

class SystemInfo : public QObject
{
    Q_OBJECT

    Q_PROPERTY(QString userName READ userName CONSTANT)
    Q_PROPERTY(QString hostName READ hostName CONSTANT)
    Q_PROPERTY(QString userAvatar READ userAvatar NOTIFY userAvatarChanged)
    Q_PROPERTY(QString customAvatarPath READ customAvatarPath WRITE setCustomAvatarPath NOTIFY customAvatarPathChanged)

public:
    explicit SystemInfo(QObject *parent = nullptr);

    QString userName() const { return m_userName; }
    QString hostName() const { return m_hostName; }
    QString userAvatar() const { return m_userAvatar; }
    
    QString customAvatarPath() const { return m_customAvatarPath; }
    void setCustomAvatarPath(const QString &path);

    // Process anonymous / total RSS from /proc/self/status, in KiB. 0 if unavailable.
    Q_INVOKABLE qint64 rssAnonKb() const;
    Q_INVOKABLE qint64 vmRssKb() const;
    // Apply jemalloc dirty/muzzy decay to arenas already created. Call once at startup.
    static void configureHeap();

    // Purge unused jemalloc pages. 1 if the purge ran, 0 otherwise.
    Q_INVOKABLE int trimMallocHeap();
    // jemalloc stats in bytes: allocated, active, resident, retained, mapped.
    Q_INVOKABLE QString mallocHeapInfo() const;

signals:
    void userAvatarChanged();
    void customAvatarPathChanged();

private:
    void resolveUserAvatar();
    bool fileExists(const QString &path) const;

    QString m_userName;
    QString m_hostName;
    QString m_userAvatar;
    QString m_customAvatarPath;
    
    static const QString DEFAULT_AVATAR;
};

#endif // SYSTEMINFO_H
