#ifndef SINGLEAPPLICATION_H
#define SINGLEAPPLICATION_H

#include <QDir>
#include <QLockFile>
#include <QCoreApplication>
#include <QStandardPaths>
#include <unistd.h>

class SingleApplication : public QObject
{
    Q_OBJECT

public:
    explicit SingleApplication(QObject *parent = nullptr)
        : QObject(parent),
          m_lockFile(getLockFilePath()),
          m_anotherInstanceRunning(false)
    {
        // Try to acquire the lock
        if (!m_lockFile.tryLock(100)) {
            // Lock failed - check why
            if (m_lockFile.error() == QLockFile::LockFailedError) {
                // Another instance holds the lock
                m_anotherInstanceRunning = true;
                qWarning() << "SingleApplication: Another instance is running (lock held by PID"
                           << getLockingPid() << ")";
            } else {
                // Lock failed for other reasons (permissions, etc.) - don't block
                qWarning() << "SingleApplication: Could not acquire lock:"
                           << m_lockFile.error() << "- allowing startup anyway";
                m_anotherInstanceRunning = false;
            }
        }
    }

    Q_INVOKABLE bool isRunning() const { return m_anotherInstanceRunning; }

private:
    static QString getLockFilePath() {
        // Use runtime dir if available (per-user), otherwise temp with uid
        QString runtimeDir = QStandardPaths::writableLocation(QStandardPaths::RuntimeLocation);
        if (runtimeDir.isEmpty()) {
            runtimeDir = QDir::tempPath();
        }
        QString appName = QFileInfo(QCoreApplication::applicationFilePath()).fileName();
        return runtimeDir + "/" + appName + "-" + QString::number(getuid()) + ".lock";
    }

    qint64 getLockingPid() const {
        qint64 pid = 0;
        QString hostname, appname;
        m_lockFile.getLockInfo(&pid, &hostname, &appname);
        return pid;
    }

    QLockFile m_lockFile;
    bool m_anotherInstanceRunning;
};

#endif // SINGLEAPPLICATION_H
