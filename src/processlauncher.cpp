#include "processlauncher.h"

#include <QProcess>
#include <QDebug>

bool ProcessLauncher::launch(const QString &program, const QStringList &arguments)
{
    qInfo() << "Launching:" << program << arguments;
    
    bool success = QProcess::startDetached(program, arguments);
    
    if (!success) {
        qWarning() << "Failed to launch:" << program;
    }
    
    return success;
}
