#ifndef PROCESSRSS_H
#define PROCESSRSS_H

#include <QObject>
#include <QString>

class ProcessRss : public QObject
{
    Q_OBJECT

public:
    explicit ProcessRss(QObject *parent = nullptr) : QObject(parent) {}

    Q_INVOKABLE qint64 vmRssKb() const { return readKb("VmRSS"); }
    Q_INVOKABLE qint64 rssAnonKb() const { return readKb("RssAnon"); }
    Q_INVOKABLE qint64 rssFileKb() const { return readKb("RssFile"); }
    Q_INVOKABLE qint64 rssShmemKb() const { return readKb("RssShmem"); }
    Q_INVOKABLE QString snapshot() const;

private:
    static qint64 readKb(const char *key);
};

#endif
