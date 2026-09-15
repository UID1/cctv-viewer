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
