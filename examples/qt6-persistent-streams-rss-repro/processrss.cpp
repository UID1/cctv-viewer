#include "processrss.h"

#include <QByteArray>
#include <QCoreApplication>
#include <QFile>
#include <QIODevice>

qint64 ProcessRss::readKb(const char *key)
{
    QFile file(QStringLiteral("/proc/self/status"));
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
        return 0;

    // procfs reports size 0, so QFile::atEnd() is true before any read.
    const QByteArray text = file.readAll();
    const QByteArray prefix = QByteArray(key) + ":";
    for (const QByteArray &line : text.split('\n')) {
        if (!line.startsWith(prefix))
            continue;
        const QByteArray rest = line.mid(prefix.size()).trimmed();
        bool ok = false;
        const qint64 value = rest.split(' ').first().toLongLong(&ok);
        return ok ? value : 0;
    }
    return 0;
}

QString ProcessRss::snapshot() const
{
    return QStringLiteral("pid=%1  VmRSS=%2 kB  RssAnon=%3 kB  RssFile=%4 kB  RssShmem=%5 kB")
        .arg(QCoreApplication::applicationPid())
        .arg(vmRssKb())
        .arg(rssAnonKb())
        .arg(rssFileKb())
        .arg(rssShmemKb());
}
