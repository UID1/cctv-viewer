#include "processrss.h"

#include <QDebug>
#include <QFileInfo>
#include <QGuiApplication>
#include <QProcess>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QThread>
#include <QUrl>

static QUrl mediaUrl(const QString &spec)
{
    if (spec.startsWith(QLatin1String("rtmp:"))
        || spec.startsWith(QLatin1String("rtsp:"))
        || spec.startsWith(QLatin1String("http:"))
        || spec.startsWith(QLatin1String("https:"))
        || spec.startsWith(QLatin1String("udp:"))
        || spec.startsWith(QLatin1String("tcp:"))
        || spec.startsWith(QLatin1String("file:"))) {
        return QUrl(spec);
    }
    return QUrl::fromLocalFile(QFileInfo(spec).absoluteFilePath());
}

// Distro Qt FFmpeg sets avformat "timeout"; for RTMP that implies listen (QTBUG-144996).
// Remux to local multicast MPEG-TS so MediaPlayer never opens rtmp:// itself.
static QUrl relayRtmpToUdp(QObject *parent, const QUrl &src, quint16 port)
{
    if (src.scheme() != QLatin1String("rtmp") && src.scheme() != QLatin1String("rtmps"))
        return src;

    const QString dest = QStringLiteral("udp://239.1.71.%1:%2?pkt_size=1316&ttl=1")
                             .arg(port == 18901 ? 1 : 2)
                             .arg(port);

    auto *ff = new QProcess(parent);
    ff->setProgram(QStringLiteral("ffmpeg"));
    ff->setArguments({
        QStringLiteral("-hide_banner"),
        QStringLiteral("-loglevel"), QStringLiteral("warning"),
        QStringLiteral("-i"), src.toString(QUrl::FullyEncoded),
        QStringLiteral("-c"), QStringLiteral("copy"),
        QStringLiteral("-f"), QStringLiteral("mpegts"),
        dest,
    });
    QObject::connect(ff, &QProcess::errorOccurred, parent, [](QProcess::ProcessError) {
        qWarning() << "ffmpeg relay failed (is ffmpeg on PATH?)";
    });
    ff->start();
    if (!ff->waitForStarted(4000)) {
        qWarning() << "ffmpeg relay did not start:" << ff->errorString();
        return src;
    }
    QThread::msleep(500);
    qInfo() << "Relaying" << src.toString() << "->" << dest;
    return QUrl(dest);
}

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    const QUrl raw0 = argc > 1 ? mediaUrl(QString::fromLocal8Bit(argv[1]))
                               : QUrl(QStringLiteral("rtmp://live.a71.ru/demo/0"));
    const QUrl raw1 = argc > 2 ? mediaUrl(QString::fromLocal8Bit(argv[2]))
                               : QUrl(QStringLiteral("rtmp://live.a71.ru/demo/1"));

    const QUrl url0 = relayRtmpToUdp(&app, raw0, 18901);
    const QUrl url1 = relayRtmpToUdp(&app, raw1, 18902);

    ProcessRss rss;
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("ProcessRss"), &rss);
    engine.rootContext()->setContextProperty(QStringLiteral("streamUrl0"), url0);
    engine.rootContext()->setContextProperty(QStringLiteral("streamUrl1"), url1);

    const QUrl qml(QStringLiteral("qrc:/main.qml"));
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &app, [qml](QObject *obj, const QUrl &objUrl) {
        if (!obj && qml == objUrl)
            QCoreApplication::exit(-1);
    }, Qt::QueuedConnection);
    engine.load(qml);

    return app.exec();
}
