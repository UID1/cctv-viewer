#include "systeminfo.h"

#include <QByteArray>
#include <QProcessEnvironment>

#include <cstdio>

#if defined(CCTV_HAVE_JEMALLOC)
#include <jemalloc/jemalloc.h>
#elif defined(__GLIBC__)
#include <malloc.h>
#endif

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

static qint64 readProcStatusKb(const char *key)
{
    QFile file(QStringLiteral("/proc/self/status"));
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return 0;
    }

    const QByteArray text = file.readAll();
    const QByteArray prefix = QByteArray(key) + ":";
    for (const QByteArray &line : text.split('\n')) {
        if (!line.startsWith(prefix)) {
            continue;
        }
        const QByteArray rest = line.mid(prefix.size()).trimmed();
        bool ok = false;
        const qint64 value = rest.split(' ').first().toLongLong(&ok);
        return ok ? value : 0;
    }
    return 0;
}

qint64 SystemInfo::rssAnonKb() const
{
    return readProcStatusKb("RssAnon");
}

qint64 SystemInfo::vmRssKb() const
{
    return readProcStatusKb("VmRSS");
}

void SystemInfo::configureHeap()
{
#if defined(CCTV_HAVE_JEMALLOC)
    ssize_t decayMs = 1000;
    mallctl("arenas.dirty_decay_ms", nullptr, nullptr, &decayMs, sizeof(decayMs));
    mallctl("arenas.muzzy_decay_ms", nullptr, nullptr, &decayMs, sizeof(decayMs));

    unsigned narenas = 0;
    size_t sz = sizeof(narenas);
    if (mallctl("arenas.narenas", &narenas, &sz, nullptr, 0) != 0)
        return;
    for (unsigned i = 0; i < narenas; ++i) {
        char name[64];
        std::snprintf(name, sizeof(name), "arena.%u.dirty_decay_ms", i);
        mallctl(name, nullptr, nullptr, &decayMs, sizeof(decayMs));
        std::snprintf(name, sizeof(name), "arena.%u.muzzy_decay_ms", i);
        mallctl(name, nullptr, nullptr, &decayMs, sizeof(decayMs));
    }
#endif
}

int SystemInfo::trimMallocHeap()
{
#if defined(CCTV_HAVE_JEMALLOC)
    char name[64];
    std::snprintf(name, sizeof(name), "arena.%u.purge", MALLCTL_ARENAS_ALL);
    return mallctl(name, nullptr, nullptr, nullptr, 0) == 0 ? 1 : 0;
#elif defined(__GLIBC__)
    return malloc_trim(0);
#else
    return 0;
#endif
}

QString SystemInfo::mallocHeapInfo() const
{
#if defined(CCTV_HAVE_JEMALLOC)
    uint64_t epoch = 1;
    size_t epochSize = sizeof(epoch);
    mallctl("epoch", &epoch, &epochSize, &epoch, sizeof(epoch));

    auto stat = [](const char *name) -> size_t {
        size_t value = 0;
        size_t len = sizeof(value);
        if (mallctl(name, &value, &len, nullptr, 0) != 0)
            return 0;
        return value;
    };
    return QStringLiteral("allocated=%1 active=%2 resident=%3 retained=%4 mapped=%5")
            .arg(static_cast<qulonglong>(stat("stats.allocated")))
            .arg(static_cast<qulonglong>(stat("stats.active")))
            .arg(static_cast<qulonglong>(stat("stats.resident")))
            .arg(static_cast<qulonglong>(stat("stats.retained")))
            .arg(static_cast<qulonglong>(stat("stats.mapped")));
#elif defined(__GLIBC__)
    const struct mallinfo2 mi = mallinfo2();
    return QStringLiteral("arena=%1 uordblks=%2 fordblks=%3 hblkhd=%4 keepcost=%5 ordblks=%6 hblks=%7")
            .arg(static_cast<qulonglong>(mi.arena))
            .arg(static_cast<qulonglong>(mi.uordblks))
            .arg(static_cast<qulonglong>(mi.fordblks))
            .arg(static_cast<qulonglong>(mi.hblkhd))
            .arg(static_cast<qulonglong>(mi.keepcost))
            .arg(static_cast<qulonglong>(mi.ordblks))
            .arg(static_cast<qulonglong>(mi.hblks));
#else
    return QStringLiteral("heap stats unavailable");
#endif
}
