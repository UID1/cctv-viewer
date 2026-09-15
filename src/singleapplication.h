#ifndef SINGLEAPPLICATION_H
#define SINGLEAPPLICATION_H

#include <QDir>
#include <QFile>
#include <QLockFile>
#include <QCoreApplication>
#include <QStandardPaths>
#include <unistd.h>
#include <signal.h>

class SingleApplication : public QObject
{
    Q_OBJECT

public:
    explicit SingleApplication(QObject *parent = nullptr)
        : QObject(parent),
          m_lockFile(getLockFilePath()),
          m_anotherInstanceRunning(false)
    {
        QString lockPath = getLockFilePath();
        qInfo() << "SingleApplication: Lock file path:" << lockPath;
        
        // Set a very short stale lock time (5 seconds) to quickly detect dead processes
        m_lockFile.setStaleLockTime(5000);
        
        // Try to acquire the lock
        if (!m_lockFile.tryLock(100)) {
            // Lock failed - check if the process is actually running
            qint64 pid = 0;
            QString hostname, appname;
            m_lockFile.getLockInfo(&pid, &hostname, &appname);
            
            qInfo() << "SingleApplication: Lock held by PID" << pid << "app:" << appname;
            
            if (pid > 0 && !isProcessRunning(pid)) {
                // Process is not running - stale lock, remove it
                qWarning() << "SingleApplication: Stale lock detected (PID" << pid << "not running), removing...";
                m_lockFile.removeStaleLockFile();
                
                // Try again
                if (m_lockFile.tryLock(100)) {
                    qInfo() << "SingleApplication: Lock acquired after removing stale lock";
                    m_anotherInstanceRunning = false;
                } else {
                    qWarning() << "SingleApplication: Still cannot acquire lock after cleanup";
                    m_anotherInstanceRunning = true;
                }
            } else if (m_lockFile.error() == QLockFile::LockFailedError) {
                // Another instance is actually running
                m_anotherInstanceRunning = true;
                qWarning() << "SingleApplication: Another instance is running (PID" << pid << ")";
            } else {
                // Lock failed for other reasons (permissions, etc.) - don't block
                qWarning() << "SingleApplication: Could not acquire lock:"
                           << m_lockFile.error() << "- allowing startup anyway";
                m_anotherInstanceRunning = false;
            }
        } else {
            qInfo() << "SingleApplication: Lock acquired successfully";
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

    static bool isProcessRunning(qint64 pid) {
        if (pid <= 0) return false;
        // Send signal 0 to check if process exists
        return (kill(static_cast<pid_t>(pid), 0) == 0);
    }

    QLockFile m_lockFile;
    bool m_anotherInstanceRunning;
};

#endif // SINGLEAPPLICATION_H
