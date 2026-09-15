#include "systeminfo.h"

#include <QProcessEnvironment>

const QString SystemInfo::DEFAULT_AVATAR = QStringLiteral("qrc:/images/default-avatar.svg");

SystemInfo::SystemInfo(QObject *parent)
    : QObject(parent)
{
    // Get username from environment
    m_userName = qEnvironmentVariable("USER");
    if (m_userName.isEmpty()) {
        m_userName = qEnvironmentVariable("USERNAME"); // Windows fallback
    }
    if (m_userName.isEmpty()) {
        m_userName = QDir::home().dirName(); // Last resort
    }
    
    // Get hostname
    m_hostName = QSysInfo::machineHostName();
    
    // Resolve avatar
    resolveUserAvatar();
}

void SystemInfo::setCustomAvatarPath(const QString &path)
{
    if (m_customAvatarPath != path) {
        m_customAvatarPath = path;
        emit customAvatarPathChanged();
        resolveUserAvatar();
    }
}

void SystemInfo::resolveUserAvatar()
{
    QString newAvatar;
    
    // Priority 1: Custom user-defined path
    if (!m_customAvatarPath.isEmpty() && fileExists(m_customAvatarPath)) {
        newAvatar = QStringLiteral("file://") + m_customAvatarPath;
    }
    // Priority 2: AccountsService (KDE/GNOME)
    else if (fileExists(QStringLiteral("/var/lib/AccountsService/icons/") + m_userName)) {
        newAvatar = QStringLiteral("file:///var/lib/AccountsService/icons/") + m_userName;
    }
    // Priority 3: Default avatar
    else {
        newAvatar = DEFAULT_AVATAR;
    }
    
    if (m_userAvatar != newAvatar) {
        m_userAvatar = newAvatar;
        emit userAvatarChanged();
    }
}

bool SystemInfo::fileExists(const QString &path) const
{
    QFileInfo fileInfo(path);
    return fileInfo.exists() && fileInfo.isFile();
}
