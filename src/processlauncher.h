#ifndef PROCESSLAUNCHER_H
#define PROCESSLAUNCHER_H

#include <QObject>
#include <QString>
#include <QStringList>

class ProcessLauncher : public QObject
{
    Q_OBJECT

public:
    explicit ProcessLauncher(QObject *parent = nullptr) : QObject(parent) {}

    Q_INVOKABLE bool launch(const QString &program, const QStringList &arguments = QStringList());
};

#endif // PROCESSLAUNCHER_H
